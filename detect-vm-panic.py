import libvirt
import time
import threading

run = True
eventLoopThread = None
VIR_DOMAIN_EVENT_CRASHED = 8

def callback(conn, dom, event, detail, opaque):
    if event == VIR_DOMAIN_EVENT_CRASHED:
        print(f'VM {dom.name()}({dom.ID()}) crashed!')
        global run
        run = False

def virEventLoopNativeRun():
    while True:
        libvirt.virEventRunDefaultImpl()

def virEventLoopNativeStart():
    global eventLoopThread
    libvirt.virEventRegisterDefaultImpl()
    eventLoopThread = threading.Thread(target=virEventLoopNativeRun,
                                       name="libvirtEventLoop")
    eventLoopThread.setDaemon(True)
    eventLoopThread.start()

if __name__ == '__main__':

    virEventLoopNativeStart()

    conn = libvirt.openReadOnly('qemu:///system')

    conn.domainEventRegister(callback, None)
    conn.setKeepAlive(5, 3)

    while run and conn.isAlive() == 1:
        time.sleep(1)
