// RUN: bitstream-opt %s -bitstream-dependence-analysis | FileCheck %s

module {
  // A tail flush must not replace the steady write as the representative
  // producer for a later recurrence-varying read.
  bitstream.pipeline @steady_and_tail {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "steady", bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %tmp[%i] {access_id = "tail", bytes = 1 : i64, tail_boundary_write} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      bitstream.recurrence operator = "xor" {
        %j = bitstream.logical_index : index
        bitstream.read %tmp[%j] {access_id = "read", bytes = 1 : i64} : !bitstream.buffer
      }
    }
  }

  // Conversely, a boundary write is still the producer when the current
  // stage has no steady write.  It must not be skipped in favor of an older
  // stage's write.
  bitstream.pipeline @tail_only_stage {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @old_producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "old", bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @tail_producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "only_tail", bytes = 1 : i64, tail_boundary_write} : !bitstream.buffer
    }

    bitstream.kernel @tail_consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "tail_read", bytes = 1 : i64} : !bitstream.buffer
    }
  }
}

// CHECK-LABEL: bitstream.analysis @steady_and_tail_analysis
// CHECK: bitstream.dependency memory = raw producer_access = "steady" consumer_access = "read"
// CHECK-SAME: producer = @steady_and_tail::@producer
// CHECK-NOT: producer_access = "tail"

// CHECK-LABEL: bitstream.analysis @tail_only_stage_analysis
// CHECK: bitstream.dependency memory = raw producer_access = "only_tail" consumer_access = "tail_read"
// CHECK-SAME: producer = @tail_only_stage::@tail_producer
