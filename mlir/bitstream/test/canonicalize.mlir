// RUN: bitstream-opt %s -canonicalize | FileCheck %s

module {
  bitstream.pipeline @canonicalize_index_arithmetic {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @k {
      %k = bitstream.logical_index : index
      %c0 = arith.constant 0 : index
      %alias = arith.addi %k, %c0 : index
      bitstream.write %tmp[%alias] {bytes = 4 : i64} : !bitstream.buffer
    }
  }
}

// CHECK-NOT: arith.addi
// CHECK: bitstream.write
