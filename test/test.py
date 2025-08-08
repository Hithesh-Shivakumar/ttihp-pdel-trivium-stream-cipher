# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os
# Tell Cocotb to resolve any 'x' bits as zeros instead of erroring
os.environ['COCOTB_RESOLVE_X'] = 'zero'

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

# ─── EDITABLE SEED & PLAINTEXT ────────────────────────────────────────────
SEED = 0xDE
DATA = [0xDE, 0xAD, 0xBE, 0xEF]
# ─────────────────────────────────────────────────────────────────────────

CMD_NORMAL = 0x00
CMD_RESET  = 0xFF

@cocotb.test()
async def tt_um_trivium_stream_processor(dut):
    log = dut._log
    log.info(f"Starting Trivium round-trip with SEED=0x{SEED:02X}")

    # Start 50 MHz clock (20 ns period)
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # --- Reset (low for 3 cycles) ---
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = CMD_NORMAL
    dut.rst_n.value  = 0
    for _ in range(3):
        await RisingEdge(dut.clk)

    # Release reset, wait one more
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Seed phase ---
    log.info(f"Seeding with 0x{SEED:02X}")
    dut.uio_in.value = SEED
    await RisingEdge(dut.clk)
    dut.uio_in.value = CMD_NORMAL
    await RisingEdge(dut.clk)
    # Extra edge to match `#20; uio_in=0; #20;` timing
    await RisingEdge(dut.clk)

    # --- First Processing Phase ---
    log.info("=== First Processing Phase ===")
    intermediate = []
    for i, val in enumerate(DATA):
        dut.ui_in.value = val
        for _ in range(8):
            await RisingEdge(dut.clk)
        out = dut.uo_out.value.integer
        intermediate.append(out)
        log.info(f"Input[{i}] = 0x{val:02X} → 0x{out:02X}")

    # --- Reset internal state via 0xFF ---
    log.info("Resetting internal state (0xFF)")
    dut.uio_in.value = CMD_RESET
    await RisingEdge(dut.clk)
    dut.uio_in.value = CMD_NORMAL
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # --- Reseed ---
    log.info(f"Re-seeding with 0x{SEED:02X}")
    dut.uio_in.value = SEED
    await RisingEdge(dut.clk)
    dut.uio_in.value = CMD_NORMAL
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # --- Second Processing Phase ---
    log.info("=== Second Processing Phase ===")
    final = []
    for i, val in enumerate(intermediate):
        dut.ui_in.value = val
        for _ in range(8):
            await RisingEdge(dut.clk)
        out = dut.uo_out.value.integer
        final.append(out)
        log.info(f"Input[{i}] = 0x{val:02X} → 0x{out:02X}")

    # --- Check Results ---
    log.info("=== Checking Results ===")
    ok = True
    for i, orig in enumerate(DATA):
        if final[i] == orig:
            log.info(f"PASS [{i}] 0x{orig:02X} → 0x{intermediate[i]:02X} → 0x{final[i]:02X}")
        else:
            log.error(f"FAIL [{i}] 0x{orig:02X} → 0x{intermediate[i]:02X} → 0x{final[i]:02X}")
            ok = False

    assert ok, f"Round-trip mismatch for SEED=0x{SEED:02X}"
    log.info("All vectors passed")
