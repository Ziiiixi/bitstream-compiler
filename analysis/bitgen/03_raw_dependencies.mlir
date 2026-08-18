#map = affine_map<(d0) -> (d0 * 4)>
#map1 = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)>
module {
  bitstream.pipeline @regex_0_polygeist_raised {
    %0 = bitstream.parameter @pipeline_arg1 {source_arg = 1 : i64} : index
    %1 = bitstream.buffer @arg0 : !bitstream.buffer
    %2 = bitstream.buffer @arg5_stream16 : !bitstream.buffer
    %3 = bitstream.buffer @arg5_stream15 : !bitstream.buffer
    %4 = bitstream.buffer @arg5_stream14 : !bitstream.buffer
    %5 = bitstream.buffer @arg5_stream13 : !bitstream.buffer
    %6 = bitstream.buffer @arg5_stream12 : !bitstream.buffer
    %7 = bitstream.buffer @arg5_stream11 : !bitstream.buffer
    %8 = bitstream.buffer @arg5_stream10 : !bitstream.buffer
    %9 = bitstream.buffer @arg5_stream9 : !bitstream.buffer
    %10 = bitstream.buffer @arg5_stream8 : !bitstream.buffer
    %11 = bitstream.buffer @arg5_stream7 : !bitstream.buffer
    %12 = bitstream.buffer @arg5_stream6 : !bitstream.buffer
    %13 = bitstream.buffer @arg5_stream5 : !bitstream.buffer
    %14 = bitstream.buffer @arg5_stream4 : !bitstream.buffer
    %15 = bitstream.buffer @arg5_stream3 : !bitstream.buffer
    %16 = bitstream.buffer @arg5_stream2 : !bitstream.buffer
    %17 = bitstream.buffer @arg5_stream1 : !bitstream.buffer
    %18 = bitstream.buffer @arg5_stream0 : !bitstream.buffer
    %19 = bitstream.buffer @arg3 : !bitstream.buffer
    bitstream.kernel @polygeist_stage0 {
      %20 = bitstream.logical_index : index
      %21 = gpu.block_dim  x
      %c-3 = arith.constant -3 : index
      %22 = arith.addi %21, %c-3 : index
      %23 = arith.muli %20, %22 : index
      %24 = gpu.thread_id  x
      %25 = arith.addi %23, %24 : index
      bitstream.read %1[%25] {access_id = "a0", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %26 = gpu.block_dim  x
      %c-3_0 = arith.constant -3 : index
      %27 = arith.addi %26, %c-3_0 : index
      %28 = arith.muli %20, %27 : index
      %29 = gpu.thread_id  x
      %30 = arith.addi %28, %29 : index
      %31 = arith.addi %30, %0 : index
      bitstream.read %1[%31] {access_id = "a1", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %32 = gpu.block_dim  x
      %c-3_1 = arith.constant -3 : index
      %33 = arith.addi %32, %c-3_1 : index
      %34 = arith.muli %20, %33 : index
      %35 = gpu.thread_id  x
      %36 = arith.addi %34, %35 : index
      %c2 = arith.constant 2 : index
      %37 = arith.muli %0, %c2 : index
      %38 = arith.addi %36, %37 : index
      bitstream.read %1[%38] {access_id = "a2", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %39 = gpu.block_dim  x
      %c-3_2 = arith.constant -3 : index
      %40 = arith.addi %39, %c-3_2 : index
      %41 = arith.muli %20, %40 : index
      %42 = gpu.thread_id  x
      %43 = arith.addi %41, %42 : index
      %c3 = arith.constant 3 : index
      %44 = arith.muli %0, %c3 : index
      %45 = arith.addi %43, %44 : index
      bitstream.read %1[%45] {access_id = "a3", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %46 = gpu.block_dim  x
      %c-3_3 = arith.constant -3 : index
      %47 = arith.addi %46, %c-3_3 : index
      %48 = arith.muli %20, %47 : index
      %49 = gpu.thread_id  x
      %50 = arith.addi %48, %49 : index
      %c4 = arith.constant 4 : index
      %51 = arith.muli %0, %c4 : index
      %52 = arith.addi %50, %51 : index
      bitstream.read %1[%52] {access_id = "a4", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %53 = gpu.block_dim  x
      %c-3_4 = arith.constant -3 : index
      %54 = arith.addi %53, %c-3_4 : index
      %55 = arith.muli %20, %54 : index
      %56 = gpu.thread_id  x
      %57 = arith.addi %55, %56 : index
      %c5 = arith.constant 5 : index
      %58 = arith.muli %0, %c5 : index
      %59 = arith.addi %57, %58 : index
      bitstream.read %1[%59] {access_id = "a5", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %60 = gpu.block_dim  x
      %c-3_5 = arith.constant -3 : index
      %61 = arith.addi %60, %c-3_5 : index
      %62 = arith.muli %20, %61 : index
      %63 = gpu.thread_id  x
      %64 = arith.addi %62, %63 : index
      %c6 = arith.constant 6 : index
      %65 = arith.muli %0, %c6 : index
      %66 = arith.addi %64, %65 : index
      bitstream.read %1[%66] {access_id = "a6", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %67 = gpu.block_dim  x
      %c-3_6 = arith.constant -3 : index
      %68 = arith.addi %67, %c-3_6 : index
      %69 = arith.muli %20, %68 : index
      %70 = gpu.thread_id  x
      %71 = arith.addi %69, %70 : index
      %c7 = arith.constant 7 : index
      %72 = arith.muli %0, %c7 : index
      %73 = arith.addi %71, %72 : index
      bitstream.read %1[%73] {access_id = "a7", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.advance "right" by 1 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 84 : i64, sync}
      bitstream.advance "right" by 2 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 5 : i64, sync}
      bitstream.advance "right" by 4 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 2 : i64, sync}
      bitstream.advance "right" by 3 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 1 : i64, sync}
      %74 = gpu.block_dim  x
      %c-3_7 = arith.constant -3 : index
      %75 = arith.addi %74, %c-3_7 : index
      %76 = arith.muli %20, %75 : index
      %77 = gpu.thread_id  x
      %78 = arith.addi %76, %77 : index
      bitstream.read %2[%78] {access_id = "a8", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %79 = gpu.block_dim  x
      %c-3_8 = arith.constant -3 : index
      %80 = arith.addi %79, %c-3_8 : index
      %81 = arith.muli %20, %80 : index
      %82 = gpu.thread_id  x
      %83 = arith.addi %81, %82 : index
      bitstream.write %2[%83] {access_id = "a9", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %84 = gpu.block_dim  x
      %c-3_9 = arith.constant -3 : index
      %85 = arith.addi %84, %c-3_9 : index
      %86 = arith.muli %20, %85 : index
      %87 = gpu.thread_id  x
      %88 = arith.addi %86, %87 : index
      bitstream.write %3[%88] {access_id = "a10", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %89 = gpu.block_dim  x
      %c-3_10 = arith.constant -3 : index
      %90 = arith.addi %89, %c-3_10 : index
      %91 = arith.muli %20, %90 : index
      %92 = gpu.thread_id  x
      %93 = arith.addi %91, %92 : index
      bitstream.write %4[%93] {access_id = "a11", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %94 = gpu.block_dim  x
      %c-3_11 = arith.constant -3 : index
      %95 = arith.addi %94, %c-3_11 : index
      %96 = arith.muli %20, %95 : index
      %97 = gpu.thread_id  x
      %98 = arith.addi %96, %97 : index
      bitstream.write %5[%98] {access_id = "a12", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %99 = gpu.block_dim  x
      %c-3_12 = arith.constant -3 : index
      %100 = arith.addi %99, %c-3_12 : index
      %101 = arith.muli %20, %100 : index
      %102 = gpu.thread_id  x
      %103 = arith.addi %101, %102 : index
      bitstream.write %6[%103] {access_id = "a13", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %104 = gpu.block_dim  x
      %c-3_13 = arith.constant -3 : index
      %105 = arith.addi %104, %c-3_13 : index
      %106 = arith.muli %20, %105 : index
      %107 = gpu.thread_id  x
      %108 = arith.addi %106, %107 : index
      bitstream.write %7[%108] {access_id = "a14", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %109 = gpu.block_dim  x
      %c-3_14 = arith.constant -3 : index
      %110 = arith.addi %109, %c-3_14 : index
      %111 = arith.muli %20, %110 : index
      %112 = gpu.thread_id  x
      %113 = arith.addi %111, %112 : index
      bitstream.write %8[%113] {access_id = "a15", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %114 = gpu.block_dim  x
      %c-3_15 = arith.constant -3 : index
      %115 = arith.addi %114, %c-3_15 : index
      %116 = arith.muli %20, %115 : index
      %117 = gpu.thread_id  x
      %118 = arith.addi %116, %117 : index
      bitstream.write %9[%118] {access_id = "a16", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %119 = gpu.block_dim  x
      %c-3_16 = arith.constant -3 : index
      %120 = arith.addi %119, %c-3_16 : index
      %121 = arith.muli %20, %120 : index
      %122 = gpu.thread_id  x
      %123 = arith.addi %121, %122 : index
      bitstream.write %10[%123] {access_id = "a17", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %124 = gpu.block_dim  x
      %c-3_17 = arith.constant -3 : index
      %125 = arith.addi %124, %c-3_17 : index
      %126 = arith.muli %20, %125 : index
      %127 = gpu.thread_id  x
      %128 = arith.addi %126, %127 : index
      bitstream.write %11[%128] {access_id = "a18", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %129 = gpu.block_dim  x
      %c-3_18 = arith.constant -3 : index
      %130 = arith.addi %129, %c-3_18 : index
      %131 = arith.muli %20, %130 : index
      %132 = gpu.thread_id  x
      %133 = arith.addi %131, %132 : index
      bitstream.write %12[%133] {access_id = "a19", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %134 = gpu.block_dim  x
      %c-3_19 = arith.constant -3 : index
      %135 = arith.addi %134, %c-3_19 : index
      %136 = arith.muli %20, %135 : index
      %137 = gpu.thread_id  x
      %138 = arith.addi %136, %137 : index
      bitstream.write %13[%138] {access_id = "a20", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %139 = gpu.block_dim  x
      %c-3_20 = arith.constant -3 : index
      %140 = arith.addi %139, %c-3_20 : index
      %141 = arith.muli %20, %140 : index
      %142 = gpu.thread_id  x
      %143 = arith.addi %141, %142 : index
      bitstream.write %14[%143] {access_id = "a21", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %144 = gpu.block_dim  x
      %c-3_21 = arith.constant -3 : index
      %145 = arith.addi %144, %c-3_21 : index
      %146 = arith.muli %20, %145 : index
      %147 = gpu.thread_id  x
      %148 = arith.addi %146, %147 : index
      bitstream.write %15[%148] {access_id = "a22", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %149 = gpu.block_dim  x
      %c-3_22 = arith.constant -3 : index
      %150 = arith.addi %149, %c-3_22 : index
      %151 = arith.muli %20, %150 : index
      %152 = gpu.thread_id  x
      %153 = arith.addi %151, %152 : index
      bitstream.write %16[%153] {access_id = "a23", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @polygeist_stage1 {
      %20 = bitstream.logical_index : index
      %21 = gpu.block_dim  x
      %c-1 = arith.constant -1 : index
      %22 = arith.addi %21, %c-1 : index
      %23 = arith.muli %20, %22 : index
      %24 = gpu.thread_id  x
      %25 = arith.addi %23, %24 : index
      bitstream.read %2[%25] {access_id = "a24", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %26 = gpu.block_dim  x
      %c-1_0 = arith.constant -1 : index
      %27 = arith.addi %26, %c-1_0 : index
      %28 = arith.muli %20, %27 : index
      %29 = gpu.thread_id  x
      %30 = arith.addi %28, %29 : index
      bitstream.read %16[%30] {access_id = "a25", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %31 = gpu.block_dim  x
      %c-1_1 = arith.constant -1 : index
      %32 = arith.addi %31, %c-1_1 : index
      %33 = arith.muli %20, %32 : index
      %34 = gpu.thread_id  x
      %35 = arith.addi %33, %34 : index
      bitstream.read %15[%35] {access_id = "a26", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.advance "right" by 1 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 1 : i64, sync}
      %36 = gpu.block_dim  x
      %c-1_2 = arith.constant -1 : index
      %37 = arith.addi %36, %c-1_2 : index
      %38 = arith.muli %20, %37 : index
      %39 = gpu.thread_id  x
      %40 = arith.addi %38, %39 : index
      bitstream.read %17[%40] {access_id = "a27", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %41 = gpu.block_dim  x
      %c-1_3 = arith.constant -1 : index
      %42 = arith.addi %41, %c-1_3 : index
      %43 = arith.muli %20, %42 : index
      %44 = gpu.thread_id  x
      %45 = arith.addi %43, %44 : index
      bitstream.write %17[%45] {access_id = "a28", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %46 = gpu.block_dim  x
      %c-1_4 = arith.constant -1 : index
      %47 = arith.addi %46, %c-1_4 : index
      %48 = arith.muli %20, %47 : index
      %49 = gpu.thread_id  x
      %50 = arith.addi %48, %49 : index
      bitstream.write %18[%50] {access_id = "a29", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @polygeist_stage2 {
      %20 = bitstream.logical_index : index
      %21 = gpu.block_dim  x
      %c-1 = arith.constant -1 : index
      %22 = arith.addi %21, %c-1 : index
      %23 = arith.muli %20, %22 : index
      %24 = gpu.thread_id  x
      %25 = arith.addi %23, %24 : index
      bitstream.read %14[%25] {access_id = "a30", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %26 = gpu.block_dim  x
      %c-1_0 = arith.constant -1 : index
      %27 = arith.addi %26, %c-1_0 : index
      %28 = arith.muli %20, %27 : index
      %29 = gpu.thread_id  x
      %30 = arith.addi %28, %29 : index
      bitstream.read %13[%30] {access_id = "a31", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %31 = gpu.block_dim  x
      %c-1_1 = arith.constant -1 : index
      %32 = arith.addi %31, %c-1_1 : index
      %33 = arith.muli %20, %32 : index
      %34 = gpu.thread_id  x
      %35 = arith.addi %33, %34 : index
      bitstream.read %12[%35] {access_id = "a32", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %36 = gpu.block_dim  x
      %c-1_2 = arith.constant -1 : index
      %37 = arith.addi %36, %c-1_2 : index
      %38 = arith.muli %20, %37 : index
      %39 = gpu.thread_id  x
      %40 = arith.addi %38, %39 : index
      bitstream.read %11[%40] {access_id = "a33", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %41 = gpu.block_dim  x
      %c-1_3 = arith.constant -1 : index
      %42 = arith.addi %41, %c-1_3 : index
      %43 = arith.muli %20, %42 : index
      %44 = gpu.thread_id  x
      %45 = arith.addi %43, %44 : index
      bitstream.read %10[%45] {access_id = "a34", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %46 = gpu.block_dim  x
      %c-1_4 = arith.constant -1 : index
      %47 = arith.addi %46, %c-1_4 : index
      %48 = arith.muli %20, %47 : index
      %49 = gpu.thread_id  x
      %50 = arith.addi %48, %49 : index
      bitstream.read %9[%50] {access_id = "a35", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %51 = gpu.block_dim  x
      %c-1_5 = arith.constant -1 : index
      %52 = arith.addi %51, %c-1_5 : index
      %53 = arith.muli %20, %52 : index
      %54 = gpu.thread_id  x
      %55 = arith.addi %53, %54 : index
      bitstream.read %8[%55] {access_id = "a36", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %56 = gpu.block_dim  x
      %c-1_6 = arith.constant -1 : index
      %57 = arith.addi %56, %c-1_6 : index
      %58 = arith.muli %20, %57 : index
      %59 = gpu.thread_id  x
      %60 = arith.addi %58, %59 : index
      bitstream.read %7[%60] {access_id = "a37", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %61 = gpu.block_dim  x
      %c-1_7 = arith.constant -1 : index
      %62 = arith.addi %61, %c-1_7 : index
      %63 = arith.muli %20, %62 : index
      %64 = gpu.thread_id  x
      %65 = arith.addi %63, %64 : index
      bitstream.read %6[%65] {access_id = "a38", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %66 = gpu.block_dim  x
      %c-1_8 = arith.constant -1 : index
      %67 = arith.addi %66, %c-1_8 : index
      %68 = arith.muli %20, %67 : index
      %69 = gpu.thread_id  x
      %70 = arith.addi %68, %69 : index
      bitstream.read %5[%70] {access_id = "a39", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %71 = gpu.block_dim  x
      %c-1_9 = arith.constant -1 : index
      %72 = arith.addi %71, %c-1_9 : index
      %73 = arith.muli %20, %72 : index
      %74 = gpu.thread_id  x
      %75 = arith.addi %73, %74 : index
      bitstream.read %4[%75] {access_id = "a40", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %76 = gpu.block_dim  x
      %c-1_10 = arith.constant -1 : index
      %77 = arith.addi %76, %c-1_10 : index
      %78 = arith.muli %20, %77 : index
      %79 = gpu.thread_id  x
      %80 = arith.addi %78, %79 : index
      bitstream.read %3[%80] {access_id = "a41", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %81 = gpu.block_dim  x
      %c-1_11 = arith.constant -1 : index
      %82 = arith.addi %81, %c-1_11 : index
      %83 = arith.muli %20, %82 : index
      %84 = gpu.thread_id  x
      %85 = arith.addi %83, %84 : index
      bitstream.read %2[%85] {access_id = "a42", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      bitstream.advance "right" by 1 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 8 : i64, sync}
      bitstream.advance "right" by 2 {callee = "_ZL26BSAdvanceRightFunctionSyncjjPj", count = 1 : i64, sync}
      %86 = gpu.block_dim  x
      %c-1_12 = arith.constant -1 : index
      %87 = arith.addi %86, %c-1_12 : index
      %88 = arith.muli %20, %87 : index
      %89 = gpu.thread_id  x
      %90 = arith.addi %88, %89 : index
      bitstream.read %19[%90] {access_id = "a43", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
      %91 = gpu.block_dim  x
      %c-1_13 = arith.constant -1 : index
      %92 = arith.addi %91, %c-1_13 : index
      %93 = arith.muli %20, %92 : index
      %94 = gpu.thread_id  x
      %95 = arith.addi %93, %94 : index
      bitstream.write %19[%95] {access_id = "a44", byte_index = #map, bytes = 4 : i64} : !bitstream.buffer
    }
  }
  bitstream.analysis @regex_0_polygeist_raised_analysis for @regex_0_polygeist_raised {
    bitstream.dependency memory = input consumer_access = "a0" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a1" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a2" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a3" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a4" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a5" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a6" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a7" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg0, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a8" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream16, consumer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a9" consumer_access = "a24" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream16, consumer = @regex_0_polygeist_raised::@polygeist_stage1, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a23" consumer_access = "a25" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream2, consumer = @regex_0_polygeist_raised::@polygeist_stage1, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a22" consumer_access = "a26" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream3, consumer = @regex_0_polygeist_raised::@polygeist_stage1, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a27" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream1, consumer = @regex_0_polygeist_raised::@polygeist_stage1}
    bitstream.dependency memory = raw producer_access = "a21" consumer_access = "a30" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream4, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a20" consumer_access = "a31" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream5, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a19" consumer_access = "a32" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream6, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a18" consumer_access = "a33" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream7, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a17" consumer_access = "a34" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream8, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a16" consumer_access = "a35" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream9, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a15" consumer_access = "a36" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream10, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a14" consumer_access = "a37" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream11, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a13" consumer_access = "a38" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream12, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a12" consumer_access = "a39" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream13, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a11" consumer_access = "a40" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream14, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a10" consumer_access = "a41" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream15, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = raw producer_access = "a9" consumer_access = "a42" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg5_stream16, consumer = @regex_0_polygeist_raised::@polygeist_stage2, producer = @regex_0_polygeist_raised::@polygeist_stage0}
    bitstream.dependency memory = input consumer_access = "a43" finite_state = none producer_byte_window = #map1 {buffer = @regex_0_polygeist_raised::@arg3, consumer = @regex_0_polygeist_raised::@polygeist_stage2}
  }
}
