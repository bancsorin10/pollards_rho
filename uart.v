// we'll do one stop bit, single bit per character, 8 characters
// setting uart by stty -F /dev/ttyS0 115200 -parenb -cstopb cs8
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

module uart_receive(
    input clk,
    input reset,
    input rx,
    output reg [7:0] data,
    output reg ready
);
    parameter FREQ = 25_000_000;
    parameter BAUD = 115_200;
    localparam PERIOD = FREQ / BAUD;

    reg [3:0] bit;
    reg [7:0] counter;
    reg [7:0] buffer;

    always @(posedge clk) begin
        if (reset) begin
            bit     <= 0;
            ready   <= 0;
            counter <= 0;
        end
        else if (rx == 0 && bit == 0) begin
            bit     <= 1;
            // counter <= -PERIOD/2;
            counter <= 0;
            ready   <= 0;
        end
        else if (bit > 0) begin
            if (counter < PERIOD - 1) begin
                counter <= counter + 1;
            end
            else begin
                counter <= 0;
                if (bit < 9) begin
                    buffer[bit - 1] <= rx;
                    bit <= bit + 1;
                end
                // else if (bit == 9) begin
                //     bit <= bit + 1; // wait one more
                // end
                else begin
                    bit   <= 0;
                    data  <= buffer;
                    ready <= 1;
                end
            end
        end
    end
endmodule
