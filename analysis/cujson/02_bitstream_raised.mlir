#map = affine_map<(d0) -> (d0 * 4)>
#map1 = affine_map<(d0) -> (d0)>
module {
  bitstream.pipeline @cujson_tokenizer_polygeist_raised {
    %0 = bitstream.buffer @arg0 : !bitstream.buffer
    %1 = bitstream.buffer @arg1 : !bitstream.buffer
    %2 = bitstream.buffer @arg2 : !bitstream.buffer
    %3 = bitstream.buffer @arg3 : !bitstream.buffer
    %4 = bitstream.buffer @arg4 : !bitstream.buffer
    %5 = bitstream.buffer @arg7 : !bitstream.buffer
    %6 = bitstream.buffer @arg8 : !bitstream.buffer
    %7 = bitstream.buffer @arg5 : !bitstream.buffer
    %8 = bitstream.buffer @arg6 : !bitstream.buffer
    %9 = bitstream.buffer @arg9 : !bitstream.buffer
    bitstream.kernel @_Z10checkAsciiPjiS_ {
      %10 = bitstream.logical_index : index
      bitstream.read %0[%10] {access_id = "a0", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %c0 = arith.constant 0 : index
      bitstream.write %1[%c0] {access_id = "a1", byte_index = #map, bytes = 4 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z9checkUTF8PjS_i {
      %10 = bitstream.logical_index : index
      bitstream.read %0[%10] {access_id = "a2", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %c-1 = arith.constant -1 : index
      %11 = arith.addi %10, %c-1 : index
      bitstream.read %0[%11] {access_id = "a3", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %c0 = arith.constant 0 : index
      bitstream.write %2[%c0] {access_id = "a4", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z17bitMapCreatorSimdPjPhS0_S0_S0_yi {
      %10 = bitstream.logical_index : index
      %c2 = arith.constant 2 : index
      %11 = arith.muli %10, %c2 : index
      bitstream.read %0[%11] {access_id = "a5", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %c2_0 = arith.constant 2 : index
      %12 = arith.muli %10, %c2_0 : index
      %c1 = arith.constant 1 : index
      %13 = arith.addi %12, %c1 : index
      bitstream.read %0[%13] {access_id = "a6", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %3[%10] {access_id = "a7", byte_index = #map1, bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %4[%10] {access_id = "a8", byte_index = #map1, bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %5[%10] {access_id = "a9", byte_index = #map1, bytes = 1 : i64} : !bitstream.buffer
      bitstream.write %6[%10] {access_id = "a10", byte_index = #map1, bytes = 1 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z25findEscapedQuoteMerge_NEWPjS_S_iii {
      %10 = bitstream.logical_index : index
      %c-1 = arith.constant -1 : index
      %11 = arith.addi %10, %c-1 : index
      %12 = scf.while (%arg0 = %11) : (index) -> index {
        %c0 = arith.constant 0 : index
        %13 = arith.cmpi sge, %arg0, %c0 : index
        scf.condition(%13) %arg0 : index
      } do {
      ^bb0(%arg0: index):
        bitstream.read %3[%arg0] {access_id = "a11", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
        bitstream.project_state %3[%arg0] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_not_ctlz_low_bit", read_access = "a11"} : !bitstream.buffer
        %c1 = arith.constant 1 : index
        %13 = arith.subi %arg0, %c1 : index
        scf.yield %13 : index
      }
      bitstream.read %4[%10] {access_id = "a12", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.read %3[%10] {access_id = "a13", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %7[%10] {access_id = "a14", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %4[%10] {access_id = "a15", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.scan @_Z33thrust_exclusive_scan_quote_countPjS_i operator = "add" {
      %10 = bitstream.logical_index : index
      bitstream.read %4[%10] {access_id = "a16", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %4[%10] {access_id = "a17", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z22inStringFinderBaselinePjS_S_i {
      %10 = bitstream.logical_index : index
      bitstream.read %4[%10] {access_id = "a18", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.project_state %4[%10] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "ssa_low_bit", read_access = "a18"} : !bitstream.buffer
      bitstream.read %7[%10] {access_id = "a19", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %8[%10] {access_id = "a20", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @_Z24findOutUsefulStringMergePjS_S_yiiS_ {
      %10 = bitstream.logical_index : index
      bitstream.read %5[%10] {access_id = "a21", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.read %6[%10] {access_id = "a22", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.read %8[%10] {access_id = "a23", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %8[%10] {access_id = "a24", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %6[%10] {access_id = "a25", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %9[%10] {access_id = "a26", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.write %5[%10] {access_id = "a27", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
  }
}
