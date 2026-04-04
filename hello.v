
// everything should be going in the montgomery domain
module pollard(
    input clk,
    input reset,
    output reg finish,
    output [63:0] d
);

    // default starting values for the pollard rho
    parameter xs = 2;
    parameter b  = 7;

    // precomputed defaults for r, r', n, n'
    parameter [63:0] n;
    parameter [63:0] np;
    parameter [63:0] r;
    parameter [63:0] rp;
    parameter [63:0] rm1;
    parameter [7:0] rs;

    reg [4:0] state = 0;
    // 1. compute mx = x*x my = y*y
    // 2. compute tx = mx & rm1 * np
    //    same with ty = my & rm1 * np
    // 3. compute tx = tx & rm1 * n
    //    same with ty = ty & rm1 * n
    // 4. x = mx + tx
    //    y = my + ty
    // 5. x = x >> rs
    //    y = y >> rs
    // 6. x = (x + b) & rm1
    //    y = (y + b) & rm1
    // repeat some steps to get y again
    // 7. my = y*y
    // 8. ty = my & rm1 * np
    // 9. ty = ty & rm1 * n
    // 10. y = my + ty;
    // 11. y = y >> rs;
    // 12. y = (y + b) & rm1
    // 13. compare with n and subtract n if necessary from x, y
    // 14. diff = | x - y |
    //     gcd start for gcd(diff, n)
    // 15. wait for gcd stop
    // 16. check the result maybe set some leds accordingly
    //     if it found a proper factor, sent it over uart or sth
    //
    // Optimizations:
    // - it might be possible to optimize a bit using brent? basically compute
    // a product of the diffs and gcd the product? this would require quite
    // a large chunk of memory to be allocated to the diff, which could be
    // good if the whole module can't be parallelized much - there might be
    // a question as to fully utilize memory + LUTs / dsp to achieve max
    // output
    // - one more optimization would be using bit serial montgomery
    // multiplication - basically split the x and y into words of size s to be
    // better picked up by dsp blocks - this might not be that relevant given
    // the small number of dsp blocks on some boards and the need to pipeline/
    // parallelize this by a lot

    reg [127:0] x = xs;
    reg [127:0] y = xs;

    reg [127:0] mx;
    reg [127:0] my;
    reg [127:0] tx;
    reg [127:0] ty;
    reg [63:0] diff;

    reg gcd_start = 0;
    wire gcd_stop;


    // going with the small registers first to test things out, they should be
    // increased according to the data
    reg [63:0] mul0_x;
    reg [63:0] mul0_y;
    wire [127:0] mul0_res;
    reg mul0_start;
    wire mul0_stop;

    reg [63:0] mul1_x;
    reg [63:0] mul1_y;
    wire [127:0] mul1_res;
    reg mul1_start;
    wire mul1_stop;

    gcd# (
        .n(n)
    ) gcd0 (
        .clk(clk),
        .reset(reset),
        .x(diff),
        .start(gcd_start),
        .stop(gcd_stop),
        .res(d)
    );


    // unsure how / if frequency will be affected by having only
    // 2 multiplliers, might need to do one for each operation?
    multiply mul0(
        .clk(clk),
        .reset(reset),
        .x(mul0_x),
        .y(mul0_y),
        .start(mul0_start),
        .stop(mul0_stop),
        .res(mul0_res)
    );

    multiply mul1(
        .clk(clk),
        .reset(reset),
        .x(mul1_x),
        .y(mul1_y),
        .start(mul1_start),
        .stop(mul1_stop),
        .res(mul1_res)
    );

    // NOTE: multiplication is done in a kind of synchronized manner, meaning
    // I will wait for multiplications to finish before moving on, this is an
    // early stage, there probably are some optimizations where you could just
    // start the multiplications and do other stuff before it finishes

    initial begin
        x <= xs;
        y <= xs;
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            // reseting the finish button makes the logic not usable or not
            // synthesizable
            finish <= 0;
            // d <= 1;
            x <= xs;
            y <= xs;
        end
        else begin
            case (state)
                5'b00000: begin
                    // mx <= x*x;
                    // my <= y*y;
                    mul0_x <= x;
                    mul0_y <= x;
                    mul1_x <= y;
                    mul1_y <= y;
                    mul0_start <= 1;
                    mul1_start <= 1;
                    state <= 5'b00001;
                    // state <= state + 1;
                end
                5'b00001: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0;
                    mul1_start <= 0;
                    state <= 5'b00010;
                end
                5'b00010: begin
                    // wait out for the multiplication to end
                    if (mul0_stop && mul1_stop) begin
                        mx <= mul0_res;
                        my <= mul1_res;
                        state <= 5'b00011;
                    end
                end
                5'b00011: begin
                    // tx <= (mx & rm1) * np;
                    // ty <= (my & rm1) * np;
                    mul0_x <= (mx & rm1);
                    mul0_y <= np;
                    mul1_x <= (my & rm1);
                    mul1_y <= np;
                    mul0_start <= 1;
                    mul1_start <= 1;

                    state <= 5'b00100;
                end
                5'b00100: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 5'b00101;
                end
                5'b00101: begin
                    // wait for the multiplication
                    if(mul0_stop && mul1_stop) begin
                        tx <= mul0_res;
                        ty <= mul1_res;
                        state <= 5'b00110;
                    end
                end
                5'b00110: begin
                    // tx <= (tx & rm1) * n;
                    // ty <= (ty & rm1) * n;
                    mul0_x <= (tx & rm1);
                    mul0_y <= n;
                    mul1_x <= (ty & rm1);
                    mul1_y <= n;
                    mul0_start <= 1;
                    mul1_start <= 1;
                    state <= 5'b00111;
                end
                5'b00111: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 5'b01000;
                end
                5'b01000: begin
                    // wait for the multiplication
                    if (mul0_stop && mul1_stop) begin
                        tx <= mul0_res;
                        ty <= mul1_res;
                        state <= 5'b01001;
                    end
                end
                5'b01001: begin
                    x <= mx + tx;
                    y <= my + ty;
                    state <= 5'b01010;
                end
                5'b01010: begin
                    x <= x >> rs;
                    y <= y >> rs;
                    state <= 5'b01011;
                end
                5'b01011: begin
                    x <= (x + b) & rm1;
                    y <= (y + b) & rm1;
                    state <= 5'b01100;
                end
                5'b01100: begin
                    // my <= y*y;
                    mul0_x <= y;
                    mul0_y <= y;
                    mul0_start <= 1;
                    state <= 5'b01101;
                end
                5'b01101: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 5'b01110;
                end
                5'b01110: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        my <= mul0_res;
                        state <= 5'b01111;
                    end
                end
                5'b01111: begin
                    // ty <= (my & rm1) * np;
                    mul0_x <= (my & rm1);
                    mul0_y <= np;
                    mul0_start <= 1;
                    state <= 5'b10000;
                end
                5'b10000: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    state <= 5'b10001;
                end
                5'b10001: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        ty <= mul0_res;
                        state <= 5'b10010;
                    end
                end
                5'b10010: begin
                    // ty <= (ty & rm1) * n;
                    mul0_x <= (ty & rm1);
                    mul0_y <= n;
                    mul0_start <= 1;
                    state <= 5'b10011;
                end
                5'b10011: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    state <= 5'b10100;
                end
                5'b10100: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        ty <= mul0_res;
                        state <= 5'b10101;
                    end
                end
                5'b10101: begin
                    y <= my + ty;
                    state <= 5'b10110;
                end
                5'b10110: begin
                    y <= y >> rs;
                    state <= 5'b10111;
                end
                5'b10111: begin
                    y <= (y + b) & rm1;
                    state <= 5'b11000;
                end
                5'b11000: begin
                    if (x > n) begin
                        x <= x - n;
                    end
                    if (y > n) begin
                        y <= y - n;
                    end
                    state <= 5'b11001;
                end
                5'b11001: begin
                    if (x > y) begin
                        diff <= x - y;
                    end
                    else begin
                        diff <= y - x;
                    end
                    gcd_start <= 1;
                    state <= 5'b11010;
                end
                5'b11010: begin
                    // wait loop for the gcd_stop to go back to 0 from
                    // a previous run
                    gcd_start <= 0;
                    state <= 5'b11011;
                end
                5'b11011: begin
                    if (gcd_stop == 1'b1) begin
                        state <= 5'b11110;
                    end
                end
                5'b11110: begin
                    if (d == 64'b1) begin
                        state <= 5'b00000;
                    end
                    else begin
                        // loop either crashed or found a factor
                        finish <= 1;
                    end
                end
                default: begin
                    state <= 4'b0000;
                    x <= xs;
                    y <= xs;
                end
            endcase
        end
    end

endmodule

module hello(
    input clk,
    input reset,
    output reg [3:0] leds,
    output tx
);

    wire [3:0] leds_rev;
    wire clk_slow;
    wire clk_fast;
    wire locked;
    wire [1:0] clk_out;

    wire p0_end;
    wire [63:0] p0_res;

    wire busy_tx;
    reg start_uart;
    integer s = 0;
    reg [7:0] data_tx;

    localparam [63:0] n = 323;
    localparam [63:0] np = 149;
    localparam [63:0] r = 512;
    localparam [63:0] rp = 94;
    localparam [63:0] rm1 = 511;
    localparam [7:0] rs = 9;

    initial begin
        leds = 4'b1111;
    end

    altpll# (
        // .operation_mode("NO_COMPENSATION"),
        .operation_mode("NORMAL"),
        .inclk0_input_frequency(20000),
        .clk0_multiply_by(1),
        .clk0_divide_by(2),
        .clk1_multiply_by(2),
        .clk1_divide_by(1)
    )PLL(
        .inclk(clk),
        .clk(clk_out),
        .locked(locked),
        .areset(reset)
    );

    send_number senn(
        .clk(clk_out[0]),
        .reset(reste),
        .x(p0_res),
        .start(start_uart),
        .tx(tx)
    );

    pollard# (
        .xs(2),
        .b(7),
        .n(n),
        .np(np),
        .r(r),
        .rp(rp),
        .rm1(rm1),
        .rs(rs)
    ) pollard0(
        .clk(clk_out[1]),
        // .clk(clk),
        .reset(reset),
        .finish(p0_end),
        .d(p0_res)
    );

    always @(posedge clk) begin
        if (reset) begin
            // leds <= data_tx;
            start_uart <= 0;
        end
        if (p0_end) begin
            // leds <= 4'b0000;
            if (p0_res == n) begin
                // loop crashed
                leds <= 4'b0110;
            end
            else begin
                start_uart <= 1;
                leds <= 4'b0000;
            end
        end
    end

    always @* begin
        // leds = ~leds_rev;
    end
endmodule

module test_pollard;

    reg clk = 0;
    wire p0_end;
    wire [63:0] p0_res;
    reg reset;

    always #1 clk = ~clk;

    pollard# (
        .xs(2),
        .b(7),
        .n(323),
        .np(149),
        .r(512),
        .rp(94),
        .rm1(511),
        .rs(9)
    ) poll(
        .clk(clk),
        .reset(reset),
        .finish(p0_end),
        .d(p0_res)
    );


    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, clk, p0_end, poll.mx, poll.mul1.state, poll.mul1_x, poll.mul1_y, poll.my, poll.mul0.state, poll.state, p0_res, poll.mul0_x, poll.mul0_y, poll.gcd0.res, poll.diff, poll.x, poll.y, poll.mul0_res, poll.mul1_res);
        #1 reset = 1;
        #3 reset = 0;

        #500
        $finish(500);
    end

endmodule
