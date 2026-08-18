add_llvm_executable(bitstream-opt
  bitstream-opt.cpp
)

llvm_update_compile_flags(bitstream-opt)

target_link_libraries(bitstream-opt PRIVATE
  MLIRBitstreamDialect
  MLIRBitstreamTransforms
  MLIRAffineDialect
  MLIRAffineTransforms
  MLIRArithDialect
  MLIRFuncDialect
  MLIRGPUDialect
  MLIRLLVMDialect
  MLIRMathDialect
  MLIRMemRefDialect
  MLIRSCFDialect
  MLIRIR
  MLIROptLib
  MLIRParser
  MLIRPass
  MLIRSupport
  MLIRTransforms
)

mlir_check_all_link_libraries(bitstream-opt)
