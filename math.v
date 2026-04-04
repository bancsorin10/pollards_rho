
// thinking if I should add an `ok` input to skip the waiting for the first
// edge to not stop instantly?

module gcd(
    input clk,
    input reset,
    input start,
    input [63:0] x,
    output reg stop,
    output reg [63:0] res
);

    parameter [63:0] n;

    reg state = 0;
    reg [63:0] xx;

    // this should move to the state machine approach used for the other
    // modules, to hold the gcd_start only for one cycle and be consistent
    // with things like multiply
    // always @(posedge clk) begin
    //     if (gcd_start == 0) begin
    //         gcd_stop <= 0;
    //         res <= n;
    //         xx <= x;
    //     end
    //     else if (gcd_stop == 0) begin
    //         if (res > xx) begin
    //             res <= res - xx;
    //         end
    //         else if (xx > res) begin
    //             xx <= xx - res;
    //         end
    //         else begin
    //             gcd_stop <= 1;
    //         end
    //     end
    // end

    always @(posedge clk) begin
        if (reset) begin
            xx <= 0;
            state <= 0;
            stop <= 0;
            res <= 0;
        end
        else begin
            case (state)
                0: begin
                    if (start) begin
                        stop <= 0;
                        res <= n;
                        xx <= x;
                        state <= 2'b01;
                    end
                end
                1: begin
                    if (res > xx) begin
                        res <= res - xx;
                    end
                    else if (xx > res) begin
                        xx <= xx - res;
                    end
                    else begin
                        stop <= 1;
                        state <= 0;
                    end
                end
                default: begin
                    state <= 0;
                    stop <= 0;
                    xx <= 0;
                    res <= 0;
                end
            endcase
        end
    end
endmodule


module multiply(
    input clk,
    input reset,
    input [63:0] x,
    input [63:0] y,
    input start,
    output reg stop,
    output reg [127:0] res
);

    reg [3:0] state;
    reg [17:0] xx;
    reg [17:0] yy;
    reg [63:0] xxx;
    reg [63:0] yyy;
    reg [7:0] size;
    reg [83:0] sizer;
    reg [3:0] ops;
    reg [3:0] i;
    reg [3:0] j;
    reg [7:0] ii;
    reg [7:0] jj;
    reg [3:0] k;

    localparam [4:0] word_size = 18;
    localparam [17:0] word_mask = 18'h3ffff;
    // reg [word_size - 1:0] carry;

    reg [37:0] inter;
    reg [23:0] carry;
    reg [15:0] shifter;

    reg [2:0] ls; // loop step

    always @(posedge clk) begin
        if (reset) begin
            res <= 0;
            state <= 0;
            size <= 0;
            sizer <= 1;
            stop <= 0;
            carry <= 0;
            i <= 0;
            inter <= 0;
            shifter <= 0;
            ls <= 0;
        end
        else begin
            case (state)
                4'b0000: begin
                    if (start == 1) begin
                        // xx <= x;
                        // yy <= y;
                        res <= 0;
                        state <= 4'b0001;
                        stop <= 0;
                        sizer <= 1;
                        size <= 0;
                        carry <= 0;
                        shifter <= 0;
                        inter <= 0;
                        i <= 0;
                        ls <= 0;
                    end
                end
                4'b0001: begin
                    if ((sizer < x) || (sizer < y)) begin
                        sizer <= sizer << word_size;
                        size <= size + 1;
                    end
                    else begin
                        ops <= (size << 1) - 1;
                        state <= 4'b0010;
                    end
                end
                4'b0010: begin
                    if (i == ops) begin
                        inter <= 0;
                        // state <= 4'b0100; // get out of the for loop
                        // i <= 0;
                        state <= 4'b0000;
                        stop <= 1;
                        res <= res + (inter << ops);
                    end
                    else begin
                        if ((i + 1) > size) begin
                        // if ((i + 1) > ops) begin
                            j <= i + 1 - size;
                        end
                        else begin
                            j <= 0;
                        end
                        state <= 4'b0011;
                    end
                end
                4'b0011: begin
                    if (((i < size) && (j == i + 1)) || ((i >= size) && (j == size))) begin
                        i <= i + 1;
                        shifter <= shifter + word_size;
                        inter <= inter >> word_size;
                        res <= res + ((inter&word_mask) << shifter);
                        state <= 4'b0010;
                    end
                    else begin
                        // should somehow achive inter += x[j] * y[i-j]
                        // note: this is wrong should be x[j*word +: word]
                        // * y[(i-j)*word +: word]
                        // but the [j +: word] doesn't seem to be working?
                        if (ls == 0) begin
                            ls <= 1;
                            k <= i - j;
                        end
                        else if (ls == 1) begin
                            ii <= j * word_size;
                            jj <= k * word_size;
                            ls <= 2;
                        end
                        else if (ls == 2) begin
                            xx <= x >> ii;
                            yy <= y >> jj;
                            ls <= 3;
                        end
                        else begin
                            inter <= inter + xx * yy;
                            j <= j + 1;
                            ls <= 0;
                        end
                    end
                end
                default: begin
                    xx <= 0;
                    yy <= 0;
                    res <= 1;
                    state <= 4'b0000;
                    size <= 1;
                    stop <= 0;
                    // carry <= 0;
                end
            endcase
        end
    end
endmodule
