#include "Bitstream/BitstreamOps.h"

#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/AffineMap.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/SymbolTable.h"
#include "llvm/ADT/STLExtras.h"

#include "Bitstream/BitstreamOpsEnums.cpp.inc"

using namespace mlir;
using namespace bitstream;

static Operation *lookupSymbolRef(Operation *from, SymbolRefAttr ref) {
  if (Operation *target = SymbolTable::lookupNearestSymbolFrom(from, ref))
    return target;

  // Analysis ops are often emitted as sibling IR to the pipeline they describe,
  // so their references may need to be resolved from an enclosing module rather
  // than the nearest nested symbol table.
  for (Operation *scope = from->getParentOp(); scope;
       scope = scope->getParentOp()) {
    if (!scope->hasTrait<OpTrait::SymbolTable>())
      continue;
    if (Operation *target = SymbolTable::lookupSymbolIn(scope, ref))
      return target;
  }
  return nullptr;
}

template <typename... ExpectedOps>
static LogicalResult verifySymbolRef(Operation *from, SymbolRefAttr ref,
                                     StringRef attrName,
                                     StringRef expectedName) {
  if (!ref)
    return from->emitOpError()
           << "requires `" << attrName << "` symbol reference";
  Operation *target = lookupSymbolRef(from, ref);
  if (!target)
    return from->emitOpError()
           << "has unresolved `" << attrName << "` symbol reference " << ref;
  if (!isa<ExpectedOps...>(target))
    return from->emitOpError() << "`" << attrName << "` must reference "
                               << expectedName << ", got " << target->getName();
  return success();
}

template <typename... ExpectedOps>
static LogicalResult verifySymbolRefArray(Operation *from, ArrayAttr refs,
                                          StringRef attrName,
                                          StringRef expectedName) {
  if (!refs)
    return success();
  for (Attribute attr : refs) {
    auto ref = dyn_cast<SymbolRefAttr>(attr);
    if (!ref)
      return from->emitOpError()
             << "`" << attrName << "` must contain symbol references";
    if (failed(
            verifySymbolRef<ExpectedOps...>(from, ref, attrName, expectedName)))
      return failure();
  }
  return success();
}

LogicalResult StateOp::verify() {
  auto transition =
      (*this)->getAttrOfType<StateTransitionKindAttr>("transition");
  if (!transition)
    return success();

  switch (transition.getValue()) {
  case StateTransitionKind::NeighborFiniteState:
    if (!(*this)->getAttrOfType<IntegerAttr>("distance"))
      return emitOpError()
             << "with neighbor_finite_state transition requires integer "
                "`distance` attribute";
    break;
  case StateTransitionKind::AddMod:
    if (!(*this)->getAttrOfType<IntegerAttr>("modulus"))
      return emitOpError()
             << "with add_mod transition requires integer `modulus` attribute";
    break;
  case StateTransitionKind::RegexAdvance:
    if (!(*this)->getAttrOfType<IntegerAttr>("distance"))
      return emitOpError()
             << "with regex_advance transition requires integer `distance` "
                "attribute";
    if (!(*this)->getAttrOfType<IntegerAttr>("domain"))
      return emitOpError()
             << "with regex_advance transition requires integer `domain` "
                "attribute";
    break;
  case StateTransitionKind::PrefixStateProjection:
  case StateTransitionKind::Xor:
  case StateTransitionKind::ProjectedState:
    break;
  }

  return success();
}

LogicalResult ParameterOp::verify() {
  auto sourceArg = (*this)->getAttrOfType<IntegerAttr>("source_arg");
  if (!sourceArg || sourceArg.getInt() < 0)
    return emitOpError() << "requires a non-negative `source_arg` ordinal";
  if (!(*this)->getParentOfType<PipelineOp>())
    return emitOpError() << "must be nested in a bitstream.pipeline";
  return success();
}

static LogicalResult verifyByteIndexMap(Operation *op) {
  auto map = op->getAttrOfType<AffineMapAttr>("byte_index");
  if (!map)
    return success();
  if (map.getValue().getNumDims() != 1 || map.getValue().getNumSymbols() != 0 ||
      map.getValue().getNumResults() != 1)
    return op->emitOpError()
           << "`byte_index` must be a one-dimensional affine map from the "
              "operation index to its byte offset";
  return success();
}

static LogicalResult verifyAccessId(Operation *op) {
  auto id = op->getAttrOfType<StringAttr>("access_id");
  if (id && id.getValue().empty())
    return op->emitOpError() << "`access_id` must be non-empty when present";
  return success();
}

LogicalResult ReadOp::verify() {
  if (failed(verifyByteIndexMap(getOperation())) ||
      failed(verifyAccessId(getOperation())))
    return failure();
  auto dependency =
      (*this)->getAttrOfType<ReadDependencyKindAttr>("dependency");
  if (!dependency)
    return success();

  switch (dependency.getValue()) {
  case ReadDependencyKind::DataDependentPredecessor:
  case ReadDependencyKind::PrefixState:
  case ReadDependencyKind::ProjectedState:
    if (!(*this)->getAttrOfType<SymbolRefAttr>("state"))
      return emitOpError()
             << "with finite-state dependency requires symbol `state` "
                "attribute";
    if (!(*this)->getAttrOfType<StateUseKindAttr>("state_kind"))
      return emitOpError()
             << "with finite-state dependency requires `state_kind` "
                "attribute";
    break;
  case ReadDependencyKind::None:
  case ReadDependencyKind::LocalNeighbor:
    break;
  }

  return success();
}

LogicalResult WriteOp::verify() {
  if (failed(verifyByteIndexMap(getOperation())) ||
      failed(verifyAccessId(getOperation())))
    return failure();
  if (auto domain = (*this)->getAttrOfType<IntegerAttr>("value_domain");
      domain && domain.getInt() <= 0)
    return emitOpError() << "`value_domain` must be positive when present";
  return success();
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

LogicalResult ProjectStateOp::verify() {
  auto domain = (*this)->getAttrOfType<IntegerAttr>("domain");
  if (!domain || domain.getInt() <= 0)
    return emitOpError() << "requires a positive finite `domain`";
  if (auto modulus = (*this)->getAttrOfType<IntegerAttr>("modulus");
      modulus && modulus.getInt() <= 0)
    return emitOpError() << "`modulus` must be positive when present";
  if (auto bits = (*this)->getAttrOfType<IntegerAttr>("projected_bits");
      bits && bits.getInt() <= 0)
    return emitOpError() << "`projected_bits` must be positive when present";
  if (auto kind = (*this)->getAttrOfType<StringAttr>("projection_kind");
      kind && kind.getValue().empty())
    return emitOpError() << "`projection_kind` must be non-empty when present";
  auto access = (*this)->getAttrOfType<StringAttr>("read_access");
  if (!access || access.getValue().empty())
    return emitOpError() << "requires a non-empty `read_access`";

  Operation *stage = (*this)->getParentOp();
  while (stage && !isa<KernelOp, ScanOp>(stage))
    stage = stage->getParentOp();
  if (!stage)
    return emitOpError() << "must be nested in a bitstream stage";

  unsigned matches = 0;
  stage->walk([&](ReadOp read) {
    auto id = read.getOperation()->getAttrOfType<StringAttr>("access_id");
    if (id && id.getValue() == access.getValue() &&
        read.getBuffer() == getBuffer() &&
        sameIndexValue(read.getIndex(), getIndex()))
      ++matches;
  });
  if (matches != 1)
    return emitOpError()
           << "`read_access` must identify exactly one read of the same "
              "buffer and structurally identical index in this stage; found "
           << matches << " matches for " << access;
  return success();
}

static LogicalResult
verifyReferencedAccess(Operation *dependency, Operation *stage,
                       Operation *buffer, StringAttr accessId, bool expectRead,
                       StringRef attrName,
                       Operation **matchedAccess = nullptr) {
  if (!stage || !buffer || !accessId)
    return failure();
  auto bufferOp = dyn_cast<BufferOp>(buffer);
  if (!bufferOp)
    return failure();

  unsigned matches = 0;
  stage->walk([&](Operation *candidate) {
    auto id = candidate->getAttrOfType<StringAttr>("access_id");
    if (!id || id.getValue() != accessId.getValue())
      return;
    if (expectRead) {
      if (auto read = dyn_cast<ReadOp>(candidate))
        if (read.getBuffer() == bufferOp.getBuffer()) {
          ++matches;
          if (matchedAccess)
            *matchedAccess = candidate;
        }
      return;
    }
    if (auto write = dyn_cast<WriteOp>(candidate))
      if (write.getBuffer() == bufferOp.getBuffer()) {
        ++matches;
        if (matchedAccess)
          *matchedAccess = candidate;
      }
  });

  if (matches != 1)
    return dependency->emitOpError()
           << "`" << attrName << "` must identify exactly one "
           << (expectRead ? "read" : "write")
           << " of the dependency buffer in the referenced stage; found "
           << matches << " matches for " << accessId;
  return success();
}

static FailureOr<AffineMap> expectedProducerByteWindow(ReadOp read) {
  auto bytes = read.getOperation()->getAttrOfType<IntegerAttr>("bytes");
  if (!bytes || bytes.getInt() <= 0)
    return failure();

  MLIRContext *context = read.getContext();
  AffineExpr start;
  if (auto byteIndex =
          read.getOperation()->getAttrOfType<AffineMapAttr>("byte_index")) {
    AffineMap map = byteIndex.getValue();
    if (map.getNumDims() != 1 || map.getNumSymbols() != 0 ||
        map.getNumResults() != 1)
      return failure();
    start = map.getResult(0);
  } else {
    start = getAffineDimExpr(0, context) * bytes.getInt();
  }

  AffineExpr end = start + getAffineConstantExpr(bytes.getInt(), context);
  SmallVector<AffineExpr, 2> interval{start, end};
  return AffineMap::get(/*dimCount=*/1, /*symbolCount=*/0, interval, context);
}

LogicalResult DependencyOp::verify() {
  for (StringRef removed : {"kind", "index_relation", "span",
                            "finite_state_proof", "external_input"})
    if ((*this)->hasAttr(removed))
      return emitOpError()
             << "uses removed dependency attribute `" << removed
             << "`; use `memory`, `finite_state`, and an optional "
                "`producer_byte_window`";

  auto memory =
      (*this)->getAttrOfType<MemoryDependencyKindAttr>("memory_dependency");
  if (!memory)
    return emitOpError() << "requires `memory` attribute";
  auto producer = (*this)->getAttrOfType<SymbolRefAttr>("producer");
  auto consumer = (*this)->getAttrOfType<SymbolRefAttr>("consumer");
  auto buffer = (*this)->getAttrOfType<SymbolRefAttr>("buffer");
  bool hasProducer = static_cast<bool>(producer);
  if (memory.getValue() == MemoryDependencyKind::Input) {
    if (hasProducer)
      return emitOpError()
             << "input dependency must not carry a producer symbol";
  }
  if (memory.getValue() == MemoryDependencyKind::RAW && !hasProducer)
    return emitOpError() << "RAW dependency requires a producer symbol";
  if (producer && failed(verifySymbolRef<KernelOp, ScanOp>(
                      getOperation(), producer, "producer",
                      "bitstream.kernel or bitstream.scan")))
    return failure();
  if (!consumer || failed(verifySymbolRef<KernelOp, ScanOp>(
                       getOperation(), consumer, "consumer",
                       "bitstream.kernel or bitstream.scan")))
    return failure();
  if (!buffer || failed(verifySymbolRef<BufferOp>(
                     getOperation(), buffer, "buffer", "bitstream.buffer")))
    return failure();

  auto consumerAccess = (*this)->getAttrOfType<StringAttr>("consumer_access");
  if (!consumerAccess || consumerAccess.getValue().empty())
    return emitOpError() << "requires a non-empty `consumer_access` identifier";
  auto producerAccess = (*this)->getAttrOfType<StringAttr>("producer_access");
  if (memory.getValue() == MemoryDependencyKind::Input && producerAccess)
    return emitOpError() << "input dependency must not carry `producer_access`";
  if (memory.getValue() == MemoryDependencyKind::RAW &&
      (!producerAccess || producerAccess.getValue().empty()))
    return emitOpError()
           << "RAW dependency requires a non-empty `producer_access` "
              "identifier";

  Operation *consumerStage = lookupSymbolRef(getOperation(), consumer);
  Operation *bufferOp = lookupSymbolRef(getOperation(), buffer);
  Operation *consumerAccessOp = nullptr;
  if (failed(verifyReferencedAccess(getOperation(), consumerStage, bufferOp,
                                    consumerAccess, /*expectRead=*/true,
                                    "consumer_access", &consumerAccessOp)))
    return failure();
  Operation *producerStage = nullptr;
  if (memory.getValue() == MemoryDependencyKind::RAW) {
    producerStage = lookupSymbolRef(getOperation(), producer);
    if (failed(verifyReferencedAccess(getOperation(), producerStage, bufferOp,
                                      producerAccess,
                                      /*expectRead=*/false, "producer_access")))
      return failure();
  }

  auto window = (*this)->getAttrOfType<AffineMapAttr>("producer_byte_window");
  auto read = dyn_cast_or_null<ReadOp>(consumerAccessOp);
  if (!read)
    return emitOpError()
           << "cannot resolve `consumer_access` to a bitstream.read";
  bool isStructurallyUnbounded =
      static_cast<bool>(read.getOperation()->getParentOfType<scf::WhileOp>()) ||
      isa_and_nonnull<ScanOp>(producerStage);
  if (isStructurallyUnbounded) {
    if (window)
      return emitOpError()
             << "structurally unbounded dependency must not carry "
                "`producer_byte_window`";
  } else {
    if (!window)
      return emitOpError()
             << "ordinary dependency requires `producer_byte_window`";
    FailureOr<AffineMap> expected = expectedProducerByteWindow(read);
    if (failed(expected))
      return emitOpError()
             << "cannot derive bounded byte window from consumer read: "
                "expected positive `bytes` and a one-dimensional "
                "`byte_index` map";
    if (window.getValue() != *expected)
      return emitOpError()
             << "`producer_byte_window` must equal the consumer read's "
                "half-open physical byte interval "
             << AffineMapAttr::get(*expected) << ", got " << window;
  }

  auto finiteState =
      (*this)->getAttrOfType<FiniteStateProofKindAttr>("finite_state");
  if (!finiteState)
    return emitOpError() << "requires `finite_state = none|proven`";

  ArrayAttr states = (*this)->getAttrOfType<ArrayAttr>("states");
  auto finiteStateDomain =
      (*this)->getAttrOfType<IntegerAttr>("finite_state_domain");
  if (finiteState.getValue() == FiniteStateProofKind::None) {
    if (finiteStateDomain)
      return emitOpError() << "with `finite_state = none` must not carry "
                              "`finite_state_domain`";
    if (states)
      return emitOpError()
             << "with `finite_state = none` must not carry `states`";
  } else {
    if (memory.getValue() == MemoryDependencyKind::Input)
      return emitOpError()
             << "input dependency cannot carry `finite_state = proven`";
    if (!finiteStateDomain || finiteStateDomain.getInt() <= 0)
      return emitOpError()
             << "with `finite_state = proven` requires a positive "
                "`finite_state_domain`";
    if (!states || states.empty())
      return emitOpError()
             << "with `finite_state = proven` requires non-empty `states` "
                "symbol reference array";
  }

  if (failed(verifySymbolRefArray<StateOp>(getOperation(), states, "states",
                                           "bitstream.state")))
    return failure();

  if (finiteState.getValue() == FiniteStateProofKind::Proven) {
    SmallVector<ProjectStateOp, 2> matchingProjections;
    consumerStage->walk([&](ProjectStateOp projection) {
      auto readAccess =
          projection.getOperation()->getAttrOfType<StringAttr>("read_access");
      auto projectionDomain =
          projection.getOperation()->getAttrOfType<IntegerAttr>("domain");
      if (readAccess && readAccess.getValue() == consumerAccess.getValue() &&
          projection.getBuffer() == read.getBuffer() &&
          sameIndexValue(projection.getIndex(), read.getIndex()) &&
          projectionDomain &&
          projectionDomain.getInt() == finiteStateDomain.getInt())
        matchingProjections.push_back(projection);
    });
    if (matchingProjections.size() != 1)
      return emitOpError()
             << "with `finite_state = proven` requires exactly one "
                "consumer-stage `bitstream.project_state` matching "
                "`consumer_access`, buffer, SSA index, and "
                "`finite_state_domain`; found "
             << matchingProjections.size();

    for (Attribute attr : states) {
      auto ref = cast<SymbolRefAttr>(attr);
      auto state =
          dyn_cast_or_null<StateOp>(lookupSymbolRef(getOperation(), ref));
      auto stateDomain =
          state ? state.getOperation()->getAttrOfType<IntegerAttr>("domain")
                : IntegerAttr();
      if (!stateDomain || stateDomain.getInt() <= 0)
        return emitOpError()
               << "proven state " << ref << " requires a positive `domain`";
      if (stateDomain.getInt() != finiteStateDomain.getInt())
        return emitOpError() << "proven state " << ref << " has domain "
                             << stateDomain.getInt()
                             << ", but dependency `finite_state_domain` is "
                             << finiteStateDomain.getInt();
    }
  }

  return success();
}

LogicalResult FusionCandidateOp::verify() {
  auto legal = (*this)->getAttrOfType<BoolAttr>("legal");
  if (legal && legal.getValue()) {
    ArrayAttr stages = (*this)->getAttrOfType<ArrayAttr>("stages");
    if (!stages || stages.empty())
      return emitOpError() << "legal candidate requires non-empty `stages`";
  }
  if (failed(verifySymbolRefArray<KernelOp, ScanOp>(
          getOperation(), (*this)->getAttrOfType<ArrayAttr>("stages"), "stages",
          "bitstream.kernel or bitstream.scan")))
    return failure();
  if (failed(verifySymbolRefArray<StateOp>(
          getOperation(), (*this)->getAttrOfType<ArrayAttr>("states"), "states",
          "bitstream.state")))
    return failure();
  return success();
}

LogicalResult FusedKernelOp::verify() {
  ArrayAttr stages = (*this)->getAttrOfType<ArrayAttr>("stages");
  ArrayAttr states = (*this)->getAttrOfType<ArrayAttr>("states");
  if (!stages || stages.empty())
    return emitOpError() << "requires non-empty `stages`";
  auto sourcePipeline =
      (*this)->getAttrOfType<FlatSymbolRefAttr>("source_pipeline");
  if (!sourcePipeline ||
      failed(verifySymbolRef<PipelineOp>(
          getOperation(),
          SymbolRefAttr::get(getContext(), sourcePipeline.getValue()),
          "source_pipeline", "bitstream.pipeline")))
    return failure();
  if (failed(verifySymbolRefArray<KernelOp, ScanOp>(
          getOperation(), stages, "stages",
          "bitstream.kernel or bitstream.scan")))
    return failure();
  if (failed(verifySymbolRefArray<StateOp>(getOperation(), states, "states",
                                           "bitstream.state")))
    return failure();
  return success();
}

#define GET_OP_CLASSES
#include "Bitstream/BitstreamOps.cpp.inc"
