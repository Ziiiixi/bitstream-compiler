// RUN: bitstream-opt %s -bitstream-finite-state-inference -bitstream-speculative-fusion | FileCheck %s

module {
  bitstream.pipeline @project_state_positive {
    %bitmap = bitstream.buffer @bitmap : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %bitmap[%i] {access_id = "a0", bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %j0 = arith.subi %k, %c1 : index
      %unused = scf.while (%j = %j0) : (index) -> index {
        %c0 = arith.constant 0 : index
        %inside = arith.cmpi sge, %j, %c0 : index
        scf.condition(%inside) %j : index
      } do {
      ^bb0(%j: index):
        bitstream.read %bitmap[%j] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
        bitstream.project_state %bitmap[%j] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_low_bit", read_access = "a1"} : !bitstream.buffer
        %next = arith.subi %j, %c1 : index
        scf.yield %next : index
      }
      bitstream.write %out[%k] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @project_state_positive_analysis for @project_state_positive {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none {buffer = @project_state_positive::@bitmap, consumer = @project_state_positive::@consumer, producer = @project_state_positive::@producer}
  }

  bitstream.pipeline @exact_read_escapes_negative {
    %bitmap = bitstream.buffer @bitmap : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %bitmap[%i] {access_id = "a0", bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %j0 = arith.subi %k, %c1 : index
      %unused = scf.while (%j = %j0) : (index) -> index {
        %c0 = arith.constant 0 : index
        %inside = arith.cmpi sge, %j, %c0 : index
        scf.condition(%inside) %j : index
      } do {
      ^bb0(%j: index):
        bitstream.read %bitmap[%j] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
        bitstream.project_state %bitmap[%j] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_low_bit", read_access = "a1"} : !bitstream.buffer
        bitstream.read %bitmap[%j] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
        %next = arith.subi %j, %c1 : index
        scf.yield %next : index
      }
      bitstream.write %out[%k] {access_id = "a3", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @exact_read_escapes_negative_analysis for @exact_read_escapes_negative {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none {buffer = @exact_read_escapes_negative::@bitmap, consumer = @exact_read_escapes_negative::@consumer, producer = @exact_read_escapes_negative::@producer}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a2" finite_state = none {buffer = @exact_read_escapes_negative::@bitmap, consumer = @exact_read_escapes_negative::@consumer, producer = @exact_read_escapes_negative::@producer}
  }
}

// CHECK-LABEL: bitstream.analysis @project_state_positive_analysis
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven
// CHECK-SAME: finite_state_domain = 2
// CHECK: bitstream.fused_kernel

// CHECK-LABEL: bitstream.analysis @exact_read_escapes_negative_analysis
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven
// CHECK-SAME: finite_state_domain = 2
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a2" finite_state = none
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = false
// CHECK-SAME: reason = "predecessor dependency has no exact while-read ProjectState proof for buffer bitmap"
// CHECK-NOT: bitstream.fused_kernel
