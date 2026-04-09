// we'll do one stop bit, single bit per character, 8 characters
// setting uart by stty -F /dev/ttyS0 115200 -parenb -cstopb cs8
// better stty -F /dev/ttyUSB0 115200 raw -echo -ixon -ixoff -crtscts
module uart_transmit(
    input clk,
    input reset,
    input start,
    input [7:0] data,
    output reg tx,
    output reg busy
);

    parameter FREQ = 25_000_000;
    parameter BAUD = 115_200;
    localparam PERIOD = FREQ / BAUD;

    reg [3:0] bit;
    // for 25MHz and 115200 baud we should do about 217 so 8 bits should be
    // enough
    reg [7:0] counter;
    // reg [7:0] in_data;

    initial begin
        tx <= 1; // idle
    end

    always @(posedge clk) begin
        if (reset) begin
            tx      <= 1;
            bit     <= 0;
            busy    <= 0;
            counter <= 0;
        end
        else if (start && !busy) begin
            busy <= 1;
            tx <= 0; // start bit
            counter <= 0;
            bit <= 0;
        end
        else if (busy) begin
            if (counter < PERIOD - 1) begin
                counter <= counter + 1;
            end
            else begin
                counter <= 0;

                if (bit < 8) begin
                    tx  <= data[bit];
                    bit <= bit + 1;
                end
                else if (bit == 8) begin
                    tx <= 1; // stop bit
                    bit <= bit + 1;
                end
                else begin
                    busy <= 0;
                end
            end
        end
    end
endmodule

// send number over UART every 2 seconds, expected clk 25MHz
// this is expected to be used after a really long computation to constantly
// output the result
module send_number(
    input clk,
    input reset,
    input [1023:0] x,
    input start,
    output tx
);

    reg [7:0] data;
    reg start_tx;
    reg [1:0] state;
    reg [1023:0] xx;

    wire busy;

    integer s;


    uart_transmit send0(
        .clk(clk),
        .reset(reset),
        .start(start_tx),
        .data(data),
        .tx(tx),
        .busy(busy)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= 2'b00;
            xx <= x;
            start_tx <= 0;
            s <= 0;
        end
        else if (start) begin
            case (state)
                2'b00: begin
                    if (start) begin
                        xx <= x;
                        state <= state + 1;
                        start_tx <= 0;
                    end
                end
                2'b01: begin
                    if ((start_tx) && (!busy)) begin
                        // account for the 1 cycle latency between starting
                        // and being busy
                    end
                    else if ((xx > 0) && (!busy)) begin
                        data <= xx[7:0];
                        xx <= xx >> 8;
                        start_tx <= 1;
                    end
                    else if (busy) begin
                        start_tx <= 0;
                    end
                    else if ((xx == 0) && (!busy)) begin
                        state <= state + 1;
                    end
                end
                2'b10: begin
                    if (s < 50_000_000) begin
                        s <= s + 1;
                    end
                    else begin
                        s <= 0;
                        state <= 0;
                    end
                end
                default: begin
                    state <= 0;
                    start_tx <= 0;
                end
            endcase
        end
    end
endmodule
