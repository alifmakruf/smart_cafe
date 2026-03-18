#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>

// ===================================================
// KONFIGURASI - GANTI SESUAI KEBUTUHAN
// ===================================================

// PIN Configuration
#define SS_PIN    D2   // SDA RFID
#define RST_PIN   D1   // RST RFID
#define RELAY_PIN D4   // Relay Control (Aktif LOW)

// WiFi Settings
const char* ssid = "cumi bakarr";
const char* password = "1020304050";

// Laravel API Settings
String serverIP = "172.25.30.20";
int serverPort = 8000;
int table_id = 2;

// API Endpoints
String activateURL = "http://" + serverIP + ":" + String(serverPort) + "/api/rfid/activate-table";
String deactivateURL = "http://" + serverIP + ":" + String(serverPort) + "/api/rfid/deactivate-table";
String testURL = "http://" + serverIP + ":" + String(serverPort) + "/api/v1/menus";

// ===================================================
// VARIABEL GLOBAL
// ===================================================

MFRC522 rfid(SS_PIN, RST_PIN);

// State Management untuk SAKLAR HOTEL
bool hasActiveSession = false;    // Ada session aktif atau tidak (sampai manual deactivate)
bool cardCurrentlyPresent = false; // Kartu sedang ditaruh atau tidak
byte sessionUID[4];                // UID kartu yang punya session
String currentUID = "";
unsigned long lastSeenTime = 0;
unsigned long lastRefresh = 0;

// Timeouts
const unsigned long CARD_TIMEOUT = 4000;     // 2 detik untuk deteksi "kartu diangkat"
const unsigned long RFID_REFRESH = 500;     // Refresh RFID setiap 1.5 detik

// ===================================================
// SETUP
// ===================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  printHeader();
  
  // Init Relay (OFF)
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);
  Serial.println("✓ Relay initialized (OFF)");
  
  // Init RFID
  SPI.begin();
  rfid.PCD_Init();
  Serial.println("✓ RFID RC522 initialized");
  
  // Connect WiFi
  connectWiFi();
  
  // Test Connection
  testConnection();
  
  printReady();
}

// ===================================================
// HELPER FUNCTIONS
// ===================================================

void printHeader() {
  Serial.println("\n\n========================================");
  Serial.println("   Smart Cafe - Hotel Switch System");
  Serial.println("========================================");
  Serial.println("Konsep: Saklar Hotel");
  Serial.println("  - Kartu ditaruh = Relay ON");
  Serial.println("  - Kartu diangkat = Relay OFF");
  Serial.println("  - Bisa ditaruh-angkat berkali-kali");
  Serial.println("========================================");
  Serial.print("Meja ID: ");
  Serial.println(table_id);
  Serial.print("Server: ");
  Serial.print(serverIP);
  Serial.print(":");
  Serial.println(serverPort);
  Serial.println("========================================\n");
}

void printReady() {
  Serial.println("\n========================================");
  Serial.println("           SYSTEM READY");
  Serial.println("========================================");
  Serial.println("Status:");
  Serial.print("  - Meja       : ");
  Serial.println(table_id);
  Serial.print("  - Session    : ");
  Serial.println(hasActiveSession ? "Active" : "No Session");
  Serial.print("  - Card Now   : ");
  Serial.println(cardCurrentlyPresent ? "Present" : "Removed");
  Serial.print("  - Relay      : ");
  Serial.println(digitalRead(RELAY_PIN) == LOW ? "ON" : "OFF");
  Serial.println("\nWaiting for customer card...\n");
}

void connectWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ WiFi Connected Successfully");
    Serial.print("  ESP IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("  Signal: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("✗ WiFi Connection FAILED!");
  }
}

void testConnection() {
  Serial.println("\n--- Testing Laravel Connection ---");
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("✗ WiFi not connected!");
    return;
  }
  
  WiFiClient client;
  HTTPClient http;
  
  http.begin(client, testURL);
  http.setTimeout(10000);
  
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    Serial.println("✓ Connection SUCCESS!");
  } else {
    Serial.println("✗ Connection FAILED");
    Serial.print("HTTP Code: ");
    Serial.println(httpCode);
  }
  
  http.end();
  Serial.println("--- End Test ---\n");
}

bool activateTable(String uid) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("✗ WiFi not connected");
    return false;
  }

  WiFiClient client;
  HTTPClient http;

  Serial.println("\n>>> ACTIVATING TABLE (First Time) <<<");
  Serial.print("  Card UID: ");
  Serial.println(uid);
  Serial.print("  Table: ");
  Serial.println(table_id);

  http.begin(client, activateURL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);

  String json = "{\"card_uid\":\"" + uid + "\",\"table_id\":" + String(table_id) + "}";
  
  int httpCode = http.POST(json);
  String response = "";
  
  if (httpCode > 0) {
    response = http.getString();
    Serial.print("  Response: ");
    Serial.println(response);
  }

  http.end();

  bool success = (httpCode == 200 && response.indexOf("\"success\":true") != -1);
  
  if (success) {
    Serial.println("✓ Table activated - Session started!");
  } else {
    Serial.println("✗ Activation failed!");
  }
  
  Serial.println("<<< END ACTIVATION >>>\n");
  return success;
}

bool isSameUID(byte *a, byte *b) {
  for (byte i = 0; i < 4; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void turnRelayOn() {
  digitalWrite(RELAY_PIN, LOW);  // Aktif LOW
  Serial.println("[RELAY] ⚡ ON");
}

void turnRelayOff() {
  digitalWrite(RELAY_PIN, HIGH);  // Aktif LOW
  Serial.println("[RELAY] ⭘ OFF");
}

String readCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// ===================================================
// MAIN LOOP - HOTEL SWITCH LOGIC
// ===================================================

void loop() {
  unsigned long now = millis();

  // Refresh RFID setiap 1.5 detik
  if (now - lastRefresh > RFID_REFRESH) {
    rfid.PCD_Reset();
    rfid.PCD_Init();
    lastRefresh = now;
  }

  // ========================================
  // DETEKSI KARTU RFID
  // ========================================
  
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String uid = readCardUID();
    lastSeenTime = now;
    
    // ========================================
    // CASE 1: BELUM ADA SESSION - Aktivasi pertama kali
    // ========================================
    
    if (!hasActiveSession) {
      Serial.println("\n========================================");
      Serial.println("🆕 NEW SESSION");
      Serial.print("Card UID: ");
      Serial.println(uid);
      Serial.println("========================================");
      Serial.println("Status: No active session");
      Serial.println("Action: Starting new session...");
      
      bool success = activateTable(uid);

      if (success) {
        // Simpan UID untuk session ini
        for (byte i = 0; i < 4; i++) {
          sessionUID[i] = rfid.uid.uidByte[i];
        }
        
        // Set state
        hasActiveSession = true;      // Session dimulai
        cardCurrentlyPresent = true;  // Kartu sedang ditaruh
        currentUID = uid;
        
        // Nyalakan relay
        turnRelayOn();
        
        Serial.println("✓ SESSION STARTED");
        Serial.println("✓ Relay ON (kartu ditaruh)");
        Serial.println("Info: Angkat kartu = relay OFF, taruh lagi = relay ON");
      } else {
        Serial.println("✗ FAILED TO START SESSION");
        Serial.println("Possible reasons:");
        Serial.println("  - Card not linked to order");
        Serial.println("  - Card not in 'running' status");
        Serial.println("  - Table already occupied");
      }
      
      Serial.println("========================================\n");
    }
    
    // ========================================
    // CASE 2: SUDAH ADA SESSION - Cek apakah kartu yang sama
    // ========================================
    
    else {
      if (isSameUID(rfid.uid.uidByte, sessionUID)) {
        // Kartu yang sama dengan session aktif
        
        if (!cardCurrentlyPresent) {
          // Kartu BARU ditaruh lagi setelah diangkat
          Serial.println("\n[HOTEL SWITCH] 🔌 Card placed back");
          cardCurrentlyPresent = true;
          turnRelayOn();
          Serial.println("Status: Card present, session continues\n");
        }
        // Else: kartu masih ditaruh, tidak perlu print apa-apa
        
      } else {
        // Kartu berbeda - abaikan
        Serial.println("\n⚠️  WARNING: Different card detected");
        Serial.print("Session card: ");
        Serial.println(currentUID);
        Serial.print("New card: ");
        Serial.println(uid);
        Serial.println("Action: Ignoring (table occupied)\n");
      }
    }

    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  }

  // ========================================
  // DETEKSI KARTU DIANGKAT (Hotel Switch OFF)
  // ========================================
  
  if (hasActiveSession && cardCurrentlyPresent && (now - lastSeenTime > CARD_TIMEOUT)) {
    Serial.println("\n[HOTEL SWITCH] 🔌 Card removed");
    
    // Update state
    cardCurrentlyPresent = false;
    
    // Matikan relay (hotel switch OFF)
    turnRelayOff();
    
    Serial.println("Status: Card removed, relay OFF");
    Serial.println("Info: Session masih aktif, taruh kartu lagi untuk ON");
    Serial.println("      Atau deactivate via Flutter untuk end session\n");
  }

  delay(100);
}