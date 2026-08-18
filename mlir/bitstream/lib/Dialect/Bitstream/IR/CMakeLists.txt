add_mlir_dialect_library(MLIRBitstreamDialect
  BitstreamDialect.cpp
  BitstreamOps.cpp
  BitstreamTypes.cpp

  DEPENDS
  MLIRBitstreamDialectIncGen
  MLIRBitstreamOpsIncGen
  MLIRBitstreamTypesIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRSideEffectInterfaces
  MLIRSupport
)
