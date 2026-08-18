#ifndef BITSTREAM_OPS_TD
#define BITSTREAM_OPS_TD

include "mlir/IR/OpBase.td"
include "mlir/IR/EnumAttr.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "Bitstream/BitstreamDialect.td"
include "Bitstream/BitstreamTypes.td"

class Bitstream_Op<string mnemonic, list<Trait> traits = []> :
    Op<Bitstream_Dialect, mnemonic, traits>;

def Bitstream_StateTransitionNeighbor
    : I32EnumAttrCase<"NeighborFiniteState", 0, "neighbor_finite_state">;
def Bitstream_StateTransitionPrefixProjection
    : I32EnumAttrCase<"PrefixStateProjection", 1, "prefix_state_projection">;
def Bitstream_StateTransitionAddMod
    : I32EnumAttrCase<"AddMod", 2, "add_mod">;
def Bitstream_StateTransitionXor
    : I32EnumAttrCase<"Xor", 3, "xor">;
def Bitstream_StateTransitionProjected
    : I32EnumAttrCase<"ProjectedState", 4, "projected_state">;
def Bitstream_StateTransitionRegexAdvance
    : I32EnumAttrCase<"RegexAdvance", 5, "regex_advance">;

def Bitstream_StateTransitionKind : I32EnumAttr<
    "StateTransitionKind",
    "finite-state transition semantics",
    [Bitstream_StateTransitionNeighbor,
     Bitstream_StateTransitionPrefixProjection,
     Bitstream_StateTransitionAddMod,
     Bitstream_StateTransitionXor,
     Bitstream_StateTransitionProjected,
     Bitstream_StateTransitionRegexAdvance]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_ReadDependencyNone
    : I32EnumAttrCase<"None", 0, "none">;
def Bitstream_ReadDependencyPredecessor
    : I32EnumAttrCase<"DataDependentPredecessor", 1,
                      "data_dependent_predecessor">;
def Bitstream_ReadDependencyLocalNeighbor
    : I32EnumAttrCase<"LocalNeighbor", 2, "local_neighbor">;
def Bitstream_ReadDependencyPrefixState
    : I32EnumAttrCase<"PrefixState", 3, "prefix_state">;
def Bitstream_ReadDependencyProjectedState
    : I32EnumAttrCase<"ProjectedState", 4, "projected_state">;

def Bitstream_ReadDependencyKind : I32EnumAttr<
    "ReadDependencyKind",
    "read-side dependence annotation",
    [Bitstream_ReadDependencyNone,
     Bitstream_ReadDependencyPredecessor,
     Bitstream_ReadDependencyLocalNeighbor,
     Bitstream_ReadDependencyPrefixState,
     Bitstream_ReadDependencyProjectedState]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_StateUseNeighbor
    : I32EnumAttrCase<"NeighborFiniteState", 0, "neighbor_finite_state">;
def Bitstream_StateUseProjection
    : I32EnumAttrCase<"FiniteStateProjection", 1,
                      "finite_state_projection">;
def Bitstream_StateUseProjected
    : I32EnumAttrCase<"ProjectedState", 2, "projected_state">;

def Bitstream_StateUseKind : I32EnumAttr<
    "StateUseKind",
    "how a read consumes a finite state",
    [Bitstream_StateUseNeighbor,
     Bitstream_StateUseProjection,
     Bitstream_StateUseProjected]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_MemoryDependencyInput
    : I32EnumAttrCase<"Input", 0, "input">;
def Bitstream_MemoryDependencyRAW
    : I32EnumAttrCase<"RAW", 1, "raw">;

def Bitstream_MemoryDependencyKind : I32EnumAttr<
    "MemoryDependencyKind",
    "memory dependence relation",
    [Bitstream_MemoryDependencyInput,
     Bitstream_MemoryDependencyRAW]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_FiniteStateProofNone
    : I32EnumAttrCase<"None", 0, "none">;
def Bitstream_FiniteStateProofProven
    : I32EnumAttrCase<"Proven", 1, "proven">;

def Bitstream_FiniteStateProofKind : I32EnumAttr<
    "FiniteStateProofKind",
    "dependency-level finite-state proof availability",
    [Bitstream_FiniteStateProofNone,
     Bitstream_FiniteStateProofProven]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_SourceEntryKernelLaunch
    : I32EnumAttrCase<"KernelLaunch", 0, "kernel_launch">;
def Bitstream_SourceEntryLibraryScan
    : I32EnumAttrCase<"LibraryScan", 1, "library_scan">;

def Bitstream_SourceEntryKind : I32EnumAttr<
    "SourceEntryKind",
    "source-level stage invocation kind",
    [Bitstream_SourceEntryKernelLaunch,
     Bitstream_SourceEntryLibraryScan]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_FusionStrategyDecoupledLookback
    : I32EnumAttrCase<"DecoupledLookback", 0, "decoupled_lookback">;
def Bitstream_FusionStrategyElementwise
    : I32EnumAttrCase<"Elementwise", 1, "elementwise">;
def Bitstream_FusionStrategyRegexAdvanceSpeculation
    : I32EnumAttrCase<"RegexAdvanceSpeculation", 2,
                      "regex_advance_speculation">;

def Bitstream_FusionStrategyKind : I32EnumAttr<
    "FusionStrategyKind",
    "fused-kernel execution strategy",
    [Bitstream_FusionStrategyDecoupledLookback,
     Bitstream_FusionStrategyElementwise,
     Bitstream_FusionStrategyRegexAdvanceSpeculation]> {
  let cppNamespace = "::bitstream";
}

def Bitstream_BufferLike : Type<
  CPred<"::llvm::isa<::bitstream::BufferType>($_self)">,
  "bitstream buffer">;

def Bitstream_YieldOp : Bitstream_Op<"yield", [Terminator]> {
  let summary = "terminator for bitstream regions";
  let assemblyFormat = "attr-dict";
}

def Bitstream_PipelineOp : Bitstream_Op<"pipeline", [
    AffineScope,
    Symbol,
    SymbolTable,
    IsolatedFromAbove,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "bitstream pipeline container";
  let arguments = (ins SymbolNameAttr:$sym_name);
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "$sym_name attr-dict-with-keyword $body";
}

def Bitstream_AnalysisOp : Bitstream_Op<"analysis", [
    Symbol,
    SymbolTable,
    IsolatedFromAbove,
    NoMemoryEffect,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "analysis result container for one source pipeline";
  let description = [{
    Keeps dependence, finite-state, fusion, and selection results out of the
    executable pipeline body. This mirrors normal compiler structure: the
    pipeline remains the program IR, while this op is a materialized analysis
    graph that later passes can consume and rewrite.
  }];
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    FlatSymbolRefAttr:$source_pipeline
  );
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "$sym_name `for` $source_pipeline attr-dict-with-keyword $body";
}

def Bitstream_DependencyGroupOp : Bitstream_Op<"dependency_group", [
    NoMemoryEffect,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "dependencies sharing the same boundedness class";
  let description = [{
    Partitions the dependency edges materialized by the classification pass.
    The `bounded` group contains edges with an explicit finite producer byte
    window; `unbounded` contains edges without such a window.  This is an
    analysis-IR grouping, not a control-flow block.
  }];
  let arguments = (ins StrAttr:$kind);
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "`kind` `=` $kind attr-dict-with-keyword $body";
}

def Bitstream_KernelOp : Bitstream_Op<"kernel", [
    AffineScope,
    Symbol,
    SymbolTable,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "logical GPU kernel stage";
  let arguments = (ins SymbolNameAttr:$sym_name);
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "$sym_name attr-dict-with-keyword $body";
}

def Bitstream_FactGroupOp : Bitstream_Op<"fact_group", [
    Symbol,
    NoMemoryEffect,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "source-language fact group extracted from Clang AST";
  let description = [{
    Holds compiler frontend facts such as calls, parameters, array loads,
    array stores, loops, and expression summaries. This op does not claim that
    a high-level idiom has been recognized; it is the neutral input layer for
    access-graph recovery.
  }];
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    StrAttr:$kind,
    OptionalAttr<StrAttr>:$source_function
  );
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "$sym_name attr-dict-with-keyword $body";
}

def Bitstream_FactOp : Bitstream_Op<"fact", [NoMemoryEffect]> {
  let summary = "one source-language fact extracted from Clang AST";
  let arguments = (ins StrAttr:$role);
  let assemblyFormat = "$role attr-dict";
}

def Bitstream_SourceEntryOp : Bitstream_Op<"source_entry", [NoMemoryEffect]> {
  let summary = "typed source-level stage invocation fact";
  let arguments = (ins
    Bitstream_SourceEntryKind:$kind,
    I64Attr:$order,
    StrAttr:$callee,
    StrAttr:$args
  );
  let assemblyFormat = "`kind` `=` $kind attr-dict";
}

def Bitstream_SourceFunctionOp : Bitstream_Op<"source_function",
    [NoMemoryEffect]> {
  let summary = "typed source-level function marker fact";
  let arguments = (ins StrAttr:$name);
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceParamOp : Bitstream_Op<"source_param", [NoMemoryEffect]> {
  let summary = "typed source-level parameter fact";
  let arguments = (ins
    StrAttr:$name,
    StrAttr:$type_text,
    OptionalAttr<UnitAttr>:$is_pointer,
    OptionalAttr<UnitAttr>:$is_reference
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceVarDeclOp : Bitstream_Op<"source_var_decl",
    [NoMemoryEffect]> {
  let summary = "typed source-level variable declaration fact";
  let arguments = (ins
    StrAttr:$name,
    OptionalAttr<StrAttr>:$init
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceExprDefOp : Bitstream_Op<"source_expr_def",
    [NoMemoryEffect]> {
  let summary = "typed source-level scalar expression definition fact";
  let arguments = (ins
    StrAttr:$target,
    OptionalAttr<StrAttr>:$expr
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceArrayLoadOp : Bitstream_Op<"source_array_load",
    [NoMemoryEffect]> {
  let summary = "typed source-level array load fact";
  let arguments = (ins
    OptionalAttr<StrAttr>:$target,
    StrAttr:$buffer,
    StrAttr:$index
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceArrayStoreOp : Bitstream_Op<"source_array_store",
    [NoMemoryEffect]> {
  let summary = "typed source-level array store fact";
  let arguments = (ins
    StrAttr:$buffer,
    StrAttr:$index,
    OptionalAttr<StrAttr>:$value,
    OptionalAttr<StrAttr>:$uses,
    OptionalAttr<StrAttr>:$calls
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceLoopOp : Bitstream_Op<"source_loop", [NoMemoryEffect]> {
  let summary = "typed source-level loop fact";
  let arguments = (ins
    StrAttr:$loop_kind,
    OptionalAttr<StrAttr>:$condition
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceCallOp : Bitstream_Op<"source_call", [NoMemoryEffect]> {
  let summary = "typed source-level call fact";
  let arguments = (ins
    StrAttr:$callee,
    OptionalAttr<StrAttr>:$args
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceAssignmentOp : Bitstream_Op<"source_assignment",
    [NoMemoryEffect]> {
  let summary = "typed source-level assignment or binary-op fact";
  let arguments = (ins
    StrAttr:$opcode,
    OptionalAttr<StrAttr>:$lhs,
    OptionalAttr<StrAttr>:$rhs
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_SourceArrayAccessOp : Bitstream_Op<"source_array_access",
    [NoMemoryEffect]> {
  let summary = "typed source-level array access fact";
  let arguments = (ins
    StrAttr:$buffer,
    StrAttr:$index
  );
  let assemblyFormat = "attr-dict";
}

def Bitstream_ScanOp : Bitstream_Op<"scan", [
    AffineScope,
    Symbol,
    SymbolTable,
    SingleBlockImplicitTerminator<"YieldOp">
  ]> {
  let summary = "logical prefix-scan stage";
  let arguments = (ins SymbolNameAttr:$sym_name, StrAttr:$combiner);
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat = "$sym_name `operator` `=` $combiner attr-dict-with-keyword $body";
}

def Bitstream_BufferOp : Bitstream_Op<"buffer", [Pure, Symbol]> {
  let summary = "declare a logical bitstream buffer";
  let arguments = (ins SymbolNameAttr:$sym_name);
  let results = (outs Bitstream_BufferLike:$buffer);
  let assemblyFormat = "$sym_name attr-dict `:` type($buffer)";
}

def Bitstream_LogicalIndexOp : Bitstream_Op<"logical_index", [Pure]> {
  let summary = "logical item coordinate of the enclosing bitstream stage";
  let description = [{
    Represents the canonical per-stage logical coordinate used to compare
    accesses across kernels and scans.  It deliberately has neither a source
    variable name nor an extent: those are not properties of a memory access.
  }];
  let results = (outs Index:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}

def Bitstream_ParameterOp : Bitstream_Op<"parameter", [Pure, Symbol]> {
  let summary = "pipeline-scoped scalar inherited from the source driver";
  let description = [{
    Represents one scalar argument of the selected source driver.  The result
    is defined inside bitstream.pipeline and may therefore be captured by all
    of its stages.  `source_arg` is SSA provenance, not a guessed source
    variable name.
  }];
  let arguments = (ins SymbolNameAttr:$sym_name, I64Attr:$source_arg);
  let results = (outs Index:$result);
  let hasVerifier = 1;
  let assemblyFormat = "$sym_name attr-dict `:` type($result)";
}

def Bitstream_ReadOp : Bitstream_Op<"read", [MemoryEffects<[MemRead]>]> {
  let summary = "read from a logical bitstream buffer";
  let arguments = (ins
    Bitstream_BufferLike:$buffer,
    Index:$index,
    OptionalAttr<StrAttr>:$access_id,
    OptionalAttr<I64Attr>:$bytes,
    OptionalAttr<AffineMapAttr>:$byte_index,
    OptionalAttr<Bitstream_ReadDependencyKind>:$dependency,
    OptionalAttr<SymbolRefAttr>:$state,
    OptionalAttr<Bitstream_StateUseKind>:$state_kind
  );
  let hasVerifier = 1;
  let assemblyFormat = [{
    $buffer `[` $index `]`
    (`dependency` `=` $dependency^)?
    (`state` `=` $state^)?
    (`state_kind` `=` $state_kind^)?
    attr-dict `:` type($buffer)
  }];
}

def Bitstream_WriteOp : Bitstream_Op<"write", [MemoryEffects<[MemWrite]>]> {
  let summary = "write to a logical bitstream buffer";
  let arguments = (ins
    Bitstream_BufferLike:$buffer,
    Index:$index,
    OptionalAttr<StrAttr>:$access_id,
    OptionalAttr<I64Attr>:$bytes,
    OptionalAttr<AffineMapAttr>:$byte_index,
    OptionalAttr<I64Attr>:$value_domain,
    OptionalAttr<UnitAttr>:$tail_boundary_write,
    OptionalAttr<StrAttr>:$meaning,
    OptionalAttr<StrAttr>:$reuse_as
  );
  let hasVerifier = 1;
  let assemblyFormat = "$buffer `[` $index `]` attr-dict `:` type($buffer)";
}

def Bitstream_ProjectStateOp : Bitstream_Op<"project_state",
    [NoMemoryEffect]> {
  let summary = "project a bitstream region into a bounded state";
  let description = [{
    First-class value-flow evidence that a buffer value at this exact SSA index
    is consumed through a bounded projection.  `read_access` identifies the
    real read being projected, `domain` is the projection's finite cardinality,
    and the remaining optional attributes refine how it is computed.
  }];
  let arguments = (ins
    Bitstream_BufferLike:$buffer,
    Index:$index,
    I64Attr:$domain,
    OptionalAttr<I64Attr>:$modulus,
    OptionalAttr<I64Attr>:$projected_bits,
    OptionalAttr<StrAttr>:$projection_kind,
    StrAttr:$read_access
  );
  let hasVerifier = 1;
  let assemblyFormat = "$buffer `[` $index `]` attr-dict `:` type($buffer)";
}

def Bitstream_AdvanceOp : Bitstream_Op<"advance", [NoMemoryEffect]> {
  let summary = "semantic bitstream shift/advance operation";
  let description = [{
    Records that a stage propagates bitstream match/state information across
    word boundaries, such as a regex/literal advance.  This is deliberately not
    a read/write edge: dependency analysis still comes from buffer accesses,
    while this op exposes semantic state propagation for later legality and
    cost-model passes.
  }];
  let arguments = (ins
    StrAttr:$direction,
    I64Attr:$distance,
    OptionalAttr<I64Attr>:$count,
    OptionalAttr<StrAttr>:$callee,
    OptionalAttr<UnitAttr>:$sync
  );
  let assemblyFormat = "$direction `by` $distance attr-dict";
}

def Bitstream_StateOp : Bitstream_Op<"state", [Symbol]> {
  let summary = "declare a small finite state needed by a stage";
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    I64Attr:$bits,
    OptionalAttr<I64Attr>:$domain,
    OptionalAttr<Bitstream_StateTransitionKind>:$transition,
    OptionalAttr<I64Attr>:$distance,
    OptionalAttr<I64Attr>:$modulus,
    OptionalAttr<StrAttr>:$derived_from,
    OptionalAttr<StrAttr>:$finite_state_source,
    OptionalAttr<StrAttr>:$advance_direction,
    OptionalAttr<I64Attr>:$advance_count,
    OptionalAttr<I64Attr>:$max_advance_distance,
    OptionalAttr<UnitAttr>:$inferred
  );
  let hasVerifier = 1;
  let assemblyFormat = [{
    $sym_name (`transition` `=` $transition^)?
    attr-dict
  }];
}

def Bitstream_DependencyOp : Bitstream_Op<"dependency", [NoMemoryEffect]> {
  let summary = "materialized producer/consumer dependence edge";
  let arguments = (ins
    OptionalAttr<SymbolRefAttr>:$producer,
    SymbolRefAttr:$consumer,
    SymbolRefAttr:$buffer,
    OptionalAttr<SymbolRefArrayAttr>:$states,
    Bitstream_MemoryDependencyKind:$memory_dependency,
    OptionalAttr<StrAttr>:$producer_access,
    StrAttr:$consumer_access,
    Bitstream_FiniteStateProofKind:$finite_state,
    OptionalAttr<AffineMapAttr>:$producer_byte_window,
    OptionalAttr<ConfinedAttr<I64Attr, [IntPositive]>>:$finite_state_domain
  );
  let hasVerifier = 1;
  let assemblyFormat = [{
    `memory` `=` $memory_dependency
    (`producer_access` `=` $producer_access^)?
    `consumer_access` `=` $consumer_access
    `finite_state` `=` $finite_state
    (`producer_byte_window` `=` $producer_byte_window^)?
    (`finite_state_domain` `=` $finite_state_domain^)?
    attr-dict
  }];
}

def Bitstream_FusionCandidateOp : Bitstream_Op<"fusion_candidate",
    [NoMemoryEffect]> {
  let summary = "analysis result describing a legal speculative fusion region";
  let arguments = (ins
    StrAttr:$name,
    SymbolRefArrayAttr:$stages,
    SymbolRefArrayAttr:$states,
    BoolAttr:$legal,
    StrAttr:$reason
  );
  let hasVerifier = 1;
  let assemblyFormat = "attr-dict";
}

def Bitstream_FusedKernelOp : Bitstream_Op<"fused_kernel",
    [Symbol, NoMemoryEffect]> {
  let summary = "descriptor for generated speculative fused kernel";
  let arguments = (ins
    SymbolNameAttr:$sym_name,
    FlatSymbolRefAttr:$source_pipeline,
    SymbolRefArrayAttr:$stages,
    SymbolRefArrayAttr:$states,
    Bitstream_FusionStrategyKind:$strategy
  );
  let hasVerifier = 1;
  let assemblyFormat = "$sym_name `strategy` `=` $strategy attr-dict";
}

#endif // BITSTREAM_OPS_TD
