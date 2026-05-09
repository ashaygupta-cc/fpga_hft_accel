`timescale 1ns / 1ps

module book_tx_fsm (
    input  logic        clk,
    input  logic        rst,

    input  logic        start,          // pulse to start sending snapshot
    input  logic [15:0] best_bid_price,
    input  logic [15:0] best_bid_qty,
    input  logic [15:0] best_ask_price,
    input  logic [15:0] best_ask_qty,

    input  logic        tx_busy,        // from uart_tx

    output logic        tx_start,       // pulse to uart_tx
    output logic [7:0]  tx_data,
    output logic        busy            // this FSM busy
);

    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,
        S_LOAD      = 3'd1,
        S_SEND      = 3'd2,
        S_WAIT_HIGH = 3'd3,
        S_WAIT_LOW  = 3'd4,
        S_NEXT      = 3'd5
    } state_t;

    state_t state;

    logic [7:0] payload [0:7];
    logic [2:0] byte_idx;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
            busy     <= 1'b0;
            byte_idx <= 3'd0;

            payload[0] <= 8'd0;
            payload[1] <= 8'd0;
            payload[2] <= 8'd0;
            payload[3] <= 8'd0;
            payload[4] <= 8'd0;
            payload[5] <= 8'd0;
            payload[6] <= 8'd0;
            payload[7] <= 8'd0;
        end else begin
            tx_start <= 1'b0; // default pulse low

            case (state)
                S_IDLE: begin
                    busy     <= 1'b0;
                    byte_idx <= 3'd0;

                    if (start) begin
                        state <= S_LOAD;
                        busy  <= 1'b1;
                    end
                end

                S_LOAD: begin
                    // capture fresh snapshot
                    payload[0] <= best_bid_price[15:8];
                    payload[1] <= best_bid_price[7:0];
                    payload[2] <= best_bid_qty[15:8];
                    payload[3] <= best_bid_qty[7:0];
                    payload[4] <= best_ask_price[15:8];
                    payload[5] <= best_ask_price[7:0];
                    payload[6] <= best_ask_qty[15:8];
                    payload[7] <= best_ask_qty[7:0];

                    byte_idx <= 3'd0;
                    state    <= S_SEND;
                end

                S_SEND: begin
                    if (!tx_busy) begin
                        tx_data  <= payload[byte_idx];
                        tx_start <= 1'b1;
                        state    <= S_WAIT_HIGH;
                    end
                end

                S_WAIT_HIGH: begin
                    // wait until uart_tx actually becomes busy
                    if (tx_busy) begin
                        state <= S_WAIT_LOW;
                    end
                end

                S_WAIT_LOW: begin
                    // wait until byte transmission is complete
                    if (!tx_busy) begin
                        state <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    if (byte_idx == 3'd7) begin
                        state <= S_IDLE;
                        busy  <= 1'b0;
                    end else begin
                        byte_idx <= byte_idx + 3'd1;
                        state    <= S_SEND;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule