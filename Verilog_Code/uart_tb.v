// UART Loopback Testbench
//--------------DESCRIPTION-----------------
// Testbench for the UART loopback system. Generates the clock and reset,
// sends multiple bytes through the UART transmitter, waits for each byte
// to be received, and compares TX vs RX results. Dumps waveform output.
//-------------------------------------------

`timescale 1ns/1ns

module uart_tb;

  // -------------------- Test Signals --------------------
  reg clk;                  // simulated clock
  reg rst;                  // reset signal
  reg tx_start;             // start trigger
  reg [7:0] tx_data;        // byte to send
  wire [7:0] rx_data;       // received byte
  wire rx_done;             // signals reception complete
  wire tx_busy;             // transmitter status

  // -------------------- Instantiate DUT --------------------
  uart_top dut (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .rx_done(rx_done),
    .tx_busy(tx_busy)
  );

  // -------------------- Clock Generation --------------------
  always #10 clk = ~clk;     // toggle every 10 ns → 50 MHz clock

  // -------------------- Test Sequence --------------------
  initial begin
    $dumpfile("uart_loopback.vcd");    // waveform file
    $dumpvars(0, uart_tb);             // record all signals

    clk = 0; rst = 1; tx_start = 0; tx_data = 8'h00; // initialize
    #100 rst = 0;                     // release reset after 100 ns

    // send several bytes through loopback
    send_byte(8'hA5);
    send_byte(8'h3C);
    send_byte(8'hFF);
    send_byte(8'h00);
    send_byte(8'h55);

    #2000 $finish;                    // end simulation
  end

  // -------------------- Helper Task --------------------
  task send_byte(input [7:0] data);
  begin
    @(negedge clk);
    tx_data  = data;                  // load data byte
    tx_start = 1;                     // raise start flag
    @(negedge clk);
    tx_start = 0;                     // lower it next cycle
    wait(rx_done);                    // wait until byte received
    #20;
    $display("TX = 0x%02h  RX = 0x%02h  %s",
             data, rx_data,
             (rx_data == data) ? "V MATCH" : "X MISMATCH");
  end
  endtask

endmodule

// ---------------------------EXPLANATION---------------------------------
// The testbench creates a 50 MHz clock using 'always #10 clk = ~clk'.
// After releasing reset, it uses the 'send_byte' task to send bytes.
// Each call to send_byte sets tx_data, pulses tx_start for one cycle,
// waits for rx_done, and prints whether the transmitted and received
// bytes match. The simulation sends several test bytes and terminates.
// Waveform data is dumped using $dumpfile and $dumpvars for analysis.
// -----------------------------------------------------------------------
