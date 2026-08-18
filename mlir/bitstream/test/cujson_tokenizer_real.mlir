// RUN: bitstream-opt %s | FileCheck %s

module {
  bitstream.pipeline @cujson_tokenizer_baseline {
    %input = bitstream.buffer @block_GPU : !bitstream.buffer
    %has_non_ascii = bitstream.buffer @has_non_ascii_GPU {alias = "validation_flags_GPU", byte_offset = 0 : i64} : !bitstream.buffer
    %utf8_error = bitstream.buffer @utf8_error_GPU {alias = "validation_flags_GPU", byte_offset = 4 : i64} : !bitstream.buffer
    %slash = bitstream.buffer @backslashes_GPU {row = 1 : i64, storage = "uint32_alias_of_uint8_bitmap"} : !bitstream.buffer
    %quote = bitstream.buffer @quote_GPU {row = 0 : i64, storage = "uint32_alias_of_uint8_bitmap"} : !bitstream.buffer
    %openclose = bitstream.buffer @open_close_GPU {row = 2 : i64} : !bitstream.buffer
    %op = bitstream.buffer @op_GPU {row = 3 : i64} : !bitstream.buffer
    %realquote = bitstream.buffer @real_quote_GPU {row = 4 : i64} : !bitstream.buffer
    %instr = bitstream.buffer @inString_GPU {alias = "quote_GPU"} : !bitstream.buffer
    %counts = bitstream.buffer @set_bit_count {alias = "backslashes_GPU"} : !bitstream.buffer

    bitstream.kernel @checkAscii {
      %word = bitstream.logical_index : index
      %c0 = arith.constant 0 : index
      bitstream.read %input[%word] {bytes = 4 : i64, meaning = "input word checked for non-ASCII bytes"} : !bitstream.buffer
      bitstream.write %has_non_ascii[%c0] {bytes = 4 : i64, meaning = "scalar flag when a non-ASCII byte is present"} : !bitstream.buffer
    }

    bitstream.kernel @checkUTF8 {
      %word = bitstream.logical_index : index
      %c0 = arith.constant 0 : index
      %c1 = arith.constant 1 : index
      %has_previous = arith.cmpi sgt, %word, %c0 : index
      %previous = arith.subi %word, %c1 : index
      bitstream.read %input[%word] {bytes = 4 : i64, meaning = "current word for UTF-8 validation"} : !bitstream.buffer
      scf.if %has_previous {
        bitstream.read %input[%previous] {bytes = 4 : i64, meaning = "previous word for cross-word UTF-8 validation"} : !bitstream.buffer
      }
      bitstream.write %utf8_error[%c0] {bytes = 4 : i64, meaning = "scalar UTF-8 error flag"} : !bitstream.buffer
    }

    bitstream.kernel @step1_classify {
      %i = bitstream.logical_index : index
      %c8 = arith.constant 8 : index
      %input_i = arith.muli %i, %c8 : index
      bitstream.read %input[%input_i] {bytes = 8 : i64, meaning = "raw JSON bytes"} : !bitstream.buffer
      bitstream.write %slash[%i] {bytes = 1 : i64, meaning = "slash byte mask for 8 input bytes"} : !bitstream.buffer
      bitstream.write %quote[%i] {bytes = 1 : i64, meaning = "quote byte mask for 8 input bytes"} : !bitstream.buffer
      bitstream.write %op[%i] {bytes = 1 : i64, meaning = "structural candidate byte mask"} : !bitstream.buffer
      bitstream.write %openclose[%i] {bytes = 1 : i64, meaning = "open/close candidate byte mask"} : !bitstream.buffer
    }

    bitstream.kernel @step2_escape_quote {
      bitstream.state @slash_carry_parity transition = neighbor_finite_state {bits = 1 : i64, distance = 1 : i64, domain = 2 : i64, derived_from = "trailing backslash run"}
      %k = bitstream.logical_index : index
      %c1 = arith.constant 1 : index
      %j_expr = arith.subi %k, %c1 : index
      bitstream.read %slash[%k] {bytes = 4 : i64, meaning = "current slash word"} : !bitstream.buffer
      bitstream.read %slash[%j_expr] dependency = data_dependent_predecessor state = @slash_carry_parity state_kind = neighbor_finite_state {where = "j < k", meaning = "walk previous slash words only until non-full backslash run"} : !bitstream.buffer
      bitstream.read %quote[%k] {bytes = 4 : i64, meaning = "quote bitmap word"} : !bitstream.buffer
      bitstream.write %realquote[%k] {bytes = 4 : i64, meaning = "real quote bitmap after escaped-quote filter"} : !bitstream.buffer
      bitstream.write %quote[%k] {bytes = 4 : i64, reuse_as = "quote_count_row", meaning = "popcount of real quotes"} : !bitstream.buffer
    }

    bitstream.scan @step3_exclusive_scan operator = "add" {
      bitstream.state @quote_count_parity transition = add_mod {bits = 1 : i64, domain = 2 : i64, modulus = 2 : i64, derived_from = "quote prefix count low bit"}
      %k = bitstream.logical_index : index
      bitstream.read %quote[%k] {bytes = 4 : i64, meaning = "quote popcount row"} : !bitstream.buffer
      bitstream.write %quote[%k] {bytes = 4 : i64, meaning = "exclusive quote-count prefix"} : !bitstream.buffer
    }

    bitstream.kernel @step3_in_string {
      bitstream.state @starts_in_string transition = prefix_state_projection {bits = 1 : i64, domain = 2 : i64, derived_from = "quote_count_prefix & 1"}
      %i = bitstream.logical_index : index
      bitstream.read %realquote[%i] {bytes = 4 : i64, meaning = "real quote bitmap"} : !bitstream.buffer
      bitstream.project_state %quote[%i] {domain = 2 : i64, modulus = 2 : i64, projection_kind = "low_bit", read_access = "quote_prefix"} : !bitstream.buffer
      bitstream.read %quote[%i] dependency = prefix_state state = @starts_in_string state_kind = finite_state_projection {access_id = "quote_prefix", bytes = 4 : i64, meaning = "exclusive quote-count prefix"} : !bitstream.buffer
      bitstream.write %instr[%i] {bytes = 4 : i64, meaning = "in-string bitmap"} : !bitstream.buffer
    }

    bitstream.kernel @step4_filter_count {
      %k = bitstream.logical_index : index
      bitstream.read %op[%k] {bytes = 4 : i64, meaning = "structural candidate bitmap"} : !bitstream.buffer
      bitstream.read %openclose[%k] {bytes = 4 : i64, meaning = "open-close candidate bitmap"} : !bitstream.buffer
      bitstream.read %instr[%k] {bytes = 4 : i64, meaning = "in-string bitmap"} : !bitstream.buffer
      bitstream.write %instr[%k] {bytes = 4 : i64, meaning = "final structural bitmap"} : !bitstream.buffer
      bitstream.write %openclose[%k] {bytes = 4 : i64, meaning = "final open-close bitmap"} : !bitstream.buffer
      bitstream.write %counts[%k] {bytes = 4 : i64, meaning = "structural popcount for later scan"} : !bitstream.buffer
      bitstream.write %op[%k] {bytes = 4 : i64, meaning = "open-close popcount for later scan"} : !bitstream.buffer
    }
  }
}

// CHECK: bitstream.pipeline @cujson_tokenizer_baseline
// CHECK: bitstream.kernel @checkAscii
// CHECK: bitstream.kernel @checkUTF8
// CHECK: bitstream.kernel @step1_classify
