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
