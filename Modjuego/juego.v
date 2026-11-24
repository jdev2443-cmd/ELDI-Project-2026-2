module reaction_game #(
    parameter CLK_FREQ      = 27000000,
    parameter LEVEL         = 8'd32,
    parameter COLOR_GRB     = 1,
    parameter SERPENTINE    = 1,
    parameter USE_RESET_PIN = 0,
    parameter TEST_MODE     = 0
)(
    input wire clk,
    input wire reset_n,

    input wire start_dip_n,
    input wire dip_easy_n,
    input wire dip_medium_n,
    input wire dip_hard_n,

    input wire [15:0] bt,

    output reg ws_data,

    output wire df_tx,
    input wire df_rx
);


    localparam IDLE     = 3'd0;
    localparam PLAY     = 3'd1;
    localparam PENALTY  = 3'd2;
    localparam RESULT   = 3'd3;
    localparam FINAL    = 3'd5;

    localparam WIN_NONE   = 2'd0;
    localparam WIN_PLAYER = 2'd1;
    localparam WIN_BOT    = 2'd2;

    localparam ROUNDS = 3;

    localparam MS_COUNT = CLK_FREQ / 1000;
    localparam DB_COUNT = CLK_FREQ / 100;

    localparam PENALTY_MS = 500;
    localparam RESULT_MS  = 1000;
    localparam FINAL_MS   = 4000;

    localparam T_BIT        = 34;
    localparam T0H          = 10;
    localparam T1H          = 22;
    localparam RESET_CYCLES = CLK_FREQ / 12500;

    reg [15:0] por_cnt = 16'd0;
    reg rst_n = 1'b0;

    always @(posedge clk) begin
        if (por_cnt != 16'hFFFF)
            por_cnt <= por_cnt + 1'b1;

        rst_n <= (por_cnt == 16'hFFFF) &
                 (USE_RESET_PIN ? reset_n : 1'b1);
    end

    reg [15:0] btn_meta, btn_sync;

    reg start_meta, start_sync;
    reg easy_meta, easy_sync;
    reg medium_meta, medium_sync;
    reg hard_meta, hard_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            btn_meta <= 16'hFFFF;
            btn_sync <= 16'hFFFF;

            start_meta <= 1'b1;
            start_sync <= 1'b1;

            easy_meta <= 1'b1;
            easy_sync <= 1'b1;

            medium_meta <= 1'b1;
            medium_sync <= 1'b1;

            hard_meta <= 1'b1;
            hard_sync <= 1'b1;

        end else begin

            btn_meta <= bt;
            btn_sync <= btn_meta;

            start_meta <= start_dip_n;
            start_sync <= start_meta;

            easy_meta <= dip_easy_n;
            easy_sync <= easy_meta;

            medium_meta <= dip_medium_n;
            medium_sync <= medium_meta;

            hard_meta <= dip_hard_n;
            hard_sync <= hard_meta;

        end
    end

    reg [15:0] btn_stable;
    reg [15:0] press_pulse;

    reg [24:0] debounce_counter [0:15];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            btn_stable <= 16'hFFFF;
            press_pulse <= 16'b0;

            for (i = 0; i < 16; i = i + 1)
                debounce_counter[i] <= 0;

        end else begin

            press_pulse <= 16'b0;

            for (i = 0; i < 16; i = i + 1) begin

                if (btn_sync[i] == btn_stable[i]) begin

                    debounce_counter[i] <= 0;

                end else if (debounce_counter[i] >= DB_COUNT - 1) begin

                    debounce_counter[i] <= 0;

                    btn_stable[i] <= btn_sync[i];

                    if (btn_sync[i] == 1'b0)
                        press_pulse[i] <= 1'b1;

                end else begin

                    debounce_counter[i] <=
                        debounce_counter[i] + 1'b1;

                end
            end
        end
    end

    reg press_found;
    reg [3:0] pressed_index;

    integer j;

    always @* begin

        press_found = 1'b0;
        pressed_index = 4'd0;

        for (j = 0; j < 16; j = j + 1) begin

            if (press_pulse[j] && !press_found) begin

                press_found = 1'b1;
                pressed_index = j[3:0];

            end
        end
    end

    reg [31:0] ms_counter;
    reg ms_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            ms_counter <= 0;
            ms_tick <= 0;

        end else begin

            if (ms_counter >= MS_COUNT - 1) begin

                ms_counter <= 0;
                ms_tick <= 1'b1;

            end else begin

                ms_counter <= ms_counter + 1'b1;
                ms_tick <= 1'b0;

            end
        end
    end

    reg [15:0] selected_bot_time;

    always @* begin

        if (!hard_sync)
            selected_bot_time = 16'd550;

        else if (!medium_sync)
            selected_bot_time = 16'd900;

        else
            selected_bot_time = 16'd1500;

    end

    reg [2:0] game_state;

    reg [1:0] winner;
    reg [1:0] round_cnt;

    reg [1:0] player_wins;
    reg [1:0] bot_wins;

    reg [15:0] lfsr;
    reg [3:0] target_led;

    reg [13:0] elapsed_ms;

    reg [15:0] bot_elapsed_ms;
    reg [15:0] bot_limit_ms;

    reg [11:0] state_counter;

    reg start_armed;

    wire lfsr_fb =
        lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    wire result_done =
        (game_state == RESULT) &&
        ms_tick &&
        (state_counter >= RESULT_MS - 1);

    wire advance_round = result_done;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            game_state <= IDLE;

            winner <= WIN_NONE;

            round_cnt <= 0;

            player_wins <= 0;
            bot_wins <= 0;

            lfsr <= 16'hACE1;

            target_led <= 0;

            elapsed_ms <= 0;
            bot_elapsed_ms <= 0;

            bot_limit_ms <= 1500;

            state_counter <= 0;

            start_armed <= 1'b1;

        end else begin

            lfsr <= {lfsr[14:0], lfsr_fb};

            case (game_state)
           
                IDLE: begin

                    elapsed_ms <= 0;
                    bot_elapsed_ms <= 0;

                    winner <= WIN_NONE;

                    round_cnt <= 0;

                    player_wins <= 0;
                    bot_wins <= 0;

                    if (start_sync)
                        start_armed <= 1'b1;

                    if (!start_sync && start_armed) begin

                        start_armed <= 1'b0;

                        bot_limit_ms <= selected_bot_time;

                        target_led <= lfsr[3:0];

                        game_state <= PLAY;

                    end
                end

                PLAY: begin

                    if (ms_tick) begin

                        if (elapsed_ms < 9999)
                            elapsed_ms <= elapsed_ms + 1'b1;

                        if (bot_elapsed_ms < 65535)
                            bot_elapsed_ms <= bot_elapsed_ms + 1'b1;

                    end

                    if (press_found) begin

                        state_counter <= 0;

                        if (pressed_index == target_led) begin

                            winner <= WIN_PLAYER;

                            player_wins <= player_wins + 1'b1;

                            game_state <= RESULT;

                        end else begin

                            game_state <= PENALTY;

                        end

                    end else if (
                        ms_tick &&
                        (bot_elapsed_ms + 1 >= bot_limit_ms)
                    ) begin

                        winner <= WIN_BOT;

                        bot_wins <= bot_wins + 1'b1;

                        state_counter <= 0;

                        game_state <= RESULT;

                    end
                end

                PENALTY: begin

                    if (ms_tick) begin

                        if (elapsed_ms < 9999)
                            elapsed_ms <= elapsed_ms + 1'b1;

                        if (bot_elapsed_ms < 65535)
                            bot_elapsed_ms <= bot_elapsed_ms + 1'b1;

                        state_counter <= state_counter + 1'b1;

                    end

                    if (
                        ms_tick &&
                        (bot_elapsed_ms + 1 >= bot_limit_ms)
                    ) begin

                        winner <= WIN_BOT;

                        bot_wins <= bot_wins + 1'b1;

                        state_counter <= 0;

                        game_state <= RESULT;

                    end else if (
                        ms_tick &&
                        state_counter >= PENALTY_MS - 1
                    ) begin

                        state_counter <= 0;

                        game_state <= PLAY;

                    end
                end

                RESULT: begin

                    if (ms_tick)
                        state_counter <= state_counter + 1'b1;

                end

                FINAL: begin

                    if (ms_tick)
                        state_counter <= state_counter + 1'b1;

                    if (
                        ms_tick &&
                        state_counter >= FINAL_MS - 1
                    ) begin

                        state_counter <= 0;

                        game_state <= IDLE;

                    end
                end

                default:
                    game_state <= IDLE;

            endcase

            if (advance_round) begin

                state_counter <= 0;

                elapsed_ms <= 0;
                bot_elapsed_ms <= 0;

                winner <= WIN_NONE;

                if (round_cnt == ROUNDS - 1) begin

                    game_state <= FINAL;

                end else begin

                    round_cnt <= round_cnt + 1'b1;

                    bot_limit_ms <= selected_bot_time;

                    target_led <= lfsr[3:0];

                    game_state <= PLAY;

                end
            end
        end
    end

    function [23:0] rgb;

        input [7:0] r, g, b;

        begin

            if (COLOR_GRB)
                rgb = {g, r, b};
            else
                rgb = {r, g, b};

        end
    endfunction

    function [3:0] chain_to_logical;

        input [3:0] s;

        begin

            if (SERPENTINE && s[2])
                chain_to_logical = {s[3:2], ~s[1:0]};
            else
                chain_to_logical = s;

        end
    endfunction

wire [23:0] C_OFF =
        24'h000000;

    wire [23:0] C_RED =
        rgb(LEVEL, 8'd0, 8'd0);

    wire [23:0] C_GREEN =
        rgb(8'd0, LEVEL, 8'd0);

    wire [23:0] C_BLUE =
        rgb(8'd0, 8'd0, LEVEL);

    wire [23:0] C_PURPLE =
        rgb(LEVEL, 8'd0, LEVEL);

    wire [23:0] C_IDLE =
        rgb(LEVEL >> 2, LEVEL >> 3, 8'd0);

    wire final_player = (player_wins > bot_wins);

    reg music_start;
    reg [1:0] music_track;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            music_start <= 1'b0;

            music_track <= 2'd1;

        end else begin

            music_start <= 1'b0;

            if (
                advance_round &&
                (round_cnt == ROUNDS - 1)
            ) begin

                music_start <= 1'b1;

                music_track <=
                    final_player ? 2'd1 : 2'd2;

            end
        end
    end

    dfplayer_uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(9600)
    ) audio_player (

        .clk(clk),

        .reset_n(rst_n),

        .play_start(music_start),

        .track_number(music_track),

        .df_tx(df_tx),

        .df_rx(df_rx)

    );

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
