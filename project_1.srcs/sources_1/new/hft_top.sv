`timescale 1ns / 1ps

module hft_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600
)(
    input  logic clk,
    input  logic cpu_resetn,
    input  logic uart_rxd,
    output logic uart_txd
);

logic [15:0] best_bid_price;
logic [15:0] best_bid_qty;
logic [15:0] best_ask_price;
logic [15:0] best_ask_qty;

    logic rst;
    assign rst = ~cpu_resetn;

    logic       rx_valid;
    logic [7:0] rx_data;

    // raw parser outputs
    logic        cmd_valid;
    logic [1:0]  cmd_op;
    logic        cmd_side;
    logic [15:0] cmd_price;
    logic [15:0] cmd_qty;

    // pipelined command signals into order_book
    logic        cmd_valid_r;
    logic [1:0]  cmd_op_r;
    logic        cmd_side_r;
    logic [15:0] cmd_price_r;
    logic [15:0] cmd_qty_r;

    logic        tx_start;
    logic [7:0]  tx_data;
    logic        tx_busy;

    logic        snap_start;
    logic        snap_busy;

    // -----------------------------
    // pipeline stage between parser and book
    // -----------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cmd_valid_r <= 1'b0;
            cmd_op_r    <= 2'd0;
            cmd_side_r  <= 1'b0;
            cmd_price_r <= 16'd0;
            cmd_qty_r   <= 16'd0;
            snap_start  <= 1'b0;
        end else begin
            // register parser outputs before feeding order_book
            cmd_valid_r <= cmd_valid;
            cmd_op_r    <= cmd_op;
            cmd_side_r  <= cmd_side;
            cmd_price_r <= cmd_price;
            cmd_qty_r   <= cmd_qty;

            // start tx one more cycle later so order_book outputs are stable
            snap_start <= cmd_valid_r;
        end
    end

    uart_rx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk(clk),
        .rst(rst),
        .rx(uart_rxd),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    cmd_parser u_parser (
        .clk(clk),
        .rst(rst),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .cmd_valid(cmd_valid),
        .cmd_op(cmd_op),
        .cmd_side(cmd_side),
        .cmd_price(cmd_price),
        .cmd_qty(cmd_qty)
    );

    order_book #(
        .MAX_LEVELS(8),
        .PRICE_W(16),
        .QTY_W(16)
    ) u_book (
        .clk(clk),
        .rst(rst),
        .cmd_valid(cmd_valid_r),
        .cmd_op(cmd_op_r),
        .cmd_side(cmd_side_r),
        .cmd_price(cmd_price_r),
        .cmd_qty(cmd_qty_r),
        .best_bid_price(best_bid_price),
        .best_bid_qty(best_bid_qty),
        .best_ask_price(best_ask_price),
        .best_ask_qty(best_ask_qty)
    );

    book_tx_fsm u_snap_tx (
        .clk(clk),
        .rst(rst),
        .start(snap_start),
        .best_bid_price(best_bid_price),
        .best_bid_qty(best_bid_qty),
        .best_ask_price(best_ask_price),
        .best_ask_qty(best_ask_qty),
        .tx_busy(tx_busy),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .busy(snap_busy)
    );

    uart_tx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_txd),
        .tx_busy(tx_busy)
    );

endmodule