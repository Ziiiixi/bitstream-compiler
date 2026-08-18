// RUN: bitstream-opt %s -bitstream-recover-access-graph | FileCheck %s

// The source spelling is intentionally generic.  Recovery recognizes the
// second store as the loop's boundary flush because it stores the loop result
// to the same buffer and width as the steady store inside the loop.
module {
  func.func @driver(%output: memref<?xi8>, %n: index) {
    call @chunked_writer(%output, %n) : (memref<?xi8>, index) -> ()
    call @second_loop_writer(%output, %n) : (memref<?xi8>, index) -> ()
    return
  }

  func.func @chunked_writer(%output: memref<?xi8>, %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %zero = arith.constant 0 : i8
    %one = arith.constant 1 : i8
    %final = scf.for %i = %c0 to %n step %c1
        iter_args(%state = %zero) -> (i8) {
      memref.store %state, %output[%i] : memref<?xi8>
      %next = arith.addi %state, %one : i8
      scf.yield %next : i8
    }
    memref.store %final, %output[%n] : memref<?xi8>
    return
  }

  // A later loop may consume an earlier loop's result.  It is a repeated
  // computation, not a one-shot boundary flush.
  func.func @second_loop_writer(%output: memref<?xi8>, %n: index) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %zero = arith.constant 0 : i8
    %one = arith.constant 1 : i8
    %final = scf.for %i = %c0 to %n step %c1
        iter_args(%state = %zero) -> (i8) {
      memref.store %state, %output[%i] : memref<?xi8>
      %next = arith.addi %state, %one : i8
      scf.yield %next : i8
    }
    scf.for %j = %c0 to %n step %c1 {
      memref.store %final, %output[%n] : memref<?xi8>
    }
    return
  }
}

// CHECK-LABEL: bitstream.kernel @chunked_writer
// CHECK: bitstream.write
// CHECK-SAME: bytes = 1 : i64
// CHECK-NOT: tail_boundary_write
// CHECK: bitstream.write
// CHECK-SAME: bytes = 1 : i64
// CHECK-SAME: tail_boundary_write

// CHECK-LABEL: bitstream.kernel @second_loop_writer
// CHECK: bitstream.write
// CHECK-NOT: tail_boundary_write
// CHECK: bitstream.write
// CHECK-NOT: tail_boundary_write
