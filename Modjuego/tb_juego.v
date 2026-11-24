module tb_reaction_game;

    parameter CLK_FREQ = 100000;

    reg clk;
    reg reset_n;

    reg start_dip_n;
    reg dip_easy_n;
    reg dip_medium_n;
    reg dip_hard_n;

    reg [15:0] bt;

    wire ws_data;
    wire df_tx;
    reg df_rx;

    integer round_test;
    integer target_test;

    reaction_game #(
        .CLK_FREQ(CLK_FREQ),
        .LEVEL(8'd32),
        .COLOR_GRB(1),
        .SERPENTINE(1),
        .USE_RESET_PIN(0),
        .TEST_MODE(0)
    ) DUT (

        .clk(clk),
        .reset_n(reset_n),

        .start_dip_n(start_dip_n),

        .dip_easy_n(dip_easy_n),
        .dip_medium_n(dip_medium_n),
        .dip_hard_n(dip_hard_n),

        .bt(bt),

        .ws_data(ws_data),

        .df_tx(df_tx),
        .df_rx(df_rx)
    );


    always #5 clk = ~clk;

    task wait_cycles;
        input integer cycles;
        integer n;
        begin
            for (n = 0; n < cycles; n = n + 1)
                @(posedge clk);
        end
    endtask

    task press_target;
        integer index;
        begin

            wait(DUT.game_state == 3'd1);

            index = DUT.target_led;

            $display("LED objetivo: %0d", index);

            bt[index] = 1'b0;

            wait_cycles(1050);

            bt[index] = 1'b1;

            wait(DUT.game_state == 3'd3);

            $display("Jugador gana la ronda");
            $display("Marcador jugador: %0d",
                     DUT.player_wins);

            wait(DUT.game_state != 3'd3);

        end
    endtask

    initial begin

        $dumpfile("reaction_game.vcd");
        $dumpvars(0, tb_reaction_game);

        clk = 0;
        reset_n = 1;

        start_dip_n = 1;

        dip_easy_n = 1;
        dip_medium_n = 1;
        dip_hard_n = 1;

        bt = 16'hFFFF;

        df_rx = 1'b1;

        $display("================================");
        $display("INICIANDO TESTBENCH REACTION GAME");
        $display("================================");

        // Esperar inicializacion interna
        wait(DUT.rst_n == 1'b1);

        wait_cycles(10);

        $display("Sistema inicializado correctamente");

        dip_easy_n = 0;

        wait_cycles(10);

        $display("Dificultad seleccionada: FACIL");

        start_dip_n = 0;

        wait_cycles(10);

        start_dip_n = 1;

        wait(DUT.game_state == 3'd1);

        $display("Partida iniciada correctamente");

        for (round_test = 1;
             round_test <= 3;
             round_test = round_test + 1) begin

            $display("");
            $display("================================");
            $display("RONDA %0d", round_test);
            $display("================================");

            press_target;

        end

        wait(DUT.game_state == 3'd5);

        $display("");
        $display("================================");
        $display("PARTIDA FINALIZADA");
        $display("================================");

        $display("Victorias jugador: %0d",
                 DUT.player_wins);

        $display("Victorias bot: %0d",
                 DUT.bot_wins);

        $display("Ganador: %s",
                 DUT.final_player ? "JUGADOR" : "BOT");
        wait(DUT.music_start == 1'b1);

        if (DUT.music_track == 2'd1)
            $display("Audio seleccionado: GANADOR.mp3");
        else
            $display("Audio seleccionado: PERDEDOR.mp3");
        wait(DUT.game_state == 3'd0);

        $display("Regreso al estado IDLE");

        $display("");
        $display("TESTBENCH FINALIZADO CORRECTAMENTE");

        #1000;

        $finish;

    end

    initial begin

        $monitor(
            "Tiempo=%0t | Estado=%0d | Ronda=%0d | "
            "Jugador=%0d | Bot=%0d | LED=%0d",
            $time,
            DUT.game_state,
            DUT.round_cnt,
            DUT.player_wins,
            DUT.bot_wins,
            DUT.target_led
        );

    end
    initial begin
        #100000000;
        $display("ERROR: Timeout de simulacion");
        $finish;
    end

endmodule
