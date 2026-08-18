#map = affine_map<(d0) -> (d0)>
#map1 = affine_map<(d0) -> (d0 * 8)>
module {
  bitstream.pipeline @gpjson_driver_polygeist_raised {
    %0 = bitstream.parameter @pipeline_arg1 {source_arg = 1 : i64} : index
    %1 = bitstream.parameter @pipeline_arg9 {source_arg = 9 : i64} : index
    %2 = bitstream.parameter @pipeline_arg10 {source_arg = 10 : i64} : index
    %3 = bitstream.buffer @arg0 : !bitstream.buffer
    %4 = bitstream.buffer @arg2 : !bitstream.buffer
    %5 = bitstream.buffer @arg3 : !bitstream.buffer
    %6 = bitstream.buffer @arg4 : !bitstream.buffer
    %7 = bitstream.buffer @arg5 : !bitstream.buffer
    %8 = bitstream.buffer @arg6 : !bitstream.buffer
    %9 = bitstream.buffer @arg7 : !bitstream.buffer
    bitstream.kernel @_Z19gpjson_escape_carryPciS_ {
      %10 = bitstream.logical_index : index
      bitstream.read %3[%10] {access_id = "a0", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.project_state %3[%10] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_not_ctlz_low_bit", read_access = "a0"} : !bitstream.buffer
      %11 = gpu.block_id  x
      %12 = gpu.block_dim  x
      %13 = arith.muli %11, %12 : index
      %14 = gpu.thread_id  x
      %15 = arith.addi %13, %14 : index
      bitstream.write %4[%15] {access_id = "a1", byte_index = #map, bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z19gpjson_escape_indexPclPbPl {
      %10 = bitstream.logical_index : index
      %11 = gpu.block_id  x
      %12 = gpu.block_dim  x
      %13 = arith.muli %11, %12 : index
      %14 = gpu.thread_id  x
      %15 = arith.addi %13, %14 : index
      %c-1 = arith.constant -1 : index
      %16 = arith.addi %15, %c-1 : index
      bitstream.read %4[%16] {access_id = "a2", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.read %3[%10] {access_id = "a3", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.project_state %3[%10] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_not_ctlz_low_bit", read_access = "a3"} : !bitstream.buffer
      %c64 = arith.constant 64 : index
      %17 = arith.divsi %10, %c64 : index
      bitstream.write %5[%17] {access_id = "a4", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      %c-1_0 = arith.constant -1 : index
      %18 = arith.addi %0, %c-1_0 : index
      %c64_1 = arith.constant 64 : index
      %19 = arith.divsi %18, %c64_1 : index
      bitstream.write %5[%19] {access_id = "a5", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z18gpjson_quote_indexPciPlS0_S_ {
      %10 = bitstream.logical_index : index
      %c64 = arith.constant 64 : index
      %11 = arith.divsi %10, %c64 : index
      bitstream.read %5[%11] {access_id = "a6", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      bitstream.read %3[%10] {access_id = "a7", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.project_state %3[%10] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_not_ctlz_low_bit", read_access = "a7"} : !bitstream.buffer
      %c64_0 = arith.constant 64 : index
      %12 = arith.divsi %10, %c64_0 : index
      bitstream.write %6[%12] {access_id = "a8", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      %c-1 = arith.constant -1 : index
      %13 = arith.addi %0, %c-1 : index
      %c64_1 = arith.constant 64 : index
      %14 = arith.divsi %13, %c64_1 : index
      bitstream.write %6[%14] {access_id = "a9", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      %15 = gpu.block_id  x
      %16 = gpu.block_dim  x
      %17 = arith.muli %15, %16 : index
      %18 = gpu.thread_id  x
      %19 = arith.addi %17, %18 : index
      bitstream.write %7[%19] {access_id = "a10", byte_index = #map, bytes = 1 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z19gpjson_xor_pre_scanPci {
      %10 = bitstream.logical_index : index
      bitstream.read %7[%10] {access_id = "a11", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %7[%10] {access_id = "a12", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z20gpjson_xor_post_scanPciiS_ {
      %10 = bitstream.logical_index : index
      bitstream.write %8[%10] {access_id = "a13", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      %11 = arith.addi %1, %2 : index
      %c-1 = arith.constant -1 : index
      %12 = arith.addi %11, %c-1 : index
      %13 = arith.divsi %12, %2 : index
      %c1 = arith.constant 1 : index
      %14 = arith.addi %10, %c1 : index
      %15 = arith.muli %13, %14 : index
      %c-1_0 = arith.constant -1 : index
      %16 = arith.addi %15, %c-1_0 : index
      bitstream.read %7[%16] {access_id = "a14", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      %c-1_1 = arith.constant -1 : index
      %17 = arith.addi %2, %c-1_1 : index
      bitstream.write %8[%17] {access_id = "a15", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z17gpjson_xor_rebasePciS_ {
      %10 = bitstream.logical_index : index
      bitstream.read %7[%10] {access_id = "a16", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      %11 = gpu.block_id  x
      %12 = gpu.block_dim  x
      %13 = arith.muli %11, %12 : index
      %14 = gpu.thread_id  x
      %15 = arith.addi %13, %14 : index
      bitstream.read %8[%15] {access_id = "a17", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %7[%10] {access_id = "a18", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z19gpjson_string_indexPliPc {
      %10 = bitstream.logical_index : index
      %11 = gpu.block_id  x
      %12 = gpu.block_dim  x
      %13 = arith.muli %11, %12 : index
      %14 = gpu.thread_id  x
      %15 = arith.addi %13, %14 : index
      %c-1 = arith.constant -1 : index
      %16 = arith.addi %15, %c-1 : index
      bitstream.read %7[%16] {access_id = "a19", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      %17 = gpu.block_id  x
      %18 = gpu.block_dim  x
      %19 = arith.muli %17, %18 : index
      %20 = gpu.thread_id  x
      %21 = arith.addi %19, %20 : index
      %c-1_0 = arith.constant -1 : index
      %22 = arith.addi %21, %c-1_0 : index
      bitstream.project_state %7[%22] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_not_ctlz_low_bit", read_access = "a19"} : !bitstream.buffer
      bitstream.read %6[%10] {access_id = "a20", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      bitstream.write %6[%10] {access_id = "a21", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z24gpjson_structural_bitmapPciPlS0_ {
      %10 = bitstream.logical_index : index
      %c64 = arith.constant 64 : index
      %11 = arith.divsi %10, %c64 : index
      bitstream.read %6[%11] {access_id = "a22", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      %c64_0 = arith.constant 64 : index
      %12 = arith.divsi %10, %c64_0 : index
      bitstream.write %9[%12] {access_id = "a23", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      bitstream.read %3[%10] {access_id = "a24", byte_index = #map, bytes = 1 : i64} : !bitstream.buffer
      %c64_1 = arith.constant 64 : index
      %13 = arith.divsi %10, %c64_1 : index
      bitstream.write %9[%13] {access_id = "a25", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
      %c-1 = arith.constant -1 : index
      %14 = arith.addi %0, %c-1 : index
      %c64_2 = arith.constant 64 : index
      %15 = arith.divsi %14, %c64_2 : index
      bitstream.write %9[%15] {access_id = "a26", byte_index = #map1, bytes = 8 : i64} : !bitstream.buffer
    }
  }
}
