// UART Receiver (8N1)
//--------------DESCRIPTION-----------------
// UART Receiver module. Receives serial data according to UART protocol
// by detecting the start bit and sampling each data bit on baud ticks.
//-------------------------------------------

module uart_rx (clk, rst, tick, rx_line, rx_data, rx_done, rx_busy) ;

    // Ports
    input        clk ;        // system clock
    input        rst ;        // async reset (active high)
    input        tick ;       // 1-cycle pulse per baud
    input        rx_line ;    // serial RX line
    output reg [7:0] rx_data ; // received byte
    output reg   rx_done ;    // 1 for one tick when byte complete
    output reg   rx_busy ;    // high while receiving

    // Parameters
    parameter DATA_BITS = 8 ; // fixed to 8 for 8N1

    // State encoding
    localparam [1:0] S_IDLE  = 2'd0 ,
                     S_START = 2'd1 ,
                     S_DATA  = 2'd2 ,
                     S_STOP  = 2'd3 ;

    // Internals
    reg [1:0] state ;                 // FSM state
    reg [2:0] bit_idx ;               // bit counter (0..7)
    reg [7:0] shift_reg ;             // shift register for received data
    reg [3:0] tick_count ;            // tick counter for half-bit delay

    // Sequential logic
    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            state      <= S_IDLE ;
            bit_idx    <= 3'd0 ;
            shift_reg  <= 8'd0 ;
            tick_count <= 4'd0 ;
            rx_data    <= 8'd0 ;
            rx_done    <= 1'b0 ;
            rx_busy    <= 1'b0 ;
        end
        else begin
            rx_done <= 1'b0 ;  // default low

            case (state)
                //--------------------------------------------------
                // Wait for start bit (falling edge)
                S_IDLE: begin
                    rx_busy <= 1'b0 ;
                    if (!rx_line) begin        // detect falling edge
                        rx_busy    <= 1'b1 ;
                        state      <= S_START ;
                        tick_count <= 4'd0 ;
                    end
                end

                //--------------------------------------------------
                // Confirm start bit (after half bit time)
                S_START: begin
                    if (tick) begin
                        tick_count <= tick_count + 4'd1 ;
                        if (tick_count == 4'd0) begin // sample start immediately

                            if (!rx_line) begin
                                tick_count <= 4'd0 ;
                                bit_idx    <= 3'd0 ;
                                state      <= S_DATA ;
                            end
                            else begin
                                state <= S_IDLE ; // false start or noise
                            end
                        end
                    end
                end

                //--------------------------------------------------
                // Read 8 data bits (LSB first)
                S_DATA: begin
                    if (tick) begin
                        shift_reg <= {rx_line, shift_reg[7:1]} ; // sample bit
                        if (bit_idx == (DATA_BITS-1))
                            state <= S_STOP ;
                        else
                            bit_idx <= bit_idx + 3'd1 ;
                    end
                end

                //--------------------------------------------------
                // Check stop bit and complete byte
                S_STOP: begin
                    if (tick) begin
                        if (rx_line) begin
                            rx_data <= shift_reg ;
                            rx_done <= 1'b1 ;   // byte complete
                        end
                        state   <= S_IDLE ;
                        rx_busy <= 1'b0 ;
                    end
                end

                //--------------------------------------------------
                default: state <= S_IDLE ;
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
