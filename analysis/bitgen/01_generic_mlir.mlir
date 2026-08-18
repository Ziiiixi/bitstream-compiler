module attributes {dlti.dl_spec = #dlti.dl_spec<#dlti.dl_entry<f80, dense<128> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr<272>, dense<64> : vector<4xi32>>, #dlti.dl_entry<!llvm.ptr<271>, dense<32> : vector<4xi32>>, #dlti.dl_entry<i64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f16, dense<16> : vector<2xi32>>, #dlti.dl_entry<f64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f128, dense<128> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr<270>, dense<32> : vector<4xi32>>, #dlti.dl_entry<i32, dense<32> : vector<2xi32>>, #dlti.dl_entry<i8, dense<8> : vector<2xi32>>, #dlti.dl_entry<i16, dense<16> : vector<2xi32>>, #dlti.dl_entry<!llvm.ptr, dense<64> : vector<4xi32>>, #dlti.dl_entry<i1, dense<8> : vector<2xi32>>, #dlti.dl_entry<"dlti.stack_alignment", 128 : i32>, #dlti.dl_entry<"dlti.endianness", "little">>, llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128", llvm.target_triple = "x86_64-unknown-linux-gnu", "polygeist.target-cpu" = "x86-64", "polygeist.target-features" = "+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87", "polygeist.tune-cpu" = "generic"} {
  memref.global @threadIdx : memref<1x3xi32> = uninitialized
  memref.global @blockDim : memref<1x3xi32> = uninitialized
  func.func @bitgen_driver(%arg0: memref<?xi32>, %arg1: i32, %arg2: i32, %arg3: memref<?xi32>, %arg4: memref<?xi32>, %arg5: memref<?xi32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    call @regex_0(%arg0, %arg1, %arg2, %arg3, %arg4, %arg5) : (memref<?xi32>, i32, i32, memref<?xi32>, memref<?xi32>, memref<?xi32>) -> ()
    return
  }
  func.func @regex_0(%arg0: memref<?xi32>, %arg1: i32, %arg2: i32, %arg3: memref<?xi32>, %arg4: memref<?xi32>, %arg5: memref<?xi32>) attributes {llvm.linkage = #llvm.linkage<external>} {
    %c-3_i32 = arith.constant -3 : i32
    %c0_i8 = arith.constant 0 : i8
    %c-1_i32 = arith.constant -1 : i32
    %c1_i32 = arith.constant 1 : i32
    %c16_i32 = arith.constant 16 : i32
    %c15_i32 = arith.constant 15 : i32
    %c14_i32 = arith.constant 14 : i32
    %c13_i32 = arith.constant 13 : i32
    %c12_i32 = arith.constant 12 : i32
    %c11_i32 = arith.constant 11 : i32
    %c10_i32 = arith.constant 10 : i32
    %c9_i32 = arith.constant 9 : i32
    %c8_i32 = arith.constant 8 : i32
    %c7_i32 = arith.constant 7 : i32
    %c6_i32 = arith.constant 6 : i32
    %c5_i32 = arith.constant 5 : i32
    %c4_i32 = arith.constant 4 : i32
    %c3_i32 = arith.constant 3 : i32
    %c2_i32 = arith.constant 2 : i32
    %c0_i32 = arith.constant 0 : i32
    %c0 = arith.constant 0 : index
    %0 = llvm.mlir.undef : i32
    %alloca = memref.alloca() : memref<1xmemref<?xi32>>
    %alloca_0 = memref.alloca() : memref<1xmemref<?xi32>>
    %alloca_1 = memref.alloca() : memref<1xmemref<?xi32>>
    %alloca_2 = memref.alloca() : memref<1xmemref<?xi32>>
    affine.store %arg5, %alloca_2[0] : memref<1xmemref<?xi32>>
    %1 = arith.index_cast %arg1 : i32 to index
    %2 = "polygeist.subindex"(%arg5, %1) : (memref<?xi32>, index) -> memref<?xi32>
    affine.store %2, %alloca_1[0] : memref<1xmemref<?xi32>>
    %3 = arith.muli %arg1, %c2_i32 : i32
    %4 = arith.index_cast %3 : i32 to index
    %5 = arith.muli %arg1, %c3_i32 : i32
    %6 = arith.index_cast %5 : i32 to index
    %7 = "polygeist.subindex"(%arg5, %6) : (memref<?xi32>, index) -> memref<?xi32>
    affine.store %7, %alloca_0[0] : memref<1xmemref<?xi32>>
    %8 = arith.muli %arg1, %c4_i32 : i32
    %9 = arith.index_cast %8 : i32 to index
    %10 = arith.muli %arg1, %c5_i32 : i32
    %11 = arith.index_cast %10 : i32 to index
    %12 = arith.muli %arg1, %c6_i32 : i32
    %13 = arith.index_cast %12 : i32 to index
    %14 = arith.muli %arg1, %c7_i32 : i32
    %15 = arith.index_cast %14 : i32 to index
    %16 = arith.muli %arg1, %c8_i32 : i32
    %17 = arith.index_cast %16 : i32 to index
    %18 = arith.muli %arg1, %c9_i32 : i32
    %19 = arith.index_cast %18 : i32 to index
    %20 = arith.muli %arg1, %c10_i32 : i32
    %21 = arith.index_cast %20 : i32 to index
    %22 = arith.muli %arg1, %c11_i32 : i32
    %23 = arith.index_cast %22 : i32 to index
    %24 = arith.muli %arg1, %c12_i32 : i32
    %25 = arith.index_cast %24 : i32 to index
    %26 = arith.muli %arg1, %c13_i32 : i32
    %27 = arith.index_cast %26 : i32 to index
    %28 = arith.muli %arg1, %c14_i32 : i32
    %29 = arith.index_cast %28 : i32 to index
    %30 = arith.muli %arg1, %c15_i32 : i32
    %31 = arith.index_cast %30 : i32 to index
    %32 = arith.muli %arg1, %c16_i32 : i32
    %33 = arith.index_cast %32 : i32 to index
    %34 = "polygeist.subindex"(%arg5, %33) : (memref<?xi32>, index) -> memref<?xi32>
    affine.store %34, %alloca[0] : memref<1xmemref<?xi32>>
    %35 = arith.sitofp %arg1 : i32 to f64
    %36 = memref.get_global @blockDim : memref<1x3xi32>
    %37 = "polygeist.subindex"(%36, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %38 = "polygeist.subindex"(%37, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %39 = memref.get_global @threadIdx : memref<1x3xi32>
    %40 = "polygeist.subindex"(%39, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %41 = "polygeist.subindex"(%40, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %42 = scf.while (%arg6 = %c0_i32) : (i32) -> i32 {
      %45 = arith.sitofp %arg6 : i32 to f64
      %46 = affine.load %38[0] : memref<?xi32>
      %47 = arith.addi %46, %c-3_i32 : i32
      %48 = arith.sitofp %47 : i32 to f64
      %49 = arith.divf %35, %48 : f64
      %50 = math.ceil %49 : f64
      %51 = arith.cmpf olt, %45, %50 : f64
      scf.condition(%51) %arg6 : i32
    } do {
    ^bb0(%arg6: i32):
      %45 = affine.load %38[0] : memref<?xi32>
      %46 = arith.addi %45, %c-3_i32 : i32
      %47 = arith.muli %arg6, %46 : i32
      %48 = affine.load %41[0] : memref<?xi32>
      %49 = arith.addi %47, %48 : i32
      %50 = arith.index_cast %49 : i32 to index
      %51 = "polygeist.subindex"(%arg0, %50) : (memref<?xi32>, index) -> memref<?xi32>
      %52 = affine.load %51[0] : memref<?xi32>
      %53 = arith.addi %49, %arg1 : i32
      %54 = arith.index_cast %53 : i32 to index
      %55 = "polygeist.subindex"(%arg0, %54) : (memref<?xi32>, index) -> memref<?xi32>
      %56 = affine.load %55[0] : memref<?xi32>
      %57 = arith.addi %49, %3 : i32
      %58 = arith.index_cast %57 : i32 to index
      %59 = "polygeist.subindex"(%arg0, %58) : (memref<?xi32>, index) -> memref<?xi32>
      %60 = affine.load %59[0] : memref<?xi32>
      %61 = arith.addi %49, %5 : i32
      %62 = arith.index_cast %61 : i32 to index
      %63 = "polygeist.subindex"(%arg0, %62) : (memref<?xi32>, index) -> memref<?xi32>
      %64 = affine.load %63[0] : memref<?xi32>
      %65 = arith.addi %49, %8 : i32
      %66 = arith.index_cast %65 : i32 to index
      %67 = "polygeist.subindex"(%arg0, %66) : (memref<?xi32>, index) -> memref<?xi32>
      %68 = affine.load %67[0] : memref<?xi32>
      %69 = arith.addi %49, %10 : i32
      %70 = arith.index_cast %69 : i32 to index
      %71 = "polygeist.subindex"(%arg0, %70) : (memref<?xi32>, index) -> memref<?xi32>
      %72 = affine.load %71[0] : memref<?xi32>
      %73 = arith.addi %49, %12 : i32
      %74 = arith.index_cast %73 : i32 to index
      %75 = "polygeist.subindex"(%arg0, %74) : (memref<?xi32>, index) -> memref<?xi32>
      %76 = affine.load %75[0] : memref<?xi32>
      %77 = arith.addi %49, %14 : i32
      %78 = arith.index_cast %77 : i32 to index
      %79 = "polygeist.subindex"(%arg0, %78) : (memref<?xi32>, index) -> memref<?xi32>
      %80 = affine.load %79[0] : memref<?xi32>
      %81 = arith.xori %68, %c-1_i32 : i32
      %82 = arith.xori %60, %c-1_i32 : i32
      %83 = arith.xori %52, %c-1_i32 : i32
      %84 = arith.andi %64, %82 : i32
      %85 = arith.andi %56, %83 : i32
      %86 = arith.andi %85, %84 : i32
      %87 = arith.andi %86, %81 : i32
      %88 = arith.andi %76, %80 : i32
      %89 = arith.ori %76, %80 : i32
      %90 = arith.xori %89, %c-1_i32 : i32
      %91 = arith.xori %72, %c-1_i32 : i32
      %92 = arith.andi %72, %90 : i32
      %93 = arith.andi %91, %88 : i32
      %94 = arith.ori %92, %93 : i32
      %95 = arith.andi %87, %94 : i32
      %96 = arith.andi %68, %91 : i32
      %97 = arith.andi %96, %90 : i32
      %98 = arith.andi %86, %97 : i32
      %99 = arith.ori %95, %98 : i32
      %100 = arith.ori %60, %64 : i32
      %101 = arith.ori %52, %56 : i32
      %102 = arith.ori %101, %100 : i32
      %103 = arith.xori %102, %c-1_i32 : i32
      %104 = arith.ori %72, %89 : i32
      %105 = arith.ori %72, %76 : i32
      %106 = arith.xori %105, %c-1_i32 : i32
      %107 = arith.andi %68, %106 : i32
      %108 = arith.andi %81, %104 : i32
      %109 = arith.ori %107, %108 : i32
      %110 = arith.andi %109, %103 : i32
      %111 = arith.ori %72, %88 : i32
      %112 = arith.andi %68, %111 : i32
      %113 = arith.ori %100, %112 : i32
      %114 = arith.ori %56, %113 : i32
      %115 = arith.andi %114, %83 : i32
      %116 = arith.ori %110, %115 : i32
      %117 = arith.xori %100, %c-1_i32 : i32
      %118 = arith.andi %96, %88 : i32
      %119 = arith.andi %85, %117 : i32
      %120 = arith.andi %119, %118 : i32
      %121 = arith.xori %80, %c-1_i32 : i32
      %122 = arith.andi %76, %121 : i32
      %123 = arith.ori %68, %72 : i32
      %124 = arith.xori %123, %c-1_i32 : i32
      %125 = arith.andi %122, %124 : i32
      %126 = arith.andi %86, %125 : i32
      %127 = arith.ori %120, %126 : i32
      %128 = arith.ori %127, %98 : i32
      %129 = arith.andi %72, %81 : i32
      %130 = arith.andi %129, %88 : i32
      %131 = arith.andi %119, %130 : i32
      %132 = arith.ori %131, %98 : i32
      %133 = arith.andi %88, %124 : i32
      %134 = arith.xori %96, %c-1_i32 : i32
      %135 = arith.andi %123, %134 : i32
      %136 = arith.xori %135, %c-1_i32 : i32
      %137 = arith.andi %88, %136 : i32
      %138 = arith.andi %119, %137 : i32
      %139 = arith.ori %138, %126 : i32
      %140 = arith.ori %139, %98 : i32
      %141 = arith.xori %76, %c-1_i32 : i32
      %142 = arith.andi %129, %141 : i32
      %143 = arith.ori %125, %142 : i32
      %144 = arith.ori %143, %97 : i32
      %145 = arith.andi %68, %72 : i32
      %146 = arith.andi %145, %122 : i32
      %147 = arith.ori %144, %146 : i32
      %148 = arith.andi %119, %147 : i32
      %149 = arith.andi %86, %124 : i32
      %150 = arith.xori %76, %80 : i32
      %151 = arith.andi %149, %150 : i32
      %152 = arith.ori %148, %151 : i32
      %153 = arith.ori %152, %98 : i32
      %154 = arith.andi %96, %122 : i32
      %155 = arith.andi %86, %154 : i32
      %156 = arith.ori %153, %155 : i32
      %157 = arith.andi %145, %90 : i32
      %158 = arith.andi %119, %157 : i32
      %159 = arith.ori %158, %98 : i32
      %160 = arith.andi %80, %141 : i32
      %161 = arith.andi %160, %124 : i32
      %162 = arith.andi %119, %161 : i32
      %163 = arith.andi %86, %133 : i32
      %164 = arith.ori %162, %163 : i32
      %165 = arith.ori %164, %98 : i32
      %166 = arith.andi %96, %141 : i32
      %167 = arith.andi %86, %166 : i32
      %168 = arith.andi %96, %160 : i32
      %169 = arith.andi %119, %168 : i32
      %170 = arith.ori %169, %98 : i32
      %171 = arith.andi %119, %124 : i32
      %172 = arith.andi %171, %150 : i32
      %173 = arith.ori %172, %120 : i32
      %174 = arith.andi %119, %146 : i32
      %175 = arith.ori %173, %174 : i32
      %176 = arith.andi %76, %124 : i32
      %177 = arith.andi %86, %176 : i32
      %178 = arith.ori %175, %177 : i32
      %179 = arith.ori %178, %98 : i32
      %180 = arith.ori %125, %97 : i32
      %181 = arith.andi %86, %180 : i32
      %182 = arith.andi %72, %88 : i32
      %183 = arith.xori %104, %c-1_i32 : i32
      %184 = arith.andi %68, %183 : i32
      %185 = arith.andi %81, %182 : i32
      %186 = arith.ori %184, %185 : i32
      %187 = arith.ori %125, %186 : i32
      %188 = arith.andi %86, %187 : i32
      %189 = arith.andi %129, %122 : i32
      %190 = arith.ori %161, %189 : i32
      %191 = arith.ori %190, %168 : i32
      %192 = arith.andi %145, %141 : i32
      %193 = arith.ori %191, %192 : i32
      %194 = arith.andi %119, %193 : i32
      %195 = arith.andi %72, %76 : i32
      %196 = arith.andi %81, %195 : i32
      %197 = arith.ori %107, %196 : i32
      %198 = arith.andi %86, %197 : i32
      %199 = arith.ori %194, %198 : i32
      %200 = arith.andi %119, %189 : i32
      %201 = arith.ori %200, %98 : i32
      %202 = arith.ori %143, %168 : i32
      %203 = arith.ori %202, %146 : i32
      %204 = arith.andi %119, %203 : i32
      %205 = arith.ori %204, %95 : i32
      %206 = arith.ori %205, %98 : i32
      %207 = arith.ori %206, %155 : i32
      %208 = arith.andi %86, %186 : i32
      %209 = arith.andi %129, %160 : i32
      %210 = arith.andi %119, %209 : i32
      %211 = arith.ori %210, %98 : i32
      %212 = arith.ori %211, %155 : i32
      %213 = arith.ori %180, %146 : i32
      %214 = arith.andi %119, %213 : i32
      %215 = arith.ori %214, %98 : i32
      %216 = arith.andi %119, %68 : i32
      %217 = arith.andi %72, %141 : i32
      %218 = arith.ori %217, %93 : i32
      %219 = arith.andi %216, %218 : i32
      %220 = arith.ori %169, %219 : i32
      %221 = arith.andi %86, %189 : i32
      %222 = arith.ori %220, %221 : i32
      %223 = arith.ori %222, %98 : i32
      %224 = arith.andi %171, %89 : i32
      %225 = arith.andi %72, %89 : i32
      %226 = arith.andi %81, %225 : i32
      %227 = arith.ori %184, %226 : i32
      %228 = arith.andi %119, %227 : i32
      %229 = arith.ori %224, %228 : i32
      %230 = arith.andi %119, %145 : i32
      %231 = arith.xori %88, %c-1_i32 : i32
      %232 = arith.andi %230, %231 : i32
      %233 = arith.ori %229, %232 : i32
      %234 = arith.ori %233, %151 : i32
      %235 = arith.ori %234, %221 : i32
      %236 = arith.andi %86, %96 : i32
      %237 = arith.andi %236, %231 : i32
      %238 = arith.ori %235, %237 : i32
      %239 = arith.xori %84, %c-1_i32 : i32
      %240 = arith.andi %100, %239 : i32
      %241 = arith.xori %240, %c-1_i32 : i32
      %242 = arith.andi %85, %241 : i32
      %243 = arith.andi %97, %242 : i32
      %244 = arith.ori %169, %221 : i32
      %245 = arith.ori %244, %98 : i32
      %246 = arith.ori %161, %130 : i32
      %247 = arith.andi %119, %246 : i32
      %248 = arith.ori %247, %98 : i32
      %249 = arith.ori %133, %97 : i32
      %250 = arith.andi %86, %249 : i32
      %251 = arith.ori %189, %97 : i32
      %252 = arith.andi %86, %251 : i32
      %253 = arith.andi %119, %97 : i32
      %254 = arith.ori %253, %167 : i32
      %255 = arith.xori %145, %c-1_i32 : i32
      %256 = arith.andi %123, %255 : i32
      %257 = arith.xori %256, %c-1_i32 : i32
      %258 = arith.andi %122, %257 : i32
      %259 = arith.andi %119, %258 : i32
      %260 = arith.ori %259, %98 : i32
      %261 = arith.andi %80, %124 : i32
      %262 = arith.ori %261, %130 : i32
      %263 = arith.andi %119, %262 : i32
      %264 = arith.ori %263, %95 : i32
      %265 = arith.ori %264, %98 : i32
      %266 = arith.ori %133, %168 : i32
      %267 = arith.ori %266, %192 : i32
      %268 = arith.andi %119, %267 : i32
      %269 = arith.andi %129, %90 : i32
      %270 = arith.andi %86, %269 : i32
      %271 = arith.ori %268, %270 : i32
      %272 = arith.ori %271, %221 : i32
      %273 = arith.ori %272, %98 : i32
      %274 = arith.ori %123, %89 : i32
      %275 = arith.xori %274, %c-1_i32 : i32
      %276 = arith.andi %86, %275 : i32
      %277 = arith.ori %131, %276 : i32
      %278 = arith.ori %277, %98 : i32
      %279 = arith.ori %189, %168 : i32
      %280 = arith.ori %279, %192 : i32
      %281 = arith.andi %119, %280 : i32
      %282 = arith.ori %281, %198 : i32
      %283 = arith.ori %261, %189 : i32
      %284 = arith.ori %283, %192 : i32
      %285 = arith.andi %119, %284 : i32
      %286 = arith.ori %285, %270 : i32
      %287 = arith.ori %286, %221 : i32
      %288 = arith.ori %287, %167 : i32
      %289 = arith.ori %125, %269 : i32
      %290 = arith.ori %289, %130 : i32
      %291 = arith.ori %290, %118 : i32
      %292 = arith.ori %291, %146 : i32
      %293 = arith.andi %119, %292 : i32
      %294 = arith.ori %293, %95 : i32
      %295 = arith.ori %294, %98 : i32
      %296 = arith.ori %143, %146 : i32
      %297 = arith.andi %119, %296 : i32
      %298 = arith.ori %297, %221 : i32
      %299 = arith.ori %298, %98 : i32
      %300 = arith.ori %299, %155 : i32
      %301 = arith.ori %133, %189 : i32
      %302 = arith.ori %301, %168 : i32
      %303 = arith.ori %302, %192 : i32
      %304 = arith.andi %119, %303 : i32
      %305 = arith.ori %304, %126 : i32
      %306 = arith.ori %305, %198 : i32
      %307 = arith.ori %166, %157 : i32
      %308 = arith.andi %119, %307 : i32
      %309 = arith.ori %308, %221 : i32
      %310 = arith.ori %309, %98 : i32
      %311 = arith.ori %172, %253 : i32
      %312 = arith.ori %311, %120 : i32
      %313 = arith.ori %312, %174 : i32
      %314 = arith.andi %149, %231 : i32
      %315 = arith.ori %313, %314 : i32
      %316 = arith.ori %315, %98 : i32
      %317 = arith.ori %316, %155 : i32
      %318 = arith.ori %168, %192 : i32
      %319 = arith.andi %119, %318 : i32
      %320 = arith.ori %319, %221 : i32
      %321 = arith.ori %320, %98 : i32
      %322 = arith.ori %247, %163 : i32
      %323 = arith.ori %322, %98 : i32
      %324 = arith.ori %290, %146 : i32
      %325 = arith.andi %119, %324 : i32
      %326 = arith.ori %325, %95 : i32
      %327 = arith.ori %326, %98 : i32
      %328 = arith.andi %119, %261 : i32
      %329 = arith.ori %328, %221 : i32
      %330 = arith.ori %329, %98 : i32
      %331 = arith.ori %100, %274 : i32
      %332 = arith.xori %331, %c-1_i32 : i32
      %333 = arith.xori %56, %c-1_i32 : i32
      %334 = arith.andi %56, %332 : i32
      %335 = arith.andi %333, %113 : i32
      %336 = arith.ori %334, %335 : i32
      %337 = arith.andi %336, %83 : i32
      %338 = arith.ori %110, %337 : i32
      %339 = arith.ori %123, %76 : i32
      %340 = arith.ori %64, %339 : i32
      %341 = arith.ori %60, %340 : i32
      %342 = arith.andi %85, %341 : i32
      %343 = arith.ori %338, %342 : i32
      %344 = arith.andi %64, %339 : i32
      %345 = arith.ori %60, %344 : i32
      %346 = arith.xori %345, %c-1_i32 : i32
      %347 = arith.andi %56, %346 : i32
      %348 = arith.ori %347, %335 : i32
      %349 = arith.andi %348, %83 : i32
      %350 = arith.ori %110, %349 : i32
      %351 = arith.ori %123, %88 : i32
      %352 = arith.andi %64, %351 : i32
      %353 = arith.ori %60, %352 : i32
      %354 = arith.andi %85, %353 : i32
      %355 = arith.ori %350, %354 : i32
      %356 = arith.ori %100, %145 : i32
      %357 = arith.xori %356, %c-1_i32 : i32
      %358 = arith.andi %56, %357 : i32
      %359 = arith.ori %358, %335 : i32
      %360 = arith.andi %359, %83 : i32
      %361 = arith.ori %110, %360 : i32
      %362 = arith.andi %145, %89 : i32
      %363 = arith.ori %64, %362 : i32
      %364 = arith.ori %60, %363 : i32
      %365 = arith.andi %85, %364 : i32
      %366 = arith.ori %361, %365 : i32
      %367 = arith.ori %162, %98 : i32
      %368 = arith.andi %160, %68 : i32
      %369 = arith.andi %119, %368 : i32
      %370 = arith.ori %369, %276 : i32
      %371 = arith.ori %370, %270 : i32
      %372 = arith.ori %371, %221 : i32
      %373 = arith.ori %372, %98 : i32
      %374 = arith.ori %143, %130 : i32
      %375 = arith.andi %119, %374 : i32
      %376 = arith.ori %375, %98 : i32
      %377 = arith.ori %376, %155 : i32
      %378 = arith.xori %129, %c-1_i32 : i32
      %379 = arith.andi %123, %378 : i32
      %380 = arith.xori %379, %c-1_i32 : i32
      %381 = arith.andi %160, %380 : i32
      %382 = arith.andi %119, %381 : i32
      %383 = arith.xori %339, %c-1_i32 : i32
      %384 = arith.andi %86, %383 : i32
      %385 = arith.ori %382, %384 : i32
      %386 = arith.ori %385, %237 : i32
      %387 = arith.xori %269, %c-1_i32 : i32
      %388 = arith.andi %274, %387 : i32
      %389 = arith.xori %97, %c-1_i32 : i32
      %390 = arith.andi %388, %389 : i32
      %391 = arith.xori %390, %c-1_i32 : i32
      %392 = arith.andi %86, %391 : i32
      %393 = arith.andi %119, %143 : i32
      %394 = arith.ori %393, %98 : i32
      %395 = arith.ori %394, %155 : i32
      %396 = arith.andi %160, %136 : i32
      %397 = arith.ori %396, %157 : i32
      %398 = arith.andi %119, %397 : i32
      %399 = arith.ori %398, %95 : i32
      %400 = arith.ori %399, %221 : i32
      %401 = arith.ori %400, %98 : i32
      %402 = arith.andi %119, %129 : i32
      %403 = arith.andi %402, %89 : i32
      %404 = arith.ori %328, %403 : i32
      %405 = arith.ori %404, %169 : i32
      %406 = arith.andi %119, %192 : i32
      %407 = arith.ori %405, %406 : i32
      %408 = arith.ori %407, %270 : i32
      %409 = arith.ori %408, %221 : i32
      %410 = arith.ori %409, %98 : i32
      %411 = arith.ori %410, %155 : i32
      %412 = arith.ori %396, %192 : i32
      %413 = arith.andi %119, %412 : i32
      %414 = arith.ori %413, %221 : i32
      %415 = arith.ori %414, %98 : i32
      %416 = arith.andi %119, %81 : i32
      %417 = arith.xori %72, %89 : i32
      %418 = arith.andi %416, %417 : i32
      %419 = arith.ori %418, %169 : i32
      %420 = arith.ori %419, %174 : i32
      %421 = arith.ori %420, %95 : i32
      %422 = arith.ori %421, %98 : i32
      %423 = arith.ori %224, %131 : i32
      %424 = arith.ori %423, %174 : i32
      %425 = arith.ori %424, %95 : i32
      %426 = arith.ori %425, %221 : i32
      %427 = arith.ori %426, %98 : i32
      %428 = arith.ori %261, %168 : i32
      %429 = arith.ori %428, %192 : i32
      %430 = arith.andi %119, %429 : i32
      %431 = arith.ori %430, %221 : i32
      %432 = arith.ori %431, %98 : i32
      %433 = arith.andi %119, %396 : i32
      %434 = arith.andi %216, %94 : i32
      %435 = arith.ori %433, %434 : i32
      %436 = arith.ori %435, %270 : i32
      %437 = arith.ori %436, %221 : i32
      %438 = arith.ori %437, %98 : i32
      %439 = arith.ori %224, %232 : i32
      %440 = arith.andi %91, %76 : i32
      %441 = arith.ori %92, %440 : i32
      %442 = arith.andi %87, %441 : i32
      %443 = arith.ori %439, %442 : i32
      %444 = arith.ori %443, %198 : i32
      %445 = arith.ori %283, %168 : i32
      %446 = arith.ori %445, %192 : i32
      %447 = arith.andi %119, %446 : i32
      %448 = arith.ori %447, %221 : i32
      %449 = arith.ori %448, %98 : i32
      %450 = arith.andi %119, %279 : i32
      %451 = arith.ori %450, %219 : i32
      %452 = arith.ori %451, %126 : i32
      %453 = arith.ori %452, %221 : i32
      %454 = arith.ori %453, %98 : i32
      %455 = arith.ori %246, %168 : i32
      %456 = arith.andi %119, %455 : i32
      %457 = arith.ori %456, %163 : i32
      %458 = arith.ori %457, %221 : i32
      %459 = arith.ori %458, %98 : i32
      %460 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%99, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %461 = arith.andi %460, %116 : i32
      %462 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%461, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %463 = arith.andi %462, %128 : i32
      %464 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%132, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %465 = arith.andi %464, %116 : i32
      %466 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%465, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %467 = arith.andi %466, %140 : i32
      %468 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%467, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %469 = arith.andi %468, %156 : i32
      %470 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%469, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %471 = arith.andi %470, %159 : i32
      %472 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%471, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %473 = arith.andi %472, %165 : i32
      %474 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%473, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %475 = arith.andi %474, %167 : i32
      %476 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%475, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %477 = arith.andi %476, %116 : i32
      %478 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%477, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %479 = arith.andi %478, %170 : i32
      %480 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%479, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %481 = arith.andi %480, %179 : i32
      %482 = arith.ori %463, %481 : i32
      %483 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%181, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %484 = arith.andi %483, %188 : i32
      %485 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%484, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %486 = arith.andi %485, %199 : i32
      %487 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%486, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %488 = arith.andi %487, %201 : i32
      %489 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%488, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %490 = arith.andi %489, %207 : i32
      %491 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%490, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %492 = arith.andi %491, %208 : i32
      %493 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%492, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %494 = arith.andi %493, %212 : i32
      %495 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%494, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %496 = arith.andi %495, %215 : i32
      %497 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%496, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %498 = arith.andi %497, %223 : i32
      %499 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%498, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %500 = arith.andi %499, %238 : i32
      %501 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%116, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %502 = arith.andi %116, %501 : i32
      %503 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%502, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %504 = arith.andi %502, %503 : i32
      %505 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%500, %c4_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %506 = arith.andi %505, %504 : i32
      %507 = arith.ori %482, %506 : i32
      %508 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%243, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %509 = arith.andi %508, %116 : i32
      %510 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%509, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %511 = arith.andi %510, %245 : i32
      %512 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%511, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %513 = arith.andi %512, %116 : i32
      %514 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%513, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %515 = arith.andi %514, %132 : i32
      %516 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%515, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %517 = arith.andi %516, %128 : i32
      %518 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%517, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %519 = arith.andi %518, %116 : i32
      %520 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%519, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %521 = arith.andi %520, %201 : i32
      %522 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%521, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %523 = arith.andi %522, %248 : i32
      %524 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%523, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %525 = arith.andi %524, %250 : i32
      %526 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%525, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %527 = arith.andi %526, %116 : i32
      %528 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%527, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %529 = arith.andi %528, %252 : i32
      %530 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%529, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %531 = arith.andi %530, %99 : i32
      %532 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%531, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %533 = arith.andi %532, %254 : i32
      %534 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%533, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %535 = arith.andi %534, %212 : i32
      %536 = arith.ori %507, %535 : i32
      %537 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%260, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %538 = arith.andi %537, %116 : i32
      %539 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%538, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %540 = arith.andi %539, %265 : i32
      %541 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%540, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %542 = arith.andi %541, %273 : i32
      %543 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%542, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %544 = arith.andi %543, %278 : i32
      %545 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%282, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %546 = arith.andi %282, %545 : i32
      %547 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%544, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %548 = arith.andi %547, %546 : i32
      %549 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%548, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %550 = arith.andi %549, %288 : i32
      %551 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%550, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %552 = arith.andi %551, %181 : i32
      %553 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%552, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %554 = arith.andi %553, %116 : i32
      %555 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%554, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %556 = arith.andi %555, %295 : i32
      %557 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%556, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %558 = arith.andi %557, %300 : i32
      %559 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%558, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %560 = arith.andi %559, %306 : i32
      %561 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%560, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %562 = arith.andi %561, %310 : i32
      %563 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%562, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %564 = arith.andi %563, %116 : i32
      %565 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%564, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %566 = arith.andi %565, %116 : i32
      %567 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%566, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %568 = arith.andi %567, %317 : i32
      %569 = arith.ori %536, %568 : i32
      %570 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%321, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %571 = arith.andi %321, %570 : i32
      %572 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%c-1_i32, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %573 = arith.andi %572, %571 : i32
      %574 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%573, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %575 = arith.andi %574, %323 : i32
      %576 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%575, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %577 = arith.andi %576, %116 : i32
      %578 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%577, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %579 = arith.andi %578, %132 : i32
      %580 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%579, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %581 = arith.andi %580, %132 : i32
      %582 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%581, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %583 = arith.andi %582, %245 : i32
      %584 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%583, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %585 = arith.andi %584, %116 : i32
      %586 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%585, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %587 = arith.andi %586, %327 : i32
      %588 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%502, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %589 = arith.andi %502, %588 : i32
      %590 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%587, %c3_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %591 = arith.andi %590, %589 : i32
      %592 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%591, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %593 = arith.andi %592, %330 : i32
      %594 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%593, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %595 = arith.andi %594, %502 : i32
      %596 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%595, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %597 = arith.andi %596, %343 : i32
      %598 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%597, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %599 = arith.andi %598, %355 : i32
      %600 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%599, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %601 = arith.andi %600, %116 : i32
      %602 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%601, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %603 = arith.andi %602, %366 : i32
      %604 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%603, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %605 = arith.andi %604, %132 : i32
      %606 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%605, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %607 = arith.andi %606, %367 : i32
      %608 = arith.ori %569, %607 : i32
      %609 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%373, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %610 = arith.andi %609, %377 : i32
      %611 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%610, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %612 = arith.andi %611, %502 : i32
      %613 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%612, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %614 = arith.andi %613, %116 : i32
      %615 = arith.ori %614, %612 : i32
      %616 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%615, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %617 = arith.andi %616, %386 : i32
      %618 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%617, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %619 = arith.andi %618, %132 : i32
      %620 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%619, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %621 = arith.andi %620, %392 : i32
      %622 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%621, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %623 = arith.andi %622, %99 : i32
      %624 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%623, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %625 = arith.andi %624, %395 : i32
      %626 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%625, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %627 = arith.andi %626, %401 : i32
      %628 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%627, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %629 = arith.andi %628, %411 : i32
      %630 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%629, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %631 = arith.andi %630, %415 : i32
      %632 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%631, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %633 = arith.andi %632, %199 : i32
      %634 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%633, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %635 = arith.andi %634, %422 : i32
      %636 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%635, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %637 = arith.andi %636, %502 : i32
      %638 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%637, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %639 = arith.andi %638, %116 : i32
      %640 = arith.ori %639, %637 : i32
      %641 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%640, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %642 = arith.andi %641, %427 : i32
      %643 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%642, %c4_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %644 = arith.andi %643, %504 : i32
      %645 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%644, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %646 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%645, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %647 = arith.ori %645, %646 : i32
      %648 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%647, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %649 = arith.ori %647, %648 : i32
      %650 = arith.cmpi slt, %49, %arg1 : i32
      scf.if %650 {
        %652 = affine.load %alloca[0] : memref<1xmemref<?xi32>>
        %653 = "polygeist.subindex"(%652, %50) : (memref<?xi32>, index) -> memref<?xi32>
        %654 = affine.load %653[0] : memref<?xi32>
        %655 = arith.ori %654, %645 : i32
        affine.store %655, %653[0] : memref<?xi32>
        %656 = arith.addi %50, %31 : index
        %657 = "polygeist.subindex"(%arg5, %656) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %649, %657[0] : memref<?xi32>
        %658 = arith.addi %50, %29 : index
        %659 = "polygeist.subindex"(%arg5, %658) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %432, %659[0] : memref<?xi32>
        %660 = arith.addi %50, %27 : index
        %661 = "polygeist.subindex"(%arg5, %660) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %438, %661[0] : memref<?xi32>
        %662 = arith.addi %50, %25 : index
        %663 = "polygeist.subindex"(%arg5, %662) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %444, %663[0] : memref<?xi32>
        %664 = arith.addi %50, %23 : index
        %665 = "polygeist.subindex"(%arg5, %664) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %377, %665[0] : memref<?xi32>
        %666 = arith.addi %50, %21 : index
        %667 = "polygeist.subindex"(%arg5, %666) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %449, %667[0] : memref<?xi32>
        %668 = arith.addi %50, %19 : index
        %669 = "polygeist.subindex"(%arg5, %668) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %454, %669[0] : memref<?xi32>
        %670 = arith.addi %50, %17 : index
        %671 = "polygeist.subindex"(%arg5, %670) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %459, %671[0] : memref<?xi32>
        %672 = arith.addi %50, %15 : index
        %673 = "polygeist.subindex"(%arg5, %672) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %502, %673[0] : memref<?xi32>
        %674 = arith.addi %50, %13 : index
        %675 = "polygeist.subindex"(%arg5, %674) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %212, %675[0] : memref<?xi32>
        %676 = arith.addi %50, %11 : index
        %677 = "polygeist.subindex"(%arg5, %676) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %243, %677[0] : memref<?xi32>
        %678 = arith.addi %50, %9 : index
        %679 = "polygeist.subindex"(%arg5, %678) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %608, %679[0] : memref<?xi32>
        %680 = affine.load %alloca_0[0] : memref<1xmemref<?xi32>>
        %681 = "polygeist.subindex"(%680, %50) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %645, %681[0] : memref<?xi32>
        %682 = arith.addi %50, %4 : index
        %683 = "polygeist.subindex"(%arg5, %682) : (memref<?xi32>, index) -> memref<?xi32>
        affine.store %116, %683[0] : memref<?xi32>
      }
      %651 = arith.addi %arg6, %c1_i32 : i32
      scf.yield %651 : i32
    }
    %43:10 = scf.while (%arg6 = %0, %arg7 = %0, %arg8 = %0, %arg9 = %0, %arg10 = %0, %arg11 = %0, %arg12 = %0, %arg13 = %0, %arg14 = %0, %arg15 = %0) : (i32, i32, i32, i32, i32, i32, i32, i32, i32, i32) -> (i32, i32, i32, i32, i32, i32, i32, i32, i32, i32) {
      %45 = affine.load %alloca_0[0] : memref<1xmemref<?xi32>>
      %46 = func.call @_ZL12bs_all_zerosPjj(%45, %arg1) : (memref<?xi32>, i32) -> i8
      %47 = arith.cmpi ne, %46, %c0_i8 : i8
      %48 = arith.cmpi eq, %46, %c0_i8 : i8
      %49:10 = scf.if %47 -> (i32, i32, i32, i32, i32, i32, i32, i32, i32, i32) {
        scf.yield %arg6, %arg7, %arg8, %arg9, %arg10, %arg11, %arg12, %arg13, %arg14, %arg15 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
      } else {
        %50:10 = scf.while (%arg16 = %arg6, %arg17 = %arg7, %arg18 = %arg8, %arg19 = %arg9, %arg20 = %arg10, %arg21 = %arg11, %arg22 = %arg12, %arg23 = %arg13, %arg24 = %arg14, %arg25 = %c0_i32) : (i32, i32, i32, i32, i32, i32, i32, i32, i32, i32) -> (i32, i32, i32, i32, i32, i32, i32, i32, i32, i32) {
          %51 = arith.sitofp %arg25 : i32 to f64
          %52 = affine.load %38[0] : memref<?xi32>
          %53 = arith.addi %52, %c-1_i32 : i32
          %54 = arith.sitofp %53 : i32 to f64
          %55 = arith.divf %35, %54 : f64
          %56 = math.ceil %55 : f64
          %57 = arith.cmpf olt, %51, %56 : f64
          scf.condition(%57) %arg16, %arg17, %arg18, %arg19, %arg20, %arg21, %arg22, %arg23, %arg24, %arg25 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
        } do {
        ^bb0(%arg16: i32, %arg17: i32, %arg18: i32, %arg19: i32, %arg20: i32, %arg21: i32, %arg22: i32, %arg23: i32, %arg24: i32, %arg25: i32):
          %51 = affine.load %38[0] : memref<?xi32>
          %52 = arith.addi %51, %c-1_i32 : i32
          %53 = arith.muli %arg25, %52 : i32
          %54 = affine.load %41[0] : memref<?xi32>
          %55 = arith.addi %53, %54 : i32
          %56 = affine.load %alloca[0] : memref<1xmemref<?xi32>>
          %57 = arith.index_cast %55 : i32 to index
          %58 = "polygeist.subindex"(%56, %57) : (memref<?xi32>, index) -> memref<?xi32>
          %59 = affine.load %58[0] : memref<?xi32>
          %60 = arith.addi %57, %4 : index
          %61 = "polygeist.subindex"(%arg5, %60) : (memref<?xi32>, index) -> memref<?xi32>
          %62 = affine.load %61[0] : memref<?xi32>
          %63 = affine.load %alloca_0[0] : memref<1xmemref<?xi32>>
          %64 = "polygeist.subindex"(%63, %57) : (memref<?xi32>, index) -> memref<?xi32>
          %65 = affine.load %64[0] : memref<?xi32>
          %66 = arith.andi %65, %62 : i32
          %67 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%66, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
          %68 = arith.xori %59, %c-1_i32 : i32
          %69 = arith.andi %67, %68 : i32
          %70 = arith.ori %67, %59 : i32
          %71 = arith.cmpi slt, %55, %arg1 : i32
          scf.if %71 {
            %73 = affine.load %alloca_1[0] : memref<1xmemref<?xi32>>
            %74 = "polygeist.subindex"(%73, %57) : (memref<?xi32>, index) -> memref<?xi32>
            %75 = affine.load %74[0] : memref<?xi32>
            %76 = arith.ori %75, %70 : i32
            affine.store %76, %74[0] : memref<?xi32>
            %77 = affine.load %alloca_2[0] : memref<1xmemref<?xi32>>
            %78 = "polygeist.subindex"(%77, %57) : (memref<?xi32>, index) -> memref<?xi32>
            affine.store %69, %78[0] : memref<?xi32>
          }
          %72 = arith.addi %arg25, %c1_i32 : i32
          scf.yield %70, %69, %68, %67, %66, %69, %62, %70, %55, %72 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
        }
        %cast = memref.cast %alloca : memref<1xmemref<?xi32>> to memref<?xmemref<?xi32>>
        %cast_3 = memref.cast %alloca_1 : memref<1xmemref<?xi32>> to memref<?xmemref<?xi32>>
        func.call @_ZL12swap_pointerPPjS0_(%cast, %cast_3) : (memref<?xmemref<?xi32>>, memref<?xmemref<?xi32>>) -> ()
        %cast_4 = memref.cast %alloca_0 : memref<1xmemref<?xi32>> to memref<?xmemref<?xi32>>
        %cast_5 = memref.cast %alloca_2 : memref<1xmemref<?xi32>> to memref<?xmemref<?xi32>>
        func.call @_ZL12swap_pointerPPjS0_(%cast_4, %cast_5) : (memref<?xmemref<?xi32>>, memref<?xmemref<?xi32>>) -> ()
        scf.yield %50#0, %50#1, %50#2, %50#3, %50#4, %50#5, %50#6, %50#7, %50#8, %50#9 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
      }
      scf.condition(%48) %49#0, %49#1, %49#2, %49#3, %49#4, %49#5, %49#6, %49#7, %49#8, %49#9 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
    } do {
    ^bb0(%arg6: i32, %arg7: i32, %arg8: i32, %arg9: i32, %arg10: i32, %arg11: i32, %arg12: i32, %arg13: i32, %arg14: i32, %arg15: i32):
      scf.yield %arg6, %arg7, %arg8, %arg9, %arg10, %arg11, %arg12, %arg13, %arg14, %arg15 : i32, i32, i32, i32, i32, i32, i32, i32, i32, i32
    }
    %44 = scf.while (%arg6 = %c0_i32) : (i32) -> i32 {
      %45 = arith.sitofp %arg6 : i32 to f64
      %46 = affine.load %38[0] : memref<?xi32>
      %47 = arith.addi %46, %c-1_i32 : i32
      %48 = arith.sitofp %47 : i32 to f64
      %49 = arith.divf %35, %48 : f64
      %50 = math.ceil %49 : f64
      %51 = arith.cmpf olt, %45, %50 : f64
      scf.condition(%51) %arg6 : i32
    } do {
    ^bb0(%arg6: i32):
      %45 = affine.load %38[0] : memref<?xi32>
      %46 = arith.addi %45, %c-1_i32 : i32
      %47 = arith.muli %arg6, %46 : i32
      %48 = affine.load %41[0] : memref<?xi32>
      %49 = arith.addi %47, %48 : i32
      %50 = arith.index_cast %49 : i32 to index
      %51 = arith.addi %50, %9 : index
      %52 = "polygeist.subindex"(%arg5, %51) : (memref<?xi32>, index) -> memref<?xi32>
      %53 = affine.load %52[0] : memref<?xi32>
      %54 = arith.addi %50, %11 : index
      %55 = "polygeist.subindex"(%arg5, %54) : (memref<?xi32>, index) -> memref<?xi32>
      %56 = affine.load %55[0] : memref<?xi32>
      %57 = arith.addi %50, %13 : index
      %58 = "polygeist.subindex"(%arg5, %57) : (memref<?xi32>, index) -> memref<?xi32>
      %59 = affine.load %58[0] : memref<?xi32>
      %60 = arith.addi %50, %15 : index
      %61 = "polygeist.subindex"(%arg5, %60) : (memref<?xi32>, index) -> memref<?xi32>
      %62 = affine.load %61[0] : memref<?xi32>
      %63 = arith.addi %50, %17 : index
      %64 = "polygeist.subindex"(%arg5, %63) : (memref<?xi32>, index) -> memref<?xi32>
      %65 = affine.load %64[0] : memref<?xi32>
      %66 = arith.addi %50, %19 : index
      %67 = "polygeist.subindex"(%arg5, %66) : (memref<?xi32>, index) -> memref<?xi32>
      %68 = affine.load %67[0] : memref<?xi32>
      %69 = arith.addi %50, %21 : index
      %70 = "polygeist.subindex"(%arg5, %69) : (memref<?xi32>, index) -> memref<?xi32>
      %71 = affine.load %70[0] : memref<?xi32>
      %72 = arith.addi %50, %23 : index
      %73 = "polygeist.subindex"(%arg5, %72) : (memref<?xi32>, index) -> memref<?xi32>
      %74 = affine.load %73[0] : memref<?xi32>
      %75 = arith.addi %50, %25 : index
      %76 = "polygeist.subindex"(%arg5, %75) : (memref<?xi32>, index) -> memref<?xi32>
      %77 = affine.load %76[0] : memref<?xi32>
      %78 = arith.addi %50, %27 : index
      %79 = "polygeist.subindex"(%arg5, %78) : (memref<?xi32>, index) -> memref<?xi32>
      %80 = affine.load %79[0] : memref<?xi32>
      %81 = arith.addi %50, %29 : index
      %82 = "polygeist.subindex"(%arg5, %81) : (memref<?xi32>, index) -> memref<?xi32>
      %83 = affine.load %82[0] : memref<?xi32>
      %84 = arith.addi %50, %31 : index
      %85 = memref.load %arg5[%84] : memref<?xi32>
      %86 = affine.load %alloca[0] : memref<1xmemref<?xi32>>
      %87 = memref.load %86[%50] : memref<?xi32>
      %88 = arith.andi %87, %85 : i32
      %89 = arith.andi %88, %83 : i32
      %90 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%89, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %91 = arith.andi %90, %80 : i32
      %92 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%91, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %93 = arith.andi %92, %77 : i32
      %94 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%93, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %95 = arith.andi %94, %74 : i32
      %96 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%95, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %97 = arith.andi %96, %71 : i32
      %98 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%97, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %99 = arith.andi %98, %68 : i32
      %100 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%99, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %101 = arith.andi %100, %65 : i32
      %102 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%101, %c2_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %103 = arith.andi %102, %62 : i32
      %104 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%103, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %105 = arith.andi %104, %59 : i32
      %106 = func.call @_ZL26BSAdvanceRightFunctionSyncjjPj(%105, %c1_i32, %arg4) : (i32, i32, memref<?xi32>) -> i32
      %107 = arith.andi %106, %56 : i32
      %108 = arith.ori %53, %107 : i32
      %109 = arith.cmpi slt, %49, %arg1 : i32
      scf.if %109 {
        %111 = "polygeist.subindex"(%arg3, %50) : (memref<?xi32>, index) -> memref<?xi32>
        %112 = affine.load %111[0] : memref<?xi32>
        %113 = arith.ori %112, %108 : i32
        affine.store %113, %111[0] : memref<?xi32>
      }
      %110 = arith.addi %arg6, %c1_i32 : i32
      scf.yield %110 : i32
    }
    return
  }
  func.func private @_ZL26BSAdvanceRightFunctionSyncjjPj(%arg0: i32, %arg1: i32, %arg2: memref<?xi32>) -> i32 attributes {llvm.linkage = #llvm.linkage<internal>} {
    %c0 = arith.constant 0 : index
    %0 = memref.get_global @threadIdx : memref<1x3xi32>
    %1 = "polygeist.subindex"(%0, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %2 = "polygeist.subindex"(%1, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %3 = affine.load %2[0] : memref<?xi32>
    %4 = arith.index_cast %3 : i32 to index
    %5 = "polygeist.subindex"(%arg2, %4) : (memref<?xi32>, index) -> memref<?xi32>
    affine.store %arg0, %5[0] : memref<?xi32>
    %6 = call @_ZL31get_value_with_bit_offset_rightPji(%arg2, %arg1) : (memref<?xi32>, i32) -> i32
    return %6 : i32
  }
  func.func private @_ZL12bs_all_zerosPjj(%arg0: memref<?xi32>, %arg1: i32) -> i8 attributes {llvm.linkage = #llvm.linkage<internal>} {
    %c1_i8 = arith.constant 1 : i8
    %c0_i8 = arith.constant 0 : i8
    %c1_i32 = arith.constant 1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c0 = arith.constant 0 : index
    %0 = llvm.mlir.undef : i32
    %alloca = memref.alloca() : memref<1xi32>
    affine.store %0, %alloca[0] : memref<1xi32>
    %1 = llvm.mlir.undef : i8
    affine.store %c0_i32, %alloca[0] : memref<1xi32>
    %2 = memref.get_global @threadIdx : memref<1x3xi32>
    %3 = "polygeist.subindex"(%2, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %4 = "polygeist.subindex"(%3, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %5 = affine.load %4[0] : memref<?xi32>
    %6 = memref.get_global @blockDim : memref<1x3xi32>
    %7 = "polygeist.subindex"(%6, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %8 = "polygeist.subindex"(%7, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %9 = scf.while (%arg2 = %5) : (i32) -> i32 {
      %14 = arith.cmpi slt, %arg2, %arg1 : i32
      scf.condition(%14) %arg2 : i32
    } do {
    ^bb0(%arg2: i32):
      %14 = arith.index_cast %arg2 : i32 to index
      %15 = "polygeist.subindex"(%arg0, %14) : (memref<?xi32>, index) -> memref<?xi32>
      %16 = affine.load %15[0] : memref<?xi32>
      %17 = arith.cmpi ne, %16, %c0_i32 : i32
      scf.if %17 {
        %20 = memref.atomic_rmw ori %c1_i32, %alloca[%c0] : (i32, memref<1xi32>) -> i32
      }
      %18 = affine.load %8[0] : memref<?xi32>
      %19 = arith.addi %arg2, %18 : i32
      scf.yield %19 : i32
    }
    %10 = affine.load %alloca[0] : memref<1xi32>
    %11 = arith.cmpi ne, %10, %c0_i32 : i32
    %12 = arith.cmpi eq, %10, %c0_i32 : i32
    %13 = scf.if %12 -> (i8) {
      scf.yield %c1_i8 : i8
    } else {
      %14 = arith.select %11, %c0_i8, %1 : i8
      scf.yield %14 : i8
    }
    return %13 : i8
  }
  func.func private @_ZL12swap_pointerPPjS0_(%arg0: memref<?xmemref<?xi32>>, %arg1: memref<?xmemref<?xi32>>) attributes {llvm.linkage = #llvm.linkage<internal>} {
    %0 = affine.load %arg0[0] : memref<?xmemref<?xi32>>
    %1 = affine.load %arg1[0] : memref<?xmemref<?xi32>>
    affine.store %1, %arg0[0] : memref<?xmemref<?xi32>>
    affine.store %0, %arg1[0] : memref<?xmemref<?xi32>>
    return
  }
  func.func private @_ZL31get_value_with_bit_offset_rightPji(%arg0: memref<?xi32>, %arg1: i32) -> i32 attributes {llvm.linkage = #llvm.linkage<internal>} {
    %c-1_i32 = arith.constant -1 : i32
    %c0_i32 = arith.constant 0 : i32
    %c32_i32 = arith.constant 32 : i32
    %c0 = arith.constant 0 : index
    %0 = llvm.mlir.undef : i32
    %1 = arith.divsi %arg1, %c32_i32 : i32
    %2 = arith.remsi %arg1, %c32_i32 : i32
    %3 = memref.get_global @threadIdx : memref<1x3xi32>
    %4 = "polygeist.subindex"(%3, %c0) : (memref<1x3xi32>, index) -> memref<3xi32>
    %5 = "polygeist.subindex"(%4, %c0) : (memref<3xi32>, index) -> memref<?xi32>
    %6 = affine.load %5[0] : memref<?xi32>
    %7 = arith.cmpi slt, %6, %1 : i32
    %8 = arith.cmpi sge, %6, %1 : i32
    %9 = arith.select %7, %c0_i32, %0 : i32
    %10 = scf.if %8 -> (i32) {
      %11 = affine.load %5[0] : memref<?xi32>
      %12 = arith.subi %11, %1 : i32
      %13 = arith.index_cast %12 : i32 to index
      %14 = "polygeist.subindex"(%arg0, %13) : (memref<?xi32>, index) -> memref<?xi32>
      %15 = affine.load %14[0] : memref<?xi32>
      %16 = arith.cmpi ne, %11, %1 : i32
      %17 = scf.if %16 -> (i32) {
        %18 = affine.load %3[0, 0] : memref<1x3xi32>
        %19 = arith.subi %18, %1 : i32
        %20 = arith.addi %19, %c-1_i32 : i32
        %21 = arith.index_cast %20 : i32 to index
        %22 = memref.load %arg0[%21] : memref<?xi32>
        %23 = arith.cmpi eq, %2, %c0_i32 : i32
        %24 = scf.if %23 -> (i32) {
          scf.yield %c0_i32 : i32
        } else {
          %27 = arith.subi %c32_i32, %2 : i32
          %28 = arith.shli %22, %27 : i32
          scf.yield %28 : i32
        }
        %25 = arith.shrsi %15, %2 : i32
        %26 = arith.ori %25, %24 : i32
        scf.yield %26 : i32
      } else {
        scf.yield %9 : i32
      }
      scf.yield %17 : i32
    } else {
      scf.yield %9 : i32
    }
    return %10 : i32
  }
}
