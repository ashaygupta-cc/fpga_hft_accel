`timescale 1ns / 1ps

module order_book #(
    parameter int MAX_LEVELS = 16,
    parameter int PRICE_W    = 16,
    parameter int QTY_W      = 16
)(
    input  logic                 clk,
    input  logic                 rst,

    input  logic                 cmd_valid,
    input  logic [1:0]           cmd_op,      // 00=ADD, 01=CANCEL, 10=EXECUTE
    input  logic                 cmd_side,    // 0=BID, 1=ASK
    input  logic [PRICE_W-1:0]   cmd_price,
    input  logic [QTY_W-1:0]     cmd_qty,

    output logic [PRICE_W-1:0]   best_bid_price,
    output logic [QTY_W-1:0]     best_bid_qty,
    output logic [PRICE_W-1:0]   best_ask_price,
    output logic [QTY_W-1:0]     best_ask_qty
);

    localparam logic [1:0] OP_ADD     = 2'b00;
    localparam logic [1:0] OP_CANCEL  = 2'b01;
    localparam logic [1:0] OP_EXECUTE = 2'b10;

    // -----------------------------
    // Book storage
    // index 0 = best price
    // bids: descending
    // asks: ascending
    // -----------------------------
    logic [PRICE_W-1:0] bid_price [0:MAX_LEVELS-1];
    logic [QTY_W-1:0]   bid_qty   [0:MAX_LEVELS-1];
    logic               bid_valid [0:MAX_LEVELS-1];

    logic [PRICE_W-1:0] ask_price [0:MAX_LEVELS-1];
    logic [QTY_W-1:0]   ask_qty   [0:MAX_LEVELS-1];
    logic               ask_valid [0:MAX_LEVELS-1];

integer i;
integer j;

logic [$clog2(MAX_LEVELS):0] count;
logic signed [$clog2(MAX_LEVELS):0] idx;
logic [$clog2(MAX_LEVELS):0] ins;

    // top of book outputs
    always_comb begin
        if (bid_valid[0]) begin
            best_bid_price = bid_price[0];
            best_bid_qty   = bid_qty[0];
        end else begin
            best_bid_price = '0;
            best_bid_qty   = '0;
        end

        if (ask_valid[0]) begin
            best_ask_price = ask_price[0];
            best_ask_qty   = ask_qty[0];
        end else begin
            best_ask_price = '0;
            best_ask_qty   = '0;
        end
    end

    // main sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                bid_price[i] <= '0;
                bid_qty[i]   <= '0;
                bid_valid[i] <= 1'b0;

                ask_price[i] <= '0;
                ask_qty[i]   <= '0;
                ask_valid[i] <= 1'b0;
            end
        end else begin
            if (cmd_valid) begin

                // ============================================
                // BID side
                // ============================================
                
                count = 0;
                idx   = -1;
                ins   = 0;
                if (cmd_side == 1'b0) begin

                    // count valid levels
                    count = 0;
                    for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                        if (bid_valid[i]) count = count + 1;
                    end

                    // find existing price
                    idx = -1;
                    for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                        if (bid_valid[i] && bid_price[i] == cmd_price)
                            idx = i;
                    end

                    case (cmd_op)

                        // ---------------- ADD ----------------
                        OP_ADD: begin
                            if (idx != -1) begin
                                bid_qty[idx] <= bid_qty[idx] + cmd_qty;
                            end else if (count < MAX_LEVELS) begin
                                // find insert position for descending order
                                ins = count;
                                for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                                    if (i < count && cmd_price > bid_price[i] && ins == count)
                                        ins = i;
                                end

                                // shift right
                                for (j = MAX_LEVELS-1; j > 0; j = j - 1) begin
                                    if (j > ins) begin
                                        bid_price[j] <= bid_price[j-1];
                                        bid_qty[j]   <= bid_qty[j-1];
                                        bid_valid[j] <= bid_valid[j-1];
                                    end
                                end

                                // insert new level
                                bid_price[ins] <= cmd_price;
                                bid_qty[ins]   <= cmd_qty;
                                bid_valid[ins] <= 1'b1;
                            end
                        end

                        // -------- CANCEL / EXECUTE ----------
                        OP_CANCEL, OP_EXECUTE: begin
                            if (idx != -1) begin
                                if (bid_qty[idx] > cmd_qty) begin
                                    bid_qty[idx] <= bid_qty[idx] - cmd_qty;
                                end else begin
                                    // delete level and compact left
                                    for (j = 0; j < MAX_LEVELS-1; j = j + 1) begin
                                        if (j >= idx) begin
                                            bid_price[j] <= bid_price[j+1];
                                            bid_qty[j]   <= bid_qty[j+1];
                                            bid_valid[j] <= bid_valid[j+1];
                                        end
                                    end
                                    bid_price[MAX_LEVELS-1] <= '0;
                                    bid_qty[MAX_LEVELS-1]   <= '0;
                                    bid_valid[MAX_LEVELS-1] <= 1'b0;
                                end
                            end
                        end

                        default: begin
                        end
                    endcase
                end

                // ============================================
                // ASK side
                // ============================================
                else begin

                    // count valid levels
                    count = 0;
                    for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                        if (ask_valid[i]) count = count + 1;
                    end

                    // find existing price
                    idx = -1;
                    for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                        if (ask_valid[i] && ask_price[i] == cmd_price)
                            idx = i;
                    end

                    case (cmd_op)

                        // ---------------- ADD ----------------
                        OP_ADD: begin
                            if (idx != -1) begin
                                ask_qty[idx] <= ask_qty[idx] + cmd_qty;
                            end else if (count < MAX_LEVELS) begin
                                // find insert position for ascending order
                                ins = count;
                                for (i = 0; i < MAX_LEVELS; i = i + 1) begin
                                    if (i < count && cmd_price < ask_price[i] && ins == count)
                                        ins = i;
                                end

                                // shift right
                                for (j = MAX_LEVELS-1; j > 0; j = j - 1) begin
                                    if (j > ins) begin
                                        ask_price[j] <= ask_price[j-1];
                                        ask_qty[j]   <= ask_qty[j-1];
                                        ask_valid[j] <= ask_valid[j-1];
                                    end
                                end

                                // insert new level
                                ask_price[ins] <= cmd_price;
                                ask_qty[ins]   <= cmd_qty;
                                ask_valid[ins] <= 1'b1;
                            end
                        end

                        // -------- CANCEL / EXECUTE ----------
                        OP_CANCEL, OP_EXECUTE: begin
                            if (idx != -1) begin
                                if (ask_qty[idx] > cmd_qty) begin
                                    ask_qty[idx] <= ask_qty[idx] - cmd_qty;
                                end else begin
                                    // delete level and compact left
                                    for (j = 0; j < MAX_LEVELS-1; j = j + 1) begin
                                        if (j >= idx) begin
                                            ask_price[j] <= ask_price[j+1];
                                            ask_qty[j]   <= ask_qty[j+1];
                                            ask_valid[j] <= ask_valid[j+1];
                                        end
                                    end
                                    ask_price[MAX_LEVELS-1] <= '0;
                                    ask_qty[MAX_LEVELS-1]   <= '0;
                                    ask_valid[MAX_LEVELS-1] <= 1'b0;
                                end
                            end
                        end

                        default: begin
                        end
                    endcase
                end
            end
        end
    end

endmodule