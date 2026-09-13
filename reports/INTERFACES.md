# Current internal interfaces — single-key revision

All signals are synchronous to `clk` unless explicitly described as asynchronous
pad inputs. A transfer occurs only on `valid && ready`. Reset/abort/flush are the
only allowed cancellation of a held valid.

| Producer -> consumer | Payload/control | Contract |
|---|---|---|
| `kb -> regs` | `key_valid`, `key_ready`, `key_id[3:0]` | Event is emitted after qualified release and held under backpressure. |
| `regs -> auth_ctrl` | `txn_valid`, `txn_ready` | Only a correct PIN creates a token; held until fire. Wrong PIN increments fail_count without a token. |
| `regs -> kb` | `pin_rejected` via `flush` | Rejected PIN clears/rearms keyboard after stable release. |
| `rumcajs -> cipher` | elaboration parameter `KEY[127:0]` | Sole key; no key selection. Runtime reference variant receives the same constant at cmd fire. |
| `auth_ctrl -> cipher` | `cmd_valid`, `cmd_ready`, `abort` | One active block; abort enters 64-cycle wipe with all core ready/valid low and m_bit=0. |
| `serial_link -> szymon` | `s_valid`, `s_ready`, `s_bit` | One-bit RX holding register; exactly 64 accepted bits, MSB first. |
| `auth_ctrl -> szymon` | `seal_valid`, `seal_ready` | Fire only after correct CS close and drained 64-bit RX. |
| `szymon -> serial_link` | `m_valid`, `m_ready`, `m_bit`, `m_last` | 64 ciphertext bits MSB first; stable under backpressure. |
| `auth_ctrl -> serial_link` | `rx_arm`, `tx_arm`, `cancel` | Fresh CS-high then falling-edge framing is required after each arm. |
| `serial_link -> auth_ctrl` | `rx_active`, `rx_done`, `tx_active`, `tx_done`, `protocol_error` | One-cycle events except phase levels; errors never change fail_count directly. |
| `auth_ctrl -> regs` | `session_end` | Clears transaction/PIN context only; never fail_count. |
| `regs -> buzzer` | `beep_event` | One cycle for accepted digit or `*`; no GOOD/BAD distinction. |
| `timebase -> consumers` | `scan_tick`, `ms_tick` | One-cycle enables; no derived clocks. |

Reset domains:

- `cold_reset_n`: asynchronous assertion from `rst_n`, synchronous two-cycle release; clears demo fail count.
- `session_reset_n`: asynchronous assertion from `rst_n && ena`, synchronous two-cycle release; immediately cancels session visibility, then clears cipher data over 64 clocks, not fail count.
- External asynchronous inputs `col_n[3:0]`, `sdi`, `sclk`, `cs_n` pass through `sync2` before functional use.
- Top outputs are combinationally fail-safe masked by `rst_n && ena && session_reset_n`.

Controller timeout starts on authorized `txn_valid && txn_ready`, after final
PIN acceptance. Timeout wins over completion on the same tick; reset wins over
both. `req` is READY only in WAIT_RX before rx_active, mapped to uo_out[0].
Internal `rsp_ready` is not exposed: uo_out[1]=0. Host waits 10000 clocks after
RX before reading ciphertext on uo_out[2]. See docs/SINGLE_KEY.md.
