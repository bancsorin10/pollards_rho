

// everything should be going in the montgomery domain
module pollard(
    input clk,
    input reset,
    output finish,
    output [127:0] d
);

    // default starting values for the pollard rho
    localparam xs = 2;
    localparam b  = 7;

    // precomputed defaults for r, r', n, n'
    parameter [127:0] n;
    parameter [127:0] np;
    parameter [127:0] r;
    parameter [127:0] rp;
    parameter [127:0] rm1;
    parameter [7:0] rs;

    reg [1:0] state;
    // 1. compute mx = x*x my = y*y
    // 2. compute tx = mx & rm1 * np
    //    same with ty = my & rm1 * np
    // 3. compute tx = tx & rm1 * n
    //    same with ty = ty & rm1 *n
    // 4. x = mx + tx
    //    y = my + ty
    // 5. x = x >> rs
    //    y = y >> rs
    // 6. x = (x + b) & rm1
    //    y = (y + b) & rm1
    // repeat some steps to get y again
    // check gcd between ...

    reg [255:0] x;
    reg [255:0] y;

    reg [255:0] mx;
    reg [255:0] my;

    always @(posedge clk) begin
        if (reset) begin
            state <= 0;
            x <= xs;
            y <= xs;
        end
        else begin
            case (state)
                2'b00: begin
                    state <= 2'b01;
                    mx <= x*x;
                    my <= y*y;
                end
                2'b01: begin
                    state <= 2'b10;
                end
                2'b10: begin
                    state <= 2'b11;
                end
                2'b11: begin
                    state <= 2'b00;
                end
                default: begin
                    state <= 0;
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
    output reg [3:0] leds
);

    wire [3:0] leds_rev;
    wire clk_slow;
    wire clk_fast;
    wire locked;
    wire [1:0] clk_out;

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

    always @* begin
        leds = ~leds_rev;
    end

endmodule
