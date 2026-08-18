// RUN: bitstream-opt %s -bitstream-recover-access-graph | FileCheck %s

// This is a compact Polygeist-shaped regression for three distinct index
// classes.  The +1 data coordinate is lane 1 before the outer while and lane
// 2 after its condition permutation.  A nested +1 sweep is independently
// recognized.  The -1 predecessor walk must remain an scf.while instead of
// being collapsed to the logical coordinate.
module {
  func.func @driver(%input: memref<?xi32>, %walk_input: memref<?xi32>,
                    %outer_output: memref<?xi32>,
                    %nested_output: memref<?xi32>, %n: index,
                    %keep_going: i1) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c4 = arith.constant 4 : index
    %c-1_i32 = arith.constant -1 : i32
    %c1_i32 = arith.constant 1 : i32
    scf.for %schedule = %c0 to %n step %c1 {
      %outer:3 = scf.while (%state0 = %c0, %k = %schedule,
                            %state2 = %c0)
          : (index, index, index) -> (index, index, index) {
        // Permute the carried values: k moves from before lane 1 to after
        // lane 2.  The update still returns to before lane 1.
        scf.condition(%keep_going) %state2, %state0, %k
            : index, index, index
      } do {
      ^bb0(%state2_after: index, %state0_after: index, %k_after: index):
        %zero_value = arith.constant 0 : i32
        memref.store %zero_value, %outer_output[%k_after] : memref<?xi32>

        // A second +1 data sweep nested in the outer convergence loop.
        %nested = scf.while (%q = %schedule) : (index) -> index {
          scf.condition(%keep_going) %q : index
        } do {
        ^bb0(%q_after: index):
          memref.store %zero_value, %nested_output[%q_after] : memref<?xi32>
          %q_next = arith.addi %q_after, %c1 : index
          scf.yield %q_next : index
        }

        // Division and remainder are retained as typed SSA expressions.
        %word = arith.divsi %k_after, %c4 : index
        %lane = arith.remsi %k_after, %c4 : index
        %packed = arith.addi %word, %lane : index
        %sample = memref.load %input[%packed] : memref<?xi32>

        // This is not a forward data coordinate.  Recovery must preserve its
        // loop-carried -1 access set explicitly.
        %j0 = arith.subi %k_after, %c1 : index
        %walk = scf.while (%j = %j0) : (index) -> index {
          %inside = arith.cmpi sge, %j, %c0 : index
          scf.condition(%inside) %j : index
        } do {
        ^bb0(%j_after: index):
          %previous = memref.load %walk_input[%j_after] : memref<?xi32>
          // The source value is consumed only through a finite overflow/parity
          // projection. Recovery must keep this proof beside the dynamic read.
          %inverted = arith.xori %previous, %c-1_i32 : i32
          %leading = math.ctlz %inverted : i32
          %parity = arith.andi %leading, %c1_i32 : i32
          %j_next = arith.subi %j_after, %c1 : index
          scf.yield %j_next : index
        }

        %k_next = arith.addi %k_after, %c1 : index
        scf.yield %state0_after, %k_next, %state2_after
            : index, index, index
      }
    }
    return
  }
}

// CHECK: bitstream.pipeline @driver_polygeist_raised
// CHECK: bitstream.kernel @polygeist_stage0
// CHECK: %[[LOGICAL:[0-9]+]] = bitstream.logical_index : index

// Both structurally proven +1 coordinates lower to the same stage coordinate.
// CHECK: bitstream.write {{.*}}[%[[LOGICAL]]]
// CHECK: bitstream.write {{.*}}[%[[LOGICAL]]]

// Signed division and remainder survive materialization and feed a read.
// CHECK: %[[DIV:.*]] = arith.divsi %[[LOGICAL]], %{{.*}} : index
// CHECK: %[[REM:.*]] = arith.remsi %[[LOGICAL]], %{{.*}} : index
// CHECK: %[[PACKED:.*]] = arith.addi %[[DIV]], %[[REM]] : index
// CHECK: bitstream.read {{.*}}[%[[PACKED]]]

// The predecessor walk remains explicit and its read uses the while-carried
// block argument, not the logical coordinate directly.
// CHECK: %[[SEED:.*]] = arith.subi %[[LOGICAL]], %{{.*}} : index
// CHECK: %{{.*}} = scf.while (%[[WALK:.*]] = %[[SEED]]) : (index) -> index
// CHECK: ^bb0(%[[J:.*]]: index):
// CHECK: bitstream.read {{.*}}[%[[J]]]
// CHECK: bitstream.project_state {{.*}}[%[[J]]]
// CHECK-SAME: domain = 2
// CHECK-SAME: projection_kind = "ssa_not_ctlz_low_bit"
// CHECK-SAME: read_access = "a{{[0-9]+}}"
// CHECK: %[[NEXT:.*]] = arith.subi %[[J]], %{{.*}} : index
// CHECK: scf.yield %[[NEXT]] : index
