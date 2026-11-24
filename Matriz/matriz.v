    function [23:0] rgb;

        input [7:0] r, g, b;

        begin

            if (COLOR_GRB)
                rgb = {g, r, b};
            else
                rgb = {r, g, b};

        end
    endfunction

    // SELECCION Y UBICACION DE LEDS

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
