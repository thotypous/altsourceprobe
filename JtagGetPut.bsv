import AltSourceProbe::*;
import GetPut::*;
export GetPut::*;
import FIFOF::*;
export FIFOF::*;

export mkJtagGet;
export mkJtagPut;

module mkJtagGet#(String instance_name, module#(FIFOF#(a)) mkFIFOF)(Get#(a))
provisos (Bits#(Maybe#(a), sma), Bits#(a, sa));
    FIFOF#(a) fifo <- mkFIFOF;
    AltSourceProbe#(Maybe#(a), Bool) jtag <- mkAltSourceDProbe(instance_name, tagged Invalid, fifo.notFull);
    Reg#(Bool) last_valid <- mkReg(True);
    rule upd_reg;
        last_valid <= isValid(jtag);
    endrule
    rule feed_fifo(!last_valid &&& jtag matches tagged Valid .val);
        fifo.enq(val);
    endrule
    return toGet(fifo);
endmodule

module mkJtagPut#(String instance_name, module#(FIFOF#(a)) mkFIFOF)(Put#(a))
provisos (Bits#(Maybe#(a), sma), Bits#(a, sa));
    FIFOF#(a) fifo <- mkFIFOF;
    AltSourceProbe#(Bool, Maybe#(a)) jtag <- mkAltSourceProbe(instance_name, False);
    Reg#(Bool) last_val <- mkReg(False);
    rule upd_reg;
        last_val <= jtag;
    endrule
    rule deq_fifo(!last_val && jtag);
        fifo.deq;
    endrule
    rule out_fifo_val(fifo.notEmpty);
        jtag <= tagged Valid fifo.first;
    endrule
    rule out_fifo_inval(!fifo.notEmpty);
        jtag <= tagged Invalid;
    endrule
    return toPut(fifo);
endmodule
