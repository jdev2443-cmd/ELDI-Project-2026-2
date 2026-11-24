    wire flash = state_counter[7];

    reg [383:0] frame_next;

    reg [23:0] pixel_color;

    reg [3:0] logical_idx;

    reg [1:0] pixel_row;
    reg [1:0] pixel_col;

    reg symbol_pixel;

    integer k;

    always @* begin

        frame_next = 384'd0;

        for (k = 0; k < 16; k = k + 1) begin

            logical_idx = chain_to_logical(k[3:0]);

            pixel_row = logical_idx[3:2];

            pixel_col = logical_idx[1:0];

            // Cuadrado verde: borde exterior.
            symbol_pixel =
                (pixel_row == 0) ||
                (pixel_row == 3) ||
                (pixel_col == 0) ||
                (pixel_col == 3);

            if (TEST_MODE) begin

                if (k == 0)
                    pixel_color = C_RED;

                else if (k == 1)
                    pixel_color = C_GREEN;

                else if (k == 2)
                    pixel_color = C_BLUE;

                else
                    pixel_color = C_IDLE;

            end else begin

                case (game_state)

                    IDLE:
                        pixel_color = C_IDLE;

                    PLAY:
                        pixel_color =
                            (target_led == logical_idx)
                            ? C_GREEN : C_OFF;

                    PENALTY:
                        pixel_color = C_RED;

                    RESULT: begin

                        if (winner == WIN_PLAYER)

                            pixel_color =
                                symbol_pixel ? C_GREEN : C_OFF;

                        else

                            pixel_color =
                                (
                                    (pixel_row == pixel_col) ||
                                    (
                                        ({1'b0, pixel_row} +
                                         {1'b0, pixel_col}) == 3'd3
                                    )
                                )
                                ? C_RED : C_OFF;

                    end

                    FINAL: begin

                        if (flash) begin

                            if (final_player)

                                pixel_color =
                                    symbol_pixel ? C_PURPLE : C_OFF;

                            else

                                pixel_color =
                                    (
                                        (pixel_row == pixel_col) ||
                                        (
                                            ({1'b0, pixel_row} +
                                             {1'b0, pixel_col}) == 3'd3
                                        )
                                    )
                                    ? C_RED : C_OFF;

                        end else begin

                            pixel_color = C_OFF;

                        end
                    end

                    default:
                        pixel_color = C_OFF;

                endcase
            end

            frame_next[383 - (k * 24) -: 24] =
                pixel_color;

        end
    end

    // TRANSMISOR WS2812B

    localparam WS_RESET = 1'b0;
    localparam WS_SEND  = 1'b1;

    reg ws_state;

    reg [11:0] ws_reset_counter;

    reg [5:0] ws_bit_phase;

    reg [8:0] ws_bit_index;

    reg [383:0] shift_reg_ws;

    wire current_bit = shift_reg_ws[383];

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            ws_state <= WS_RESET;

            ws_reset_counter <= 0;

            ws_bit_phase <= 0;

            ws_bit_index <= 0;

            shift_reg_ws <= 0;

            ws_data <= 1'b0;

        end else begin

            case (ws_state)

                WS_RESET: begin

                    ws_data <= 1'b0;

                    if (ws_reset_counter >= RESET_CYCLES - 1) begin

                        ws_reset_counter <= 0;

                        shift_reg_ws <= frame_next;

                        ws_bit_index <= 0;

                        ws_bit_phase <= 0;

                        ws_state <= WS_SEND;

                    end else begin

                        ws_reset_counter <=
                            ws_reset_counter + 1'b1;

                    end
                end

                WS_SEND: begin

                    if (current_bit)

                        ws_data <= (ws_bit_phase < T1H);

                    else

                        ws_data <= (ws_bit_phase < T0H);

                    if (ws_bit_phase == T_BIT - 1) begin

                        ws_bit_phase <= 0;

                        if (ws_bit_index == 383) begin

                            ws_bit_index <= 0;

                            ws_state <= WS_RESET;

                        end else begin

                            ws_bit_index <= ws_bit_index + 1'b1;

                            shift_reg_ws <= {
                                shift_reg_ws[382:0], 1'b0
                            };

                        end
                    end else begin

                        ws_bit_phase <= ws_bit_phase + 1'b1;

                    end
                end

                default: begin

                    ws_state <= WS_RESET;

                    ws_data <= 1'b0;

                end
            endcase
        end
    end

endmodule

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

    // TRANSMISION UART

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
