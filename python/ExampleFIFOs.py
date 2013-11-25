#!/usr/bin/python3
import jtaghttpclient, jtagfifo

jtag = jtaghttpclient.JTAGServer()
devices = list(jtag.iter_devices(['IN', 'OUT']))

for dev in devices:
    infifo = jtagfifo.JTAGInputFIFO(dev['IN'])
    outfifo = jtagfifo.JTAGOutputFIFO(dev['OUT'])
    for i in range(11):
        infifo.enq(i)
    try:
        infifo.enq(0)
        assert(False)  # should not be reached
    except jtagfifo.JTAGFIFOFullError:
        pass
    for i in range(11):
        val = outfifo.deq()
        assert(val == i)
    try:
        outfifo.deq()
        assert(False)  # should not be reached
    except jtagfifo.JTAGFIFOEmptyError:
        pass
    print('OK: '+repr(dev))
