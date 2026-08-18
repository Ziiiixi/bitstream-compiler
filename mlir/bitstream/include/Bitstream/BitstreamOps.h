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

namespace bitstream {

// Return the enclosing recurrence whose own logical coordinate drives this
// read's index.  A read may be nested in another recurrence while capturing an
// outer coordinate, so callers must not rely on getParentOfType alone.
RecurrenceOp findVaryingRecurrence(ReadOp read);

} // namespace bitstream

#endif // BITSTREAM_OPS_H
