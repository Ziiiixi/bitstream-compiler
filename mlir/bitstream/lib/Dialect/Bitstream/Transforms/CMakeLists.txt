add_mlir_library(MLIRBitstreamTransforms
  DependenceAnalysis.cpp
  DependencyClassification.cpp
  FiniteStateInference.cpp
  RecoverSemantics.cpp
  SpeculativeFusion.cpp

  DEPENDS
  MLIRBitstreamPassesIncGen
  MLIRBitstreamOpsIncGen

  LINK_LIBS PUBLIC
  MLIRBitstreamDialect
  MLIRAffineAnalysis
  MLIRAffineDialect
  MLIRArithDialect
  MLIRFuncDialect
  MLIRGPUDialect
  MLIRMathDialect
  MLIRMemRefDialect
  MLIRSCFDialect
  MLIRIR
  MLIRPass
  MLIRSupport
)
