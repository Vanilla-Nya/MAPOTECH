import time
import json
import random
import sys

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("Modul 'paho-mqtt' belum terinstall.")
    print("Silakan jalankan: pip install paho-mqtt")
    sys.exit(1)

# ==============================================================================
# VITASCALE IOT VIRTUAL SIMULATOR (MAPOTECH)
# Mengirimkan telemetri virtual Sensor Ultrasonik (Tinggi) & Load Cell (Berat)
# ==============================================================================

BROKER = "broker.emqx.io"
PORT = 1883
DEVICE_ID = "VTS-001"
FASKES_ID = "PUSKESMAS-001"
TOPIC_TELEMETRY = f"mapotech/{FASKES_ID}/vitascale/{DEVICE_ID}/telemetry"
TOPIC_STATUS = f"mapotech/{FASKES_ID}/vitascale/{DEVICE_ID}/status"

POLE_HEIGHT_CM = 200.0  # Ketinggian tiang acuan sensor ultrasonik (cm)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"[MQTT] Berhasil terhubung ke broker {BROKER}:{PORT}")
        # Kirim status online (Retained message)
        client.publish(TOPIC_STATUS, json.dumps({"status": "online", "device": DEVICE_ID}), retain=True)
    else:
        print(f"[MQTT] Gagal terhubung ke broker, kode hasil: {rc}")

client = mqtt.Client(client_id=f"vitascale_sim_{int(time.time())}")
client.on_connect = on_connect

print("==================================================")
print(" VITASCALE VIRTUAL MQTT SIMULATOR")
print(f" Broker  : {BROKER}:{PORT}")
print(f" Topik   : {TOPIC_TELEMETRY}")
print("==================================================")
print("Menghubungkan ke broker MQTT...")

try:
    client.connect(BROKER, PORT, 60)
except Exception as e:
    print(f"Error koneksi ke broker: {e}")
    sys.exit(1)

client.loop_start()

# Profil target simulasi balita: Tinggi ~84.5 cm, Berat ~11.8 kg
target_height = 84.5
target_weight = 11.8
cycle = 0

try:
    print("\n[SIMULATOR BERJALAN]")
    print("Mensimulasikan balita naik ke stadiometer & timbangan...")
    print("Tekan Ctrl+C di terminal untuk menghentikan simulasi.\n")

    while True:
        cycle += 1
        
        # 6 siklus pertama (~3 detik): Balita bergerak/goyang saat baru naik (is_stable = False)
        # Setelah itu: Nilai stabil (is_stable = True)
        is_stable = cycle > 6

        noise_w = 0.0 if is_stable else (random.random() - 0.5) * 0.5
        noise_h = 0.0 if is_stable else (random.random() - 0.5) * 1.2

        current_weight = round(max(0.0, target_weight + noise_w), 2)
        current_height = round(max(0.0, target_height + noise_h), 1)
        raw_ultrasonic_dist = round(POLE_HEIGHT_CM - current_height, 1)

        payload = {
            "device_id": DEVICE_ID,
            "faskes_id": FASKES_ID,
            "timestamp": int(time.time()),
            "weight": {
                "val_kg": current_weight,
                "is_stable": is_stable,
                "unit": "kg"
            },
            "height": {
                "val_cm": current_height,
                "raw_dist_cm": raw_ultrasonic_dist,
                "pole_height_cm": POLE_HEIGHT_CM,
                "is_stable": is_stable,
                "unit": "cm"
            },
            "battery": {
                "percentage": 94,
                "is_charging": False
            },
            "rssi_dbm": -64
        }

        client.publish(TOPIC_TELEMETRY, json.dumps(payload))
        
        status_badge = "✅ STABIL (Kunci)" if is_stable else "⏳ MENGUKUR (Goyang)"
        print(f"[{time.strftime('%H:%M:%S')}] TB: {current_height} cm (Jarak: {raw_ultrasonic_dist} cm) | BB: {current_weight} kg | {status_badge}")

        time.sleep(0.5)

except KeyboardInterrupt:
    print("\n[SIMULATOR] Menghentikan transmisi...")
    client.publish(TOPIC_STATUS, json.dumps({"status": "offline", "device": DEVICE_ID}), retain=True)
    time.sleep(0.2)
    client.loop_stop()
    client.disconnect()
    print("Simulator MQTT VitaScale telah ditutup dengan aman.")
