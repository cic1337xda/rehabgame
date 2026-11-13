# 🦿 Nod Telemetri Biomekanik Pemulihan Lutut ESP32 (`esp32`)

Modul ini mengandungi perisian tegar (firmware) pengeluaran, skematik litar CAD, dan spesifikasi telemetri wayarles untuk **Nod Penderia Pemulihan Lutut ESP32**. Menggunakan dua unit penderia orientasi mutlak pintar **Bosch BNO055** yang beroperasi dalam mod gabungan **6-DoF IMU** (bebas gangguan magnetik), sistem ini mengira sudut fleksi dan ekstensi sendi lutut secara masa nyata dan memancarkan paket telemetri bersih melalui protokol **Bluetooth Classic Serial Port Profile (SPP)** pada kadar 20 Hz.

---

## 📑 Pilihan Bahasa / Language Options
* 🇲🇾 **[Dokumentasi Bahasa Melayu (Semasa)](README_MY.md)**
* 🇬🇧 **[English Documentation](README.md)**

---

## 📚 Indeks Dokumentasi Teknikal

| Dokumen | Keterangan |
| :--- | :--- |
| 🔌 **[PINOUT_AND_WIRING_MY.md](PINOUT_AND_WIRING_MY.md)** | Penetapan pin mikropengawal, skematik litar bus I2C berganda, BOM komponen, dan susun atur litar. |
| 📡 **[BLUETOOTH_TELEMETRY_MY.md](BLUETOOTH_TELEMETRY_MY.md)** | Protokol penemuan SPP, pemformatan paket telemetri, formulasi sudut matematik, dan algoritma penapisan data. |
| ⚡ **[FLASHING_AND_SETUP_MY.md](FLASHING_AND_SETUP_MY.md)** | Pemasangan rantaian alat (toolchain), tetapan Arduino IDE / CLI, pustaka wajib, dan aliran kerja kalibrasi pesakit. |

---

## 🏛️ Seni Bina Perkakasan Pinggir (Edge Hardware)

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
                     (Alamat 0x29)  |                             |  (Alamat 0x29)
                                    v                             v
                   +------------------------------+ +------------------------------+
                   |  BNO055 #1 (PEHA / PROXIMAL) | |  BNO055 #2 (BETIS / DISTAL)  |
                   |  - 6-DoF OPERATION_MODE_IMUPLUS| - 6-DoF OPERATION_MODE_IMUPLUS|
                   |  - Magnetometer Dinyahaktif  | |  - Magnetometer Dinyahaktif  |
                   |  - Kristal Luaran Aktif      | |  - Kristal Luaran Aktif      |
                   |  - Vektor: VECTOR_GRAVITY    | |  - Vektor: VECTOR_GRAVITY    |
                   +------------------------------+ +------------------------------+
                                    \                             /
                                     \                           /
                                      v                         v
                           +-----------------------------------------------+
                           |          PENGIRAAN SUDUT BIOMEKANIK LUTUT     |
                           |  - Produk Titik: cos(theta) = (g1 . g2)/(|g1||g2|)
                           |  - Penentukuran Asas: Purata 50 Sampel Kaki Lurus
                           |  - Perlindungan NaN & Pemulihan Kendiri I2C   |
                           |  - Penapis Laluan Rendah (EMA Alpha = 0.15)   |
                           +-----------------------------------------------+
                                                   |
                                                   v
                           +-----------------------------------------------+
                           |         ALIRAN TELEMETRI WAYARLES BLUETOOTH   |
                           |  - Nama Siaran Peranti: "ESP32_Rehab_Knee"    |
                           |  - Muatan Bersih: "0.0\n" ... "90.0\n" (20 Hz)|
                           +-----------------------------------------------+
```

---

## 📂 Peta Kod Sumber & Aset

* **Perisian Tegar Pengeluaran:** [`esp32_rehab_knee/esp32_rehab_knee.ino`](esp32_rehab_knee/esp32_rehab_knee.ino)
* **Vektor Skematik CAD (SVG):** [`schematic.svg`](schematic.svg)
* **Format Cetakan Skematik CAD (PDF):** [`Schematic_rehabgame_2026-11-13.pdf`](Schematic_rehabgame_2026-11-13.pdf)
* **Resolusi Tinggi Skematik CAD (PNG):** [`Schematic_rehabgame_2026-11-13.png`](Schematic_rehabgame_2026-11-13.png)
