#ifndef BITSTREAM_TYPES_TD
#define BITSTREAM_TYPES_TD

include "mlir/IR/AttrTypeBase.td"
include "Bitstream/BitstreamDialect.td"

def Bitstream_BufferType : TypeDef<Bitstream_Dialect, "Buffer"> {
  let mnemonic = "buffer";
  let summary = "logical bitstream buffer handle";
  let description = [{
    A logical buffer represents an input byte stream, intermediate bitmap row,
    prefix metadata row, or final bitmap output. The type intentionally hides
    the physical allocation so dependence analysis can reason about logical
    producer/consumer edges first.
  }];
}

#endif // BITSTREAM_TYPES_TD
