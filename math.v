
module multiply #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    // x ram block
    input [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,

    // y ram block
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    // res ram block,
    output reg [data_width-1:0] res,
    output reg [addr_width:0] res_addr,
    output reg we,

    output reg stop
);

    // idea is to use ram blocks for storing the large numbers and results
    // - the chip can't do ram operations directly, the values have to be
    // stored in a register first
    // - 18 bit size due to the dsp being 18x18 as well
    // - ram can't be passed directly in the inputs so it has to be done via
    // the top module
    // - getting the value from the ram is done by passing the desired address
    // to the x/y_addr -- consider the following cycles
    // 1. x_addr changes on first cycle
    // 2. top module sees the change and updates x to the value in ram
    // 3. x is finally available in this module so there is a dead cycle that
    // needs to be waited out
    //
    // Always multiplying numbers inside the domain, since the setup for the
    // R is 898 bits the highest size x can be is that meaning that finding
    // the size we have to go down from the 50th (x[49]) to check for how many
    // multiplications we have to do
    //
    // using a MUX in order to reuse the multiplier module will lead to yet
    // another latency cycle between 1 and 2, where the top module makes the
    // request towards the ram module

    localparam addr_size = 1 << addr_width;

    reg [3:0] state;
    reg [(data_width<<1)-1:0] temp;
    reg [7:0] size;
    reg [7:0] ops;
    reg [7:0] i;
    reg [7:0] j;
    reg [15:0] ii;
    reg [15:0] jj;
    reg [7:0] k;


    // reg [255:0] inter;
    reg [99:0] inter;

    always @(posedge clk) begin
        case (state)
            4'b0000: begin
                if (start == 1) begin
                    stop <= 0;
                    state <= 4'b0001;
                    size <= addr_size - 1;
                    inter <= 0;
                    i <= 0;
                    we <= 0;
                end
            end

            // find size and amount of multiplications needed
            4'b0001: begin
                x_addr <= size;
                y_addr <= size;
                state <= 4'b0010;
            end
            4'b0010: begin
                // wait for ram read
                state <= 4'b0011;
            end
            4'b0011: begin
                if ((|x) || (|y)) begin
                    size <= size + 1;
                    state <= 4'b0100;
                end
                else begin
                    // assume this never gets to 0, no need for extra logic
                    size <= size - 1;
                    state <= 4'b0001;
                end
            end
            4'b0100: begin
                ops <= (size << 1) - 1;
                state <= 4'b0101;
            end

            // start the multiplication cycle
            4'b0101: begin
                if (i == ops) begin
                    // idk, max carry shouldn't execeed 26 bits or sth like
                    // that -- doing 2 assignments here should be enough
                    we <= 1;
                    res <= inter[17:0];
                    res_addr <= i; // double measures, I believe this is i already
                    inter <= inter >> data_width;
                    i <= i + 1;
                    state <= 4'b1100;
                end
                else begin
                    if ((i + 1) > size) begin
                        j <= i + 1 - size;
                    end
                    else begin
                        j <= 0;
                    end
                    state <= 4'b0110;
                end
            end
            4'b0110: begin
                if (((i < size) && (j > i)) || ((i >= size) && (j == size))) begin
                    i <= i + 1;
                    inter <= inter >> data_width;
                    res_addr <= i;
                    res <= inter[17:0];
                    we <= 1;
                    state <= 4'b1011;
                end
                else begin
                    state <= 4'b0111;
                    k <= i - j;
                end
            end

            4'b0111: begin
                x_addr <= j;
                y_addr <= k;
                state <= 4'b1000;
            end
            4'b1000: begin
                // waiting cycle for the ram to load
                state <= 4'b1001;
            end
            4'b1001: begin
                temp <= x * y;
                state <= 4'b1010;
            end
            4'b1010: begin
                inter <= inter + temp;
                j <= j + 1;
                state <= 4'b0110;
            end
            4'b1011: begin
                we <= 0; // one cycle should be enough
                state <= 4'b0101;
            end

            4'b1100: begin
                res <= inter[17:0];
                res_addr <= i;
                inter <= 0;
                state <= 4'b1101;
            end
            4'b1101: begin
                we <= 0;
                stop <= 1;
                state <= 4'b0000;
            end

            default: begin
                state <= 4'b0000;
                size <= 1;
                inter <= 0;
                stop <= 0;
            end
        endcase
    end
endmodule

// module square #(
//     parameter addr_width = 6,
//     parameter data_width = 18
// )(
//     input clk,
//     input start,
// 
//     input [data_width-1:0] x,
//     output [addr_width-1:0] x_addr,
// 
//     output [data_width-1:0] res,
//     output [addr_width:0] res_addr,
//     output we,
// 
//     output reg stop
// );
// 
//     wire [data_width-1:0] xx;
//     wire [data_width-1:0] xx_w;
//     wire [addr_width-1:0] xx_addr;
//     wire xx_we;
//     reg ops = 0;
// 
//     ram #(
//         .addr_width(addr_width),
//         .data_width(data_width)
//     ) r0 (
//         .clk(clk),
//         .we(xx_we),
//         .addr(xx_addr),
//         .din(xx_w),
//         .dout(xx)
//     );
// 
//     reg start_copy = 0;
//     copy_ram #(
//         .addr_width(6),
//         .data_width(18)
//     )(
//         .clk(clk),
//         .start(start_copy),
//         .we(xx_we),
//         .x(xx_w),
//         .x_addr(copy_xx_addr),
//         .y(x),
//         .y_addr(copy_x_addr),
//         .stop(stop_copy)
//     );
// 
//     wire [addr_width-1:0] mul_x_addr;
// 
//     assign x_addr = (ops == 2'b00) ? copy_x_addr : mul_x_addr;
//     assign xx_addr = (ops == 2'b00) ? copy_xx_addr : mul_xx_addr;
// 
//     multiply #(
//         .addr_size(addr_size),
//         .data_width(data_width)
//     )(
//         .clk(clk),
//         .start(start),
//         .x(x),
//         .x_addr(mul_x_addr),
//         .y(xx),
//         .y_addr(mul_xx_addr),
//         .res(res),
//         .res_addr(res_addr),
//         .we(we),
//         .stop(stop_mul)
//     );
// 
//     reg [4:0] state = 0;
// 
//     always @(posedge clk) begin
//         case (state)
//             4'b0000: begin
//                 if (start) begin
//                     start_copy <= 0;
//                     ops <= 0;
//                     stop <= 0;
//                     state <= 4'b0001;
//                 end
//             end
//             4'b0001: begin
//                 start_copy <= 1;
//                 state <= 4'b0010;
//             end
//             4'b0010: begin
//                 start_copy <= 0;
//                 state <= 4'b0011;
//             end
//             4'b0011: begin
//                 if (stop_copy) begin
//                     ops <= 1;
//                     state <= 4'b0100;
//                 end
//             end
//             4'b0100: begin
//                 start_multiply <= 1;
//                 state <= 4'b0101;
//             end
//             4'b0101: begin
//                 start_multiply <= 0;
//                 state <= 4'b0110;
//             end
//             4'b0110: begin
//                 if (stop_mul) begin
//                     stop <= 1;
//                     state <= 4'b0000;
//                 end
//             end
//             default: begin
//                 state <= 4'b0000;
//             end
//         endcase
//     end
// endmodule

module gcd #(
    parameter addr_width = 6,
    parameter addr_size = 50, // used for copy -- we don't always do full mem
    parameter data_width = 18
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output [addr_width-1:0] y_addr,

    output we,
    output [data_width-1:0] res,
    output [addr_width-1:0] res_addr,

    output reg dud,
    output reg stop
);

    wire [data_width-1:0] xx; // copy of x
    wire [addr_width-1:0] xx_addr;
    wire [data_width-1:0] xx_w;
    wire xx_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) r0 (
        .clk(clk),
        .we(xx_we),
        .addr(xx_addr),
        .din(xx_w),
        .dout(xx)
    );

    wire [data_width-1:0] yy; // copy of y
    wire [addr_width-1:0] yy_addr;
    wire [data_width-1:0] yy_w;
    wire yy_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) r1 (
        .clk(clk),
        .we(yy_we),
        .addr(yy_addr),
        .din(yy_w),
        .dout(yy)
    );

    reg start_copy0 = 0;
    wire stop_copy0;
    wire [addr_width-1:0] copy0_addr;
    wire [data_width-1:0] copy0_w;
    wire copy0_we;
    copy_ram #(
        .addr_width(addr_width),
        // we can get away with just 50 assumming x < n, n is 896 bits wide
        .addr_size_x(addr_size),
        .data_width(data_width)
    ) copy0 (
        .clk(clk),
        .start(start_copy0),
        .we(copy0_we),
        .x(copy0_w),
        .x_addr(copy0_addr),
        .y(x),
        .y_addr(x_addr),
        .stop(stop_copy0)
    );

    reg start_copy1 = 0;
    wire stop_copy1;
    wire [addr_width-1:0] copy1_addr;
    wire [data_width-1:0] copy1_w;
    wire copy1_we;
    copy_ram #(
        .addr_width(addr_width),
        .addr_size_x(addr_size),
        .data_width(data_width)
    ) copy1 (
        .clk(clk),
        .start(start_copy1),
        .we(copy1_we),
        .x(copy1_w),
        .x_addr(copy1_addr),
        .y(y),
        .y_addr(y_addr),
        .stop(stop_copy1)
    );

    reg start_shift = 0;
    wire shift_we;
    wire [data_width-1:0] shift_x;
    wire [data_width-1:0] shift_x_w;
    wire [addr_width-1:0] shift_x_addr;
    wire stop_shift;
    inplace_shift_ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .shift_count(1)
    ) shift0 (
        .clk(clk),
        .start(start_shift),
        .we(shift_we),
        .x(shift_x),
        .x_w(shift_x_w),
        .x_addr(shift_x_addr),
        .stop(stop_shift)
    );

    reg start_comp = 0;
    wire stop_comp;
    wire comp_big;
    wire comp_eq;
    wire [addr_width-1:0] comp_x_addr;
    wire [addr_width-1:0] comp_y_addr;
    compare_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) comp (
        .clk(clk),
        .start(start_comp),
        .x(xx),
        .x_addr(comp_x_addr),
        .y(yy),
        .y_addr(comp_y_addr),
        .big(comp_big),
        .eq(comp_eq),
        .stop(stop_comp)
    );

    reg start_copy_res = 0;
    wire stop_copy_res;
    wire [addr_width-1:0] copy_res_xx_addr;
    // copy res module
    copy_ram #(
        .addr_width(addr_width),
        .addr_size_x(addr_size),
        .data_width(data_width)
    ) copy2 (
        .clk(clk),
        .start(start_copy_res),
        .we(we),
        .x(res),
        .x_addr(res_addr),
        .y(xx),
        .y_addr(copy_res_xx_addr),
        .stop(stop_copy_res)
    );

    reg start_sub = 0;
    wire stop_sub;
    wire [addr_width-1:0] sub_x_addr;
    wire [data_width-1:0] sub_x_w;
    wire [addr_width-1:0] sub_y_addr;
    wire [data_width-1:0] sub_x;
    wire [data_width-1:0] sub_y;
    wire sub_we;
    inplace_full_sub_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) sub0 (
        .clk(clk),
        .start(start_sub),
        .we(sub_we),
        .x(sub_x),
        .x_w(sub_x_w),
        .x_addr(sub_x_addr),
        .y(sub_y),
        .y_addr(sub_y_addr),
        .stop(stop_sub)
    );

    // jist of it is to copy the ram blocks into fancier ram that can be
    // shifted around thus giving us the following reductions:
    // x % 2 == 0 -> x = x >> 1 -- basically offset += 1
    // y % 2 == 0 -> y = y >> 1 -- basically offset += 1
    // if both are odd we should subtract depending on which one is bigger
    //
    // ops:
    // 3'b000 -- copy ram blocks
    // 3'b001 -- sub ram blocks x - y
    // 3'b010 -- diff ram blocks y - x
    // 3'b011 -- compare ram blocks
    // 3'b100 -- copy result into ram block
    // 3'b101 -- shift x with 1 block (18 bits)
    // 3'b110 -- shift y with 1 block (18 bits)

    reg [2:0] ops = 0;


    assign xx_addr = (ops == 3'b000) ? copy0_addr :
                     (ops == 3'b001) ? sub_x_addr :
                     (ops == 3'b010) ? sub_y_addr :
                     (ops == 3'b011) ? comp_x_addr :
                     (ops == 3'b100) ? copy_res_xx_addr :
                     (ops == 3'b101) ? shift_x_addr :
                     0;
                     // tops_xx_addr;
    assign xx_we = (ops == 3'b000) ? copy0_we :
                   (ops == 3'b001) ? sub_we :
                   (ops == 3'b101) ? shift_we :
                   0;

    assign xx_w = (ops == 3'b000) ? copy0_w :
                  (ops == 3'b001) ? sub_x_w :
                  (ops == 3'b101) ? shift_x_w :
                  0;

    assign yy_addr = (ops == 3'b000) ? copy1_addr :
                     (ops == 3'b001) ? sub_y_addr :
                     (ops == 3'b010) ? sub_x_addr :
                     (ops == 3'b011) ? comp_y_addr :
                     (ops == 3'b110) ? shift_x_addr :
                     0;
    assign yy_we = (ops == 3'b000) ? copy1_we :
                   (ops == 3'b010) ? sub_we :
                   (ops == 3'b110) ? shift_we :
                   0;

    assign yy_w = (ops == 3'b000) ? copy1_w :
                  (ops == 3'b010) ? sub_x_w :
                  (ops == 3'b110) ? shift_x_w :
                  0;

    assign shift_x = (ops == 3'b101) ? xx :
                     (ops == 3'b110) ? yy :
                     0;

    assign sub_x = (ops == 3'b001) ? xx :
                   (ops == 5'b010) ? yy :
                   0;
    assign sub_y = (ops == 3'b001) ? yy :
                   (ops == 5'b010) ? xx :
                   0;


    reg [5:0] state = 0;

    always @(posedge clk) begin
        case (state)
            6'b000000: begin
                if (start) begin
                    ops <= 3'b000; // copy first
                    start_copy0 <= 1;
                    start_copy1 <= 1;
                    start_comp <= 0;
                    start_copy_res <= 0;
                    start_sub <= 0;
                    start_shift <= 0;
                    dud <= 0;
                    stop <= 0;
                    state <= 6'b000001;
                end
            end
            6'b000001: begin
                // wait cycle
                start_copy0 <= 0;
                start_copy1 <= 0;
                state <= 6'b000010;
            end
            6'b000010: begin
                if (stop_copy0 && stop_copy1) begin
                    ops <= 3'b111;
                    state <= 6'b000011;
                end
            end

            6'b000011: begin
                state <= 6'b000101;
            end

            // check least significant block is 0, if so we can shift it out
            6'b000101: begin
                if (xx == 0) begin
                    start_shift <= 1;
                    ops <= 3'b101;
                    state <= 6'b010101;
                end
                else if (yy == 0) begin
                    start_shift <= 1;
                    ops <= 3'b110;
                    state <= 6'b010101;
                end
                else begin
                    ops <= 3'b011; // compare stage init
                    state <= 6'b000110;
                end
            end

            // might be able to just check block 24 is 0, it has a low
            // probability to be entirely 0 most likely so we might be able to
            // do an earlier exit? unsure if we skip that much time ?

            // compare to find diff or sub
            6'b000110: begin
                start_comp <= 1;
                state <= 6'b000111;
            end
            6'b000111: begin
                // wait cycle
                start_comp <= 0;
                state <= 6'b001000;
            end
            6'b001000: begin
                if (stop_comp) begin
                    state <= 6'b001001;
                end
            end
            6'b001001: begin
                if (comp_eq) begin
                    ops <= 3'b111;
                    state <= 6'b001011;
                end
                else if (comp_big) begin
                    ops <= 3'b001; // sub ops -- x - y
                    state <= 6'b001111;
                end
                else begin
                    ops <= 3'b010; // diff ops -- y - x
                    state <= 6'b001111;
                end
            end
            6'b001010: begin
                // wait cycle
                state <= 6'b001011;
            end
            6'b001011: begin
                if (xx == 18'b1) begin
                    // most likely its just 1, I don't really want to check
                    // all the ram block
                    dud <= 1;
                    stop <= 1;
                    state <= 6'b000000;
                end
                else begin
                    ops <= 3'b100; // copy res ops
                    state <= 6'b001100;
                end
            end
            6'b001100: begin
                // we actually found something -- copy to res
                start_copy_res <= 1;
                state <= 6'b001101;
            end
            6'b001101: begin
                // wait cycle
                start_copy_res <= 0;
                state <= 6'b001110;
            end
            6'b001110: begin
                if (stop_copy_res) begin
                    stop <= 1;
                    state <= 6'b000000;
                end
            end
            6'b001111: begin
                start_sub <= 1;
                state <= 6'b010000;
            end
            6'b010000: begin
                // wait cycle
                start_sub <= 0;
                state <= 6'b010001;
            end
            6'b010001: begin
                if (stop_sub) begin
                    ops <= 3'b011;
                    state <= 6'b000110;
                end
            end
            // too lazy to change everything here goes the shifting
            6'b010101: begin
                // wait cycle
                start_shift <= 0;
                state <= 6'b010110;
            end
            6'b010110: begin
                if (stop_shift) begin
                    ops <= 3'b111;
                    state <= 6'b000011;
                end
            end
        endcase
    end

endmodule

module pollard(
    input clk,
    input start,
    output uart_tx,
    output reg [3:0] leds
    //output reg stop
);

    localparam addr_width = 6;
    localparam addr_size = 50;
    localparam data_width = 18;

    wire [data_width-1:0] x;
    wire [addr_width-1:0] x_addr;
    wire [data_width-1:0] x_w;
    wire x_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("start_x.txt")
    ) ram_x (
        .clk(clk),
        .we(x_we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    wire [data_width-1:0] y;
    wire [addr_width-1:0] y_addr;
    wire [data_width-1:0] y_w;
    wire y_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("start_x.txt")
    ) ram_y (
        .clk(clk),
        .we(y_we),
        .addr(y_addr),
        .din(y_w),
        .dout(y)
    );

    wire [data_width-1:0] n0;
    wire [addr_width-1:0] n0_addr;
    wire [data_width-1:0] n0_w;
    wire n0_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("rsa896.txt")
    ) ram_n0 (
        .clk(clk),
        .we(n0_we),
        .addr(n0_addr),
        .din(n0_w),
        .dout(n0)
    );

    wire [data_width-1:0] n1;
    wire [addr_width-1:0] n1_addr;
    wire [data_width-1:0] n1_w;
    wire n1_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("rsa896.txt")
    ) ram_n1 (
        .clk(clk),
        .we(n1_we),
        .addr(n1_addr),
        .din(n1_w),
        .dout(n1)
    );

    wire [data_width-1:0] np0;
    wire [addr_width-1:0] np0_addr;
    wire [data_width-1:0] np0_w;
    wire np0_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("np.txt")
    ) ram_np0 (
        .clk(clk),
        .we(np0_we),
        .addr(np0_addr),
        .din(np0_w),
        .dout(np0)
    );

    wire [data_width-1:0] np1;
    wire [addr_width-1:0] np1_addr;
    wire [data_width-1:0] np1_w;
    wire np1_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("np.txt")
    ) ram_np1 (
        .clk(clk),
        .we(np1_we),
        .addr(np1_addr),
        .din(np1_w),
        .dout(np1)
    );

    wire [data_width-1:0] mx;
    wire [addr_width:0] mx_addr;
    wire [data_width-1:0] mx_w;
    wire mx_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_mx (
        .clk(clk),
        .we(mx_we),
        .addr(mx_addr),
        .din(mx_w),
        .dout(mx)
    );

    wire [data_width-1:0] mtx;
    wire [addr_width:0] mtx_addr;
    wire [data_width-1:0] mtx_w;
    wire mtx_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_mtx (
        .clk(clk),
        .we(mtx_we),
        .addr(mtx_addr),
        .din(mtx_w),
        .dout(mtx)
    );

    wire [data_width-1:0] tx;
    wire [addr_width:0] tx_addr;
    wire [data_width-1:0] tx_w;
    wire tx_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_tx (
        .clk(clk),
        .we(tx_we),
        .addr(tx_addr),
        .din(tx_w),
        .dout(tx)
    );

    wire [data_width-1:0] my;
    wire [addr_width:0] my_addr;
    wire [data_width-1:0] my_w;
    wire my_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_my (
        .clk(clk),
        .we(my_we),
        .addr(my_addr),
        .din(my_w),
        .dout(my)
    );

    wire [data_width-1:0] mty;
    wire [addr_width:0] mty_addr;
    wire [data_width-1:0] mty_w;
    wire mty_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_mty (
        .clk(clk),
        .we(mty_we),
        .addr(mty_addr),
        .din(mty_w),
        .dout(mty)
    );

    wire [data_width-1:0] ty;
    wire [addr_width:0] ty_addr;
    wire [data_width-1:0] ty_w;
    wire ty_we;
    ram #(
        .addr_width(addr_width + 1),
        .data_width(data_width)
    ) ram_ty (
        .clk(clk),
        .we(ty_we),
        .addr(ty_addr),
        .din(ty_w),
        .dout(ty)
    );

    wire [data_width-1:0] xx;
    wire [addr_width-1:0] xx_addr;
    wire [data_width-1:0] xx_w;
    wire xx_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("start_x.txt")
    ) ram_xx (
        .clk(clk),
        .we(xx_we),
        .addr(xx_addr),
        .din(xx_w),
        .dout(xx)
    );

    wire [data_width-1:0] yy;
    wire [addr_width-1:0] yy_addr;
    wire [data_width-1:0] yy_w;
    wire yy_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .init_file("start_x.txt")
    ) ram_yy (
        .clk(clk),
        .we(yy_we),
        .addr(yy_addr),
        .din(yy_w),
        .dout(yy)
    );

    wire [data_width-1:0] diff;
    wire [addr_width-1:0] diff_addr;
    wire [data_width-1:0] diff_w;
    wire diff_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) ram_diff (
        .clk(clk),
        .we(diff_we),
        .addr(diff_addr),
        .din(diff_w),
        .dout(diff)
    );

    wire [data_width-1:0] factor;
    wire [addr_width-1:0] factor_addr;
    reg [addr_width-1:0] top_factor_addr = 0;
    wire [data_width-1:0] factor_w;
    wire factor_we;
    ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) ram_factor (
        .clk(clk),
        .we(factor_we),
        .addr(factor_addr),
        .din(factor_w),
        .dout(factor)
    );

    reg start_copy0 = 0;
    wire [addr_width-1:0] copy0_x_addr;
    wire [addr_width-1:0] copy0_y_addr;
    wire [data_width-1:0] copy0_x_w;
    wire [data_width-1:0] copy0_y;
    wire copy0_we;
    wire stop_copy0;
    copy_ram #(
        .addr_width(addr_width),
        .addr_size_x(50), // x should be at most 900 bits
        .data_width(data_width)
    ) copy0 (
        .clk(clk),
        .start(start_copy0),
        .we(copy0_we),
        .x(copy0_x_w),
        .x_addr(copy0_x_addr),
        .y(copy0_y),
        .y_addr(copy0_y_addr),
        .stop(stop_copy0)
    );

    reg start_copy1 = 0;
    wire [addr_width-1:0] copy1_x_addr;
    wire [addr_width-1:0] copy1_y_addr;
    wire [data_width-1:0] copy1_x_w;
    wire [data_width-1:0] copy1_y;
    wire stop_copy1;
    copy_ram #(
        .addr_width(addr_width),
        .addr_size_x(50), // x should be at most 900 bits
        .data_width(data_width)
    ) copy1 (
        .clk(clk),
        .start(start_copy1),
        .we(copy1_we),
        .x(copy1_x_w),
        .x_addr(copy1_x_addr),
        .y(copy1_y),
        .y_addr(copy1_y_addr),
        .stop(stop_copy1)
    );

    reg start_m0 = 0;
    wire [data_width-1:0] m0_x;
    wire [addr_width-1:0] m0_x_addr;
    wire [data_width-1:0] m0_y;
    wire [addr_width-1:0] m0_y_addr;
    wire [data_width-1:0] m0_res_w;
    wire [addr_width:0] m0_res_addr;
    wire m0_res_we;
    wire stop_m0;
    multiply #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) m0 (
        .clk(clk),
        .start(start_m0),
        .x(m0_x),
        .x_addr(m0_x_addr),
        .y(m0_y),
        .y_addr(m0_y_addr),
        .res(m0_res_w),
        .res_addr(m0_res_addr),
        .we(m0_res_we),
        .stop(stop_m0)
    );

    reg start_m1 = 0;
    wire [data_width-1:0] m1_x;
    wire [addr_width-1:0] m1_x_addr;
    wire [data_width-1:0] m1_y;
    wire [addr_width-1:0] m1_y_addr;
    wire [data_width-1:0] m1_res_w;
    wire [addr_width:0] m1_res_addr;
    wire m1_res_we;
    wire stop_m1;
    multiply #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) m1 (
        .clk(clk),
        .start(start_m1),
        .x(m1_x),
        .x_addr(m1_x_addr),
        .y(m1_y),
        .y_addr(m1_y_addr),
        .res(m1_res_w),
        .res_addr(m1_res_addr),
        .we(m1_res_we),
        .stop(stop_m1)
    );

    reg start_clear0 = 0;
    wire clear0_we;
    wire [addr_width:0] clear0_addr;
    wire [data_width-1:0] clear0_x_w;
    wire stop_clear0;
    clear_ram #(
        .addr_width(addr_width+1),
        .data_width(data_width)
    ) clear0 (
        .clk(clk),
        .start(start_clear0),
        .we(clear0_we),
        .addr(clear0_addr),
        .x(clear0_x_w),
        .stop(stop_clear0)
    );

    reg start_clear1 = 0;
    wire clear1_we;
    wire [addr_width:0] clear1_addr;
    wire [data_width-1:0] clear1_x_w;
    wire stop_clear1;
    clear_ram #(
        .addr_width(addr_width+1),
        .data_width(data_width)
    ) clear1 (
        .clk(clk),
        .start(start_clear1),
        .we(clear1_we),
        .addr(clear1_addr),
        .x(clear1_x_w),
        .stop(stop_clear1)
    );

    reg start_add0 = 0;
    wire add0_we;
    wire [data_width-1:0] add0_x;
    wire [data_width-1:0] add0_x_w;
    wire [addr_width:0] add0_x_addr;
    wire [data_width-1:0] add0_y;
    wire [addr_width:0] add0_y_addr;
    wire stop_add0;
    inplace_full_add_ram #(
        .addr_width(addr_width+1),
        .data_width(data_width)
    ) add0 (
        .clk(clk),
        .start(start_add0),
        .we(add0_we),
        .x(add0_x),
        .x_w(add0_x_w),
        .x_addr(add0_x_addr),
        .y(add0_y),
        .y_addr(add0_y_addr),
        .stop(stop_add0)
    );

    reg start_add1 = 0;
    wire add1_we;
    wire [data_width-1:0] add1_x;
    wire [data_width-1:0] add1_x_w;
    wire [addr_width:0] add1_x_addr;
    wire [data_width-1:0] add1_y;
    wire [addr_width:0] add1_y_addr;
    wire stop_add1;
    inplace_full_add_ram #(
        .addr_width(addr_width+1),
        .data_width(data_width)
    ) add1 (
        .clk(clk),
        .start(start_add1),
        .we(add1_we),
        .x(add1_x),
        .x_w(add1_x_w),
        .x_addr(add1_x_addr),
        .y(add1_y),
        .y_addr(add1_y_addr),
        .stop(stop_add1)
    );

    reg start_shift0 = 0;
    wire shift0_we;
    wire [data_width-1:0] shift0_x_w;
    wire [addr_width-1:0] shift0_x_addr;
    wire [data_width-1:0] shift0_y;
    wire [addr_width:0] shift0_y_addr;
    wire stop_shift0;
    shift_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) shift0 (
        .clk(clk),
        .start(start_shift0),
        .we(shift0_we),
        .x(shift0_x_w),
        .x_addr(shift0_x_addr),
        .y(shift0_y),
        .y_addr(shift0_y_addr),
        .stop(stop_shift0)
    );

    reg start_shift1 = 0;
    wire shift1_we;
    wire [data_width-1:0] shift1_x_w;
    wire [addr_width-1:0] shift1_x_addr;
    wire [data_width-1:0] shift1_y;
    wire [addr_width:0] shift1_y_addr;
    wire stop_shift1;
    shift_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) shift1 (
        .clk(clk),
        .start(start_shift1),
        .we(shift1_we),
        .x(shift1_x_w),
        .x_addr(shift1_x_addr),
        .y(shift1_y),
        .y_addr(shift1_y_addr),
        .stop(stop_shift1)
    );

    reg start_const_add0 = 0;
    wire [data_width-1:0] const_add0_x;
    wire [data_width-1:0] const_add0_x_w;
    wire [addr_width-1:0] const_add0_x_addr;
    wire const_add0_we;
    wire const_add0_stop;
    inplace_constant_add_ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .b(17)
    ) const_add0 (
        .clk(clk),
        .start(start_const_add0),
        .x(const_add0_x),
        .x_w(const_add0_x_w),
        .x_addr(const_add0_x_addr),
        .we(const_add0_we),
        .stop(stop_const_add0)
    );

    reg start_const_add1 = 0;
    wire [data_width-1:0] const_add1_x;
    wire [data_width-1:0] const_add1_x_w;
    wire [addr_width-1:0] const_add1_x_addr;
    wire const_add1_we;
    wire const_add1_stop;
    inplace_constant_add_ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .b(17)
    ) const_add1 (
        .clk(clk),
        .start(start_const_add1),
        .x(const_add1_x),
        .x_w(const_add1_x_w),
        .x_addr(const_add1_x_addr),
        .we(const_add1_we),
        .stop(stop_const_add1)
    );

    reg start_clear_top0 = 0;
    wire clear_top0_we;
    wire [data_width-1:0] clear_top0_x_w;
    wire [addr_width-1:0] clear_top0_x_addr;
    wire stop_clear_top0;
    clear_top_ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .clear_index(50)
    ) clear_top0 (
        .clk(clk),
        .start(start_clear_top0),
        .we(clear_top0_we),
        .x_w(clear_top0_x_w),
        .x_addr(clear_top0_x_addr),
        .stop(stop_clear_top0)
    );

    reg start_clear_top1 = 0;
    wire clear_top1_we;
    wire [data_width-1:0] clear_top1_x_w;
    wire [addr_width-1:0] clear_top1_x_addr;
    wire stop_clear_top1;
    clear_top_ram #(
        .addr_width(addr_width),
        .data_width(data_width),
        .clear_index(50)
    ) clear_top1 (
        .clk(clk),
        .start(start_clear_top1),
        .we(clear_top1_we),
        .x_w(clear_top1_x_w),
        .x_addr(clear_top1_x_addr),
        .stop(stop_clear_top1)
    );

    reg start_comp0 = 0;
    wire [data_width-1:0] comp0_x;
    wire [addr_width-1:0] comp0_x_addr;
    wire [data_width-1:0] comp0_y;
    wire [addr_width-1:0] comp0_y_addr;
    wire stop_comp0;
    wire comp0_big;
    wire comp0_eq;
    compare_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) comp0 (
        .clk(clk),
        .start(start_comp0),
        .x(comp0_x),
        .x_addr(comp0_x_addr),
        .y(comp0_y),
        .y_addr(comp0_y_addr),
        .stop(stop_comp0),
        .big(comp0_big),
        .eq(comp0_eq)
    );

    reg start_sub0 = 0;
    wire sub0_we;
    wire [data_width-1:0] sub0_x;
    wire [data_width-1:0] sub0_x_w;
    wire [addr_width-1:0] sub0_x_addr;
    wire [data_width-1:0] sub0_y;
    wire [addr_width-1:0] sub0_y_addr;
    wire stop_sub0;
    inplace_full_sub_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) sub0 (
        .clk(clk),
        .start(start_sub0),
        .we(sub0_we),
        .x(sub0_x),
        .x_w(sub0_x_w),
        .x_addr(sub0_x_addr),
        .y(sub0_y),
        .y_addr(sub0_y_addr),
        .stop(stop_sub0)
    );

    reg start_sub1 = 0;
    wire [data_width-1:0] sub1_x;
    wire [addr_width-1:0] sub1_x_addr;
    wire [data_width-1:0] sub1_y;
    wire [addr_width-1:0] sub1_y_addr;
    wire [data_width-1:0] sub1_res_w;
    wire [addr_width-1:0] sub1_res_addr;
    wire stop_sub1;
    full_sub_ram #(
        .addr_width(addr_width),
        .data_width(data_width)
    ) sub1 (
        .clk(clk),
        .start(start_sub1),
        .x(sub1_x),
        .x_addr(sub1_x_addr),
        .y(sub1_y),
        .y_addr(sub1_y_addr),
        .we(sub1_we),
        .res(sub1_res_w),
        .res_addr(sub1_res_addr),
        .stop(stop_sub1)
    );

    reg start_gcd0 = 0;
    wire [data_width-1:0] gcd0_x;
    wire [addr_width-1:0] gcd0_x_addr;
    wire [data_width-1:0] gcd0_y;
    wire [addr_width-1:0] gcd0_y_addr;
    wire [data_width-1:0] gcd_res_w;
    wire [addr_width-1:0] gcd_res_addr;
    wire gcd0_we;
    wire gcd0_dud;
    wire stop_gcd0;
    gcd #(
        .addr_width(addr_width),
        .addr_size(50),
        .data_width(data_width)
    ) gcd0 (
        .clk(clk),
        .start(start_gcd0),
        .x(gcd0_x),
        .x_addr(gcd0_x_addr),
        .y(gcd0_y),
        .y_addr(gcd0_y_addr),
        .we(gcd0_we),
        .res(gcd0_res_w),
        .res_addr(gcd0_res_addr),
        .dud(gcd0_dud),
        .stop(stop_gcd0)
    );

    reg reset_uart = 0;
    wire busy_uart;
    reg start_uart = 0;
    reg [7:0] uart_data = 0;
    uart_transmit uart0(
        .clk(clk),
        .reset(reset_uart),
        .start(start_uart),
        .data(uart_data),
        .tx(uart_tx),
        .busy(busy_uart)
    );

    // ops stages
    // 5'b00000: copy x to xx which is used for the initial squaring
    // 5'b00001: initial mx = x * x and my = y * y
    // 5'b00010: copy mx&rm1 to mtx and my&rm1 to mty
    // 5'b00011: tx = mtx*np and ty = mty*np
    // 5'b00100: copy tx&rm1 to mtx and ty&rm1 to mty
    // 5'b00101: clear tx and ty
    // 5'b00110: tx = mtx*n ; ty = mty*n
    // 5'b00111: tx = tx + mx ; ty = ty + my
    // 5'b01000: x = tx >> 900 ; y = ty >> 900 ; clear mx, clear my
    // 5'b01001: x = x + b ; y = y + b ; clear mtx, clear mty
    // 5'b01010: x = x & 50 ; y = y & 50 ; clear tx, clear ty
    reg [4:0] ops = 0;

    assign x_w = (ops == 5'b01000) ? shift0_x_w :
                 (ops == 5'b01001) ? const_add0_x_w :
                 (ops == 5'b01011) ? sub0_x_w :
                 (ops == 5'b01110) ? clear_top0_x_w :
                 0;
    assign x_addr = (ops == 5'b00000) ? copy0_y_addr :
                    (ops == 5'b00001) ? m0_x_addr :
                    (ops == 5'b01000) ? shift0_x_addr :
                    (ops == 5'b01001) ? const_add0_x_addr :
                    (ops == 5'b01010) ? comp0_x_addr :
                    (ops == 5'b01011) ? sub0_x_addr :
                    (ops == 5'b01110) ? clear_top0_x_addr :
                    (ops == 5'b11010) ? comp0_x_addr :
                    (ops == 5'b11011) ? sub1_x_addr :
                    (ops == 5'b11100) ? sub1_y_addr :
                    0;
    assign x_we = (ops == 5'b01000) ? shift0_we :
                  (ops == 5'b01001) ? const_add0_we :
                  (ops == 5'b01011) ? sub0_we :
                  (ops == 5'b01110) ? clear_top0_we :
                  0;

    assign y_w = (ops == 5'b01000) ? shift1_x_w :
                 (ops == 5'b01001) ? const_add1_x_w :
                 (ops == 5'b01101) ? sub0_x_w :
                 (ops == 5'b01110) ? clear_top1_x_w :
                 (ops == 5'b10110) ? shift1_x_w :
                 (ops == 5'b10111) ? const_add1_x_w :
                 (ops == 5'b11001) ? sub0_x_w :
                 0;
    assign y_addr = (ops == 5'b00000) ? copy1_y_addr :
                    (ops == 5'b00001) ? m1_x_addr :
                    (ops == 5'b01000) ? shift1_x_addr :
                    (ops == 5'b01001) ? const_add1_x_addr :
                    (ops == 5'b01100) ? comp0_x_addr :
                    (ops == 5'b01101) ? sub0_x_addr :
                    (ops == 5'b01110) ? clear_top1_x_addr :
                    (ops == 5'b01111) ? copy1_y_addr :
                    (ops == 5'b10000) ? m1_x_addr :
                    (ops == 5'b10110) ? shift1_x_addr :
                    (ops == 5'b10111) ? const_add1_x_addr :
                    (ops == 5'b11000) ? comp0_x_addr :
                    (ops == 5'b11001) ? sub0_x_addr :
                    (ops == 5'b11010) ? comp0_y_addr :
                    (ops == 5'b11011) ? sub1_y_addr :
                    (ops == 5'b11100) ? sub1_x_addr :
                    0;
    assign y_we = (ops == 5'b01000) ? shift1_we :
                  (ops == 5'b01001) ? const_add1_we :
                  (ops == 5'b01101) ? sub0_we :
                  (ops == 5'b01110) ? clear_top1_we :
                  (ops == 5'b10110) ? shift1_we :
                  (ops == 5'b10111) ? const_add1_we :
                  (ops == 5'b11001) ? sub0_we :
                  0;

    assign mx_w = (ops == 5'b00001) ? m0_res_w :
                  (ops == 5'b01000) ? clear0_x_w :
                  0;
    assign mx_we = (ops == 5'b00001) ? m0_res_we :
                   (ops == 5'b01000) ? clear0_we :
                   0;
    assign mx_addr = (ops == 5'b00001) ? m0_res_addr :
                     (ops == 5'b00010) ? copy0_y_addr :
                     (ops == 5'b00111) ? add0_y_addr :
                     (ops == 5'b01000) ? clear0_addr :
                     0;

    assign my_w = (ops == 5'b00001) ? m1_res_w :
                  (ops == 5'b01000) ? clear1_x_w :
                  (ops == 5'b10000) ? m1_res_w :
                  (ops == 5'b10110) ? clear1_x_w :
                  0;
    assign my_we = (ops == 5'b00001) ? m1_res_we :
                   (ops == 5'b01000) ? clear1_we :
                   (ops == 5'b10000) ? m1_res_we :
                   (ops == 5'b10110) ? clear1_we :
                   0;
    assign my_addr = (ops == 5'b00001) ? m1_res_addr :
                     (ops == 5'b00010) ? copy1_y_addr :
                     (ops == 5'b00111) ? add1_y_addr :
                     (ops == 5'b01000) ? clear1_addr :
                     (ops == 5'b10000) ? m1_res_addr :
                     (ops == 5'b10001) ? copy1_y_addr :
                     (ops == 5'b10101) ? add1_y_addr :
                     (ops == 5'b10110) ? clear1_addr :
                     0;

    assign m0_x = (ops == 5'b00001) ? x :
                  (ops == 5'b00011) ? mtx :
                  (ops == 5'b00110) ? mtx :
                  0;
    assign m0_y = (ops == 5'b00001) ? xx :
                  (ops == 5'b00011) ? np0 :
                  (ops == 5'b00110) ? n0 :
                  0;
    assign m1_x = (ops == 5'b00001) ? y :
                  (ops == 5'b00011) ? mty :
                  (ops == 5'b00110) ? mty :
                  (ops == 5'b10000) ? y :
                  (ops == 5'b10010) ? mty :
                  (ops == 5'b10100) ? mty :
                  0;
    assign m1_y = (ops == 5'b00001) ? yy :
                  (ops == 5'b00011) ? np1 :
                  (ops == 5'b00110) ? n1 :
                  (ops == 5'b10000) ? yy :
                  (ops == 5'b10010) ? np1 :
                  (ops == 5'b10100) ? n1 :
                  0;

    assign xx_we = (ops == 5'b00000) ? copy0_we : 0;
    assign yy_we = (ops == 5'b00000) ? copy1_we :
                   (ops == 5'b01111) ? copy1_we :
                   0;

    assign xx_addr = (ops == 5'b00000) ? copy0_x_addr :
                     (ops == 5'b00001) ? m0_y_addr : 0;
    assign yy_addr = (ops == 5'b00000) ? copy1_x_addr :
                     (ops == 5'b00001) ? m1_y_addr :
                     (ops == 5'b01111) ? copy1_x_addr :
                     (ops == 5'b10000) ? m1_y_addr :
                     0;

    assign copy0_y = (ops == 5'b00000) ? x :
                     (ops == 5'b00010) ? mx :
                     (ops == 5'b00100) ? tx :
                     0;
    assign copy1_y = (ops == 5'b00000) ? y :
                     (ops == 5'b00010) ? my :
                     (ops == 5'b00100) ? ty :
                     (ops == 5'b01111) ? y :
                     (ops == 5'b10001) ? my :
                     (ops == 5'b10011) ? ty :
                     0;

    assign xx_w = (ops == 5'b00000) ? copy0_x_w : 0;
    assign yy_w = (ops == 5'b00000) ? copy1_x_w :
                  (ops == 5'b01111) ? copy1_x_w :
                  0;

    assign mtx_w = (ops == 5'b00010) ? copy0_x_w :
                   (ops == 5'b00100) ? copy0_x_w :
                   0;
    assign mtx_we = (ops == 5'b00010) ? copy0_we :
                    (ops == 5'b00100) ? copy0_we :
                    0;
    assign mtx_addr = (ops == 5'b00010) ? copy0_x_addr :
                      (ops == 5'b00011) ? m0_x_addr :
                      (ops == 5'b00100) ? copy0_x_addr :
                      (ops == 5'b00110) ? m0_x_addr :
                      0;

    assign mty_w = (ops == 5'b00010) ? copy1_x_w :
                   (ops == 5'b00100) ? copy1_x_w :
                   (ops == 5'b10001) ? copy1_x_w :
                   (ops == 5'b10011) ? copy1_x_w :
                   0;
    assign mty_we = (ops == 5'b00010) ? copy1_we :
                    (ops == 5'b00100) ? copy1_we :
                    (ops == 5'b10001) ? copy1_we :
                    (ops == 5'b10011) ? copy1_we :
                    0;
    assign mty_addr = (ops == 5'b00010) ? copy1_x_addr :
                      (ops == 5'b00011) ? m1_x_addr :
                      (ops == 5'b00100) ? copy1_x_addr :
                      (ops == 5'b00110) ? m1_x_addr :
                      (ops == 5'b10001) ? copy1_x_addr :
                      (ops == 5'b10010) ? m1_x_addr :
                      (ops == 5'b10011) ? copy1_x_addr :
                      (ops == 5'b10100) ? m1_x_addr :
                      0;

    assign tx_w = (ops == 5'b00011) ? m0_res_w :
                  (ops == 5'b00101) ? clear0_x_w :
                  (ops == 5'b00110) ? m0_res_w :
                  (ops == 5'b00111) ? add0_x_w :
                  (ops == 5'b01110) ? clear0_x_w :
                  0;
    assign tx_we = (ops == 5'b00011) ? m0_res_we :
                   (ops == 5'b00101) ? clear0_we :
                   (ops == 5'b00110) ? m0_res_we :
                   (ops == 5'b00111) ? add0_we :
                   (ops == 5'b01110) ? clear0_we :
                   0;
    assign tx_addr = (ops == 5'b00011) ? m0_res_addr :
                     (ops == 5'b00100) ? copy0_y_addr :
                     (ops == 5'b00101) ? clear0_addr :
                     (ops == 5'b00110) ? m0_res_addr :
                     (ops == 5'b00111) ? add0_x_addr :
                     (ops == 5'b01000) ? shift0_y_addr :
                     (ops == 5'b01110) ? clear0_addr :
                     0;

    assign ty_w = (ops == 5'b00011) ? m1_res_w :
                  (ops == 5'b00101) ? clear1_x_w :
                  (ops == 5'b00110) ? m1_res_w :
                  (ops == 5'b00111) ? add1_x_w :
                  (ops == 5'b01110) ? clear1_x_w :
                  (ops == 5'b10010) ? m1_res_w :
                  (ops == 5'b10100) ? m1_res_w :
                  (ops == 5'b10101) ? add1_x_w :
                  0;
    assign ty_we = (ops == 5'b00011) ? m1_res_we :
                   (ops == 5'b00101) ? clear1_we :
                   (ops == 5'b00110) ? m1_res_we :
                   (ops == 5'b00111) ? add1_we :
                   (ops == 5'b01110) ? clear1_we :
                   (ops == 5'b10010) ? m1_res_we :
                   (ops == 5'b10100) ? m1_res_we :
                   (ops == 5'b10101) ? add1_we :
                   0;
    assign ty_addr = (ops == 5'b00011) ? m1_res_addr :
                     (ops == 5'b00100) ? copy1_y_addr :
                     (ops == 5'b00101) ? clear1_addr :
                     (ops == 5'b00110) ? m1_res_addr :
                     (ops == 5'b00111) ? add1_x_addr :
                     (ops == 5'b01000) ? shift1_y_addr :
                     (ops == 5'b01110) ? clear1_addr :
                     (ops == 5'b10010) ? m1_res_addr :
                     (ops == 5'b10011) ? copy1_y_addr :
                     (ops == 5'b10100) ? m1_res_addr :
                     (ops == 5'b10101) ? add1_x_addr :
                     (ops == 5'b10110) ? shift1_y_addr :
                     0;

    assign np0_addr = (ops == 5'b00011) ? m0_y_addr :
                      0;
    assign np1_addr = (ops == 5'b00011) ? m1_y_addr :
                      (ops == 5'b10010) ? m1_y_addr :
                      0;

    assign n0_addr = (ops == 5'b00110) ? m0_y_addr :
                     (ops == 5'b01010) ? comp0_y_addr :
                     (ops == 5'b01011) ? sub0_y_addr :
                     (ops == 5'b01100) ? comp0_y_addr :
                     (ops == 5'b01101) ? sub0_y_addr :
                     (ops == 5'b11000) ? comp0_y_addr :
                     (ops == 5'b11001) ? sub0_y_addr :
                     (ops == 5'b11101) ? gcd0_y_addr :
                     0;
    assign n1_addr = (ops == 5'b00110) ? m1_y_addr :
                     (ops == 5'b10100) ? m1_y_addr :
                     0;

    assign add0_x = (ops == 5'b00111) ? tx : 0;
    assign add0_y = (ops == 5'b00111) ? mx : 0;
    assign add1_x = (ops == 5'b00111) ? ty :
                    (ops == 5'b10101) ? ty :
                    0;
    assign add1_y = (ops == 5'b00111) ? my :
                    (ops == 5'b10101) ? my :
                    0;

    assign shift0_y = (ops == 5'b01000) ? tx : 0;
    assign shift1_y = (ops == 5'b01000) ? ty :
                      (ops == 5'b10110) ? ty :
                      0;

    assign const_add0_x = (ops == 5'b01001) ? x : 0;
    assign const_add1_x = (ops == 5'b01001) ? y :
                          (ops == 5'b10111) ? y : 0;

    assign comp0_x = (ops == 5'b01010) ? x :
                     (ops == 5'b01100) ? y :
                     (ops == 5'b11000) ? y :
                     (ops == 5'b11010) ? x :
                     0;
    assign comp0_y = (ops == 5'b01010) ? n0 :
                     (ops == 5'b01100) ? n0 :
                     (ops == 5'b11000) ? n0 :
                     (ops == 5'b11010) ? y :
                     0;

    assign sub0_x = (ops == 5'b01011) ? x :
                    (ops == 5'b01101) ? y :
                    (ops == 5'b11001) ? y :
                    0;
    assign sub0_y = (ops == 5'b01011) ? n0 :
                    (ops == 5'b01101) ? n0 :
                    (ops == 5'b11001) ? n0 :
                    0;

    assign diff_w = (ops == 5'b11011) ? sub1_res_w :
                    (ops == 5'b11100) ? sub1_res_w :
                    0;
    assign diff_addr = (ops == 5'b11011) ? sub1_res_addr :
                       (ops == 5'b11100) ? sub1_res_addr :
                       (ops == 5'b11101) ? gcd0_x_addr :
                       0;
    assign diff_we = (ops == 5'b11011) ? sub1_we :
                     (ops == 5'b11100) ? sub1_we :
                     0;

    assign sub1_x = (ops == 5'b11011) ? x :
                    (ops == 5'b11100) ? y :
                    0;
    assign sub1_y = (ops == 5'b11011) ? y :
                    (ops == 5'b11100) ? x :
                    0;

    assign gcd0_x = (ops == 5'b11101) ? diff :
                    0;
    assign gcd0_y = (ops == 5'b11101) ? n0 :
                    0;

    assign factor_w = (ops == 5'b11101) ? gcd0_res_w :
                      0;
    assign factor_we = (ops == 5'b11101) ? gcd0_we :
                       0;
    assign factor_addr = (ops == 5'b11101) ? gcd0_res_addr :
                         (ops == 5'b11110) ? top_factor_addr :
                         0;

    reg [6:0] state = 0;
    integer s = 0;
    reg [4:0] i = 0;
    reg [3:0] l = 4'b1111;

    always @(posedge clk) begin
        case (state)
            7'b0000000: begin
                ops <= 0;
                leds <= 4'b1111;
                // leds <= l;
                // l <= l - 1;
                state <= 7'b0000001;
            end

            // xx = x ; yy = y
            7'b0000001: begin
                start_copy0 <= 1;
                start_copy1 <= 1;
                state <= 7'b0000010;
            end
            7'b0000010: begin
                start_copy0 <= 0;
                start_copy1 <= 0;
                state <= 7'b0000011;
            end
            7'b0000011: begin
                if (stop_copy0 && stop_copy1) begin
                    ops <= 5'b00001;
                    state <= 7'b0000100;
                end
            end

            // mx = x * xx ; my = y * yy
            7'b0000100: begin
                start_m0 <= 1;
                start_m1 <= 1;
                state <= 7'b0000101;
            end
            7'b0000101: begin
                start_m0 <= 0;
                start_m1 <= 0;
                state <= 7'b0000110;
            end
            7'b0000110: begin
                if (stop_m0 && stop_m1) begin
                    ops <= 5'b00010;
                    state <= 7'b0000111;
                end
            end

            // mtx = mx ; mty = my
            7'b0000111: begin
                start_copy0 <= 1;
                start_copy1 <= 1;
                state <= 7'b0001000;
            end
            7'b0001000: begin
                start_copy0 <= 0;
                start_copy1 <= 0;
                state <= 7'b0001001;
            end
            7'b0001001: begin
                if (stop_copy0 && stop_copy1) begin
                    ops <= 5'b00011;
                    state <= 7'b0001010;
                end
            end

            // tx = mtx * np ; ty = mty * np
            7'b0001010: begin
                start_m0 <= 1;
                start_m1 <= 1;
                state <= 7'b0001011;
            end
            7'b0001011: begin
                start_m0 <= 0;
                start_m1 <= 0;
                state <= 7'b0001100;
            end
            7'b0001100: begin
                if (stop_m0 && stop_m1) begin
                    ops <= 5'b00100;
                    state <= 7'b0001101;
                end
            end

            // mtx = tx & rm1 ; mty = ty & rm1
            7'b0001101: begin
                start_copy0 <= 1;
                start_copy1 <= 1;
                state <= 7'b0001110;
            end
            7'b0001110: begin
                start_copy0 <= 0;
                start_copy1 <= 0;
                state <= 7'b0001111;
            end
            7'b0001111: begin
                if (stop_copy0 && stop_copy1) begin
                    ops <= 5'b00101;
                    state <= 7'b0010000;
                end
            end

            // clear tx ; clear ty
            7'b0010000: begin
                start_clear0 <= 1;
                start_clear1 <= 1;
                state <= 7'b0010001;
            end
            7'b0010001: begin
                start_clear0 <= 0;
                start_clear1 <= 0;
                state <= 7'b0010010;
            end
            7'b0010010: begin
                if (stop_clear0 && stop_clear1) begin
                    ops <= 5'b00110;
                    state <= 7'b0010011;
                end
            end

            // tx = mtx * n ; ty = mty * n
            7'b0010011: begin
                start_m0 <= 1;
                start_m1 <= 1;
                state <= 7'b0010100;
            end
            7'b0010100: begin
                start_m0 <= 0;
                start_m1 <= 0;
                state <= 7'b0010101;
            end
            7'b0010101: begin
                if (stop_m0 && stop_m1) begin
                    ops <= 5'b00111;
                    state <= 7'b0010110;
                end
            end

            // tx = tx + mx ; ty = ty + my
            7'b0010110: begin
                start_add0 <= 1;
                start_add1 <= 1;
                state <= 7'b0010111;
            end
            7'b0010111: begin
                start_add0 <= 0;
                start_add1 <= 0;
                state <= 7'b0011000;
            end
            7'b0011000: begin
                if (stop_add0 && stop_add1) begin
                    ops <= 5'b01000;
                    state <= 7'b0011001;
                end
            end

            // x = tx >> 900 ; y = ty >> 900
            // clear mx ; clear my
            7'b0011001: begin
                start_shift0 <= 1;
                start_shift1 <= 1;
                start_clear0 <= 1;
                start_clear1 <= 1;
                state <= 7'b0011010;
            end
            7'b0011010: begin
                start_shift0 <= 0;
                start_shift1 <= 0;
                start_clear0 <= 0;
                start_clear1 <= 0;
                state <= 7'b0011011;
            end
            7'b0011011: begin
                if (stop_shift0 && stop_shift1 && stop_clear0 && stop_clear1) begin
                    ops <= 5'b01001;
                    state <= 7'b0011100;
                end
            end

            // x = x + b ; y = y + b
            // clear mtx ; clear mty
            7'b0011100: begin
                start_const_add0 <= 1;
                start_const_add1 <= 1;
                // start_clear0 <= 1;
                // start_clear1 <= 1;
                state <= 7'b0011101;
            end
            7'b0011101: begin
                start_const_add0 <= 0;
                start_const_add1 <= 0;
                // start_clear0 <= 0;
                // start_clear1 <= 0;
                state <= 7'b0011110;
            end
            7'b0011110: begin
                if (stop_const_add0 && stop_const_add1) begin
                    ops <= 5'b01010;
                    state <= 7'b0011111;
                end
            end

            // compare x ? n // 01010
            7'b0011111: begin
                start_comp0 <= 1;
                state <= 7'b0100000;
            end
            7'b0100000: begin
                start_comp0 <= 0;
                state <= 7'b0100001;
            end
            7'b0100001: begin
                if (stop_comp0) begin
                    if (comp0_big) begin
                        ops <= 5'b01011;
                        state <= 7'b0100010;
                    end
                    else begin
                        ops <= 5'b01100;
                        state <= 7'b0100101;
                    end
                end
            end
            
            // x > n x = x - n // 01011
            7'b0100010: begin
                start_sub0 <= 1;
                state <= 7'b0100011;
            end
            7'b0100011: begin
                start_sub0 <= 0;
                state <= 7'b0100100;
            end
            7'b0100100: begin
                if (stop_sub0) begin
                    ops <= 5'b01010;
                    state <= 7'b0011111; // go again - im really afraid of having x > n and blowing the loop away
                end
            end

            // compare y ? n // 01100
            7'b0100101: begin
                start_comp0 <= 1;
                state <= 7'b0100110;
            end
            7'b0100110: begin
                start_comp0 <= 0;
                state <= 7'b0100111;
            end
            7'b0100111: begin
                if (stop_comp0) begin
                    if (comp0_big) begin
                        ops <= 5'b01101;
                        state <= 7'b0101000;
                    end
                    else begin
                        ops <= 5'b01110;
                        state <= 7'b0101011;
                    end
                end
            end

            // y > n y = y - n // 01101
            7'b0101000: begin
                start_sub0 <= 1;
                state <= 7'b0101001;
            end
            7'b0101001: begin
                start_sub0 <= 0;
                state <= 7'b0101010;
            end
            7'b0101010: begin
                if (stop_sub0) begin
                    ops <= 5'b01100;
                    state <= 7'b0100101; // go again
                end
            end

            // x = x & rm1 ; y = y & rm1
            // clear tx ; clear ty
            7'b0101011: begin
                start_clear_top0 <= 1;
                start_clear_top1 <= 1;
                start_clear0 <= 1;
                start_clear1 <= 1;
                state <= 7'b0101100;
            end
            7'b0101100: begin
                start_clear_top0 <= 0;
                start_clear_top1 <= 0;
                start_clear0 <= 0;
                start_clear1 <= 0;
                state <= 7'b0101101;
            end
            7'b0101101: begin
                if (stop_clear_top0 && stop_clear_top1 && stop_clear0 && stop_clear1) begin
                    ops <= 5'b01111;
                    state <= 7'b0101110;
                end
            end

            // yy = y
            7'b0101110: begin
                start_copy1 <= 1;
                state <= 7'b0101111;
            end
            7'b0101111: begin
                start_copy1 <= 0;
                state <= 7'b0110000;
            end
            7'b0110000: begin
                if (stop_copy1) begin
                    ops <= 5'b10000;
                    state <= 7'b0110001;
                end
            end

            // my = y * yy
            7'b0110001: begin
                start_m1 <= 1;
                state <= 7'b0110010;
            end
            7'b0110010: begin
                start_m1 <= 0;
                state <= 7'b0110011;
            end
            7'b0110011: begin
                if (stop_m1) begin
                    ops <= 5'b10001;
                    state <= 7'b0110100;
                end
            end

            // mty = my & rm1
            7'b0110100: begin
                start_copy1 <= 1;
                state <= 7'b0110101;
            end
            7'b0110101: begin
                start_copy1 <= 0;
                state <= 7'b0110110;
            end
            7'b0110110: begin
                if (stop_copy1) begin
                    ops <= 5'b10010;
                    state <= 7'b0110111;
                end
            end
            
            // ty = mty * np
            7'b0110111: begin
                start_m1 <= 1;
                state <= 7'b0111000;
            end
            7'b0111000: begin
                start_m1 <= 0;
                state <= 7'b0111001;
            end
            7'b0111001: begin
                if (stop_m1) begin
                    ops <= 5'b10011;
                    state <= 7'b0111010;
                end
            end

            // mty = ty & rm1
            7'b0111010: begin
                start_copy1 <= 1;
                state <= 7'b0111011;
            end
            7'b0111011: begin
                start_copy1 <= 0;
                state <= 7'b0111100;
            end
            7'b0111100: begin
                if (stop_copy1) begin
                    ops <= 5'b10100;
                    state <= 7'b0111101;
                end
            end

            // ty = mty * n
            7'b0111101: begin
                start_m1 <= 1;
                state <= 7'b0111110;
            end
            7'b0111110: begin
                start_m1 <= 0;
                state <= 7'b0111111;
            end
            7'b0111111: begin
                if (stop_m1) begin
                    ops <= 5'b10101;
                    state <= 7'b1000000;
                end
            end

            // ty = ty + my
            7'b1000000: begin
                start_add1 <= 1;
                state <= 7'b1000001;
            end
            7'b1000001: begin
                start_add1 <= 0;
                state <= 7'b1000010;
            end
            7'b1000010: begin
                if (stop_add1) begin
                    ops <= 5'b10110;
                    state <= 7'b1000011;
                end
            end

            // y = ty >> 900
            // clear my
            7'b1000011: begin
                start_shift1 <= 1;
                start_clear1 <= 1;
                state <=  7'b1000100;
            end
            7'b1000100: begin
                start_shift1 <= 0;
                start_clear1 <= 0;
                state <= 7'b1000101;
            end
            7'b1000101: begin
                if (stop_shift1 && stop_clear1) begin
                    ops <= 5'b10111;
                    state <= 7'b1000110;
                end
            end

            // y = y + b
            7'b1000110: begin
                start_const_add1 <= 1;
                state <= 7'b1000111;
            end
            7'b1000111: begin
                start_const_add1 <= 0;
                state <= 7'b1001000;
            end
            7'b1001000: begin
                if (stop_const_add1) begin
                    ops <= 5'b11000;
                    state <= 7'b1001001;
                end
            end

            // compare y ? n
            7'b1001001: begin
                start_comp0 <= 1;
                state <= 7'b1001010;
            end
            7'b1001010: begin
                start_comp0 <= 0;
                state <= 7'b1001011;
            end
            7'b1001011: begin
                if (stop_comp0) begin
                    if (comp0_big) begin
                        ops <= 5'b11001;
                        state <= 7'b1001100;
                    end
                    else begin
                        ops <= 5'b11010;
                        state <= 7'b1001111;
                    end
                end
            end

            // y = y - n
            7'b1001100: begin
                start_sub0 <= 1;
                state <= 7'b1001101;
            end
            7'b1001101: begin
                start_sub0 <= 0;
                state <= 7'b1001110;
            end
            7'b1001110: begin
                if (stop_sub0) begin
                    // ops <= 5'b11011;
                    ops <= 5'b11000;
                    state <= 7'b1001001;
                end
            end

            // x ? y
            7'b1001111: begin
                start_comp0 <= 1;
                state <= 7'b1010000;
            end
            7'b1010000: begin
                start_comp0 <= 0;
                state <= 7'b1010001;
            end
            7'b1010001: begin
                if (stop_comp0) begin
                    if (comp0_big) begin
                        ops <= 5'b11011;
                        state <= 7'b1010010;
                    end
                    else begin
                        ops <= 5'b11100;
                        state <= 7'b1010101;
                    end
                end
            end

            // diff = x - y
            7'b1010010: begin
                start_sub1 <= 1;
                state <= 7'b1010011;
            end
            7'b1010011: begin
                start_sub1 <= 0;
                state <= 7'b1010100;
            end
            7'b1010100: begin
                if (stop_sub1) begin
                    ops <= 5'b11101;
                    state <= 7'b1011000;
                end
            end

            // diff = y - x
            7'b1010101: begin
                start_sub1 <= 1;
                state <= 7'b1010110;
            end
            7'b1010110: begin
                start_sub1 <= 0;
                state <= 7'b1010111;
            end
            7'b1010111: begin
                if (stop_sub1) begin
                    ops <= 5'b11101;
                    state <= 7'b1011000;
                end
            end

            // gcd(diff, n)
            7'b1011000: begin
                start_gcd0 <= 1;
                state <= 7'b1011001;
            end
            7'b1011001: begin
                start_gcd0 <= 0;
                state <= 7'b1011010;
            end
            7'b1011010: begin
                if (stop_gcd0) begin
                    if (gcd0_dud) begin
                        state <= 7'b0000000;
                    end
                    else begin
                        ops <= 5'b11110;
                        state <= 7'b1011011;
                    end
                end
            end
            
            // send the number back, we actually got it
            7'b1011011: begin
                leds <= 4'b0000;
                top_factor_addr <= i;
                state <= 7'b1011100;
            end
            7'b1011100: begin
                uart_data <= factor[7:0];
                start_uart <= 1;
                state <= 7'b1011101;
            end
            7'b1011101: begin
                start_uart <= 0;
                state <= 7'b1011110;
            end
            7'b1011110: begin
                if (!busy_uart) begin
                    state <= 7'b1011111;
                    // if (i < 26) begin
                    //     state <= 7'b1011011;
                    // end
                    // else begin
                    //     state <= 7'b1011111;
                    // end
                end
            end
            7'b1011111: begin
                uart_data <= factor[15:8];
                start_uart <= 1;
                state <= 7'b1100000;
            end
            7'b1100000: begin
                start_uart <= 0;
                state <= 7'b1100001;
            end
            7'b1100001: begin
                if (!busy_uart) begin
                    state <= 7'b1100010;
                end
            end
            7'b1100010: begin
                uart_data <= factor[17:16];
                start_uart <= 1;
                state <= 7'b1100011;
            end
            7'b1100011: begin
                start_uart <= 0;
                state <= 7'b1100100;
            end
            7'b1100100: begin
                if (!busy_uart) begin
                    if (i < 26) begin
                        state <= 7'b1011011;
                    end
                    else begin
                        state <= 7'b1100101;
                    end
                end
            end
            7'b1100101: begin
                if (s == 50_000_000) begin
                    s <= 0;
                    i <= 0;
                    state <= 7'b1011011;
                end
                else begin
                    s <= s + 1;
                end
            end

            default: begin
                state <= 7'b0000000;
                // start_m0 <= 0;
                // ops <= 5'b00000;
            end
        endcase
    end

endmodule
