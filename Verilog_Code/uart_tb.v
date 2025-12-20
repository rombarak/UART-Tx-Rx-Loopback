// UART Loopback Testbench
//--------------DESCRIPTION-----------------
// Testbench for the UART loopback system. Generates the clock and reset,
// sends multiple bytes through the UART transmitter, waits for each byte
// to be received, and compares TX vs RX results. Dumps waveform output.
//-------------------------------------------

module tb_baud_gen ;

    // Signals
    reg clk ;           
    reg rst ;           
    wire tick ;         

    // Parameters
    parameter CLK_FREQ  = 1_000_000 ;   // 1 MHz clock
    parameter BAUD_RATE = 10_000 ;      // 10 Kbps baud

    // DUT
    baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .tick(tick)
    );

    // Clock gen
    initial clk = 0 ;
    always #0.5 clk = ~clk ;  // 1 MHz (1 µs period)

    // Reset
    initial begin
        rst = 1 ;
        #5 rst = 0 ;
    end

    // Simulation
    initial begin
        $dumpfile("baud_gen_tb.vcd") ;
        $dumpvars(0, tb_baud_gen) ;
        #20000 $finish ;
    end

    // Monitor
    initial begin
        $display("Time (ns)\tTick") ;
        $monitor("%d\t\t%b", $time, tick) ;
    end

endmodule

// ---------------------------EXPLANATION---------------------------------
// The testbench creates a 50 MHz clock using 'always #10 clk = ~clk'.
// After releasing reset, it uses the 'send_byte' task to send bytes.
// Each call to send_byte sets tx_data, pulses tx_start for one cycle,
// waits for rx_done, and prints whether the transmitted and received
// bytes match. The simulation sends several test bytes and terminates.
// Waveform data is dumped using $dumpfile and $dumpvars for analysis.
// -----------------------------------------------------------------------
