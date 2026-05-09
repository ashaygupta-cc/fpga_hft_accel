`timescale 1ns / 1ps

module tb_uart_loopback;

    reg clk;
    reg rst;

    reg        tx_start;
    reg [7:0]  tx_data;
    wire       serial_line;
    wire       tx_busy;

    wire [7:0] rx_data;
    wire       rx_valid;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115200;
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD   = 10; // 100 MHz

    // transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_uut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(serial_line),
        .tx_busy(tx_busy)
    );

    // receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_uut (
        .clk(clk),
        .rst(rst),
        .rx(serial_line),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    // 100 MHz clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // task to request TX of one byte
    task start_tx_byte;
        input [7:0] data;
        begin
            @(posedge clk);
            tx_data  <= data;
            tx_start <= 1'b1;

            @(posedge clk);
            tx_start <= 1'b0;
        end
    endtask

    initial begin
        clk      = 1'b0;
        rst      = 1'b1;
        tx_start = 1'b0;
        tx_data  = 8'h00;

        #100;
        rst = 1'b0;

        // send A
        start_tx_byte(8'h41);
        wait (tx_busy == 1'b1);
        wait (tx_busy == 1'b0);
        #(CLK_PERIOD * CLKS_PER_BIT * 2);

        // send B
        start_tx_byte(8'h42);
        wait (tx_busy == 1'b1);
        wait (tx_busy == 1'b0);
        #(CLK_PERIOD * CLKS_PER_BIT * 2);

        // send C
        start_tx_byte(8'h43);
        wait (tx_busy == 1'b1);
        wait (tx_busy == 1'b0);
        #(CLK_PERIOD * CLKS_PER_BIT * 3);

        $finish;
    end

    // log TX start
    always @(posedge clk) begin
        if (tx_start) begin
            $display("Time=%0t | TX start byte 0x%02h (%c)", $time, tx_data, tx_data);
        end
    end

    // log RX result
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("Time=%0t | RX received byte 0x%02h (%c)", $time, rx_data, rx_data);
        end
    end

endmodule