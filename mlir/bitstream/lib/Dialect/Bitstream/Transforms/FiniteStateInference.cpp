#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamPasses.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"

#include <cassert>
#include <memory>
#include <optional>
#include <string>

namespace bitstream {
#define GEN_PASS_DEF_BITSTREAMFINITESTATEINFERENCE
#include "Bitstream/BitstreamPasses.h.inc"
} // namespace bitstream

using namespace mlir;
using namespace bitstream;

namespace {

static StringRef getStringAttr(Operation *op, StringRef name,
                               StringRef fallback = "") {
  if (auto attr = op->getAttrOfType<StringAttr>(name))
    return attr.getValue();
  return fallback;
}

static int64_t bitsNeededForDomain(int64_t domain) {
  if (domain <= 1)
    return 1;
  int64_t bits = 0;
  int64_t values = domain - 1;
  while (values > 0) {
    ++bits;
    values >>= 1;
  }
  return bits;
}

static void createFiniteState(OpBuilder &builder, Operation *stage,
                              StringRef name, int64_t domain,
                              StateTransitionKind transition,
                              std::optional<int64_t> distance,
                              std::optional<int64_t> modulus) {
  OperationState state(stage->getLoc(), StateOp::getOperationName());
  state.addAttribute(SymbolTable::getSymbolAttrName(),
                     builder.getStringAttr(name));
  state.addAttribute("bits",
                     builder.getI64IntegerAttr(bitsNeededForDomain(domain)));
  state.addAttribute("domain", builder.getI64IntegerAttr(domain));
  state.addAttribute("transition", StateTransitionKindAttr::get(
                                       builder.getContext(), transition));
  if (distance)
    state.addAttribute("distance", builder.getI64IntegerAttr(*distance));
  if (modulus)
    state.addAttribute("modulus", builder.getI64IntegerAttr(*modulus));
  state.addAttribute("inferred", builder.getUnitAttr());

  auto &body = stage->getRegion(0).front();
  builder.setInsertionPointToStart(&body);
  builder.create(state);
}

static StringRef leafSymbolName(SymbolRefAttr ref) {
  ArrayRef<FlatSymbolRefAttr> nested = ref.getNestedReferences();
  if (!nested.empty())
    return nested.back().getValue();
  return ref.getRootReference();
}

static AnalysisOp findAnalysisForPipeline(ModuleOp module,
                                          StringRef pipelineName) {
  AnalysisOp result;
  module.walk([&](AnalysisOp analysis) {
    if (result)
      return;
    auto source = analysis.getOperation()->getAttrOfType<FlatSymbolRefAttr>(
        "source_pipeline");
    if (source && source.getValue() == pipelineName)
      result = analysis;
  });
  return result;
}

static SymbolRefAttr makeStateRef(MLIRContext *ctx, StringRef pipeline,
                                  StringRef stage, StringRef state) {
  return SymbolRefAttr::get(
      ctx, pipeline,
      {FlatSymbolRefAttr::get(ctx, stage), FlatSymbolRefAttr::get(ctx, state)});
}

static ArrayAttr makeSingleStateRefArray(Builder &builder, StringRef pipeline,
                                         StringRef stage, StringRef state) {
  return builder.getArrayAttr(
      {makeStateRef(builder.getContext(), pipeline, stage, state)});
}

static ArrayAttr makeTwoStateRefArray(Builder &builder, StringRef pipeline,
                                      StringRef firstStage,
                                      StringRef firstState,
                                      StringRef secondStage,
                                      StringRef secondState) {
  return builder.getArrayAttr(
      {makeStateRef(builder.getContext(), pipeline, firstStage, firstState),
       makeStateRef(builder.getContext(), pipeline, secondStage, secondState)});
}

static bool hasRawMemoryDependency(DependencyOp dep) {
  auto memory = dep.getOperation()->getAttrOfType<MemoryDependencyKindAttr>(
      "memory_dependency");
  return memory && memory.getValue() == MemoryDependencyKind::RAW;
}

struct ProjectedRead {
  ReadOp read;
  Operation *projection = nullptr;
};

struct ProjectionRef {
  Operation *op = nullptr;
  Value buffer;
  Value index;
};

static ReadOp findExactReadForEdge(DependencyOp dep, Operation *consumerStage,
                                   Value buffer) {
  if (!consumerStage || !buffer)
    return {};
  StringRef access = getStringAttr(dep.getOperation(), "consumer_access");
  if (access.empty())
    return {};

  ReadOp result;
  bool ambiguous = false;
  consumerStage->walk([&](ReadOp read) {
    if (read.getBuffer() != buffer ||
        getStringAttr(read.getOperation(), "access_id") != access)
      return;
    if (result) {
      ambiguous = true;
      return;
    }
    result = read;
  });
  return ambiguous ? ReadOp() : result;
}

static WriteOp findExactWriteForEdge(DependencyOp dep, Operation *producerStage,
                                     Value buffer) {
  if (!producerStage || !buffer)
    return {};
  StringRef access = getStringAttr(dep.getOperation(), "producer_access");
  if (access.empty())
    return {};

  WriteOp result;
  bool ambiguous = false;
  producerStage->walk([&](WriteOp write) {
    if (write.getBuffer() != buffer ||
        getStringAttr(write.getOperation(), "access_id") != access)
      return;
    if (result) {
      ambiguous = true;
      return;
    }
    result = write;
  });
  return ambiguous ? WriteOp() : result;
}

static std::optional<ProjectionRef> getProjectionRef(Operation *op) {
  if (auto projection = dyn_cast<ProjectStateOp>(op))
    return ProjectionRef{op, projection.getBuffer(), projection.getIndex()};
  return std::nullopt;
}

static void collectProjectionRefs(Operation *stage, Value buffer,
                                  SmallVectorImpl<ProjectionRef> &out) {
  stage->walk([&](Operation *op) {
    std::optional<ProjectionRef> projection = getProjectionRef(op);
    if (projection && projection->buffer == buffer)
      out.push_back(*projection);
  });
}

static bool hasValidProjectionProof(Operation *projection) {
  auto domainAttr = projection->getAttrOfType<IntegerAttr>("domain");
  return isa<ProjectStateOp>(projection) && domainAttr &&
         domainAttr.getInt() > 0;
}

static bool sameIndexValue(Value lhs, Value rhs, unsigned depth = 0) {
  if (lhs == rhs)
    return true;
  if (!lhs || !rhs || depth > 8)
    return false;

  Operation *lhsDef = lhs.getDefiningOp();
  Operation *rhsDef = rhs.getDefiningOp();
  if (!lhsDef || !rhsDef)
    return false;
  if (lhsDef->getName() != rhsDef->getName())
    return false;
  if (lhsDef->getNumResults() != 1 || rhsDef->getNumResults() != 1)
    return false;
  if (lhsDef->getAttrDictionary() != rhsDef->getAttrDictionary())
    return false;
  if (lhsDef->getNumOperands() != rhsDef->getNumOperands())
    return false;

  for (auto [lhsOperand, rhsOperand] :
       llvm::zip(lhsDef->getOperands(), rhsDef->getOperands())) {
    if (!sameIndexValue(lhsOperand, rhsOperand, depth + 1))
      return false;
  }
  return true;
}

static std::optional<ProjectedRead>
findProjectedReadForEdge(DependencyOp dep, Operation *consumerStage,
                         Value buffer) {
  if (!consumerStage || !buffer)
    return std::nullopt;

  auto consumerAccess =
      dep.getOperation()->getAttrOfType<StringAttr>("consumer_access");
  if (!consumerAccess || consumerAccess.getValue().empty())
    return std::nullopt;

  SmallVector<ProjectionRef> projections;
  collectProjectionRefs(consumerStage, buffer, projections);

  std::optional<ProjectedRead> result;
  consumerStage->walk([&](ReadOp read) {
    if (result || read.getBuffer() != buffer)
      return;
    auto readId = read.getOperation()->getAttrOfType<StringAttr>("access_id");
    if (!readId || readId.getValue() != consumerAccess.getValue())
      return;
    for (ProjectionRef projection : projections) {
      auto projectedRead =
          projection.op->getAttrOfType<StringAttr>("read_access");
      if (!projectedRead ||
          projectedRead.getValue() != consumerAccess.getValue())
        continue;
      if (!sameIndexValue(projection.index, read.getIndex()))
        continue;
      if (!hasValidProjectionProof(projection.op))
        continue;
      result = ProjectedRead{read, projection.op};
      return;
    }
  });
  return result;
}

static bool isNestedUnderWhile(ReadOp read, Operation *stage) {
  for (Operation *parent = read.getOperation()->getParentOp();
       parent && parent != stage; parent = parent->getParentOp()) {
    if (parent->getName().getStringRef() == "scf.while")
      return true;
  }
  return false;
}

static void annotateReadWithState(ReadOp read, StringRef stateName,
                                  ReadDependencyKind dependency,
                                  StateUseKind stateKind) {
  MLIRContext *ctx = read.getContext();
  read.getOperation()->setAttr("dependency",
                               ReadDependencyKindAttr::get(ctx, dependency));
  read.getOperation()->setAttr("state", SymbolRefAttr::get(ctx, stateName));
  read.getOperation()->setAttr("state_kind",
                               StateUseKindAttr::get(ctx, stateKind));
}

static std::optional<int64_t> positiveDomain(Operation *op,
                                             StringRef attribute) {
  if (!op)
    return std::nullopt;
  auto domain = op->getAttrOfType<IntegerAttr>(attribute);
  if (!domain || domain.getInt() <= 0)
    return std::nullopt;
  return domain.getInt();
}

static void clearEdgeFiniteStateProof(DependencyOp dep, Builder &builder) {
  dep.getOperation()->setAttr(
      "finite_state", FiniteStateProofKindAttr::get(
                          builder.getContext(), FiniteStateProofKind::None));
  dep.getOperation()->removeAttr("finite_state_domain");
  dep.getOperation()->removeAttr("states");
}

static void setEdgeFiniteStateProof(DependencyOp dep, Builder &builder,
                                    ArrayAttr states, int64_t domain) {
  assert(states && !states.empty() && domain > 0 &&
         "finite-state proof requires states and a positive domain");
  dep.getOperation()->setAttr(
      "finite_state", FiniteStateProofKindAttr::get(
                          builder.getContext(), FiniteStateProofKind::Proven));
  dep.getOperation()->setAttr("finite_state_domain",
                              builder.getI64IntegerAttr(domain));
  dep.getOperation()->setAttr("states", states);
}

static void markEdgeFiniteState(DependencyOp dep, Builder &builder,
                                StringRef pipelineName, StringRef stageName,
                                StringRef stateName, int64_t domain) {
  setEdgeFiniteStateProof(
      dep, builder,
      makeSingleStateRefArray(builder, pipelineName, stageName, stateName),
      domain);
}

struct BitstreamFiniteStateInferencePass
    : bitstream::impl::BitstreamFiniteStateInferenceBase<
          BitstreamFiniteStateInferencePass> {
  void runOnOperation() override {
    ModuleOp module = getOperation();

    module.walk([&](PipelineOp pipeline) {
      SmallVector<Operation *> staleStates;
      pipeline.getBody().walk([&](StateOp state) {
        if (state.getOperation()->hasAttr("inferred"))
          staleStates.push_back(state.getOperation());
      });
      for (Operation *op : staleStates)
        op->erase();
      pipeline.getBody().walk([&](ReadOp read) {
        read.getOperation()->removeAttr("dependency");
        read.getOperation()->removeAttr("state");
        read.getOperation()->removeAttr("state_kind");
      });

      llvm::StringMap<Value> buffersByName;
      llvm::StringMap<Operation *> stagesByName;
      llvm::StringMap<std::string> scanStateByStageAndBuffer;
      llvm::DenseMap<Operation *, std::string> recurrenceStateByOp;
      unsigned nextStateId = 0;
      auto newStateName = [&]() {
        return "state" + std::to_string(nextStateId++);
      };
      pipeline.getBody().walk([&](BufferOp buffer) {
        StringRef name = getStringAttr(buffer.getOperation(),
                                       SymbolTable::getSymbolAttrName());
        if (!name.empty()) {
          buffersByName[name] = buffer.getBuffer();
        }
      });

      OpBuilder builder(pipeline.getContext());
      std::string pipelineName = getStringAttr(pipeline.getOperation(),
                                               SymbolTable::getSymbolAttrName())
                                     .str();
      AnalysisOp analysis = findAnalysisForPipeline(module, pipelineName);
      if (!analysis)
        return;

      for (Operation &stage : pipeline.getBody().front()) {
        if (!isa<KernelOp, ScanOp>(&stage))
          continue;
        StringRef name =
            getStringAttr(&stage, SymbolTable::getSymbolAttrName());
        if (!name.empty())
          stagesByName[name] = &stage;
      }

      analysis.getBody().walk(
          [&](DependencyOp dep) { clearEdgeFiniteStateProof(dep, builder); });

      auto createStateForStage =
          [&](Operation *stage, int64_t domain, StateTransitionKind transition,
              std::optional<int64_t> distance,
              std::optional<int64_t> modulus) -> std::string {
        std::string stateName = newStateName();
        createFiniteState(builder, stage, stateName, domain, transition,
                          distance, modulus);
        return stateName;
      };

      auto createRegexAdvanceStateForStage =
          [&](Operation *stage, int64_t maxDistance, int64_t advanceCount,
              StringRef direction) -> std::string {
        std::string stateName = newStateName();
        int64_t domain = std::max<int64_t>(2, maxDistance + 1);

        OperationState state(stage->getLoc(), StateOp::getOperationName());
        state.addAttribute(SymbolTable::getSymbolAttrName(),
                           builder.getStringAttr(stateName));
        state.addAttribute(
            "bits", builder.getI64IntegerAttr(bitsNeededForDomain(domain)));
        state.addAttribute("domain", builder.getI64IntegerAttr(domain));
        state.addAttribute(
            "transition",
            StateTransitionKindAttr::get(builder.getContext(),
                                         StateTransitionKind::RegexAdvance));
        state.addAttribute("distance", builder.getI64IntegerAttr(maxDistance));
        state.addAttribute("max_advance_distance",
                           builder.getI64IntegerAttr(maxDistance));
        state.addAttribute("advance_count",
                           builder.getI64IntegerAttr(advanceCount));
        state.addAttribute("advance_direction",
                           builder.getStringAttr(direction));
        state.addAttribute("finite_state_source",
                           builder.getStringAttr("bitstream.advance"));
        state.addAttribute(
            "derived_from",
            builder.getStringAttr("max bitstream.advance distance + 1"));
        state.addAttribute("inferred", builder.getUnitAttr());

        auto &body = stage->getRegion(0).front();
        builder.setInsertionPointToStart(&body);
        builder.create(state);
        return stateName;
      };

      for (Operation &stage : pipeline.getBody().front()) {
        if (!isa<KernelOp>(&stage))
          continue;

        int64_t maxDistance = 0;
        int64_t advanceCount = 0;
        std::string direction;
        stage.walk([&](AdvanceOp advance) {
          auto distance =
              advance.getOperation()->getAttrOfType<IntegerAttr>("distance");
          if (!distance || distance.getInt() <= 0)
            return;
          maxDistance = std::max(maxDistance, distance.getInt());
          if (auto count =
                  advance.getOperation()->getAttrOfType<IntegerAttr>("count"))
            advanceCount += std::max<int64_t>(1, count.getInt());
          else
            ++advanceCount;
          StringRef currentDirection =
              getStringAttr(advance.getOperation(), "direction");
          if (direction.empty())
            direction = currentDirection.str();
          else if (direction != currentDirection)
            direction = "mixed";
        });

        if (maxDistance > 0)
          createRegexAdvanceStateForStage(
              &stage, maxDistance, std::max<int64_t>(1, advanceCount),
              direction.empty() ? StringRef("unknown") : StringRef(direction));
      }

      auto getOrCreateScanState =
          [&](Operation *scanStage, StringRef scanName, StringRef bufferName,
              int64_t domain) -> std::optional<std::string> {
        if (!scanStage || scanName.empty() || bufferName.empty())
          return std::nullopt;
        std::string key = scanName.str() + "|" + bufferName.str();
        auto existing = scanStateByStageAndBuffer.find(key);
        if (existing != scanStateByStageAndBuffer.end())
          return existing->second;

        StringRef combiner = getStringAttr(scanStage, "combiner");
        std::optional<int64_t> modulus;
        if (combiner != "xor")
          modulus = domain;
        std::string stateName =
            createStateForStage(scanStage, domain,
                                combiner == "xor" ? StateTransitionKind::Xor
                                                  : StateTransitionKind::AddMod,
                                std::nullopt, modulus);
        scanStateByStageAndBuffer[key] = stateName;
        return stateName;
      };

      auto getOrCreateRecurrenceState =
          [&](RecurrenceOp recurrence, Operation *stage,
              int64_t domain) -> std::optional<std::string> {
        if (!recurrence || !stage || domain <= 0)
          return std::nullopt;
        auto existing = recurrenceStateByOp.find(recurrence.getOperation());
        if (existing != recurrenceStateByOp.end())
          return existing->second;

        StringRef combiner =
            getStringAttr(recurrence.getOperation(), "combiner");
        std::optional<int64_t> modulus;
        StateTransitionKind transition = StateTransitionKind::AddMod;
        if (combiner == "xor")
          transition = StateTransitionKind::Xor;
        else
          modulus = domain;
        std::string stateName = createStateForStage(stage, domain, transition,
                                                    std::nullopt, modulus);
        recurrenceStateByOp[recurrence.getOperation()] = stateName;
        return stateName;
      };

      analysis.getBody().walk([&](DependencyOp dep) {
        if (!hasRawMemoryDependency(dep))
          return;

        auto consumerRef =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("consumer");
        auto producerRef =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("producer");
        auto bufferRef =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("buffer");
        if (!consumerRef || !bufferRef)
          return;

        StringRef consumerName = leafSymbolName(consumerRef);
        StringRef producerName = producerRef ? leafSymbolName(producerRef) : "";
        StringRef bufferName = leafSymbolName(bufferRef);
        auto stageIt = stagesByName.find(consumerName);
        auto bufferIt = buffersByName.find(bufferName);
        if (stageIt == stagesByName.end() || bufferIt == buffersByName.end())
          return;

        Operation *consumerStage = stageIt->second;
        Operation *producerStage = nullptr;
        if (!producerName.empty()) {
          auto producerIt = stagesByName.find(producerName);
          if (producerIt != stagesByName.end())
            producerStage = producerIt->second;
        }
        Value buffer = bufferIt->second;
        bool hasFiniteByteWindow =
            dep.getOperation()->hasAttr("producer_byte_window");
        bool producerIsScan = isa_and_nonnull<ScanOp>(producerStage);
        bool consumerIsScan = isa<ScanOp>(consumerStage);

        if (producerIsScan && !consumerIsScan && !hasFiniteByteWindow) {
          ReadOp exactRead = findExactReadForEdge(dep, consumerStage, buffer);
          WriteOp exactWrite =
              findExactWriteForEdge(dep, producerStage, buffer);
          std::optional<int64_t> scanDomain =
              positiveDomain(producerStage, "state_domain");
          std::optional<int64_t> valueDomain =
              exactWrite
                  ? positiveDomain(exactWrite.getOperation(), "value_domain")
                  : std::nullopt;

          // Preferred structural proof: recovery identified a global scan,
          // its carried state has a finite domain, and the exact write named
          // by this dependency stores a value in that same domain.  The exact
          // consumer access therefore reads the scan state directly; no
          // source-name heuristic or fabricated ProjectState is needed.
          if (exactRead && exactWrite && scanDomain && valueDomain &&
              *scanDomain == *valueDomain) {
            StringRef scanName = leafSymbolName(producerRef);
            std::string consumerState =
                createStateForStage(consumerStage, *scanDomain,
                                    StateTransitionKind::PrefixStateProjection,
                                    std::nullopt, std::nullopt);
            std::optional<std::string> scanState = getOrCreateScanState(
                producerStage, scanName, bufferName, *scanDomain);
            if (!scanState)
              return;

            annotateReadWithState(exactRead, consumerState,
                                  ReadDependencyKind::PrefixState,
                                  StateUseKind::CarriedState);
            setEdgeFiniteStateProof(
                dep, builder,
                makeTwoStateRefArray(builder, pipelineName, scanName,
                                     *scanState, consumerName, consumerState),
                *scanDomain);
            return;
          }

          // Compatibility path for hand-written/older IR that lacks recovered
          // scan-domain metadata but provides an exact ProjectState proof.
          std::optional<ProjectedRead> projected =
              findProjectedReadForEdge(dep, consumerStage, buffer);
          if (!projected)
            return;

          int64_t domain =
              projected->projection->getAttrOfType<IntegerAttr>("domain")
                  .getInt();
          if ((scanDomain && *scanDomain != domain) ||
              (valueDomain && *valueDomain != domain))
            return;
          std::string consumerState = createStateForStage(
              consumerStage, domain, StateTransitionKind::PrefixStateProjection,
              std::nullopt, std::nullopt);
          annotateReadWithState(projected->read, consumerState,
                                ReadDependencyKind::PrefixState,
                                StateUseKind::FiniteStateProjection);
          if (!producerRef)
            return;
          StringRef scanName = leafSymbolName(producerRef);
          auto scanIt = stagesByName.find(scanName);
          if (scanIt == stagesByName.end())
            return;
          std::optional<std::string> scanState = getOrCreateScanState(
              scanIt->second, scanName, bufferName, domain);
          if (!scanState)
            return;

          // The producer stage itself identifies this as a scan dependency.
          // The exact finite-state proof is sufficient for speculative fusion;
          // no separate dependency-reduction marker is needed.
          setEdgeFiniteStateProof(
              dep, builder,
              makeTwoStateRefArray(builder, pipelineName, scanName, *scanState,
                                   consumerName, consumerState),
              domain);
          return;
        }

        if (hasFiniteByteWindow) {
          std::optional<ProjectedRead> projected =
              findProjectedReadForEdge(dep, consumerStage, buffer);
          if (!projected)
            return;

          int64_t domain =
              projected->projection->getAttrOfType<IntegerAttr>("domain")
                  .getInt();
          std::optional<int64_t> modulus;
          if (auto attr =
                  projected->projection->getAttrOfType<IntegerAttr>("modulus"))
            modulus = attr.getInt();
          std::string stateName = createStateForStage(
              consumerStage, domain, StateTransitionKind::ProjectedState,
              std::nullopt, modulus);
          annotateReadWithState(projected->read, stateName,
                                ReadDependencyKind::ProjectedState,
                                StateUseKind::ProjectedState);
          markEdgeFiniteState(dep, builder, pipelineName, consumerName,
                              stateName, domain);
          return;
        }

        if (consumerIsScan || producerIsScan)
          return;

        ReadOp exactRead = findExactReadForEdge(dep, consumerStage, buffer);
        RecurrenceOp recurrence =
            exactRead ? findVaryingRecurrence(exactRead) : RecurrenceOp();
        std::optional<int64_t> recurrenceDomain =
            recurrence
                ? positiveDomain(recurrence.getOperation(), "state_domain")
                : std::nullopt;
        if (exactRead && recurrence && recurrenceDomain) {
          std::optional<std::string> stateName = getOrCreateRecurrenceState(
              recurrence, consumerStage, *recurrenceDomain);
          if (!stateName)
            return;
          annotateReadWithState(exactRead, *stateName,
                                ReadDependencyKind::PrefixState,
                                StateUseKind::CarriedState);
          markEdgeFiniteState(dep, builder, pipelineName, consumerName,
                              *stateName, *recurrenceDomain);
          return;
        }

        std::optional<ProjectedRead> projected =
            findProjectedReadForEdge(dep, consumerStage, buffer);
        if (!projected || !isNestedUnderWhile(projected->read, consumerStage))
          return;

        int64_t domain =
            projected->projection->getAttrOfType<IntegerAttr>("domain")
                .getInt();
        std::optional<int64_t> modulus;
        if (auto attr =
                projected->projection->getAttrOfType<IntegerAttr>("modulus"))
          modulus = attr.getInt();
        std::string stateName = createStateForStage(
            consumerStage, domain, StateTransitionKind::NeighborFiniteState,
            /*distance=*/1, modulus);
        annotateReadWithState(projected->read, stateName,
                              ReadDependencyKind::DataDependentPredecessor,
                              StateUseKind::NeighborFiniteState);
        markEdgeFiniteState(dep, builder, pipelineName, consumerName, stateName,
                            domain);
      });
    });
  }
};

} // namespace

std::unique_ptr<Pass> bitstream::createBitstreamFiniteStateInferencePass() {
  return std::make_unique<BitstreamFiniteStateInferencePass>();
}
