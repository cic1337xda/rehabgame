# 🦿 ESP32 Knee Rehabilitation Biomechanical Telemetry Node (`esp32`)

This module houses the production firmware, CAD schematics, and wireless telemetry specifications for the **ESP32 Knee Rehabilitation Sensor Node**. Utilizing dual **Bosch BNO055** absolute orientation sensors operating in magnetic-decoupled **6-DoF IMU mode**, the system computes real-time knee joint angles (flexion and extension) and broadcasts clean telemetry packets over **Bluetooth Classic Serial Port Profile (SPP)** at 20 Hz.

---

## 📑 Language Options / Pilihan Bahasa
* 🇬🇧 **[English Documentation (Current)](README.md)**
* 🇲🇾 **[Dokumentasi Bahasa Melayu](README_MY.md)**

---

## 📚 Technical Documentation Index

| Document | Description |
| :--- | :--- |
| 🔌 **[PINOUT_AND_WIRING.md](PINOUT_AND_WIRING.md)** | Microcontroller pin assignments, dual I2C wiring schematics, BOM, and electrical layout. |
| 📡 **[BLUETOOTH_TELEMETRY.md](BLUETOOTH_TELEMETRY.md)** | SPP discovery protocol, packet transmission framing, mathematical angle formulation, and filter pipeline. |
| ⚡ **[FLASHING_AND_SETUP.md](FLASHING_AND_SETUP.md)** | Toolchain installation, Arduino IDE / CLI setup, board parameters, required libraries, and calibration workflow. |

---

## 🏛️ Edge Hardware Architecture

```text
                           +-----------------------------------------------+
                           |          ESP32 DUAL-CORE MCU (240 MHz)        |
                           |                                               |
                           |  [Wire: Bus 0]      -> SDA: GPIO 4, SCL: 27   |
                           |  [TwoWire: Bus 1]   -> SDA: GPIO 32, SCL: 25  |
                           |  [BluetoothSerial]  -> SPP @ 20 Hz (115200)   |
                           +-----------------------------------------------+
                                    |                             |
                       I2C Bus 0    |                             |    I2C Bus 1
                     (Address 0x29) |                             |  (Address 0x29)
                                    v                             v
                   +------------------------------+ +------------------------------+
                   |  BNO055 #1 (THIGH / PROXIMAL)| |  BNO055 #2 (CALF / DISTAL)   |
                   |  - 6-DoF OPERATION_MODE_IMUPLUS| - 6-DoF OPERATION_MODE_IMUPLUS|
                   |  - Magnetometer Disabled     | |  - Magnetometer Disabled     |
                   |  - External Crystal Enabled  | |  - External Crystal Enabled  |
                   |  - Vector: VECTOR_GRAVITY    | |  - Vector: VECTOR_GRAVITY    |
                   +------------------------------+ +------------------------------+
                                    \                             /
                                     \                           /
                                      v                         v
                           +-----------------------------------------------+
                           |          BIOMECHANICAL ANGLE COMPUTATION      |
                           |  - Dot Product: cos(theta) = (g1 . g2) / (|g1||g2|)
                           |  - Baseline Zeroing: 50-sample Straight Leg Offset
                           |  - NaN Protection & I2C Self-Healing Watchdog |
                           |  - Low-Pass Filter: Exponential Moving Average|
                           +-----------------------------------------------+
                                                   |
                                                   v
                           +-----------------------------------------------+
                           |          WIRELESS BLUETOOTH SPP STREAM        |
                           |  - Device Broadcast Name: "ESP32_Rehab_Knee"  |
                           |  - Stream Payload: "0.0\n" ... "90.0\n" (20Hz)|
                           +-----------------------------------------------+
```

---

## 📂 Source Code Map

* **Production Firmware:** [`esp32_rehab_knee/esp32_rehab_knee.ino`](esp32_rehab_knee/esp32_rehab_knee.ino)
* **CAD Schematic Vector (SVG):** [`schematic.svg`](schematic.svg)
* **CAD Schematic Print (PDF):** [`Schematic_rehabgame_2026-11-13.pdf`](Schematic_rehabgame_2026-11-13.pdf)
* **CAD Schematic High-Res (PNG):** [`Schematic_rehabgame_2026-11-13.png`](Schematic_rehabgame_2026-11-13.png)
