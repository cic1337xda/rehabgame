# 🎮 Jambatan Telemetri Python, Integrasi Permainan & Simpanan Skor (`docs`)

Dokumen ini menyediakan panduan teknikal menyeluruh mengenai **Jambatan Telemetri Python**, integrasi permainan **Godot Engine 4.4 Flappy Bird Pemulihan Lutut**, saluran penentukuran julat pergerakan (*Range of Motion - ROM*), serta seni bina penyimpanan rekod markah pesakit dalam fail JSON.

---

## 📑 Pilihan Bahasa / Language Options
* 🇲🇾 **[Dokumentasi Bahasa Melayu (Semasa)](TELEMETRY_AND_SCORING_MY.md)**
* 🇬🇧 **[English Documentation](TELEMETRY_AND_SCORING.md)**

---

## 🏗️ Topologi Saluran Perisian & Telemetri

```text
+------------------------------+
|     NOD BOLEH PAKAI ESP32    |
|  - Dwi BNO055 (6-DoF IMU)    |
|  - Aliran Telemetri 20 Hz    |
+------------------------------+
               |
               | Bluetooth Klasik SPP ("ESP32_Rehab_Knee", 115200 baud)
               v
+-----------------------------------------------------------------------+
|             JAMBATAN TELEMETRI PYTHON (`bridge-with-value.py`)        |
|  1. Imbasan Windows Registry (BTHENUM & SERIALCOMM)                   |
|  2. Penarafan Skor Pintar (ESP32_Rehab_Knee, MAC: 704BCA69184E)       |
|  3. Ujian Jabat Tangan Aktif (Had Masa 1.8s, Sahkan Nombor Sah)      |
|  4. Pemulihan Sambungan Automatik (Imbas semula setiap 2s jika putus) |
+-----------------------------------------------------------------------+
               |
               | Paket UDP Gelung Balik Tempatan (127.0.0.1:4242)
               v
+-----------------------------------------------------------------------+
|             PERMAINAN PEMULIHAN GODOT ENGINE 4.4                      |
|                                                                       |
|  [Penerima PacketPeerUDP]                                             |
|   - Menerima muatan nombor secara berterusan pada Port 4242           |
|                                                                       |
|  [Menu Penentukuran Klinikal ROM]                                     |
|   - "Kunci Lurus" (min_angle) & "Kunci Bengkok" (max_angle)           |
|   - Tolok Visual Julat Pergerakan (0% - 100%)                         |
|                                                                       |
|  [Enjin Pemetaan Kinematik Flappy Bird]                               |
|   - remap(angle, min_angle, max_angle, 650px, 25px)                   |
|   - Kelicinan pergerakan paksi-Y burung menggunakan lerp()            |
|                                                                       |
|  [Simpanan Rekod Pesakit & Papan Markah]                              |
|   - Laluan Maya Godot: user://leaderboard.json                        |
|   - Lokasi Fizikal Windows: %APPDATA%\Godot\app_userdata\Rehab Games  |
+-----------------------------------------------------------------------+
```

---

## 🐍 Analisis Mendalam Jambatan Telemetri Python (`bridge-with-value.py`)

Dalam penggunaan komputer klinikal, nombor port maya Bluetooth COM sering berubah-ubah di antara laptop (contohnya `COM3`, `COM5`, `COM7`, `COM12`). Kod yang menetapkan port secara tetap (*hardcoded*) atau gelung pengimbas satu port mudah gagal disebabkan kekeliruan port masuk (*inbound*) dan port keluar (*outbound*) Windows.

Jambatan telemetri ini menyelesaikan masalah tersebut melalui 4 peringkat automasi pintar:

### 1. Pemeriksaan Mendalam Windows Registry
Skrip membaca kunci perkakasan Windows secara terus tanpa memerlukan hak pentadbir (*Administrator*):
* `HKLM\SYSTEM\CurrentControlSet\Enum\BTHENUM`: Mengenalpasti semua peranti Bluetooth yang telah dipadankan, nama mesra, GUID, dan ID perkakasan.
* `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`: Memetakan peranti sistem terus kepada port COM yang sedang aktif.

### 2. Matriks Penarafan Kebarangkalian Port
Setiap calon port diberikan skor berdasarkan atribut perkakasan:

| Kriteria Penilaian | Skor Kebarangkalian | Rasional Teknikal |
| :--- | :---: | :--- |
| Mengandungi **`ESP32_Rehab_Knee`** / **`Rehab`** / **`Knee`** | **+2000** | Padanan tepat nama siaran firmware ESP32 |
| Sepadan dengan Alamat MAC **`704BCA69184E`** | **+2500** | Pengenalan perkakasan pemancar radio ESP32 |
| Berkaitan dengan `BTHENUM` / `Bluetooth` | **+1000** | Mengesahkan antaramuka maya RFCOMM Bluetooth |
| Nombor Indeks COM Tinggi | **+1 hingga +50** | Port keluar Bluetooth (*outbound*) lazimnya bernombor lebih tinggi |
| Mengandungi `CP210x` / `CH340` / `FTDI` | **+300** | Pilihan sandaran jika menggunakan kabel USB UART |
| Port Papan Induk `COM1` / `PNP0501` | **-500** | Menapis keluar port bersiri lama papan induk |

### 3. Ujian Jabat Tangan Aktif (*Telemetry Handshake*)
Skrip tidak mengunci port secara buta, sebaliknya menjalankan ujian aktif:
* Membuka port calon dengan had masa buka `timeout=0.6s`.
* Mendengar bacaan data nombor perpuluhan (`0.0` hingga `360.0`).
* Jika data sah diterima dalam tempoh `1.8s`, port disahkan **100% milik ESP32** dan dikunci untuk aliran telemetri.
* Jika tiada data (contohnya port *inbound* yang senyap), port ditutup serta-merta dan skrip terus beralih ke calon port seterusnya tanpa tergantung.

### 4. Gelung Sambungan Semula Automatik (*Auto-Reconnect*)
* **Jika ESP32 Dihidupkan Selepas Permainan Bermula:** Skrip terus mengimbas setiap 2 saat sehingga peranti dikesan.
* **Jika Bluetooth Terputus:** Mengesan ketiadaan isyarat selepas 6 kali had masa (~3.6 saat), menutup sambungan lama dengan selamat, dan automatik mencari semula ESP32 tanpa perlu memulakan semula (*restart*) permainan.

---

## 🎯 Penentukuran Klinikal & Mekanik Permainan (Godot 4.4)

### 1. Aliran Penentukuran Sebelum Bermain (`main.gd`)
Sebelum sesi senaman dimulakan, ahli fisioterapi atau pesakit membuka **Menu Penentukuran**:
* **Label Sudut Semasa:** Memaparkan bacaan sudut fleksi lutut langsung secara masa nyata.
* **"Kunci Lurus" (`min_angle`):** Merakam bacaan kaki lurus penuh pesakit (kebiasaannya `0.0°` hingga `10.0°`).
* **"Kunci Bengkok" (`max_angle`):** Merakam tahap fleksi maksimum pesakit (kebiasaannya `60.0°` hingga `100.0°`).
* **Tolok Kemajuan Visual:** Menunjukkan tahap pergerakan ternormal ($0\% - 100\%$):
  $$\text{Peratusan} = \text{clamp}\left(\frac{\theta_{\text{semasa}} - \theta_{\text{min}}}{\theta_{\text{maks}} - \theta_{\text{min}}} \times 100.0, 0.0, 100.0\right)$$

### 2. Pemetaan Kinematik Flappy Bird
Semasa bermain, fleksi lutut pesakit memandu ketinggian menegak burung secara langsung:

```gdscript
func _update_bird_mapping() -> void:
    if not is_min_calibrated or not is_max_calibrated or max_angle <= min_angle:
        return
        
    var clamped_angle = clamp(current_knee_angle, min_angle, max_angle)
    # Memetakan sudut lutut kepada piksel skrin (650px = tanah/bawah, 25px = langit/atas)
    var target_y = remap(clamped_angle, min_angle, max_angle, 650.0, 25.0)
    
    # Kelicinan pergerakan menggunakan interpolasi eksponen (lerp)
    $Bird.position.y = lerp($Bird.position.y, target_y, 0.15)
```

---

## 💾 Penyimpanan Rekod Pesakit & Seni Bina Fail JSON

Nama pesakit, markah tertinggi, dan tarikh sesi latihan disimpan secara setempat dalam format JSON.

### 1. Struktur Kandungan Fail (`leaderboard.json`)
```json
[
	{
		"name": "hehe",
		"high_score": 999999999999,
		"last_updated": "2026-10-18"
	},
	{
		"name": "Ahmad_Pesakit",
		"high_score": 24,
		"last_updated": "2026-11-13"
	}
]
```

### 2. Lokasi Fizikal Fail Penyimpanan

| Sistem Operasi | Laluan Maya Godot | Lokasi Fizikal Pada Cakera Keras |
| :--- | :--- | :--- |
| **Windows 10 / 11** | `user://leaderboard.json` | `%APPDATA%\Godot\app_userdata\Rehab Games\leaderboard.json` |
| | | *(Laluan penuh: `C:\Users\<Username>\AppData\Roaming\Godot\app_userdata\Rehab Games\leaderboard.json`)* |
| **Linux (Fedora / Ubuntu)** | `user://leaderboard.json` | `~/.local/share/godot/app_userdata/Rehab Games/leaderboard.json` |

### 3. Cara Mengakses atau Memadam Rekod Pesakit di Windows
1. Tekan kekunci **`Windows + R`** pada papan kekunci.
2. Dalam tetingkap Run, salin dan tampal alamat ini:
   ```text
   %APPDATA%\Godot\app_userdata\Rehab Games
   ```
3. Tekan butang **Enter**. Folder simpanan akan terbuka serta-merta.
4. **Semakan Data:** Buka fail `leaderboard.json` menggunakan Notepad untuk melihat sejarah rekod pesakit.
5. **Set Semula Rekod:** Padam fail `leaderboard.json`. Permainan akan menjana semula fail baharu secara automatik semasa dibuka kali seterusnya.
