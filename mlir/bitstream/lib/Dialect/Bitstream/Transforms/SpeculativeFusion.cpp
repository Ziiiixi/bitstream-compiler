#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamPasses.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/Support/raw_ostream.h"

#include <algorithm>
#include <memory>
#include <optional>
#include <string>

namespace bitstream {
#define GEN_PASS_DEF_BITSTREAMSPECULATIVEFUSION
#include "Bitstream/BitstreamPasses.h.inc"
} // namespace bitstream

using namespace mlir;
using namespace bitstream;

namespace {

static constexpr int64_t kMinimumRuntimeStateDomain = 2;
static constexpr int64_t kBinaryScanStateDomain = 2;
static constexpr int64_t kMaxProjectedStateDomain = 33;

static StringRef getStringAttr(Operation *op, StringRef name,
                               StringRef fallback = "") {
  if (auto attr = op->getAttrOfType<StringAttr>(name))
    return attr.getValue();
  return fallback;
}

static std::optional<MemoryDependencyKind>
getMemoryDependency(DependencyOp dep) {
  if (auto attr = dep.getOperation()->getAttrOfType<MemoryDependencyKindAttr>(
          "memory_dependency"))
    return attr.getValue();
  return std::nullopt;
}

static std::optional<int64_t> getI64Attr(Operation *op, StringRef name) {
  if (auto attr = op->getAttrOfType<IntegerAttr>(name))
    return attr.getInt();
  return std::nullopt;
}

static std::string joinStrings(ArrayRef<std::string> parts, StringRef sep) {
  std::string result;
  llvm::raw_string_ostream os(result);
  for (unsigned i = 0; i < parts.size(); ++i) {
    if (i)
      os << sep;
    os << parts[i];
  }
  return os.str();
}

static std::string concat(StringRef a, StringRef b, StringRef c = "") {
  std::string result;
  llvm::raw_string_ostream os(result);
  os << a << b << c;
  return os.str();
}

static std::string encodeSymbolRef(SymbolRefAttr ref) {
  std::string result = ref.getRootReference().str();
  for (FlatSymbolRefAttr nested : ref.getNestedReferences()) {
    result += "::";
    result += nested.getValue().str();
  }
  return result;
}

static StringRef leafSymbolName(SymbolRefAttr ref) {
  ArrayRef<FlatSymbolRefAttr> nested = ref.getNestedReferences();
  if (!nested.empty())
    return nested.back().getValue();
  return ref.getRootReference();
}

static bool sameIndexValue(Value lhs, Value rhs, unsigned depth = 0) {
  if (lhs == rhs)
    return true;
  if (!lhs || !rhs || depth > 8)
    return false;

  Operation *lhsDef = lhs.getDefiningOp();
  Operation *rhsDef = rhs.getDefiningOp();
  if (!lhsDef || !rhsDef || lhsDef->getName() != rhsDef->getName())
    return false;
  if (lhsDef->getNumResults() != 1 || rhsDef->getNumResults() != 1 ||
      lhsDef->getAttrDictionary() != rhsDef->getAttrDictionary() ||
      lhsDef->getNumOperands() != rhsDef->getNumOperands())
    return false;
  for (auto [lhsOperand, rhsOperand] :
       llvm::zip(lhsDef->getOperands(), rhsDef->getOperands()))
    if (!sameIndexValue(lhsOperand, rhsOperand, depth + 1))
      return false;
  return true;
}

struct ExactProjectedRead {
  ReadOp read;
  ProjectStateOp projection;
};

static ReadOp findExactRead(DependencyOp dep, Operation *consumerStage,
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

static WriteOp findExactWrite(DependencyOp dep, Operation *producerStage,
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

static std::optional<ExactProjectedRead>
findExactProjectedRead(DependencyOp dep, Operation *consumerStage,
                       Value buffer) {
  if (!consumerStage || !buffer)
    return std::nullopt;
  StringRef consumerAccess =
      getStringAttr(dep.getOperation(), "consumer_access");
  if (consumerAccess.empty())
    return std::nullopt;

  SmallVector<ProjectStateOp> projections;
  consumerStage->walk([&](ProjectStateOp projection) {
    if (projection.getBuffer() != buffer ||
        getStringAttr(projection.getOperation(), "read_access") !=
            consumerAccess)
      return;
    auto domain =
        projection.getOperation()->getAttrOfType<IntegerAttr>("domain");
    if (domain && domain.getInt() >= 2)
      projections.push_back(projection);
  });

  std::optional<ExactProjectedRead> result;
  consumerStage->walk([&](ReadOp read) {
    if (result || read.getBuffer() != buffer ||
        getStringAttr(read.getOperation(), "access_id") != consumerAccess)
      return;
    for (ProjectStateOp projection : projections) {
      if (sameIndexValue(projection.getIndex(), read.getIndex())) {
        result = ExactProjectedRead{read, projection};
        return;
      }
    }
  });
  return result;
}

static bool isNestedUnderWhile(ReadOp read, Operation *stage) {
  for (Operation *parent = read.getOperation()->getParentOp();
       parent && parent != stage; parent = parent->getParentOp())
    if (parent->getName().getStringRef() == "scf.while")
      return true;
  return false;
}

static void appendStateRefs(ArrayAttr refs, llvm::StringSet<> &states) {
  if (!refs)
    return;
  for (Attribute attr : refs)
    if (auto ref = dyn_cast<SymbolRefAttr>(attr))
      states.insert(encodeSymbolRef(ref));
}

static SymbolRefAttr makeNestedRef(MLIRContext *ctx, StringRef encoded) {
  SmallVector<StringRef> parts;
  encoded.split(parts, "::");
  if (parts.size() > 1) {
    SmallVector<FlatSymbolRefAttr> nested;
    for (StringRef part : ArrayRef<StringRef>(parts).drop_front())
      nested.push_back(FlatSymbolRefAttr::get(ctx, part));
    return SymbolRefAttr::get(ctx, parts.front(), nested);
  }
  return SymbolRefAttr::get(ctx, encoded);
}

static ArrayAttr makeSymbolRefArray(Builder &builder,
                                    ArrayRef<std::string> encodedRefs) {
  SmallVector<Attribute> attrs;
  llvm::StringSet<> seen;
  for (StringRef ref : encodedRefs) {
    if (ref.empty() || seen.contains(ref))
      continue;
    seen.insert(ref);
    attrs.push_back(makeNestedRef(builder.getContext(), ref));
  }
  return builder.getArrayAttr(attrs);
}

static PipelineOp findPipeline(ModuleOp module, StringRef name) {
  PipelineOp result;
  module.walk([&](PipelineOp pipeline) {
    if (result)
      return;
    if (getStringAttr(pipeline.getOperation(),
                      SymbolTable::getSymbolAttrName()) == name)
      result = pipeline;
  });
  return result;
}

struct BitstreamSpeculativeFusionPass
    : bitstream::impl::BitstreamSpeculativeFusionBase<
          BitstreamSpeculativeFusionPass> {
  void runOnOperation() override {
    ModuleOp module = getOperation();

    module.walk([&](AnalysisOp analysis) {
      auto source = analysis.getOperation()->getAttrOfType<FlatSymbolRefAttr>(
          "source_pipeline");
      if (!source)
        return;
      std::string pipelineName = source.getValue().str();
      PipelineOp pipeline = findPipeline(module, pipelineName);
      if (!pipeline)
        return;

      SmallVector<Operation *> staleOps;
      analysis.getBody().walk([&](Operation *op) {
        if (isa<FusionCandidateOp, FusedKernelOp>(op))
          staleOps.push_back(op);
      });
      for (Operation *op : staleOps)
        op->erase();

      SmallVector<std::string> stages;
      llvm::StringSet<> seenStages;
      llvm::StringSet<> states;
      llvm::StringMap<int64_t> stateDomains;
      llvm::StringMap<Operation *> pipelineStages;
      llvm::StringMap<Value> pipelineBuffers;
      SmallVector<std::string> illegalReasons;
      bool hasFiniteStateDependency = false;
      bool hasRegexAdvanceState = false;

      auto recordStage = [&](StringRef encodedStage) {
        if (encodedStage.empty() || seenStages.contains(encodedStage))
          return;
        stages.push_back(encodedStage.str());
        seenStages.insert(encodedStage);
      };

      pipeline.getBody().walk([&](Operation *op) {
        if (isa<KernelOp, ScanOp>(op)) {
          StringRef name = getStringAttr(op, SymbolTable::getSymbolAttrName());
          if (!name.empty())
            pipelineStages[name] = op;
          return;
        }
        if (auto buffer = dyn_cast<BufferOp>(op)) {
          StringRef name = getStringAttr(buffer.getOperation(),
                                         SymbolTable::getSymbolAttrName());
          if (!name.empty())
            pipelineBuffers[name] = buffer.getBuffer();
        }
      });

      pipeline.getBody().walk([&](StateOp state) {
        Operation *stageOp = nullptr;
        if (auto kernel = state->getParentOfType<KernelOp>())
          stageOp = kernel.getOperation();
        else if (auto scan = state->getParentOfType<ScanOp>())
          stageOp = scan.getOperation();
        if (!stageOp)
          return;
        StringRef stageName =
            getStringAttr(stageOp, SymbolTable::getSymbolAttrName());
        StringRef name = getStringAttr(state.getOperation(),
                                       SymbolTable::getSymbolAttrName());
        if (stageName.empty() || name.empty())
          return;
        int64_t domain = -1;
        if (auto attr =
                state.getOperation()->getAttrOfType<IntegerAttr>("domain"))
          domain = attr.getInt();
        std::string encodedStage = pipelineName + "::" + stageName.str();
        std::string encodedState = encodedStage + "::" + name.str();
        stateDomains[encodedState] = domain;

        auto transition =
            state.getOperation()->getAttrOfType<StateTransitionKindAttr>(
                "transition");
        if (transition &&
            transition.getValue() == StateTransitionKind::RegexAdvance &&
            domain >= 2) {
          hasRegexAdvanceState = true;
          states.insert(encodedState);
          recordStage(encodedStage);
        }
      });

      analysis.getBody().walk([&](DependencyOp dep) {
        auto producer =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("producer");
        auto consumer =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("consumer");
        auto buffer =
            dep.getOperation()->getAttrOfType<SymbolRefAttr>("buffer");
        ArrayAttr depStates =
            dep.getOperation()->getAttrOfType<ArrayAttr>("states");
        bool hasFiniteByteWindow =
            dep.getOperation()->hasAttr("producer_byte_window");
        std::optional<MemoryDependencyKind> memoryDependency =
            getMemoryDependency(dep);

        if (producer) {
          std::string encodedProducer = encodeSymbolRef(producer);
          recordStage(encodedProducer);
        }
        if (consumer) {
          std::string encodedConsumer = encodeSymbolRef(consumer);
          recordStage(encodedConsumer);
        }

        if (!memoryDependency) {
          illegalReasons.push_back("dependency is missing its memory kind");
          return;
        }

        if (!producer && *memoryDependency != MemoryDependencyKind::Input) {
          illegalReasons.push_back(
              concat("unknown producer for buffer ",
                     buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        // Input edges have no producer stage inside the candidate region.
        if (!producer)
          return;

        if (*memoryDependency != MemoryDependencyKind::RAW) {
          illegalReasons.push_back(
              concat("producer-backed dependency is not RAW for buffer ",
                     buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        if (getStringAttr(dep.getOperation(), "producer_access").empty() ||
            getStringAttr(dep.getOperation(), "consumer_access").empty()) {
          illegalReasons.push_back(concat(
              "dependency is missing its exact access_id link for buffer ",
              buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        if (hasFiniteByteWindow) {
          // A concrete finite producer window is an ordinary fusion edge. It
          // needs neither ProjectState nor a finite-state proof. A proof may be
          // present as analysis information, but does not affect this
          // candidate's states, legality, or strategy.
          return;
        }

        appendStateRefs(depStates, states);

        Operation *producerStage = nullptr;
        Operation *consumerStage = nullptr;
        Value pipelineBuffer;
        auto producerIt = pipelineStages.find(leafSymbolName(producer));
        if (producerIt != pipelineStages.end())
          producerStage = producerIt->second;
        if (consumer) {
          auto consumerIt = pipelineStages.find(leafSymbolName(consumer));
          if (consumerIt != pipelineStages.end())
            consumerStage = consumerIt->second;
        }
        if (buffer) {
          auto bufferIt = pipelineBuffers.find(leafSymbolName(buffer));
          if (bufferIt != pipelineBuffers.end())
            pipelineBuffer = bufferIt->second;
        }
        if (!producerStage || !consumerStage || !pipelineBuffer) {
          illegalReasons.push_back(concat(
              "dependency without a finite byte window does not resolve to "
              "pipeline IR for "
              "buffer ",
              buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        bool producerIsScan = isa<ScanOp>(producerStage);
        ReadOp exactRead = findExactRead(dep, consumerStage, pipelineBuffer);
        WriteOp exactWrite = findExactWrite(dep, producerStage, pipelineBuffer);
        std::optional<ExactProjectedRead> projected =
            findExactProjectedRead(dep, consumerStage, pipelineBuffer);

        RecurrenceOp recurrence =
            exactRead ? findVaryingRecurrence(exactRead) : RecurrenceOp();
        std::optional<int64_t> scanDomain =
            producerIsScan ? getI64Attr(producerStage, "state_domain")
                           : std::nullopt;
        std::optional<int64_t> writeDomain =
            exactWrite ? getI64Attr(exactWrite.getOperation(), "value_domain")
                       : std::nullopt;
        std::optional<int64_t> recurrenceDomain =
            recurrence ? getI64Attr(recurrence.getOperation(), "state_domain")
                       : std::nullopt;

        bool hasFiniteScanOutput = producerIsScan && exactRead && exactWrite &&
                                   scanDomain && *scanDomain > 0 &&
                                   writeDomain && *scanDomain == *writeDomain;
        bool hasFiniteRecurrenceRead = !producerIsScan && exactRead &&
                                       recurrence && recurrenceDomain &&
                                       *recurrenceDomain > 0;
        bool hasExactProjection =
            projected && (producerIsScan ||
                          isNestedUnderWhile(projected->read, consumerStage));

        if (!exactRead || (!hasFiniteScanOutput && !hasFiniteRecurrenceRead &&
                           !hasExactProjection)) {
          illegalReasons.push_back(concat(
              producerIsScan
                  ? StringRef("scan dependency has neither exact finite scan "
                              "output evidence nor an access-linked "
                              "ProjectState proof for buffer ")
                  : (recurrence
                         ? StringRef("recurrence dependency has no finite "
                                     "recovered state domain for buffer ")
                         : StringRef("predecessor dependency has no exact "
                                     "while-read ProjectState proof for "
                                     "buffer ")),
              buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        auto readDependency =
            exactRead.getOperation()->getAttrOfType<ReadDependencyKindAttr>(
                "dependency");
        ReadDependencyKind expectedDependency =
            (producerIsScan || hasFiniteRecurrenceRead)
                ? ReadDependencyKind::PrefixState
                : ReadDependencyKind::DataDependentPredecessor;
        if (!readDependency ||
            readDependency.getValue() != expectedDependency) {
          illegalReasons.push_back(concat(
              (producerIsScan || hasFiniteRecurrenceRead)
                  ? StringRef("scan/recurrence read lacks its inferred "
                              "prefix-state proof for buffer ")
                  : StringRef(
                        "predecessor read lacks its inferred finite-state "
                        "proof for buffer "),
              buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        auto stateUse =
            exactRead.getOperation()->getAttrOfType<StateUseKindAttr>(
                "state_kind");
        StateUseKind expectedStateUse =
            (hasFiniteScanOutput || hasFiniteRecurrenceRead)
                ? StateUseKind::CarriedState
                : (producerIsScan ? StateUseKind::FiniteStateProjection
                                  : StateUseKind::NeighborFiniteState);
        if (!stateUse || stateUse.getValue() != expectedStateUse) {
          illegalReasons.push_back(concat(
              (hasFiniteScanOutput || hasFiniteRecurrenceRead)
                  ? StringRef("structural scan/recurrence read is not marked "
                              "as carried state for buffer ")
                  : StringRef("projected finite-state read has inconsistent "
                              "state use for buffer "),
              buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        auto finiteState =
            dep.getOperation()->getAttrOfType<FiniteStateProofKindAttr>(
                "finite_state");
        if (!finiteState ||
            finiteState.getValue() != FiniteStateProofKind::Proven ||
            !depStates || depStates.empty()) {
          illegalReasons.push_back(
              concat("dependency without a finite byte window has no exact "
                     "finite-state proof for "
                     "buffer ",
                     buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
          return;
        }

        {
          hasFiniteStateDependency = true;
          std::optional<int64_t> provenDomain =
              getI64Attr(dep.getOperation(), "finite_state_domain");
          if (!provenDomain) {
            illegalReasons.push_back(concat(
                "finite-state dependency has no proven domain for buffer ",
                buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
            return;
          }
          if (hasFiniteScanOutput) {
            if (*scanDomain != *provenDomain || *writeDomain != *provenDomain) {
              illegalReasons.push_back(concat(
                  "scan state and exact producer value domains do not match "
                  "the dependency proof for buffer ",
                  buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
              return;
            }
          } else if (hasFiniteRecurrenceRead) {
            if (*recurrenceDomain != *provenDomain) {
              illegalReasons.push_back(concat(
                  "recurrence state domain does not match the dependency "
                  "proof for buffer ",
                  buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
              return;
            }
          } else {
            auto projectedDomain = projected->projection.getOperation()
                                       ->getAttrOfType<IntegerAttr>("domain");
            if (!projectedDomain || projectedDomain.getInt() != *provenDomain) {
              illegalReasons.push_back(concat(
                  "dependency state domain does not match its exact "
                  "ProjectState proof for buffer ",
                  buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
              return;
            }
          }
          if (*provenDomain < kMinimumRuntimeStateDomain ||
              (producerIsScan && *provenDomain != kBinaryScanStateDomain) ||
              (!producerIsScan && *provenDomain > kMaxProjectedStateDomain)) {
            illegalReasons.push_back(concat(
                producerIsScan
                    ? StringRef("scan dependency is not proven binary for "
                                "buffer ")
                    : StringRef("finite-state dependency exceeds template "
                                "domain for buffer "),
                buffer ? leafSymbolName(buffer) : StringRef("<unknown>")));
            return;
          }
          if (!depStates || depStates.empty()) {
            illegalReasons.push_back(
                "dependency without a finite byte window requires an explicit "
                "bitstream.state");
          } else {
            for (Attribute attr : depStates) {
              auto ref = dyn_cast<SymbolRefAttr>(attr);
              if (!ref) {
                illegalReasons.push_back(
                    "dependency state reference is invalid");
                continue;
              }
              std::string stateName = encodeSymbolRef(ref);
              auto domainIt = stateDomains.find(stateName);
              if (domainIt == stateDomains.end() ||
                  domainIt->second < kMinimumRuntimeStateDomain) {
                illegalReasons.push_back(
                    concat("state ", stateName, " has no finite domain"));
              } else if (producerIsScan &&
                         domainIt->second != kBinaryScanStateDomain) {
                illegalReasons.push_back(
                    concat("state ", stateName,
                           " is not binary for the scan finite-state proof"));
              } else if (domainIt->second != *provenDomain) {
                illegalReasons.push_back(
                    concat("state ", stateName,
                           " does not match the dependency proof domain"));
              } else if (!producerIsScan &&
                         domainIt->second > kMaxProjectedStateDomain) {
                illegalReasons.push_back(
                    concat("state ", stateName,
                           " exceeds finite-state template domain"));
              }
            }
          }
        }
      });

      SmallVector<std::string> stateNames;
      for (const auto &entry : states)
        stateNames.push_back(entry.getKey().str());

      bool legal = illegalReasons.empty();
      std::string reason =
          legal ? (hasRegexAdvanceState && !hasFiniteStateDependency
                       ? "all producer dependencies have finite byte windows; "
                         "regex advance has a finite-state proof"
                       : (hasFiniteStateDependency
                              ? "every dependency without a finite byte window "
                                "has an exact finite-state proof; remaining "
                                "dependencies have finite byte windows"
                              : "all producer dependencies have finite byte "
                                "windows; no finite-state proof is "
                                "required"))
                : joinStrings(illegalReasons, "; ");

      OpBuilder builder(pipeline.getContext());
      builder.setInsertionPointToEnd(&analysis.getBody().front());
      if (!analysis.getBody().front().empty() &&
          isa<YieldOp>(&analysis.getBody().front().back()))
        builder.setInsertionPoint(&analysis.getBody().front().back());

      auto str = [&](StringRef value) { return builder.getStringAttr(value); };
      std::string candidateName = pipelineName + "_speculative_fusion";
      SmallVector<std::string> stageRefs;
      for (StringRef stage : stages)
        stageRefs.push_back(stage.str());

      builder.create<FusionCandidateOp>(analysis.getLoc(), str(candidateName),
                                        makeSymbolRefArray(builder, stageRefs),
                                        makeSymbolRefArray(builder, stateNames),
                                        builder.getBoolAttr(legal),
                                        str(reason));

      if (legal) {
        FusionStrategyKind selectedStrategy = FusionStrategyKind::Elementwise;
        if (hasFiniteStateDependency)
          selectedStrategy = FusionStrategyKind::DecoupledLookback;
        else if (hasRegexAdvanceState)
          selectedStrategy = FusionStrategyKind::RegexAdvanceSpeculation;
        builder.create<FusedKernelOp>(
            analysis.getLoc(), builder.getStringAttr(candidateName + "_kernel"),
            FlatSymbolRefAttr::get(builder.getContext(), pipelineName),
            makeSymbolRefArray(builder, stageRefs),
            makeSymbolRefArray(builder, stateNames),
            FusionStrategyKindAttr::get(builder.getContext(),
                                        selectedStrategy));
      }
    });
  }
};

} // namespace

std::unique_ptr<Pass> bitstream::createBitstreamSpeculativeFusionPass() {
  return std::make_unique<BitstreamSpeculativeFusionPass>();
}
