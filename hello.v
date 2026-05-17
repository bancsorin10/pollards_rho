module test(
    input clk,
    output reg j,
    output reg x_addr
);
    integer s = 0;
    reg c = 0;
    always @(posedge clk) begin
        x_addr <= 0;
        if (c == 0) begin
            j <= 0;
            c <= 1;
        end
        else begin
            s <= s+1;
            if (s == 50_000_000) begin
                j <= ~j;
                s <= 0;
            end
        end
    end

endmodule

module hello(
    input clk,
    input reset,
    output reg [3:0] leds
);

    integer i;

    wire [17:0] x;
    wire [5:0] x_addr;
    wire [5:0] test_x_addr;
    reg [5:0] top_x_addr;
    wire we;
    wire [17:0] x_w;

    wire j;

    assign x_addr = (j == 0) ? top_x_addr : test_x_addr;

    ram #(
        .init_file("test_ram.txt")
    ) r0 (
        .clk(clk),
        .we(we),
        .addr(x_addr),
        .din(x_w),
        .dout(x)
    );

    test t0(
        .clk(clk),
        .j(j),
        .x_addr(test_x_addr)
    );


    always @(posedge clk) begin
        top_x_addr <= 1;
        if (leds != x[3:0]) begin
            leds <= x;
        end
    end

endmodule

