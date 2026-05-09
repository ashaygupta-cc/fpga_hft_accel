import serial
import struct
import time

# ----------------------------
# CONFIG
# ----------------------------
PORT = "COM4"          
BAUD = 9600
TIMEOUT = 2.0

OP_ADD = 0
OP_CANCEL = 1
OP_EXECUTE = 2

SIDE_BID = 0
SIDE_ASK = 1


def make_cmd(op: int, side: int, price: int, qty: int) -> bytes:
    b0 = ((side & 0x1) << 2) | (op & 0x3)
    return bytes([
        b0,
        (price >> 8) & 0xFF,
        price & 0xFF,
        (qty >> 8) & 0xFF,
        qty & 0xFF,
    ])


def read_exact(ser: serial.Serial, n: int) -> bytes:
    data = b""
    start = time.time()
    while len(data) < n:
        chunk = ser.read(n - len(data))
        if chunk:
            data += chunk
        if time.time() - start > TIMEOUT:
            raise TimeoutError(f"Timeout while waiting for {n} bytes, got {len(data)}")
    return data


def decode_snapshot(data: bytes):
    if len(data) != 8:
        raise ValueError(f"Expected 8 bytes, got {len(data)}")
    bb_price = (data[0] << 8) | data[1]
    bb_qty   = (data[2] << 8) | data[3]
    ba_price = (data[4] << 8) | data[5]
    ba_qty   = (data[6] << 8) | data[7]
    return bb_price, bb_qty, ba_price, ba_qty


def send_and_print(ser: serial.Serial, op: int, side: int, price: int, qty: int):
    pkt = make_cmd(op, side, price, qty)
    ser.write(pkt)
    ser.flush()

    resp = read_exact(ser, 8)
    bb_p, bb_q, ba_p, ba_q = decode_snapshot(resp)

    print(
        f"SENT  op={op} side={side} price={price} qty={qty} "
        f"-> RESP  BB={bb_p} x {bb_q} | BA={ba_p} x {ba_q}"
    )


def main():
    with serial.Serial(PORT, BAUD, timeout=0.1) as ser:
        time.sleep(2.0)  # give board/UART time

        # optional: clear old junk bytes
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        send_and_print(ser, OP_ADD,     SIDE_BID, 100, 10)
        send_and_print(ser, OP_ADD,     SIDE_BID, 101, 5)
        send_and_print(ser, OP_ADD,     SIDE_BID,  99, 20)

        send_and_print(ser, OP_ADD,     SIDE_ASK, 105, 7)
        send_and_print(ser, OP_ADD,     SIDE_ASK, 104, 12)
        send_and_print(ser, OP_ADD,     SIDE_ASK, 106, 3)

        send_and_print(ser, OP_ADD,     SIDE_BID, 101, 8)
        send_and_print(ser, OP_CANCEL,  SIDE_BID, 101, 4)
        send_and_print(ser, OP_EXECUTE, SIDE_ASK, 104, 12)


if __name__ == "__main__":
    main()