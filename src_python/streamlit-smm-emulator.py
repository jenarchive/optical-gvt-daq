import streamlit as st
import time
import logging
import pandas as pd
from src_python.notifier import notify
from SMM_emulator.smmtcpserver import SMMTCPServer
from SMM_emulator.healthmonitor import HealthMonitor
from SMM_emulator.udp2harw import SMMUDPStreamHandler
from streamlit.runtime.scriptrunner import add_script_run_ctx
from streamlit.elements.utils import _shown_default_value_warning
_shown_default_value_warning = True

st.session_state.trigger_opcode = True

## get logger
class LogHandler(logging.Handler):
    def __init__(self):
        logging.Handler.__init__(self)
        self.log = list()
        self.last_warning = None
    def emit(self, record):
        self.log.insert(0,self.format(record))
        if record.levelno>20:
            self.last_warning = self.format(record)
        notify()
    def clear(self):
        self.log.clear()
    def getvalue(self):
        return '\n'.join(self.log)

@st.cache_resource
def get_logger():
    logging.basicConfig(level = logging.INFO)
    smm_logger = logging.getLogger('SMM')
    smm_logger.propagate = False
    # add commandline handler
    cmd_handler = logging.StreamHandler()
    log_formatter = logging.Formatter('%(asctime)s - %(message)s', datefmt='[%d-%b-%y %H:%M:%S]')
    cmd_handler.setFormatter(log_formatter)
    cmd_handler.setLevel(logging.DEBUG)
    smm_logger.addHandler(cmd_handler)

    txt_handler = LogHandler()
    txt_handler.setFormatter(log_formatter)
    smm_logger.addHandler(txt_handler)
    return (smm_logger,txt_handler)
smm_logger,txt_handler = get_logger()


# Networking Parameters
cols = st.columns(5)
host = cols[0].text_input('Hostname','')
harw_ip = cols[1].text_input('HARW IP','127.0.0.1')
port = cols[2].number_input('TCP Port',min_value=0,max_value=65535,value=65432,step=1)
port_health = cols[3].number_input('UDP (in) Port',min_value=0,max_value=65535,value=51013,step=1)
port_udp_out = cols[4].number_input('UDP (out) Port',min_value=0,max_value=65535,value=51000,step=1)

#setup resources
@st.cache_resource
def get_SMMTCPServer():
    smm = SMMTCPServer(host,port)
    add_script_run_ctx(smm)
    smm.start()
    return smm
smm = get_SMMTCPServer()

@st.cache_resource
def get_HealthMonitor():
    hm = HealthMonitor(port_health,isLoopback=True)
    add_script_run_ctx(hm)
    hm.start()
    return hm
hm = get_HealthMonitor()

@st.cache_resource
def get_smm_data():
    sm_udp = SMMUDPStreamHandler(harw_ip,port_udp_out)
    add_script_run_ctx(hm)
    sm_udp.start()
    return sm_udp
sm_udp = get_smm_data()

if 'last_notify' not in st.session_state:
    st.session_state.last_notify = None
if 'clear_notify' not in st.session_state:
    st.session_state.clear_notify = False

if st.session_state.clear_notify:
    smm.Notification = None  
    st.session_state.clear_notify = False
    st.session_state.last_notify = None
if smm.Notification:
    st.session_state.last_notify = (smm.Notification,True)

def clear_notify():
    # smm_logger.info('clearing notify')
    st.session_state.clear_notify = True
    
def set_notify(message,is_warning=False):
    st.session_state.last_notify = (message,is_warning)

def do_nothing():
    pass

def process_opcode(opcode,data):
    match opcode:
        case 'RUN_NO':
            st.session_state.run_number = float(data)
        case 'DP_NO':
            pass
            # st.session_state.dp_number = float(data)
        case 'POLAR':
            st.session_state.polar_number = float(data)
        case 'SCAN':
            st.session_state.scan_number = float(data)
        case 'ALPHA_MOVE':
            st.session_state.aoa = float(data)
        case 'USER_MSG':
            set_notify(data)
        case 'SYSTEM_MSG':
            set_notify(data)
        case 'ADVISE_MSG':
            print(f'setting notify: {data}')
            set_notify(data,True)
        case _:
            pass


def send_opcode(opcode,data,process_op=False):
    if st.session_state.trigger_opcode:
        smm.send_opcode(str(opcode),str(data))
    if process_op:
        st.session_state.trigger_opcode = False  
        process_opcode(str(opcode),str(data))
        time.sleep(0.1)
        st.session_state.trigger_opcode = True
        
def send_shaker_properties():
    amp = round(float(st.session_state.shaker_amp),2)
    burst = round(float(st.session_state.shaker_burst),2)
    f_start = round(float(st.session_state.shaker_f_start),2)
    f_end = round(float(st.session_state.shaker_f_end),2)
    delay = round(float(st.session_state.shaker_delay),2)
    band = round(float(st.session_state.shaker_band),2)
    # if amp>0:
    #     str_data = f'SHKR_MODE,Steady'
    # else:
    str_data = f'SHKR_MODE,chirp,amplitude,{amp},burst,{burst},start_freq,{f_start},end_freq,{f_end},band,{band},delay,{delay}'
    send_opcode('COMMENT',str_data,process_op=True)
    
        
# TCP Server State
st.title('TCP Server Monitoring')
st.text_area('SMM TCP Server Log',value=txt_handler.getvalue(),key='log_area',height=200)
if not smm.is_alive():
    st.metric("TCP Server", 'Stopped')
else:
    states = smm.ClientStates
    cols = st.columns(len(smm.ClientStates)+2)
    cols[0].metric("TCP Server", 'Running')
    cols[1].metric("Clients", len(states))
    for i in range(len(states)):
        cols[i+2].metric(states[i][0], 'Ready' if states[i][1] else 'Not Ready')

st.title('Health Monitoring')
cols = st.columns(5)
if hm.IsAlive:
    cols[0].metric("Heartbeat?", 'Yes!')
    cols[1].metric("Damping Ratio", f"{hm.data['DR']*100:.0f}%")
    cols[2].metric("Strain Gauge Limit", f"{hm.data['SG']*100:.0f}%")
    cols[3].metric("Accelerometer Limit", f"{hm.data['ACC']*100:.0f}%")
    cols[4].metric("Mass Position", f"{hm.data['MASS']*100:.0f}%")
else:
    cols[1].metric("Heartbeat?", 'No!')
    

if st.session_state.last_notify:
    cols = st.columns([3,1])
    if st.session_state.last_notify[1]:
        cols[0].warning(st.session_state.last_notify[0])
    else:
        cols[0].info(st.session_state.last_notify[0])
    cols[1].button('Clear',on_click=clear_notify)
    
st.title('Wind Tunnel States')
cols = st.columns(4)
V = cols[0].number_input('Wind Speed',min_value=0.0,max_value=100.0,value=0.0,step=0.5,key='wind_speed',on_change=do_nothing)
aoa = cols[1].number_input('AoA',min_value=-10.0,max_value=10.0,value=0.0,step=0.1,key='aoa',on_change=lambda:send_opcode('MOVE_ALPHA',str(st.session_state.aoa)))
T = cols[2].number_input('Temperature',value=20,key='temperature',on_change=do_nothing)
p = cols[3].number_input('Pressure',value=1013,key='pressure',on_change=do_nothing)
# cols = st.columns(4)
cols[0].number_input('Run Number',step=1,key='run_number',on_change=lambda:send_opcode('RUN_NO',str(st.session_state.run_number)))
cols[1].number_input('Polar Number',value=0,step=1,key='polar_number',on_change=lambda:send_opcode('POLAR',str(st.session_state.polar_number)))
cols[2].number_input('Data Point Number',value=0,step=1,key='dp_number',on_change=lambda:send_opcode('DP_NO',str(st.session_state.dp_number)))
b_cols = cols[3].columns(2)
b_cols[0].button('New',on_click=lambda:send_opcode('NEW',''))
b_cols[0].button('End',on_click=lambda:send_opcode('END',''))
b_cols[1].button('Zero',on_click=lambda:send_opcode('ZERO',''))
b_cols[1].button('Cancel',on_click=lambda:send_opcode('CANCEL',''))

st.title('Setup Shaker')
cols = st.columns(4)
V = cols[0].number_input('Amplitude',min_value=0.0,max_value=1.0,value=0.2,step=0.05,key='shaker_amp',on_change=do_nothing)
V = cols[0].number_input('Burst Percentage',min_value=0.0,max_value=100.0,value=100.0,step=10.0,key='shaker_burst',on_change=do_nothing)
V = cols[1].number_input('Start Frequency [Hz]',min_value=0.0,max_value=20.0,value=0.5,step=0.5,key='shaker_f_start',on_change=do_nothing)
V = cols[1].number_input('End Freqeuncy [Hz]',min_value=0.0,max_value=20.0,value=20.0,step=0.5,key='shaker_f_end',on_change=do_nothing)
V = cols[2].number_input('Start Delay [s]',min_value=0.0,max_value=20.0,value=0.5,step=0.5,key='shaker_delay',on_change=do_nothing)
V = cols[2].number_input('Tansition Band [s]',min_value=0.0,max_value=5.0,value=5.0,step=0.5,key='shaker_band',on_change=do_nothing)
onShakerButton = cols[3].button('Send Properties',on_click=lambda:send_shaker_properties())

st.title('Run a Scan')
cols = st.columns(4)
cols[0].selectbox('Polar Type',options=['CPT','CTT','MPT','WPT'],key='polar_type',on_change=lambda:send_opcode('POLAR_TYPE',str(st.session_state.polar_type)))
cols[1].number_input('Scan Duration',value=1,step=1,key='scan_dur',on_change=lambda:send_opcode('SCAN_DRTN',str(st.session_state.scan_dur)))
cols[2].number_input('Scan Number',value=0,step=1,key='scan_number')
onScanButton = cols[3].button('Scan',on_click=lambda:send_opcode('SCAN',str(st.session_state.scan_number),process_op=True))

st.subheader('Manual OPCODE Sender')
cols = st.columns([1,3,1])
opcode = cols[0].text_input('OPCODE',value='RUN_NO')
data = cols[1].text_input('Data',value='')
cols[2].button('Send',on_click=lambda:send_opcode(str(opcode),str(data),process_op=True))

sm_udp.data.EAS.value = V
sm_udp.data.v0_corrected.value = V
sm_udp.data.AoA.value = aoa
sm_udp.data.corrected_AOA.value = aoa
sm_udp.data.baro_pressure.value = p
sm_udp.data.static_temperature.value = T
sm_udp.data.tunnel_temperature.value = T


st.sidebar.button('Update',on_click=do_nothing)

uploaded_file = st.file_uploader('Upload Run File',type='csv')

def process_row():
    smm.send_opcode(str(df[0][st.session_state.current_row]),df[1][st.session_state.current_row])
    process_opcode(str(df[0][st.session_state.current_row]),df[1][st.session_state.current_row])
    st.session_state.current_row += 1
    if st.session_state.current_row >= st.session_state.NumberSteps:
        st.session_state.current_row = 0

def reset_row():
    st.session_state.current_row = 0

if uploaded_file is not None:
    df = pd.read_csv(uploaded_file,header=None)
    if 'NumberSteps' not in st.session_state:
        st.session_state.NumberSteps = len(df[0])    
    cols = st.columns([3,1])
    cols[1].write(uploaded_file.name)
    cr = cols[1].number_input('Current Row',min_value=0,max_value=len(df[0])-1,step=1,key='current_row') 
    cols[1].button('Process Row',on_click=process_row)
    cols[1].button('Reset Run',on_click=reset_row)
    cols[0].dataframe(df.style.map(lambda _: "background-color: CornflowerBlue;", subset=([cr], slice(None))),use_container_width=True)
    # st.write(df)
