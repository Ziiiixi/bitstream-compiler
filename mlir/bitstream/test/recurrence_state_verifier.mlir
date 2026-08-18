// RUN: bitstream-opt %s --split-input-file --verify-diagnostics -o /dev/null

module {
  bitstream.pipeline @valid_metadata {
    bitstream.kernel @consumer {
      bitstream.recurrence operator = "xor" attributes {initial_state = 0 : i64, state_domain = 2 : i64} {
      }
    }

    // The original scan spelling remains valid when finite-state metadata is
    // unavailable.
    bitstream.scan @legacy_scan operator = "add" {
    }

    bitstream.scan @finite_scan operator = "xor" attributes {initial_state = 1 : i64, state_domain = 2 : i64} {
    }
  }
}

// -----

module {
  bitstream.pipeline @recurrence_proof {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      bitstream.state @recurrence_state {bits = 1 : i64, domain = 2 : i64}
      bitstream.recurrence operator = "xor" attributes {initial_state = 0 : i64, state_domain = 2 : i64} {
        %i = bitstream.logical_index : index
        bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
      }
    }
  }

  bitstream.analysis @recurrence_proof_analysis for @recurrence_proof {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven finite_state_domain = 2 {buffer = @recurrence_proof::@tmp, consumer = @recurrence_proof::@consumer, producer = @recurrence_proof::@producer, states = [@recurrence_proof::@consumer::@recurrence_state]}
  }
}

// -----

module {
  bitstream.pipeline @scan_output_proof {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.scan @producer operator = "xor" attributes {initial_state = 0 : i64, state_domain = 2 : i64} {
      bitstream.state @scan_state {bits = 1 : i64, domain = 2 : i64}
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64, value_domain = 2 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      %i = bitstream.logical_index : index
      bitstream.read %tmp[%i] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
    }
  }

  bitstream.analysis @scan_output_proof_analysis for @scan_output_proof {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven finite_state_domain = 2 {buffer = @scan_output_proof::@tmp, consumer = @scan_output_proof::@consumer, producer = @scan_output_proof::@producer, states = [@scan_output_proof::@producer::@scan_state]}
  }
}

// -----

// A nested recurrence may capture the coordinate of an outer recurrence.  The
// dependency belongs to that outer recurrence, not merely to the closest
// recurrence marker around the read.
module {
  bitstream.pipeline @outer_recurrence_proof {
    %tmp = bitstream.buffer @tmp : !bitstream.buffer

    bitstream.kernel @producer {
      %i = bitstream.logical_index : index
      bitstream.write %tmp[%i] {access_id = "a0", bytes = 4 : i64} : !bitstream.buffer
    }

    bitstream.kernel @consumer {
      bitstream.state @outer_state {bits = 1 : i64, domain = 2 : i64}
      bitstream.recurrence operator = "xor" attributes {state_domain = 2 : i64} {
        %outer = bitstream.logical_index : index
        bitstream.recurrence operator = "xor" attributes {state_domain = 3 : i64} {
          bitstream.read %tmp[%outer] {access_id = "a1", bytes = 4 : i64} : !bitstream.buffer
        }
      }
    }
  }

  bitstream.analysis @outer_recurrence_proof_analysis for @outer_recurrence_proof {
    bitstream.dependency memory = raw producer_access = "a0" consumer_access = "a1" finite_state = proven finite_state_domain = 2 {buffer = @outer_recurrence_proof::@tmp, consumer = @outer_recurrence_proof::@consumer, producer = @outer_recurrence_proof::@producer, states = [@outer_recurrence_proof::@consumer::@outer_state]}
  }
}

// -----

module {
  bitstream.pipeline @nonpositive_domain {
    bitstream.kernel @consumer {
      // expected-error@+1 {{`state_domain` must be positive when present}}
      bitstream.recurrence operator = "xor" attributes {state_domain = 0 : i64} {
      }
    }
  }
}

// -----

module {
  bitstream.pipeline @negative_initial_state {
    // expected-error@+1 {{`initial_state` must be non-negative when present}}
    bitstream.scan @prefix operator = "xor" attributes {initial_state = -1 : i64, state_domain = 2 : i64} {
    }
  }
}

// -----

module {
  bitstream.pipeline @initial_state_without_domain {
    bitstream.kernel @consumer {
      // expected-error@+1 {{with `initial_state` requires `state_domain`}}
      bitstream.recurrence operator = "xor" attributes {initial_state = 0 : i64} {
      }
    }
  }
}

// -----

module {
  bitstream.pipeline @initial_state_out_of_domain {
    // expected-error@+1 {{`initial_state` must be less than `state_domain`}}
    bitstream.scan @prefix operator = "xor" attributes {initial_state = 2 : i64, state_domain = 2 : i64} {
    }
  }
}
