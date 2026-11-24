module tb_dfplayer_uart;

    parameter CLK_FREQ  = 96000;
    parameter BAUD_RATE = 9600;

    localparam BIT_TIME_NS = (CLK_FREQ / BAUD_RATE) * 10 * 10;

    reg        clk;
    reg        reset_n;
    reg        play_start;
    reg  [1:0] track_number;

    wire       df_tx;
    reg        df_rx;

    integer    i;
    integer    errors;
    reg  [7:0] received_byte;

    dfplayer_uart #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) DUT (
        .clk          (clk),
        .reset_n      (reset_n),
        .play_start   (play_start),
        .track_number (track_number),
        .df_tx        (df_tx),
        .df_rx        (df_rx)
    );

    always #5 clk = ~clk;

    function [7:0] expected_byte;
        input integer index;
        input integer track;
        begin
            case (index)
                0:       expected_byte = 8'h7E;
                1:       expected_byte = 8'hFF;
                2:       expected_byte = 8'h06;
                3:       expected_byte = 8'h12;
                4:       expected_byte = 8'h00;
                5:       expected_byte = 8'h00;
                6:       expected_byte = (track == 1) ? 8'h01 : 8'h02;
                7:       expected_byte = 8'hFE;
                8:       expected_byte = (track == 1) ? 8'hE8 : 8'hE7;
                9:       expected_byte = 8'hEF;
                default: expected_byte = 8'h00;
            endcase
        end
    endfunction

    task receive_uart_byte;
        integer bit_number;
        begin
            // Esperar bit de inicio
            @(negedge df_tx);

            #(BIT_TIME_NS * 3 / 2);

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                received_byte[bit_number] = df_tx;
                #(BIT_TIME_NS);
            end

            if (df_tx !== 1'b1) begin
                $display("ERROR: Bit de parada incorrecto");
                errors = errors + 1;
            end

            $display("Byte recibido: %02h", received_byte);
        end
    endtas

    task check_packet;
        input integer track;
        reg [7:0] expected;
        integer index;
        begi
            $display("");
           if (track == 1)
                $display("VERIFICANDO GANADOR.mp3");
            else
                $display("VERIFICANDO PERDEDOR.mp3");

            for (index = 0; index < 10; index = index + 1) begin
                receive_uart_byte;
                expected = expected_byte(index, track);

                if (received_byte !== expected) begin
                    $display("ERROR Byte %0d: Esperado=%02h Recibido=%02h", index, expected, received_byte);
                    errors = errors + 1;
                end else begin
                    $display("BYTE %0d CORRECTO", index);
                end
            end
        end
    endtask

    task send_track;
        input [1:0] track;
        begin
            track_number = track;
            @(negedge clk);
            play_start = 1'b1;
            @(negedge clk);
            play_start = 1'b0;

            check_packet(track);

            wait (DUT.uart_state == 2'd0);
            repeat (5) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("dfplayer_uart.vcd");
        $dumpvars(0, tb_dfplayer_uart);

        clk          = 0;
        reset_n      = 0;
        play_start   = 0;
        track_number = 0;
        df_rx        = 1'b1;
        errors       = 0;

        $display("TESTBENCH DFPLAYER UART");
 
        repeat (10) @(posedge clk);
        reset_n = 1;
        repeat (10) @(posedge clk);

        if (df_tx !== 1'b1) begin
            $display("ERROR: UART no esta en reposo");
            errors = errors + 1;
        end else begin
            $display("UART inicializado correctamente");
        end

        send_track(2'd1);

        send_track(2'd2);

        $display("");
        if (errors == 0) begin
            $display("TODAS LAS PRUEBAS CORRECTAS");
        end else begin
            $display("SIMULACION CON ERRORES: %0d", errors);
        end

        #1000;
        $finish;
    end

    initial begin
        #1000000;
        $display("ERROR: Timeout UART");
        $finish;
    end

endmodule
