// RUN: bitstream-opt %s --split-input-file --verify-diagnostics -o /dev/null

module {
  bitstream.pipeline @bounded_missing_window {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @bounded_missing_window_analysis for @bounded_missing_window {
    // expected-error@+1 {{ordinary dependency requires `producer_byte_window`}}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none {buffer = @bounded_missing_window::@tmp, consumer = @bounded_missing_window::@consumer, producer = @bounded_missing_window::@producer}
  }
}

// -----

module {
  bitstream.pipeline @none_with_domain {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
    }
  }
  bitstream.analysis @none_with_domain_analysis for @none_with_domain {
    // expected-error@+1 {{with `finite_state = none` must not carry `finite_state_domain`}}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> finite_state_domain = 2 {buffer = @none_with_domain::@tmp, consumer = @none_with_domain::@consumer, producer = @none_with_domain::@producer}
  }
}

// -----

module {
  bitstream.pipeline @proven_without_domain {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer
    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }
    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      bitstream.project_state %tmp[%i] {domain = 2 : i64, read_access = "a1"} : !bitstream.buffer
    }
  }
  bitstream.analysis @proven_without_domain_analysis for @proven_without_domain {
    // expected-error@+1 {{with `finite_state = proven` requires a positive `finite_state_domain`}}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> {buffer = @proven_without_domain::@tmp, consumer = @proven_without_domain::@consumer, producer = @proven_without_domain::@producer}
  }
}

// -----

module {
  bitstream.pipeline @unbounded_with_window {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.scan @producer operator = "add" {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @unbounded_with_window_analysis for @unbounded_with_window {
    // expected-error@+1 {{structurally unbounded dependency must not carry `producer_byte_window`}}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 4, d0 * 4 + 4)> {buffer = @unbounded_with_window::@tmp, consumer = @unbounded_with_window::@consumer, producer = @unbounded_with_window::@producer}
  }
}

// -----

module {
  bitstream.pipeline @bounded_wrong_window {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {
        access_id = "a1",
        byte_index = affine_map<(d0) -> (d0 * 8 + 4)>,
        bytes = 4 : i64
      } : !bitstream.buffer
    }
  }

  bitstream.analysis @bounded_wrong_window_analysis for @bounded_wrong_window {
    // expected-error@+1 {{`producer_byte_window` must equal the consumer read's half-open physical byte interval}}
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = none producer_byte_window = affine_map<(d0) -> (d0 * 8, d0 * 8 + 4)> {buffer = @bounded_wrong_window::@tmp, consumer = @bounded_wrong_window::@consumer, producer = @bounded_wrong_window::@producer}
  }
}
