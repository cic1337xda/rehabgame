# 📡 Wireless Bluetooth Telemetry & Biomechanical Kinematics (`esp32`)

This specification describes the **Bluetooth Classic Serial Port Profile (SPP)** communication protocol, data framing, mathematical joint angle algorithms, and signal conditioning pipeline implemented in the **ESP32 Knee Rehabilitation Firmware**.

---

## 📑 Language Options / Pilihan Bahasa
* 🇬🇧 **[English Documentation (Current)](BLUETOOTH_TELEMETRY.md)**
* 🇲🇾 **[Dokumentasi Bahasa Melayu](BLUETOOTH_TELEMETRY_MY.md)**

---

## 📶 Wireless Protocol Architecture

| Parameter | Specification | Technical Rationale |
| :--- | :--- | :--- |
| **Protocol** | Bluetooth Classic 2.1+EDR / 4.2 SPP (Serial Port Profile) | Native Windows COM-port emulation with low protocol overhead |
| **Broadcast Identifier** | **`ESP32_Rehab_Knee`** | Unique friendly name for instant discovery and auto-pairing |
| **RFCOMM Channel** | `Channel 1` | Standard SPP bidirectional streaming channel |
| **Baud Rate** | `115200 bps` | High-throughput UART bridge with negligible transmission jitter |
| **Transmission Rate** | `20 Hz` (`50 ms` period) | Perfectly matches Godot game physics step with sub-20ms latency |
| **Payload Format** | Line-delimited ASCII float (`\r\n`) | Zero serialization overhead, robust against partial packet fragmentation |

---

## 📦 Packet Framing Specification

Telemetry packets are broadcast as clean, decimal-formatted ASCII floats delimited by a standard newline sequence:

```text
+-------------------------+------+------+
| Numeric ASCII String    |  \r  |  \n  |
| "0.0" through "120.0"   | 0x0D | 0x0A |
+-------------------------+------+------+
```

### Typical Live Packet Samples

```text
0.0\r\n        <-- Full extension (straight leg baseline)
12.4\r\n       <-- Initial knee flexion initiation
45.8\r\n       <-- Mid-range flexion trajectory
88.3\r\n       <-- Deep target flexion squat
```

---

## 📐 Mathematical Kinematics & Signal Pipeline

### 1. 6-DoF Sensor Fusion Mode (`OPERATION_MODE_IMUPLUS`)
Standard 9-axis fusion algorithms (NDOF) incorporate magnetometer data to correct yaw drift. However, indoors and around metal chairs or moving electrical cables, magnetic distortion causes catastrophic orientation jumps. 
The firmware strictly locks both sensors into **`OPERATION_MODE_IMUPLUS`**:
* **Accelerometer:** Provides continuous absolute vertical Earth gravity reference.
* **Gyroscope:** Provides high-speed dynamic angular rate damping.
* **Magnetometer:** **Permanently powered down**, eliminating all wire-movement heading corruption.

### 2. Analytical Dot-Product Joint Angle Formulation
Rather than relying on Euler angles (which suffer from mathematical gimbal lock singularities), the knee angle is derived directly from the normalized gravity vectors of the thigh and calf segments:

$$\vec{g}_{\text{thigh}} = \begin{bmatrix} x_1 \\ y_1 \\ z_1 \end{bmatrix}, \quad \vec{g}_{\text{calf}} = \begin{bmatrix} x_2 \\ y_2 \\ z_2 \end{bmatrix}$$

The cosine of the internal angle $\theta$ between the two limb vectors is computed via dot product:

$$\cos\theta = \frac{\vec{g}_{\text{thigh}} \cdot \vec{g}_{\text{calf}}}{|\vec{g}_{\text{thigh}}| \times |\vec{g}_{\text{calf}}|}$$

To guard against floating-point precision overshoots, the quotient is mathematically clamped:

$$\cos\theta_{\text{clamped}} = \text{clamp}(\cos\theta, -1.0, 1.0)$$

$$\theta_{\text{raw}} = \arccos(\cos\theta_{\text{clamped}}) \times \frac{180.0}{\pi}$$

### 3. Baseline Offset Zeroing (Straight Leg Reference)
At boot time, the firmware performs a 50-sample baseline calibration while the patient maintains a fully extended, relaxed leg:

$$\theta_{\text{offset}} = \frac{1}{50} \sum_{i=1}^{50} \theta_{\text{raw}, i}$$

Subsequent live angles are normalized against this baseline:

$$\theta_{\text{calibrated}} = \max(0.0, \theta_{\text{raw}} - \theta_{\text{offset}})$$

### 4. Exponential Moving Average (EMA) Low-Pass Filter
To suppress muscle tremor and mechanical sensor vibration, an exponential moving average filter is applied at 20 Hz:

$$\theta_{\text{smoothed}} = (\alpha \times \theta_{\text{calibrated}}) + ((1 - \alpha) \times \theta_{\text{smoothed}, t-1})$$

Where:
* **$\alpha = 0.15$**: Balances smooth visual motion in Godot without introducing perceptible lag (effective cutoff frequency $\approx 1.5\text{ Hz}$).

---

## 🛡️ Wire-Bump & Fault Resilience Guards

1. **Earth Gravity Vector Validation:**
   - Earth gravity magnitude squared is $|\vec{g}|^2 \approx 9.806^2 \approx 96.16\text{ m}^2/\text{s}^4$.
   - The firmware checks if $|\vec{g}_{\text{thigh}}|^2 \ge 9.0$ and $|\vec{g}_{\text{calf}}|^2 \ge 9.0$. If a loose wire momentarily drops communication, the vector drops to zero.
2. **`NaN` Filter Poisoning Prevention:**
   - If either sensor produces an invalid vector, the sample is immediately discarded.
   - The filter retains its last known valid angle, preventing `0.0 / 0.0 = NaN` from permanently corrupting the smoothing accumulator.
3. **Automatic Sensor Re-initialization Watchdog:**
   - If invalid samples persist for more than 20 consecutive cycles (~1 second), the firmware triggers an automatic non-blocking I2C reset and reconfigures `OPERATION_MODE_IMUPLUS` in the background without dropping the Bluetooth link.
