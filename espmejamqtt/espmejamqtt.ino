#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <PubSubClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <ArduinoJson.h>

// ========================================
// PIN CONFIGURATION
// ========================================
#define SS_PIN    D2  // GPIO4
#define RST_PIN   D1  // GPIO5
#define RELAY_PIN D4  // GPIO2

// ✅ LED Pins (indicator pesanan)
#define LED_PREPARING_PIN D8  // GPIO15 - LED kuning: sedang preparing
#define LED_READY_PIN     D0  // GPIO16 - LED hijau: pesanan ready

// ========================================
// WIFI CONFIGURATION
// ========================================
const char* ssid = "cumi bakarr";
const char* password = "1020304050";

// ========================================
// MQTT CONFIGURATION (HiveMQ Cloud)
// ========================================
const char* mqtt_server = "aa76b3bfe96d48c7b7203acbc3c437ed.s1.eu.hivemq.cloud";
const int mqtt_port = 8883;
const char* mqtt_user = "Admin";
const char* mqtt_pass = "Admin123";

// ========================================
// SERVER CONFIGURATION
// ========================================
String serverIP = "10.147.116.127";
int serverPort = 8000;
int table_id = 1; // ← GANTI: 1, 2, 3, dst

String activateURL = "http://" + serverIP + ":" + String(serverPort) + "/api/rfid/activate-table";
String checkCardURL = "http://" + serverIP + ":" + String(serverPort) + "/api/rfid/check-card/";
String checkOrderURL = "http://" + serverIP + ":" + String(serverPort) + "/api/pesanan/check-table/";

// ========================================
// GLOBALS
// ========================================
WiFiClientSecure espClient;
PubSubClient mqtt(espClient);
MFRC522 rfid(SS_PIN, RST_PIN);

bool hasActiveSession = false;
bool cardCurrentlyPresent = false;
byte sessionUID[4];
String currentUID = "";
unsigned long lastSeenTime = 0;
unsigned long lastStatusCheck = 0;
unsigned long lastRefresh = 0;
unsigned long lastOrderCheck = 0; // ✅ NEW: untuk check status pesanan

const unsigned long CARD_TIMEOUT = 2000;
const unsigned long STATUS_CHECK_INTERVAL = 10000; // ✅ FIXED: 10 detik (lebih jarang)
const unsigned long RFID_REFRESH = 1500;
const unsigned long ORDER_CHECK_INTERVAL = 5000; // ✅ FIXED: 5 detik (lebih jarang)
int cardCheckFailCount = 0; // ✅ NEW: counter untuk failed checks
const int MAX_FAIL_BEFORE_DEACTIVATE = 2; // ✅ NEW: baru deactivate setelah 3x fail berturut-turut

// ✅ LED Status
enum LedStatus {
  LED_OFF,
  LED_PREPARING,
  LED_READY
};
LedStatus currentLedStatus = LED_OFF;

// ========================================
// MQTT TOPICS
// ========================================
String topicStatus = "warungkopi/table/" + String(table_id) + "/status";
String topicRelay = "warungkopi/table/" + String(table_id) + "/relay";
String topicLed = "warungkopi/table/" + String(table_id) + "/led";
String topicKitchen = "warungkopi/kitchen/#";

// ========================================
// SETUP
// ========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n========================================");
  Serial.println("   ESP TABLE WITH AUTO LED CONTROL");
  Serial.println("========================================");
  Serial.print("Meja ID: ");
  Serial.println(table_id);
  Serial.print("MQTT: ");
  Serial.println(mqtt_server);
  Serial.println("========================================\n");
  
  // ✅ Setup Relay
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);
  Serial.println("✓ Relay: OFF");
  
  // ✅ Setup LED pins
  pinMode(LED_PREPARING_PIN, OUTPUT);
  pinMode(LED_READY_PIN, OUTPUT);
  digitalWrite(LED_PREPARING_PIN, LOW);
  digitalWrite(LED_READY_PIN, LOW);
  Serial.println("✓ LEDs: OFF (PREPARING=LOW, READY=LOW)");
  
  // ✅ Test LEDs saat startup
  Serial.println("\n🔆 Testing LEDs...");
  
  // Test LED Preparing (Kuning)
  Serial.println("  Testing PREPARING LED (Kuning)...");
  digitalWrite(LED_PREPARING_PIN, HIGH);
  delay(1000);
  digitalWrite(LED_PREPARING_PIN, LOW);
  
  // Test LED Ready (Hijau)
  Serial.println("  Testing READY LED (Hijau)...");
  digitalWrite(LED_READY_PIN, HIGH);
  delay(1000);
  digitalWrite(LED_READY_PIN, LOW);
  
  Serial.println("✓ LED Test Complete\n");
  
  // ✅ Setup RFID
  SPI.begin();
  rfid.PCD_Init();
  Serial.println("✓ RFID initialized");
  
  // ✅ Connect WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✓ WiFi Connected");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  
  // ✅ Setup MQTT
  espClient.setInsecure();
  mqtt.setServer(mqtt_server, mqtt_port);
  mqtt.setCallback(mqttCallback);
  
  connectMQTT();
  
  Serial.println("\n✓✓✓ READY ✓✓✓\n");
}

// ========================================
// MQTT CONNECT
// ========================================
void connectMQTT() {
  Serial.print("Connecting to MQTT...");
  
  String clientId = "ESP_Table_" + String(table_id) + "_" + String(random(0xffff), HEX);
  
  int attempts = 0;
  while (!mqtt.connected() && attempts < 3) {
    if (mqtt.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println(" Connected!");
      
      // ✅ Subscribe to LED control topic
      mqtt.subscribe(topicLed.c_str());
      Serial.print("Subscribed: ");
      Serial.println(topicLed);
      
      // ✅ Subscribe to kitchen topics untuk monitoring
      mqtt.subscribe(topicKitchen.c_str());
      Serial.print("Subscribed: ");
      Serial.println(topicKitchen);
      
      // Publish initial status
      publishStatus();
      
    } else {
      Serial.print(" Failed, rc=");
      Serial.println(mqtt.state());
      attempts++;
      delay(2000);
    }
  }
}

// ========================================
// ✅ LED CONTROL FUNCTIONS
// ========================================
void setLedStatus(LedStatus status) {
  if (currentLedStatus == status) {
    return; // Sudah dalam status yang diminta
  }
  
  currentLedStatus = status;
  
  switch (status) {
    case LED_PREPARING:
      digitalWrite(LED_PREPARING_PIN, HIGH);  // Kuning ON
      digitalWrite(LED_READY_PIN, LOW);       // Hijau OFF
      Serial.println("💡 LED: PREPARING (Kuning ON, Hijau OFF)");
      break;
      
    case LED_READY:
      digitalWrite(LED_PREPARING_PIN, LOW);   // Kuning OFF
      digitalWrite(LED_READY_PIN, HIGH);      // Hijau ON
      Serial.println("💡 LED: READY (Kuning OFF, Hijau ON)");
      break;
      
    case LED_OFF:
    default:
      digitalWrite(LED_PREPARING_PIN, LOW);   // Kuning OFF
      digitalWrite(LED_READY_PIN, LOW);       // Hijau OFF
      Serial.println("💡 LED: OFF (Kuning OFF, Hijau OFF)");
      break;
  }
  
  publishStatus();
}

// ========================================
// ✅ NEW: CHECK ORDER STATUS FROM SERVER
// ========================================
void checkOrderStatus() {
  if (!hasActiveSession) {
    // Tidak ada sesi aktif, matikan LED
    if (currentLedStatus != LED_OFF) {
      Serial.println("🔍 No active session - LED OFF");
      setLedStatus(LED_OFF);
    }
    return;
  }
  
  Serial.println("\n========================================");
  Serial.println("🔍 CHECKING ORDER STATUS");
  Serial.print("  Table ID: ");
  Serial.println(table_id);
  
  WiFiClient client;
  HTTPClient http;
  String url = checkOrderURL + String(table_id);
  
  Serial.print("  URL: ");
  Serial.println(url);
  
  http.begin(client, url);
  int httpCode = http.GET();
  String response = http.getString();
  
  Serial.print("  Response Code: ");
  Serial.println(httpCode);
  
  if (httpCode == 200) {
    // Parse JSON response
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      bool hasOrder = doc["has_order"] | false;
      const char* status = doc["status"] | "";
      
      Serial.print("  Has Order: ");
      Serial.println(hasOrder ? "YES" : "NO");
      Serial.print("  Status: ");
      Serial.println(status);
      
      if (hasOrder) {
        String statusStr = String(status);
        
        if (statusStr == "preparing") {
          Serial.println("  Action: Set LED to PREPARING");
          setLedStatus(LED_PREPARING);
        } 
        else if (statusStr == "ready") {
          Serial.println("  Action: Set LED to READY");
          setLedStatus(LED_READY);
        }
        else if (statusStr == "paid" || statusStr == "placed") {
          // Order baru dibuat, belum preparing
          Serial.println("  Action: LED OFF (order belum preparing)");
          setLedStatus(LED_OFF);
        }
        else {
          // completed, cancelled, etc
          Serial.println("  Action: LED OFF (order selesai/dibatalkan)");
          setLedStatus(LED_OFF);
        }
      } else {
        Serial.println("  Action: LED OFF (no order)");
        setLedStatus(LED_OFF);
      }
      
    } else {
      Serial.print("  ❌ JSON Parse Error: ");
      Serial.println(error.c_str());
    }
  } else {
    Serial.println("  ❌ HTTP Error");
  }
  
  http.end();
  Serial.println("========================================\n");
}

// ========================================
// MQTT CALLBACK (Receive Messages)
// ========================================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("📥 MQTT Received [");
  Serial.print(topic);
  Serial.print("]: ");
  
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  // Parse JSON
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("❌ JSON parse failed");
    return;
  }
  
  // ✅ Handle LED control (dari Flutter)
  if (String(topic) == topicLed) {
    bool preparing = doc["preparing"] | false;
    bool ready = doc["ready"] | false;
    
    Serial.println("\n========================================");
    Serial.println("🎛️  LED CONTROL RECEIVED (MQTT)");
    Serial.print("  Preparing: ");
    Serial.println(preparing ? "TRUE" : "FALSE");
    Serial.print("  Ready: ");
    Serial.println(ready ? "TRUE" : "FALSE");
    Serial.println("========================================");
    
    if (preparing) {
      setLedStatus(LED_PREPARING);
    } else if (ready) {
      setLedStatus(LED_READY);
    } else {
      setLedStatus(LED_OFF);
    }
  }
  
  // ✅ Monitor kitchen topics (untuk auto-trigger check)
  if (String(topic).startsWith("warungkopi/kitchen/")) {
    int tableId = doc["table_id"] | 0;
    
    if (tableId == table_id) {
      Serial.println("\n========================================");
      Serial.println("📋 KITCHEN EVENT FOR THIS TABLE");
      Serial.print("  Topic: ");
      Serial.println(topic);
      Serial.print("  Table ID: ");
      Serial.println(tableId);
      Serial.println("  Action: Trigger order check");
      Serial.println("========================================\n");
      
      // ✅ Langsung check status dari server
      checkOrderStatus();
    }
  }
}

// ========================================
// PUBLISH STATUS
// ========================================
void publishStatus() {
  if (!mqtt.connected()) return;
  
  StaticJsonDocument<256> doc;
  doc["table_id"] = table_id;
  doc["has_session"] = hasActiveSession;
  doc["card_present"] = cardCurrentlyPresent;
  doc["card_uid"] = currentUID;
  doc["relay_on"] = (digitalRead(RELAY_PIN) == LOW);
  doc["led_preparing"] = (digitalRead(LED_PREPARING_PIN) == HIGH);
  doc["led_ready"] = (digitalRead(LED_READY_PIN) == HIGH);
  doc["timestamp"] = millis();
  
  String output;
  serializeJson(doc, output);
  
  mqtt.publish(topicStatus.c_str(), output.c_str());
  
  Serial.print("📤 Published status: ");
  Serial.println(output);
}

// ========================================
// HTTP: ACTIVATE TABLE
// ========================================
bool activateTable(String uid) {
  Serial.println("\n>>> ACTIVATING TABLE <<<");
  
  WiFiClient client;
  HTTPClient http;
  http.begin(client, activateURL);
  http.addHeader("Content-Type", "application/json");
  
  String json = "{\"card_uid\":\"" + uid + "\",\"table_id\":" + String(table_id) + "}";
  Serial.println("Sending: " + json);
  
  int httpCode = http.POST(json);
  String response = http.getString();
  
  Serial.print("Response Code: ");
  Serial.println(httpCode);
  Serial.print("Response Body: ");
  Serial.println(response);
  
  http.end();
  
  bool success = (httpCode == 200 && response.indexOf("\"success\":true") != -1);
  
  if (success) {
    publishStatus();
  }
  
  Serial.println(success ? "✓ SUCCESS" : "✗ FAILED");
  Serial.println("<<< END ACTIVATION >>>\n");
  
  return success;
}

// ========================================
// HTTP: CHECK CARD STATUS
// ========================================
bool checkCardStatus(String uid) {
  Serial.println("\n>>> CHECKING CARD STATUS <<<");
  
  WiFiClient client;
  HTTPClient http;
  String url = checkCardURL + uid;
  
  Serial.println("URL: " + url);
  
  http.begin(client, url);
  http.setTimeout(5000); // ✅ Timeout 5 detik
  int httpCode = http.GET();
  String response = http.getString();
  
  Serial.print("Response Code: ");
  Serial.println(httpCode);
  Serial.print("Response Body: ");
  Serial.println(response);
  
  http.end();
  
  bool sessionValid = false;
  
  if (httpCode == 200) {
    // ✅ Parse JSON untuk akurasi lebih baik
    StaticJsonDocument<512> doc;
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      // Cek dari JSON response
      bool success = doc["success"] | false;
      const char* status = doc["status"] | "";
      bool sessionValidJson = doc["session_valid"] | false;
      
      Serial.print("Success: ");
      Serial.println(success ? "true" : "false");
      Serial.print("Status: ");
      Serial.println(status);
      Serial.print("Session Valid: ");
      Serial.println(sessionValidJson ? "true" : "false");
      
      String statusStr = String(status);
      
      // ✅ Session valid jika:
      // 1. success = true
      // 2. status = "running" atau "in_use" 
      // 3. ATAU session_valid = true
      if (success) {
        if (statusStr == "running" || statusStr == "in_use" || sessionValidJson) {
          sessionValid = true;
        }
      }
    } else {
      Serial.print("JSON Parse Error: ");
      Serial.println(error.c_str());
      
      // ✅ Fallback ke string parsing jika JSON gagal
      if (response.indexOf("\"status\":\"running\"") != -1 || 
          response.indexOf("\"status\":\"in_use\"") != -1 ||
          response.indexOf("\"session_valid\":true") != -1) {
        sessionValid = true;
      }
    }
  } else {
    Serial.println("❌ HTTP Request Failed!");
  }
  
  Serial.print("Final Session Valid: ");
  Serial.println(sessionValid ? "YES ✓" : "NO ✗");
  Serial.println("<<< END CHECK >>>\n");
  
  return sessionValid;
}

// ========================================
// RFID: READ UID
// ========================================
String readCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

bool isSameUID(byte *a, byte *b) {
  for (byte i = 0; i < 4; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ========================================
// RELAY CONTROL
// ========================================
void turnRelayOn() {
  digitalWrite(RELAY_PIN, LOW);
  Serial.println("[RELAY] ⚡ ON");
  publishStatus();
}

void turnRelayOff() {
  digitalWrite(RELAY_PIN, HIGH);
  Serial.println("[RELAY] ⭘ OFF");
  publishStatus();
}

// ========================================
// MAIN LOOP
// ========================================
void loop() {
  // Maintain MQTT connection
  if (!mqtt.connected()) {
    connectMQTT();
  }
  mqtt.loop();
  
  unsigned long now = millis();
  
  // Refresh RFID
  if (now - lastRefresh > RFID_REFRESH) {
    rfid.PCD_Reset();
    rfid.PCD_Init();
    lastRefresh = now;
  }
  
  // ========================================
  // ✅ PERIODIC ORDER STATUS CHECK
  // ========================================
  if (now - lastOrderCheck > ORDER_CHECK_INTERVAL) {
    checkOrderStatus();
    lastOrderCheck = now;
  }
  
  // ========================================
  // PERIODIC CARD STATUS CHECK
  // ========================================
  if (hasActiveSession && (now - lastStatusCheck > STATUS_CHECK_INTERVAL)) {
    Serial.println("\n========================================");
    Serial.println("🔍 PERIODIC CARD CHECK");
    Serial.print("Session UID: ");
    Serial.println(currentUID);
    Serial.print("Fail Count: ");
    Serial.println(cardCheckFailCount);
    Serial.println("========================================");
    
    bool stillValid = checkCardStatus(currentUID);
    
    if (!stillValid) {
      cardCheckFailCount++; // ✅ Increment fail counter
      
      Serial.print("⚠️ Check failed! Count: ");
      Serial.println(cardCheckFailCount);
      
      // ✅ Baru deactivate setelah beberapa kali fail berturut-turut
      if (cardCheckFailCount >= MAX_FAIL_BEFORE_DEACTIVATE) {
        Serial.println("\n⚠️⚠️⚠️ CARD DEACTIVATED (After multiple fails)! ⚠️⚠️⚠️");
        
        hasActiveSession = false;
        cardCurrentlyPresent = false;
        currentUID = "";
        cardCheckFailCount = 0;
        
        turnRelayOff();
        setLedStatus(LED_OFF);
        
        Serial.println("✓ SESSION ENDED\n");
      } else {
        Serial.println("⚠️ Will retry next check...\n");
      }
    } else {
      // ✅ Reset fail counter jika check berhasil
      if (cardCheckFailCount > 0) {
        Serial.print("✓ Check succeeded! Resetting fail count from ");
        Serial.println(cardCheckFailCount);
        cardCheckFailCount = 0;
      } else {
        Serial.println("✓ Session continues");
      }
      
      if (cardCurrentlyPresent && digitalRead(RELAY_PIN) == HIGH) {
        turnRelayOn();
      }
    }
    
    lastStatusCheck = now;
  }
  
  // ========================================
  // DETECT CARD
  // ========================================
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String uid = readCardUID();
    lastSeenTime = now;
    
    Serial.println("\n========================================");
    Serial.print("🔍 CARD: ");
    Serial.println(uid);
    Serial.println("========================================");
    
    if (!hasActiveSession) {
      Serial.println("Status: NO SESSION - Activating...");
      
      bool success = activateTable(uid);
      
      if (success) {
        for (byte i = 0; i < 4; i++) {
          sessionUID[i] = rfid.uid.uidByte[i];
        }
        
        hasActiveSession = true;
        cardCurrentlyPresent = true;
        currentUID = uid;
        cardCheckFailCount = 0; // ✅ Reset fail counter
        lastStatusCheck = now;
        
        turnRelayOn();
        
        // ✅ Check order status setelah activate
        checkOrderStatus();
        
        Serial.println("✓ SESSION STARTED\n");
      } else {
        Serial.println("✗ FAILED\n");
      }
    } else {
      if (isSameUID(rfid.uid.uidByte, sessionUID)) {
        if (!cardCurrentlyPresent) {
          Serial.println("[HOTEL] Card returned");
          cardCurrentlyPresent = true;
          turnRelayOn();
        }
      } else {
        Serial.println("⚠️  Different card - Ignored\n");
      }
    }
    
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
  }
  
  // ========================================
  // DETECT CARD REMOVED
  // ========================================
  if (hasActiveSession && cardCurrentlyPresent && (now - lastSeenTime > CARD_TIMEOUT)) {
    Serial.println("\n[HOTEL] Card removed");
    cardCurrentlyPresent = false;
    turnRelayOff();
    // ✅ LED tetap nyala (status pesanan tetap ada)
    Serial.println();
  }
  
  delay(100);
}