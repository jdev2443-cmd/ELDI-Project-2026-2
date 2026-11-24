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
