#include "Bitstream/BitstreamDialect.h"

#include "Bitstream/BitstreamOps.h"
#include "Bitstream/BitstreamTypes.h"

#include "Bitstream/BitstreamDialect.cpp.inc"

using namespace mlir;
using namespace bitstream;

void BitstreamDialect::initialize() {
  addTypes<
#define GET_TYPEDEF_LIST
#include "Bitstream/BitstreamTypes.cpp.inc"
      >();

  addOperations<
#define GET_OP_LIST
#include "Bitstream/BitstreamOps.cpp.inc"
      >();
}
