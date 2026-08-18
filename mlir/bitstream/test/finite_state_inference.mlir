// RUN: bitstream-opt %s -bitstream-dependence-analysis -bitstream-dependency-classification -bitstream-finite-state-inference | FileCheck %s --check-prefix=GRAPH

module {
  bitstream.pipeline @neighbor_is_not_state {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @consumer {
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %km1_expr = arith.subi %k, %c1 : index
      bitstream.read %tmp[%km1_expr] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.read %tmp[%k] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @scalar_low_bit_predecessor_is_state {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
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
        bitstream.project_state %tmp[%j] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "scalar_low_bit", read_access = "a1"} : !bitstream.buffer
        %next = arith.subi %j, %c1 : index
        scf.yield %next : index
      }
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @projection_with_exact_escape_is_not_state {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
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
        bitstream.project_state %tmp[%j] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "scalar_low_bit", read_access = "a1"} : !bitstream.buffer
        bitstream.read %tmp[%j] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
        %next = arith.subi %j, %c1 : index
        scf.yield %next : index
      }
      bitstream.write %out[%k] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @scan_projection_is_state {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @source {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.scan @prefix operator = "add" {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %tmp[%i] {bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a3", bytes = 4 : i64} : !bitstream.buffer
      bitstream.project_state %tmp[%i] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "low_bit", read_access = "a3"} : !bitstream.buffer
      bitstream.write %out[%i] {bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.pipeline @bounded_projection_is_proven {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    %out = bitstream.buffer @out : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      bitstream.project_state %tmp[%i] {domain = 3 : i64, modulus = 3 : i64, projection_kind = "mod3", read_access = "a1"} : !bitstream.buffer
      bitstream.write %out[%i] {access_id = "a2", bytes = 4 : i64} : !bitstream.buffer
    }
  }
}

// GRAPH-LABEL: bitstream.pipeline @neighbor_is_not_state
// GRAPH-NOT: neighbor_finite_state
// GRAPH-NOT: data_dependent_predecessor

// GRAPH-LABEL: bitstream.pipeline @scalar_low_bit_predecessor_is_state
// GRAPH: bitstream.state @state0 transition = neighbor_finite_state
// GRAPH-SAME: distance = 1
// GRAPH: bitstream.read {{.*}} dependency = data_dependent_predecessor state = @state0 state_kind = neighbor_finite_state

// GRAPH-LABEL: bitstream.analysis @scalar_low_bit_predecessor_is_state_analysis
// GRAPH: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven
// GRAPH-SAME: finite_state_domain = 2
// GRAPH-SAME: states = [@scalar_low_bit_predecessor_is_state::@consumer::@state0]

// GRAPH-LABEL: bitstream.pipeline @projection_with_exact_escape_is_not_state
// GRAPH: bitstream.state @state0 transition = neighbor_finite_state
// GRAPH: bitstream.read {{.*}} dependency = data_dependent_predecessor state = @state0 state_kind = neighbor_finite_state
// GRAPH-SAME: access_id = "a1"
// GRAPH: bitstream.read
// GRAPH-SAME: access_id = "a2"

// GRAPH-LABEL: bitstream.analysis @projection_with_exact_escape_is_not_state_analysis
// GRAPH: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven
// GRAPH-SAME: finite_state_domain = 2
// GRAPH-SAME: states = [@projection_with_exact_escape_is_not_state::@consumer::@state0]
// GRAPH: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a2" finite_state = none
// GRAPH-NOT: finite_state_domain
// GRAPH-NOT: states =

// GRAPH-LABEL: bitstream.pipeline @scan_projection_is_state
// GRAPH: bitstream.state @state1 transition = add_mod
// GRAPH: bitstream.state @state0 transition = prefix_state_projection
// GRAPH: bitstream.read {{.*}} dependency = prefix_state state = @state0 state_kind = finite_state_projection

// GRAPH-LABEL: bitstream.analysis @scan_projection_is_state_analysis
// GRAPH: bitstream.dependency memory = raw producer_access = "a2" consumer_access = "a3" finite_state = proven
// GRAPH-SAME: finite_state_domain = 2
// GRAPH-SAME: states = [@scan_projection_is_state::@prefix::@state1, @scan_projection_is_state::@consumer::@state0]

// GRAPH-LABEL: bitstream.pipeline @bounded_projection_is_proven
// GRAPH: bitstream.state @state0 transition = projected_state
// GRAPH-SAME: domain = 3
// GRAPH: bitstream.read {{.*}} dependency = projected_state state = @state0 state_kind = projected_state

// GRAPH-LABEL: bitstream.analysis @bounded_projection_is_proven_analysis
// GRAPH: bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven producer_byte_window =
// GRAPH-SAME: finite_state_domain = 3
// GRAPH-SAME: states = [@bounded_projection_is_proven::@consumer::@state0]
