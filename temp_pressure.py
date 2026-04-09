import serial
import time
from serial.tools import list_ports

def find_arty7_port():
    ports = list_ports.comports()
    for port in ports:
        if 'Digilent' in port.description or 'Arty' in port.description:
            return port.device
    return None

SERIAL_PORT = find_arty7_port()
BAUD_RATE = 921600

# Coefficients (filled by command 2)
c0  = c1  = 0
c00 = c10 = c01 = c11 = 0
c20 = c21 = c30 = 0
kT  = 524288.0
kP  = 524288.0

def sign_extend(value, bits):
    if value >= (1 << (bits - 1)):
        value -= (1 << bits)
    return value

def read_coefficients(raw):
    global c0, c1, c00, c10, c01, c11, c20, c21, c30
    c0  = sign_extend((raw[0] << 4) | (raw[1] >> 4), 12)
    c1  = sign_extend(((raw[1] & 0x0F) << 8) | raw[2], 12)
    c00 = sign_extend((raw[3] << 12) | (raw[4] << 4) | (raw[5] >> 4), 20)
    c10 = sign_extend(((raw[5] & 0x0F) << 16) | (raw[6] << 8) | raw[7], 20)
    c01 = sign_extend((raw[8] << 8)  | raw[9],  16)
    c11 = sign_extend((raw[10] << 8) | raw[11], 16)
    c20 = sign_extend((raw[12] << 8) | raw[13], 16)
    c21 = sign_extend((raw[14] << 8) | raw[15], 16)
    c30 = sign_extend((raw[16] << 8) | raw[17], 16)
    print(f"c0={c0}, c1={c1}, c00={c00}, c10={c10}")
    print(f"c01={c01}, c11={c11}, c20={c20}, c21={c21}, c30={c30}")

def compensate(data):
    # data[0:3] = Pressure, data[3:6] = Temperature
    Praw = (data[0] << 16) | (data[1] << 8) | data[2]
    if Praw & 0x800000:
        Praw -= 0x1000000

    Traw = (data[3] << 16) | (data[4] << 8) | data[5]
    if Traw & 0x800000:
        Traw -= 0x1000000

    Tsc = Traw / kT
    Psc = Praw / kP

    Tcomp = c0 * 0.5 + c1 * Tsc
    Pcomp = (c00 + Psc*(c10 + Psc*(c20 + Psc*c30)) + Tsc*c01 + Tsc*Psc*(c11 + Psc*c21)) / 100.0

    return round(Tcomp, 2), round(Pcomp, 2)

def send_data(data):
    ser.write(data.encode())

if SERIAL_PORT is None:
    print("No Arty7 FPGA serial device found.")
else:
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud.")

        # Init
        ser.write(b"1")
        time.sleep(1)
        ser.reset_input_buffer()  # flush init response before reading coeffs

        # Read coefficients
        ser.write(b"2")
        time.sleep(1)
        raw = ser.read(ser.in_waiting)
        print("COEFF RAW:", raw.hex(' ').upper())
        coeff = raw[1:19]
        if len(coeff) == 18:
            read_coefficients(coeff)

        while True:
            send_data("3")
            time.sleep(1)
            if ser.in_waiting > 0:
                raw_data = ser.read(ser.in_waiting)
                data = raw_data[11:17]
                if len(data) == 6:
                    temp, pres = compensate(data)
                    print(f"Temperature: {temp} C")
                    print(f"Pressure   : {pres} hPa")
            else:
                time.sleep(0.01)

    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except KeyboardInterrupt:
        print("Stopped by user.")