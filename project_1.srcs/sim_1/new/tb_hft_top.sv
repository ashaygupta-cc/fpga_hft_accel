`timescale 1ns / 1ps

module tb_hft_top;

    logic clk;
    logic rst;
    logic uart_rxd;
    logic uart_txd;

    logic [15:0] best_bid_price;
    logic [15:0] best_bid_qty;
    logic [15:0] best_ask_price;
    logic [15:0] best_ask_qty;

    localparam integer CLK_FREQ_HZ    = 100_000_000;
    localparam integer BAUD_RATE      = 9600;
    localparam integer BIT_PERIOD_NS  = 1_000_000_000 / BAUD_RATE;

    localparam [1:0] OP_ADD     = 2'b00;
    localparam [1:0] OP_CANCEL  = 2'b01;
    localparam [1:0] OP_EXECUTE = 2'b10;

    // DUT
  hft_top #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .BAUD_RATE(BAUD_RATE)
) dut (
    .clk(clk),
    .cpu_resetn(~rst),
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),
    .best_bid_price(best_bid_price),
    .best_bid_qty(best_bid_qty),
    .best_ask_price(best_ask_price),
    .best_ask_qty(best_ask_qty)
);

    // receiver in TB to decode DUT's uart_txd response
    logic       mon_rx_valid;
    logic [7:0] mon_rx_data;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ_HZ),
        .BAUD_RATE(BAUD_RATE)
    ) tb_uart_monitor (
        .clk(clk),
        .rst(rst),
        .rx(uart_txd),
        .rx_data(mon_rx_data),
        .rx_valid(mon_rx_valid)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // response byte collection
    logic [7:0] resp [0:7];
    integer resp_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            resp_count <= 0;
        end else begin
            if (mon_rx_valid) begin
                if (resp_count < 8) begin
                    resp[resp_count] <= mon_rx_data;
                    resp_count <= resp_count + 1;
                end
            end
        end
    end

    task reset_resp_buffer;
        integer i;
        begin
            resp_count = 0;
            for (i = 0; i < 8; i = i + 1) begin
                resp[i] = 8'd0;
            end
        end
    endtask

    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            uart_rxd = 1'b1;
            #(BIT_PERIOD_NS);

            uart_rxd = 1'b0; // start bit
            #(BIT_PERIOD_NS);

            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd = data[i]; // LSB first
                #(BIT_PERIOD_NS);
            end

            uart_rxd = 1'b1; // stop bit
            #(BIT_PERIOD_NS);
        end
    endtask

    task send_packet(
        input [1:0]  op,
        input        side,
        input [15:0] price,
        input [15:0] qty
    );
        reg [7:0] b0, b1, b2, b3, b4;
        integer timeout_cycles;
        reg [15:0] bb_p, bb_q, ba_p, ba_q;
        begin
            b0 = {5'b00000, side, op};
            b1 = price[15:8];
            b2 = price[7:0];
            b3 = qty[15:8];
            b4 = qty[7:0];

            reset_resp_buffer();

            $display("T=%0t | SEND op=%0d side=%0d price=%0d qty=%0d",
                     $time, op, side, price, qty);

            send_uart_byte(b0);
            send_uart_byte(b1);
            send_uart_byte(b2);
            send_uart_byte(b3);
            send_uart_byte(b4);

            // wait until all 8 response bytes arrive
            timeout_cycles = 0;
            while (resp_count < 8 && timeout_cycles < 20000000) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (resp_count < 8) begin
                $display("T=%0t | ERROR: timed out waiting for 8 response bytes, got %0d",
                         $time, resp_count);
            end else begin
                bb_p = {resp[0], resp[1]};
                bb_q = {resp[2], resp[3]};
                ba_p = {resp[4], resp[5]};
                ba_q = {resp[6], resp[7]};

                $display("T=%0t | RESP BB=%0d x %0d | BA=%0d x %0d",
                         $time, bb_p, bb_q, ba_p, ba_q);
            end
        end
    endtask

    initial begin
        clk      = 1'b0;
        rst      = 1'b1;
        uart_rxd = 1'b1;

        #(20 * BIT_PERIOD_NS);
        rst = 1'b0;

        send_packet(OP_ADD,     1'b0, 16'd100, 16'd10);
        send_packet(OP_ADD,     1'b0, 16'd101, 16'd5);
        send_packet(OP_ADD,     1'b0, 16'd99,  16'd20);

        send_packet(OP_ADD,     1'b1, 16'd105, 16'd7);
        send_packet(OP_ADD,     1'b1, 16'd104, 16'd12);
        send_packet(OP_ADD,     1'b1, 16'd106, 16'd3);

        send_packet(OP_ADD,     1'b0, 16'd101, 16'd8);
        send_packet(OP_CANCEL,  1'b0, 16'd101, 16'd4);
        send_packet(OP_EXECUTE, 1'b1, 16'd104, 16'd12);

        #(10 * BIT_PERIOD_NS);

        $display("FINAL_INTERNAL | BB=%0d x %0d | BA=%0d x %0d",
                 best_bid_price, best_bid_qty,
                 best_ask_price, best_ask_qty);

        $finish;
    end

endmodule