import urllib3, json

class JTAGServerResponseError(Exception):
    def __init__(self, r):
        self.r = r
    def __str__(self):
        return 'JTAGServerResponseError(%d, %s)' % (self.r.status, repr(self.r.data))
    
class JTAGError(Exception):
    def __init__(self, obj):
        self.obj = obj
    def __str__(self):
        return 'JTAGError(%s)' % repr(self.obj)
    
class FallbackDict(dict):
    def __init__(self):
        super(FallbackDict, self).__init__()
        self._fallback = {}
    def _set(self, id, name, obj):
        self[id] = obj
        self._fallback[name] = obj
    def clear(self):
        super(FallbackDict, self).clear()
        self._fallback.clear()
    def __getitem__(self, key):
        if key in self:
            return super(FallbackDict, self).__getitem__(key)
        return self._fallback[key]

class JTAGServerDir(FallbackDict):
    def update(self):
        self.clear()
        response = self.request('/')
        if 'error' in response:
            return # a dict with an error is returned when the device does not contain source/probes
        for id, name in response.items():
            id = int(id)
            self._set(id, name, self._childclass(self, id, name))   
            
class JTAGServerSubDir(JTAGServerDir):
    def __init__(self, parent, id, name):
        super(JTAGServerDir, self).__init__()
        self.parent = parent
        self.id = id
        self.name = name
        self.update()
    def request(self, path):
        return self.parent.request('/%d%s'% (self.id, path))
    def __repr__(self):
        return '%s(%s, %s)' % (self.__class__.__name__, repr(self.name), dict.__repr__(self)) 

class JTAGServer(JTAGServerDir):
    def __init__(self, server='localhost:8000'):
        super(JTAGServer, self).__init__()
        self.pool = urllib3.PoolManager(num_pools=1)
        if server.endswith('/'):
            server = server[:-1]
        if not server.startswith('http://'):
            server = 'http://' + server
        self.server = server
        self._childclass = JTAGHardware
        self.update()
    def request(self, path):
        r = self.pool.request('GET', self.server + path)
        if r.status != 200:
            raise JTAGServerResponseError(r)
        return json.loads(r.data.decode('utf-8'))
    def iter_devices(self, instance_names):
        """ Iterate over devices containing all instance_names """
        for hw in self.values():
            for dev in hw.values():
                if not False in [inst in dev._fallback for inst in instance_names]:
                    yield dev
        
class JTAGInstance(object):
    def __init__(self, parent, id, info):
        super(JTAGInstance, self).__init__()
        self.parent = parent
        self.id = id
        self.name = info[0]
        self.source_width, self.probe_width = map(int, info[1:])
    def __repr__(self):
        return 'JTAGInstance(%s, source[%d], probe[%d])' % (
            repr(self.name), self.source_width, self.probe_width)
    def request(self, path):
        return self.parent.request('/%d%s'% (self.id, path))
    def __setattr__(self, name, value):
        if name == 'source':
            response = self.request('/%x' % value)
            if response != 'ok':
                raise JTAGError(response)
        elif name == 'probe':
            raise KeyError('probe cannot be set')
        else:
            super(JTAGInstance, self).__setattr__(name, value)
    def __getattr__(self, name):
        if name == 'source':
            response = self.request('/cur')
        elif name == 'probe':
            response = self.request('/get')
        else:
            return super(JTAGInstance, self).__getattr__(name)
        if isinstance(response, dict):
            raise JTAGError(response)
        if response == '':
            return 0
        return int(response, 16)
        
class JTAGDevice(JTAGServerSubDir):
    _childclass = JTAGInstance
    def _set(self, id, info, obj):
        name = info[0]
        super(JTAGDevice, self)._set(id, name, obj)
        
class JTAGHardware(JTAGServerSubDir):
    _childclass = JTAGDevice
