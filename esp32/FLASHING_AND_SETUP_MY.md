# ⚡ Pengaturcaraan Firmware, Rantaian Alat & Penyediaan Peranti (`esp32`)

Panduan ini menyediakan langkah demi langkah untuk mengkompil, memprogram (*flash*), dan menyediakan **Perisian Tegar Pemulihan Lutut ESP32** menggunakan Arduino IDE atau antaramuka baris arahan (`arduino-cli`).

---

## 📑 Pilihan Bahasa / Language Options
* 🇲🇾 **[Dokumentasi Bahasa Melayu (Semasa)](FLASHING_AND_SETUP_MY.md)**
* 🇬🇧 **[English Documentation](FLASHING_AND_SETUP.md)**

---

## 📦 Keperluan Perisian & Pustaka (Dependencies)

### 1. Persekitaran Arduino IDE atau CLI
* **Arduino IDE:** Versi `2.2.0` atau terkini ([arduino.cc](https://www.arduino.cc/en/software)).
* **Arduino CLI:** Versi `0.35.0` atau terkini (pilihan untuk pengaturcaraan automatik).

### 2. Pakej Teras Papan ESP32 (Board Core)
1. Buka Arduino IDE, pergi ke **File** $\rightarrow$ **Preferences**.
2. Masukkan URL rasmi pengurus papan Espressif ke dalam kotak **Additional Boards Manager URLs**:
   ```text
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Buka **Tools** $\rightarrow$ **Board** $\rightarrow$ **Boards Manager**, cari `esp32` oleh **Espressif Systems**, dan pasang versi `2.0.14` (atau `3.0.x`).

### 3. Pustaka Arduino Yang Diperlukan
Pasang pustaka berikut melalui **Library Manager** (**Sketch** $\rightarrow$ **Include Library** $\rightarrow$ **Manage Libraries**):

| Nama Pustaka | Pengarang | Tujuan & Fungsi |
| :--- | :--- | :--- |
| **Adafruit BNO055** | Adafruit | Pemacu perkakasan dan pengekstrakan vektor bagi sensor Bosch BNO055 |
| **Adafruit Unified Sensor** | Adafruit | Lapisan abstraksi sensor yang diperlukan oleh pemacu Adafruit |
| **BluetoothSerial** | Espressif | Pustaka teras piawai ESP32 untuk Bluetooth Klasik SPP |
| **Wire** | Espressif | Pustaka teras piawai ESP32 untuk dwi-pengawal perkakasan I2C |

---

## 🛠️ Tetapan Konfigurasi Papan dalam Arduino IDE

Tetapkan parameter papan di bawah menu **Tools** sebelum memulakan muat naik:

| Parameter Tetapan | Pilihan Disyorkan |
| :--- | :--- |
| **Board** | `ESP32 Dev Module` (atau `WEMOS D1 MINI ESP32`) |
| **Upload Speed** | `921600` (atau `115200` jika kabel USB panjang/bising) |
| **CPU Frequency** | `240MHz (WiFi/BT)` |
| **Flash Frequency** | `80MHz` |
| **Flash Mode** | `QIO` |
| **Flash Size** | `4MB (32Mb)` |
| **Partition Scheme** | `Default 4MB with spiffs (1.2MB APP/1.5MB SPIFFS)` |
| **Core Debug Level** | `None` |
| **Port** | Pilih port COM USB UART yang aktif (contohnya `COM3`) |

---

## 💻 Pengaturcaraan Melalui Baris Arahan (`arduino-cli`)

Bagi pengguna terminal atau automasi skrip:

```bash
# 1. Kompil kod sumber
arduino-cli compile --fqbn esp32:esp32:esp32 esp32/esp32_rehab_knee

# 2. Muat naik ke papan ESP32 (gantikan COM3 / /dev/ttyUSB0 mengikut port anda)
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32 esp32/esp32_rehab_knee

# 3. Pantau paparan bersiri (115200 baud)
arduino-cli monitor -p COM3 -c baudrate=115200
```

---

## 🚀 Aliran Kerja Pemadanan Bluetooth & Penentukuran Klinikal

### Langkah 1: Pemadanan Bluetooth Kali Pertama (Laptop Windows)
1. Hidupkan ESP32 menggunakan power bank 5V atau kabel USB.
2. Di komputer Windows:
   * Buka **Settings** $\rightarrow$ **Bluetooth & devices**.
   * Pastikan Bluetooth dihidupkan, klik **Add device** $\rightarrow$ **Bluetooth**.
   * Cari dan klik pada **`ESP32_Rehab_Knee`**.
   * Windows akan memadankan peranti dan menetapkan port COM keluar (*outbound*) secara automatik.

### Langkah 2: Penentukuran Sifar Anatomi Pesakit
1. Pasang tali penderia peha (BNO055 #1) dengan kemas pada bahagian hadapan/sisi peha pesakit.
2. Pasang tali penderia betis (BNO055 #2) dengan kemas pada bahagian hadapan/sisi betis pesakit.
3. Minta pesakit meluruskan kaki sepenuhnya di atas katil rawatan atau bangku sokongan.
4. Tekan butang **EN / RESET** pada ESP32:
   * ESP32 akan berhenti seketika selama 2.5 saat, kemudian mengambil purata 50 sampel graviti bagi menetapkan bacaan sifar (`0.0°`).
   * Selepas penentukuran selesai, telemetri sudut langsung akan terus dipancarkan.
