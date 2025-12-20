// UART Transmitter (8N1)
//--------------DESCRIPTION-----------------
// UART transmitter. Sends a frame composed of: start bit (0), eight data
// bits LSB-first, and stop bit (1). Uses the baud 'tick' to time each bit
// and asserts 'tx_busy' while a frame is in progress.
//-------------------------------------------

module uart_tx (clk, rst, tick, tx_start, tx_data, tx_line, tx_busy);
    input        clk;
    input        rst;
    input        tick;
    input        tx_start;
    input  [7:0] tx_data;
    output reg   tx_line;
    output reg   tx_busy;

    parameter DATA_BITS = 8;

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg [3:0] ticks_done; // Internal counter to track 16 ticks per bit

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_IDLE;
            bit_idx    <= 3'd0;
            shift_reg  <= 8'd0;
            tx_line    <= 1'b1;
            tx_busy    <= 1'b0;
            ticks_done <= 4'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    tx_line <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg  <= tx_data;
                        bit_idx    <= 3'd0;
                        tx_busy    <= 1'b1;
                        ticks_done <= 4'd0;
                        state      <= S_START;
                    end
                end

                S_START: begin
                    if (tick) begin
                        tx_line <= 1'b0;
                        if (ticks_done == 15) begin
                            ticks_done <= 4'd0;
                            state      <= S_DATA;
                        end else begin
                            ticks_done <= ticks_done + 4'd1;
                        end
                    end
                end

                S_DATA: begin
                    if (tick) begin
                        tx_line <= shift_reg[0];
                        if (ticks_done == 15) begin
                            ticks_done <= 4'd0;
                            shift_reg  <= {1'b0, shift_reg[7:1]};
                            if (bit_idx == (DATA_BITS-1))
                                state <= S_STOP;
                            else
                                bit_idx <= bit_idx + 3'd1;
                        end else begin
                            ticks_done <= ticks_done + 4'd1;
                        end
                    end
                end

                S_STOP: begin
                    if (tick) begin
                        tx_line <= 1'b1;
                        if (ticks_done == 15) begin
                            ticks_done <= 4'd0;
                            state      <= S_IDLE;
                            tx_busy    <= 1'b0;
                        end else begin
                            ticks_done <= ticks_done + 4'd1;
                        end
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

// ---------------------------EXPLANATION---------------------------------
// State machine with four states
// IDLE  line is 1. When tx_start is seen on clock edge it copies tx_data
//       into shift_reg sets tx_busy and moves to START.
// START on the next tick drives 0 for the start bit then moves to DATA.
// DATA  on each tick outputs shift_reg bit 0 shifts right and counts bits.
// STOP  on tick drives 1 for the stop bit clears tx_busy and returns to IDLE.
// All changes happen on clk. Line is high when idle.
// -----------------------------------------------------------------------
