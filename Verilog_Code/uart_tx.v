// UART Transmitter (8N1)
//--------------DESCRIPTION-----------------
// UART transmitter. Sends a frame composed of: start bit (0), eight data
// bits LSB-first, and stop bit (1). Uses the baud 'tick' to time each bit
// and asserts 'tx_busy' while a frame is in progress.
//-------------------------------------------

module uart_tx (clk, rst, tick, tx_start, tx_data, tx_line, tx_busy) ;

    // Ports
    input        clk ;        // system clock
    input        rst ;        // async reset (active high)
    input        tick ;       // 1-cycle pulse per baud
    input        tx_start ;   // start request
    input  [7:0] tx_data ;    // byte to send (LSB first)
    output reg   tx_line ;    // serial TX line
    output reg   tx_busy ;    // high while sending

    // Params
    parameter DATA_BITS = 8 ; // fixed to 8 for 8N1

    // State encoding
    localparam [1:0] S_IDLE  = 2'd0 ,
                     S_START = 2'd1 ,
                     S_DATA  = 2'd2 ,
                     S_STOP  = 2'd3 ;

    // Internals
    reg [1:0] state ;                 // FSM state
    reg [2:0] bit_idx ;               // 0..7
    reg [7:0] shift_reg ;             // data shift register

    // Sequential logic
    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            state     <= S_IDLE ;
            bit_idx   <= 3'd0 ;
            shift_reg <= 8'd0 ;
            tx_line   <= 1'b1 ;       // idle level is '1'
            tx_busy   <= 1'b0 ;
        end
        else begin
            // default hold
            case (state)
                S_IDLE: begin
                    tx_line <= 1'b1 ;
                    tx_busy <= 1'b0 ;
                    if (tx_start) begin
                        shift_reg <= tx_data ;  // latch data
                        bit_idx   <= 3'd0 ;
                        tx_busy   <= 1'b1 ;
                        state     <= S_START ;
                    end
                end

                S_START: begin
                    if (tick) begin
                        tx_line <= 1'b0 ;      // start bit
                        state   <= S_DATA ;
                    end
                end

                S_DATA: begin
                    if (tick) begin
                        tx_line   <= shift_reg[0] ;        // LSB first
                        shift_reg <= {1'b0, shift_reg[7:1]} ; // shift right
                        if (bit_idx == (DATA_BITS-1))
                            state <= S_STOP ;
                        else
                            bit_idx <= bit_idx + 3'd1 ;
                    end
                end

                S_STOP: begin
                    if (tick) begin
                        tx_line <= 1'b1 ;      // stop bit
                        state   <= S_IDLE ;
                        tx_busy <= 1'b0 ;
                    end
                end

                default: state <= S_IDLE ;
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
