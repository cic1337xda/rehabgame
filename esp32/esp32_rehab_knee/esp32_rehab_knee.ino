/**
 * ==============================================================================
 * ESP32 Knee Rehabilitation Biomechanical Telemetry Firmware
 * ==============================================================================
 * Hardware:
 * - Microcontroller: ESP32 DevKit / Wemos D1 Mini ESP32
 * - Sensor 1 (Thigh / Proximal): Bosch BNO055 on I2C Bus 0 (SDA: 4, SCL: 27, Addr: 0x29)
 * - Sensor 2 (Calf / Distal):    Bosch BNO055 on I2C Bus 1 (SDA: 32, SCL: 25, Addr: 0x29)
 * 
 * Communication:
 * - Bluetooth Classic Serial Port Profile (SPP): "ESP32_Rehab_Knee"
 * - Baud Rate: 115200 bps
 * - Telemetry Cadence: 20 Hz (50 ms interval)
 * - Format: Pure numeric ASCII float angle + "\r\n" (e.g., "45.2\n")
 * 
 * Biomechanical Features:
 * - 6-DoF IMU mode (OPERATION_MODE_IMUPLUS) with Magnetometer disabled to
 *   eliminate indoor magnetic interference and wire-movement artifacts.
 * - Automatic 50-sample baseline extension zeroing at boot (0.0 deg straight reference).
 * - Vector dot-product gravity angle calculation with mathematical NaN guards.
 * - Auto-recovery / self-healing I2C bus handler for loose cable resilience.
 * ==============================================================================
 */

#include <Wire.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BNO055.h>
#include <utility/imumaths.h>
#include <BluetoothSerial.h>

// Validate Bluetooth Classic configuration is enabled in ESP32 board core
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth Classic is not enabled! Please enable Bluetooth Classic in your ESP32 board configuration.
#endif

// --- 1. Pin Assignments & Bus Configurations ---
#define I2C_SDA_PIN_1 4
#define I2C_SCL_PIN_1 27
#define I2C_SDA_PIN_2 32
#define I2C_SCL_PIN_2 25

#define BNO055_I2C_ADDR 0x29

// Secondary hardware TwoWire instance on ESP32
TwoWire I2C_Bus2 = TwoWire(1);

// Sensor instances on separate I2C buses
Adafruit_BNO055 bnoThigh = Adafruit_BNO055(55, BNO055_I2C_ADDR, &Wire);
Adafruit_BNO055 bnoCalf  = Adafruit_BNO055(56, BNO055_I2C_ADDR, &I2C_Bus2);

// Bluetooth Serial interface
BluetoothSerial SerialBT;

// --- 2. Biomechanical & Filtering Variables ---
unsigned long lastSamplingTime = 0;
const unsigned long SAMPLING_DELAY_MS = 50; // 20 Hz cadence

float offsetAngle = 0.0;
float smoothedKneeAngle = 0.0;
const float FILTER_ALPHA = 0.15; // Exponential Moving Average smoothing factor

// I2C wire-bump resilience counter
int sensorGlitchCount = 0;

void configureSensors() {
  // Enforce 6-DOF IMU fusion mode (Magnetometer disabled to eliminate wire jumps)
  bnoThigh.setMode(OPERATION_MODE_IMUPLUS);
  bnoCalf.setMode(OPERATION_MODE_IMUPLUS);

  // Engage external crystal oscillators for enhanced mathematical precision
  bnoThigh.setExtCrystalUse(true);
  bnoCalf.setExtCrystalUse(true);
}

void setup() {
  // Initialize standard hardware UART for debugging
  Serial.begin(115200);

  // Initialize Bluetooth Classic SPP with standard discovery name
  SerialBT.begin("ESP32_Rehab_Knee");
  Serial.println("\n[SYSTEM] Bluetooth interface initialized: ESP32_Rehab_Knee");

  // Initialize dual I2C buses with 30ms timeout guard to prevent lockups on wire disturbances
  Wire.begin(I2C_SDA_PIN_1, I2C_SCL_PIN_1);
  I2C_Bus2.begin(I2C_SDA_PIN_2, I2C_SCL_PIN_2);
  Wire.setTimeOut(30);
  I2C_Bus2.setTimeOut(30);

  // Validate thigh sensor initialization
  if (!bnoThigh.begin()) {
    Serial.println("[ERROR] Thigh sensor (Bus 1) initialization failed. Check wiring on GPIO 4/27.");
    while (1) { delay(1000); }
  }

  // Validate calf sensor initialization
  if (!bnoCalf.begin()) {
    Serial.println("[ERROR] Calf sensor (Bus 2) initialization failed. Check wiring on GPIO 32/25.");
    while (1) { delay(1000); }
  }

  // Configure sensors in 6-DoF mode
  configureSensors();

  // Stabilization latency
  delay(1000);

  // Perform baseline offset acquisition (straight leg zeroing reference)
  Serial.println("[CALIBRATION] Commencing baseline zeroing. Maintain full leg extension...");
  delay(2500);

  float cumulativeAngle = 0.0;
  const int CALIBRATION_SAMPLES = 50;
  int validSamples = 0;

  while (validSamples < CALIBRATION_SAMPLES) {
    imu::Vector<3> gThigh = bnoThigh.getVector(Adafruit_BNO055::VECTOR_GRAVITY);
    imu::Vector<3> gCalf  = bnoCalf.getVector(Adafruit_BNO055::VECTOR_GRAVITY);

    float magThighSq = gThigh.x() * gThigh.x() + gThigh.y() * gThigh.y() + gThigh.z() * gThigh.z();
    float magCalfSq  = gCalf.x() * gCalf.x() + gCalf.y() * gCalf.y() + gCalf.z() * gCalf.z();

    // Verify vectors are healthy (Earth gravity magnitude squared is ~96.0; threshold > 9.0)
    if (magThighSq >= 9.0f && magCalfSq >= 9.0f) {
      float dotProduct = gThigh.x() * gCalf.x() + gThigh.y() * gCalf.y() + gThigh.z() * gCalf.z();
      float magThigh = sqrt(magThighSq);
      float magCalf  = sqrt(magCalfSq);
      float denom = magThigh * magCalf;

      if (denom > 0.001f) {
        float cosTheta = constrain(dotProduct / denom, -1.0f, 1.0f);
        float sampleAngle = acos(cosTheta) * 180.0 / PI;

        if (!isnan(sampleAngle)) {
          cumulativeAngle += sampleAngle;
          validSamples++;
        }
      }
    }
    delay(20);
  }

  offsetAngle = cumulativeAngle / CALIBRATION_SAMPLES;
  smoothedKneeAngle = 0.0;

  Serial.println("[CALIBRATION] Baseline zeroing concluded successfully.");
  Serial.println("[SYSTEM] Transmitting pure telemetry stream (6-DOF IMU Mode)...");
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastSamplingTime >= SAMPLING_DELAY_MS) {
    lastSamplingTime = currentMillis;

    // Acquire gravity vector telemetry from both inertial measurement units
    imu::Vector<3> gThigh = bnoThigh.getVector(Adafruit_BNO055::VECTOR_GRAVITY);
    imu::Vector<3> gCalf  = bnoCalf.getVector(Adafruit_BNO055::VECTOR_GRAVITY);

    float magThighSq = gThigh.x() * gThigh.x() + gThigh.y() * gThigh.y() + gThigh.z() * gThigh.z();
    float magCalfSq  = gCalf.x() * gCalf.x() + gCalf.y() * gCalf.y() + gCalf.z() * gCalf.z();

    // Wire-bump & noise guard: Earth gravity magnitude is ~9.8 m/s^2 (squared ~96).
    // If either sensor drops (returns 0,0,0 or corrupted reading), protect the filter from NaN poisoning!
    if (magThighSq < 9.0f || magCalfSq < 9.0f || isnan(magThighSq) || isnan(magCalfSq)) {
      sensorGlitchCount++;

      // If disconnected/loose wire lasts more than 20 frames (~1 sec), perform soft sensor re-init
      if (sensorGlitchCount > 20) {
        bnoThigh.begin();
        bnoCalf.begin();
        configureSensors();
        sensorGlitchCount = 0;
      }

      // Stream existing valid smoothed knee angle so connection does not glitch to 0
      SerialBT.println(smoothedKneeAngle, 1);
      Serial.println(smoothedKneeAngle, 1);
      return;
    }

    sensorGlitchCount = 0;

    float magThigh = sqrt(magThighSq);
    float magCalf  = sqrt(magCalfSq);
    float denom = magThigh * magCalf;

    if (denom > 0.001f) {
      float dotProduct = gThigh.x() * gCalf.x() + gThigh.y() * gCalf.y() + gThigh.z() * gCalf.z();
      float cosTheta = constrain(dotProduct / denom, -1.0f, 1.0f);
      float rawAngle = acos(cosTheta) * 180.0 / PI;

      if (!isnan(rawAngle)) {
        // Normalize against baseline calibration offset
        float calibratedAngle = rawAngle - offsetAngle;
        if (calibratedAngle < 0.0) {
          calibratedAngle = 0.0;
        }

        // Apply low-pass exponential smoothing filter safely
        smoothedKneeAngle = (FILTER_ALPHA * calibratedAngle) + ((1.0 - FILTER_ALPHA) * smoothedKneeAngle);
      }
    }

    // Transmit clean float telemetry (Line-delimited for streaming parsers)
    SerialBT.println(smoothedKneeAngle, 1);
    Serial.println(smoothedKneeAngle, 1);
  }
}
