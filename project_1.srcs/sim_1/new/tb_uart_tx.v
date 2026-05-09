`timescale 1ns / 1ps

module tb_uart_tx;

    reg clk;
    reg rst;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx;
    wire tx_busy;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115200;
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD   = 10; // 100 MHz

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // helper task to request a transmit
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
        clk = 1'b0;
        rst = 1'b1;
        tx_start = 1'b0;
        tx_data = 8'h00;

        #100;
        rst = 1'b0;

        // send 'A'
        start_tx_byte(8'h41);

        // wait until transmitter finishes
        wait (tx_busy == 1'b1);
        wait (tx_busy == 1'b0);

        #(CLK_PERIOD * CLKS_PER_BIT * 2);

        // send 'B'
        start_tx_byte(8'h42);

        wait (tx_busy == 1'b1);
        wait (tx_busy == 1'b0);

        #(CLK_PERIOD * CLKS_PER_BIT * 3);

        $finish;
    end

    // just log start/finish
    always @(posedge clk) begin
        if (tx_start)
            $display("Time=%0t | starting TX byte 0x%02h (%c)", $time, tx_data, tx_data);
    end

endmodule