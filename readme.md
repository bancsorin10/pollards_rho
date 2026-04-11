

# intro

This is a verilog implementation of the pollard's rho. This uses comba
multiplication and try factor the RSA 896 (google the rsa factoring challenge).

Some additions are being restructured to go over multiple cycles as to try and
reduce the area.

The main problem this faces is still the area, as this multiplies 1024 bits
numbers and the cyclone 10 LP that I've been using only has 6.7k LUTs. For the
basic 323 factoring this worked as comba multiplication reduced the area from
90k to only about 5k LUTs, but trying to factor the rsa 896 is quite a
challenge.

Going further I'll be trying to move from the cyclone 10 lp to a cyclone 5 from
a DE10-nano board and see if the design fits.
