// RUN: bitstream-opt %s -bitstream-recover-access-graph | FileCheck %s

module {
  bitstream.pipeline @toy_ast_facts {
    bitstream.fact_group @k attributes {kind = "clang_ast_facts"} {
      bitstream.source_entry kind = kernel_launch {args = "input, tmp, n", callee = "k", order = 0 : i64}
      bitstream.source_param {is_pointer, name = "in", type_text = "uint32_t *"}
      bitstream.source_param {is_pointer, name = "out", type_text = "uint32_t *"}
      bitstream.source_param {name = "n", type_text = "int"}
      bitstream.source_var_decl {
        name = "thread_coordinate",
        init = "blockIdx.x * blockDim.x + threadIdx.x",
        init_kind = "binary",
        init_opcode = "+",
        init_lhs_kind = "binary",
        init_lhs_opcode = "*",
        init_lhs_lhs_kind = "gpu",
        init_lhs_lhs_gpu = "block_id",
        init_lhs_lhs_dim = "x",
        init_lhs_rhs_kind = "gpu",
        init_lhs_rhs_gpu = "block_dim",
        init_lhs_rhs_dim = "x",
        init_rhs_kind = "gpu",
        init_rhs_gpu = "thread_id",
        init_rhs_dim = "x"
      }
      bitstream.source_array_load {target = "v", buffer = "in", index = "thread_coordinate", index_kind = "symbol", index_symbol = "thread_coordinate"}
      bitstream.source_array_store {buffer = "out", index = "thread_coordinate", value = "v", index_kind = "symbol", index_symbol = "thread_coordinate", source_line = 1 : i64}
    }
  }
}

// CHECK: bitstream.buffer @input
// CHECK: bitstream.buffer @tmp
// CHECK: bitstream.logical_index
// CHECK: bitstream.read {{.*}}access_id = "a0"
// CHECK: bitstream.write {{.*}}access_id = "a1"
