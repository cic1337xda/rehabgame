import socket
import time
import sys
import platform
import serial

# Target network configurations for local loopback ingestion
UDP_IP = "127.0.0.1"
UDP_PORT = 4242

# Automatically resolve platform-specific default serial interfaces
if platform.system() == "Windows":
    DEFAULT_PORT = "COM4"  # Modify to match your outbound Windows Bluetooth COM port
else:
    DEFAULT_PORT = "/dev/rfcomm0"

BAUD_RATE = 115200

def initialize_socket() -> socket.socket:
    """Instantiate and configure the local UDP transmission socket."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return sock

def run_bridge(serial_port: str):
    """Execute continuous serial-to-UDP packet bridging with reconnection logic."""
    sock = initialize_socket()
    print(f"[SYSTEM] Initialized UDP stream targeted at {UDP_IP}:{UDP_PORT}")
    print(f"[SYSTEM] Target serial device: {serial_port}")

    while True:
        try:
            print(f"[SERIAL] Attempting connection to {serial_port}...")
            with serial.Serial(serial_port, BAUD_RATE, timeout=1.0) as ser:
                print(f"[SERIAL] Connection established successfully on {serial_port}.")
                
                while True:
                    raw_line = ser.readline()
                    if not raw_line:
                        continue

                    try:
                        decoded_payload = raw_line.decode("utf-8").strip()
                        # Validate that incoming payload is numeric data
                        float(decoded_payload)
                        sock.sendto(decoded_payload.encode("utf-8"), (UDP_IP, UDP_PORT))
                    except ValueError:
                        # Skip telemetry parsing errors or transient handshake strings
                        continue

        except (serial.SerialException, FileNotFoundError) as exception:
            print(f"[WARNING] Serial connection failure: {exception}. Retrying in 2 seconds...")
            time.sleep(2.0)
        except KeyboardInterrupt:
            print("\n[SYSTEM] Bridge terminated by user.")
            sys.exit(0)

if __name__ == "__main__":
    target_port = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PORT
    run_bridge(target_port)
