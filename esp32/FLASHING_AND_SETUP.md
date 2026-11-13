# ⚡ Firmware Flashing, Toolchain & Device Setup (`esp32`)

This guide provides step-by-step instructions for compiling, flashing, and provisioning the **ESP32 Knee Rehabilitation Firmware** using the Arduino IDE or the command-line interface (`arduino-cli`).

---

## 📑 Language Options / Pilihan Bahasa
* 🇬🇧 **[English Documentation (Current)](FLASHING_AND_SETUP.md)**
* 🇲🇾 **[Dokumentasi Bahasa Melayu](FLASHING_AND_SETUP_MY.md)**

---

## 📦 Required Software & Dependencies

### 1. Arduino IDE or CLI Environment
* **Arduino IDE:** Version `2.2.0` or higher ([arduino.cc](https://www.arduino.cc/en/software)).
* **Arduino CLI:** Version `0.35.0` or higher (optional for automated deployment).

### 2. ESP32 Board Core
1. In Arduino IDE, navigate to **File** $\rightarrow$ **Preferences**.
2. Add the official Espressif board manager URL to **Additional Boards Manager URLs**:
   ```text
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Open **Tools** $\rightarrow$ **Board** $\rightarrow$ **Boards Manager**, search for `esp32` by **Espressif Systems**, and install version `2.0.14` (or `3.0.x`).

### 3. Required Arduino Libraries
Install the following libraries via **Library Manager** (**Sketch** $\rightarrow$ **Include Library** $\rightarrow$ **Manage Libraries**):

| Library Name | Author | Purpose |
| :--- | :--- | :--- |
| **Adafruit BNO055** | Adafruit | Hardware driver and vector extraction for Bosch BNO055 |
| **Adafruit Unified Sensor** | Adafruit | Common sensor abstraction layer required by Adafruit drivers |
| **BluetoothSerial** | Espressif | Standard ESP32 core library for Bluetooth Classic SPP |
| **Wire** | Espressif | Standard ESP32 core library for dual physical I2C controllers |

---

## 🛠️ Arduino IDE Board Configuration Settings

Configure the board parameters under the **Tools** menu before flashing:

| Setting Parameter | Recommended Option |
| :--- | :--- |
| **Board** | `ESP32 Dev Module` (or `WEMOS D1 MINI ESP32`) |
| **Upload Speed** | `921600` (fall back to `115200` if cable is noisy) |
| **CPU Frequency** | `240MHz (WiFi/BT)` |
| **Flash Frequency** | `80MHz` |
| **Flash Mode** | `QIO` |
| **Flash Size** | `4MB (32Mb)` |
| **Partition Scheme** | `Default 4MB with spiffs (1.2MB APP/1.5MB SPIFFS)` |
| **Core Debug Level** | `None` |
| **Port** | Select the active USB-to-UART bridge COM port (e.g., `COM3`) |

---

## 💻 Command-Line Flashing via `arduino-cli`

For headless or scripted flashing workflows:

```bash
# 1. Compile the sketch
arduino-cli compile --fqbn esp32:esp32:esp32 esp32/esp32_rehab_knee

# 2. Upload to connected board (replace COM3 / /dev/ttyUSB0 with your port)
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32 esp32/esp32_rehab_knee

# 3. Monitor live serial output (115200 baud)
arduino-cli monitor -p COM3 -c baudrate=115200
```

---

## 🚀 Clinical Device Pairing & Calibration Workflow

### Step 1: Initial Windows Bluetooth Pairing (One-Time Setup)
1. Power on the ESP32 via a 5V power bank or USB port.
2. On the clinical Windows PC:
   * Open **Settings** $\rightarrow$ **Bluetooth & devices**.
   * Toggle Bluetooth **ON** and click **Add device** $\rightarrow$ **Bluetooth**.
   * Locate and click **`ESP32_Rehab_Knee`**.
   * Windows will pair the device and automatically assign an outbound Bluetooth COM port.

### Step 2: Patient Anatomical Zeroing Reference
1. Fasten the proximal BNO055 strap securely to the patient's anterior/lateral mid-thigh.
2. Fasten the distal BNO055 strap securely to the anterior/lateral mid-shank (calf).
3. Instruct the patient to keep their leg **fully extended and straight** on a level examination bed or leg rest.
4. Press the **EN / RESET** button on the ESP32:
   * The ESP32 will pause for 2.5 seconds, then average 50 gravity samples to calibrate zero (`0.0°`).
   * Once calibrated, the stream begins transmitting live joint angles.
