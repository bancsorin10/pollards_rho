

module ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter init_file = "zero.txt"
)(
    input clk,
    input we,
    input [addr_width-1:0] addr,
    input [data_width-1:0] din,
    output reg [data_width-1:0] dout
);

    localparam mem_depth = 1 << addr_width;

    reg [data_width-1:0] mem [0:mem_depth-1];

    initial begin
        if (init_file != "") begin
            $readmemh(init_file, mem);
        end
    end

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout <= mem[addr];
    end
endmodule

// module extended_ram #(
//     parameter addr_width = 6,
//     parameter data_width = 18,
//     parameter init_file = ""
// )(
//     input clk,
//     input we,
//     input [addr_width-1:0] addr,
//     input [addr_width-1:0] offset,
//     input [data_width-1:0] din,
//     output reg [data_width-1:0] dout
// );
// 
//     localparam mem_depth = 1 << (addr_width + 1);
// 
//     reg [data_width-1:0] mem [0:mem_depth-1];
// 
//     initial begin
//         if (init_file != "") begin
//             $readmemh(init_file, mem);
//         end
//     end
// 
//     always @(posedge clk) begin
//         if (we) begin
//             mem[addr + offset] <= din;
//         end
//         dout <= mem[addr + offset];
//     end
// endmodule

module clear_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,
    output reg we,
    output reg stop,
    output reg [addr_width-1:0] addr,
    output reg [data_width-1:0] x
);
    localparam addr_size = 1 << addr_width;

    reg [7:0] s = 0;

    reg [1:0] state;

    always @(posedge clk) begin
        x <= 0;
        case (state)
            2'b00: begin
                if (start) begin
                    state <= 2'b01;
                    we <= 1;
                    addr <= 0;
                    s <= 1;
                    stop <= 0;
                end
            end
            2'b01: begin
                s <= s + 1;
                addr <= s;
                if (s == (addr_size - 1)) begin
                    state <= 2'b10;
                end
            end
            2'b10: begin
                we <= 0;
                stop <= 1;
                state <= 2'b00;
            end
            default: begin
                state <= 2'b00;
                s <= 0;
                stop <= 0;
                we <= 0;
            end
        endcase
    end

endmodule

module copy_ram #(
    parameter addr_width = 6,
    parameter addr_size_x = 1 << addr_width, // you don't always need to copy everything
    parameter data_width = 18
)(
    input clk,
    input start,

    output reg we,
    output reg [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,

    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg stop
);

    reg [2:0] state = 3'b000;
    reg [17:0] tmp = 0;
    reg [7:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    tmp <= 0;
                    s <= 0;
                    state <= 3'b001;
                    stop <= 0;
                end
            end
            3'b001: begin
                we <= 0;
                y_addr <= s;
                x_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                tmp <= y;
                state <= 3'b100;
            end
            3'b100: begin
                we <= 1;
                x <= tmp;
                s <= s + 1;
                if (s == (addr_size_x - 1)) begin
                    state <= 3'b101;
                end
                else begin
                    state <= 3'b001;
                end
            end
            3'b101: begin
                we <= 0;
                stop <= 1;
                state <= 3'b000;
            end
        endcase
    end

endmodule

module shift_ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter shift_count = 50 // 18*50 == 900 size of rs for my montgomery
)(
    input clk,
    input start,

    output reg we,
    output reg [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,

    input [data_width-1:0] y,
    output reg [addr_width:0] y_addr,

    output reg stop
);

    localparam addr_size = 1 << addr_width;

    reg [2:0] state = 3'b000;
    reg [17:0] tmp = 0;
    reg [7:0] sx = 0;
    reg [7:0] sy = shift_count;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    tmp <= 0;
                    sx <= 0;
                    sy <= shift_count;
                    state <= 3'b001;
                    stop <= 0;
                end
            end
            3'b001: begin
                we <= 0;
                x_addr <= sx;
                y_addr <= sy;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                tmp <= y;
                state <= 3'b100;
            end
            3'b100: begin
                we <= 1;
                x <= tmp;
                sx <= sx + 1;
                sy <= sy + 1;
                if (sx == (addr_size - 1)) begin
                    state <= 3'b101;
                end
                else begin
                    state <= 3'b001;
                end
            end
            3'b101: begin
                we <= 0;
                stop <= 1;
                state <= 3'b000;
            end
            default: begin
                we <= 0;
                stop <= 0;
                state <= 3'b000;
            end
        endcase
    end
endmodule

module inplace_shift_ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter shift_count = 50 // 18*50 == 900 size of rs for my montgomery
)(
    input clk,
    input start,

    output reg we,
    input [data_width-1:0] x,
    output reg [data_width-1:0] x_w,
    output reg [addr_width-1:0] x_addr,

    output reg stop
);
    localparam addr_size = 1 << addr_width;

    reg [2:0] state = 0;
    reg [data_width-1:0] tmp = 0;
    reg [addr_width-1:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    s <= 0;
                    tmp <= 0;
                    stop <= 0;
                    x_addr <= shift_count;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                // wait cycle
                state <= 3'b010;
            end
            3'b010: begin
                tmp <= x;
                x_w <= 0;
                we <= 1;
                state <= 3'b011;
            end
            3'b011: begin
                x_addr <= s;
                x_w <= tmp;
                // we <= 1;
                s <= s + 1;
                state <= 3'b100;
            end
            3'b100: begin
                we <= 0;
                if (s == (addr_size - 1)) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    x_addr <= s + shift_count;
                    state <= 3'b001;
                end
            end
        endcase
    end

endmodule

module full_add_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg we,
    output reg [data_width-1:0] res,
    output reg [addr_width-1:0] res_addr,

    output reg stop
);
    // add 2 ram blocks and store the result in the third

    localparam addr_size = 1 << addr_width;

    reg [data_width:0] temp;
    reg c = 0;
    reg [2:0] state = 0;
    reg [addr_width:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    c <= 0;
                    s <= 0;
                    we <= 0;
                    stop <= 0;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                y_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x+y+c;
                state <= 3'b100;
            end
            3'b100: begin
                c <= temp[data_width];
                // temp <= temp + c;
                state <= 3'b101;
            end
            3'b101: begin
                we <= 1;
                res <= temp;
                res_addr <= s;
                state <= 3'b110;
            end
            3'b110: begin
                we <= 0;
                s <= s+1;
                state <= 3'b111;
            end
            3'b111: begin
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
        endcase
    end

endmodule

module inplace_full_add_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    output reg we,
    input [data_width-1:0] x,
    output reg [data_width-1:0] x_w,
    output reg [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg stop
);
    // add 2 ram blocks and store the result in the third

    localparam addr_size = 1 << addr_width;

    reg [data_width:0] temp;
    reg c = 0;
    reg [2:0] state = 0;
    reg [addr_width:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    c <= 0;
                    s <= 0;
                    we <= 0;
                    stop <= 0;
                    temp <= 0;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                y_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x+y+c;
                state <= 3'b100;
            end
            3'b100: begin
                c <= temp[data_width];
                // temp <= temp + c;
                state <= 3'b101;
            end
            3'b101: begin
                we <= 1;
                x_w <= temp;
                state <= 3'b110;
            end
            3'b110: begin
                we <= 0;
                s <= s+1;
                state <= 3'b111;
            end
            3'b111: begin
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
        endcase
    end

endmodule

module inplace_constant_add_ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter b = 7 // constant for addition
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output reg [data_width-1:0] x_w,
    output reg [addr_width-1:0] x_addr,
    output reg we,

    output reg stop
);

    localparam addr_size = 1 << addr_width;

    reg [addr_width:0] s = 0;
    reg [2:0] state = 0;
    reg [data_width:0] temp;
    reg [7:0] a = b;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    s <= 0;
                    we <= 0;
                    temp <= 0;
                    stop <= 0;
                    a <= b;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x + a;
                state <= 3'b100;
            end
            3'b100: begin
                we <= 1;
                x_w <= temp;
                s <= s + 1;
                a <= temp[data_width];
                state <= 3'b101;
            end
            3'b101: begin
                we <= 0;
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
            default: begin
                we <= 0;
                stop <= 0;
                state <= 3'b000;
            end
        endcase
    end
endmodule

module constant_add_ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter b = 7 // constant for addition
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,

    output reg we,
    output reg [data_width-1:0] res,
    output reg [addr_width-1:0] res_addr,

    output reg stop
);

    localparam addr_size = 1 << addr_width;

    reg [addr_width:0] s = 0;
    reg [2:0] state = 0;
    reg [data_width:0] temp;
    reg [7:0] a = b;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    s <= 0;
                    we <= 0;
                    temp <= 0;
                    stop <= 0;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x + a;
                state <= 3'b100;
            end
            3'b100: begin
                we <= 1;
                res <= temp;
                res_addr <= s;
                s <= s + 1;
                a <= temp[data_width];
                state <= 3'b101;
            end
            3'b101: begin
                we <= 0;
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
            default: begin
                we <= 0;
                stop <= 0;
                state <= 3'b000;
            end
        endcase
    end
endmodule

module compare_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg stop,
    output reg big,
    output reg eq
);

    localparam addr_size = 1 << addr_width;

    reg [2:0] state = 0;
    reg [addr_width:0] s = addr_size-1;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    stop <= 0;
                    big <= 0;
                    eq <= 0;
                    s <= addr_size-1;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                y_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // waiting cycle
                state <= 3'b011;
            end
            3'b011: begin
                if (x == y) begin
                    if (s == 0) begin
                        eq <= 1;
                        stop <= 1;
                        state <= 3'b000;
                    end
                    else begin
                        s <= s - 1;
                        state <= 3'b001;
                    end
                end
                else begin
                    state <= 3'b100;
                end
            end
            3'b100: begin
                if (x > y) begin
                    big <= 1;
                end
                stop <= 1;
                state <= 3'b000;
            end
            default: begin
                stop <= 0;
                state <= 3'b000;
            end
        endcase
    end
endmodule

module full_sub_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    input [data_width-1:0] x,
    output reg [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg we,
    output reg [data_width-1:0] res,
    output reg [addr_width-1:0] res_addr,

    output reg stop
);
    // add 2 ram blocks and store the result in the third

    localparam addr_size = 1 << addr_width;

    reg [data_width:0] temp;
    reg c = 0;
    reg [2:0] state = 0;
    reg [addr_width:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    c <= 0;
                    s <= 0;
                    we <= 0;
                    stop <= 0;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                y_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x-y-c;
                state <= 3'b100;
            end
            3'b100: begin
                c <= temp[data_width];
                // temp <= temp - c;
                state <= 3'b101;
            end
            3'b101: begin
                we <= 1;
                res <= temp;
                res_addr <= s;
                state <= 3'b110;
            end
            3'b110: begin
                we <= 0;
                s <= s+1;
                state <= 3'b111;
            end
            3'b111: begin
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
        endcase
    end
endmodule

module inplace_full_sub_ram #(
    parameter addr_width = 6,
    parameter data_width = 18
)(
    input clk,
    input start,

    output reg we,
    input [data_width-1:0] x,
    output reg [data_width-1:0] x_w,
    output reg [addr_width-1:0] x_addr,
    input [data_width-1:0] y,
    output reg [addr_width-1:0] y_addr,

    output reg stop
);
    // add 2 ram blocks and store the result in the third

    localparam addr_size = 1 << addr_width;

    reg [data_width:0] temp;
    reg c = 0;
    reg [2:0] state = 0;
    reg [addr_width:0] s = 0;

    always @(posedge clk) begin
        case (state)
            3'b000: begin
                if (start) begin
                    c <= 0;
                    s <= 0;
                    we <= 0;
                    x_w <= 0;
                    stop <= 0;
                    state <= 3'b001;
                end
            end
            3'b001: begin
                x_addr <= s;
                y_addr <= s;
                state <= 3'b010;
            end
            3'b010: begin
                // wait cycle
                state <= 3'b011;
            end
            3'b011: begin
                temp <= x-y-c;
                state <= 3'b100;
            end
            3'b100: begin
                c <= temp[data_width];
                // temp <= temp - c;
                state <= 3'b101;
            end
            3'b101: begin
                we <= 1;
                x_w <= temp;
                state <= 3'b110;
            end
            3'b110: begin
                we <= 0;
                s <= s+1;
                state <= 3'b111;
            end
            3'b111: begin
                if (s == addr_size) begin
                    stop <= 1;
                    state <= 3'b000;
                end
                else begin
                    state <= 3'b001;
                end
            end
        endcase
    end
endmodule

module clear_top_ram #(
    parameter addr_width = 6,
    parameter data_width = 18,
    parameter clear_index = 50 // will clear everything above this
)(
    input clk,
    input start,

    output reg we,
    output reg [data_width-1:0] x_w,
    output reg [addr_width-1:0] x_addr,

    output reg stop
);
    localparam addr_size = 1 << addr_width;

    reg [7:0] s = 0;

    reg [1:0] state;

    always @(posedge clk) begin
        x_w <= 0;
        case (state)
            2'b00: begin
                if (start) begin
                    state <= 2'b01;
                    we <= 1;
                    x_addr <= clear_index;
                    s <= clear_index + 1;
                    stop <= 0;
                end
            end
            2'b01: begin
                s <= s + 1;
                x_addr <= s;
                if (s == (addr_size - 1)) begin
                    state <= 2'b10;
                end
            end
            2'b10: begin
                we <= 0;
                stop <= 1;
                state <= 2'b00;
            end
            default: begin
                state <= 2'b00;
                s <= 0;
                stop <= 0;
                we <= 0;
            end
        endcase
    end
endmodule
