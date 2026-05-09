`timescale 1ns/1ps

module tb_order_book;

    logic clk;
    logic rst;

    logic        cmd_valid;
    logic [1:0]  cmd_op;
    logic        cmd_side;
    logic [15:0] cmd_price;
    logic [15:0] cmd_qty;

    logic [15:0] best_bid_price;
    logic [15:0] best_bid_qty;
    logic [15:0] best_ask_price;
    logic [15:0] best_ask_qty;

    order_book #(
        .MAX_LEVELS(8),
        .PRICE_W(16),
        .QTY_W(16)
    ) dut (
        .clk(clk),
        .rst(rst),
        .cmd_valid(cmd_valid),
        .cmd_op(cmd_op),
        .cmd_side(cmd_side),
        .cmd_price(cmd_price),
        .cmd_qty(cmd_qty),
        .best_bid_price(best_bid_price),
        .best_bid_qty(best_bid_qty),
        .best_ask_price(best_ask_price),
        .best_ask_qty(best_ask_qty)
    );

    localparam [1:0] OP_ADD     = 2'b00;
    localparam [1:0] OP_CANCEL  = 2'b01;
    localparam [1:0] OP_EXECUTE = 2'b10;

    always #5 clk = ~clk;

    task send_cmd(
        input [1:0] op,
        input       side,
        input [15:0] price,
        input [15:0] qty
    );
    begin
        @(posedge clk);
        cmd_valid <= 1'b1;
        cmd_op    <= op;
        cmd_side  <= side;
        cmd_price <= price;
        cmd_qty   <= qty;

        @(posedge clk);
        cmd_valid <= 1'b0;
        cmd_op    <= 2'b00;
        cmd_side  <= 1'b0;
        cmd_price <= 16'd0;
        cmd_qty   <= 16'd0;

        @(posedge clk);
        $display("T=%0t | BB=%0d x %0d | BA=%0d x %0d",
                 $time, best_bid_price, best_bid_qty, best_ask_price, best_ask_qty);
    end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        cmd_valid = 0;
        cmd_op = 0;
        cmd_side = 0;
        cmd_price = 0;
        cmd_qty = 0;

        #30;
        rst = 0;

        // add bids
        send_cmd(OP_ADD, 0, 16'd100, 16'd10);   // bid 100 qty 10
        send_cmd(OP_ADD, 0, 16'd101, 16'd5);    // bid 101 qty 5 -> best bid becomes 101
        send_cmd(OP_ADD, 0, 16'd99,  16'd20);   // bid 99 qty 20

        // add asks
        send_cmd(OP_ADD, 1, 16'd105, 16'd7);    // ask 105 qty 7
        send_cmd(OP_ADD, 1, 16'd104, 16'd12);   // ask 104 qty 12 -> best ask becomes 104
        send_cmd(OP_ADD, 1, 16'd106, 16'd3);    // ask 106 qty 3

        // add more at existing bid level
        send_cmd(OP_ADD, 0, 16'd101, 16'd8);    // bid 101 becomes 13

        // partial cancel
        send_cmd(OP_CANCEL, 0, 16'd101, 16'd4); // bid 101 becomes 9

        // full delete
        send_cmd(OP_EXECUTE, 1, 16'd104, 16'd12); // ask 104 removed, best ask becomes 105

        #50;
        $finish;
    end

endmodule