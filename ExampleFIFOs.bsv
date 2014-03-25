import JtagGetPut::*;
import SpecialFIFOs::*;
import Connectable::*;

typedef Bit#(8) Byte;

(* synthesize, clock_prefix="CLOCK_50", reset_prefix="RST_N" *)
module mkExample(Empty);
    Get#(Byte) byteIn <- mkJtagGet("IN", mkSizedFIFOF(10));
    Put#(Byte) byteOut <- mkJtagPut("OUT", mkPipelineFIFOF);
    mkConnection(byteIn, byteOut);
endmodule
