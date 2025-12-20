// UART Receiver (8N1)
//--------------DESCRIPTION-----------------
// UART Receiver module. Receives serial data according to UART protocol
// by detecting the start bit and sampling each data bit on baud ticks.
//-------------------------------------------

module uart_rx (clk, rst, tick, rx_line, rx_data, rx_done, rx_busy);
    input        clk;
    input        rst;
    input        tick;
    input        rx_line;
    output reg [7:0] rx_data;
    output reg   rx_done;
    output reg   rx_busy;

    parameter DATA_BITS = 8;

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg [3:0] ticks_done; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_IDLE;
            bit_idx    <= 3'd0;
            shift_reg  <= 8'd0;
            ticks_done <= 4'd0; // התיקון כאן: השם המעודכן בלבד
            rx_data    <= 8'd0;
            rx_done    <= 1'b0;
            rx_busy    <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            case (state)
                S_IDLE: begin
                    rx_busy <= 1'b0;
                    if (!rx_line) begin
                        rx_busy    <= 1'b1;
                        ticks_done <= 4'd0;
                        state      <= S_START;
                    end
                end

                S_START: begin
                    if (tick) begin
                        if (ticks_done == 7) begin // Mid-point check
                            if (!rx_line) begin
                                ticks_done <= 4'd0;
                                bit_idx    <= 3'd0;
                                state      <= S_DATA;
                            end else begin
                                state <= S_IDLE;
                            end
                        end else begin
                            ticks_done <= ticks_done + 4'd1;
                        end
                    end
                end

                S_DATA: begin
                    if (tick) begin
                        if (ticks_done == 15) begin // Sample at mid-point
                            ticks_done <= 4'd0;
                            shift_reg  <= {rx_line, shift_reg[7:1]};
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
                        if (ticks_done == 15) begin
                            if (rx_line) begin
                                rx_data <= shift_reg;
                                rx_done <= 1'b1;
                            end
                            state   <= S_IDLE;
                            rx_busy <= 1'b0;
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
// The receiver uses a finite state machine with four states:
// 1. IDLE  : Waits for rx_line to go low (start bit detected).
// 2. START : Waits one tick to confirm a valid start bit.
// 3. DATA  : Samples each data bit on consecutive ticks into shift_reg
//            (LSB-first). Counts until all 8 bits are received.
// 4. STOP  : On the next tick, checks if rx_line is high (stop bit).
//            If valid, moves shift_reg to rx_data and pulses rx_done.
// This method ensures stable sampling at the middle of each bit period
// and accurate reception even without oversampling.
// -----------------------------------------------------------------------
