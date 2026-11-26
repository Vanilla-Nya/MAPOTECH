/*
 * ==============================================================================
 * VITASCALE BY MAPOTECH — ESP32 MQTT + WEB PROVISIONING (USB SERIAL & BLE)
 * Hardware:
 *   - ESP32-WROOM-32 DevKit
 *   - HX711 + 4x 50kg Load Cell Wheatstone Bridge (Berat Badan)
 *   - HC-SR04 Ultrasonik (Tinggi Badan Stadiometer)
 * Provisioning (Langsung dari Browser Web MAPOTECH tanpa buka 192.168.4.1):
 *   1. USB Web Serial (115200 baud JSON line) — ideal saat ESP32 baru / habis diganti
 *   2. Bluetooth Web BLE GATT (UUID 4fafc201-1fb5-459e-8fcc-c5c9c331914b)
 *   3. MQTT Remote Command (`set_wifi`, `tare`, `calibrate`) saat ESP32 online
 * ==============================================================================
 */

#include <WiFi.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <HX711.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- PIN DEFINITIONS (Sesuaikan dengan wiring fisik jika berbeda) ---
#define TRIG_PIN       5
#define ECHO_PIN       18
#define HX711_DOUT_PIN 19
#define HX711_SCK_PIN  21
#define STATUS_LED_PIN 2

// --- BLE PROVISIONING UUID (Harus cocok dengan Web App MAPOTECH) ---
#define BLE_SERVICE_UUID     "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHAR_CONFIG_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BLE_CHAR_STATUS_UUID "beb5483f-36e1-4688-b7f5-ea07361b26a8"

Preferences prefs;
WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
HX711 scale;

// --- KONFIGURASI PERSISTEN (NVS Flash) ---
String wifiSsid     = "";
String wifiPass     = "";
String mqttBroker   = "broker.hivemq.com";
int    mqttPort     = 1883;
String faskesId     = "PUSKESMAS-001";
String deviceId     = "VTS-001";
float  poleHeightCm = 166.0f;
float  calFactor    = 25.75f;

// --- STATE RUNTIME & BUFFER ---
String serialRxBuffer = "";
String bleRxBuffer    = "";
volatile bool hasPendingConfigJson = false;
String pendingConfigJson = "";
BLECharacteristic* bleStatusChar = nullptr;

// Moving average / stability detection untuk berat badan
const int WEIGHT_BUF_SIZE = 10;
float weightBuf[WEIGHT_BUF_SIZE];
int weightBufIdx = 0;
bool weightBufFilled = false;

unsigned long lastTelemetryMs = 0;
unsigned long lastMqttAttemptMs = 0;
unsigned long lastWifiAttemptMs = 0;

String topicTelemetry() { return "mapotech/" + faskesId + "/vitascale/" + deviceId + "/telemetry"; }
String topicStatus()    { return "mapotech/" + faskesId + "/vitascale/" + deviceId + "/status"; }
String topicCommand()   { return "mapotech/" + faskesId + "/vitascale/" + deviceId + "/command"; }

void sendStatusReply(const String& status, const String& msg) {
  StaticJsonDocument<256> doc;
  doc["status"] = status;
  doc["message"] = msg;
  doc["device_id"] = deviceId;
  doc["faskes_id"] = faskesId;
  doc["ssid"] = wifiSsid;
  doc["wifi_connected"] = (WiFi.status() == WL_CONNECTED);
  String out;
  serializeJson(doc, out);
  Serial.println(out);
  if (bleStatusChar != nullptr) {
    bleStatusChar->setValue(out.c_str());
    bleStatusChar->notify();
  }
}

void saveConfigToPrefs() {
  prefs.putString("ssid", wifiSsid);
  prefs.putString("pass", wifiPass);
  prefs.putString("broker", mqttBroker);
  prefs.putInt("port", mqttPort);
  prefs.putString("faskes", faskesId);
  prefs.putString("dev", deviceId);
  prefs.putFloat("pole", poleHeightCm);
  prefs.putFloat("cal", calFactor);
}

void loadConfigFromPrefs() {
  wifiSsid     = prefs.getString("ssid", "");
  wifiPass     = prefs.getString("pass", "");
  mqttBroker   = prefs.getString("broker", "broker.hivemq.com");
  mqttPort     = prefs.getInt("port", 1883);
  faskesId     = prefs.getString("faskes", "PUSKESMAS-001");
  deviceId     = prefs.getString("dev", "VTS-001");
  poleHeightCm = prefs.getFloat("pole", 166.0f);
  calFactor    = prefs.getFloat("cal", 25.75f);
  if (mqttPort == 8884 || mqttPort == 8084 || mqttPort == 8083) {
    mqttPort = 1883; // Normalisasi port browser WSS menjadi MQTT TCP ESP32
  }
}

void applyConfigJson(const String& rawJson) {
  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, rawJson);
  if (err) {
    sendStatusReply("error", "JSON konfigurasi tidak valid");
    return;
  }

  String cmd = doc["cmd"] | (doc["command"] | "setup");
  if (cmd == "tare") {
    scale.tare(10);
    sendStatusReply("ok", "Tare selesai");
    return;
  }

  if (doc.containsKey("ssid")) {
    String s = doc["ssid"].as<String>();
    s.trim();
    if (s.length() > 0) wifiSsid = s;
  }
  if (doc.containsKey("password")) {
    wifiPass = doc["password"].as<String>();
  }
  if (doc.containsKey("broker")) {
    String b = doc["broker"].as<String>();
    b.trim();
    if (b.length() > 0) mqttBroker = b;
  }
  if (doc.containsKey("port") && doc["port"].as<int>() > 0) {
    int p = doc["port"].as<int>();
    mqttPort = (p == 8884 || p == 8084 || p == 8083) ? 1883 : p;
  }
  if (doc.containsKey("faskes_id")) {
    String f = doc["faskes_id"].as<String>();
    f.trim();
    if (f.length() > 0) faskesId = f;
  }
  if (doc.containsKey("device_id")) {
    String d = doc["device_id"].as<String>();
    d.trim();
    if (d.length() > 0) deviceId = d;
  }
  if (doc.containsKey("pole_height_cm") && doc["pole_height_cm"].as<float>() > 0) {
    poleHeightCm = doc["pole_height_cm"].as<float>();
  }
  if (doc.containsKey("cal_factor") && doc["cal_factor"].as<float>() > 0) {
    calFactor = doc["cal_factor"].as<float>();
    scale.set_scale(calFactor);
  }

  saveConfigToPrefs();
  sendStatusReply("ok", "Konfigurasi tersimpan, menghubungkan Wi-Fi & MQTT");

  // Terapkan langsung tanpa menunggu reboot manual
  mqtt.disconnect();
  WiFi.disconnect(true);
  delay(200);
  if (wifiSsid.length() > 0) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
  }
}

// --- BLE CALLBACKS (Untuk provisioning wireless Web Bluetooth Chrome/Edge) ---
class ConfigCharCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    String chunk = pCharacteristic->getValue().c_str();
    if (chunk.length() == 0) return;
    bleRxBuffer += chunk;
    int nlIdx = bleRxBuffer.indexOf('\n');
    if (nlIdx >= 0) {
      String fullLine = bleRxBuffer.substring(0, nlIdx);
      bleRxBuffer = bleRxBuffer.substring(nlIdx + 1);
      fullLine.trim();
      if (fullLine.length() > 0) {
        pendingConfigJson = fullLine;
        hasPendingConfigJson = true;
      }
    }
    if (bleRxBuffer.length() > 1024) {
      bleRxBuffer = "";
    }
  }
};

void startBleProvisioning() {
  String bleName = "VitaScale-" + deviceId;
  BLEDevice::init(bleName.c_str());
  BLEServer* server = BLEDevice::createServer();
  BLEService* service = server->createService(BLE_SERVICE_UUID);

  BLECharacteristic* configChar = service->createCharacteristic(
    BLE_CHAR_CONFIG_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  configChar->setCallbacks(new ConfigCharCallbacks());

  bleStatusChar = service->createCharacteristic(
    BLE_CHAR_STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  bleStatusChar->addDescriptor(new BLE2902());

  service->start();
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
}

// --- MQTT CALLBACK (Command dari Web App MAPOTECH) ---
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String msg;
  msg.reserve(length + 1);
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  StaticJsonDocument<512> doc;
  if (deserializeJson(doc, msg)) return;

  String command = doc["command"] | "";
  if (command == "tare") {
    scale.tare(10);
  } else if (command == "calibrate") {
    float weightG = doc["weight_g"] | 0.0f;
    if (weightG > 0.0f) {
      long raw = scale.get_value(10);
      calFactor = (float)raw / weightG;
      scale.set_scale(calFactor);
      saveConfigToPrefs();
    }
  } else if (command == "set_wifi" || command == "set_config") {
    applyConfigJson(msg);
  }
}

float readUltrasonicDistCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration <= 0) return -1.0f;
  return (duration * 0.0343f) / 2.0f;
}

void setup() {
  Serial.begin(115200);
  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  prefs.begin("vitascale", false);
  loadConfigFromPrefs();

  scale.begin(HX711_DOUT_PIN, HX711_SCK_PIN);
  scale.set_scale(calFactor);
  scale.tare(5);

  startBleProvisioning();

  if (wifiSsid.length() > 0) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
  }

  mqtt.setServer(mqttBroker.c_str(), mqttPort);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512);
}

void loop() {
  // 1. Baca provisioning langsung via USB Web Serial
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n') {
      serialRxBuffer.trim();
      if (serialRxBuffer.startsWith("{")) {
        applyConfigJson(serialRxBuffer);
      }
      serialRxBuffer = "";
    } else if (c != '\r') {
      serialRxBuffer += c;
      if (serialRxBuffer.length() > 1024) serialRxBuffer = "";
    }
  }

  // 2. Proses konfigurasi masuk dari BLE GATT
  if (hasPendingConfigJson) {
    String jsonCopy = pendingConfigJson;
    hasPendingConfigJson = false;
    applyConfigJson(jsonCopy);
  }

  // 3. Jaga koneksi Wi-Fi (tanpa captive portal 192.168.4.1)
  if (wifiSsid.length() > 0 && WiFi.status() != WL_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, LOW);
    if (millis() - lastWifiAttemptMs > 10000) {
      lastWifiAttemptMs = millis();
      WiFi.begin(wifiSsid.c_str(), wifiPass.c_str());
    }
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, LOW);
    return;
  }

  digitalWrite(STATUS_LED_PIN, HIGH);

  // 4. Jaga koneksi MQTT
  if (!mqtt.connected()) {
    if (millis() - lastMqttAttemptMs > 4000) {
      lastMqttAttemptMs = millis();
      mqtt.setServer(mqttBroker.c_str(), mqttPort);
      String clientId = "esp32_" + deviceId + "_" + String((uint32_t)ESP.getEfuseMac(), HEX);
      if (mqtt.connect(clientId.c_str(), topicStatus().c_str(), 1, true, "{\"status\":\"offline\"}")) {
        mqtt.publish(topicStatus().c_str(), "{\"status\":\"online\"}", true);
        mqtt.subscribe(topicCommand().c_str());
      }
    }
    return;
  }

  mqtt.loop();

  // 5. Kirim telemetri sensor tiap 500 ms
  if (millis() - lastTelemetryMs >= 500) {
    lastTelemetryMs = millis();

    float kg = scale.is_ready() ? (scale.get_units(3) / 1000.0f) : 0.0f;
    if (kg < 0.0f && kg > -0.05f) kg = 0.0f;

    weightBuf[weightBufIdx] = kg;
    weightBufIdx = (weightBufIdx + 1) % WEIGHT_BUF_SIZE;
    if (weightBufIdx == 0) weightBufFilled = true;

    bool isStable = false;
    if (weightBufFilled && kg > 0.2f) {
      float minW = weightBuf[0], maxW = weightBuf[0];
      for (int i = 1; i < WEIGHT_BUF_SIZE; i++) {
        if (weightBuf[i] < minW) minW = weightBuf[i];
        if (weightBuf[i] > maxW) maxW = weightBuf[i];
      }
      isStable = (maxW - minW) <= 0.05f;
    }

    float rawDist = readUltrasonicDistCm();
    float heightCm = (rawDist > 0.0f && rawDist < poleHeightCm)
      ? (poleHeightCm - rawDist)
      : 0.0f;

    StaticJsonDocument<384> doc;
    doc["device_id"] = deviceId;
    doc["faskes_id"] = faskesId;
    doc["rssi_dbm"]  = WiFi.RSSI();

    JsonObject w = doc.createNestedObject("weight");
    w["val_kg"] = roundf(kg * 100.0f) / 100.0f;
    w["is_stable"] = isStable;
    w["unit"] = "kg";

    JsonObject h = doc.createNestedObject("height");
    h["val_cm"] = roundf(heightCm * 10.0f) / 10.0f;
    h["raw_dist_cm"] = rawDist > 0 ? roundf(rawDist * 10.0f) / 10.0f : 0.0f;
    h["pole_height_cm"] = poleHeightCm;
    h["is_stable"] = isStable;
    h["unit"] = "cm";

    String out;
    serializeJson(doc, out);
    mqtt.publish(topicTelemetry().c_str(), out.c_str());
  }
}
