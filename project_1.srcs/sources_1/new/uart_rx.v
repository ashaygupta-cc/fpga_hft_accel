`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,
    output reg  [7:0] rx_data,
    output reg  rx_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_CLKS    = CLKS_PER_BIT / 2;

    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_shift;
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
            rx_shift  <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // default: pulse for 1 clk only

            case (state)
                IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;

                    // detect start bit
                    if (rx == 1'b0) begin
                        state <= START;
                    end
                end

                START: begin
                    // wait to middle of start bit, confirm still low
                    if (clk_count == HALF_CLKS - 1) begin
                        clk_count <= 16'd0;
                        if (rx == 1'b0) begin
                            state <= DATA;
                        end else begin
                            state <= IDLE; // false start
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;

                        // LSB first
                        rx_shift[bit_index] <= rx;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 16'd0;
                        state <= IDLE;

                        // optional stop-bit check: if (rx == 1'b1)
                        rx_data  <= rx_shift;
                        rx_valid <= 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule