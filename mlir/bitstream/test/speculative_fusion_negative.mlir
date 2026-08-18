// RUN: bitstream-opt %s -bitstream-speculative-fusion | FileCheck %s

module {
  bitstream.pipeline @unbounded_without_exact_proof {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
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
        bitstream.read %tmp[%j] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
        %next = arith.subi %j, %c1 : index
        scf.yield %next : index
      }
      bitstream.write %out[%k] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @unbounded_without_exact_proof_analysis for @unbounded_without_exact_proof {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none {buffer = @unbounded_without_exact_proof::@tmp, consumer = @unbounded_without_exact_proof::@consumer, producer = @unbounded_without_exact_proof::@producer}
  }

  bitstream.pipeline @ordinary_elementwise {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%i] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @ordinary_elementwise_analysis for @ordinary_elementwise {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> {buffer = @ordinary_elementwise::@tmp, consumer = @ordinary_elementwise::@consumer, producer = @ordinary_elementwise::@producer}
  }

  bitstream.pipeline @plain_neighbor {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %k = bitstream.logical_index : index
      bitstream.write %tmp[%k] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %km1_expr = arith.subi %k, %c1 : index
      bitstream.read %tmp[%km1_expr] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%k] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @plain_neighbor_analysis for @plain_neighbor {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> {buffer = @plain_neighbor::@tmp, consumer = @plain_neighbor::@consumer, producer = @plain_neighbor::@producer}
  }
}

// CHECK-LABEL: bitstream.analysis @unbounded_without_exact_proof_analysis for @unbounded_without_exact_proof
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = false
// CHECK-SAME: reason = "predecessor dependency has no exact while-read ProjectState proof for buffer tmp"

// CHECK-LABEL: bitstream.analysis @ordinary_elementwise_analysis for @ordinary_elementwise
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK-SAME: reason = "all producer dependencies have finite byte windows; no finite-state proof is required"
// CHECK: bitstream.fused_kernel
// CHECK-SAME: strategy = elementwise

// CHECK-LABEL: bitstream.analysis @plain_neighbor_analysis for @plain_neighbor
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK-SAME: reason = "all producer dependencies have finite byte windows; no finite-state proof is required"
// CHECK: bitstream.fused_kernel
// CHECK-SAME: strategy = elementwise
