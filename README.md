AltSourceProbe
==============

This repository contains a wrapper and a set of useful Bluespec modules for dealing with `altsource_probe`, a *megafunction* which can be used in hardware designs as a kind of communication bus to talk with a computer in a fashion *portable* across Altera FPGA devices.

This module is very suitable for debugging hardware designs or for communicating with slow data rates. If you are looking for something similar but capable of achieving higher data rates, please take a look at our [AlteraJtagUart](https://github.com/thotypous/alterajtaguart) module.

See the `AltSourceProbe.bsv` file for a brief description of the available modules.

The `ExampleSimple.bsv` file contains a simple example, which controls the DE2_70 board LEDs using JTAG.

The `ExampleFIFOs.bsv` file contains an example on using the `JtagGetPut.bsv` library, which can be particularly useful for debugging Bluespec atomic transactions or for transmitting general purpose data (though at slow data rates).

The `jtaghttpd.tcl` file consists of a simple HTTP server which can be used to talk with Altera JTAG devices in other languages besides TCL. Beware we are not experienced TCL coders. Just run the file using the `quartus_stp -t` interpreter to start the server. Please look at the comments at the beginning of the file for documentation.

The `python` directory contains some client code and some examples which can be used to communicate with the JTAG HTTP server using the Python language.
