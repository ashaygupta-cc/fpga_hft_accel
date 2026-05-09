`timescale 1ns / 1ps

module tb_uart_rx;

    reg clk;
    reg rst;
    reg rx;
    wire [7:0] rx_data;
    wire rx_valid;

    localparam integer CLK_FREQ     = 100_000_000;
    localparam integer BAUD_RATE    = 115200;
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CLK_PERIOD   = 10; // 100 MHz => 10 ns

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    // 100 MHz clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // task to send one UART byte
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // idle
            rx = 1'b1;
            #(CLK_PERIOD * CLKS_PER_BIT);

            // start bit
            rx = 1'b0;
            #(CLK_PERIOD * CLKS_PER_BIT);

            // 8 data bits, LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #(CLK_PERIOD * CLKS_PER_BIT);
            end

            // stop bit
            rx = 1'b1;
            #(CLK_PERIOD * CLKS_PER_BIT);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        rx  = 1'b1; // UART idle high

        #100;
        rst = 1'b0;

        // send 'A' = 0x41
        send_uart_byte(8'h41);

        // wait a bit
        #(CLK_PERIOD * CLKS_PER_BIT * 3);

        // send 'B' = 0x42
        send_uart_byte(8'h42);

        #(CLK_PERIOD * CLKS_PER_BIT * 3);

        // send 'C' = 0x43
        send_uart_byte(8'h43);

        #(CLK_PERIOD * CLKS_PER_BIT * 5);

        $finish;
    end

    // console monitor
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("Time=%0t | rx_valid=1 | rx_data=0x%02h | char=%c",
                     $time, rx_data, rx_data);
        end
    end

endmodule