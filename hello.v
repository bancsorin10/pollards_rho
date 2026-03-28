

module gcd(
    input clk,
    input gcd_start,
    input [127:0] x,
    output reg gcd_stop,
    output reg [127:0] res
);

    parameter [127:0] n;

    reg [1:0] state;
    reg [127:0] xx;

    always @(posedge clk) begin
        if (gcd_start == 0) begin
            gcd_stop <= 0;
            res <= n;
            xx <= x;
        end
        else if (gcd_stop == 0) begin
            if (res > xx) begin
                res <= res - xx;
            end
            else if (xx > res) begin
                xx <= xx - res;
            end
            else begin
                gcd_stop <= 1;
            end
        end
    end
endmodule

// everything should be going in the montgomery domain
module pollard(
    input clk,
    input reset,
    output reg finish,
    output [127:0] d
);

    // default starting values for the pollard rho
    parameter xs = 2;
    parameter b  = 7;

    // precomputed defaults for r, r', n, n'
    parameter [127:0] n;
    parameter [127:0] np;
    parameter [127:0] r;
    parameter [127:0] rp;
    parameter [127:0] rm1;
    parameter [7:0] rs;

    reg [3:0] state;
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

    reg [255:0] x;
    reg [255:0] y;

    reg [255:0] mx;
    reg [255:0] my;
    reg [255:0] tx;
    reg [255:0] ty;
    reg [127:0] diff;

    reg gcd_start = 0;
    wire gcd_stop;

    gcd# (
        .n(n)
    ) gcd0 (
        .clk(clk),
        .x(diff),
        .gcd_start(gcd_start),
        .gcd_stop(gcd_stop),
        .res(d)
    );


    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            // reseting the finish button makes the logic not usable or not
            // synthesizable
            finish <= 0;
            d <= 1;
            x <= xs;
            y <= xs;
        end
        else begin
            case (state)
                4'b0000: begin
                    mx <= x*x;
                    my <= y*y;
                    state <= 4'b0001;
                end
                4'b0001: begin
                    tx <= (mx & rm1) * np;
                    ty <= (my & rm1) * np;
                    state <= 4'b0010;
                end
                4'b0010: begin
                    tx <= (tx & rm1) * n;
                    ty <= (ty & rm1) * n;
                    state <= 4'b0011;
                end
                4'b0011: begin
                    x <= mx + tx;
                    y <= my + ty;
                    state <= 4'b0100;
                end
                4'b0100: begin
                    x <= x >> rs;
                    y <= y >> rs;
                    state <= 4'b0101;
                end
                4'b0101: begin
                    x <= (x + b) & rm1;
                    y <= (y + b) & rm1;
                    state <= 4'b0110;
                end
                4'b0110: begin
                    my <= y*y;
                    state <= 4'b0111;
                end
                4'b0111: begin
                    ty <= (my & rm1) * np;
                    state <= 4'b1000;
                end
                4'b1000: begin
                    ty <= (ty & rm1) * n;
                    state <= 4'b1001;
                end
                4'b1001: begin
                    y <= my + ty;
                    state <= 4'b1010;
                end
                4'b1010: begin
                    y <= y >> rs;
                    state <= 4'b1011;
                end
                4'b1011: begin
                    y <= (y + b) & rm1;
                    state <= 4'b1100;
                end
                4'b1100: begin
                    if (x > n) begin
                        x <= x - n;
                    end
                    if (y > n) begin
                        y <= y - n;
                    end
                    state <= 4'b1101;
                end
                4'b1101: begin
                    if (x > y) begin
                        diff <= x - y;
                    end
                    else begin
                        diff <= y - x;
                    end
                    gcd_start <= 1'b1;
                    state <= 4'b1110;
                end
                4'b1110: begin
                    if (gcd_stop == 1'b1) begin
                        gcd_start <= 1'b0;
                        state <= 4'b1111;
                    end
                end
                4'b1111: begin
                    if (d == 1'b1) begin
                        state <= 4'b0000;
                    end
                    else begin
                        // loop either crashed or found a factor
                        finish <= 1'b1;
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
    wire [127:0] p0_res;

    wire busy_tx;
    reg start_uart;
    integer s = 0;
    reg [7:0] data_tx;

    localparam [127:0] n = 323;
    localparam [127:0] np = 149;
    localparam [127:0] r = 512;
    localparam [127:0] rp = 94;
    localparam [127:0] rm1 = 511;
    localparam [7:0] rs = 9;

    altpll# (
        // .operation_mode("NO_COMPENSATION"),
        .operation_mode("NORMAL"),
        .inclk0_input_frequency(20000),
        .clk0_multiply_by(1),
        .clk0_divide_by(2),
        .clk1_multiply_by(8),
        .clk1_divide_by(1)
    )PLL(
        .inclk(clk),
        .clk(clk_out),
        .locked(locked),
        .areset(reset)
    );

    uart_transmit uart0(
        .clk(clk_out[0]),
        .reset(reset),
        .data(data_tx),
        .start(start_uart),
        .tx(tx),
        .busy(busy_tx)
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
        .reset(reset),
        .finish(p0_end),
        .d(p0_res)
    );

    always @(posedge clk) begin
        if (reset) begin
            // leds <= data_tx;
            start_uart <= 0;
        end
        else if (busy_tx) begin
            start_uart <= 0;
        end
        else if (s < 50_000_000) begin
            s <= s + 1;
        end
        else begin
            s <= 0;
            // leds <= leds -1;
            data_tx <= p0_res;
            start_uart <= 1;
        end
    end

    always @* begin
        if (p0_end == 1) begin
            leds = 4'b0000;
        end
        else begin
            leds = 4'b1111;
        end
        // leds = ~leds_rev;
    end

endmodule
