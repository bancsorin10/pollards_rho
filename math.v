
// thinking if I should add an `ok` input to skip the waiting for the first
// edge to not stop instantly?

// to do -- fix gcd ? or not in simulation diff is just not computed
module gcd(
    input clk,
    input reset,
    input start,
    input [1023:0] x,
    output reg stop,
    output reg [1023:0] res
);
    // the gcd alg could be improved a lot by just following known algorithms
    // this one just does subtractions because I was thinking it'll just
    // reduce the area
    //
    // really doing it bad introducing extra stuff just to be able to compare
    // things because of the fitter not being able to do anaything about that
    // due to numbers being too large

    parameter [1023:0] n;

    // reg state = 0;
    reg [1:0] state = 0;
    reg [1023:0] xx;
    reg [1023:0] yy;

    reg [63:0] xs;
    reg [63:0] ys;
    reg [15:0] shift;

    always @(posedge clk) begin
        if (reset) begin
            xx <= 0;
            state <= 0;
            stop <= 0;
            res <= 1;
            yy <= 0;
        end
        else begin
            case (state)
                2'b00: begin
                    if ((start) && ((x & 1) == 0)) begin
                        // early exit
                        stop <= 1;
                        res <= 1;
                    end
                    else if (start) begin
                        stop <= 0;
                        res <= 1;
                        yy <= n;
                        xx <= x;
                        state <= 2'b01;
                        shift <= 960;
                    end
                end
                2'b01: begin
                    xs <= xx >> shift;
                    ys <= yy >> shift;
                    state <= 2'b10;
                end
                2'b10: begin
                    if (xs > ys) begin
                        state <= 4'b0001;
                        xx <= xx - yy;
                        shift <= 960;
                        state <= 2'b01;
                    end
                    else if (xs < ys) begin
                        state <= 2'b01;
yy <= yy - xx;
                        // TODO: this should be a variable type of shift
                        // starter, if 00 reduce the shift where you reset
                        // might not be as simple as that tho, as there could
                        // be a comparison of 1000_0000 with 1000_0000 where
                        // the first word is equal and the second one is also
                        // equal but zero, I can't just decrease the def_shift
                        // on 0000
                        shift <= 960;
                        state <= 2'b01;
                    end
                    else begin
                        state <= 2'b11;
                    end
                end
                2'b11: begin
                    if (shift == 0) begin
                        res <= xx;
                        stop <= 1;
                        state <= 2'b00;
                    end
                    else begin
                        shift <= shift - 64;
                        state <= 2'b01;
                    end
                end
                default: begin
                    state <= 2'b00;
                    stop <= 0;
                    xx <= 0;
                    res <= 1;
                end
            endcase
        end
    end
endmodule

// not really needed because we don't really do addition per se, we just
// change some bits so `|` is enough
// but for mx+tx it might be necessary
module add(
    input clk,
    input reset,
    input start,
    input [2043:0] x,
    input [2043:0] y,
    output reg stop,
    output reg [2043:0] res
);

    reg [3:0] state = 0;

    reg [1:0] c = 0;
    reg [513:0] temp = 0;


    // just do 4 additions temp = x+y; hardcode [511:0], [1023:512] ...
    // don't care about the last carry, result shouldn't exceed the 2043
    always @(posedge clk) begin
        if (reset) begin
            res <= 0;
            state <= 4'b0000;
            temp <= 0;
            c <= 0;
        end
        else begin
        case (state)
            4'b0000: begin
                if (start) begin
                    temp <= x[511:0] + y[511:0];
                    stop <= 0;
                    state <= 4'b0001;
                end
            end
            4'b0001: begin
                c <= temp[513:512];
                res[511:0] <= temp[511:0];
                temp <= x[1023:512] + y[1023:512];
                state <= 4'b0010;
            end
            4'b0010: begin
                temp <= temp + c;
                state <= 4'b0011;
            end
            4'b0011: begin
                res[1023:512] <= temp[511:0];
                c <= temp[513:512];
                temp <= x[1535:1024] + y[1535:1024];
                state <= 4'b0100;
            end
            4'b0100: begin
                temp <= temp + c;
                state <= 4'b0101;
            end
            4'b0101: begin
                res[1535:1024] <= temp[511:0];
                c <= temp[513:512];
                temp <= x[2043:1536] + y[2043:1536];
                state <= 4'b0110;
            end
            4'b0110: begin
                temp <= temp + c;
                state <= 4'b0111;
            end
            4'b0111: begin
                res[2043:1536] <= temp[511:0];
                stop <= 1;
                state <= 4'b0000;
            end
            default: begin
                state <= 4'b0000;
                stop <= 0;
                res <= 0;
                temp <= 0;
            end
        endcase
        end
    end

endmodule



module multiply(
    input clk,
    input reset,
    input [1023:0] x,
    input [1023:0] y,
    input start,
    output reg stop,
    // output reg [3:0] leds,
    output reg [2047:0] res
);

    reg [3:0] state;
    reg [17:0] xx;
    reg [17:0] yy;
    reg [35:0] temp;
    reg [7:0] size;
    reg [1024:0] sizer;
    reg [7:0] ops;
    reg [7:0] i;
    reg [7:0] j;
    reg [15:0] ii;
    reg [15:0] jj;
    reg [7:0] k;

    reg [2047:0] tmp_res;

    localparam [4:0] word_size = 18;
    localparam [17:0] word_mask = 18'h3ffff;
    // reg [word_size - 1:0] carry;

    reg [17:0] masked;
    // reg [2047:0] inter;
    reg [256:0] inter;
    // reg [23:0] carry;
    reg [15:0] shifter;


    reg [2:0] ls; // loop step

    always @(posedge clk) begin
        if (reset) begin
            // res <= 0;
            tmp_res <= 0;
            state <= 0;
            size <= 0;
            sizer <= 1;
            stop <= 0;
            i <= 0;
            inter <= 0;
            shifter <= 0;
            masked <= 0;
            ls <= 0;
        end
        else begin
            // leds <= ops;
            case (state)
                4'b0000: begin
                    if (start == 1) begin
                        // xx <= x;
                        // yy <= y;
                        // res <= 0;
                        tmp_res <= 0;
                        stop <= 0;
                        state <= 4'b0001;
                        sizer <= 1;
                        masked <= 0;
                        size <= 0;
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
                        state <= 4'b0000;
                        // inter <= inter << shifter;
                        res <= tmp_res | (inter << shifter);
                        stop <= 1;
                        inter <= 0;
                    end
                    else begin
                        if ((i + 1) > size) begin
                            j <= i + 1 - size;
                        end
                        else begin
                            j <= 0;
                        end
                        state <= 4'b0011;
                    end
                end
                4'b0011: begin
                    if (((i < size) && (j > i)) || ((i >= size) && (j == size))) begin
                        i <= i + 1;
                        inter <= inter >> word_size;
                        // res <= res + ((inter&word_mask) << shifter);
                        // state <= 4'b0010;
                        masked <= inter;
                        state <= 4'b0100;
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
                        else if (ls == 3) begin
                            temp <= xx * yy;
                            ls <= 4;
                        end
                        else begin
                            inter <= inter + temp;
                            j <= j + 1;
                            ls <= 0;
                        end
                    end
                end
                4'b0100: begin
                    // stop <= 1;
                    state <= 4'b0010;
                    // inter <= 0;
                    tmp_res <= tmp_res | (masked << shifter);
                    shifter <= shifter + word_size;
                    // res <= res + inter;
                end
                default: begin
                    xx <= 0;
                    yy <= 0;
                    res <= 0;
                    masked <= 0;
                    tmp_res <= 0;
                    state <= 4'b0000;
                    size <= 1;
                    stop <= 0;
                end
            endcase
        end
    end
endmodule
