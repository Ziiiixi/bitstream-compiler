// RUN: bitstream-opt %s -bitstream-dependence-analysis -bitstream-dependency-classification | FileCheck %s

module {
  bitstream.pipeline @toy_bounded_neighbor {
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

  bitstream.pipeline @scan_output_is_global_prefix {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.scan @prefix operator = "add" {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i0 = bitstream.logical_index : index
      bitstream.read %tmp[%i0] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%i0] {bytes = 4 : i64} : !bitstream.buffer
    }
  }
}

// CHECK: [[WORD_WINDOW:#[a-zA-Z0-9_]+]] = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
// CHECK: bitstream.write {{.*}}access_id = "a0"
// CHECK: bitstream.read {{.*}}access_id = "a1"
// CHECK: bitstream.analysis @toy_bounded_neighbor_analysis for @toy_bounded_neighbor
// CHECK: bitstream.dependency_group kind = "bounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @toy_bounded_neighbor::@tmp
// CHECK-SAME: consumer = @toy_bounded_neighbor::@consumer
// CHECK-SAME: producer = @toy_bounded_neighbor::@producer

// CHECK: bitstream.analysis @scan_output_is_global_prefix_analysis for @scan_output_is_global_prefix
// CHECK: bitstream.dependency_group kind = "bounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: consumer = @scan_output_is_global_prefix::@prefix
// CHECK-SAME: producer = @scan_output_is_global_prefix::@producer
// CHECK: bitstream.dependency_group kind = "unbounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a2" consumer_access = "a3" finite_state = none
// CHECK-SAME: consumer = @scan_output_is_global_prefix::@consumer
// CHECK-SAME: producer = @scan_output_is_global_prefix::@prefix
// CHECK-NOT: producer_byte_window
