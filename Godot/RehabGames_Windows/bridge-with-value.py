"""
Clinical Telemetry Bridge (Serial/Bluetooth RFCOMM -> UDP)
---------------------------------------------------------
Automated, zero-configuration telemetry pipeline for ESP32 Knee Rehabilitation Game.

Features:
- Dynamic Auto-Discovery: Discovers ESP32 COM port on Windows across any laptop without manual configuration.
- Deep Hardware Inspection: Inspects Windows Registry (BTHENUM, BTHPORT, SERIALCOMM) and PySerial metadata.
- Active Telemetry Handshake: Probes candidate ports and validates numerical knee angle data (0.0° - 180.0°)
  to avoid hang-ups on inbound or idle virtual Bluetooth ports.
- Resilient Auto-Reconnection: If ESP32 is powered on after the game starts, or if Bluetooth connection
  momentarily drops, it automatically re-scans and reconnects seamlessly without restarting the game.
- Cross-Platform: Works on Windows (clinical / client delivery) and Linux (Fedora development).
"""

import socket
import time
import sys
import platform
import subprocess
import os
import re
import serial
import serial.tools.list_ports

try:
    import winreg
except ImportError:
    winreg = None

# Network telemetry target for Godot loopback ingestion
UDP_IP = "127.0.0.1"
UDP_PORT = 4242
BAUD_RATE = 115200

# Target ESP32 hardware identifiers (from ESP32 firmware)
TARGET_DEVICE_NAMES = ["ESP32_Rehab_Knee", "ESP32", "Rehab", "Knee"]
TARGET_MAC = "70:4B:CA:69:18:4E"
TARGET_MAC_CLEAN = "704BCA69184E"
RFCOMM_CHANNEL = "1"


def log(msg: str):
    """Prints immediately flushed messages to standard output."""
    print(msg, flush=True)


def query_windows_registry():
    """
    Queries Windows Registry to discover Bluetooth devices, friendly names,
    and their mapped COM port assignments.
    """
    port_meta = {}
    if winreg is None:
        return port_meta

    # 1. Inspect HKLM\SYSTEM\CurrentControlSet\Enum\BTHENUM
    bt_enum_path = r"SYSTEM\CurrentControlSet\Enum\BTHENUM"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, bt_enum_path) as enum_key:
            num_subkeys = winreg.QueryInfoKey(enum_key)[0]
            for i in range(num_subkeys):
                try:
                    guid_key_name = winreg.EnumKey(enum_key, i)
                    with winreg.OpenKey(enum_key, guid_key_name) as guid_key:
                        num_instances = winreg.QueryInfoKey(guid_key)[0]
                        for j in range(num_instances):
                            try:
                                inst_name = winreg.EnumKey(guid_key, j)
                                with winreg.OpenKey(guid_key, inst_name) as inst_key:
                                    friendly_name = ""
                                    for prop in ["FriendlyName", "DeviceDesc"]:
                                        try:
                                            friendly_name, _ = winreg.QueryValueEx(inst_key, prop)
                                            if friendly_name:
                                                break
                                        except OSError:
                                            pass

                                    try:
                                        with winreg.OpenKey(inst_key, "Device Parameters") as dp_key:
                                            port_val, _ = winreg.QueryValueEx(dp_key, "PortName")
                                            if port_val and isinstance(port_val, str) and port_val.upper().startswith("COM"):
                                                clean_port = port_val.upper().strip()
                                                port_meta[clean_port] = {
                                                    "name": friendly_name or "Bluetooth Serial Device",
                                                    "hwid": f"BTHENUM\\{guid_key_name}\\{inst_name}",
                                                    "is_bluetooth": True
                                                }
                                    except OSError:
                                        pass
                            except OSError:
                                continue
                except OSError:
                    continue
    except OSError:
        pass

    # 2. Inspect HKLM\HARDWARE\DEVICEMAP\SERIALCOMM (All registered system COM ports)
    serialcomm_path = r"HARDWARE\DEVICEMAP\SERIALCOMM"
    try:
        with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, serialcomm_path) as comm_key:
            num_values = winreg.QueryInfoKey(comm_key)[1]
            for i in range(num_values):
                try:
                    dev_path, port_val, _ = winreg.EnumValue(comm_key, i)
                    if isinstance(port_val, str) and port_val.upper().startswith("COM"):
                        clean_port = port_val.upper().strip()
                        dev_lower = str(dev_path).lower()
                        is_bth = "bth" in dev_lower or "bluetooth" in dev_lower
                        if clean_port not in port_meta:
                            port_meta[clean_port] = {
                                "name": "Bluetooth Serial Link" if is_bth else "System Serial Port",
                                "hwid": str(dev_path),
                                "is_bluetooth": is_bth
                            }
                        elif is_bth:
                            port_meta[clean_port]["is_bluetooth"] = True
                except OSError:
                    continue
    except OSError:
        pass

    return port_meta


def find_candidate_ports(cli_override: str = None) -> list:
    """
    Discovers all available serial ports, cross-references hardware metadata,
    and returns a ranked list of candidate ports sorted by likelihood.
    """
    candidates = {}
    os_name = platform.system()

    # Manual CLI override takes precedence if supplied
    if cli_override:
        clean_override = cli_override.strip()
        candidates[clean_override] = {
            "port": clean_override,
            "score": 10000,
            "desc": f"CLI override ({clean_override})",
            "hwid": "CLI_OVERRIDE"
        }

    # 1. Enumerate serial communication ports
    system_ports = list(serial.tools.list_ports.comports())

    # 2. Query Windows Registry for deep metadata
    reg_meta = query_windows_registry() if os_name == "Windows" else {}

    for reg_port, meta in reg_meta.items():
        if reg_port not in candidates:
            candidates[reg_port] = {
                "port": reg_port,
                "score": 0,
                "desc": meta.get("name", "Windows Registry Port"),
                "hwid": meta.get("hwid", "")
            }

    for p in system_ports:
        port_name = p.device
        if port_name not in candidates:
            candidates[port_name] = {
                "port": port_name,
                "score": 0,
                "desc": p.description or "Serial Device",
                "hwid": p.hwid or ""
            }
        else:
            if p.description and p.description != "n/a":
                candidates[port_name]["desc"] = f"{candidates[port_name]['desc']} | {p.description}"
            if p.hwid and p.hwid != "n/a":
                candidates[port_name]["hwid"] = f"{candidates[port_name]['hwid']} {p.hwid}"

    # 3. Calculate likelihood scores
    for port_name, data in candidates.items():
        if data["score"] >= 10000:
            continue

        score = 0
        text_to_check = f"{port_name} {data['desc']} {data['hwid']}".upper()

        # Check for device name keywords
        for kw in TARGET_DEVICE_NAMES:
            if kw.upper() in text_to_check:
                score += 2000
                break

        # Check for MAC address match
        if TARGET_MAC_CLEAN in text_to_check.replace(":", "").replace("-", ""):
            score += 2500

        # Check for Bluetooth identifiers
        is_bluetooth = False
        if "BTHENUM" in text_to_check or "BTHMODEM" in text_to_check or "BLUETOOTH" in text_to_check:
            is_bluetooth = True
            score += 1000

        # Preference higher numbered Bluetooth COM ports (outgoing port convention)
        if is_bluetooth and port_name.upper().startswith("COM"):
            try:
                num = int(re.sub(r"\D", "", port_name))
                score += min(num, 50)
            except ValueError:
                pass

        # USB Serial UART fallback
        if any(chip in text_to_check for chip in ["CP210", "CH340", "FTDI", "USB-SERIAL", "USB SERIAL", "ARDUINO"]):
            score += 300

        # Down-rank motherboard legacy serial ports (e.g. COM1 or /dev/ttyS*)
        if "PNP0501" in text_to_check or "COMMUNICATIONS PORT" in text_to_check or port_name.upper() == "COM1" or re.match(r"^/dev/ttyS\d+$", port_name):
            score -= 500

        data["score"] = score

    # 4. Linux RFCOMM fallback
    if os_name != "Windows":
        rfcomm_dev = "/dev/rfcomm0"
        if not os.path.exists(rfcomm_dev):
            try:
                subprocess.run(
                    ["sudo", "rfcomm", "bind", "0", TARGET_MAC, RFCOMM_CHANNEL],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
            except Exception:
                pass

        if os.path.exists(rfcomm_dev) and rfcomm_dev not in candidates:
            candidates[rfcomm_dev] = {
                "port": rfcomm_dev,
                "score": 3000,
                "desc": f"Linux RFCOMM device bound to {TARGET_MAC}",
                "hwid": "RFCOMM0"
            }

    sorted_candidates = sorted(candidates.values(), key=lambda c: c["score"], reverse=True)
    return sorted_candidates


def probe_port_for_telemetry(port_name: str, timeout_seconds: float = 1.8):
    """
    Attempts to open port_name and listen for valid numeric knee angle telemetry.
    Returns (serial_instance, initial_angle) on success, or (None, None) on failure.
    """
    try:
        ser = serial.Serial(
            port=port_name,
            baudrate=BAUD_RATE,
            timeout=0.6,
            write_timeout=0.6
        )
    except (serial.SerialException, OSError, FileNotFoundError):
        return None, None

    try:
        ser.reset_input_buffer()
    except Exception:
        pass

    start_time = time.time()
    valid_angle = None

    while time.time() - start_time < timeout_seconds:
        try:
            line_bytes = ser.readline()
            if not line_bytes:
                continue

            decoded = line_bytes.decode("utf-8", errors="ignore").strip()
            if not decoded:
                continue

            try:
                angle_val = float(decoded)
                if -10.0 <= angle_val <= 360.0:
                    valid_angle = angle_val
                    break
            except ValueError:
                continue
        except (serial.SerialException, OSError):
            break

    if valid_angle is not None:
        return ser, valid_angle

    try:
        ser.close()
    except Exception:
        pass
    return None, None


def stream_telemetry(ser: serial.Serial, sock: socket.socket, port_name: str, initial_val: float):
    """
    Continuous telemetry loop: reads angle data from verified serial port
    and sends UDP packets to Godot. Automatically handles disconnection.
    """
    try:
        initial_payload = f"{initial_val:.1f}".encode("utf-8")
        sock.sendto(initial_payload, (UDP_IP, UDP_PORT))
    except Exception as e:
        log(f"[NETWORK ERROR] Failed sending UDP packet: {e}")

    packet_counter = 1
    last_log_time = time.time()
    consecutive_timeouts = 0
    MAX_TIMEOUTS = 6  # ~3.6 seconds of silence indicates disconnection

    log(f"[STREAM] Telemetry pipeline ACTIVE on {port_name} -> Godot UDP {UDP_IP}:{UDP_PORT}")

    while True:
        try:
            raw_line = ser.readline()
            if not raw_line:
                consecutive_timeouts += 1
                if consecutive_timeouts >= MAX_TIMEOUTS:
                    log(f"\n[WARNING] Telemetry signal lost on {port_name} (timed out). Reconnecting...")
                    break
                continue

            consecutive_timeouts = 0
            decoded = raw_line.decode("utf-8", errors="ignore").strip()
            if not decoded:
                continue

            try:
                angle_val = float(decoded)
                sock.sendto(decoded.encode("utf-8"), (UDP_IP, UDP_PORT))
                packet_counter += 1

                now = time.time()
                if now - last_log_time >= 1.0:
                    log(f"[STREAM] [{port_name}] Telemetry: {angle_val:.1f}° | Packets: {packet_counter} -> Godot")
                    last_log_time = now
            except ValueError:
                continue

        except (serial.SerialException, OSError) as serial_err:
            log(f"\n[DISCONNECT] Serial communication interrupted on {port_name}: {serial_err}")
            break
        except Exception as general_err:
            log(f"\n[STREAM ERROR] Unexpected error: {general_err}")
            break

    try:
        ser.close()
    except Exception:
        pass


def run_bridge(cli_override: str = None):
    """
    Main resilient orchestration loop:
    - Continuously scans and ranks ports
    - Probes each candidate for valid ESP32 telemetry
    - Streams when connected
    - Automatically recovers and reconnects when disconnected
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    log("=" * 65)
    log("  ESP32 Knee Rehab Telemetry Bridge (Auto-Discovery Mode)")
    log(f"  Target UDP: {UDP_IP}:{UDP_PORT} | Baud: {BAUD_RATE}")
    log(f"  Device Identifier: {TARGET_DEVICE_NAMES[0]} / {TARGET_MAC}")
    log("=" * 65)

    if cli_override:
        log(f"[CONFIG] Manual port override provided: {cli_override}")

    while True:
        try:
            candidates = find_candidate_ports(cli_override)

            if not candidates:
                log("[SCAN] No active COM ports or Bluetooth serial interfaces detected.")
                log("[HINT] Ensure ESP32 is powered ON and paired in Windows Bluetooth settings.")
                time.sleep(2.0)
                continue

            connected = False
            for cand in candidates:
                port_name = cand["port"]
                desc = cand["desc"]
                score = cand["score"]

                if score < 0:
                    continue

                log(f"[PROBE] Checking port {port_name} (Score: {score} | {desc})...")
                ser, initial_angle = probe_port_for_telemetry(port_name, timeout_seconds=1.8)

                if ser is not None:
                    log(f"\n[CONNECTED] >>> Successfully linked to ESP32 on {port_name}! Initial angle: {initial_angle:.1f}° <<<")
                    connected = True
                    stream_telemetry(ser, sock, port_name, initial_angle)
                    break
                else:
                    log(f"[PROBE] No telemetry on {port_name} (unreachable or incoming port).")

            if not connected:
                log("[STATUS] ESP32 not detected on any scanned port. Retrying in 2 seconds...")
                time.sleep(2.0)
            else:
                log("[STATUS] Session ended. Re-scanning for ESP32 in 1 second...")
                time.sleep(1.0)

        except KeyboardInterrupt:
            log("\n[SYSTEM] Bridge terminated by user.")
            try:
                sock.close()
            except Exception:
                pass
            sys.exit(0)
        except Exception as loop_err:
            log(f"[BRIDGE ERROR] Discovery loop error: {loop_err}. Retrying in 2s...")
            time.sleep(2.0)


if __name__ == "__main__":
    cli_arg = sys.argv[1] if len(sys.argv) > 1 else None
    run_bridge(cli_arg)
