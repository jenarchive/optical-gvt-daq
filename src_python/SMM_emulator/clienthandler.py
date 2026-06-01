import sys
import selectors
import json
import io
import struct
import logging
import threading
import time

request_search = {
    "morpheus": "Follow the white rabbit. \U0001f430",
    "ring": "In the caves beneath the Misty Mountains. \U0001f48d",
    "\U0001f436": "\U0001f43e Playing ball! \U0001f3d0",
}


class ClientHandler:
    def __init__(self, selector, sock, addr, on_notify=None):
        self.selector = selector
        self.sock = sock
        self.addr = addr
        self._recv_buffer = b""
        self._recv_buffer_idx = 0
        self._send_buffer = b""
        self.opcode_len = 10
        self.opcode = None
        self.data = None
        self.log = logging.getLogger('SMM')
        self.Name = 'Unknown'
        self._isReady = False
        self._isReady_lock = threading.Lock()
        self.on_notify = on_notify
        
    @property
    def State(self):
        return (self.Name,self.IsReady)
        
    @property
    def IsReady(self):
        with self._isReady_lock:
            return self._isReady
    @IsReady.setter
    def IsReady(self,value):
        with self._isReady_lock:
            self._isReady = value

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

    def _write(self):
        if self._send_buffer:
            self.log.info(f"Sending {self._send_buffer!r} to {self.addr}")
            try:
                # Should be ready to write
                sent = self.sock.send(self._send_buffer)
            except BlockingIOError:
                # Resource temporarily unavailable (errno EWOULDBLOCK)
                pass
            else:
                self._send_buffer = self._send_buffer[sent:]

    def process_events(self, mask):
        if mask & selectors.EVENT_READ:
            self.read()
        if mask & selectors.EVENT_WRITE:
            self.write()

    def read(self):
        self._read()
        if self.opcode is None:
            self.process_opcode()

        if self.opcode is not None:
            self.process_data()
            if self.data is not None:
                self.process_request()

    def write(self):
        self._write()

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
        for i in range(self._recv_buffer_idx,len(self._recv_buffer)):
            if self._recv_buffer[i] == b'#'[0]:
                self.data = self._recv_buffer[:(i)]
                self._recv_buffer = self._recv_buffer[(i+1):]
                self._recv_buffer_idx = 0
                break
            self._recv_buffer_idx += 1
        
    def process_request(self):
        # call callback
        # print(self.opcode)
        # print(self.on_notify is not None)
        # print(self.opcode is eq b'ADVISE_MSG')
        if self.on_notify is not None and self.opcode == b'ADVISE_MSG':
            self.on_notify(self.data.decode("utf-8"))
        # raise log
        if self.Name == 'Unknown':
            self.log.info(f'Recieved OPCODE: {self.opcode}, from {self.addr}, with DATA: {self.data}')
        else:
            self.log.info(f'Recieved OPCODE: {self.opcode}, from {self.Name}, with DATA: {self.data}')        
        # process opcode    
        match self.opcode:
            case b'IDENTITY__':
                self.Name = self.data.decode("utf-8")
                self.IsReady = True
            case b'READY_____':
                self.IsReady = True
            case _:
                pass
        self.opcode = None
        self.data = None