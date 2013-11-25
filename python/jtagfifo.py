class JTAGFIFOFullError(Exception):
    pass
class JTAGFIFOEmptyError(Exception):
    pass

class JTAGInputFIFO(object):
    def __init__(self, pin):
        assert(pin.source_width >= 1)
        assert(pin.probe_width == 1)
        databits = pin.source_width - 1
        self.pin = pin
        self.validflag = 1<<databits
    def enq(self, value):
        if self.pin.probe != 1:
            raise JTAGFIFOFullError()
        assert(value < self.validflag)
        self.pin.source = value  # avoid different wire delays from corrupting data
        self.pin.source = self.validflag | value
        
class JTAGOutputFIFO(object):
    def __init__(self, pin):
        assert(pin.source_width == 1)
        assert(pin.probe_width >= 1)
        databits = pin.probe_width - 1
        self.pin = pin
        self.validflag = 1<<databits
    def deq(self):
        probe_val = self.pin.probe
        if (probe_val & self.validflag) == 0:
            raise JTAGFIFOEmptyError()
        self.pin.source = 0
        self.pin.source = 1   # fifo.deq
        return probe_val & (~self.validflag)

        