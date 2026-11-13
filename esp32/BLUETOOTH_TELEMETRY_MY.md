# 📡 Telemetri Wayarles Bluetooth & Kinematik Biomekanik (`esp32`)

Spesifikasi ini menerangkan protokol komunikasi **Bluetooth Classic Serial Port Profile (SPP)**, pemformatan data, algoritma pengiraan sudut matematik sendi, dan saluran penapisan isyarat yang dilaksanakan dalam **Perisian Tegar Pemulihan Lutut ESP32**.

---

## 📑 Pilihan Bahasa / Language Options
* 🇲🇾 **[Dokumentasi Bahasa Melayu (Semasa)](BLUETOOTH_TELEMETRY_MY.md)**
* 🇬🇧 **[English Documentation](BLUETOOTH_TELEMETRY.md)**

---

## 📶 Seni Bina Protokol Wayarles

| Parameter | Spesifikasi | Rasional Teknikal |
| :--- | :--- | :--- |
| **Protokol** | Bluetooth Klasik 2.1+EDR / 4.2 SPP (Serial Port Profile) | Emulasi port COM Windows secara natif dengan overhed protokol yang sangat rendah |
| **Nama Siaran (Identifier)** | **`ESP32_Rehab_Knee`** | Nama mesra unik untuk penemuan segera dan pemadanan (*auto-pairing*) automatik |
| **Saluran RFCOMM** | `Channel 1` | Saluran strim data dua hala piawai SPP |
| **Kadar Baud** | `115200 bps` | Jambatan UART berkelajuan tinggi tanpa herotan masa (*jitter*) |
| **Kadar Penghantaran** | `20 Hz` (sela masa `50 ms`) | Sepadan dengan kadar fizik permainan Godot dengan pendaman bawah 20ms |
| **Format Muatan** | Rentetan ASCII nombor perpuluhan (`\r\n`) | Tiada overhed pensirilan (*serialization*), kebal daripada serpihan paket |

---

## 📦 Spesifikasi Pemformatan Paket Data

Paket data telemetri dipancarkan sebagai rentetan ASCII nombor perpuluhan bersih yang diakhiri dengan jujukan baris baharu piawai:

```text
+-------------------------+------+------+
| Rentetan ASCII Nombor   |  \r  |  \n  |
| "0.0" hingga "120.0"    | 0x0D | 0x0A |
+-------------------------+------+------+
```

### Contoh Sampel Paket Langsung

```text
0.0\r\n        <-- Kaki lurus sepenuhnya (rujukan sifar asas)
12.4\r\n       <-- Permulaan pergerakan fleksi lutut
45.8\r\n       <-- Fasa pergerakan separuh bengkok
88.3\r\n       <-- Fleksi sasaran senaman pemulihan
```

---

## 📐 Kinematik Matematik & Saluran Isyarat

### 1. Mod Gabungan Penderia 6-DoF (`OPERATION_MODE_IMUPLUS`)
Algoritma gabungan 9-paksi biasa (NDOF) menggunakan data magnetometer untuk membetulkan sisihan paksi yaw. Namun, di dalam bangunan dan berdekatan kerusi logam atau kabel wayar yang bergerak, herotan medan magnet menyebabkan lonjakan orientasi yang mendadak.
Perisian tegar mengunci kedua-dua sensor ke dalam mod **`OPERATION_MODE_IMUPLUS`**:
* **Accelerometer:** Membekalkan rujukan graviti menegak bumi yang stabil secara berterusan.
* **Gyroscope:** Membekalkan redaman kelajuan sudut dinamik berkelajuan tinggi.
* **Magnetometer:** **Dimatikan sepenuhnya**, menghapuskan semua herotan akibat pergerakan wayar.

### 2. Formulasi Sudut Sendi Melalui Produk Titik (Dot Product)
Bagi mengelakkan ralat singulariti *Gimbal Lock* yang wujud pada sudut Euler, sudut lutut dikira terus daripada vektor graviti normal segmen peha dan betis:

$$\vec{g}_{\text{peha}} = \begin{bmatrix} x_1 \\ y_1 \\ z_1 \end{bmatrix}, \quad \vec{g}_{\text{betis}} = \begin{bmatrix} x_2 \\ y_2 \\ z_2 \end{bmatrix}$$

Kosinus bagi sudut dalaman $\theta$ antara dua vektor anggota kaki dikira melalui produk titik:

$$\cos\theta = \frac{\vec{g}_{\text{peha}} \cdot \vec{g}_{\text{betis}}}{|\vec{g}_{\text{peha}}| \times |\vec{g}_{\text{betis}}|}$$

Bagi melindungi daripada ketidaktepatan nombor titik apung, hasil bahagi dikunci secara matematik:

$$\cos\theta_{\text{kunci}} = \text{clamp}(\cos\theta, -1.0, 1.0)$$

$$\theta_{\text{mentah}} = \arccos(\cos\theta_{\text{kunci}}) \times \frac{180.0}{\pi}$$

### 3. Penentukuran Sifar Asas (Rujukan Kaki Lurus)
Semasa permulaan sistem (*boot*), perisian tegar mengambil purata 50 sampel bacaan awal ketika pesakit meluruskan kaki sepenuhnya:

$$\theta_{\text{offset}} = \frac{1}{50} \sum_{i=1}^{50} \theta_{\text{mentah}, i}$$

Sudut semasa kemudiannya ditolak dengan nilai asas ini:

$$\theta_{\text{tertentu}} = \max(0.0, \theta_{\text{mentah}} - \theta_{\text{offset}})$$

### 4. Penapis Laluan Rendah Purata Bergerak Eksponen (EMA)
Bagi meredakan getaran otot dan gegaran mekanikal sensor, penapis purata bergerak eksponen diaplikasikan pada kadar 20 Hz:

$$\theta_{\text{licin}} = (\alpha \times \theta_{\text{tertentu}}) + ((1 - \alpha) \times \theta_{\text{licin}, t-1})$$

Di mana:
* **$\alpha = 0.15$**: Mengimbangi kelicinan pergerakan visual watak burung dalam Godot tanpa sebarang kelewatan masa yang ketara (frekuensi pemotongan efektif $\approx 1.5\text{ Hz}$).

---

## 🛡️ Ciri Perlindungan Gegaran Wayar & Pemulihan Ralat

1. **Pengesahan Vektor Graviti Bumi:**
   - Magnitud kuasa dua graviti bumi adalah $|\vec{g}|^2 \approx 9.806^2 \approx 96.16\text{ m}^2/\text{s}^4$.
   - Kod memeriksa sama ada $|\vec{g}_{\text{peha}}|^2 \ge 9.0$ dan $|\vec{g}_{\text{betis}}|^2 \ge 9.0$. Jika wayar longgar seketika, nilai vektor akan jatuh kepada sifar.
2. **Pencegahan Kerosakan Penapis Akibat `NaN`:**
   - Jika mana-mana sensor menghasilkan vektor tidak sah, sampel tersebut dibuang serta-merta.
   - Penapis mengekalkan sudut sah terakhir, mengelakkan ralat `0.0 / 0.0 = NaN` daripada merosakkan nilai penapis secara kekal.
3. **Pemulihan Kendiri Penderia (*Watchdog*):**
   - Jika gangguan wayar berlanjutan melebihi 20 kitaran (~1 saat), perisian tegar akan menetapkan semula bus I2C secara lembut dan mengkonfigurasi semula mod `OPERATION_MODE_IMUPLUS` di latar belakang tanpa memutuskan sambungan Bluetooth.
