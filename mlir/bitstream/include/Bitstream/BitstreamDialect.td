#ifndef BITSTREAM_DIALECT_TD
#define BITSTREAM_DIALECT_TD

include "mlir/IR/DialectBase.td"

def Bitstream_Dialect : Dialect {
  let name = "bitstream";
  let cppNamespace = "::bitstream";
  let useDefaultTypePrinterParser = 1;

  let summary = "Bitstream pipeline dialect for finite-state bitmap workloads";
  let description = [{
    The bitstream dialect models GPU pipelines that transform dense input byte
    streams into packed bitmaps and small state summaries. It is deliberately
    higher level than LLVM/NVVM IR so compiler passes can still recover
    producer/consumer bitmap dependencies, prefix-scan state, and fusion
    legality.
  }];
}

#endif // BITSTREAM_DIALECT_TD
