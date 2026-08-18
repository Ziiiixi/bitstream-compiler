#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamPasses.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/Casting.h"

#include <memory>
namespace bitstream {
#define GEN_PASS_DEF_BITSTREAMDEPENDENCYCLASSIFICATION
#include "Bitstream/BitstreamPasses.h.inc"
} // namespace bitstream

using namespace mlir;
using namespace bitstream;

namespace {

static bool isUnbounded(DependencyOp dep) {
  return !dep.getOperation()->hasAttr("producer_byte_window");
}

static DependencyGroupOp createDependencyGroup(OpBuilder &builder,
                                                Location loc,
                                                StringRef kind) {
  OperationState state(loc, DependencyGroupOp::getOperationName());
  state.addAttribute("kind", builder.getStringAttr(kind));
  Region *body = state.addRegion();
  body->push_back(new Block());
  auto group = cast<DependencyGroupOp>(builder.create(state));
  OpBuilder::atBlockEnd(&group.getBody().front()).create<YieldOp>(loc);
  return group;
}

static void flattenDependencyGroups(AnalysisOp analysis) {
  Block &analysisBody = analysis.getBody().front();
  Operation *analysisTerminator = analysisBody.getTerminator();
  SmallVector<DependencyGroupOp> groups;
  analysisBody.walk(
      [&](DependencyGroupOp group) { groups.push_back(group); });

  for (DependencyGroupOp group : groups) {
    SmallVector<DependencyOp> dependencies;
    group.getBody().walk(
        [&](DependencyOp dep) { dependencies.push_back(dep); });
    for (DependencyOp dep : dependencies)
      dep->moveBefore(analysisTerminator);
    group.erase();
  }
}

static void groupClassifiedDependencies(AnalysisOp analysis) {
  Block &analysisBody = analysis.getBody().front();
  SmallVector<DependencyOp> dependencies;
  for (Operation &op : analysisBody)
    if (auto dep = dyn_cast<DependencyOp>(op))
      dependencies.push_back(dep);

  OpBuilder builder(analysis.getContext());
  builder.setInsertionPoint(analysisBody.getTerminator());
  DependencyGroupOp bounded =
      createDependencyGroup(builder, analysis.getLoc(), "bounded");
  DependencyGroupOp unbounded =
      createDependencyGroup(builder, analysis.getLoc(), "unbounded");

  for (DependencyOp dep : dependencies) {
    Operation *groupTerminator =
        (isUnbounded(dep) ? unbounded : bounded)
            .getBody()
            .front()
            .getTerminator();
    dep->moveBefore(groupTerminator);
  }
}

struct BitstreamDependencyClassificationPass
    : bitstream::impl::BitstreamDependencyClassificationBase<
          BitstreamDependencyClassificationPass> {
  void runOnOperation() override {
    SmallVector<AnalysisOp> analyses;
    getOperation().walk(
        [&](AnalysisOp analysis) { analyses.push_back(analysis); });

    for (AnalysisOp analysis : analyses) {
      // This keeps the pass idempotent: re-running classification replaces the
      // old presentation groups instead of nesting another pair inside them.
      flattenDependencyGroups(analysis);

      groupClassifiedDependencies(analysis);
    }
  }
};

} // namespace

std::unique_ptr<Pass>
bitstream::createBitstreamDependencyClassificationPass() {
  return std::make_unique<BitstreamDependencyClassificationPass>();
}
