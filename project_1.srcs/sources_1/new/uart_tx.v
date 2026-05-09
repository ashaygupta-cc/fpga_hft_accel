`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire tx_start,
    input  wire [7:0] tx_data,
    output reg  tx,
    output reg  tx_busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  tx_shift;
    reg [1:0]  state;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            clk_count <= 16'd0;
            bit_index <= 3'd0;
            tx_shift  <= 8'd0;
            tx        <= 1'b1; // idle high
            tx_busy   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        tx_shift <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                START: begin
                    tx      <= 1'b0; // start bit
                    tx_busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state     <= DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    tx      <= tx_shift[bit_index];
                    tx_busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    tx      <= 1'b1; // stop bit
                    tx_busy <= 1'b1;

                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        tx_busy   <= 1'b0;
                        state     <= IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    tx    <= 1'b1;
                end
            endcase
        end
    end

endmodule