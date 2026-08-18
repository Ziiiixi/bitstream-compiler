// RUN: bitstream-opt %s -bitstream-finite-state-inference -bitstream-speculative-fusion | FileCheck %s

module {
  bitstream.pipeline @pack_popcount {
    %bitmap = bitstream.buffer @bitmap : !bitstream.buffer
    %count = bitstream.buffer @count : !bitstream.buffer

    bitstream.kernel @byte_producer {
      %i = bitstream.logical_index : index
      bitstream.write %bitmap[%i] {access_id = "a0", bytes = 1 : i64} : !bitstream.buffer
    }

    bitstream.kernel @popcount_consumer {
      %k = bitstream.logical_index : index
      bitstream.read %bitmap[%k] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      bitstream.project_state %bitmap[%k] {domain = 33 : i64, modulus = 33 : i64, projected_bits = 6 : i64, projection_kind = "popcount", read_access = "a1"} : !bitstream.buffer
      bitstream.write %count[%k] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @pack_popcount_analysis for @pack_popcount {
    // Repacking four produced bytes into one word has the explicit finite byte
    // window carried by this bounded edge. The exact ProjectState link is
    // retained as an explicit proof when inference succeeds, while fusion
    // legality and strategy remain determined by the finite byte window.
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> {buffer = @pack_popcount::@bitmap, consumer = @pack_popcount::@popcount_consumer, producer = @pack_popcount::@byte_producer}
  }
}

// CHECK: [[WORD_WINDOW:#[a-zA-Z0-9_]+]] = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
// CHECK-LABEL: bitstream.kernel @popcount_consumer
// CHECK: bitstream.state @state0 transition = projected_state
// CHECK-SAME: domain = 33
// CHECK: bitstream.read
// CHECK-SAME: access_id = "a1"
// CHECK: bitstream.project_state
// CHECK-SAME: read_access = "a1"

// CHECK-LABEL: bitstream.analysis @pack_popcount_analysis
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven producer_byte_window = [[WORD_WINDOW]]
// CHECK-SAME: finite_state_domain = 33
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK: bitstream.fused_kernel
// CHECK-SAME: strategy = elementwise
