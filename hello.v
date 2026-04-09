
// everything should be going in the montgomery domain
module pollard(
    input clk,
    input reset,
    output reg finish,
    output [1023:0] d
);

    // default starting values for the pollard rho
    parameter [63:0] xs = 2;
    parameter [63:0] b  = 7;

    // precomputed defaults for r, r', n, n'
    parameter [1023:0] n;
    parameter [1023:0] np;
    parameter [1023:0] r;
    parameter [1023:0] rp;
    parameter [1023:0] rm1;
    parameter [15:0] rs;

    reg [5:0] state = 0;
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

    reg [2047:0] x = xs;
    reg [2047:0] y = xs;

    reg [2047:0] mx;
    reg [2047:0] my;
    reg [2047:0] tx;
    reg [2047:0] ty;
    reg [1023:0] diff;

    reg gcd_start = 0;
    wire gcd_stop;


    // going with the small registers first to test things out, they should be
    // increased according to the data
    reg [1023:0] mul0_x;
    reg [1023:0] mul0_y;
    wire [2047:0] mul0_res;
    reg mul0_start;
    wire mul0_stop;

    reg [1023:0] mul1_x;
    reg [1023:0] mul1_y;
    wire [2047:0] mul1_res;
    reg mul1_start;
    wire mul1_stop;

    reg [2043:0] add0_x;
    reg [2043:0] add0_y;
    wire [2043:0] add0_res;
    reg add0_start;
    wire add0_stop;
    reg [2043:0] add1_x;
    reg [2043:0] add1_y;
    wire [2043:0] add1_res;
    reg add1_start;
    wire add1_stop;

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

    add add0(
        .clk(clk),
        .reset(reset),
        .x(add0_x),
        .y(add0_y),
        .start(add0_start),
        .stop(add0_stop),
        .res(add0_res)
    );

    add add1(
        .clk(clk),
        .reset(reset),
        .x(add1_x),
        .y(add1_y),
        .start(add1_start),
        .stop(add1_stop),
        .res(add1_res)
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
                6'b000000: begin
                    // mx <= x*x;
                    // my <= y*y;
                    mul0_x <= x;
                    mul0_y <= x;
                    mul1_x <= y;
                    mul1_y <= y;
                    mul0_start <= 1;
                    mul1_start <= 1;
                    state <= 6'b000001;
                    // state <= state + 1;
                end
                6'b000001: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0;
                    mul1_start <= 0;
                    state <= 6'b000010;
                end
                6'b000010: begin
                    // wait out for the multiplication to end
                    if (mul0_stop && mul1_stop) begin
                        mx <= mul0_res;
                        my <= mul1_res;
                        state <= 6'b000011;
                    end
                end
                6'b000011: begin
                    // tx <= (mx & rm1) * np;
                    // ty <= (my & rm1) * np;
                    mul0_x <= (mx & rm1);
                    mul0_y <= np;
                    mul1_x <= (my & rm1);
                    mul1_y <= np;
                    mul0_start <= 1;
                    mul1_start <= 1;

                    state <= 6'b000100;
                end
                6'b000100: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 6'b000101;
                end
                6'b000101: begin
                    // wait for the multiplication
                    if(mul0_stop && mul1_stop) begin
                        tx <= mul0_res;
                        ty <= mul1_res;
                        state <= 6'b000110;
                    end
                end
                6'b000110: begin
                    // tx <= (tx & rm1) * n;
                    // ty <= (ty & rm1) * n;
                    mul0_x <= (tx & rm1);
                    mul0_y <= n;
                    mul1_x <= (ty & rm1);
                    mul1_y <= n;
                    mul0_start <= 1;
                    mul1_start <= 1;
                    state <= 6'b000111;
                end
                6'b000111: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 6'b001000;
                end
                6'b001000: begin
                    // wait for the multiplication
                    if (mul0_stop && mul1_stop) begin
                        tx <= mul0_res;
                        ty <= mul1_res;
                        state <= 6'b001001;
                    end
                end
                6'b001001: begin
                    // x <= mx + tx;
                    // y <= my + ty;
                    add0_x <= mx;
                    add0_y <= tx;
                    add0_start <= 1;
                    add1_x <= my;
                    add1_y <= ty;
                    add1_start <= 1;
                    state <= 6'b001010;
                end
                6'b001010: begin
                    // waiting cycle
                    add0_start <= 0;
                    add1_start <= 0;
                    state <= 6'b001011;
                end
                6'b001011: begin
                    if (add0_stop && add1_stop) begin
                        x <= add0_res;
                        y <= add1_res;
                        state <= 6'b001100;
                    end
                end

                /////
                6'b001100: begin
                    x <= x >> rs;
                    y <= y >> rs;
                    state <= 6'b001101;
                end
                6'b001101: begin
                    x <= (x[1023:0] + b) & rm1;
                    y <= (y[1023:0] + b) & rm1;
                    state <= 6'b001110;
                end
                6'b001110: begin
                    if (x > n) begin
                        x <= x[1023:0] - n;
                    end
                    if (y > n) begin
                        y <= y[1023:0] - n;
                    end
                    state <= 6'b001111;

                end
                6'b001111: begin
                    // my <= y*y;
                    mul0_x <= y;
                    mul0_y <= y;
                    mul0_start <= 1;
                    state <= 6'b010000;
                end
                6'b010000: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    mul1_start <= 0; // one  cycle should be enough
                    state <= 6'b010001;
                end
                6'b010001: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        my <= mul0_res;
                        state <= 6'b010010;
                    end
                end
                6'b010010: begin
                    // ty <= (my & rm1) * np;
                    mul0_x <= (my & rm1);
                    mul0_y <= np;
                    mul0_start <= 1;
                    state <= 6'b010011;
                end
                6'b010011: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    state <= 6'b010100;
                end
                6'b010100: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        ty <= mul0_res;
                        state <= 6'b010101;
                    end
                end
                6'b010101: begin
                    // ty <= (ty & rm1) * n;
                    mul0_x <= (ty & rm1);
                    mul0_y <= n;
                    mul0_start <= 1;
                    state <= 6'b010110;
                end
                6'b010110: begin
                    // skip a clock cycle for when the multiplication is
                    // started previous stop values are still in place from
                    // the previous one
                    mul0_start <= 0; // one  cycle should be enough
                    state <= 6'b010111;
                end
                6'b010111: begin
                    // wait for the multiplication
                    if (mul0_stop) begin
                        ty <= mul0_res;
                        state <= 6'b011000;
                    end
                end
                6'b011000: begin
                    y <= my + ty;
                    state <= 6'b011001;
                end
                6'b011001: begin
                    y <= y >> rs;
                    state <= 6'b011010;
                end
                6'b011010: begin
                    y <= (y + b) & rm1;
                    state <= 6'b011011;
                end
                6'b011011: begin
                    if (y > n) begin
                        y <= y[1023:0] - n;
                    end
                    state <= 6'b011100;
                end
                6'b011100: begin
                    if (x > y) begin
                        diff <= x[1023:0] - y[1023:0];
                    end
                    else begin
                        diff <= y[1023:0] - x[1023:0];
                    end
                    gcd_start <= 1;
                    state <= 6'b011101;
                end
                6'b011101: begin
                    // wait loop for the gcd_stop to go back to 0 from
                    // a previous run
                    gcd_start <= 0;
                    state <= 6'b011110;
                end
                6'b011110: begin
                    if (gcd_stop == 1'b1) begin
                        state <= 6'b011111;
                    end
                end
                6'b011111: begin
                    if (d == 64'b1) begin
                        state <= 6'b000000;
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
    wire [1023:0] p0_res;

    wire busy_tx;
    reg start_uart;
    integer s = 0;
    reg [7:0] data_tx;

    // localparam [63:0] n = 323;
    // localparam [63:0] np = 149;
    // localparam [63:0] r = 512;
    // localparam [63:0] rp = 94;
    // localparam [63:0] rm1 = 511;
    // localparam [7:0] rs = 9;

    localparam [1023:0] n = 1024'd412023436986659543855531365332575948179811699844327982845455626433876445565248426198098870423161841879261420247188869492560931776375033421130982397485150944909106910269861031862704114880866970564902903653658867433731720813104105190864254793282601391257624033946373269391;
    localparam [1023:0] np = 1024'd638293895258188475132920891728787677695565547652228734484748655326023714263142647020719820143831500805693551499322361418387782419805549905623637897472773835746562303213135508185464159845913836315651623175125320386698964114659086145214859925850379825673180254744091945105;
    localparam [1023:0] r = 1024'd2113178124542660985409359139666066426075389304144486088511842836106695610226899437897669023550628751578697579973028514715529390238010742149002155913851758307633546735996020336674926070705705764212096931632844753616592113171006246955353587595068145905958154323590951993344;
    localparam [1023:0] rp = 1024'd124453325291164959107397083496404142069443042106972149463279878044770345091600400269378452788345699130937306625988193470230890121767778286664735372211997510874309219914452139565668017271632391284341227250556383955834056737608778835215883646062516754378593595228890760099;
    localparam [1023:0] rm1 = 1024'd2113178124542660985409359139666066426075389304144486088511842836106695610226899437897669023550628751578697579973028514715529390238010742149002155913851758307633546735996020336674926070705705764212096931632844753616592113171006246955353587595068145905958154323590951993343;
    localparam [15:0] rs = 898;

    initial begin
        leds = 4'b1111;
    end

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
    wire [1023:0] p0_res;
    reg reset;

    localparam [1023:0] n = 1024'd412023436986659543855531365332575948179811699844327982845455626433876445565248426198098870423161841879261420247188869492560931776375033421130982397485150944909106910269861031862704114880866970564902903653658867433731720813104105190864254793282601391257624033946373269391;
    localparam [1023:0] np = 1024'd638293895258188475132920891728787677695565547652228734484748655326023714263142647020719820143831500805693551499322361418387782419805549905623637897472773835746562303213135508185464159845913836315651623175125320386698964114659086145214859925850379825673180254744091945105;
    localparam [1023:0] r = 1024'd2113178124542660985409359139666066426075389304144486088511842836106695610226899437897669023550628751578697579973028514715529390238010742149002155913851758307633546735996020336674926070705705764212096931632844753616592113171006246955353587595068145905958154323590951993344;
    localparam [1023:0] rp = 1024'd124453325291164959107397083496404142069443042106972149463279878044770345091600400269378452788345699130937306625988193470230890121767778286664735372211997510874309219914452139565668017271632391284341227250556383955834056737608778835215883646062516754378593595228890760099;
    localparam [1023:0] rm1 = 1024'd2113178124542660985409359139666066426075389304144486088511842836106695610226899437897669023550628751578697579973028514715529390238010742149002155913851758307633546735996020336674926070705705764212096931632844753616592113171006246955353587595068145905958154323590951993343;
    localparam [15:0] rs = 898;


    always #1 clk = ~clk;

    pollard# (
        .xs(64'd7420147241704),
        .b(64'd170200279),
        .n(n),
        .np(np),
        .r(r),
        .rp(rp),
        .rm1(rm1),
        .rs(rs)
    ) poll(
        .clk(clk),
        .reset(reset),
        .finish(p0_end),
        .d(p0_res)
    );


    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, clk, p0_end, poll.mul0.inter, poll.add0.temp, poll.add0_x, poll.add0_y, poll.add0_res, poll.gcd_start, poll.gcd0.shift, poll.gcd0.state, poll.gcd0.xs, poll.tx, poll.ty, poll.gcd0.ys, poll.mx, poll.mul1.state, poll.mul0.stop, poll.mul1_x, poll.mul1_y, poll.my, poll.mul0.state, poll.state, p0_res, poll.mul0_x, poll.mul0_y, poll.gcd0.res, poll.gcd_stop, poll.gcd0.xx, poll.gcd0.yy, poll.diff, poll.x, poll.y, poll.mul0_res, poll.mul1_res);
        // #1 reset = 1;
        // #3 reset = 0;

        #10_000_000
        $finish(10_000_000);
    end

endmodule
