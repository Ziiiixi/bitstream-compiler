#ifndef BITSTREAM_OPS_H
#define BITSTREAM_OPS_H

#include "Bitstream/BitstreamDialect.h"
#include "Bitstream/BitstreamTypes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

#include "Bitstream/BitstreamOpsEnums.h.inc"

#define GET_OP_CLASSES
#include "Bitstream/BitstreamOps.h.inc"

#endif // BITSTREAM_OPS_H
