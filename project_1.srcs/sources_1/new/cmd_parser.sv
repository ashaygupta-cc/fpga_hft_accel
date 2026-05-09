`timescale 1ns / 1ps

module cmd_parser (
    input  logic        clk,
    input  logic        rst,

    input  logic        rx_valid,
    input  logic [7:0]  rx_data,

    output logic        cmd_valid,
    output logic [1:0]  cmd_op,
    output logic        cmd_side,
    output logic [15:0] cmd_price,
    output logic [15:0] cmd_qty
);

    logic [2:0]  byte_count;
    logic [7:0]  b0, b1, b2, b3, b4;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_count <= 3'd0;
            b0 <= 8'd0;
            b1 <= 8'd0;
            b2 <= 8'd0;
            b3 <= 8'd0;
            b4 <= 8'd0;

            cmd_valid <= 1'b0;
            cmd_op    <= 2'd0;
            cmd_side  <= 1'b0;
            cmd_price <= 16'd0;
            cmd_qty   <= 16'd0;
        end else begin
            cmd_valid <= 1'b0;

            if (rx_valid) begin
                case (byte_count)
                    3'd0: begin
                        b0 <= rx_data;
                        byte_count <= 3'd1;
                    end

                    3'd1: begin
                        b1 <= rx_data;
                        byte_count <= 3'd2;
                    end

                    3'd2: begin
                        b2 <= rx_data;
                        byte_count <= 3'd3;
                    end

                    3'd3: begin
                        b3 <= rx_data;
                        byte_count <= 3'd4;
                    end

                    3'd4: begin
                        b4 <= rx_data;

                        cmd_op    <= b0[1:0];
                        cmd_side  <= b0[2];
                        cmd_price <= {b1, b2};
                        cmd_qty   <= {b3, rx_data};
                        cmd_valid <= 1'b1;

                        byte_count <= 3'd0;
                    end

                    default: begin
                        byte_count <= 3'd0;
                    end
                endcase
            end
        end
    end

endmodule