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
