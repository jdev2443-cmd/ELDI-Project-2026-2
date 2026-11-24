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
