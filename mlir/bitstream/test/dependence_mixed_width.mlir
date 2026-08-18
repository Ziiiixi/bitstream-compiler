// RUN: bitstream-opt %s -bitstream-dependence-analysis -bitstream-dependency-classification | FileCheck %s

module {
  bitstream.pipeline @mixed_width_bitmap {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @byte_writer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @word_reader {
      %k = bitstream.logical_index : index
      bitstream.read %tmp[%k] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @mixed_width_shifted_bitmap {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @byte_writer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @word_reader {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %km1_expr = arith.subi %k, %c1 : index
      bitstream.read %tmp[%km1_expr] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }
}

// CHECK: [[WORD_WINDOW:#[a-zA-Z0-9_]+]] = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
// CHECK: bitstream.write {{.*}}access_id = "a0"
// CHECK: bitstream.read {{.*}}access_id = "a1"
// CHECK: bitstream.analysis @mixed_width_bitmap_analysis for @mixed_width_bitmap
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @mixed_width_bitmap::@tmp
// CHECK-SAME: consumer = @mixed_width_bitmap::@word_reader
// CHECK-SAME: producer = @mixed_width_bitmap::@byte_writer

// CHECK: bitstream.analysis @mixed_width_shifted_bitmap_analysis for @mixed_width_shifted_bitmap
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: buffer = @mixed_width_shifted_bitmap::@tmp
// CHECK-SAME: consumer = @mixed_width_shifted_bitmap::@word_reader
// CHECK-SAME: producer = @mixed_width_shifted_bitmap::@byte_writer
