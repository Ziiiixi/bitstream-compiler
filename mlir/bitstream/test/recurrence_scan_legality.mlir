// RUN: bitstream-opt %s -bitstream-dependence-analysis -bitstream-dependency-classification -bitstream-finite-state-inference -bitstream-speculative-fusion | FileCheck %s

module {
  // A local recurrence may contain both iteration-varying and captured
  // invariant accesses.  Only the former denotes an unbounded access set for
  // one enclosing work item, and its recovered binary carried state proves the
  // edge finite-state reducible.
  bitstream.pipeline @local_xor_recurrence {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %captured = bitstream.logical_index : index
      bitstream.recurrence operator = "xor" attributes {initial_state = 0 : i64, state_domain = 2 : i64} {
        %i = bitstream.logical_index : index
        bitstream.read %tmp[%i] {access_id = "a1", bytes = 1 : i64} : !bitstream.buffer
        bitstream.read %tmp[%captured] {access_id = "a2", bytes = 1 : i64} : !bitstream.buffer
        bitstream.write %out[%i] {access_id = "a3", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
      }
    }
  }

  // A recovered global scan publishes its carried state directly.  Exact
  // ScanOp.state_domain and WriteOp.value_domain evidence is sufficient; the
  // consumer does not need a synthetic bitstream.project_state operation.
  bitstream.pipeline @direct_scan_state {
    %input = bitstream.buffer @input : !bitstream.buffer
    %prefix = bitstream.buffer @prefix : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @source {
      %i = bitstream.logical_index : index
      bitstream.write %input[%i] {access_id = "a0", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }

    bitstream.scan @xor_prefix operator = "xor" attributes {initial_state = 0 : i64, state_domain = 2 : i64} {
      %i = bitstream.logical_index : index
      bitstream.read %input[%i] {access_id = "a1", bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %prefix[%i] {access_id = "a2", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %prefix[%i] {access_id = "a3", bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %out[%i] {access_id = "a4", bytes = 1 : i64} : !bitstream.buffer
    }
  }

  // The read is lexically inside the inner recurrence but its address is
  // driven by the outer recurrence's coordinate.  Every pass must select the
  // outer domain rather than relying on the nearest parent marker.
  bitstream.pipeline @nested_outer_recurrence {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      bitstream.recurrence operator = "xor" attributes {state_domain = 2 : i64} {
        %outer = bitstream.logical_index : index
        bitstream.recurrence operator = "xor" attributes {state_domain = 3 : i64} {
          bitstream.read %tmp[%outer] {access_id = "a1", bytes = 1 : i64} : !bitstream.buffer
          bitstream.write %out[%outer] {access_id = "a2", bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
        }
      }
    }
  }
}

// CHECK-LABEL: bitstream.pipeline @local_xor_recurrence
// CHECK: bitstream.kernel @consumer
// CHECK: bitstream.state @state0 transition = xor
// CHECK-SAME: domain = 2
// CHECK: bitstream.recurrence operator = "xor"
// CHECK: bitstream.read {{.*}} dependency = prefix_state state = @state0 state_kind = carried_state
// CHECK-SAME: access_id = "a1"
// CHECK: bitstream.read
// CHECK-SAME: access_id = "a2"

// CHECK-LABEL: bitstream.analysis @local_xor_recurrence_analysis for @local_xor_recurrence
// CHECK: bitstream.dependency_group kind = "bounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a2" finite_state = none producer_byte_window =
// CHECK: bitstream.dependency_group kind = "unbounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven finite_state_domain = 2
// CHECK-NOT: producer_byte_window
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK: bitstream.fused_kernel @local_xor_recurrence_speculative_fusion_kernel strategy = decoupled_lookback

// CHECK-LABEL: bitstream.pipeline @direct_scan_state
// CHECK: bitstream.scan @xor_prefix operator = "xor"
// CHECK: bitstream.state @state1 transition = xor
// CHECK-SAME: domain = 2
// CHECK: bitstream.kernel @consumer
// CHECK: bitstream.state @state0 transition = prefix_state_projection
// CHECK-SAME: domain = 2
// CHECK: bitstream.read {{.*}} dependency = prefix_state state = @state0 state_kind = carried_state
// CHECK-SAME: access_id = "a3"
// CHECK-NOT: bitstream.project_state

// CHECK-LABEL: bitstream.analysis @direct_scan_state_analysis for @direct_scan_state
// CHECK: bitstream.dependency_group kind = "bounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window =
// CHECK: bitstream.dependency_group kind = "unbounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a2" consumer_access = "a3" finite_state = proven finite_state_domain = 2
// CHECK-NOT: producer_byte_window
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK: bitstream.fused_kernel @direct_scan_state_speculative_fusion_kernel strategy = decoupled_lookback

// CHECK-LABEL: bitstream.pipeline @nested_outer_recurrence
// CHECK: bitstream.kernel @consumer
// CHECK: bitstream.state @state0 transition = xor
// CHECK-SAME: domain = 2
// CHECK: bitstream.recurrence operator = "xor" attributes {state_domain = 2
// CHECK: bitstream.recurrence operator = "xor" attributes {state_domain = 3
// CHECK: bitstream.read {{.*}} dependency = prefix_state state = @state0 state_kind = carried_state
// CHECK-SAME: access_id = "a1"

// CHECK-LABEL: bitstream.analysis @nested_outer_recurrence_analysis for @nested_outer_recurrence
// CHECK: bitstream.dependency_group kind = "bounded"
// CHECK: bitstream.dependency_group kind = "unbounded"
// CHECK: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven finite_state_domain = 2
// CHECK-NOT: producer_byte_window
// CHECK: bitstream.fusion_candidate
// CHECK-SAME: legal = true
// CHECK: bitstream.fused_kernel @nested_outer_recurrence_speculative_fusion_kernel strategy = decoupled_lookback
