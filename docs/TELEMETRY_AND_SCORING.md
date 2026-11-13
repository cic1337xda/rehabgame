# 🎮 Python Telemetry Bridge, Exergame Integration & Score Persistence (`docs`)

This document provides a comprehensive technical guide to the **Python Telemetry Bridge**, the **Godot Engine 4.4 Flappy Bird Rehabilitation Game**, the clinical Range of Motion (ROM) calibration pipeline, and persistent JSON patient scoring storage.

---

## 📑 Language Options / Pilihan Bahasa
* 🇬🇧 **[English Documentation (Current)](TELEMETRY_AND_SCORING.md)**
* 🇲🇾 **[Dokumentasi Bahasa Melayu](TELEMETRY_AND_SCORING_MY.md)**

---

## 🏗️ Software & Telemetry Pipeline Topology

```text
+------------------------------+
|     ESP32 WEARABLE NODE      |
|  - Dual BNO055 (6-DoF IMU)   |
|  - 20 Hz Telemetry Stream    |
+------------------------------+
               |
               | Bluetooth Classic SPP ("ESP32_Rehab_Knee", 115200 baud)
               v
+-----------------------------------------------------------------------+
|             PYTHON TELEMETRY BRIDGE (`bridge-with-value.py`)          |
|  1. Windows Registry Scan (BTHENUM & SERIALCOMM)                      |
|  2. Smart Likelihood Ranking (ESP32_Rehab_Knee, MAC: 704BCA69184E)    |
|  3. Active Handshake Probe (1.8s Timeout, Validates Numeric Stream)   |
|  4. Dynamic Auto-Reconnect Watchdog (Re-scans every 2s on drop)       |
+-----------------------------------------------------------------------+
               |
               | Local Loopback UDP Datagrams (127.0.0.1:4242)
               v
+-----------------------------------------------------------------------+
|             GODOT ENGINE 4.4 REHABILITATION EXERGAME                  |
|                                                                       |
|  [PacketPeerUDP Receiver]                                             |
|   - Continuously ingests numeric payload on Port 4242                 |
|                                                                       |
|  [Clinical ROM Calibration Menu]                                      |
|   - "Lock Straight" (min_angle) & "Lock Bent" (max_angle)             |
|   - Real-time Range of Motion Bar (0% - 100%)                         |
|                                                                       |
|  [Flappy Bird Kinematic Remap Engine]                                 |
|   - remap(angle, min_angle, max_angle, 650px, 25px)                   |
|   - Non-linear lerp() smoothing on bird Y-position                    |
|                                                                       |
|  [Patient Record & Leaderboard Storage]                               |
|   - Virtual Godot Path: user://leaderboard.json                       |
|   - Windows Physical: %APPDATA%\Godot\app_userdata\Rehab Games        |
+-----------------------------------------------------------------------+
```

---

## 🐍 Python Telemetry Bridge Deep Dive (`bridge-with-value.py`)

In clinical desktop deployments, Bluetooth virtual COM ports fluctuate across client laptops (e.g., `COM3`, `COM5`, `COM7`, `COM12`). Hardcoded port configurations or naive single-port loops fail frequently due to Windows inbound vs. outbound Bluetooth port mapping.

The telemetry bridge solves this through a four-stage autonomous discovery pipeline:

### 1. Deep Windows Registry Hardware Inspection
The bridge queries both low-level Windows hardware subkeys without requiring administrative elevation:
* `HKLM\SYSTEM\CurrentControlSet\Enum\BTHENUM`: Discovers all paired Bluetooth devices, friendly names, device GUIDs, and hardware IDs.
* `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`: Maps virtual communication ports directly to active system devices.

### 2. Multi-Tier Likelihood Scoring Matrix
Candidate ports are scored according to hardware attributes:

| Condition | Likelihood Score | Rationale |
| :--- | :---: | :--- |
| Contains **`ESP32_Rehab_Knee`** / **`Rehab`** / **`Knee`** | **+2000** | Direct firmware broadcast identifier match |
| Matches Hardware MAC **`704BCA69184E`** | **+2500** | Hardware-level radio transmitter identification |
| Associated with `BTHENUM` / `Bluetooth` | **+1000** | Confirms wireless RFCOMM virtual interface |
| Outbound High COM Index | **+1 to +50** | Outbound Bluetooth ports traditionally increment above inbound ports |
| Contains `CP210x` / `CH340` / `FTDI` | **+300** | USB-UART debugging cable fallback |
| Legacy Motherboard `COM1` / `PNP0501` | **-500** | Excludes non-Bluetooth internal motherboard ports |

### 3. Active Telemetry Handshake Probe
Rather than locking onto a port blindly, the bridge performs an active probe:
* Opens candidate port with a non-blocking `timeout=0.6s`.
* Listens for valid newline-terminated ASCII float lines (`0.0` to `360.0`).
* If verified within `1.8s`, the port is confirmed **100% active ESP32 telemetry** and locked for streaming.
* If no valid telemetry arrives (e.g. idle inbound port), it closes cleanly and probes the next candidate immediately without freezing.

### 4. Resilient Auto-Reconnection Loop
* **ESP32 Powered On After Game:** Continues scanning every 2 seconds until the hardware comes online.
* **Bluetooth Disconnection:** Detects silence after 6 consecutive timeouts (~3.6s), closes the dead serial descriptor, and seamlessly enters auto-discovery mode to reconnect as soon as the patient returns within range.

---

## 🎯 Clinical Calibration & Game Remapping (Godot 4.4)

### 1. In-Game Calibration Flow (`main.gd`)
Before the exercise session starts, the clinician or patient accesses the **Calibration Menu**:
* **Live Angle Label:** Displays live angular displacement in degrees with 1-decimal resolution.
* **"Lock Straight" (`min_angle`):** Records baseline knee extension (typically `0.0°` to `10.0°`).
* **"Lock Bent" (`max_angle`):** Records the patient's maximum comfortable knee flexion (typically `60.0°` to `100.0°`).
* **Range Progress Bar:** Displays real-time normalized joint engagement ($0\% - 100\%$):
  $$\text{Percentage} = \text{clamp}\left(\frac{\theta_{\text{current}} - \theta_{\text{min}}}{\theta_{\text{max}} - \theta_{\text{min}}} \times 100.0, 0.0, 100.0\right)$$

### 2. Flappy Bird Kinematic Mapping
During active gameplay, patient knee flexion directly controls the vertical elevation of the on-screen bird:

```gdscript
func _update_bird_mapping() -> void:
    if not is_min_calibrated or not is_max_calibrated or max_angle <= min_angle:
        return
        
    var clamped_angle = clamp(current_knee_angle, min_angle, max_angle)
    # Remap knee angle to screen pixel coordinates (650px = bottom/ground, 25px = top/sky)
    var target_y = remap(clamped_angle, min_angle, max_angle, 650.0, 25.0)
    
    # Smooth flight motion using exponential interpolation
    $Bird.position.y = lerp($Bird.position.y, target_y, 0.15)
```

---

## 💾 Patient Score Persistence & Storage Architecture

Patient names, high scores, and clinical session completion dates are preserved locally in JSON format.

### 1. File Structure (`leaderboard.json`)
```json
[
	{
		"name": "hehe",
		"high_score": 999999999999,
		"last_updated": "2026-10-18"
	},
	{
		"name": "Ahmad_Patient",
		"high_score": 24,
		"last_updated": "2026-11-13"
	}
]
```

### 2. Physical File Locations

| Operating System | Godot Virtual Path | Physical Storage Location on Disk |
| :--- | :--- | :--- |
| **Windows 10 / 11** | `user://leaderboard.json` | `%APPDATA%\Godot\app_userdata\Rehab Games\leaderboard.json` |
| | | *(Full path: `C:\Users\<Username>\AppData\Roaming\Godot\app_userdata\Rehab Games\leaderboard.json`)* |
| **Linux (Fedora / Ubuntu)** | `user://leaderboard.json` | `~/.local/share/godot/app_userdata/Rehab Games/leaderboard.json` |

### 3. How to Access or Reset Patient Data on Windows
1. Press the **`Windows + R`** keys simultaneously.
2. In the Run dialogue box, paste:
   ```text
   %APPDATA%\Godot\app_userdata\Rehab Games
   ```
3. Press **Enter**. The folder opens instantly.
4. **Audit Data:** Open `leaderboard.json` in Notepad to inspect historical patient scores.
5. **Reset Records:** Delete `leaderboard.json`. The game will automatically regenerate a fresh leaderboard upon next startup.
