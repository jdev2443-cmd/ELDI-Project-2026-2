module dfplayer_uart #(
    parameter CLK_FREQ = 27000000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire reset_n,

    input wire play_start,

    input wire [1:0] track_number,

    output reg df_tx,

    input wire df_rx
);

    localparam integer BAUD_DIV =
        CLK_FREQ / BAUD_RATE;

    localparam U_IDLE  = 2'd0;
    localparam U_START = 2'd1;
    localparam U_DATA  = 2'd2;
    localparam U_STOP  = 2'd3;

    reg [1:0] uart_state;

    reg [15:0] baud_count;

    reg [3:0] byte_index;

    reg [2:0] bit_index;

    reg [7:0] tx_byte;

    reg [1:0] track_latched;

    // PAQUETE DE COMANDO DFPLAYER

    function [7:0] packet_byte;

        input [3:0] index;

        input [1:0] track;

        begin

            case (index)

                4'd0: packet_byte = 8'h7E;

                4'd1: packet_byte = 8'hFF;

                4'd2: packet_byte = 8'h06;

                4'd3: packet_byte = 8'h12;

                4'd4: packet_byte = 8'h00;

                4'd5: packet_byte = 8'h00;

                4'd6:
                    packet_byte =
                        (track == 2'd1) ? 8'h01 : 8'h02;

                4'd7:
                    packet_byte = 8'hFE;

                4'd8:
                    packet_byte =
                        (track == 2'd1) ? 8'hE8 : 8'hE7;

                4'd9:
                    packet_byte = 8'hEF;

                default:
                    packet_byte = 8'hEF;

            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            uart_state <= U_IDLE;

            baud_count <= 16'd0;

            byte_index <= 4'd0;

            bit_index <= 3'd0;

            tx_byte <= 8'd0;

            track_latched <= 2'd1;

            df_tx <= 1'b1;

        end else begin

            case (uart_state)

                U_IDLE: begin

                    df_tx <= 1'b1;

                    baud_count <= 16'd0;

                    if (play_start) begin

                        track_latched <= track_number;

                        byte_index <= 4'd0;

                        bit_index <= 3'd0;

                        tx_byte <=
                            packet_byte(4'd0, track_number);

                        df_tx <= 1'b0;

                        uart_state <= U_START;

                    end
                end

                // BIT DE INICIO

                U_START: begin

                    if (baud_count >= BAUD_DIV - 1) begin

                        baud_count <= 16'd0;

                        df_tx <= tx_byte[0];

                        tx_byte <= {
                            1'b0,
                            tx_byte[7:1]
                        };

                        bit_index <= 3'd0;

                        uart_state <= U_DATA;

                    end else begin

                        baud_count <= baud_count + 1'b1;

                    end
                end

                // BITS DE DATOS

                U_DATA: begin

                    if (baud_count >= BAUD_DIV - 1) begin

                        baud_count <= 16'd0;

                        if (bit_index == 3'd7) begin

                            df_tx <= 1'b1;

                            uart_state <= U_STOP;

                        end else begin

                            df_tx <= tx_byte[0];

                            tx_byte <= {
                                1'b0,
                                tx_byte[7:1]
                            };

                            bit_index <= bit_index + 1'b1;

                        end

                    end else begin

                        baud_count <= baud_count + 1'b1;

                    end
                end

                // BIT DE PARADA

                U_STOP: begin

                    if (baud_count >= BAUD_DIV - 1) begin

                        baud_count <= 16'd0;

                        if (byte_index == 4'd9) begin

                            uart_state <= U_IDLE;

                            df_tx <= 1'b1;

                        end else begin

                            byte_index <= byte_index + 1'b1;

                            tx_byte <= packet_byte(
                                byte_index + 1'b1,
                                track_latched
                            );

                            df_tx <= 1'b0;

                            uart_state <= U_START;

                        end

                    end else begin

                        baud_count <= baud_count + 1'b1;

                    end
                end

                default: begin

                    uart_state <= U_IDLE;

                    df_tx <= 1'b1;

                    baud_count <= 16'd0;

                end

            endcase
        end
    end

endmodule
