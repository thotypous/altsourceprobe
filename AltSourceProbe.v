module AltSourceProbe (probe, source_clk, source);

    parameter INSTANCE_ID = "";
    parameter SOURCE_WIDTH = 0;
    parameter SOURCE_INITIAL_VALUE = " ";
    parameter PROBE_WIDTH = 0;

    input  [ PROBE_WIDTH-1:0] probe;
    input                     source_clk;
    output [SOURCE_WIDTH-1:0] source;
    
    altsource_probe altsource_probe_component (
        .probe (probe),
        .source_clk (source_clk),
        .source (source)
        // synopsys translate_off
        ,
        .clrn (),
        .ena (),
        .ir_in (),
        .ir_out (),
        .jtag_state_cdr (),
        .jtag_state_cir (),
        .jtag_state_e1dr (),
        .jtag_state_sdr (),
        .jtag_state_tlr (),
        .jtag_state_udr (),
        .jtag_state_uir (),
        .raw_tck (),
        .source_ena (),
        .tdi (),
        .tdo (),
        .usr1 ()
        // synopsys translate_on
        );
    defparam
        altsource_probe_component.enable_metastability = "YES",
        altsource_probe_component.instance_id = INSTANCE_ID,
        altsource_probe_component.probe_width = PROBE_WIDTH,
        altsource_probe_component.sld_auto_instance_index = "YES",
        altsource_probe_component.sld_instance_index = 0,
        altsource_probe_component.source_initial_value = SOURCE_INITIAL_VALUE,
        altsource_probe_component.source_width = SOURCE_WIDTH;

endmodule
