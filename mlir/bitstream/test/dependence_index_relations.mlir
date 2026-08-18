// RUN: bitstream-opt %s -bitstream-dependence-analysis -bitstream-dependency-classification | FileCheck %s

module {
  bitstream.pipeline @same_access {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%i] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @fixed_offset {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      %c2 = arith.constant 2 : index
      %idx_expr = arith.muli %i, %c2 : index
      bitstream.write %tmp[%idx_expr] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      %c2 = arith.constant 2 : index
      %base_expr = arith.muli %i, %c2 : index
      %c4 = arith.constant 4 : index
      %idx_expr = arith.addi %base_expr, %c4 : index
      bitstream.read %tmp[%idx_expr] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%idx_expr] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @plain_neighbor {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %k = bitstream.logical_index : index
      bitstream.write %tmp[%k] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %km1_expr = arith.subi %k, %c1 : index
      bitstream.read %tmp[%km1_expr] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @explicit_byte_index {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {byte_index = affine_map<(d0) -> (d0 * 8)>, bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {byte_index = affine_map<(d0) -> (d0 * 8 + 4)>, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%i] {byte_index = affine_map<(d0) -> (d0 * 4)>, bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @duplicate_reads_keep_distinct_ids {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {byte_index = affine_map<(d0) -> (d0 * 4)>, bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {byte_index = affine_map<(d0) -> (d0 * 4)>, bytes = 4 : i64} : !bitstream.buffer
      bitstream.read %tmp[%i] {byte_index = affine_map<(d0) -> (d0 * 4)>, bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @while_carried_index_is_unbounded {
    %input = bitstream.buffer @input : !bitstream.buffer

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %j0 = arith.subi %i, %c1 : index
      %unused = scf.while (%j = %j0) : (index) -> index {
        %c0 = arith.constant 0 : index
        %inside = arith.cmpi sge, %j, %c0 : index
        scf.condition(%inside) %j : index
      } do {
      ^bb0(%j: index):
        bitstream.read %input[%j] {byte_index = affine_map<(d0) -> (d0 * 4)>, bytes = 4 : i64} : !bitstream.buffer
        %step = arith.constant 1 : index
        %next = arith.subi %j, %step : index
        scf.yield %next : index
      }
    }
  }
}

// CHECK: [[WORD_WINDOW:#[a-zA-Z0-9_]+]] = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
// CHECK: [[EXPLICIT_WINDOW:#[a-zA-Z0-9_]+]] = affine_map<(d0) -> (d0 * 8 + 4, d0 * 8 + 8)>
// CHECK: bitstream.write {{.*}}access_id = "a0"
// CHECK: bitstream.read {{.*}}access_id = "a1"
// CHECK: bitstream.analysis @same_access_analysis for @same_access
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @same_access::@tmp
// CHECK-SAME: consumer = @same_access::@consumer
// CHECK-SAME: producer = @same_access::@producer

// CHECK: bitstream.analysis @fixed_offset_analysis for @fixed_offset
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @fixed_offset::@tmp
// CHECK-SAME: consumer = @fixed_offset::@consumer
// CHECK-SAME: producer = @fixed_offset::@producer

// CHECK: bitstream.analysis @plain_neighbor_analysis for @plain_neighbor
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @plain_neighbor::@tmp
// CHECK-SAME: consumer = @plain_neighbor::@consumer
// CHECK-SAME: producer = @plain_neighbor::@producer

// CHECK: bitstream.analysis @explicit_byte_index_analysis for @explicit_byte_index
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[EXPLICIT_WINDOW]]
// CHECK-SAME: buffer = @explicit_byte_index::@tmp

// CHECK: bitstream.analysis @duplicate_reads_keep_distinct_ids_analysis for @duplicate_reads_keep_distinct_ids
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a2" finite_state = none producer_byte_window = [[WORD_WINDOW]]

// CHECK: bitstream.analysis @while_carried_index_is_unbounded_analysis for @while_carried_index_is_unbounded
// CHECK: bitstream.dependency memory = input consumer_access = "a0" finite_state = none
// CHECK-SAME: buffer = @while_carried_index_is_unbounded::@input
// CHECK-NOT: producer_byte_window
