module attributes {dlti.dl_spec = #dlti.dl_spec<#dlti.dl_entry<i8, dense<8> : vector<2xi32>>, #dlti.dl_entry<i16, dense<16> : vector<2xi32>>, #dlti.dl_entry<i32, dense<32> : vector<2xi32>>, #dlti.dl_entry<f16, dense<16> : vector<2xi32>>, #dlti.dl_entry<f64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f128, dense<128> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr<271>, dense<32> : vector<4xi32>>, #dlti.dl_entry<!llvm.ptr<272>, dense<64> : vector<4xi32>>, #dlti.dl_entry<!llvm.ptr<270>, dense<32> : vector<4xi32>>, #dlti.dl_entry<i64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f80, dense<128> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi32>>, #dlti.dl_entry<i1, dense<8> : vector<2xi32>>, #dlti.dl_entry<"dlti.endianness", "little">, #dlti.dl_entry<"dlti.stack_alignment", 128 : i32>>, llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128", llvm.target_triple = "x86_64-unknown-linux-gnu", "polygeist.target-cpu" = "x86-64", "polygeist.target-features" = "+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87", "polygeist.tune-cpu" = "generic"} {
  memref.global @gridDim : memref<1x1xi32> = uninitialized
  memref.global @threadIdx : memref<1x1xi32> = uninitialized
  memref.global @blockDim : memref<1x1xi32> = uninitialized
  memref.global @blockIdx : memref<1x1xi32> = uninitialized
  func.func @gpjson_driver(%arg0: memref<?xi8>, %arg1: i32, %arg2: memref<?xi8>, %arg3: memref<?xi64>, %arg4: memref<?xi64>, %arg5: memref<?xi8>, %arg6: memref<?xi8>, %arg7: memref<?xi64>, %arg8: i32, %arg9: i32, %arg10: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    call @_Z19gpjson_escape_carryPciS_(%arg0, %arg1, %arg2) : (memref<?xi8>, i32, memref<?xi8>) -> ()
    %0 = arith.extsi %arg1 : i32 to i64
    call @_Z19gpjson_escape_indexPclPbPl(%arg0, %0, %arg2, %arg3) : (memref<?xi8>, i64, memref<?xi8>, memref<?xi64>) -> ()
    call @_Z18gpjson_quote_indexPciPlS0_S_(%arg0, %arg1, %arg3, %arg4, %arg5) : (memref<?xi8>, i32, memref<?xi64>, memref<?xi64>, memref<?xi8>) -> ()
    call @_Z19gpjson_xor_pre_scanPci(%arg5, %arg9) : (memref<?xi8>, i32) -> ()
    call @_Z20gpjson_xor_post_scanPciiS_(%arg5, %arg9, %arg10, %arg6) : (memref<?xi8>, i32, i32, memref<?xi8>) -> ()
    call @_Z17gpjson_xor_rebasePciS_(%arg5, %arg9, %arg6) : (memref<?xi8>, i32, memref<?xi8>) -> ()
    call @_Z19gpjson_string_indexPliPc(%arg4, %arg8, %arg5) : (memref<?xi64>, i32, memref<?xi8>) -> ()
    call @_Z24gpjson_structural_bitmapPciPlS0_(%arg0, %arg1, %arg4, %arg7) : (memref<?xi8>, i32, memref<?xi64>, memref<?xi64>) -> ()
    return
  }
  func.func @_Z19gpjson_escape_carryPciS_(%arg0: memref<?xi8>, %arg1: i32, %arg2: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c63_i32 = arith.constant 63 : i32
    %c-1_i32 = arith.constant -1 : i32
    %c92_i32 = arith.constant 92 : i32
    %false = arith.constant false
    %c0_i32 = arith.constant 0 : i32
    %c64_i32 = arith.constant 64 : i32
    %c1_i32 = arith.constant 1 : i32
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = affine.load %0[0, 0] : memref<1x1xi32>
    %2 = memref.get_global @blockDim : memref<1x1xi32>
    %3 = affine.load %2[0, 0] : memref<1x1xi32>
    %4 = arith.muli %1, %3 : i32
    %5 = memref.get_global @threadIdx : memref<1x1xi32>
    %6 = affine.load %5[0, 0] : memref<1x1xi32>
    %7 = arith.addi %4, %6 : i32
    %8 = memref.get_global @gridDim : memref<1x1xi32>
    %9 = affine.load %8[0, 0] : memref<1x1xi32>
    %10 = arith.muli %3, %9 : i32
    %11 = arith.addi %arg1, %10 : i32
    %12 = arith.addi %11, %c-1_i32 : i32
    %13 = arith.divsi %12, %10 : i32
    %14 = arith.addi %13, %c63_i32 : i32
    %15 = arith.divsi %14, %c64_i32 : i32
    %16 = arith.muli %15, %c64_i32 : i32
    %17 = arith.muli %7, %16 : i32
    %18 = arith.addi %17, %16 : i32
    %19:2 = scf.while (%arg3 = %17, %arg4 = %c0_i32) : (i32, i32) -> (i32, i32) {
      %23 = arith.cmpi slt, %arg3, %18 : i32
      %24 = scf.if %23 -> (i1) {
        %25 = arith.cmpi slt, %arg3, %arg1 : i32
        scf.yield %25 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%24) %arg4, %arg3 : i32, i32
    } do {
    ^bb0(%arg3: i32, %arg4: i32):
      %23 = arith.index_cast %arg4 : i32 to index
      %24 = "polygeist.subindex"(%arg0, %23) : (memref<?xi8>, index) -> memref<?xi8>
      %25 = affine.load %24[0] : memref<?xi8>
      %26 = arith.extsi %25 : i8 to i32
      %27 = arith.cmpi eq, %26, %c92_i32 : i32
      %28 = scf.if %27 -> (i32) {
        %30 = arith.xori %arg3, %c1_i32 : i32
        scf.yield %30 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %29 = arith.addi %arg4, %c1_i32 : i32
      scf.yield %29, %28 : i32, i32
    }
    %20 = arith.index_cast %7 : i32 to index
    %21 = "polygeist.subindex"(%arg2, %20) : (memref<?xi8>, index) -> memref<?xi8>
    %22 = arith.trunci %19#0 : i32 to i8
    affine.store %22, %21[0] : memref<?xi8>
    return
  }
  func.func @_Z19gpjson_escape_indexPclPbPl(%arg0: memref<?xi8>, %arg1: i64, %arg2: memref<?xi8>, %arg3: memref<?xi64>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c63_i32 = arith.constant 63 : i32
    %c0 = arith.constant 0 : index
    %c-1_i32 = arith.constant -1 : i32
    %c-1_i64 = arith.constant -1 : i64
    %c63_i64 = arith.constant 63 : i64
    %c92_i32 = arith.constant 92 : i32
    %c64_i64 = arith.constant 64 : i64
    %false = arith.constant false
    %c0_i64 = arith.constant 0 : i64
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c64_i32 = arith.constant 64 : i32
    %c1_i64 = arith.constant 1 : i64
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = "polygeist.subindex"(%0, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %2 = "polygeist.subindex"(%1, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %3 = affine.load %2[0] : memref<?xi32>
    %4 = memref.get_global @blockDim : memref<1x1xi32>
    %5 = "polygeist.subindex"(%4, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %6 = "polygeist.subindex"(%5, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %7 = affine.load %6[0] : memref<?xi32>
    %8 = arith.muli %3, %7 : i32
    %9 = memref.get_global @threadIdx : memref<1x1xi32>
    %10 = "polygeist.subindex"(%9, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %11 = "polygeist.subindex"(%10, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %12 = affine.load %11[0] : memref<?xi32>
    %13 = arith.addi %8, %12 : i32
    %14 = affine.load %4[0, 0] : memref<1x1xi32>
    %15 = memref.get_global @gridDim : memref<1x1xi32>
    %16 = affine.load %15[0, 0] : memref<1x1xi32>
    %17 = arith.muli %14, %16 : i32
    %18 = arith.extsi %17 : i32 to i64
    %19 = arith.addi %arg1, %18 : i64
    %20 = arith.addi %19, %c-1_i64 : i64
    %21 = arith.divsi %20, %18 : i64
    %22 = arith.trunci %21 : i64 to i32
    %23 = arith.addi %22, %c63_i32 : i32
    %24 = arith.divsi %23, %c64_i32 : i32
    %25 = arith.muli %24, %c64_i32 : i32
    %26 = arith.muli %13, %25 : i32
    %27 = arith.addi %26, %25 : i32
    %28 = arith.cmpi eq, %13, %c0_i32 : i32
    %29 = scf.if %28 -> (i32) {
      scf.yield %c0_i32 : i32
    } else {
      %41 = arith.addi %13, %c-1_i32 : i32
      %42 = arith.index_cast %41 : i32 to index
      %43 = "polygeist.subindex"(%arg2, %42) : (memref<?xi8>, index) -> memref<?xi8>
      %44 = affine.load %43[0] : memref<?xi8>
      %45 = arith.extui %44 : i8 to i32
      scf.yield %45 : i32
    }
    %30 = arith.extsi %26 : i32 to i64
    %31 = arith.extsi %27 : i32 to i64
    %32:4 = scf.while (%arg4 = %30, %arg5 = %c0_i32, %arg6 = %c0_i64, %arg7 = %29) : (i64, i32, i64, i32) -> (i64, i64, i32, i32) {
      %41 = arith.cmpi slt, %arg4, %31 : i64
      %42 = scf.if %41 -> (i1) {
        %43 = arith.cmpi slt, %arg4, %arg1 : i64
        scf.yield %43 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%42) %arg6, %arg4, %arg5, %arg7 : i64, i64, i32, i32
    } do {
    ^bb0(%arg4: i64, %arg5: i64, %arg6: i32, %arg7: i32):
      %41 = arith.cmpi eq, %arg7, %c1_i32 : i32
      %42 = scf.if %41 -> (i64) {
        %53 = arith.remsi %arg5, %c64_i64 : i64
        %54 = arith.shli %c1_i64, %53 : i64
        %55 = arith.ori %arg4, %54 : i64
        scf.yield %55 : i64
      } else {
        scf.yield %arg4 : i64
      }
      %43 = arith.index_cast %arg5 : i64 to index
      %44 = "polygeist.subindex"(%arg0, %43) : (memref<?xi8>, index) -> memref<?xi8>
      %45 = affine.load %44[0] : memref<?xi8>
      %46 = arith.extsi %45 : i8 to i32
      %47 = arith.cmpi eq, %46, %c92_i32 : i32
      %48:2 = scf.if %47 -> (i32, i32) {
        %53 = arith.addi %arg6, %c1_i32 : i32
        %54 = arith.xori %arg7, %c1_i32 : i32
        scf.yield %53, %54 : i32, i32
      } else {
        scf.yield %arg6, %c0_i32 : i32, i32
      }
      %49 = arith.remsi %arg5, %c64_i64 : i64
      %50 = arith.cmpi eq, %49, %c63_i64 : i64
      %51 = arith.select %50, %c0_i64, %42 : i64
      scf.if %50 {
        %53 = arith.divsi %arg5, %c64_i64 : i64
        %54 = arith.index_cast %53 : i64 to index
        %55 = "polygeist.subindex"(%arg3, %54) : (memref<?xi64>, index) -> memref<?xi64>
        affine.store %42, %55[0] : memref<?xi64>
      }
      %52 = arith.addi %arg5, %c1_i64 : i64
      scf.yield %52, %48#0, %51, %48#1 : i64, i32, i64, i32
    }
    %33 = arith.cmpi sle, %arg1, %31 : i64
    %34 = arith.addi %arg1, %c-1_i64 : i64
    %35 = arith.remsi %34, %c64_i64 : i64
    %36 = arith.cmpi ne, %35, %c63_i64 : i64
    %37 = arith.andi %33, %36 : i1
    %38 = arith.subi %arg1, %30 : i64
    %39 = arith.cmpi sgt, %38, %c0_i64 : i64
    %40 = arith.andi %37, %39 : i1
    scf.if %40 {
      %41 = arith.divsi %34, %c64_i64 : i64
      %42 = arith.index_cast %41 : i64 to index
      %43 = "polygeist.subindex"(%arg3, %42) : (memref<?xi64>, index) -> memref<?xi64>
      affine.store %32#0, %43[0] : memref<?xi64>
    }
    return
  }
  func.func @_Z18gpjson_quote_indexPciPlS0_S_(%arg0: memref<?xi8>, %arg1: i32, %arg2: memref<?xi64>, %arg3: memref<?xi64>, %arg4: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c63_i32 = arith.constant 63 : i32
    %c0 = arith.constant 0 : index
    %c-1_i32 = arith.constant -1 : i32
    %c63_i64 = arith.constant 63 : i64
    %c1_i64 = arith.constant 1 : i64
    %c34_i32 = arith.constant 34 : i32
    %c64_i64 = arith.constant 64 : i64
    %false = arith.constant false
    %c0_i32 = arith.constant 0 : i32
    %c0_i64 = arith.constant 0 : i64
    %c64_i32 = arith.constant 64 : i32
    %c1_i32 = arith.constant 1 : i32
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = "polygeist.subindex"(%0, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %2 = "polygeist.subindex"(%1, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %3 = affine.load %2[0] : memref<?xi32>
    %4 = memref.get_global @blockDim : memref<1x1xi32>
    %5 = "polygeist.subindex"(%4, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %6 = "polygeist.subindex"(%5, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %7 = affine.load %6[0] : memref<?xi32>
    %8 = arith.muli %3, %7 : i32
    %9 = memref.get_global @threadIdx : memref<1x1xi32>
    %10 = "polygeist.subindex"(%9, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %11 = "polygeist.subindex"(%10, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %12 = affine.load %11[0] : memref<?xi32>
    %13 = arith.addi %8, %12 : i32
    %14 = affine.load %4[0, 0] : memref<1x1xi32>
    %15 = memref.get_global @gridDim : memref<1x1xi32>
    %16 = affine.load %15[0, 0] : memref<1x1xi32>
    %17 = arith.muli %14, %16 : i32
    %18 = arith.addi %arg1, %17 : i32
    %19 = arith.addi %18, %c-1_i32 : i32
    %20 = arith.divsi %19, %17 : i32
    %21 = arith.addi %20, %c63_i32 : i32
    %22 = arith.divsi %21, %c64_i32 : i32
    %23 = arith.muli %22, %c64_i32 : i32
    %24 = arith.muli %13, %23 : i32
    %25 = arith.addi %24, %23 : i32
    %26 = arith.extsi %24 : i32 to i64
    %27 = arith.extsi %25 : i32 to i64
    %28:4 = scf.while (%arg5 = %26, %arg6 = %c0_i32, %arg7 = %c0_i64, %arg8 = %c0_i64) : (i64, i32, i64, i64) -> (i32, i64, i64, i64) {
      %42 = arith.cmpi slt, %arg5, %27 : i64
      %43 = scf.if %42 -> (i1) {
        %44 = arith.extsi %arg1 : i32 to i64
        %45 = arith.cmpi slt, %arg5, %44 : i64
        scf.yield %45 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%43) %arg6, %arg7, %arg5, %arg8 : i32, i64, i64, i64
    } do {
    ^bb0(%arg5: i32, %arg6: i64, %arg7: i64, %arg8: i64):
      %42 = arith.remsi %arg7, %c64_i64 : i64
      %43 = arith.cmpi eq, %42, %c0_i64 : i64
      %44 = scf.if %43 -> (i64) {
        %60 = arith.divsi %arg7, %c64_i64 : i64
        %61 = arith.index_cast %60 : i64 to index
        %62 = "polygeist.subindex"(%arg2, %61) : (memref<?xi64>, index) -> memref<?xi64>
        %63 = affine.load %62[0] : memref<?xi64>
        scf.yield %63 : i64
      } else {
        scf.yield %arg8 : i64
      }
      %45 = arith.index_cast %arg7 : i64 to index
      %46 = "polygeist.subindex"(%arg0, %45) : (memref<?xi8>, index) -> memref<?xi8>
      %47 = affine.load %46[0] : memref<?xi8>
      %48 = arith.extsi %47 : i8 to i32
      %49 = arith.cmpi eq, %48, %c34_i32 : i32
      %50 = arith.shli %c1_i64, %42 : i64
      %51 = arith.andi %44, %50 : i64
      %52 = arith.cmpi eq, %51, %c0_i64 : i64
      %53 = arith.andi %49, %52 : i1
      %54 = arith.ori %arg6, %50 : i64
      %55 = arith.select %53, %54, %arg6 : i64
      %56 = scf.if %53 -> (i32) {
        %60 = arith.addi %arg5, %c1_i32 : i32
        scf.yield %60 : i32
      } else {
        scf.yield %arg5 : i32
      }
      %57 = arith.cmpi eq, %42, %c63_i64 : i64
      %58 = arith.select %57, %c0_i64, %55 : i64
      scf.if %57 {
        %60 = arith.divsi %arg7, %c64_i64 : i64
        %61 = arith.index_cast %60 : i64 to index
        %62 = "polygeist.subindex"(%arg3, %61) : (memref<?xi64>, index) -> memref<?xi64>
        affine.store %55, %62[0] : memref<?xi64>
      }
      %59 = arith.addi %arg7, %c1_i64 : i64
      scf.yield %59, %56, %58, %44 : i64, i32, i64, i64
    }
    %29 = arith.cmpi sle, %arg1, %25 : i32
    %30 = arith.addi %arg1, %c-1_i32 : i32
    %31 = arith.remsi %30, %c64_i32 : i32
    %32 = arith.extsi %31 : i32 to i64
    %33 = arith.cmpi ne, %32, %c63_i64 : i64
    %34 = arith.andi %29, %33 : i1
    %35 = arith.subi %arg1, %24 : i32
    %36 = arith.cmpi sgt, %35, %c0_i32 : i32
    %37 = arith.andi %34, %36 : i1
    scf.if %37 {
      %42 = arith.divsi %30, %c64_i32 : i32
      %43 = arith.index_cast %42 : i32 to index
      %44 = "polygeist.subindex"(%arg3, %43) : (memref<?xi64>, index) -> memref<?xi64>
      affine.store %28#1, %44[0] : memref<?xi64>
    }
    %38 = arith.index_cast %13 : i32 to index
    %39 = "polygeist.subindex"(%arg4, %38) : (memref<?xi8>, index) -> memref<?xi8>
    %40 = arith.andi %28#0, %c1_i32 : i32
    %41 = arith.trunci %40 : i32 to i8
    affine.store %41, %39[0] : memref<?xi8>
    return
  }
  func.func @_Z19gpjson_xor_pre_scanPci(%arg0: memref<?xi8>, %arg1: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c-1_i32 = arith.constant -1 : i32
    %c1_i64 = arith.constant 1 : i64
    %false = arith.constant false
    %c0_i32 = arith.constant 0 : i32
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = affine.load %0[0, 0] : memref<1x1xi32>
    %2 = memref.get_global @blockDim : memref<1x1xi32>
    %3 = affine.load %2[0, 0] : memref<1x1xi32>
    %4 = arith.muli %1, %3 : i32
    %5 = memref.get_global @threadIdx : memref<1x1xi32>
    %6 = affine.load %5[0, 0] : memref<1x1xi32>
    %7 = arith.addi %4, %6 : i32
    %8 = memref.get_global @gridDim : memref<1x1xi32>
    %9 = affine.load %8[0, 0] : memref<1x1xi32>
    %10 = arith.muli %3, %9 : i32
    %11 = arith.addi %arg1, %10 : i32
    %12 = arith.addi %11, %c-1_i32 : i32
    %13 = arith.divsi %12, %10 : i32
    %14 = arith.extsi %13 : i32 to i64
    %15 = arith.extsi %7 : i32 to i64
    %16 = arith.muli %15, %14 : i64
    %17 = arith.addi %16, %14 : i64
    %18:2 = scf.while (%arg2 = %16, %arg3 = %c0_i32) : (i64, i32) -> (i64, i32) {
      %19 = arith.cmpi slt, %arg2, %17 : i64
      %20 = scf.if %19 -> (i1) {
        %21 = arith.extsi %arg1 : i32 to i64
        %22 = arith.cmpi slt, %arg2, %21 : i64
        scf.yield %22 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%20) %arg2, %arg3 : i64, i32
    } do {
    ^bb0(%arg2: i64, %arg3: i32):
      %19 = arith.index_cast %arg2 : i64 to index
      %20 = "polygeist.subindex"(%arg0, %19) : (memref<?xi8>, index) -> memref<?xi8>
      %21 = affine.load %20[0] : memref<?xi8>
      %22 = arith.extsi %21 : i8 to i32
      %23 = arith.xori %arg3, %22 : i32
      %24 = arith.trunci %23 : i32 to i8
      affine.store %24, %20[0] : memref<?xi8>
      %25 = arith.addi %arg2, %c1_i64 : i64
      scf.yield %25, %23 : i64, i32
    }
    return
  }
  func.func @_Z20gpjson_xor_post_scanPciiS_(%arg0: memref<?xi8>, %arg1: i32, %arg2: i32, %arg3: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c-1_i64 = arith.constant -1 : i64
    %c-1_i32 = arith.constant -1 : i32
    %c1_i64 = arith.constant 1 : i64
    %c0_i32 = arith.constant 0 : i32
    %0 = arith.addi %arg1, %arg2 : i32
    %1 = arith.addi %0, %c-1_i32 : i32
    %2 = arith.divsi %1, %arg2 : i32
    %3 = arith.extsi %2 : i32 to i64
    %4 = arith.addi %arg2, %c-1_i32 : i32
    %5 = arith.extsi %4 : i32 to i64
    %6 = arith.index_cast %5 : i64 to index
    %7 = scf.for %arg4 = %c0 to %6 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
      %11 = arith.index_cast %arg4 : index to i64
      %12 = "polygeist.subindex"(%arg3, %arg4) : (memref<?xi8>, index) -> memref<?xi8>
      %13 = arith.trunci %arg5 : i32 to i8
      affine.store %13, %12[0] : memref<?xi8>
      %14 = arith.addi %11, %c1_i64 : i64
      %15 = arith.muli %3, %14 : i64
      %16 = arith.addi %15, %c-1_i64 : i64
      %17 = arith.index_cast %16 : i64 to index
      %18 = "polygeist.subindex"(%arg0, %17) : (memref<?xi8>, index) -> memref<?xi8>
      %19 = affine.load %18[0] : memref<?xi8>
      %20 = arith.extsi %19 : i8 to i32
      %21 = arith.xori %arg5, %20 : i32
      scf.yield %21 : i32
    }
    %8 = arith.index_cast %4 : i32 to index
    %9 = "polygeist.subindex"(%arg3, %8) : (memref<?xi8>, index) -> memref<?xi8>
    %10 = arith.trunci %7 : i32 to i8
    affine.store %10, %9[0] : memref<?xi8>
    return
  }
  func.func @_Z17gpjson_xor_rebasePciS_(%arg0: memref<?xi8>, %arg1: i32, %arg2: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c-1_i32 = arith.constant -1 : i32
    %c1_i64 = arith.constant 1 : i64
    %false = arith.constant false
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = affine.load %0[0, 0] : memref<1x1xi32>
    %2 = memref.get_global @blockDim : memref<1x1xi32>
    %3 = affine.load %2[0, 0] : memref<1x1xi32>
    %4 = arith.muli %1, %3 : i32
    %5 = memref.get_global @threadIdx : memref<1x1xi32>
    %6 = affine.load %5[0, 0] : memref<1x1xi32>
    %7 = arith.addi %4, %6 : i32
    %8 = memref.get_global @gridDim : memref<1x1xi32>
    %9 = affine.load %8[0, 0] : memref<1x1xi32>
    %10 = arith.muli %3, %9 : i32
    %11 = arith.addi %arg1, %10 : i32
    %12 = arith.addi %11, %c-1_i32 : i32
    %13 = arith.divsi %12, %10 : i32
    %14 = arith.extsi %13 : i32 to i64
    %15 = arith.extsi %7 : i32 to i64
    %16 = arith.muli %15, %14 : i64
    %17 = arith.addi %16, %14 : i64
    %18 = arith.index_cast %7 : i32 to index
    %19 = "polygeist.subindex"(%arg2, %18) : (memref<?xi8>, index) -> memref<?xi8>
    %20 = scf.while (%arg3 = %16) : (i64) -> i64 {
      %21 = arith.cmpi slt, %arg3, %17 : i64
      %22 = scf.if %21 -> (i1) {
        %23 = arith.extsi %arg1 : i32 to i64
        %24 = arith.cmpi slt, %arg3, %23 : i64
        scf.yield %24 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%22) %arg3 : i64
    } do {
    ^bb0(%arg3: i64):
      %21 = arith.index_cast %arg3 : i64 to index
      %22 = "polygeist.subindex"(%arg0, %21) : (memref<?xi8>, index) -> memref<?xi8>
      %23 = affine.load %22[0] : memref<?xi8>
      %24 = affine.load %19[0] : memref<?xi8>
      %25 = arith.xori %23, %24 : i8
      affine.store %25, %22[0] : memref<?xi8>
      %26 = arith.addi %arg3, %c1_i64 : i64
      scf.yield %26 : i64
    }
    return
  }
  func.func @_Z19gpjson_string_indexPliPc(%arg0: memref<?xi64>, %arg1: i32, %arg2: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c-1_i32 = arith.constant -1 : i32
    %c63_i64 = arith.constant 63 : i64
    %c32_i64 = arith.constant 32 : i64
    %c16_i64 = arith.constant 16 : i64
    %c8_i64 = arith.constant 8 : i64
    %c4_i64 = arith.constant 4 : i64
    %c2_i64 = arith.constant 2 : i64
    %c1_i64 = arith.constant 1 : i64
    %c0_i64 = arith.constant 0 : i64
    %c-1_i64 = arith.constant -1 : i64
    %false = arith.constant false
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %0 = memref.get_global @blockIdx : memref<1x1xi32>
    %1 = affine.load %0[0, 0] : memref<1x1xi32>
    %2 = memref.get_global @blockDim : memref<1x1xi32>
    %3 = affine.load %2[0, 0] : memref<1x1xi32>
    %4 = arith.muli %1, %3 : i32
    %5 = memref.get_global @threadIdx : memref<1x1xi32>
    %6 = affine.load %5[0, 0] : memref<1x1xi32>
    %7 = arith.addi %4, %6 : i32
    %8 = memref.get_global @gridDim : memref<1x1xi32>
    %9 = affine.load %8[0, 0] : memref<1x1xi32>
    %10 = arith.muli %3, %9 : i32
    %11 = arith.addi %arg1, %10 : i32
    %12 = arith.addi %11, %c-1_i32 : i32
    %13 = arith.divsi %12, %10 : i32
    %14 = arith.muli %7, %13 : i32
    %15 = arith.addi %14, %13 : i32
    %16 = arith.cmpi sgt, %7, %c0_i32 : i32
    %17 = scf.if %16 -> (i64) {
      %19 = arith.addi %7, %c-1_i32 : i32
      %20 = arith.index_cast %19 : i32 to index
      %21 = "polygeist.subindex"(%arg2, %20) : (memref<?xi8>, index) -> memref<?xi8>
      %22 = affine.load %21[0] : memref<?xi8>
      %23 = arith.extsi %22 : i8 to i32
      %24 = arith.cmpi eq, %23, %c1_i32 : i32
      %25 = arith.select %24, %c-1_i64, %c0_i64 : i64
      scf.yield %25 : i64
    } else {
      scf.yield %c0_i64 : i64
    }
    %18:2 = scf.while (%arg3 = %14, %arg4 = %17) : (i32, i64) -> (i32, i64) {
      %19 = arith.cmpi slt, %arg3, %15 : i32
      %20 = scf.if %19 -> (i1) {
        %21 = arith.cmpi slt, %arg3, %arg1 : i32
        scf.yield %21 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%20) %arg3, %arg4 : i32, i64
    } do {
    ^bb0(%arg3: i32, %arg4: i64):
      %19 = arith.index_cast %arg3 : i32 to index
      %20 = "polygeist.subindex"(%arg0, %19) : (memref<?xi64>, index) -> memref<?xi64>
      %21 = affine.load %20[0] : memref<?xi64>
      %22 = arith.shli %21, %c1_i64 : i64
      %23 = arith.xori %21, %22 : i64
      %24 = arith.shli %23, %c2_i64 : i64
      %25 = arith.xori %23, %24 : i64
      %26 = arith.shli %25, %c4_i64 : i64
      %27 = arith.xori %25, %26 : i64
      %28 = arith.shli %27, %c8_i64 : i64
      %29 = arith.xori %27, %28 : i64
      %30 = arith.shli %29, %c16_i64 : i64
      %31 = arith.xori %29, %30 : i64
      %32 = arith.shli %31, %c32_i64 : i64
      %33 = arith.xori %31, %32 : i64
      %34 = arith.xori %33, %arg4 : i64
      affine.store %34, %20[0] : memref<?xi64>
      %35 = arith.shrsi %34, %c63_i64 : i64
      %36 = arith.addi %arg3, %c1_i32 : i32
      scf.yield %36, %35 : i32, i64
    }
    return
  }
  func.func @_Z24gpjson_structural_bitmapPciPlS0_(%arg0: memref<?xi8>, %arg1: i32, %arg2: memref<?xi64>, %arg3: memref<?xi64>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c63_i32 = arith.constant 63 : i32
    %c0 = arith.constant 0 : index
    %c-1_i32 = arith.constant -1 : i32
    %c44_i32 = arith.constant 44 : i32
    %c58_i32 = arith.constant 58 : i32
    %c93_i32 = arith.constant 93 : i32
    %c91_i32 = arith.constant 91 : i32
    %c125_i32 = arith.constant 125 : i32
    %c123_i32 = arith.constant 123 : i32
    %c63_i64 = arith.constant 63 : i64
    %c1_i64 = arith.constant 1 : i64
    %false = arith.constant false
    %c0_i64 = arith.constant 0 : i64
    %c64_i32 = arith.constant 64 : i32
    %c1_i32 = arith.constant 1 : i32
    %true = arith.constant true
    %0 = llvm.mlir.undef : i8
    %1 = memref.get_global @blockIdx : memref<1x1xi32>
    %2 = "polygeist.subindex"(%1, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %3 = "polygeist.subindex"(%2, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %4 = affine.load %3[0] : memref<?xi32>
    %5 = memref.get_global @blockDim : memref<1x1xi32>
    %6 = "polygeist.subindex"(%5, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %7 = "polygeist.subindex"(%6, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %8 = affine.load %7[0] : memref<?xi32>
    %9 = arith.muli %4, %8 : i32
    %10 = memref.get_global @threadIdx : memref<1x1xi32>
    %11 = "polygeist.subindex"(%10, %c0) : (memref<1x1xi32>, index) -> memref<1xi32>
    %12 = "polygeist.subindex"(%11, %c0) : (memref<1xi32>, index) -> memref<?xi32>
    %13 = affine.load %12[0] : memref<?xi32>
    %14 = arith.addi %9, %13 : i32
    %15 = affine.load %5[0, 0] : memref<1x1xi32>
    %16 = memref.get_global @gridDim : memref<1x1xi32>
    %17 = affine.load %16[0, 0] : memref<1x1xi32>
    %18 = arith.muli %15, %17 : i32
    %19 = arith.addi %arg1, %18 : i32
    %20 = arith.addi %19, %c-1_i32 : i32
    %21 = arith.divsi %20, %18 : i32
    %22 = arith.addi %21, %c63_i32 : i32
    %23 = arith.divsi %22, %c64_i32 : i32
    %24 = arith.muli %23, %c64_i32 : i32
    %25 = arith.muli %14, %24 : i32
    %26 = arith.addi %25, %24 : i32
    %27:4 = scf.while (%arg4 = %0, %arg5 = %25, %arg6 = %c0_i64, %arg7 = %c0_i64) : (i8, i32, i64, i64) -> (i64, i8, i32, i64) {
      %36 = arith.cmpi slt, %arg5, %26 : i32
      %37 = scf.if %36 -> (i1) {
        %38 = arith.cmpi slt, %arg5, %arg1 : i32
        scf.yield %38 : i1
      } else {
        scf.yield %false : i1
      }
      scf.condition(%37) %arg6, %arg4, %arg5, %arg7 : i64, i8, i32, i64
    } do {
    ^bb0(%arg4: i64, %arg5: i8, %arg6: i32, %arg7: i64):
      %36 = arith.remsi %arg6, %c64_i32 : i32
      %37 = arith.extsi %36 : i32 to i64
      %38 = arith.cmpi eq, %37, %c0_i64 : i64
      %39 = arith.select %38, %c0_i64, %arg4 : i64
      %40 = scf.if %38 -> (i64) {
        %49 = arith.divsi %arg6, %c64_i32 : i32
        %50 = arith.index_cast %49 : i32 to index
        %51 = "polygeist.subindex"(%arg2, %50) : (memref<?xi64>, index) -> memref<?xi64>
        %52 = affine.load %51[0] : memref<?xi64>
        scf.yield %52 : i64
      } else {
        scf.yield %arg7 : i64
      }
      %41 = arith.shli %c1_i64, %37 : i64
      %42 = arith.andi %40, %41 : i64
      %43 = arith.cmpi ne, %42, %c0_i64 : i64
      %44 = arith.cmpi eq, %37, %c63_i64 : i64
      %45 = arith.andi %43, %44 : i1
      %46 = arith.cmpi eq, %42, %c0_i64 : i64
      scf.if %45 {
        %49 = arith.divsi %arg6, %c64_i32 : i32
        %50 = arith.index_cast %49 : i32 to index
        %51 = "polygeist.subindex"(%arg3, %50) : (memref<?xi64>, index) -> memref<?xi64>
        affine.store %39, %51[0] : memref<?xi64>
      }
      %47:2 = scf.if %46 -> (i8, i64) {
        %49 = arith.index_cast %arg6 : i32 to index
        %50 = "polygeist.subindex"(%arg0, %49) : (memref<?xi8>, index) -> memref<?xi8>
        %51 = affine.load %50[0] : memref<?xi8>
        %52 = arith.extsi %51 : i8 to i32
        %53 = arith.cmpi eq, %52, %c123_i32 : i32
        %54 = scf.if %53 -> (i1) {
          scf.yield %true : i1
        } else {
          %60 = arith.cmpi eq, %52, %c125_i32 : i32
          scf.yield %60 : i1
        }
        %55 = scf.if %54 -> (i1) {
          scf.yield %true : i1
        } else {
          %60 = arith.cmpi eq, %52, %c91_i32 : i32
          scf.yield %60 : i1
        }
        %56 = scf.if %55 -> (i1) {
          scf.yield %true : i1
        } else {
          %60 = arith.cmpi eq, %52, %c93_i32 : i32
          scf.yield %60 : i1
        }
        %57 = scf.if %56 -> (i1) {
          scf.yield %true : i1
        } else {
          %60 = arith.cmpi eq, %52, %c58_i32 : i32
          scf.yield %60 : i1
        }
        %58 = scf.if %57 -> (i1) {
          scf.yield %true : i1
        } else {
          %60 = arith.cmpi eq, %52, %c44_i32 : i32
          scf.yield %60 : i1
        }
        %59 = scf.if %58 -> (i64) {
          %60 = arith.ori %39, %41 : i64
          scf.yield %60 : i64
        } else {
          scf.yield %39 : i64
        }
        scf.if %44 {
          %60 = arith.divsi %arg6, %c64_i32 : i32
          %61 = arith.index_cast %60 : i32 to index
          %62 = "polygeist.subindex"(%arg3, %61) : (memref<?xi64>, index) -> memref<?xi64>
          affine.store %59, %62[0] : memref<?xi64>
        }
        scf.yield %51, %59 : i8, i64
      } else {
        scf.yield %arg5, %39 : i8, i64
      }
      %48 = arith.addi %arg6, %c1_i32 : i32
      scf.yield %47#0, %48, %47#1, %40 : i8, i32, i64, i64
    }
    %28 = arith.cmpi sle, %arg1, %26 : i32
    %29 = arith.cmpi sgt, %arg1, %25 : i32
    %30 = arith.andi %28, %29 : i1
    %31 = arith.addi %arg1, %c-1_i32 : i32
    %32 = arith.remsi %31, %c64_i32 : i32
    %33 = arith.extsi %32 : i32 to i64
    %34 = arith.cmpi ne, %33, %c63_i64 : i64
    %35 = arith.andi %30, %34 : i1
    scf.if %35 {
      %36 = arith.divsi %31, %c64_i32 : i32
      %37 = arith.index_cast %36 : i32 to index
      %38 = "polygeist.subindex"(%arg3, %37) : (memref<?xi64>, index) -> memref<?xi64>
      affine.store %27#0, %38[0] : memref<?xi64>
    }
    return
  }
}
