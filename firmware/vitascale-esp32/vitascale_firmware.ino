/*
 * ==============================================================================
 * VITASCALE BY MAPOTECH — ESP32 FIRMWARE REFERENCE SKETCH
 * Hardware:
 *   - ESP32-WROOM-32
 *   - HX711 + 4x 50kg Load Cells (Wheatstone Bridge Combiner)
 *   - AS5600 12-bit Magnetic Rotary Encoder (I2C: SDA=21, SCL=22)
 *   - Wi-Fi Provisioning Hotspot (Captive Portal)
 *   - HTTPS Client with Device Token Authentication
 * ==============================================================================
 */

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <ArduinoJson.h>

// --- PIN DEFINITIONS ---
#define HX711_DOUT_PIN 19
#define HX711_SCK_PIN  18
#define I2C_SDA_PIN    21
#define I2C_SCL_PIN    22
#define STATUS_LED_PIN 2
#define SETUP_BTN_PIN  0 // BOOT button triggers Wi-Fi setup mode

// --- AS5600 I2C CONSTANTS ---
#define AS5600_ADDR        0x36
#define AS5600_RAW_ANGLE   0x0C

// --- MEKANIK KALIBRASI ---
// Effective wheel circumference for tape measurement: pi * D
// Example: Effective spool diameter = 3.183 cm -> circumference = 10.0 cm per 360 deg
const float WHEEL_CIRCUMFERENCE_CM = 10.0f;
const float AS5600_STEPS_PER_REV   = 4096.0f;

Preferences prefs;
WebServer server(80);

String wifi_ssid = "";
String wifi_pass = "";
String device_token = "";
String api_base_url = "https://abdburxhqqwsobmzuwmz.supabase.co/functions/v1/vitascale-device";
String device_serial = "";

bool is_setup_mode = false;
long last_as5600_raw = -1;
long total_revolutions = 0;

void setup() {
  Serial.begin(115200);
  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(SETUP_BTN_PIN, INPUT_PULLUP);
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  // Generate unique serial from MAC address
  uint64_t chipid = ESP.getEfuseMac();
  char serialBuf[32];
  snprintf(serialBuf, sizeof(serialBuf), "VTS-%04X%08X", (uint16_t)(chipid >> 32), (uint32_t)chipid);
  device_serial = String(serialBuf);

  Serial.println("==========================================");
  Serial.println("VITASCALE By MAPOTECH — Firmware Starting");
  Serial.print("Device Serial: ");
  Serial.println(device_serial);
  Serial.println("==========================================");

  prefs.begin("vitascale", false);
  wifi_ssid    = prefs.getString("ssid", "");
  wifi_pass    = prefs.getString("pass", "");
  device_token = prefs.getString("dev_token", "");

  // Check if button pressed at boot to force setup mode
  if (digitalRead(SETUP_BTN_PIN) == LOW || wifi_ssid.length() == 0) {
    startSetupPortal();
  } else {
    connectWiFi();
  }
}

void loop() {
  if (is_setup_mode) {
    server.handleClient();
    return;
  }

  // Periodic heartbeat every 60s
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 60000) {
    lastHeartbeat = millis();
    sendHeartbeat();
  }

  // Normal sensor loop execution
  delay(50);
}

// --- WI-FI PROVISIONING CAPTIVE PORTAL ---
void startSetupPortal() {
  is_setup_mode = true;
  String ap_name = "VitaScale-Setup-" + device_serial.substring(device_serial.length() - 4);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ap_name.c_str());

  Serial.println("[SETUP] Hotspot dibuat: " + ap_name);
  Serial.println("[SETUP] Buka browser di http://192.168.4.1/");

  server.on("/", HTTP_GET, []() {
    String html = "<html><head><meta name='viewport' content='width=device-width, initial-scale=1'><title>Setup VitaScale</title>"
                  "<style>body{font-family:sans-serif;padding:20px;background:#f8fafc;color:#1e293b;}"
                  ".card{background:white;padding:24px;border-radius:16px;max-width:380px;margin:auto;box-shadow:0 4px 12px rgba(0,0,0,0.08);}"
                  "input{width:100%;padding:10px;margin:8px 0 16px;border:1px solid #cbd5e1;border-radius:8px;box-sizing:border-box;}"
                  "button{background:#1abc9c;color:white;width:100%;padding:12px;border:none;border-radius:8px;font-weight:bold;cursor:pointer;}"
                  "</style></head><body><div class='card'>"
                  "<h2>VitaScale Setup</h2>"
                  "<p style='font-size:12px;color:#64748b;'>Konfigurasi Wi-Fi & Pairing Faskes MAPOTECH</p>"
                  "<form action='/save' method='POST'>"
                  "<label>SSID Wi-Fi:</label><input type='text' name='s' required>"
                  "<label>Password Wi-Fi:</label><input type='password' name='p'>"
                  "<label>Kode Pairing Faskes (6 Digit):</label><input type='text' name='k' placeholder='Contoh: 839201'>"
                  "<button type='submit'>Simpan & Hubungkan</button>"
                  "</form></div></body></html>";
    server.send(200, "text/html", html);
  });

  server.on("/save", HTTP_POST, []() {
    String s = server.arg("s");
    String p = server.arg("p");
    String k = server.arg("k");

    prefs.putString("ssid", s);
    prefs.putString("pass", p);

    server.send(200, "text/html", "<html><body><h3>Konfigurasi disimpan. Perangkat sedang menyambungkan...</h3></body></html>");
    delay(1000);
    ESP.restart();
  });

  server.begin();
}

void connectWiFi() {
  Serial.print("[WIFI] Menyambung ke " + wifi_ssid + "...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 25) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Terhubung! IP: " + WiFi.localIP().toString());
    digitalWrite(STATUS_LED_PIN, HIGH);
  } else {
    Serial.println("\n[WIFI] Gagal tersambung. Mengaktifkan Setup Portal...");
    startSetupPortal();
  }
}

// --- AS5600 ROTARY ENCODER READING & WRAP-AROUND ---
float readWaistCircumferenceCm() {
  Wire.beginTransmission(AS5600_ADDR);
  Wire.write(AS5600_RAW_ANGLE);
  if (Wire.endTransmission() != 0) return -1.0f;

  Wire.requestFrom(AS5600_ADDR, 2);
  if (Wire.available() < 2) return -1.0f;

  int highByte = Wire.read();
  int lowByte  = Wire.read();
  long rawAngle = ((highByte & 0x0F) << 8) | lowByte;

  if (last_as5600_raw != -1) {
    long diff = rawAngle - last_as5600_raw;
    // Wrap around 4096 (0 <-> 4095)
    if (diff < -2048) {
      total_revolutions++;
    } else if (diff > 2048) {
      total_revolutions--;
    }
  }
  last_as5600_raw = rawAngle;

  float totalSteps = (total_revolutions * AS5600_STEPS_PER_REV) + rawAngle;
  float lengthCm = (totalSteps / AS5600_STEPS_PER_REV) * WHEEL_CIRCUMFERENCE_CM;
  return lengthCm > 0 ? lengthCm : 0.0f;
}

// --- HTTPS SENSOR TRANSMISSION WITH IDEMPOTENCY KEY ---
bool sendMeasurement(String sessionId, String measurementType, float value, String unit) {
  if (WiFi.status() != WL_CONNECTED || device_token.length() == 0) return false;

  WiFiClientSecure client;
  client.setInsecure(); // For production, set root CA cert
  HTTPClient https;

  String endpoint = api_base_url + "/measurement";
  if (!https.begin(client, endpoint)) return false;

  https.addHeader("Content-Type", "application/json");
  https.addHeader("x-device-token", device_token);

  // Generate unique idempotency key for this measurement event
  String idempotencyKey = device_serial + "-" + String(millis()) + "-" + String(random(1000, 9999));

  StaticJsonDocument<256> doc;
  doc["session_id"] = sessionId;
  doc["measurement_type"] = measurementType;
  doc["value"] = value;
  doc["unit"] = unit;
  doc["quality"] = "stable";
  doc["idempotency_key"] = idempotencyKey;

  String reqBody;
  serializeJson(doc, reqBody);

  int httpCode = https.POST(reqBody);
  bool success = (httpCode == 201 || httpCode == 200);

  Serial.printf("[HTTPS] POST /measurement status: %d (success: %s)\n", httpCode, success ? "true" : "false");
  https.end();
  return success;
}

void sendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED || device_token.length() == 0) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient https;

  String endpoint = api_base_url + "/heartbeat";
  if (https.begin(client, endpoint)) {
    https.addHeader("Content-Type", "application/json");
    https.addHeader("x-device-token", device_token);
    int code = https.POST("{}");
    Serial.printf("[HEARTBEAT] status: %d\n", code);
    https.end();
  }
}
