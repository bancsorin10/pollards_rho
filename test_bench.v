

module test_mul;

    reg clk = 0;
    reg start = 0;


    wire [17:0] x;
    wire [5:0] x_addr;
    reg [17:0] x_w;
    wire [17:0] y;
    wire [5:0] y_addr;
    reg [17:0] y_w;
    wire [17:0] res;
    wire [6:0] res_addr;
    wire res_we;
    wire [17:0] res_w;

    reg x_we;
    reg y_we;
    wire stop;

    ram #(
        .addr_width(6),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    ram #(
        .addr_width(6),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    ram #(
        .addr_width(7),
        .data_width(18)
    ) r2 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    multiply m0 (
        .clk(clk),
        .start(start),
        .x_addr(x_addr),
        .x(x),
        .y_addr(y_addr),
        .y(y),
        .res_addr(res_addr),
        .res(res_w),
        .we(res_we),
        .stop(stop)
    );

    always #1 clk = ~clk;

    reg [17:0] res_reg;
    integer i = 0;

    initial begin
        $dumpfile("ram_is_cool.vcd");
        $dumpvars(0, clk, res_reg, m0.res, m0.i, m0.j, m0.k, m0.state, r0.mem, x, y, m0.size, m0.ops);

        for (i = 0; i < 64; i = i + 1) begin
            r0.mem[i] = 0;
            r1.mem[i] = 0;
        end

        r0.mem[0] = 27;
        r1.mem[0] = 29;
        r0.mem[1] = 51;

        #1
        start = 1;
        #10
        start = 0;

        #1000

        #1
        start = 1;
        #10
        start = 0;

        #10000
        $finish(10000);
    end

endmodule

module test_clear;

    reg clk = 0;

    always #1 clk = ~clk;

    wire we;
    wire addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(we),
        .addr(addr),
        .din(x_w),
        .dout(x)
    );

    reg start_clear;
    wire stop_clear;

    clear_ram #(
        .addr_width(1),
        .data_width(18)
    ) c0 (
        .clk(clk),
        .start(start_clear),
        .we(we),
        .stop(stop_clear),
        .addr(addr),
        .x(x_w)
    );

    wire [17:0] mem0 = r0.mem[0];
    wire [17:0] mem1 = r0.mem[1];

    initial begin
        $dumpfile("ram_clear.vcd");
        $dumpvars(0, clk, stop_clear, mem0, mem1);
        r0.mem[0] = 18'h7ab2;
        r0.mem[1] = 18'haabc;
        #4
        start_clear = 1;
        #2
        start_clear = 0;

        #100
        // $dumpall;
        $finish(100);
    end

endmodule

module test_copy;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    reg start_copy;
    wire stop_copy;

    copy_ram #(
        .addr_width(1),
        .addr_size_x(2),
        .data_width(18)
    ) c0 (
        .clk(clk),
        .start(start_copy),
        .we(x_we),
        .x(x_w),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .stop(stop_copy)
    );

    wire [17:0] mem0 = r0.mem[0];
    wire [17:0] mem1 = r0.mem[1];

    initial begin
        $dumpfile("ram_copy.vcd");
        $dumpvars(0, clk, stop_copy, mem0, mem1, start_copy, c0.state, r0.addr, r0.din, r0.we);
        r0.mem[0] = 0;
        r0.mem[1] = 0;
        r1.mem[0] = 18'h7ab2;
        r1.mem[1] = 18'haabc;
        #4
        start_copy = 1;
        #2
        start_copy = 0;

        #100
        // $dumpall;
        $finish(100);
    end

endmodule

module test_shift;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire [5:0] x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(6),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire [5:0] y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(6),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    reg start_shift;
    wire stop_shift;

    shift_ram #(
        .addr_width(6),
        .data_width(18),
        .shift_count(50)
    ) c0 (
        .clk(clk),
        .start(start_shift),
        .we(x_we),
        .x(x_w),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .stop(stop_shift)
    );

    wire [17:0] mem0 = r0.mem[0];
    wire [17:0] mem1 = r0.mem[1];
    integer i;

    initial begin
        $dumpfile("ram_shift.vcd");
        $dumpvars(0, clk, stop_shift, mem0, mem1, start_shift, c0.state, r0.addr, r0.din, r0.we);
        for (i = 0; i < 64; i = i + 1) begin
            r0.mem[i] = 0;
            r1.mem[i] = 0;
        end
        r1.mem[50] = 18'h7ab2;
        r1.mem[51] = 18'haabc;
        #4
        start_shift = 1;
        #2
        start_shift = 0;

        #100
        // $dumpall;
        $finish(100);
    end

endmodule

module test_full_add;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    wire res_addr;
    wire res_we;
    wire [17:0] res;
    wire [17:0] res_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r2 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    reg start_add = 0;
    wire stop_add;

    full_add_ram #(
        .addr_width(1),
        .data_width(18)
    ) a0 (
        .clk(clk),
        .start(start_add),
        .x(x),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .we(res_we),
        .res(res_w),
        .res_addr(res_addr),
        .stop(stop_add)
    );

    wire [17:0] mem0 = r2.mem[0];
    wire [17:0] mem1 = r2.mem[1];

    initial begin
        $dumpfile("ram_full_add.vcd");
        $dumpvars(0, clk, stop_add, mem0, mem1);
        r0.mem[0] = 18'h204a;
        r0.mem[1] = 18'h2014;
        r1.mem[0] = 18'h2222;
        r1.mem[1] = 18'h9907;
        r2.mem[0] = 0;
        r2.mem[1] = 0;

        #2
        start_add = 1;
        #2
        start_add = 0;

        #100
        $finish(100);
    end

endmodule

module test_constant_add;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire res_addr;
    wire res_we;
    wire [17:0] res;
    wire [17:0] res_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    reg start_add = 0;
    wire stop_add;

    constant_add_ram #(
        .addr_width(1),
        .data_width(18),
        .b(17)
    ) a0 (
        .clk(clk),
        .start(start_add),
        .x(x),
        .x_addr(x_addr),
        .we(res_we),
        .res(res_w),
        .res_addr(res_addr),
        .stop(stop_add)
    );

    wire [17:0] mem0 = r1.mem[0];
    wire [17:0] mem1 = r1.mem[1];

    initial begin
        $dumpfile("ram_constant_add.vcd");
        $dumpvars(0, clk, stop_add, mem0, mem1, a0.state);
        r0.mem[0] = 18'h204a;
        r0.mem[1] = 18'h2014;
        r1.mem[0] = 0;
        r1.mem[1] = 0;

        #2
        start_add = 1;
        #2
        start_add = 0;

        #100
        $finish(100);
    end

endmodule

module test_compare;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    reg start;
    wire stop;
    wire big;
    wire eq;

    compare_ram #(
        .addr_width(1),
        .data_width(18)
    ) comp (
        .clk(clk),
        .start(start),
        .x(x),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .stop(stop),
        .big(big),
        .eq(eq)
    );

    wire [17:0] mem0 = r0.mem[0];
    wire [17:0] mem1 = r0.mem[1];
    initial begin
        $dumpfile("ram_compare.vcd");
        $dumpvars(0, clk, mem0, mem1, comp.state, big, eq);
        r0.mem[0] = 18'h204a;
        r0.mem[1] = 18'h2014;
        r1.mem[0] = 0;
        r1.mem[1] = 18'h2014;

        #2
        start = 1;
        #2
        start = 0;
        #50
        r1.mem[0] = 18'h204a;
        #2
        start = 1;
        #2
        start = 0;

        #100
        $finish(100);
    end

endmodule

module test_full_sub;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    wire res_addr;
    wire res_we;
    wire [17:0] res;
    wire [17:0] res_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r2 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    reg start_sub = 0;
    wire stop_sub;

    full_sub_ram #(
        .addr_width(1),
        .data_width(18)
    ) a0 (
        .clk(clk),
        .start(start_sub),
        .x(x),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .we(res_we),
        .res(res_w),
        .res_addr(res_addr),
        .stop(stop_sub)
    );

    wire [17:0] mem0 = r2.mem[0];
    wire [17:0] mem1 = r2.mem[1];

    initial begin
        $dumpfile("ram_full_sub.vcd");
        $dumpvars(0, clk, stop_sub, mem0, mem1);
        r0.mem[0] = 18'h2222;
        r0.mem[1] = 18'h9907;
        r1.mem[0] = 18'h204a;
        r1.mem[1] = 18'h2014;
        r2.mem[0] = 0;
        r2.mem[1] = 0;

        #2
        start_sub = 1;
        #2
        start_sub = 0;

        #100
        $finish(100);
    end

endmodule

module test_gcd_rew;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    wire res_addr;
    wire res_we;
    wire [17:0] res;
    wire [17:0] res_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r2 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    reg start = 0;
    wire dud;
    wire stop;

    gcd_rew #(
        .addr_width(1),
        .addr_size(2),
        .data_width(18)
    ) g0 (
        .clk(clk),
        .start(start),
        .x(x),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .we(res_we),
        .res(res_w),
        .res_addr(res_addr),
        .dud(dud),
        .stop(stop)
    );

    wire [17:0] mem0 = r2.mem[0];
    wire [17:0] mem1 = r2.mem[1];

    wire [17:0] memx = g0.r0.mem[0];
    wire [17:0] memy = g0.r1.mem[0];
    wire [17:0] memx1 = g0.r0.mem[1];
    wire [17:0] memy1 = g0.r1.mem[1];

    initial begin
        $dumpfile("ram_gcd_rew.vcd");
        $dumpvars(0, clk, stop, memx1, memy1, g0.start_sub, g0.xx, g0.yy, mem0, mem1, dud, g0.state, g0.copy0.state, g0.copy1.state, g0.copy0.tmp, g0.copy1.tmp, memx, memy, g0.xx_we, g0.xx_w, x);
        $dumpvars(0, g0.ops);
        $dumpvars(0, g0.comp_eq);
        r0.mem[0] = 18'h2221;
        r0.mem[1] = 18'h9907;
        r1.mem[0] = 18'h2047;
        r1.mem[1] = 18'h2013;
        // r0.mem[0] = 18'd17;
        // r0.mem[1] = 0;
        // r1.mem[0] = 18'd34;
        // r1.mem[1] = 0;
        r2.mem[0] = 0;
        r2.mem[1] = 0;

        #2
        start = 1;
        #2
        start = 0;

        #10000

        r0.mem[0] = 18'h0;
        r0.mem[1] = 18'h9907;
        r1.mem[0] = 18'h9907;
        r1.mem[1] = 0;
        #2
        start = 1;
        #2
        start = 0;
        #10000
        $finish(20000);
    end
endmodule

module test_gcd_rew;

    reg clk = 0;

    always #1 clk = ~clk;

    wire x_we;
    wire x_addr;
    wire [17:0] x;
    wire [17:0] x_w;

    ram #(
        .addr_width(1),
        .data_width(18)
    ) r0 (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire y_we;
    wire y_addr;
    wire [17:0] y;
    wire [17:0] y_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r1 (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    wire res_addr;
    wire res_we;
    wire [17:0] res;
    wire [17:0] res_w;
    ram #(
        .addr_width(1),
        .data_width(18)
    ) r2 (
        .clk(clk),
        .we(res_we),
        .addr(res_addr),
        .din(res_w),
        .dout(res)
    );

    reg start = 0;
    wire dud;
    wire stop;

    gcd_rew #(
        .addr_width(1),
        .addr_size(2),
        .data_width(18)
    ) g0 (
        .clk(clk),
        .start(start),
        .x(x),
        .x_addr(x_addr),
        .y(y),
        .y_addr(y_addr),
        .we(res_we),
        .res(res_w),
        .res_addr(res_addr),
        .dud(dud),
        .stop(stop)
    );

    wire [17:0] mem0 = r2.mem[0];
    wire [17:0] mem1 = r2.mem[1];

    wire [17:0] memx = g0.r0.mem[0];
    wire [17:0] memy = g0.r1.mem[0];
    wire [17:0] memx1 = g0.r0.mem[1];
    wire [17:0] memy1 = g0.r1.mem[1];

    initial begin
        $dumpfile("ram_gcd_rew.vcd");
        $dumpvars(0, clk, stop, memx1, memy1, g0.start_sub, g0.xx, g0.yy, mem0, mem1, dud, g0.state, g0.copy0.state, g0.copy1.state, g0.copy0.tmp, g0.copy1.tmp, memx, memy, g0.xx_we, g0.xx_w, x);
        $dumpvars(0, g0.ops);
        $dumpvars(0, g0.comp_eq);
        r0.mem[0] = 18'h2221;
        r0.mem[1] = 18'h9907;
        r1.mem[0] = 18'h2047;
        r1.mem[1] = 18'h2013;
        // r0.mem[0] = 18'd17;
        // r0.mem[1] = 0;
        // r1.mem[0] = 18'd34;
        // r1.mem[1] = 0;
        r2.mem[0] = 0;
        r2.mem[1] = 0;

        #2
        start = 1;
        #2
        start = 0;

        #10000

        r0.mem[0] = 18'h0;
        r0.mem[1] = 18'h9907;
        r1.mem[0] = 18'h9907;
        r1.mem[1] = 0;
        #2
        start = 1;
        #2
        start = 0;
        #10000
        $finish(20000);
    end
endmodule

module test_pollard;

    reg clk = 0;
    always #1 clk = ~clk;

    reg start = 0;
    wire uart_tx;

    pollard p0(
        .clk(clk),
        .start(start),
        .uart_tx(uart_tx)
    );

    wire [17:0] x = p0.ram_x.mem[0];
    wire [17:0] mx = p0.ram_mx.mem[0];
    wire [17:0] mtx = p0.ram_mtx.mem[0];
    wire [17:0] tx = p0.ram_tx.mem[50];
    wire [17:0] tx0 = p0.ram_tx.mem[0];
    wire [17:0] y = p0.ram_y.mem[0];
    wire [17:0] yy = p0.ram_yy.mem[0];
    wire [17:0] ty = p0.ram_ty.mem[50];
    wire [17:0] ty0 = p0.ram_ty.mem[0];
    wire [17:0] mty = p0.ram_mty.mem[0];
    wire [17:0] my = p0.ram_my.mem[0];
    wire [17:0] np = p0.ram_np0.mem[0];
    initial begin
        $dumpfile("ram_pollard.vcd");
        $dumpvars(0, clk, x, tx, tx0, mx, mtx, np);
        $dumpvars(0, p0.state, p0.ops, p0.stop_m0, p0.stop_m1, p0.stop_add0);
        $dumpvars(0, p0.add0_we, p0.add0.temp, p0.add0_x_w, p0.add0.temp, p0.add0.state);
        $dumpvars(0, y, yy, ty, ty0, my, mty);
        $dumpvars(0, p0.gcd0.state);

        #2
        start = 1;
        #2
        start = 0;

        #5000000
        $finish(5000000);
    end

endmodule
