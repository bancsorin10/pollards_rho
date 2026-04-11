

# intro

This is a verilog implementation of the pollards rho.

This POC is factoring in the number `323 == 17*19` and sends the result over
uart.

The implementation uses worded comba multiplication in order to try and reduce
the area. The multiplications are done in the Montgomery domain as to avoid
doing divisions.
