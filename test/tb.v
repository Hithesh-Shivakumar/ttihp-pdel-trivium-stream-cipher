`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump the signals to a VCD file for waveform inspection
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wires and registers
  reg clk = 0;
  reg rst_n = 0;
  reg ena = 1;

  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Clock generation: 50 MHz = 20 ns period
  always #10 clk = ~clk;

  // DUT instantiation
  tt_um_trivium_stream_processor user_project (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // Test vectors
  reg [7:0] input_data  [0:3];
  reg [7:0] intermediate [0:3];
  reg [7:0] output_data  [0:3];

  integer i;

  initial begin
    // Input Initialization
    input_data[0] = 8'hDE;
    input_data[1] = 8'hAD;
    input_data[2] = 8'hBE;
    input_data[3] = 8'hEF;

    ui_in  = 8'h00;
    uio_in = 8'h00;

    // Reset
    rst_n = 0;
    #50;
    rst_n = 1;

    // === SEED INPUT ===
    uio_in = 8'hBB;  // Custom seed
    #20;
    uio_in = 8'h00;  // Clear
    #20;

    // === FIRST PROCESSING PHASE ===
    $display("=== First Processing Phase ===");
    for (i = 0; i < 4; i = i + 1) begin
      ui_in = input_data[i];
      repeat (8) @(posedge clk);
      intermediate[i] = uo_out;
      $display("Input[%0d] = 0x%02x => Output = 0x%02x", i, input_data[i], intermediate[i]);
    end

    // === RESET STATE ===
    uio_in = 8'hFF;
    #20;
    uio_in = 8'h00;
    #40;

    // === SAME SEED RE-INPUT ===
    uio_in = 8'hBB;
    #20;
    uio_in = 8'h00;
    #20;

    // === SECOND PROCESSING PHASE ===
    $display("=== Second Processing Phase ===");
    for (i = 0; i < 4; i = i + 1) begin
      ui_in = intermediate[i];
      repeat (8) @(posedge clk);
      output_data[i] = uo_out;
      $display("Input[%0d] = 0x%02x => Output = 0x%02x", i, intermediate[i], output_data[i]);
    end

    // === VERIFY OUTPUT ===
    $display("=== Test Result ===");
    for (i = 0; i < 4; i = i + 1) begin
      if (input_data[i] == output_data[i])
        $display("PASS: [%0d] 0x%02x -> 0x%02x -> 0x%02x", i, input_data[i], intermediate[i], output_data[i]);
      else
        $display("FAIL: [%0d] 0x%02x -> 0x%02x -> 0x%02x", i, input_data[i], intermediate[i], output_data[i]);
    end

    #100000;
    $finish;
  end

endmodule
