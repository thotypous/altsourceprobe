// Example for the DE2 70 board
//
// Should be trivial to port to other devices,
// just adapt the pin assignments and the number
// of bits

import AltSourceProbe::*;

interface Example;
    (* result="LEDG", always_ready *)
    method Bit#(9) ledg;
endinterface

(* synthesize, clock_prefix="CLOCK_50", reset_prefix="RST_N" *)
module mkExample(Example);
    AltSourceProbe#(Bit#(9), Bit#(0)) jtag <- mkAltSourceDProbe("LEDG", 0, ?);
    method Bit#(9) ledg = jtag;
endmodule
