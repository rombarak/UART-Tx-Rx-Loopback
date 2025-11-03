// UART Top Module (Loopback Integration)
//--------------DESCRIPTION-----------------
// Top-level UART integration (loopback). Connects the baud generator,
// transmitter, and receiver. The transmitter output is looped back to
// the receiver for full end-to-end testing.
//-------------------------------------------


module uart_top (clk, rst, tx_start, tx_data, rx_data, rx_done, tx_busy);

  // Ports
  input        clk;        // system clock input
  input        rst;        // asynchronous reset
  input        tx_start;   // start-transmission signal
  input  [7:0] tx_data;    // data byte to transmit
  output [7:0] rx_data;    // data byte received
  output       rx_done;    // pulse high when a byte is received
  output       tx_busy;    // indicates transmitter is active

  // Internal Wires
  wire tick;               // baud-rate tick from baud_gen
  wire tx_line;            // serial line between Tx and Rx (loopback)

  // Baud Generator
  baud_gen baud_inst (
    .clk (clk),            // connect system clock
    .rst (rst),            // connect reset
    .tick(tick)            // output tick pulse
  );

  // Transmitter
  uart_tx tx_inst (
    .clk      (clk),
    .rst      (rst),
    .tick     (tick),      // driven by baud tick
    .tx_start (tx_start),  // start pulse
    .tx_data  (tx_data),   // byte to send
    .tx_line  (tx_line),   // serial output line
    .tx_busy  (tx_busy)    // status flag
  );

  // Receiver (Loopback)
  uart_rx rx_inst (
    .clk      (clk),
    .rst      (rst),
    .tick     (tick),      // same baud tick for synchronization
    .rx_line  (tx_line),   // loopback connection from Tx
    .rx_data  (rx_data),   // received byte
    .rx_done  (rx_done),   // done pulse
    .rx_busy  ( )          // unused output ignored
  );

endmodule

// ---------------------------EXPLANATION---------------------------------
// The baud_gen module produces the shared timing tick.
// uart_tx sends serial data on tx_line.
// uart_rx receives data from the same tx_line (loopback).
// The design allows simulation of a full UART communication channel
// without external hardware. Each transmitted byte is immediately
// received and verified internally.
// -----------------------------------------------------------------------
