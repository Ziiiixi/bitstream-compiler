// RUN: bitstream-opt %s -bitstream-recover-access-graph | FileCheck %s

// Polygeist-shaped scalar SSA loops exercising the three recovery decisions:
// a state recurrence nested in a scheduling loop, a scheduler-independent
// prefix recurrence, and an ordinary coordinate-only elementwise loop.
module {
  func.func @driver(%input: memref<?xi1>, %partial: memref<?xi1>,
                    %base: memref<?xi1>, %rebased: memref<?xi1>,
                    %words: memref<?xi64>, %word_state: memref<?xi64>,
                    %n: index) {
    call @local_xor(%input, %partial, %n)
        : (memref<?xi1>, memref<?xi1>, index) -> ()
    call @global_xor(%partial, %base, %n)
        : (memref<?xi1>, memref<?xi1>, index) -> ()
    call @ordinary_rebase(%partial, %base, %rebased, %n)
        : (memref<?xi1>, memref<?xi1>, memref<?xi1>, index) -> ()
    call @local_projected_xor(%words, %word_state, %n)
        : (memref<?xi64>, memref<?xi64>, index) -> ()
    call @local_two_xor(%input, %partial, %base, %n)
        : (memref<?xi1>, memref<?xi1>, memref<?xi1>, index) -> ()
    return
  }

  func.func @local_xor(%input: memref<?xi1>, %partial: memref<?xi1>,
                       %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %false = arith.constant false
    // The outer loop is the scheduling coordinate.  The nested while carries
    // a separate XOR state and therefore remains a local recurrence region.
    scf.for %schedule = %c0 to %n step %c1 {
      %end = arith.addi %schedule, %c1 : index
      %result:2 = scf.while (%i = %schedule, %state = %false)
          : (index, i1) -> (index, i1) {
        %inside = arith.cmpi slt, %i, %end : index
        scf.condition(%inside) %i, %state : index, i1
      } do {
      ^bb0(%i_after: index, %state_after: i1):
        %value = memref.load %input[%i_after] : memref<?xi1>
        %next_state = arith.xori %state_after, %value : i1
        memref.store %next_state, %partial[%i_after] : memref<?xi1>
        %next_i = arith.addi %i_after, %c1 : index
        scf.yield %next_i, %next_state : index, i1
      }
    }
    return
  }

  func.func @global_xor(%partial: memref<?xi1>, %base: memref<?xi1>,
                        %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %false = arith.constant false
    %result = scf.for %i = %c0 to %n step %c1
        iter_args(%state = %false) -> (i1) {
      memref.store %state, %base[%i] : memref<?xi1>
      %value = memref.load %partial[%i] : memref<?xi1>
      %next_state = arith.xori %state, %value : i1
      scf.yield %next_state : i1
    }
    memref.store %result, %base[%n] : memref<?xi1>
    return
  }

  func.func @ordinary_rebase(%partial: memref<?xi1>, %base: memref<?xi1>,
                             %rebased: memref<?xi1>, %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    scf.for %i = %c0 to %n step %c1 {
      %lhs = memref.load %partial[%i] : memref<?xi1>
      %rhs = memref.load %base[%i] : memref<?xi1>
      %value = arith.xori %lhs, %rhs : i1
      memref.store %value, %rebased[%i] : memref<?xi1>
    }
    return
  }

  // A word-at-a-time recurrence may project the XOR result to the high bit
  // carried into the next local iteration.  The carried state is binary even
  // though the loaded and stored words are i64.
  func.func @local_projected_xor(%input: memref<?xi64>,
                                 %state_out: memref<?xi64>, %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %zero = arith.constant 0 : i64
    %c63 = arith.constant 63 : i64
    scf.for %schedule = %c0 to %n step %c1 {
      %end = arith.addi %schedule, %c1 : index
      %result:2 = scf.while (%i = %schedule, %state = %zero)
          : (index, i64) -> (index, i64) {
        %inside = arith.cmpi slt, %i, %end : index
        scf.condition(%inside) %i, %state : index, i64
      } do {
      ^bb0(%i_after: index, %state_after: i64):
        %word = memref.load %input[%i_after] : memref<?xi64>
        %prefix = arith.xori %state_after, %word : i64
        %next_state = arith.shrui %prefix, %c63 : i64
        memref.store %next_state, %state_out[%i_after] : memref<?xi64>
        %next_i = arith.addi %i_after, %c1 : index
        scf.yield %next_i, %next_state : index, i64
      }
    }
    return
  }

  // Two carried XOR lanes in the same source loop are a tuple recurrence.
  // They must not be reconstructed as two artificially nested loops, and a
  // scalar domain-2 proof is insufficient for their joint state.
  func.func @local_two_xor(%input: memref<?xi1>, %first: memref<?xi1>,
                           %second: memref<?xi1>, %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %false = arith.constant false
    scf.for %schedule = %c0 to %n step %c1 {
      %end = arith.addi %schedule, %c1 : index
      %result:3 = scf.while (%i = %schedule, %left = %false,
                             %right = %false)
          : (index, i1, i1) -> (index, i1, i1) {
        %inside = arith.cmpi slt, %i, %end : index
        scf.condition(%inside) %i, %left, %right : index, i1, i1
      } do {
      ^bb0(%i_after: index, %left_after: i1, %right_after: i1):
        %value = memref.load %input[%i_after] : memref<?xi1>
        %next_left = arith.xori %left_after, %value : i1
        %next_right = arith.xori %right_after, %value : i1
        memref.store %next_left, %first[%i_after] : memref<?xi1>
        memref.store %next_right, %second[%i_after] : memref<?xi1>
        %next_i = arith.addi %i_after, %c1 : index
        scf.yield %next_i, %next_left, %next_right : index, i1, i1
      }
    }
    return
  }
}

// CHECK-LABEL: bitstream.kernel @local_xor
// CHECK: bitstream.recurrence operator = "xor"
// CHECK-SAME: initial_state = 0 : i64
// CHECK-SAME: state_domain = 2 : i64
// CHECK: %[[LOCAL:[0-9]+]] = bitstream.logical_index : index
// CHECK: bitstream.read {{.*}}[%[[LOCAL]]]
// CHECK: bitstream.write {{.*}}[%[[LOCAL]]]
// CHECK-SAME: value_domain = 2 : i64

// The independent scf.for iter_arg is the stage-wide serial prefix scan.
// CHECK-LABEL: bitstream.scan @global_xor operator = "xor"
// CHECK-SAME: initial_state = 0 : i64
// CHECK-SAME: state_domain = 2 : i64
// CHECK: bitstream.write
// CHECK-SAME: value_domain = 2 : i64
// CHECK: bitstream.read
// CHECK: bitstream.write
// CHECK-SAME: tail_boundary_write
// CHECK-SAME: value_domain = 2 : i64

// An elementwise XOR without a carried state is not a recurrence or scan.
// CHECK-LABEL: bitstream.kernel @ordinary_rebase
// CHECK-NOT: bitstream.recurrence
// CHECK: bitstream.read
// CHECK: bitstream.read
// CHECK: bitstream.write

// Projecting an i64 XOR prefix to its high bit still proves domain 2.
// CHECK-LABEL: bitstream.kernel @local_projected_xor
// CHECK: bitstream.recurrence operator = "xor"
// CHECK-SAME: initial_state = 0 : i64
// CHECK-SAME: state_domain = 2 : i64
// CHECK: %[[PROJECTED_INDEX:[0-9]+]] = bitstream.logical_index : index
// CHECK: bitstream.read {{.*}}[%[[PROJECTED_INDEX]]]
// CHECK: bitstream.write {{.*}}[%[[PROJECTED_INDEX]]]
// CHECK-SAME: value_domain = 2 : i64

// Same-loop lanes are represented once and left domainless until tuple state
// has an explicit IR representation.
// CHECK-LABEL: bitstream.kernel @local_two_xor
// CHECK-NEXT: bitstream.recurrence operator = "tuple"
// CHECK-NOT: state_domain
// CHECK: %[[TUPLE_INDEX:[0-9]+]] = bitstream.logical_index : index
// CHECK: bitstream.read {{.*}}[%[[TUPLE_INDEX]]]
// CHECK: bitstream.write {{.*}}[%[[TUPLE_INDEX]]]
// CHECK: bitstream.write {{.*}}[%[[TUPLE_INDEX]]]
// CHECK-NOT: bitstream.recurrence
