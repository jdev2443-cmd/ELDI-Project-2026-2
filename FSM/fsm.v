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
  
                // ESPERA DE INICIO
         
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

                // INICIO JUEGO

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

                // PENALIZACION

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

                // RESULTADO DE RONDA

                RESULT: begin

                    if (ms_tick)
                        state_counter <= state_counter + 1'b1;

                end

                // RESULTADO FINAL

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

            // SELECCION DE AVANZAR RONDA O TERMINAR PARTIDA

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
