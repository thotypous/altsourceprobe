AltSourceProbe
==============

This repository contains a wrapper and a set of useful Bluespec modules for dealing with `alt_sourceprobe`, a feature  which can be used in hardware designs as a kind of communication bus to talk with a computer in a fashion *portable* across Altera FPGA devices.

See the `AltSourceProbe.bsv` file for a brief description of the available modules.

The `Example.bsv` file contains a simple example, which controls the DE2_70 board LEDs using JTAG.

The `jtaghttpd.tcl` file consists of a simple HTTP server which can be used to talk with Altera JTAG devices in other languages besides TCL. Beware we are not experienced TCL coders. Just run the file using the `quartus_stp -t` interpreter to start the server. Please look at the comments at the beginning of the file for documentation.
