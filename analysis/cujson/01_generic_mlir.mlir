module attributes {dlti.dl_spec = #dlti.dl_spec<#dlti.dl_entry<f80, dense<128> : vector<2xi32>>, #dlti.dl_entry<i64, dense<64> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr<270>, dense<32> : vector<4xi32>>, #dlti.dl_entry<f128, dense<128> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr<272>, dense<64> : vector<4xi32>>, #dlti.dl_entry<!llvm.ptr<271>, dense<32> : vector<4xi32>>, #dlti.dl_entry<f16, dense<16> : vector<2xi32>>, #dlti.dl_entry<f64, dense<64> : vector<2xi32>>, #dlti.dl_entry<i16, dense<16> : vector<2xi32>>, #dlti.dl_entry<i32, dense<32> : vector<2xi32>>, #dlti.dl_entry<i8, dense<8> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi32>>, #dlti.dl_entry<i1, dense<8> : vector<2xi32>>, #dlti.dl_entry<"dlti.stack_alignment", 128 : i32>, #dlti.dl_entry<"dlti.endianness", "little">>, llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128", llvm.target_triple = "x86_64-unknown-linux-gnu", "polygeist.target-cpu" = "x86-64", "polygeist.target-features" = "+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87", "polygeist.tune-cpu" = "generic"} {
  memref.global @gridDim : memref<1x1xi32> = uninitialized
  memref.global @threadIdx : memref<1x1xi32> = uninitialized
  memref.global @blockDim : memref<1x1xi32> = uninitialized
  memref.global @blockIdx : memref<1x1xi32> = uninitialized
  func.func @cujson_tokenizer(%arg0: memref<?xi32>, %arg1: memref<?xi32>, %arg2: memref<?xi32>, %arg3: memref<?xi32>, %arg4: memref<?xi32>, %arg5: memref<?xi32>, %arg6: memref<?xi32>, %arg7: memref<?xi32>, %arg8: memref<?xi32>, %arg9: memref<?xi32>, %arg10: i64, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c4_i64 = arith.constant 4 : i64
    %c3_i64 = arith.constant 3 : i64
    %0 = arith.addi %arg10, %c3_i64 : i64
    %1 = arith.divsi %0, %c4_i64 : i64
    %2 = arith.trunci %1 : i64 to i32
    call @_Z10checkAsciiPjiS_(%arg0, %2, %arg1) : (memref<?xi32>, i32, memref<?xi32>) -> ()
    call @_Z9checkUTF8PjS_i(%arg0, %arg2, %2) : (memref<?xi32>, memref<?xi32>, i32) -> ()
    %3 = "polygeist.memref2pointer"(%arg3) : (memref<?xi32>) -> !llvm.ptr
    %4 = "polygeist.pointer2memref"(%3) : (!llvm.ptr) -> memref<?xi8>
    %5 = "polygeist.memref2pointer"(%arg4) : (memref<?xi32>) -> !llvm.ptr
    %6 = "polygeist.pointer2memref"(%5) : (!llvm.ptr) -> memref<?xi8>
    %7 = "polygeist.memref2pointer"(%arg7) : (memref<?xi32>) -> !llvm.ptr
    %8 = "polygeist.pointer2memref"(%7) : (!llvm.ptr) -> memref<?xi8>
    %9 = "polygeist.memref2pointer"(%arg8) : (memref<?xi32>) -> !llvm.ptr
    %10 = "polygeist.pointer2memref"(%9) : (!llvm.ptr) -> memref<?xi8>
    call @_Z17bitMapCreatorSimdPjPhS0_S0_S0_yi(%arg0, %4, %6, %8, %10, %arg10, %arg11) : (memref<?xi32>, memref<?xi8>, memref<?xi8>, memref<?xi8>, memref<?xi8>, i64, i32) -> ()
    call @_Z25findEscapedQuoteMerge_NEWPjS_S_iii(%arg3, %arg4, %arg5, %arg12, %arg13, %arg14) : (memref<?xi32>, memref<?xi32>, memref<?xi32>, i32, i32, i32) -> ()
    call @_Z33thrust_exclusive_scan_quote_countPjS_i(%arg4, %arg4, %arg12) : (memref<?xi32>, memref<?xi32>, i32) -> ()
    call @_Z22inStringFinderBaselinePjS_S_i(%arg5, %arg4, %arg6, %arg12) : (memref<?xi32>, memref<?xi32>, memref<?xi32>, i32) -> ()
    %11 = arith.extsi %arg12 : i32 to i64
    call @_Z24findOutUsefulStringMergePjS_S_yiiS_(%arg7, %arg8, %arg6, %11, %arg13, %arg14, %arg9) : (memref<?xi32>, memref<?xi32>, memref<?xi32>, i64, i32, i32, memref<?xi32>) -> ()
    return
  }
  func.func @_Z10checkAsciiPjiS_(%arg0: memref<?xi32>, %arg1: i32, %arg2: memref<?xi32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c-2139062144_i32 = arith.constant -2139062144 : i32
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
    %11 = arith.index_cast %arg1 : i32 to index
    %12 = arith.index_cast %7 : i32 to index
    %13 = arith.index_cast %10 : i32 to index
    scf.for %arg3 = %12 to %11 step %13 {
      %14 = arith.subi %arg3, %12 : index
      %15 = arith.divui %14, %13 : index
      %16 = arith.muli %15, %13 : index
      %17 = arith.addi %12, %16 : index
      %18 = "polygeist.subindex"(%arg0, %17) : (memref<?xi32>, index) -> memref<?xi32>
      %19 = affine.load %18[0] : memref<?xi32>
      %20 = arith.andi %19, %c-2139062144_i32 : i32
      %21 = arith.cmpi ne, %20, %c0_i32 : i32
      scf.if %21 {
        affine.store %c1_i32, %arg2[0] : memref<?xi32>
      }
    }
    return
  }
  func.func @_Z9checkUTF8PjS_i(%arg0: memref<?xi32>, %arg1: memref<?xi32>, %arg2: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c4 = arith.constant 4 : index
    %c1 = arith.constant 1 : index
    %c-2139062144_i32 = arith.constant -2139062144 : i32
    %c32_i64 = arith.constant 32 : i64
    %c24_i64 = arith.constant 24 : i64
    %c16_i64 = arith.constant 16 : i64
    %c8_i64 = arith.constant 8 : i64
    %c-1075843073_i32 = arith.constant -1075843073 : i32
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c4_i32 = arith.constant 4 : i32
    %c-1566399838_i32 = arith.constant -1566399838 : i32
    %c151587081_i32 = arith.constant 151587081 : i32
    %c185273099_i32 = arith.constant 185273099 : i32
    %c202116108_i32 = arith.constant 202116108 : i32
    %c252645135_i32 = arith.constant 252645135 : i32
    %c134744072_i32 = arith.constant 134744072 : i32
    %c-202116109_i32 = arith.constant -202116109 : i32
    %c-185273100_i32 = arith.constant -185273100 : i32
    %c1077952576_i32 = arith.constant 1077952576 : i32
    %c-252645136_i32 = arith.constant -252645136 : i32
    %c67372036_i32 = arith.constant 67372036 : i32
    %c-522133280_i32 = arith.constant -522133280 : i32
    %c269488144_i32 = arith.constant 269488144 : i32
    %c-303174163_i32 = arith.constant -303174163 : i32
    %c538976288_i32 = arith.constant 538976288 : i32
    %c-1044266559_i32 = arith.constant -1044266559 : i32
    %c16843009_i32 = arith.constant 16843009 : i32
    %c-1061109568_i32 = arith.constant -1061109568 : i32
    %c33686018_i32 = arith.constant 33686018 : i32
    %c127_i32 = arith.constant 127 : i32
    %c-128_i32 = arith.constant -128 : i32
    %c-269488145_i32 = arith.constant -269488145 : i32
    %c-538976289_i32 = arith.constant -538976289 : i32
    %c0 = arith.constant 0 : index
    %c-1_i32 = arith.constant -1 : i32
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
    %11 = arith.index_cast %arg2 : i32 to index
    %12 = arith.index_cast %7 : i32 to index
    %13 = arith.index_cast %10 : i32 to index
    %14 = llvm.mlir.undef : i32
    scf.for %arg3 = %12 to %11 step %13 {
      %15 = arith.subi %arg3, %12 : index
      %16 = arith.divui %15, %13 : index
      %17 = arith.muli %16, %13 : index
      %18 = arith.addi %12, %17 : index
      %19 = arith.index_cast %18 : index to i32
      %20 = memref.load %arg0[%18] : memref<?xi32>
      %21 = arith.cmpi sgt, %19, %c0_i32 : i32
      %22 = scf.if %21 -> (i32) {
        %30 = arith.addi %19, %c-1_i32 : i32
        %31 = arith.index_cast %30 : i32 to index
        %32 = "polygeist.subindex"(%arg0, %31) : (memref<?xi32>, index) -> memref<?xi32>
        %33 = affine.load %32[0] : memref<?xi32>
        scf.yield %33 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %23 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
        %30 = arith.index_cast %arg4 : index to i32
        %31 = arith.muli %30, %c8_i32 : i32
        %32 = arith.shrsi %22, %31 : i32
        %33 = arith.andi %32, %c255_i32 : i32
        %34 = arith.shrsi %c-1075843073_i32, %31 : i32
        %35 = arith.andi %34, %c255_i32 : i32
        %36 = arith.cmpi sgt, %33, %35 : i32
        %37 = scf.if %36 -> (i32) {
          %40 = arith.subi %33, %35 : i32
          scf.yield %40 : i32
        } else {
          scf.yield %c0_i32 : i32
        }
        %38 = arith.shli %37, %31 : i32
        %39 = arith.ori %arg5, %38 : i32
        scf.yield %39 : i32
      }
      %24 = arith.andi %20, %c-2139062144_i32 : i32
      %25 = arith.cmpi eq, %24, %c0_i32 : i32
      %26 = arith.select %25, %23, %14 : i32
      %27 = arith.cmpi ne, %24, %c0_i32 : i32
      %28 = scf.if %27 -> (i32) {
        %30 = arith.extsi %20 : i32 to i64
        %31 = arith.shli %30, %c32_i64 : i64
        %32 = arith.extsi %22 : i32 to i64
        %33 = arith.ori %31, %32 : i64
        %34 = arith.shrsi %33, %c24_i64 : i64
        %35 = arith.trunci %34 : i64 to i32
        %36 = arith.shrsi %33, %c16_i64 : i64
        %37 = arith.trunci %36 : i64 to i32
        %38 = arith.shrsi %33, %c8_i64 : i64
        %39 = arith.trunci %38 : i64 to i32
        %40 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-2139062144_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi slt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %41 = arith.andi %40, %c33686018_i32 : i32
        %42 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-1061109568_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sge, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %43 = arith.andi %42, %c16843009_i32 : i32
        %44 = arith.ori %41, %43 : i32
        %45 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-1061109568_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %46 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-1044266559_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %47 = arith.ori %45, %46 : i32
        %48 = arith.andi %47, %c538976288_i32 : i32
        %49 = arith.ori %44, %48 : i32
        %50 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-303174163_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %51 = arith.andi %50, %c269488144_i32 : i32
        %52 = arith.ori %49, %51 : i32
        %53 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-522133280_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %54 = arith.andi %53, %c67372036_i32 : i32
        %55 = arith.ori %52, %54 : i32
        %56 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-252645136_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %57 = arith.andi %56, %c1077952576_i32 : i32
        %58 = arith.ori %55, %57 : i32
        %59 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-185273100_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %60 = arith.andi %59, %c1077952576_i32 : i32
        %61 = arith.ori %58, %60 : i32
        %62 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %35, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-202116109_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %63 = arith.andi %62, %c134744072_i32 : i32
        %64 = arith.ori %61, %63 : i32
        %65 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %64, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c0_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %66 = arith.andi %65, %c-2139062144_i32 : i32
        %67 = arith.shrsi %20, %c4_i32 : i32
        %68 = arith.andi %67, %c252645135_i32 : i32
        %69 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c202116108_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi slt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %70 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c134744072_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi slt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %71 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c185273099_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %72 = arith.ori %70, %71 : i32
        %73 = arith.andi %72, %c16843009_i32 : i32
        %74 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c134744072_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sge, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %75 = arith.andi %69, %74 : i32
        %76 = arith.andi %75, %c-1566399838_i32 : i32
        %77 = arith.ori %73, %76 : i32
        %78 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c134744072_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %79 = arith.andi %69, %78 : i32
        %80 = arith.andi %79, %c134744072_i32 : i32
        %81 = arith.ori %77, %80 : i32
        %82 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c134744072_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi eq, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %83 = arith.andi %82, %c1077952576_i32 : i32
        %84 = arith.ori %81, %83 : i32
        %85 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %68, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c151587081_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %86 = arith.andi %85, %69 : i32
        %87 = arith.andi %86, %c269488144_i32 : i32
        %88 = arith.ori %84, %87 : i32
        %89 = arith.andi %66, %88 : i32
        %90 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %37, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-538976289_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %107 = arith.subi %100, %102 : i32
            scf.yield %107 : i32
          } else {
            scf.yield %c0_i32 : i32
          }
          %105 = arith.shli %104, %98 : i32
          %106 = arith.ori %arg5, %105 : i32
          scf.yield %106 : i32
        }
        %91 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %39, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c-269488145_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %107 = arith.subi %100, %102 : i32
            scf.yield %107 : i32
          } else {
            scf.yield %c0_i32 : i32
          }
          %105 = arith.shli %104, %98 : i32
          %106 = arith.ori %arg5, %105 : i32
          scf.yield %106 : i32
        }
        %92 = arith.ori %90, %91 : i32
        %93 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %92, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.trunci %100 : i32 to i8
          %102 = arith.extsi %101 : i8 to i32
          %103 = arith.shrsi %c0_i32, %98 : i32
          %104 = arith.andi %103, %c255_i32 : i32
          %105 = arith.trunci %104 : i32 to i8
          %106 = arith.extsi %105 : i8 to i32
          %107 = arith.subi %102, %106 : i32
          %108 = arith.cmpi sgt, %107, %c127_i32 : i32
          %109 = arith.select %108, %c127_i32, %107 : i32
          %110 = arith.cmpi slt, %109, %c-128_i32 : i32
          %111 = arith.select %110, %c-128_i32, %109 : i32
          %112 = arith.andi %111, %c255_i32 : i32
          %113 = arith.shli %112, %98 : i32
          %114 = arith.ori %arg5, %113 : i32
          scf.yield %114 : i32
        }
        %94 = scf.for %arg4 = %c0 to %c4 step %c1 iter_args(%arg5 = %c0_i32) -> (i32) {
          %97 = arith.index_cast %arg4 : index to i32
          %98 = arith.muli %97, %c8_i32 : i32
          %99 = arith.shrsi %93, %98 : i32
          %100 = arith.andi %99, %c255_i32 : i32
          %101 = arith.shrsi %c0_i32, %98 : i32
          %102 = arith.andi %101, %c255_i32 : i32
          %103 = arith.cmpi sgt, %100, %102 : i32
          %104 = scf.if %103 -> (i32) {
            %105 = arith.shli %c255_i32, %98 : i32
            %106 = arith.ori %arg5, %105 : i32
            scf.yield %106 : i32
          } else {
            scf.yield %arg5 : i32
          }
          scf.yield %104 : i32
        }
        %95 = arith.andi %94, %c-2139062144_i32 : i32
        %96 = arith.xori %95, %89 : i32
        scf.yield %96 : i32
      } else {
        scf.yield %26 : i32
      }
      %29 = arith.cmpi ne, %28, %c0_i32 : i32
      scf.if %29 {
        affine.store %28, %arg1[0] : memref<?xi32>
      }
    }
    return
  }
  func.func @_Z17bitMapCreatorSimdPjPhS0_S0_S0_yi(%arg0: memref<?xi32>, %arg1: memref<?xi8>, %arg2: memref<?xi8>, %arg3: memref<?xi8>, %arg4: memref<?xi8>, %arg5: i64, %arg6: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c0_i32 = arith.constant 0 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i8 = arith.constant 0 : i8
    %c4_i64 = arith.constant 4 : i64
    %c8_i64 = arith.constant 8 : i64
    %c2_i32 = arith.constant 2 : i32
    %alloca = memref.alloca() : memref<1xi8>
    %cast = memref.cast %alloca : memref<1xi8> to memref<?xi8>
    %0 = llvm.mlir.undef : i8
    affine.store %0, %alloca[0] : memref<1xi8>
    %alloca_0 = memref.alloca() : memref<1xi8>
    %cast_1 = memref.cast %alloca_0 : memref<1xi8> to memref<?xi8>
    affine.store %0, %alloca_0[0] : memref<1xi8>
    %alloca_2 = memref.alloca() : memref<1xi8>
    %cast_3 = memref.cast %alloca_2 : memref<1xi8> to memref<?xi8>
    affine.store %0, %alloca_2[0] : memref<1xi8>
    %alloca_4 = memref.alloca() : memref<1xi8>
    %cast_5 = memref.cast %alloca_4 : memref<1xi8> to memref<?xi8>
    affine.store %0, %alloca_4[0] : memref<1xi8>
    %1 = memref.get_global @blockIdx : memref<1x1xi32>
    %2 = affine.load %1[0, 0] : memref<1x1xi32>
    %3 = memref.get_global @blockDim : memref<1x1xi32>
    %4 = affine.load %3[0, 0] : memref<1x1xi32>
    %5 = arith.muli %2, %4 : i32
    %6 = memref.get_global @threadIdx : memref<1x1xi32>
    %7 = affine.load %6[0, 0] : memref<1x1xi32>
    %8 = arith.addi %5, %7 : i32
    %9 = memref.get_global @gridDim : memref<1x1xi32>
    %10 = affine.load %9[0, 0] : memref<1x1xi32>
    %11 = arith.muli %4, %10 : i32
    %12 = arith.index_cast %arg6 : i32 to index
    %13 = arith.index_cast %8 : i32 to index
    %14 = arith.index_cast %11 : i32 to index
    scf.for %arg7 = %13 to %12 step %14 {
      %15 = arith.subi %arg7, %13 : index
      %16 = arith.divui %15, %14 : index
      %17 = arith.muli %16, %14 : index
      %18 = arith.addi %13, %17 : index
      %19 = arith.index_cast %18 : index to i32
      %20 = arith.muli %19, %c2_i32 : i32
      %21 = arith.index_cast %20 : i32 to index
      %22 = "polygeist.subindex"(%arg0, %21) : (memref<?xi32>, index) -> memref<?xi32>
      %23 = affine.load %22[0] : memref<?xi32>
      %24 = arith.extsi %19 : i32 to i64
      %25 = arith.muli %24, %c8_i64 : i64
      %26 = arith.addi %25, %c4_i64 : i64
      %27 = arith.cmpi slt, %26, %arg5 : i64
      %28 = arith.extui %27 : i1 to i8
      %29 = scf.if %27 -> (i32) {
        %38 = arith.addi %20, %c1_i32 : i32
        %39 = arith.index_cast %38 : i32 to index
        %40 = "polygeist.subindex"(%arg0, %39) : (memref<?xi32>, index) -> memref<?xi32>
        %41 = affine.load %40[0] : memref<?xi32>
        scf.yield %41 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      affine.store %c0_i8, %alloca_4[0] : memref<1xi8>
      affine.store %c0_i8, %alloca_2[0] : memref<1xi8>
      affine.store %c0_i8, %alloca_0[0] : memref<1xi8>
      affine.store %c0_i8, %alloca[0] : memref<1xi8>
      func.call @_Z22classifyEightByteWordsjjbRhS_S_S_(%23, %29, %28, %cast_5, %cast_3, %cast_1, %cast) : (i32, i32, i8, memref<?xi8>, memref<?xi8>, memref<?xi8>, memref<?xi8>) -> ()
      %30 = "polygeist.subindex"(%arg1, %18) : (memref<?xi8>, index) -> memref<?xi8>
      %31 = affine.load %alloca_4[0] : memref<1xi8>
      affine.store %31, %30[0] : memref<?xi8>
      %32 = "polygeist.subindex"(%arg2, %18) : (memref<?xi8>, index) -> memref<?xi8>
      %33 = affine.load %alloca_2[0] : memref<1xi8>
      affine.store %33, %32[0] : memref<?xi8>
      %34 = "polygeist.subindex"(%arg3, %18) : (memref<?xi8>, index) -> memref<?xi8>
      %35 = affine.load %alloca_0[0] : memref<1xi8>
      affine.store %35, %34[0] : memref<?xi8>
      %36 = "polygeist.subindex"(%arg4, %18) : (memref<?xi8>, index) -> memref<?xi8>
      %37 = affine.load %alloca[0] : memref<1xi8>
      affine.store %37, %36[0] : memref<?xi8>
    }
    return
  }
  func.func @_Z25findEscapedQuoteMerge_NEWPjS_S_iii(%arg0: memref<?xi32>, %arg1: memref<?xi32>, %arg2: memref<?xi32>, %arg3: i32, %arg4: i32, %arg5: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %true = arith.constant true
    %c-1431655766_i32 = arith.constant -1431655766 : i32
    %c1431655765_i32 = arith.constant 1431655765 : i32
    %c32_i32 = arith.constant 32 : i32
    %c-1_i32 = arith.constant -1 : i32
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c2_i32 = arith.constant 2 : i32
    %false = arith.constant false
    %0 = llvm.mlir.undef : i32
    %1 = memref.get_global @blockIdx : memref<1x1xi32>
    %2 = affine.load %1[0, 0] : memref<1x1xi32>
    %3 = memref.get_global @blockDim : memref<1x1xi32>
    %4 = affine.load %3[0, 0] : memref<1x1xi32>
    %5 = arith.muli %2, %4 : i32
    %6 = memref.get_global @threadIdx : memref<1x1xi32>
    %7 = affine.load %6[0, 0] : memref<1x1xi32>
    %8 = arith.addi %5, %7 : i32
    %9 = memref.get_global @gridDim : memref<1x1xi32>
    %10 = affine.load %9[0, 0] : memref<1x1xi32>
    %11 = arith.muli %4, %10 : i32
    %12 = arith.index_cast %arg4 : i32 to index
    %13 = arith.index_cast %8 : i32 to index
    %14 = arith.index_cast %11 : i32 to index
    %15:8 = scf.for %arg6 = %13 to %12 step %14 iter_args(%arg7 = %0, %arg8 = %0, %arg9 = %0, %arg10 = %0, %arg11 = %0, %arg12 = %0, %arg13 = %0, %arg14 = %0) -> (i32, i32, i32, i32, i32, i32, i32, i32) {
      %16 = arith.subi %arg6, %13 : index
      %17 = arith.divui %16, %14 : index
      %18 = arith.muli %17, %14 : index
      %19 = arith.addi %13, %18 : index
      %20 = arith.index_cast %19 : index to i32
      %21 = arith.muli %20, %arg5 : i32
      %22:9 = scf.while (%arg15 = %arg7, %arg16 = %arg8, %arg17 = %arg9, %arg18 = %arg10, %arg19 = %arg11, %arg20 = %arg12, %arg21 = %arg13, %arg22 = %arg14, %arg23 = %21) : (i32, i32, i32, i32, i32, i32, i32, i32, i32) -> (i32, i32, i32, i32, i32, i32, i32, i32, i32) {
        %23 = arith.cmpi slt, %arg23, %arg3 : i32
        %24 = scf.if %23 -> (i1) {
          %25 = arith.addi %21, %arg5 : i32
          %26 = arith.cmpi slt, %arg23, %25 : i32
          scf.yield %26 : i1
        } else {
          scf.yield %false : i1
        }
        scf.condition(%24) %arg15, %arg16, %arg17, %arg18, %arg19, %arg20, %arg21, %arg22, %arg23 : i32, i32, i32, i32, i32, i32, i32, i32, i32
      } do {
      ^bb0(%arg15: i32, %arg16: i32, %arg17: i32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32):
        %23 = arith.cmpi eq, %arg23, %c0_i32 : i32
        %24:4 = scf.if %23 -> (i32, i32, i32, i32) {
          scf.yield %arg19, %arg20, %arg21, %c0_i32 : i32, i32, i32, i32
        } else {
          %38 = arith.addi %arg23, %c-1_i32 : i32
          %39:4 = scf.while (%arg24 = %arg19, %arg25 = %arg20, %arg26 = %38, %arg27 = %c2_i32) : (i32, i32, i32, i32) -> (i32, i32, i32, i32) {
            %42 = arith.cmpi eq, %arg27, %c2_i32 : i32
            %43 = scf.if %42 -> (i1) {
              %44 = arith.cmpi sge, %arg26, %c0_i32 : i32
              scf.yield %44 : i1
            } else {
              scf.yield %false : i1
            }
            scf.condition(%43) %arg24, %arg25, %arg26, %arg27 : i32, i32, i32, i32
          } do {
          ^bb0(%arg24: i32, %arg25: i32, %arg26: i32, %arg27: i32):
            %42 = arith.index_cast %arg26 : i32 to index
            %43 = "polygeist.subindex"(%arg0, %42) : (memref<?xi32>, index) -> memref<?xi32>
            %44 = affine.load %43[0] : memref<?xi32>
            %45 = arith.xori %44, %c-1_i32 : i32
            %46 = arith.cmpi eq, %45, %c0_i32 : i32
            %47:2 = scf.if %46 -> (i32, i1) {
              scf.yield %c32_i32, %true : i32, i1
            } else {
              %50 = math.ctlz %45 : i32
              %51 = arith.cmpi eq, %50, %c32_i32 : i32
              scf.yield %50, %51 : i32, i1
            }
            %48 = scf.if %47#1 -> (i32) {
              scf.yield %c2_i32 : i32
            } else {
              %50 = arith.andi %47#0, %c1_i32 : i32
              scf.yield %50 : i32
            }
            %49 = arith.addi %arg26, %c-1_i32 : i32
            scf.yield %47#0, %44, %49, %48 : i32, i32, i32, i32
          }
          %40 = arith.cmpi eq, %39#3, %c2_i32 : i32
          %41 = arith.select %40, %c0_i32, %39#3 : i32
          scf.yield %39#0, %39#1, %39#2, %41 : i32, i32, i32, i32
        }
        %25 = arith.index_cast %arg23 : i32 to index
        %26 = "polygeist.subindex"(%arg1, %25) : (memref<?xi32>, index) -> memref<?xi32>
        %27 = affine.load %26[0] : memref<?xi32>
        %28 = "polygeist.subindex"(%arg0, %25) : (memref<?xi32>, index) -> memref<?xi32>
        %29 = affine.load %28[0] : memref<?xi32>
        %30 = arith.shli %29, %c1_i32 : i32
        %31 = arith.ori %30, %24#3 : i32
        %32 = arith.andi %27, %31 : i32
        %33 = arith.cmpi eq, %32, %c0_i32 : i32
        %34 = scf.if %33 -> (i32) {
          scf.yield %27 : i32
        } else {
          %38 = arith.xori %24#3, %c-1_i32 : i32
          %39 = arith.andi %29, %38 : i32
          %40 = arith.shli %39, %c1_i32 : i32
          %41 = arith.ori %40, %24#3 : i32
          %42 = arith.andi %39, %c-1431655766_i32 : i32
          %43 = arith.xori %41, %c-1_i32 : i32
          %44 = arith.andi %42, %43 : i32
          %45 = arith.addi %44, %39 : i32
          %46 = arith.shli %45, %c1_i32 : i32
          %47 = arith.xori %46, %c1431655765_i32 : i32
          %48 = arith.andi %47, %41 : i32
          %49 = arith.xori %48, %c-1_i32 : i32
          %50 = arith.andi %49, %27 : i32
          scf.yield %50 : i32
        }
        %35 = "polygeist.subindex"(%arg2, %25) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %34, %35[0] : memref<?xi32>
        %36 = func.call @__builtin_popcount(%34) : (i32) -> i32
        affine.store %36, %26[0] : memref<?xi32>
        %37 = arith.addi %arg23, %c1_i32 : i32
        scf.yield %34, %32, %29, %27, %24#0, %24#1, %24#2, %24#3, %37 : i32, i32, i32, i32, i32, i32, i32, i32, i32
      }
      scf.yield %22#0, %22#1, %22#2, %22#3, %22#4, %22#5, %22#6, %22#7 : i32, i32, i32, i32, i32, i32, i32, i32
    }
    return
  }
  func.func private @_Z33thrust_exclusive_scan_quote_countPjS_i(memref<?xi32>, memref<?xi32>, i32) attributes {llvm.linkage = #llvm.linkage<external>}
  func.func @_Z22inStringFinderBaselinePjS_S_i(%arg0: memref<?xi32>, %arg1: memref<?xi32>, %arg2: memref<?xi32>, %arg3: i32) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c2_i32 = arith.constant 2 : i32
    %c4_i32 = arith.constant 4 : i32
    %c8_i32 = arith.constant 8 : i32
    %c16_i32 = arith.constant 16 : i32
    %c-1_i32 = arith.constant -1 : i32
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
    %11 = arith.index_cast %arg3 : i32 to index
    %12 = arith.index_cast %7 : i32 to index
    %13 = arith.index_cast %10 : i32 to index
    scf.for %arg4 = %12 to %11 step %13 {
      %14 = arith.subi %arg4, %12 : index
      %15 = arith.divui %14, %13 : index
      %16 = arith.muli %15, %13 : index
      %17 = arith.addi %12, %16 : index
      %18 = "polygeist.subindex"(%arg1, %17) : (memref<?xi32>, index) -> memref<?xi32>
      %19 = affine.load %18[0] : memref<?xi32>
      %20 = arith.andi %19, %c1_i32 : i32
      %21 = arith.cmpi ne, %20, %c0_i32 : i32
      %22 = "polygeist.subindex"(%arg0, %17) : (memref<?xi32>, index) -> memref<?xi32>
      %23 = affine.load %22[0] : memref<?xi32>
      %24 = arith.shli %23, %c1_i32 : i32
      %25 = arith.xori %23, %24 : i32
      %26 = arith.shli %25, %c2_i32 : i32
      %27 = arith.xori %25, %26 : i32
      %28 = arith.shli %27, %c4_i32 : i32
      %29 = arith.xori %27, %28 : i32
      %30 = arith.shli %29, %c8_i32 : i32
      %31 = arith.xori %29, %30 : i32
      %32 = arith.shli %31, %c16_i32 : i32
      %33 = arith.xori %31, %32 : i32
      %34 = "polygeist.subindex"(%arg2, %17) : (memref<?xi32>, index) -> memref<?xi32>
      %35 = scf.if %21 -> (i32) {
        %36 = arith.xori %33, %c-1_i32 : i32
        scf.yield %36 : i32
      } else {
        scf.yield %33 : i32
      }
      affine.store %35, %34[0] : memref<?xi32>
    }
    return
  }
  func.func @_Z24findOutUsefulStringMergePjS_S_yiiS_(%arg0: memref<?xi32>, %arg1: memref<?xi32>, %arg2: memref<?xi32>, %arg3: i64, %arg4: i32, %arg5: i32, %arg6: memref<?xi32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c1_i32 = arith.constant 1 : i32
    %c-1_i32 = arith.constant -1 : i32
    %false = arith.constant false
    %0 = llvm.mlir.undef : i32
    %1 = memref.get_global @blockIdx : memref<1x1xi32>
    %2 = affine.load %1[0, 0] : memref<1x1xi32>
    %3 = memref.get_global @blockDim : memref<1x1xi32>
    %4 = affine.load %3[0, 0] : memref<1x1xi32>
    %5 = arith.muli %2, %4 : i32
    %6 = memref.get_global @threadIdx : memref<1x1xi32>
    %7 = affine.load %6[0, 0] : memref<1x1xi32>
    %8 = arith.addi %5, %7 : i32
    %9 = memref.get_global @gridDim : memref<1x1xi32>
    %10 = affine.load %9[0, 0] : memref<1x1xi32>
    %11 = arith.muli %4, %10 : i32
    %12 = arith.index_cast %arg4 : i32 to index
    %13 = arith.index_cast %8 : i32 to index
    %14 = arith.index_cast %11 : i32 to index
    %15:5 = scf.for %arg7 = %13 to %12 step %14 iter_args(%arg8 = %0, %arg9 = %0, %arg10 = %0, %arg11 = %0, %arg12 = %0) -> (i32, i32, i32, i32, i32) {
      %16 = arith.subi %arg7, %13 : index
      %17 = arith.divui %16, %14 : index
      %18 = arith.muli %17, %14 : index
      %19 = arith.addi %13, %18 : index
      %20 = arith.index_cast %19 : index to i32
      %21 = arith.muli %20, %arg5 : i32
      %22:6 = scf.while (%arg13 = %arg8, %arg14 = %arg9, %arg15 = %arg10, %arg16 = %arg11, %arg17 = %arg12, %arg18 = %21) : (i32, i32, i32, i32, i32, i32) -> (i32, i32, i32, i32, i32, i32) {
        %23 = arith.extsi %arg18 : i32 to i64
        %24 = arith.cmpi slt, %23, %arg3 : i64
        %25 = scf.if %24 -> (i1) {
          %26 = arith.addi %21, %arg5 : i32
          %27 = arith.cmpi slt, %arg18, %26 : i32
          scf.yield %27 : i1
        } else {
          scf.yield %false : i1
        }
        scf.condition(%25) %arg13, %arg14, %arg15, %arg16, %arg17, %arg18 : i32, i32, i32, i32, i32, i32
      } do {
      ^bb0(%arg13: i32, %arg14: i32, %arg15: i32, %arg16: i32, %arg17: i32, %arg18: i32):
        %23 = arith.index_cast %arg18 : i32 to index
        %24 = "polygeist.subindex"(%arg0, %23) : (memref<?xi32>, index) -> memref<?xi32>
        %25 = affine.load %24[0] : memref<?xi32>
        %26 = "polygeist.subindex"(%arg1, %23) : (memref<?xi32>, index) -> memref<?xi32>
        %27 = affine.load %26[0] : memref<?xi32>
        %28 = "polygeist.subindex"(%arg2, %23) : (memref<?xi32>, index) -> memref<?xi32>
        %29 = affine.load %28[0] : memref<?xi32>
        %30 = arith.xori %29, %c-1_i32 : i32
        %31 = arith.andi %30, %25 : i32
        %32 = arith.andi %30, %27 : i32
        affine.store %31, %28[0] : memref<?xi32>
        affine.store %32, %26[0] : memref<?xi32>
        %33 = "polygeist.subindex"(%arg6, %23) : (memref<?xi32>, index) -> memref<?xi32>
        %34 = func.call @__builtin_popcount(%31) : (i32) -> i32
        affine.store %34, %33[0] : memref<?xi32>
        %35 = func.call @__builtin_popcount(%32) : (i32) -> i32
        affine.store %35, %24[0] : memref<?xi32>
        %36 = arith.addi %arg18, %c1_i32 : i32
        scf.yield %32, %31, %29, %27, %25, %36 : i32, i32, i32, i32, i32, i32
      }
      scf.yield %22#0, %22#1, %22#2, %22#3, %22#4 : i32, i32, i32, i32, i32
    }
    return
  }
  func.func @_Z21validateUtf8FourBytesjj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c-538976289_i32 = arith.constant -538976289 : i32
    %c-269488145_i32 = arith.constant -269488145 : i32
    %c-128_i32 = arith.constant -128 : i32
    %c127_i32 = arith.constant 127 : i32
    %c33686018_i32 = arith.constant 33686018 : i32
    %c-1061109568_i32 = arith.constant -1061109568 : i32
    %c16843009_i32 = arith.constant 16843009 : i32
    %c-1044266559_i32 = arith.constant -1044266559 : i32
    %c538976288_i32 = arith.constant 538976288 : i32
    %c-303174163_i32 = arith.constant -303174163 : i32
    %c269488144_i32 = arith.constant 269488144 : i32
    %c-522133280_i32 = arith.constant -522133280 : i32
    %c67372036_i32 = arith.constant 67372036 : i32
    %c-252645136_i32 = arith.constant -252645136 : i32
    %c1077952576_i32 = arith.constant 1077952576 : i32
    %c-185273100_i32 = arith.constant -185273100 : i32
    %c-202116109_i32 = arith.constant -202116109 : i32
    %c134744072_i32 = arith.constant 134744072 : i32
    %c252645135_i32 = arith.constant 252645135 : i32
    %c202116108_i32 = arith.constant 202116108 : i32
    %c185273099_i32 = arith.constant 185273099 : i32
    %c151587081_i32 = arith.constant 151587081 : i32
    %c-1566399838_i32 = arith.constant -1566399838 : i32
    %c4_i32 = arith.constant 4 : i32
    %c8_i32 = arith.constant 8 : i32
    %c255_i32 = arith.constant 255 : i32
    %c-1075843073_i32 = arith.constant -1075843073 : i32
    %c8_i64 = arith.constant 8 : i64
    %c16_i64 = arith.constant 16 : i64
    %c24_i64 = arith.constant 24 : i64
    %c32_i64 = arith.constant 32 : i64
    %c0_i32 = arith.constant 0 : i32
    %c-2139062144_i32 = arith.constant -2139062144 : i32
    %0 = llvm.mlir.undef : i32
    %1 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %7 = arith.index_cast %arg2 : index to i32
      %8 = arith.muli %7, %c8_i32 : i32
      %9 = arith.shrsi %arg1, %8 : i32
      %10 = arith.andi %9, %c255_i32 : i32
      %11 = arith.shrsi %c-1075843073_i32, %8 : i32
      %12 = arith.andi %11, %c255_i32 : i32
      %13 = arith.cmpi sgt, %10, %12 : i32
      %14 = scf.if %13 -> (i32) {
        %17 = arith.subi %10, %12 : i32
        scf.yield %17 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %15 = arith.shli %14, %8 : i32
      %16 = arith.ori %arg3, %15 : i32
      scf.yield %16 : i32
    }
    %2 = arith.andi %arg0, %c-2139062144_i32 : i32
    %3 = arith.cmpi eq, %2, %c0_i32 : i32
    %4 = arith.select %3, %1, %0 : i32
    %5 = arith.cmpi ne, %2, %c0_i32 : i32
    %6 = scf.if %5 -> (i32) {
      %7 = arith.extsi %arg0 : i32 to i64
      %8 = arith.shli %7, %c32_i64 : i64
      %9 = arith.extsi %arg1 : i32 to i64
      %10 = arith.ori %8, %9 : i64
      %11 = arith.shrsi %10, %c24_i64 : i64
      %12 = arith.trunci %11 : i64 to i32
      %13 = arith.shrsi %10, %c16_i64 : i64
      %14 = arith.trunci %13 : i64 to i32
      %15 = arith.shrsi %10, %c8_i64 : i64
      %16 = arith.trunci %15 : i64 to i32
      %17 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-2139062144_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi slt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %18 = arith.andi %17, %c33686018_i32 : i32
      %19 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-1061109568_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sge, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %20 = arith.andi %19, %c16843009_i32 : i32
      %21 = arith.ori %18, %20 : i32
      %22 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-1061109568_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %23 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-1044266559_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %24 = arith.ori %22, %23 : i32
      %25 = arith.andi %24, %c538976288_i32 : i32
      %26 = arith.ori %21, %25 : i32
      %27 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-303174163_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %28 = arith.andi %27, %c269488144_i32 : i32
      %29 = arith.ori %26, %28 : i32
      %30 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-522133280_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %31 = arith.andi %30, %c67372036_i32 : i32
      %32 = arith.ori %29, %31 : i32
      %33 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-252645136_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %34 = arith.andi %33, %c1077952576_i32 : i32
      %35 = arith.ori %32, %34 : i32
      %36 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-185273100_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %37 = arith.andi %36, %c1077952576_i32 : i32
      %38 = arith.ori %35, %37 : i32
      %39 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %12, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-202116109_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %40 = arith.andi %39, %c134744072_i32 : i32
      %41 = arith.ori %38, %40 : i32
      %42 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %41, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c0_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %43 = arith.andi %42, %c-2139062144_i32 : i32
      %44 = arith.shrsi %arg0, %c4_i32 : i32
      %45 = arith.andi %44, %c252645135_i32 : i32
      %46 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c202116108_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi slt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %47 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c134744072_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi slt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %48 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c185273099_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %49 = arith.ori %47, %48 : i32
      %50 = arith.andi %49, %c16843009_i32 : i32
      %51 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c134744072_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sge, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %52 = arith.andi %46, %51 : i32
      %53 = arith.andi %52, %c-1566399838_i32 : i32
      %54 = arith.ori %50, %53 : i32
      %55 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c134744072_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %56 = arith.andi %46, %55 : i32
      %57 = arith.andi %56, %c134744072_i32 : i32
      %58 = arith.ori %54, %57 : i32
      %59 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c134744072_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi eq, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %60 = arith.andi %59, %c1077952576_i32 : i32
      %61 = arith.ori %58, %60 : i32
      %62 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %45, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c151587081_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %63 = arith.andi %62, %46 : i32
      %64 = arith.andi %63, %c269488144_i32 : i32
      %65 = arith.ori %61, %64 : i32
      %66 = arith.andi %43, %65 : i32
      %67 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %14, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-538976289_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %84 = arith.subi %77, %79 : i32
          scf.yield %84 : i32
        } else {
          scf.yield %c0_i32 : i32
        }
        %82 = arith.shli %81, %75 : i32
        %83 = arith.ori %arg3, %82 : i32
        scf.yield %83 : i32
      }
      %68 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %16, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c-269488145_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %84 = arith.subi %77, %79 : i32
          scf.yield %84 : i32
        } else {
          scf.yield %c0_i32 : i32
        }
        %82 = arith.shli %81, %75 : i32
        %83 = arith.ori %arg3, %82 : i32
        scf.yield %83 : i32
      }
      %69 = arith.ori %67, %68 : i32
      %70 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %69, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.trunci %77 : i32 to i8
        %79 = arith.extsi %78 : i8 to i32
        %80 = arith.shrsi %c0_i32, %75 : i32
        %81 = arith.andi %80, %c255_i32 : i32
        %82 = arith.trunci %81 : i32 to i8
        %83 = arith.extsi %82 : i8 to i32
        %84 = arith.subi %79, %83 : i32
        %85 = arith.cmpi sgt, %84, %c127_i32 : i32
        %86 = arith.select %85, %c127_i32, %84 : i32
        %87 = arith.cmpi slt, %86, %c-128_i32 : i32
        %88 = arith.select %87, %c-128_i32, %86 : i32
        %89 = arith.andi %88, %c255_i32 : i32
        %90 = arith.shli %89, %75 : i32
        %91 = arith.ori %arg3, %90 : i32
        scf.yield %91 : i32
      }
      %71 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
        %74 = arith.index_cast %arg2 : index to i32
        %75 = arith.muli %74, %c8_i32 : i32
        %76 = arith.shrsi %70, %75 : i32
        %77 = arith.andi %76, %c255_i32 : i32
        %78 = arith.shrsi %c0_i32, %75 : i32
        %79 = arith.andi %78, %c255_i32 : i32
        %80 = arith.cmpi sgt, %77, %79 : i32
        %81 = scf.if %80 -> (i32) {
          %82 = arith.shli %c255_i32, %75 : i32
          %83 = arith.ori %arg3, %82 : i32
          scf.yield %83 : i32
        } else {
          scf.yield %arg3 : i32
        }
        scf.yield %81 : i32
      }
      %72 = arith.andi %71, %c-2139062144_i32 : i32
      %73 = arith.xori %72, %66 : i32
      scf.yield %73 : i32
    } else {
      scf.yield %4 : i32
    }
    return %6 : i32
  }
  func.func @_Z22classifyEightByteWordsjjbRhS_S_S_(%arg0: i32, %arg1: i32, %arg2: i8, %arg3: memref<?xi8>, %arg4: memref<?xi8>, %arg5: memref<?xi8>, %arg6: memref<?xi8>) attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c15_i32 = arith.constant 15 : i32
    %c7_i32 = arith.constant 7 : i32
    %c4_i32 = arith.constant 4 : i32
    %c0_i32 = arith.constant 0 : i32
    %c0_i8 = arith.constant 0 : i8
    %c741092396_i32 = arith.constant 741092396 : i32
    %c976894522_i32 = arith.constant 976894522 : i32
    %c2105376125_i32 = arith.constant 2105376125 : i32
    %c2071690107_i32 = arith.constant 2071690107 : i32
    %c1566399837_i32 = arith.constant 1566399837 : i32
    %c1532713819_i32 = arith.constant 1532713819 : i32
    %c572662306_i32 = arith.constant 572662306 : i32
    %c16843009_i32 = arith.constant 16843009 : i32
    %c1549556828_i32 = arith.constant 1549556828 : i32
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %0 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c1549556828_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %1 = arith.andi %0, %c16843009_i32 : i32
    %2 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c572662306_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %3 = arith.andi %2, %c16843009_i32 : i32
    %4 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c1532713819_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %5 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c1566399837_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %6 = arith.ori %4, %5 : i32
    %7 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c2071690107_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %8 = arith.ori %6, %7 : i32
    %9 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c2105376125_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %10 = arith.ori %8, %9 : i32
    %11 = arith.andi %10, %c16843009_i32 : i32
    %12 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c976894522_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %13 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
      %18 = arith.index_cast %arg7 : index to i32
      %19 = arith.muli %18, %c8_i32 : i32
      %20 = arith.shrsi %arg0, %19 : i32
      %21 = arith.andi %20, %c255_i32 : i32
      %22 = arith.shrsi %c741092396_i32, %19 : i32
      %23 = arith.andi %22, %c255_i32 : i32
      %24 = arith.cmpi eq, %21, %23 : i32
      %25 = scf.if %24 -> (i32) {
        %26 = arith.shli %c255_i32, %19 : i32
        %27 = arith.ori %arg8, %26 : i32
        scf.yield %27 : i32
      } else {
        scf.yield %arg8 : i32
      }
      scf.yield %25 : i32
    }
    %14 = arith.ori %12, %13 : i32
    %15 = arith.andi %14, %c16843009_i32 : i32
    %16 = arith.ori %15, %11 : i32
    affine.store %c0_i8, %arg3[0] : memref<?xi8>
    affine.store %c0_i8, %arg4[0] : memref<?xi8>
    affine.store %c0_i8, %arg5[0] : memref<?xi8>
    affine.store %c0_i8, %arg6[0] : memref<?xi8>
    %17 = arith.cmpi ne, %arg2, %c0_i8 : i8
    scf.if %17 {
      %18 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c1549556828_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %19 = arith.andi %18, %c16843009_i32 : i32
      %20 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c572662306_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %21 = arith.andi %20, %c16843009_i32 : i32
      %22 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c1532713819_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %23 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c1566399837_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %24 = arith.ori %22, %23 : i32
      %25 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c2071690107_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %26 = arith.ori %24, %25 : i32
      %27 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c2105376125_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %28 = arith.ori %26, %27 : i32
      %29 = arith.andi %28, %c16843009_i32 : i32
      %30 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c976894522_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %31 = scf.for %arg7 = %c0 to %c4 step %c1 iter_args(%arg8 = %c0_i32) -> (i32) {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = arith.muli %35, %c8_i32 : i32
        %37 = arith.shrsi %arg1, %36 : i32
        %38 = arith.andi %37, %c255_i32 : i32
        %39 = arith.shrsi %c741092396_i32, %36 : i32
        %40 = arith.andi %39, %c255_i32 : i32
        %41 = arith.cmpi eq, %38, %40 : i32
        %42 = scf.if %41 -> (i32) {
          %43 = arith.shli %c255_i32, %36 : i32
          %44 = arith.ori %arg8, %43 : i32
          scf.yield %44 : i32
        } else {
          scf.yield %arg8 : i32
        }
        scf.yield %42 : i32
      }
      %32 = arith.ori %30, %31 : i32
      %33 = arith.andi %32, %c16843009_i32 : i32
      %34 = arith.ori %33, %29 : i32
      scf.for %arg7 = %c0 to %c4 step %c1 {
        %35 = arith.index_cast %arg7 : index to i32
        %36 = affine.load %arg3[0] : memref<?xi8>
        %37 = arith.extsi %36 : i8 to i32
        %38 = arith.muli %35, %c7_i32 : i32
        %39 = arith.shrsi %1, %38 : i32
        %40 = arith.andi %39, %c15_i32 : i32
        %41 = arith.ori %37, %40 : i32
        %42 = arith.shrsi %19, %38 : i32
        %43 = arith.andi %42, %c15_i32 : i32
        %44 = arith.shli %43, %c4_i32 : i32
        %45 = arith.ori %41, %44 : i32
        %46 = arith.trunci %45 : i32 to i8
        affine.store %46, %arg3[0] : memref<?xi8>
        %47 = affine.load %arg4[0] : memref<?xi8>
        %48 = arith.extsi %47 : i8 to i32
        %49 = arith.shrsi %3, %38 : i32
        %50 = arith.andi %49, %c15_i32 : i32
        %51 = arith.ori %48, %50 : i32
        %52 = arith.shrsi %21, %38 : i32
        %53 = arith.andi %52, %c15_i32 : i32
        %54 = arith.shli %53, %c4_i32 : i32
        %55 = arith.ori %51, %54 : i32
        %56 = arith.trunci %55 : i32 to i8
        affine.store %56, %arg4[0] : memref<?xi8>
        %57 = affine.load %arg5[0] : memref<?xi8>
        %58 = arith.extsi %57 : i8 to i32
        %59 = arith.shrsi %16, %38 : i32
        %60 = arith.andi %59, %c15_i32 : i32
        %61 = arith.ori %58, %60 : i32
        %62 = arith.shrsi %34, %38 : i32
        %63 = arith.andi %62, %c15_i32 : i32
        %64 = arith.shli %63, %c4_i32 : i32
        %65 = arith.ori %61, %64 : i32
        %66 = arith.trunci %65 : i32 to i8
        affine.store %66, %arg5[0] : memref<?xi8>
        %67 = affine.load %arg6[0] : memref<?xi8>
        %68 = arith.extsi %67 : i8 to i32
        %69 = arith.shrsi %11, %38 : i32
        %70 = arith.andi %69, %c15_i32 : i32
        %71 = arith.ori %68, %70 : i32
        %72 = arith.shrsi %29, %38 : i32
        %73 = arith.andi %72, %c15_i32 : i32
        %74 = arith.shli %73, %c4_i32 : i32
        %75 = arith.ori %71, %74 : i32
        %76 = arith.trunci %75 : i32 to i8
        affine.store %76, %arg6[0] : memref<?xi8>
      }
    } else {
      scf.for %arg7 = %c0 to %c4 step %c1 {
        %18 = arith.index_cast %arg7 : index to i32
        %19 = affine.load %arg3[0] : memref<?xi8>
        %20 = arith.extsi %19 : i8 to i32
        %21 = arith.muli %18, %c7_i32 : i32
        %22 = arith.shrsi %1, %21 : i32
        %23 = arith.andi %22, %c15_i32 : i32
        %24 = arith.ori %20, %23 : i32
        %25 = arith.trunci %24 : i32 to i8
        affine.store %25, %arg3[0] : memref<?xi8>
        %26 = affine.load %arg4[0] : memref<?xi8>
        %27 = arith.extsi %26 : i8 to i32
        %28 = arith.shrsi %3, %21 : i32
        %29 = arith.andi %28, %c15_i32 : i32
        %30 = arith.ori %27, %29 : i32
        %31 = arith.trunci %30 : i32 to i8
        affine.store %31, %arg4[0] : memref<?xi8>
        %32 = affine.load %arg5[0] : memref<?xi8>
        %33 = arith.extsi %32 : i8 to i32
        %34 = arith.shrsi %16, %21 : i32
        %35 = arith.andi %34, %c15_i32 : i32
        %36 = arith.ori %33, %35 : i32
        %37 = arith.trunci %36 : i32 to i8
        affine.store %37, %arg5[0] : memref<?xi8>
        %38 = affine.load %arg6[0] : memref<?xi8>
        %39 = arith.extsi %38 : i8 to i32
        %40 = arith.shrsi %11, %21 : i32
        %41 = arith.andi %40, %c15_i32 : i32
        %42 = arith.ori %39, %41 : i32
        %43 = arith.trunci %42 : i32 to i8
        affine.store %43, %arg6[0] : memref<?xi8>
      }
    }
    return
  }
  func.func @_Z5__clzj(%arg0: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c32_i32 = arith.constant 32 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = arith.cmpi eq, %arg0, %c0_i32 : i32
    %1 = scf.if %0 -> (i32) {
      scf.yield %c32_i32 : i32
    } else {
      %2 = math.ctlz %arg0 : i32
      scf.yield %2 : i32
    }
    return %1 : i32
  }
  func.func @_Z23filterEscapedQuotesWordjjj(%arg0: i32, %arg1: i32, %arg2: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c1431655765_i32 = arith.constant 1431655765 : i32
    %c-1431655766_i32 = arith.constant -1431655766 : i32
    %c1_i32 = arith.constant 1 : i32
    %c-1_i32 = arith.constant -1 : i32
    %0 = arith.xori %arg2, %c-1_i32 : i32
    %1 = arith.andi %arg1, %0 : i32
    %2 = arith.shli %1, %c1_i32 : i32
    %3 = arith.ori %2, %arg2 : i32
    %4 = arith.andi %1, %c-1431655766_i32 : i32
    %5 = arith.xori %3, %c-1_i32 : i32
    %6 = arith.andi %4, %5 : i32
    %7 = arith.addi %6, %1 : i32
    %8 = arith.shli %7, %c1_i32 : i32
    %9 = arith.xori %8, %c1431655765_i32 : i32
    %10 = arith.andi %9, %3 : i32
    %11 = arith.xori %10, %c-1_i32 : i32
    %12 = arith.andi %11, %arg0 : i32
    return %12 : i32
  }
  func.func @_Z6__popcj(%arg0: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %0 = call @__builtin_popcount(%arg0) : (i32) -> i32
    return %0 : i32
  }
  func.func @_Z10prefix_xorj(%arg0: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c16_i32 = arith.constant 16 : i32
    %c8_i32 = arith.constant 8 : i32
    %c4_i32 = arith.constant 4 : i32
    %c2_i32 = arith.constant 2 : i32
    %c1_i32 = arith.constant 1 : i32
    %0 = arith.shli %arg0, %c1_i32 : i32
    %1 = arith.xori %arg0, %0 : i32
    %2 = arith.shli %1, %c2_i32 : i32
    %3 = arith.xori %1, %2 : i32
    %4 = arith.shli %3, %c4_i32 : i32
    %5 = arith.xori %3, %4 : i32
    %6 = arith.shli %5, %c8_i32 : i32
    %7 = arith.xori %5, %6 : i32
    %8 = arith.shli %7, %c16_i32 : i32
    %9 = arith.xori %7, %8 : i32
    return %9 : i32
  }
  func.func @_Z9__vsubus4jj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.shrsi %arg1, %2 : i32
      %6 = arith.andi %5, %c255_i32 : i32
      %7 = arith.cmpi sgt, %4, %6 : i32
      %8 = scf.if %7 -> (i32) {
        %11 = arith.subi %4, %6 : i32
        scf.yield %11 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %9 = arith.shli %8, %2 : i32
      %10 = arith.ori %arg3, %9 : i32
      scf.yield %10 : i32
    }
    return %0 : i32
  }
  func.func @_Z21classifyUtf8FourBytesjj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c-1566399838_i32 = arith.constant -1566399838 : i32
    %c151587081_i32 = arith.constant 151587081 : i32
    %c185273099_i32 = arith.constant 185273099 : i32
    %c202116108_i32 = arith.constant 202116108 : i32
    %c252645135_i32 = arith.constant 252645135 : i32
    %c4_i32 = arith.constant 4 : i32
    %c0_i32 = arith.constant 0 : i32
    %c134744072_i32 = arith.constant 134744072 : i32
    %c-202116109_i32 = arith.constant -202116109 : i32
    %c-185273100_i32 = arith.constant -185273100 : i32
    %c1077952576_i32 = arith.constant 1077952576 : i32
    %c-252645136_i32 = arith.constant -252645136 : i32
    %c67372036_i32 = arith.constant 67372036 : i32
    %c-522133280_i32 = arith.constant -522133280 : i32
    %c269488144_i32 = arith.constant 269488144 : i32
    %c-303174163_i32 = arith.constant -303174163 : i32
    %c538976288_i32 = arith.constant 538976288 : i32
    %c-1044266559_i32 = arith.constant -1044266559 : i32
    %c16843009_i32 = arith.constant 16843009 : i32
    %c-1061109568_i32 = arith.constant -1061109568 : i32
    %c33686018_i32 = arith.constant 33686018 : i32
    %c-2139062144_i32 = arith.constant -2139062144 : i32
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-2139062144_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi slt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %1 = arith.andi %0, %c33686018_i32 : i32
    %2 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-1061109568_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sge, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %3 = arith.andi %2, %c16843009_i32 : i32
    %4 = arith.ori %1, %3 : i32
    %5 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-1061109568_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %6 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-1044266559_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %7 = arith.ori %5, %6 : i32
    %8 = arith.andi %7, %c538976288_i32 : i32
    %9 = arith.ori %4, %8 : i32
    %10 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-303174163_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %11 = arith.andi %10, %c269488144_i32 : i32
    %12 = arith.ori %9, %11 : i32
    %13 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-522133280_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %14 = arith.andi %13, %c67372036_i32 : i32
    %15 = arith.ori %12, %14 : i32
    %16 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-252645136_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %17 = arith.andi %16, %c1077952576_i32 : i32
    %18 = arith.ori %15, %17 : i32
    %19 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-185273100_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sgt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %20 = arith.andi %19, %c1077952576_i32 : i32
    %21 = arith.ori %18, %20 : i32
    %22 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %arg1, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c-202116109_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sgt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %23 = arith.andi %22, %c134744072_i32 : i32
    %24 = arith.ori %21, %23 : i32
    %25 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %24, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c0_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %26 = arith.andi %25, %c-2139062144_i32 : i32
    %27 = arith.shrsi %arg0, %c4_i32 : i32
    %28 = arith.andi %27, %c252645135_i32 : i32
    %29 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c202116108_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi slt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %30 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c134744072_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi slt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %31 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c185273099_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sgt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %32 = arith.ori %30, %31 : i32
    %33 = arith.andi %32, %c16843009_i32 : i32
    %34 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c134744072_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sge, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %35 = arith.andi %29, %34 : i32
    %36 = arith.andi %35, %c-1566399838_i32 : i32
    %37 = arith.ori %33, %36 : i32
    %38 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c134744072_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sgt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %39 = arith.andi %29, %38 : i32
    %40 = arith.andi %39, %c134744072_i32 : i32
    %41 = arith.ori %37, %40 : i32
    %42 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c134744072_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi eq, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %43 = arith.andi %42, %c1077952576_i32 : i32
    %44 = arith.ori %41, %43 : i32
    %45 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %50 = arith.index_cast %arg2 : index to i32
      %51 = arith.muli %50, %c8_i32 : i32
      %52 = arith.shrsi %28, %51 : i32
      %53 = arith.andi %52, %c255_i32 : i32
      %54 = arith.shrsi %c151587081_i32, %51 : i32
      %55 = arith.andi %54, %c255_i32 : i32
      %56 = arith.cmpi sgt, %53, %55 : i32
      %57 = scf.if %56 -> (i32) {
        %58 = arith.shli %c255_i32, %51 : i32
        %59 = arith.ori %arg3, %58 : i32
        scf.yield %59 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %57 : i32
    }
    %46 = arith.andi %45, %29 : i32
    %47 = arith.andi %46, %c269488144_i32 : i32
    %48 = arith.ori %44, %47 : i32
    %49 = arith.andi %26, %48 : i32
    return %49 : i32
  }
  func.func @_Z26checkUtf8ContinuationBytesjjj(%arg0: i32, %arg1: i32, %arg2: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c127_i32 = arith.constant 127 : i32
    %c-128_i32 = arith.constant -128 : i32
    %c-2139062144_i32 = arith.constant -2139062144 : i32
    %c0_i32 = arith.constant 0 : i32
    %c-269488145_i32 = arith.constant -269488145 : i32
    %c-538976289_i32 = arith.constant -538976289 : i32
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %0 = scf.for %arg3 = %c0 to %c4 step %c1 iter_args(%arg4 = %c0_i32) -> (i32) {
      %7 = arith.index_cast %arg3 : index to i32
      %8 = arith.muli %7, %c8_i32 : i32
      %9 = arith.shrsi %arg0, %8 : i32
      %10 = arith.andi %9, %c255_i32 : i32
      %11 = arith.shrsi %c-538976289_i32, %8 : i32
      %12 = arith.andi %11, %c255_i32 : i32
      %13 = arith.cmpi sgt, %10, %12 : i32
      %14 = scf.if %13 -> (i32) {
        %17 = arith.subi %10, %12 : i32
        scf.yield %17 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %15 = arith.shli %14, %8 : i32
      %16 = arith.ori %arg4, %15 : i32
      scf.yield %16 : i32
    }
    %1 = scf.for %arg3 = %c0 to %c4 step %c1 iter_args(%arg4 = %c0_i32) -> (i32) {
      %7 = arith.index_cast %arg3 : index to i32
      %8 = arith.muli %7, %c8_i32 : i32
      %9 = arith.shrsi %arg1, %8 : i32
      %10 = arith.andi %9, %c255_i32 : i32
      %11 = arith.shrsi %c-269488145_i32, %8 : i32
      %12 = arith.andi %11, %c255_i32 : i32
      %13 = arith.cmpi sgt, %10, %12 : i32
      %14 = scf.if %13 -> (i32) {
        %17 = arith.subi %10, %12 : i32
        scf.yield %17 : i32
      } else {
        scf.yield %c0_i32 : i32
      }
      %15 = arith.shli %14, %8 : i32
      %16 = arith.ori %arg4, %15 : i32
      scf.yield %16 : i32
    }
    %2 = arith.ori %0, %1 : i32
    %3 = scf.for %arg3 = %c0 to %c4 step %c1 iter_args(%arg4 = %c0_i32) -> (i32) {
      %7 = arith.index_cast %arg3 : index to i32
      %8 = arith.muli %7, %c8_i32 : i32
      %9 = arith.shrsi %2, %8 : i32
      %10 = arith.andi %9, %c255_i32 : i32
      %11 = arith.trunci %10 : i32 to i8
      %12 = arith.extsi %11 : i8 to i32
      %13 = arith.shrsi %c0_i32, %8 : i32
      %14 = arith.andi %13, %c255_i32 : i32
      %15 = arith.trunci %14 : i32 to i8
      %16 = arith.extsi %15 : i8 to i32
      %17 = arith.subi %12, %16 : i32
      %18 = arith.cmpi sgt, %17, %c127_i32 : i32
      %19 = arith.select %18, %c127_i32, %17 : i32
      %20 = arith.cmpi slt, %19, %c-128_i32 : i32
      %21 = arith.select %20, %c-128_i32, %19 : i32
      %22 = arith.andi %21, %c255_i32 : i32
      %23 = arith.shli %22, %8 : i32
      %24 = arith.ori %arg4, %23 : i32
      scf.yield %24 : i32
    }
    %4 = scf.for %arg3 = %c0 to %c4 step %c1 iter_args(%arg4 = %c0_i32) -> (i32) {
      %7 = arith.index_cast %arg3 : index to i32
      %8 = arith.muli %7, %c8_i32 : i32
      %9 = arith.shrsi %3, %8 : i32
      %10 = arith.andi %9, %c255_i32 : i32
      %11 = arith.shrsi %c0_i32, %8 : i32
      %12 = arith.andi %11, %c255_i32 : i32
      %13 = arith.cmpi sgt, %10, %12 : i32
      %14 = scf.if %13 -> (i32) {
        %15 = arith.shli %c255_i32, %8 : i32
        %16 = arith.ori %arg4, %15 : i32
        scf.yield %16 : i32
      } else {
        scf.yield %arg4 : i32
      }
      scf.yield %14 : i32
    }
    %5 = arith.andi %4, %c-2139062144_i32 : i32
    %6 = arith.xori %5, %arg2 : i32
    return %6 : i32
  }
  func.func @_Z9__vcmpeq4jj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.shrsi %arg1, %2 : i32
      %6 = arith.andi %5, %c255_i32 : i32
      %7 = arith.cmpi eq, %4, %6 : i32
      %8 = scf.if %7 -> (i32) {
        %9 = arith.shli %c255_i32, %2 : i32
        %10 = arith.ori %arg3, %9 : i32
        scf.yield %10 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %8 : i32
    }
    return %0 : i32
  }
  func.func private @__builtin_popcount(i32) -> i32 attributes {llvm.linkage = #llvm.linkage<external>}
  func.func @_Z10__vcmpltu4jj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.shrsi %arg1, %2 : i32
      %6 = arith.andi %5, %c255_i32 : i32
      %7 = arith.cmpi slt, %4, %6 : i32
      %8 = scf.if %7 -> (i32) {
        %9 = arith.shli %c255_i32, %2 : i32
        %10 = arith.ori %arg3, %9 : i32
        scf.yield %10 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %8 : i32
    }
    return %0 : i32
  }
  func.func @_Z10__vcmpgeu4jj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.shrsi %arg1, %2 : i32
      %6 = arith.andi %5, %c255_i32 : i32
      %7 = arith.cmpi sge, %4, %6 : i32
      %8 = scf.if %7 -> (i32) {
        %9 = arith.shli %c255_i32, %2 : i32
        %10 = arith.ori %arg3, %9 : i32
        scf.yield %10 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %8 : i32
    }
    return %0 : i32
  }
  func.func @_Z10__vcmpgtu4jj(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.shrsi %arg1, %2 : i32
      %6 = arith.andi %5, %c255_i32 : i32
      %7 = arith.cmpi sgt, %4, %6 : i32
      %8 = scf.if %7 -> (i32) {
        %9 = arith.shli %c255_i32, %2 : i32
        %10 = arith.ori %arg3, %9 : i32
        scf.yield %10 : i32
      } else {
        scf.yield %arg3 : i32
      }
      scf.yield %8 : i32
    }
    return %0 : i32
  }
  func.func @_Z9__vsubss4ii(%arg0: i32, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<linkonce_odr>} {
    %c4 = arith.constant 4 : index
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c-128_i32 = arith.constant -128 : i32
    %c127_i32 = arith.constant 127 : i32
    %c255_i32 = arith.constant 255 : i32
    %c8_i32 = arith.constant 8 : i32
    %c0_i32 = arith.constant 0 : i32
    %0 = scf.for %arg2 = %c0 to %c4 step %c1 iter_args(%arg3 = %c0_i32) -> (i32) {
      %1 = arith.index_cast %arg2 : index to i32
      %2 = arith.muli %1, %c8_i32 : i32
      %3 = arith.shrsi %arg0, %2 : i32
      %4 = arith.andi %3, %c255_i32 : i32
      %5 = arith.trunci %4 : i32 to i8
      %6 = arith.extsi %5 : i8 to i32
      %7 = arith.shrsi %arg1, %2 : i32
      %8 = arith.andi %7, %c255_i32 : i32
      %9 = arith.trunci %8 : i32 to i8
      %10 = arith.extsi %9 : i8 to i32
      %11 = arith.subi %6, %10 : i32
      %12 = arith.cmpi sgt, %11, %c127_i32 : i32
      %13 = arith.select %12, %c127_i32, %11 : i32
      %14 = arith.cmpi slt, %13, %c-128_i32 : i32
      %15 = arith.select %14, %c-128_i32, %13 : i32
      %16 = arith.andi %15, %c255_i32 : i32
      %17 = arith.shli %16, %2 : i32
      %18 = arith.ori %arg3, %17 : i32
      scf.yield %18 : i32
    }
    return %0 : i32
  }
}
