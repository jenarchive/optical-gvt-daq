from threading import Thread,Lock,Event
import socket
from interval_timer import IntervalTimer
import logging

class SMMUDPStreamHandler(Thread):
    def __init__(self,dest, port):
        Thread.__init__(self,daemon=True)
        self._data = UDPOutStructure()
        self._data_lock = Lock()
        self.sock = None
        self.dest = dest
        self.port = port
        self.freq = 10
        
        self.kill_switch = Event()
        self.log = logging.getLogger('SMM')
    
    @property
    def data(self):
        with self._data_lock:
            return self._data
    @data.setter
    def data(self,value):
        with self._data_lock:
            self._data = value
            
    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.connect((self.dest,self.port))
    
    def run(self):
        self.connect()
        self.log.info(f"Sending UDP Data to {(self.dest, self.port)}")
        for interval in IntervalTimer(1/self.freq):
            message = self.data.encode()
            self.sock.sendall(message)
            if self.kill_switch.is_set():
                break
        self.log.info(f"Stopping UDP Data to {(self.dest, self.port)}")
        
        
        
        
    

class UDPDataItem():
    def __init__(self,name:str,value):
        self.name = name
        self.value = value
    def encode(self):
        return (self.name+','+str(self.value)).encode('utf-8')

class UDPOutStructure:
    def __init__(self):
        self.project_path = UDPDataItem('Project','HARW_01')
        self.run_number = UDPDataItem('Run',0)
        self.polar_number = UDPDataItem('Polar',0)
        self.data_point_number = UDPDataItem('DP',0)
        self.sequence_number = UDPDataItem('Sequence',0)
        self.baro_pressure = UDPDataItem('Baro',0.0)
        self.tunnel_temperature = UDPDataItem('Temp',0.0)
        self.AoA = UDPDataItem('AlphaModel',0.0)
        self.corrected_AOA  = UDPDataItem('AlphaC',0.0)
        self.dyn_pressure  = UDPDataItem('Q0C',0.0)
        self.EAS  = UDPDataItem('Veas',0.0)
        self.v0_corrected  = UDPDataItem('V0C',0.0)
        self.M0_corrected  = UDPDataItem('M0C',0.0)
        self.Reynolds_corrected  = UDPDataItem('REC',0.0)
        self.static_pressure  = UDPDataItem('P0C',0.0)
        self.total_pressure  = UDPDataItem('PI0C',0.0)
        self.static_temperature  = UDPDataItem('T0C',0.0)
        self.blockage  = UDPDataItem('Blockage',0.0)
    
    def encode(self):
        message = b'D_USR_FLD_'
        for v in self.__dict__.values():
            if isinstance(v,UDPDataItem):
                message += v.encode()+b','
        return message + b'#'