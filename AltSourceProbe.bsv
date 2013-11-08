import NumConv::*;

// All our modules implement a register-like interface, but
// the read type (tr) can be different from the write type (tw)
interface AltSourceProbe#(type tr, type tw);
    method tr _read();
    method Action _write(tw v);
endinterface


// Low-level alt_sourceprobe wrapper.
// Its _write method needs to be enabled every cycle.
import "BVI" AltSourceProbe =
    module mkAltSourceProbe#(String id, tr initv) (AltSourceProbe#(tr, tw))
    provisos (Bits#(tr, sr), Bits#(tw, sw));
        parameter INSTANCE_ID = id;
        parameter SOURCE_WIDTH = valueOf(sr);
        parameter SOURCE_INITIAL_VALUE = " " +
            (valueOf(sr) > 0 ? toHex(pack(initv)) : "");
        parameter PROBE_WIDTH = valueOf(sw);

        method source _read();
        method _write(probe) enable((*inhigh*)EN);

        default_clock clk(source_clk, (*unused*)GATE);
        default_reset no_reset;

        schedule (_write) CF (_read); // in and out ports are independent
        schedule (_write) C (_write);
        schedule (_read) CF (_read);
    endmodule


// This implementation exposes a default value to the probe
// during every cycle on which _write is not enabled.
module mkAltSourceDProbe#(String id, tr initv, tw defv) (AltSourceProbe#(tr, tw))
provisos (Bits#(tr, sr), Bits#(tw, sw));
    AltSourceProbe#(tr, tw) child <- mkAltSourceProbe(id, initv);
    Wire#(tw) writeval <- mkDWire(defv);

    (* fire_when_enabled, no_implicit_conditions *)
    rule route_write;
        child <= writeval;
    endrule

    method Action _write(tw v);
        writeval <= v;
    endmethod

    method tr _read = child;
endmodule


// This implementation uses a registered probe,
// to hold the last value written to it.
module mkAltSourceRProbe#(String id, tr initv, tw defv) (AltSourceProbe#(tr, tw))
provisos (Bits#(tr, sr), Bits#(tw, sw));
    AltSourceProbe#(tr, tw) child <- mkAltSourceProbe(id, initv);
    Reg#(tw) writeval <- mkReg(defv);

    (* fire_when_enabled, no_implicit_conditions *)
    rule route_write;
        child <= writeval;
    endrule

    method Action _write(tw v);
        writeval <= v;
    endmethod

    method tr _read = child;
endmodule
