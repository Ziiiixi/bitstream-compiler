#ifndef BITSTREAM_PASSES_TD
#define BITSTREAM_PASSES_TD

include "mlir/Pass/PassBase.td"

def BitstreamFiniteStateInference
    : Pass<"bitstream-finite-state-inference", "mlir::ModuleOp"> {
  let summary = "Prove small finite-state dependencies after graph discovery";
  let description = [{
    Runs after raw dependence discovery and structural classification. It walks
    every RAW dependency and resolves the exact producer and consumer accesses.
    A proof may come from an access-linked bitstream.project_state, a finite
    local bitstream.recurrence that drives the consumer index, or an exact
    finite-domain write from a bitstream.scan. Only that exact edge receives
    bitstream.state, finite_state = proven, and a positive domain; every other
    edge remains finite_state = none. A bounded proof is recorded but does not
    change ordinary window-based fusion legality.
  }];
  let constructor = "bitstream::createBitstreamFiniteStateInferencePass()";
  let dependentDialects = ["bitstream::BitstreamDialect"];
}

def BitstreamRecoverSemantics
    : Pass<"bitstream-recover-access-graph", "mlir::ModuleOp"> {
  let summary = "Build a generic bitstream access graph from frontend IR";
  let description = [{
    Consumes either bitstream.fact_group operations emitted from Clang AST facts
    or generic Polygeist MLIR (func/scf/memref/arith). It builds local
    read/write/index SSA structure and emits a generic access graph with
    bitstream.logical_index coordinates, ordinary arith/scf index computation,
    bitstream.read/write operations, and finite-state projection evidence
    recovered by SSA subgraph matching. Structured scf.for iteration arguments
    and scf.while carried lanes are inspected before access flattening, so
    recognized local state remains in bitstream.recurrence regions and a
    scheduler-independent global prefix becomes bitstream.scan. It deliberately
    avoids naming workload-specific idioms; later passes build raw dependencies,
    classify structural relations, and prove finite-state semantics.
  }];
  let constructor = "bitstream::createBitstreamRecoverSemanticsPass()";
  let dependentDialects = [
    "mlir::affine::AffineDialect",
    "bitstream::BitstreamDialect",
    "mlir::arith::ArithDialect",
    "mlir::func::FuncDialect",
    "mlir::gpu::GPUDialect",
    "mlir::memref::MemRefDialect",
    "mlir::scf::SCFDialect"
  ];
}

def BitstreamDependenceAnalysis
    : Pass<"bitstream-dependence-analysis", "mlir::ModuleOp"> {
  let summary = "Compare byte-indexed accesses and build raw dependencies";
  let description = [{
    Walks bitstream.pipeline operations, collects logical buffer declarations,
    stage-local reads, and writes.  Each real read/write receives a stable
    access_id and carries its own byte_index map.  The pass composes that map
    with the operation's SSA index and emits bitstream.dependency operations.
    Every ordinary dependency carries a two-result affine
    producer_byte_window for its half-open physical-byte interval, expressed
    over the consumer read's existing access-index operand. A scan producer,
    recurrence-varying read, or loop-carried predecessor read carries no such
    map; a recurrence-invariant read remains windowed. Dependencies refer
    directly to the real producer and consumer access_id values; no duplicate
    boundedness or access-domain summary is emitted. Every new edge starts with
    the explicit finite_state = none status.
  }];
  let constructor = "bitstream::createBitstreamDependenceAnalysisPass()";
  let dependentDialects = [
    "mlir::affine::AffineDialect",
    "bitstream::BitstreamDialect"
  ];
}

def BitstreamDependencyClassification
    : Pass<"bitstream-dependency-classification", "mlir::ModuleOp"> {
  let summary = "Group bounded and unbounded dependencies";
  let description = [{
    Places dependencies with a finite byte-window witness in the bounded group
    and structurally unbounded dependencies in the unbounded group. It does not
    add a classification attribute, invent another access summary, or prove a
    state projection.
  }];
  let constructor = "bitstream::createBitstreamDependencyClassificationPass()";
  let dependentDialects = ["bitstream::BitstreamDialect"];
}

def BitstreamSpeculativeFusion
    : Pass<"bitstream-speculative-fusion", "mlir::ModuleOp"> {
  let summary = "Prove ordinary or finite-state fusion regions";
  let description = [{
    Consumes bitstream.analysis dependency operations and emits a fusion candidate plus
    a fused-kernel descriptor when every producer edge is either bounded with
    an explicit byte window or is an unbounded edge carrying an exact
    finite-state proof. ProjectState is matched through access IDs, so one
    projected read cannot legalize another read of the same buffer. Recovered
    recurrence and scan proofs additionally require exact state/value-domain
    agreement on the referenced access. Scan state is currently binary;
    predecessor and recurrence state is accepted only within the runtime
    template's finite domain limit.
  }];
  let constructor = "bitstream::createBitstreamSpeculativeFusionPass()";
  let dependentDialects = ["bitstream::BitstreamDialect"];
}

#endif // BITSTREAM_PASSES_TD
