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

    // PARAMETROS WS2812B
    localparam T_BIT        = 34;
    localparam T0H          = 10;
    localparam T1H          = 22;
    localparam RESET_CYCLES = CLK_FREQ / 12500;
