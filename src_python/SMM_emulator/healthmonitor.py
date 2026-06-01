import selectors
import logging
from threading import Thread,Event,Lock,Timer
import selectors
import socket
import traceback

request_search = {
    "morpheus": "Follow the white rabbit. \U0001f430",
    "ring": "In the caves beneath the Misty Mountains. \U0001f48d",
    "\U0001f436": "\U0001f43e Playing ball! \U0001f3d0",
}

class HealthMonitor(Thread):
    def __init__(self, port, isLoopback=False):
        Thread.__init__(self,daemon=True)
        self.selector = selectors.DefaultSelector()
        self.kill_switch = Event()
        
        self._isAlive = False
        self._isAlive_lock = Lock()
        
        if isLoopback:
            self.host = '127.0.0.1'
        else:
            self.host = socket.gethostname()
        self.port = port
        self.sock = None
        self._recv_buffer = b""
        
        self._raw_data = None
        self._data = None
        self._data_lock = Lock()
        
        self._heartbeat_timer = Timer(15,self.on_no_heartbeat)
        self._heartbeat_counter = 0
        
        self.log = logging.getLogger('SMM')
        self.Name = 'HARW'
    
    @property
    def data(self):
        with self._data_lock:
            return self._data
    @data.setter
    def data(self,value):
        with self._data_lock:
            self._data = value
            
    @property
    def IsAlive(self):
        with self._isAlive_lock:
            return self._isAlive
    @IsAlive.setter
    def IsAlive(self,value):
        with self._isAlive_lock:
            self._isAlive = value
    
    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        print((self.host, self.port))
        self.sock.bind((self.host, self.port))
        self.sock.setblocking(False)
        #sort out heartbeat timer
        self.IsAlive = False
        # self._heartbeat_timer = Timer(15,self.on_no_heartbeat)
        # self._heartbeat_timer.start()
        # register selector
        self.selector.register(self.sock, selectors.EVENT_READ, data=self)
        
    def on_no_heartbeat(self):
        self.IsAlive = False
        self.log.warning(f'Health Monitor: No heartbeat from HARW')
        
    def run(self):
        self.connect()
        self.process_events()
    
    def process_events(self):
        while not self.kill_switch.is_set():
            events = self.selector.select(timeout=0.1)
            if events:
                try:
                    self.read()
                except RuntimeError:
                    self.log.error(f"Main: Error: Exception for Health Monitor:\n")
                    
                except Exception:
                    self.log.error(
                        f"Main: Error: Exception for Health Monitor:\n"
                        f"{traceback.format_exc()}"
                    )
        self.sock.close()
        self.kill_switch.clear()
        self.selector.close()

    def _read(self):
        try:
            # Should be ready to read
            data = self.sock.recv(4096)
        except BlockingIOError:
            # Resource temporarily unavailable (errno EWOULDBLOCK)
            pass
        else:
            if data:
                self._recv_buffer += data
            else:
                raise RuntimeError("Peer closed.")

    def read(self):
        self._read()
        self.process_data()
        if self._raw_data is not None:
            self.process_request()

    def close(self):
        self.log.info(f"Closing connection to {self.addr}")
        try:
            self.selector.unregister(self.sock)
        except Exception as e:
            self.log.error(
                f"Error: selector.unregister() exception for "
                f"{self.addr}: {e!r}"
            )

        try:
            self.sock.close()
        except OSError as e:
            self.log.error(f"Error: socket.close() exception for {self.addr}: {e!r}")
        finally:
            # Delete reference to socket object for garbage collection
            self.sock = None

    def process_opcode(self):
        if len(self._recv_buffer) >= self.opcode_len:
            self.opcode = self._recv_buffer[:self.opcode_len]
            self._recv_buffer = self._recv_buffer[self.opcode_len:]

    def process_data(self):
        if self._recv_buffer[-1] == b'#'[0]:
            self._raw_data = self._recv_buffer[:-1]
            self._recv_buffer = b''
    def process_request(self):
        _raw = self._raw_data 
        self._raw_data = None   
        items = _raw[10:-2].split(b',')
        self.data = dict(zip([k.decode('utf-8') for k in items[0:-2:2]],[float(v) for v in items[1:-1:2]]))
        # deal with heartbeat timer
        self._heartbeat_counter += 1
        if not self.IsAlive:
            self.IsAlive = True
            self.log.info(f'Health Monitor: Heartbeat found from HARW')
        if self._heartbeat_counter >= 10:
            self.log.debug(f'Health Heartbeat, last message: {_raw}')
            self._heartbeat_counter = 0
            if self._heartbeat_timer.is_alive():
                self._heartbeat_timer.cancel()
            self._heartbeat_timer = Timer(15,self.on_no_heartbeat)
            self._heartbeat_timer.start()