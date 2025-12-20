// UART Baud Rate Generator
//--------------DESCRIPTION-----------------
// Baud-rate generator. Divides the 50 MHz system clock down to the target
// bit rate (default 9600 bps) and outputs a single-cycle 'tick' at each
// bit boundary to drive TX/RX timing.
//-------------------------------------------


module baud_gen (clk, rst, tick);
    input  clk;
    input  rst;
    output reg tick;

    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 9600;

    // Updated divisor for x16 oversampling
    localparam integer DIVISOR = CLK_FREQ / (BAUD_RATE * 16);

    reg [31:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end
endmodule

// ---------------------------EXPLANATION---------------------------------
// A 32-bit counter increments on each 'clk'. When it reaches
// CLK_FREQ / (BAUD_RATE * 16)-1, the module asserts 'tick' for one clock and
// resets the counter to zero. 'rst' asynchronously clears the counter and
// tick. Both the transmitter and receiver consume the same 'tick' to keep
// their state machines aligned to UART bit boundaries.
// -----------------------------------------------------------------------
