#!/usr/bin/python3
import jtaghttpclient

jtag = jtaghttpclient.JTAGServer()
devices = list(jtag.iter_devices(['LEDG']))

while True:
    for dev in devices:
        dev['LEDG'].source = 0x55
        dev['LEDG'].source = 0xAA
