#ifndef BITSTREAM_PASSES_H
#define BITSTREAM_PASSES_H

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/GPU/IR/GPUDialect.h"
#include "mlir/Pass/Pass.h"

namespace bitstream {

std::unique_ptr<mlir::Pass> createBitstreamDependenceAnalysisPass();
std::unique_ptr<mlir::Pass> createBitstreamDependencyClassificationPass();
std::unique_ptr<mlir::Pass> createBitstreamFiniteStateInferencePass();
std::unique_ptr<mlir::Pass> createBitstreamRecoverSemanticsPass();
std::unique_ptr<mlir::Pass> createBitstreamSpeculativeFusionPass();

#define GEN_PASS_REGISTRATION
#include "Bitstream/BitstreamPasses.h.inc"

} // namespace bitstream

#endif // BITSTREAM_PASSES_H
