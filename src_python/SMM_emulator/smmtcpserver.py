import sys
import socket
import selectors
import traceback
import logging
from numpy import nan

from SMM_emulator.clienthandler import ClientHandler
from threading import Thread,Event,Lock

class SMMTCPServer(Thread):
    def __init__(self, host, port):
        Thread.__init__(self,daemon=True)
        self.host = host
        self.port = port
        self.sel = selectors.DefaultSelector()
        self.lsock = None
        self.kill_switch = Event()
        self.log = logging.getLogger('SMM')
        self.clients = list()
        self.clients_lock = Lock()
        
        self.Notification = None
        self.Notification_lock = Lock()
        
    @property
    def ClientStates(self):
        return [c.State for c in self.clients]
        
    def run(self):
        self.connect()
        self.process_events()
        
    def connect(self):
        self.sel = selectors.DefaultSelector()
        self.lsock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.lsock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.lsock.bind((self.host, self.port))
        self.lsock.listen()
        self.log.info(f"Listening on {(self.host, self.port)}")
        self.lsock.setblocking(False)
        self.sel.register(self.lsock, selectors.EVENT_READ, data=None)
        
    def send_opcode(self,opcode,data):
        code = self.gen_opcode_message(opcode,data)
        for client in self.clients:
            client.IsReady = False
            client._send_buffer += code
        
        
    def gen_opcode_message(self,opcode,data):
        if data is nan or not data:
            return (opcode.ljust(10,'_')+"#").encode('utf-8') 
        else:
            return (opcode.ljust(10,'_')+str(data)+"#").encode('utf-8') 
        
    @property
    def Notification(self):
        # with self.Notification_lock:
        return self._Notification
    @Notification.setter
    def Notification(self,value):
        # with self.Notification_lock:
        self._Notification = value
            
    def accept_wrapper(self, sock):
        conn, addr = sock.accept()  # Should be ready to read
        self.log.info(f"Accepted connection from {addr}")
        conn.setblocking(False)
        def set_notification(notification):
            self.Notification = notification
        message = ClientHandler(self.sel, conn, addr,on_notify=set_notification)
        with self.clients_lock:
            self.clients.append(message)
        self.sel.register(conn, selectors.EVENT_READ | selectors.EVENT_WRITE, data=message)
        message._send_buffer = b'IDENTIFY__#'
        
    def process_events(self):
        while not self.kill_switch.is_set():
            events = self.sel.select(timeout=0.1)
            if events:
                for key, mask in events:
                    if key.data is None:
                        self.accept_wrapper(key.fileobj)
                    else:
                        message = key.data
                        try:
                            message.process_events(mask)
                        except RuntimeError:
                            self.log.error(f"Main: Error: Exception for {message.addr}:\n")
                            with self.clients_lock:
                                self.clients.remove(message)
                            message.close()
                        except Exception:
                            self.log.error(
                                f"Main: Error: Exception for {message.addr}:\n"
                                f"{traceback.format_exc()}"
                            )
                            with self.clients_lock:
                                self.clients.remove(message)
                            message.close()
        self.kill_switch.clear()
        self.sel.close()