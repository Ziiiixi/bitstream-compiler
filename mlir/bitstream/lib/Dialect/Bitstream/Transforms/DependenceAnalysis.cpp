#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamPasses.h"

#include "mlir/Dialect/Affine/IR/AffineOps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/GPU/IR/GPUDialect.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/StringSet.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/raw_ostream.h"

#include <memory>
#include <optional>
#include <string>
#include <utility>

namespace bitstream {
#define GEN_PASS_DEF_BITSTREAMDEPENDENCEANALYSIS
#include "Bitstream/BitstreamPasses.h.inc"
} // namespace bitstream

using namespace mlir;
using namespace bitstream;

namespace {

struct Producer {
  std::string stage;
  std::string accessId;
  Value index;
  Operation *accessOp = nullptr;
  bool isScan = false;
};

struct BufferInfo {
  std::string name;
};

struct PendingEdge {
  std::optional<std::string> producer;
  std::string consumer;
  std::string buffer;
  std::string producerAccessId;
  std::string consumerAccessId;
  std::optional<AffineMap> producerByteWindow;
  MemoryDependencyKind memoryDependency = MemoryDependencyKind::Input;
};

static StringRef getStringAttr(Operation *op, StringRef name,
                               StringRef fallback = "") {
  if (auto attr = op->getAttrOfType<StringAttr>(name))
    return attr.getValue();
  return fallback;
}

static std::optional<int64_t> getI64Attr(Operation *op, StringRef name) {
  if (auto attr = op->getAttrOfType<IntegerAttr>(name))
    return attr.getInt();
  return std::nullopt;
}

static int64_t getAccessBytes(Operation *op) {
  return getI64Attr(op, "bytes").value_or(0);
}

static bool dependsOnWhileCarriedIndex(Value index) {
  SmallVector<Value, 8> worklist;
  llvm::SmallPtrSet<Value, 16> seen;
  if (index)
    worklist.push_back(index);
  while (!worklist.empty()) {
    Value value = worklist.pop_back_val();
    if (!value || !seen.insert(value).second)
      continue;
    if (auto arg = dyn_cast<BlockArgument>(value)) {
      if (isa_and_nonnull<scf::WhileOp>(arg.getOwner()->getParentOp()))
        return true;
      continue;
    }
    Operation *def = value.getDefiningOp();
    if (!def)
      continue;
    worklist.append(def->operand_begin(), def->operand_end());
  }
  return false;
}

static std::string getStageName(Operation *op) {
  if (isa<KernelOp, ScanOp>(op))
    return getStringAttr(op, SymbolTable::getSymbolAttrName()).str();
  return "";
}

static bool isStage(Operation *op) { return isa<KernelOp, ScanOp>(op); }

static SymbolRefAttr makeNestedRef(MLIRContext *ctx, StringRef root,
                                   StringRef nested) {
  return SymbolRefAttr::get(ctx, root, {FlatSymbolRefAttr::get(ctx, nested)});
}

static AnalysisOp createAnalysisContainer(OpBuilder &builder, Location loc,
                                          StringRef pipelineName) {
  OperationState state(loc, AnalysisOp::getOperationName());
  std::string analysisName = (pipelineName + "_analysis").str();
  state.addAttribute(SymbolTable::getSymbolAttrName(),
                     builder.getStringAttr(analysisName));
  state.addAttribute(
      "source_pipeline",
      FlatSymbolRefAttr::get(builder.getContext(), pipelineName));
  Region *region = state.addRegion();
  region->push_back(new Block());
  auto analysis = cast<AnalysisOp>(builder.create(state));
  OpBuilder::atBlockEnd(&analysis.getBody().front()).create<YieldOp>(loc);
  return analysis;
}

static bool analysisForPipeline(AnalysisOp analysis, StringRef pipelineName) {
  auto source = analysis.getOperation()->getAttrOfType<FlatSymbolRefAttr>(
      "source_pipeline");
  return source && source.getValue() == pipelineName;
}

struct CanonicalIndex {
  bool valid = false;
  bool varying = false;
  std::string expression;
  std::optional<int64_t> constant;
};

static CanonicalIndex constantExpression(int64_t value) {
  return CanonicalIndex{true, false, "const(" + std::to_string(value) + ")",
                        value};
}

static CanonicalIndex namedExpression(StringRef name, bool varying) {
  return CanonicalIndex{true, varying, name.str(), std::nullopt};
}

static CanonicalIndex makeBinaryExpression(StringRef name, CanonicalIndex lhs,
                                           CanonicalIndex rhs,
                                           bool commutative) {
  if (!lhs.valid || !rhs.valid)
    return {};
  if (commutative && rhs.expression < lhs.expression)
    std::swap(lhs, rhs);
  return CanonicalIndex{true, lhs.varying || rhs.varying,
                        name.str() + "(" + lhs.expression + "," +
                            rhs.expression + ")",
                        std::nullopt};
}

static CanonicalIndex makeAddExpression(CanonicalIndex lhs,
                                        CanonicalIndex rhs) {
  if (lhs.constant == 0)
    return rhs;
  if (rhs.constant == 0)
    return lhs;
  return makeBinaryExpression("add", std::move(lhs), std::move(rhs), true);
}

static CanonicalIndex makeSubExpression(CanonicalIndex lhs,
                                        CanonicalIndex rhs) {
  if (rhs.constant == 0)
    return lhs;
  return makeBinaryExpression("sub", std::move(lhs), std::move(rhs), false);
}

static CanonicalIndex makeMulExpression(CanonicalIndex lhs,
                                        CanonicalIndex rhs) {
  if (!lhs.valid || !rhs.valid || (lhs.varying && rhs.varying))
    return {};
  if (lhs.constant == 0 || rhs.constant == 0)
    return constantExpression(0);
  if (lhs.constant == 1)
    return rhs;
  if (rhs.constant == 1)
    return lhs;
  return makeBinaryExpression("mul", std::move(lhs), std::move(rhs), true);
}

static std::optional<int64_t> constantInteger(Value value) {
  Operation *def = value ? value.getDefiningOp() : nullptr;
  if (!def || def->getName().getStringRef() != "arith.constant")
    return std::nullopt;
  if (auto attr = def->getAttrOfType<IntegerAttr>("value"))
    return attr.getInt();
  return std::nullopt;
}

static std::string attributeKey(Operation *op) {
  std::string result;
  llvm::raw_string_ostream os(result);
  op->getAttrDictionary().print(os);
  return os.str();
}

static CanonicalIndex canonicalizeIndex(Value value, unsigned depth = 0) {
  if (!value || depth > 32 || dependsOnWhileCarriedIndex(value))
    return {};

  if (auto constant = constantInteger(value))
    return constantExpression(*constant);
  if (value.getDefiningOp<LogicalIndexOp>())
    return namedExpression("coordinate(logical)", true);
  if (auto parameter = value.getDefiningOp<ParameterOp>()) {
    auto sourceArg =
        parameter.getOperation()->getAttrOfType<IntegerAttr>("source_arg");
    if (!sourceArg)
      return {};
    return namedExpression(
        "invariant(parameter:" + std::to_string(sourceArg.getInt()) + ")",
        false);
  }

  Operation *def = value.getDefiningOp();
  if (!def)
    return {};
  StringRef opName = def->getName().getStringRef();
  auto gpuLeaf = [&](bool varying) {
    return namedExpression(opName.str() + attributeKey(def), varying);
  };
  if (opName == "gpu.thread_id" || opName == "gpu.block_id" ||
      opName == "gpu.lane_id" || opName == "gpu.subgroup_id")
    return gpuLeaf(true);
  if (opName == "gpu.block_dim" || opName == "gpu.grid_dim" ||
      opName == "gpu.subgroup_size")
    return gpuLeaf(false);

  if (def->getNumOperands() == 2 &&
      (opName == "arith.addi" || opName == "arith.subi" ||
       opName == "arith.muli")) {
    CanonicalIndex lhs = canonicalizeIndex(def->getOperand(0), depth + 1);
    CanonicalIndex rhs = canonicalizeIndex(def->getOperand(1), depth + 1);
    if (opName == "arith.addi")
      return makeAddExpression(std::move(lhs), std::move(rhs));
    if (opName == "arith.subi")
      return makeSubExpression(std::move(lhs), std::move(rhs));
    return makeMulExpression(std::move(lhs), std::move(rhs));
  }

  bool divisionOrRemainder =
      opName == "arith.divsi" || opName == "arith.divui" ||
      opName == "arith.floordivsi" || opName == "arith.ceildivsi" ||
      opName == "arith.ceildivui" || opName == "arith.remsi" ||
      opName == "arith.remui";
  if (divisionOrRemainder && def->getNumOperands() == 2) {
    CanonicalIndex lhs = canonicalizeIndex(def->getOperand(0), depth + 1);
    CanonicalIndex rhs = canonicalizeIndex(def->getOperand(1), depth + 1);
    if (!lhs.valid || !rhs.valid || rhs.varying)
      return {};
    if (lhs.varying && (!rhs.constant || *rhs.constant <= 0))
      return {};
    return makeBinaryExpression(opName, std::move(lhs), std::move(rhs), false);
  }

  bool affineCast = opName == "arith.index_cast" ||
                    opName == "arith.index_castui" || opName == "arith.extsi" ||
                    opName == "arith.extui" || opName == "arith.trunci";
  if (affineCast && def->getNumOperands() == 1) {
    CanonicalIndex operand = canonicalizeIndex(def->getOperand(0), depth + 1);
    if (!operand.valid)
      return {};
    operand.expression = opName.str() + "(" + operand.expression + ")";
    return operand;
  }

  // Runtime-invariant arithmetic can be used freely as a coefficient or
  // offset. Unknown operations that depend on a varying coordinate are not a
  // proved affine address.
  if (opName.starts_with("arith.")) {
    SmallVector<CanonicalIndex, 4> operands;
    for (Value operand : def->getOperands()) {
      CanonicalIndex canonical = canonicalizeIndex(operand, depth + 1);
      if (!canonical.valid || canonical.varying)
        return {};
      operands.push_back(std::move(canonical));
    }
    std::string expression = opName.str() + attributeKey(def) + "(";
    for (auto [index, operand] : llvm::enumerate(operands)) {
      if (index)
        expression += ",";
      expression += operand.expression;
    }
    expression += ")";
    return CanonicalIndex{true, false, std::move(expression), std::nullopt};
  }

  return {};
}

static CanonicalIndex composeAffineExpr(AffineExpr expr,
                                        const CanonicalIndex &dimension) {
  if (auto dim = expr.dyn_cast<AffineDimExpr>()) {
    if (dim.getPosition() != 0)
      return {};
    return dimension;
  }
  if (auto constant = expr.dyn_cast<AffineConstantExpr>())
    return constantExpression(constant.getValue());

  auto binary = expr.dyn_cast<AffineBinaryOpExpr>();
  if (!binary)
    return {};
  CanonicalIndex lhs = composeAffineExpr(binary.getLHS(), dimension);
  CanonicalIndex rhs = composeAffineExpr(binary.getRHS(), dimension);
  switch (expr.getKind()) {
  case AffineExprKind::Add:
    return makeAddExpression(std::move(lhs), std::move(rhs));
  case AffineExprKind::Mul:
    return makeMulExpression(std::move(lhs), std::move(rhs));
  case AffineExprKind::FloorDiv:
  case AffineExprKind::CeilDiv:
  case AffineExprKind::Mod: {
    auto divisor = binary.getRHS().dyn_cast<AffineConstantExpr>();
    if (!lhs.valid || !divisor || divisor.getValue() <= 0)
      return {};
    StringRef name =
        expr.getKind() == AffineExprKind::FloorDiv  ? "affine.floordiv"
        : expr.getKind() == AffineExprKind::CeilDiv ? "affine.ceildiv"
                                                    : "affine.mod";
    return makeBinaryExpression(name, std::move(lhs), std::move(rhs), false);
  }
  default:
    return {};
  }
}

static CanonicalIndex canonicalByteAddress(Operation *accessOp, Value index) {
  if (!accessOp)
    return {};
  CanonicalIndex address = canonicalizeIndex(index);
  if (!address.valid)
    return {};

  if (auto mapAttr = accessOp->getAttrOfType<AffineMapAttr>("byte_index")) {
    AffineMap map = mapAttr.getValue();
    if (map.getNumDims() != 1 || map.getNumSymbols() != 0 ||
        map.getNumResults() != 1)
      return {};
    return composeAffineExpr(map.getResult(0), address);
  }

  int64_t bytes = getAccessBytes(accessOp);
  if (bytes <= 0)
    return {};
  return makeMulExpression(std::move(address), constantExpression(bytes));
}

static std::optional<AffineMap> deriveProducerByteWindow(ReadOp read) {
  int64_t bytes = getAccessBytes(read.getOperation());
  if (bytes <= 0)
    return std::nullopt;

  MLIRContext *context = read.getContext();
  AffineExpr start;
  if (auto byteIndex =
          read.getOperation()->getAttrOfType<AffineMapAttr>("byte_index")) {
    AffineMap map = byteIndex.getValue();
    if (map.getNumDims() != 1 || map.getNumSymbols() != 0 ||
        map.getNumResults() != 1)
      return std::nullopt;
    start = map.getResult(0);
  } else {
    start = getAffineDimExpr(0, context) * bytes;
  }

  AffineExpr end = start + getAffineConstantExpr(bytes, context);
  SmallVector<AffineExpr, 2> interval{start, end};
  return AffineMap::get(/*dimCount=*/1, /*symbolCount=*/0, interval, context);
}

static bool isEnclosedInWhile(ReadOp read) {
  return static_cast<bool>(
      read.getOperation()->getParentOfType<scf::WhileOp>());
}

static bool deriveDependencyWindow(PendingEdge &edge, ReadOp read,
                                   bool producerIsInput,
                                   const Producer *producer) {
  // Decide whether this read is an external input or a read-after-write edge.
  edge.memoryDependency =
      producerIsInput ? MemoryDependencyKind::Input : MemoryDependencyKind::RAW;

  // A dynamically repeated read and a scan-produced value have no finite
  // producer window for one consumer coordinate, regardless of whether the
  // individual address expression is affine.  A local recurrence is treated
  // this way only when the read index actually varies with its recovered
  // logical recurrence coordinate; captured invariant accesses stay bounded.
  if ((!producerIsInput && producer && producer->isScan) ||
      isEnclosedInWhile(read) || findVaryingRecurrence(read)) {
    edge.producerByteWindow.reset();
    return true;
  }

  int64_t consumerBytes = getAccessBytes(read.getOperation());
  if (consumerBytes <= 0)
    return false;

  if (producerIsInput) {
    // External input supplies exactly the finite half-open byte interval read
    // by this access.
    CanonicalIndex consumerAccess =
        canonicalByteAddress(read.getOperation(), read.getIndex());
    if (!consumerAccess.valid)
      return false;
    edge.producerByteWindow = deriveProducerByteWindow(read);
    return edge.producerByteWindow.has_value();
  }

  CanonicalIndex consumerAccess =
      canonicalByteAddress(read.getOperation(), read.getIndex());
  if (!consumerAccess.valid)
    return false;

  if (!producer || !producer->accessOp)
    return false;
  int64_t producerBytes = getAccessBytes(producer->accessOp);
  if (producerBytes <= 0)
    return false;
  CanonicalIndex producerAccess =
      canonicalByteAddress(producer->accessOp, producer->index);
  if (!producerAccess.valid)
    return false;

  (void)producerBytes;
  edge.producerByteWindow = deriveProducerByteWindow(read);
  return edge.producerByteWindow.has_value();
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

static Operation *findEnclosingStage(Operation *op) {
  for (Operation *parent = op->getParentOp(); parent;
       parent = parent->getParentOp())
    if (isa<KernelOp, ScanOp>(parent))
      return parent;
  return nullptr;
}

static void assignAccessIds(PipelineOp pipeline) {
  SmallVector<Operation *, 16> accesses;
  llvm::StringMap<unsigned> idCounts;
  pipeline.getBody().walk([&](Operation *op) {
    if (!isa<ReadOp, WriteOp>(op))
      return;
    accesses.push_back(op);
    if (auto id = op->getAttrOfType<StringAttr>("access_id");
        id && !id.getValue().empty())
      ++idCounts[id.getValue()];
  });

  // Resolve projections before changing any IDs. Buffer and exact structural
  // index identity make a duplicate textual ID unambiguous whenever the input
  // satisfies ProjectStateOp's verifier.
  SmallVector<std::pair<ProjectStateOp, ReadOp>, 8> projectedReads;
  pipeline.getBody().walk([&](ProjectStateOp projection) {
    auto referencedId =
        projection.getOperation()->getAttrOfType<StringAttr>("read_access");
    Operation *stage = findEnclosingStage(projection.getOperation());
    if (!referencedId || referencedId.getValue().empty() || !stage)
      return;

    SmallVector<ReadOp, 2> matches;
    stage->walk([&](ReadOp read) {
      auto candidateId =
          read.getOperation()->getAttrOfType<StringAttr>("access_id");
      if (candidateId && candidateId.getValue() == referencedId.getValue() &&
          read.getBuffer() == projection.getBuffer() &&
          sameIndexValue(read.getIndex(), projection.getIndex()))
        matches.push_back(read);
    });
    if (matches.size() == 1)
      projectedReads.emplace_back(projection, matches.front());
  });

  llvm::StringSet<> usedIds;
  for (Operation *access : accesses) {
    auto id = access->getAttrOfType<StringAttr>("access_id");
    if (id && !id.getValue().empty() && idCounts[id.getValue()] == 1)
      usedIds.insert(id.getValue());
  }

  int64_t ordinal = 0;
  auto nextId = [&]() {
    std::string id;
    do {
      id = "a" + std::to_string(ordinal++);
    } while (usedIds.contains(id));
    usedIds.insert(id);
    return id;
  };

  for (Operation *access : accesses) {
    auto id = access->getAttrOfType<StringAttr>("access_id");
    if (id && !id.getValue().empty() && idCounts[id.getValue()] == 1)
      continue;
    access->setAttr("access_id",
                    StringAttr::get(access->getContext(), nextId()));
  }

  // A projection names the real read operation, so keep that reference stable
  // when a missing or duplicate access ID had to be repaired.
  for (auto [projection, read] : projectedReads) {
    auto id = read.getOperation()->getAttrOfType<StringAttr>("access_id");
    if (id)
      projection.getOperation()->setAttr("read_access", id);
  }
}

static std::string accessId(Operation *op) {
  return getStringAttr(op, "access_id").str();
}

struct BitstreamDependenceAnalysisPass
    : bitstream::impl::BitstreamDependenceAnalysisBase<
          BitstreamDependenceAnalysisPass> {
  void runOnOperation() override {
    ModuleOp module = getOperation();

    // Step 1: analyze each recovered bitstream.pipeline independently.
    module.walk([&](PipelineOp pipeline) {
      // Remove a previous result for this pipeline so the pass can be re-run.
      SmallVector<Operation *> staleOps;
      std::string pipelineName = getStringAttr(pipeline.getOperation(),
                                               SymbolTable::getSymbolAttrName())
                                     .str();
      module.walk([&](AnalysisOp analysis) {
        if (analysisForPipeline(analysis, pipelineName))
          staleOps.push_back(analysis.getOperation());
      });
      for (Operation *op : staleOps)
        op->erase();

      // Step 2: map each buffer SSA value to its pipeline-level buffer name.
      llvm::DenseMap<Value, BufferInfo> buffers;
      pipeline.getBody().walk([&](BufferOp buffer) {
        BufferInfo info;
        info.name = getStringAttr(buffer.getOperation(),
                                  SymbolTable::getSymbolAttrName())
                        .str();
        buffers[buffer.getBuffer()] = std::move(info);
      });

      // Step 3: give every real read/write a stable ID used by dependency
      // edges. Keep already-unique IDs stable and repair only missing or
      // duplicate IDs.
      assignAccessIds(pipeline);

      // `producers` stores the latest preceding writer for each buffer name.
      // `edges` accumulates dependencies until the final AnalysisOp is emitted.
      llvm::StringMap<Producer> producers;
      SmallVector<PendingEdge, 8> edges;
      bool relationFailure = false;

      // Step 4: visit kernel/scan stages in pipeline launch order.
      for (Operation &stage : pipeline.getBody().front()) {
        if (!isStage(&stage))
          continue;

        std::string consumer = getStageName(&stage);
        // Step 5: for each read, connect it to the latest preceding writer of
        // the same buffer, or mark it as an external input if none exists.
        stage.walk([&](ReadOp read) {
          auto it = buffers.find(read.getBuffer());
          if (it == buffers.end()) {
            read.emitWarning() << "read uses an unknown bitstream buffer";
            return;
          }

          const BufferInfo &bufferInfo = it->second;
          auto producerIt = producers.find(bufferInfo.name);
          // A source buffer is not labeled ahead of time. It is inferred
          // structurally: if this pipeline reads a buffer before any previous
          // stage writes it, that read consumes an external input.
          bool producerIsInput = producerIt == producers.end();

          PendingEdge edge;
          if (!producerIsInput) {
            edge.producer = producerIt->second.stage;
            edge.producerAccessId = producerIt->second.accessId;
          }
          edge.consumer = consumer;
          edge.buffer = bufferInfo.name;
          edge.consumerAccessId = accessId(read.getOperation());
          // Attach a finite producer byte window when structurally provable;
          // scan-produced values and reads inside scf.while have no such
          // window.
          if (!deriveDependencyWindow(edge, read, producerIsInput,
                                      producerIsInput ? nullptr
                                                      : &producerIt->second)) {
            read.emitError()
                << "cannot derive a finite byte window or structural "
                   "unboundedness for this access: expected "
                   "a positive `bytes` and a structurally affine byte address "
                   "(including invariant coefficients), a read enclosed in "
                   "scf.while, a recurrence-varying read, or a RAW edge "
                   "produced by bitstream.scan";
            relationFailure = true;
            return;
          }
          edges.push_back(std::move(edge));
        });

        // Step 6: process writes after reads, then make them the latest
        // producers seen by later stages. This also handles in-place stages
        // correctly. Select within the current stage first: prefer its
        // steady-state write over a final boundary flush, but use the boundary
        // write when it is the only write this stage performs.
        llvm::StringMap<Producer> stageProducers;
        llvm::StringMap<Producer> boundaryProducers;
        stage.walk([&](WriteOp write) {
          auto it = buffers.find(write.getBuffer());
          if (it == buffers.end()) {
            write.emitWarning() << "write uses an unknown bitstream buffer";
            return;
          }
          Producer producer{consumer, accessId(write.getOperation()),
                            write.getIndex(), write.getOperation(),
                            isa<ScanOp>(&stage)};
          if (write.getOperation()->hasAttr("tail_boundary_write"))
            boundaryProducers[it->second.name] = std::move(producer);
          else
            stageProducers[it->second.name] = std::move(producer);
        });
        for (auto &entry : boundaryProducers)
          if (!stageProducers.count(entry.getKey()))
            stageProducers[entry.getKey()] = std::move(entry.getValue());
        for (auto &entry : stageProducers)
          producers[entry.getKey()] = std::move(entry.getValue());
      }

      if (relationFailure) {
        signalPassFailure();
        return;
      }

      // Step 7: materialize the accumulated edges as bitstream.dependency ops
      // in a new bitstream.analysis container placed after the source pipeline.
      OpBuilder builder(pipeline.getContext());
      builder.setInsertionPointAfter(pipeline);
      AnalysisOp analysis =
          createAnalysisContainer(builder, pipeline.getLoc(), pipelineName);
      builder.setInsertionPointToEnd(&analysis.getBody().front());
      if (!analysis.getBody().front().empty() &&
          isa<YieldOp>(&analysis.getBody().front().back()))
        builder.setInsertionPoint(&analysis.getBody().front().back());

      for (const PendingEdge &edge : edges) {
        auto memoryAttr = MemoryDependencyKindAttr::get(builder.getContext(),
                                                        edge.memoryDependency);
        OperationState state(pipeline.getLoc(),
                             DependencyOp::getOperationName());
        if (edge.producer)
          state.addAttribute("producer",
                             makeNestedRef(builder.getContext(), pipelineName,
                                           *edge.producer));
        state.addAttribute(
            "consumer",
            makeNestedRef(builder.getContext(), pipelineName, edge.consumer));
        state.addAttribute("buffer", makeNestedRef(builder.getContext(),
                                                   pipelineName, edge.buffer));
        if (!edge.producerAccessId.empty())
          state.addAttribute("producer_access",
                             builder.getStringAttr(edge.producerAccessId));
        if (edge.consumerAccessId.empty()) {
          pipeline.emitError() << "dependency consumer has no access_id";
          signalPassFailure();
          return;
        }
        state.addAttribute("consumer_access",
                           builder.getStringAttr(edge.consumerAccessId));
        if (edge.producerByteWindow)
          state.addAttribute("producer_byte_window",
                             AffineMapAttr::get(*edge.producerByteWindow));
        state.addAttribute("finite_state", FiniteStateProofKindAttr::get(
                                               builder.getContext(),
                                               FiniteStateProofKind::None));
        state.addAttribute("memory_dependency", memoryAttr);
        builder.create(state);
      }
    });
  }
};

} // namespace

std::unique_ptr<Pass> bitstream::createBitstreamDependenceAnalysisPass() {
  return std::make_unique<BitstreamDependenceAnalysisPass>();
}
