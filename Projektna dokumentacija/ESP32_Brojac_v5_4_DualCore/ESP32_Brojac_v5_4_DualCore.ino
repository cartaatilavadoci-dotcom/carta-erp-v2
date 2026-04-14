/*
 * ============================================
 * CARTA ERP - ESP32 Brojač sa Supabase
 * ============================================
 * 
 * Verzija: 5.4 (DUAL CORE POLLING)
 * 
 * PROMJENE vs v5.3:
 * - Core 1: Dedicirano brojanje (polling 1ms) - NEMA GUBITAKA!
 * - Core 0: HTTP, OLED, WiFi (može blokirati)
 * - Varijable volatile za thread-safety
 * 
 * POTREBNE BIBLIOTEKE:
 * - ArduinoJson (by Benoit Blanchon)
 * - Adafruit SSD1306
 * - Adafruit GFX
 */

#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <time.h>

// ============================================
// KONFIGURACIJA - PRILAGODI!
// ============================================

// WiFi
const char* WIFI_SSID = "carta_network";
const char* WIFI_PASS = "l1w?r$carta";

// Supabase
const char* SUPABASE_URL = "https://gusudzydgofdcywmvwbh.supabase.co";
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1c3VkenlkZ29mZGN5d212d2JoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU2OTg5ODEsImV4cCI6MjA4MTI3NDk4MX0.nvaFFyJcyNKWI2Yg2TpynDX-NsPdfzg3Cp87ur_E5qU";

// Stroj - PROMIJENI ZA SVAKU LINIJU!
const char* MACHINE_CODE = "NLI-2";  // NLI-1, NLI-2, WH-T1, WH-B1

// Hardware
#define BUTTON_PIN 23
#define SCREEN_WIDTH 128 
#define SCREEN_HEIGHT 64
#define OLED_ADDR 0x3C

// Timing
#define DEBOUNCE_MS 150
#define IDLE_TIMEOUT_MS 5000
#define DISPLAY_INTERVAL_MS 200
#define WIFI_CHECK_INTERVAL 30000
#define HEARTBEAT_INTERVAL 60000

// BATCH SYNC
#define SYNC_EVERY_N_PIECES 500
#define COMPENSATION_PIECES 6

// NTP (opcionalno - radi i bez)
const char* NTP_SERVER = "pool.ntp.org";
const long GMT_OFFSET_SEC = 3600;
const int DAYLIGHT_OFFSET_SEC = 3600;

// ============================================
// GLOBALNE VARIJABLE - VOLATILE za dual core!
// ============================================
volatile int tubes = 0;
volatile int syncedCount = 0;
volatile unsigned long lastPulseTime = 0;
volatile bool machineRunning = false;

int serverCount = 0;
int targetQuantity = 0;
String workOrderNumber = "";
String workOrderId = "";
bool hasActiveRN = false;

unsigned long stopStartTime = 0;

// BATCH SYNC
int lastBatchSyncAt = 0;
int lastSyncLogAt = 0;

// EVENT QUEUE
bool pendingStopEvent = false;
bool pendingStartEvent = false;
int pendingStartDuration = 0;
int stopEventCount = 0;
int startEventCount = 0;
bool pendingSyncLog = false;
int pendingSyncLogCount = 0;

unsigned long lastDisplayTime = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastHeartbeat = 0;
unsigned long startTime = 0;

Preferences preferences;
int offlineBuffer = 0;

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
WiFiServer server(80);

bool ntpSynced = false;

// DUAL CORE
TaskHandle_t countingTaskHandle = NULL;
volatile bool countingTaskRunning = false;

// ============================================
// CORE 1: COUNTING TASK (samo broji!)
// ============================================
void countingTask(void *parameter) {
  bool lastButtonState = HIGH;
  unsigned long lastDebounceTime = 0;
  
  Serial.println("🔢 Counting task started on Core 1");
  countingTaskRunning = true;
  
  while (true) {
    bool currentState = digitalRead(BUTTON_PIN);
    unsigned long now = millis();
    
    // FALLING edge detection (HIGH -> LOW)
    if (lastButtonState == HIGH && currentState == LOW) {
      if (now - lastDebounceTime >= DEBOUNCE_MS) {
        // BROJI!
        tubes++;
        lastDebounceTime = now;
        lastPulseTime = now;
        
        // Ako stroj nije radio, sad radi
        if (!machineRunning) {
          machineRunning = true;
        }
        
        // Debug svaki 100. impuls
        if (tubes % 100 == 0) {
          Serial.printf("📊 Count: %d (Core 1)\n", tubes);
        }
      }
    }
    
    lastButtonState = currentState;
    
    // Kratka pauza - 1ms polling
    delay(1);
  }
}

// ============================================
// SETUP
// ============================================
void setup() {
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("  CARTA ERP - ESP32 Brojač v5.4");
  Serial.println("  DUAL CORE POLLING");
  Serial.println("  Stroj: " + String(MACHINE_CODE));
  Serial.println("========================================\n");
  
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // OLED
  Wire.begin();
  delay(100);
  
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("OLED greška!");
  } else {
    Serial.println("✅ OLED OK");
  }
  showStatus("Pokretanje...");
  
  // NVS
  preferences.begin("counter", false);
  offlineBuffer = preferences.getInt("buffer", 0);
  tubes = preferences.getInt("local", 0);
  lastBatchSyncAt = preferences.getInt("lastBatch", 0);
  lastSyncLogAt = preferences.getInt("lastLog", 0);
  
  if (offlineBuffer < 0 || offlineBuffer > 10000000) {
    offlineBuffer = 0;
    preferences.putInt("buffer", 0);
  }
  if (tubes < 0 || tubes > 100000000) {
    tubes = 0;
    preferences.putInt("local", 0);
  }
  
  syncedCount = tubes;
  Serial.printf("📂 Loaded: tubes=%d, buffer=%d\n", tubes, offlineBuffer);
  
  // WiFi
  connectWiFi();
  
  // NTP - pokušaj, ali nije obavezno
  if (WiFi.status() == WL_CONNECTED) {
    configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
    struct tm timeinfo;
    if (getLocalTime(&timeinfo, 3000)) {
      ntpSynced = true;
      Serial.println("✅ NTP OK");
    } else {
      Serial.println("⚠️ NTP nije uspio - nastavlja bez");
    }
  }
  
  // Web server
  server.begin();
  Serial.println("🌐 Web server started");
  
  startTime = millis();
  lastPulseTime = millis();
  
  if (WiFi.status() == WL_CONNECTED) {
    checkActiveWorkOrder();
  }
  
  // ============================================
  // POKRENI COUNTING TASK NA CORE 1
  // ============================================
  xTaskCreatePinnedToCore(
    countingTask,           // Funkcija
    "CountingTask",         // Ime
    4096,                   // Stack size
    NULL,                   // Parametri
    2,                      // Prioritet (viši = važniji)
    &countingTaskHandle,    // Handle
    1                       // CORE 1
  );
  
  // Čekaj da task krene
  delay(100);
  
  Serial.println("\n✅ Spreman!");
  Serial.println("   Core 0: HTTP, OLED, WiFi");
  Serial.println("   Core 1: Counting (dedicated)");
  Serial.println("   Sync: 500 kom (+6) | OEE eventi aktivni\n");
}

// ============================================
// LOOP (Core 0) - HTTP, OLED, sync
// ============================================
void loop() {
  unsigned long now = millis();
  
  // Lokalne kopije volatile varijabli
  int currentTubes = tubes;
  unsigned long pulseTime = lastPulseTime;
  bool isRunning = machineRunning;
  
  // 1. OLED
  if (now - lastDisplayTime > DISPLAY_INTERVAL_MS) {
    updateDisplay();
    lastDisplayTime = now;
  }
  
  // 2. BATCH SYNC kad stroj stoji
  if (!isRunning && (currentTubes - lastBatchSyncAt >= SYNC_EVERY_N_PIECES)) {
    Serial.println("\n📊 Batch sync...");
    syncToSupabase(true);
  }
  
  // 3. IDLE DETECTION
  static bool wasRunning = false;
  if (isRunning && (now - pulseTime > IDLE_TIMEOUT_MS)) {
    machineRunning = false;
    stopStartTime = pulseTime;
    Serial.println("\n⏸️ Stroj stao");
    
    pendingStopEvent = true;
    stopEventCount = currentTubes;
    
    if (currentTubes > syncedCount || offlineBuffer > 0) {
      syncToSupabase(false);
    }
  }
  
  // 4. Detektiraj kad stroj krene (za START event)
  if (!wasRunning && isRunning) {
    // Stroj je upravo krenuo
    unsigned long stoppedDuration = now - stopStartTime;
    
    Serial.println("\n▶️ Stroj pokrenut!");
    
    if (pendingStopEvent) {
      pendingStartEvent = true;
      pendingStartDuration = stoppedDuration / 1000;
      startEventCount = currentTubes;
    }
  }
  wasRunning = isRunning;
  
  // 5. ŠALJI EVENTE kad stroj stoji
  if (!isRunning) {
    processEventQueue();
  }
  
  // 6. Spremi u NVS periodično
  static unsigned long lastNvsSave = 0;
  if (now - lastNvsSave > 10000) {
    preferences.putInt("local", currentTubes);
    lastNvsSave = now;
  }
  
  // 7. Sync log queue
  if (currentTubes - lastSyncLogAt >= SYNC_EVERY_N_PIECES) {
    pendingSyncLog = true;
    pendingSyncLogCount = currentTubes;
    lastSyncLogAt = currentTubes;
    preferences.putInt("lastLog", lastSyncLogAt);
    Serial.println("📊 Queue sync log @ " + String(currentTubes));
  }
  
  // 8. WiFi check
  if (now - lastWifiCheck > WIFI_CHECK_INTERVAL) {
    if (WiFi.status() != WL_CONNECTED) {
      connectWiFi();
    }
    lastWifiCheck = now;
  }
  
  // 9. Heartbeat
  if (now - lastHeartbeat > HEARTBEAT_INTERVAL) {
    if (WiFi.status() == WL_CONNECTED && !isRunning) {
      checkActiveWorkOrder();
    }
    lastHeartbeat = now;
  }
  
  // 10. Web server
  WiFiClient client = server.available();
  if (client) {
    handleWebClient(client);
  }
  
  delay(10);
}

// ============================================
// WiFi
// ============================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  
  Serial.print("📡 Connecting to ");
  Serial.println(WIFI_SSID);
  showStatus("WiFi...");
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("✅ Connected! IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n⚠️ WiFi failed");
  }
}

// ============================================
// EVENT QUEUE
// ============================================
void processEventQueue() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  if (pendingStopEvent) {
    if (sendStopEvent(stopEventCount)) {
      pendingStopEvent = false;
    }
  }
  
  if (pendingStartEvent && !pendingStopEvent) {
    if (sendStartEvent(startEventCount, pendingStartDuration)) {
      pendingStartEvent = false;
    }
  }
  
  if (pendingSyncLog && !pendingStopEvent && !pendingStartEvent) {
    if (sendSyncLog(pendingSyncLogCount)) {
      pendingSyncLog = false;
    }
  }
}

bool sendStopEvent(int count) {
  if (!hasActiveRN || workOrderId.length() == 0) return true;
  
  Serial.println("📤 STOP event @ " + String(count));
  
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/prod_machine_events";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Prefer", "return=minimal");
  http.setTimeout(5000);
  
  String payload = "{\"machine_code\":\"" + String(MACHINE_CODE) + "\","
                   "\"event_type\":\"STOP\","
                   "\"count_at_event\":" + String(count) + ","
                   "\"work_order_id\":\"" + workOrderId + "\","
                   "\"work_order_number\":\"" + workOrderNumber + "\"}";
  
  int httpCode = http.POST(payload);
  http.end();
  
  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ STOP sent");
    return true;
  } else {
    Serial.println("❌ STOP failed: " + String(httpCode));
    return false;
  }
}

bool sendStartEvent(int count, int durationSec) {
  if (!hasActiveRN || workOrderId.length() == 0) return true;
  
  Serial.println("📤 START event @ " + String(count) + " (idle " + String(durationSec) + "s)");
  
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/prod_machine_events";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Prefer", "return=minimal");
  http.setTimeout(5000);
  
  String payload = "{\"machine_code\":\"" + String(MACHINE_CODE) + "\","
                   "\"event_type\":\"START\","
                   "\"count_at_event\":" + String(count) + ","
                   "\"duration_seconds\":" + String(durationSec) + ","
                   "\"work_order_id\":\"" + workOrderId + "\","
                   "\"work_order_number\":\"" + workOrderNumber + "\"}";
  
  int httpCode = http.POST(payload);
  http.end();
  
  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ START sent");
    return true;
  } else {
    Serial.println("❌ START failed: " + String(httpCode));
    return false;
  }
}

bool sendSyncLog(int count) {
  if (!hasActiveRN || workOrderId.length() == 0) return true;
  
  Serial.println("📤 Sync log @ " + String(count));
  
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/prod_machine_counter_sync";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Prefer", "return=minimal");
  http.setTimeout(5000);
  
  int shiftNum = ntpSynced ? getShiftNumber() : 0;
  String prodDate = ntpSynced ? getProductionDate() : "";
  
  String payload = "{\"machine_code\":\"" + String(MACHINE_CODE) + "\","
                   "\"count_at_sync\":" + String(count) + ","
                   "\"work_order_id\":\"" + workOrderId + "\","
                   "\"work_order_number\":\"" + workOrderNumber + "\"";
  
  if (shiftNum > 0) {
    payload += ",\"shift_number\":" + String(shiftNum);
  }
  if (prodDate.length() > 0) {
    payload += ",\"production_date\":\"" + prodDate + "\"";
  }
  
  payload += "}";
  
  int httpCode = http.POST(payload);
  http.end();
  
  if (httpCode == 201 || httpCode == 200) {
    Serial.println("✅ Sync log sent");
    return true;
  } else {
    Serial.println("❌ Sync log failed: " + String(httpCode));
    return false;
  }
}

// ============================================
// ACTIVE WORK ORDER
// ============================================
void checkActiveWorkOrder() {
  if (WiFi.status() != WL_CONNECTED) return;
  
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/rpc/get_active_work_order";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(5000);
  
  String payload = "{\"p_machine_code\":\"" + String(MACHINE_CODE) + "\"}";
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    String response = http.getString();
    
    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, response);
    
    if (!error) {
      hasActiveRN = doc["active"].as<bool>();
      
      if (hasActiveRN) {
        workOrderId = doc["work_order_id"].as<String>();
        workOrderNumber = doc["work_order_number"].as<String>();
        targetQuantity = doc["target"].as<int>();
        int newServerCount = doc["count"].as<int>();
        
        int currentTubes = tubes;
        if (newServerCount > 0 && currentTubes == syncedCount && offlineBuffer == 0) {
          if (abs(newServerCount - currentTubes) > 10) {
            Serial.printf("🔄 Sync from server: %d -> %d\n", currentTubes, newServerCount);
            tubes = newServerCount;
            syncedCount = newServerCount;
            lastBatchSyncAt = newServerCount;
            preferences.putInt("local", newServerCount);
            preferences.putInt("lastBatch", newServerCount);
          }
        }
        
        serverCount = newServerCount;
        Serial.println("📋 RN: " + workOrderNumber + " | Cilj: " + String(targetQuantity) + " | Server: " + String(serverCount));
      } else {
        workOrderId = "";
        workOrderNumber = "";
        targetQuantity = 0;
        Serial.println("⏳ Nema aktivnog RN");
      }
    }
  }
  
  http.end();
}

// ============================================
// SYNC TO SUPABASE
// ============================================
void syncToSupabase(bool addCompensation) {
  int currentTubes = tubes;
  int newPulses = currentTubes - syncedCount + offlineBuffer;
  
  if (newPulses <= 0) return;
  
  if (WiFi.status() != WL_CONNECTED) {
    offlineBuffer += (currentTubes - syncedCount);
    syncedCount = currentTubes;
    preferences.putInt("buffer", offlineBuffer);
    return;
  }
  
  if (!hasActiveRN) {
    checkActiveWorkOrder();
    if (!hasActiveRN) {
      offlineBuffer += (currentTubes - syncedCount);
      syncedCount = currentTubes;
      preferences.putInt("buffer", offlineBuffer);
      return;
    }
  }
  
  Serial.println("📤 Sync +" + String(newPulses));
  
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/rpc/increment_machine_counter";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(5000);
  
  String deviceId = WiFi.macAddress();
  deviceId.replace(":", "");
  
  String payload = "{\"p_machine_code\":\"" + String(MACHINE_CODE) + "\","
                   "\"p_device_id\":\"" + deviceId + "\","
                   "\"p_increment\":" + String(newPulses) + "}";
  
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    String response = http.getString();
    
    DynamicJsonDocument doc(512);
    deserializeJson(doc, response);
    
    if (doc["success"].as<bool>()) {
      syncedCount = currentTubes;
      offlineBuffer = 0;
      preferences.putInt("buffer", 0);
      
      serverCount = doc["count"].as<int>();
      lastBatchSyncAt = currentTubes;
      preferences.putInt("lastBatch", lastBatchSyncAt);
      
      Serial.println("✅ Server: " + String(serverCount));
      
      if (addCompensation && COMPENSATION_PIECES > 0) {
        tubes += COMPENSATION_PIECES;
        preferences.putInt("local", tubes);
        Serial.println("➕ +" + String(COMPENSATION_PIECES) + " → " + String(tubes));
      }
    }
  } else {
    offlineBuffer += newPulses;
    syncedCount = currentTubes;
    preferences.putInt("buffer", offlineBuffer);
  }
  
  http.end();
}

// ============================================
// HELPER FUNCTIONS
// ============================================
int getShiftNumber() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return 0;
  
  int hour = timeinfo.tm_hour;
  if (hour >= 6 && hour < 14) return 1;
  if (hour >= 14 && hour < 22) return 2;
  return 3;
}

String getProductionDate() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "";
  
  if (timeinfo.tm_hour < 6) {
    time_t now = time(nullptr) - 86400;
    localtime_r(&now, &timeinfo);
  }
  
  char buf[11];
  strftime(buf, sizeof(buf), "%Y-%m-%d", &timeinfo);
  return String(buf);
}

// ============================================
// OLED DISPLAY
// ============================================
void updateDisplay() {
  int currentTubes = tubes;
  bool isRunning = machineRunning;
  
  display.clearDisplay();
  display.setTextColor(WHITE);
  
  display.setTextSize(1);
  display.setCursor(0, 0);
  
  if (hasActiveRN) {
    String rnShort = workOrderNumber;
    if (rnShort.length() > 12) rnShort = rnShort.substring(0, 10) + "..";
    display.print(rnShort);
    display.setCursor(100, 0);
    display.print(isRunning ? "RUN" : "IDL");
  } else {
    display.println("Ceka RN...");
  }
  
  display.drawLine(0, 10, 128, 10, WHITE);
  
  display.setTextSize(3);
  display.setCursor(5, 18);
  display.print(currentTubes);
  
  display.setTextSize(1);
  int pending = currentTubes - syncedCount + offlineBuffer;
  if (pending > 0 && pending < 100000) {
    display.setCursor(90, 20);
    display.print("+" + String(pending));
  }
  
  int toNextBatch = SYNC_EVERY_N_PIECES - (currentTubes - lastBatchSyncAt);
  if (toNextBatch > 0 && toNextBatch <= SYNC_EVERY_N_PIECES) {
    display.setCursor(90, 30);
    display.print("B:" + String(toNextBatch));
  }
  
  if (targetQuantity > 0) {
    display.setCursor(0, 42);
    int progress = (serverCount * 100) / targetQuantity;
    display.print("Cilj: " + String(targetQuantity));
    display.setCursor(80, 42);
    display.print(String(progress) + "%");
    
    int barWidth = min((serverCount * 120) / targetQuantity, 120);
    display.drawRect(4, 52, 120, 8, WHITE);
    display.fillRect(4, 52, barWidth, 8, WHITE);
  }
  
  display.setCursor(0, 56);
  if (WiFi.status() == WL_CONNECTED) {
    display.print(WiFi.localIP());
    display.setCursor(105, 56);
    display.print("DC");
  } else {
    display.print("NO WIFI");
  }
  
  display.display();
}

void showStatus(String msg) {
  display.clearDisplay();
  display.setTextColor(WHITE);
  display.setTextSize(1);
  display.setCursor(0, 28);
  display.println(msg);
  display.display();
}

// ============================================
// WEB SERVER
// ============================================
void handleWebClient(WiFiClient& client) {
  String request = "";
  unsigned long timeout = millis() + 2000;
  
  while (client.connected() && millis() < timeout) {
    if (client.available()) {
      char c = client.read();
      request += c;
      if (request.endsWith("\r\n\r\n")) break;
    }
  }
  
  String firstLine = request.substring(0, request.indexOf('\r'));
  String endpoint = "/";
  
  if (firstLine.startsWith("GET ")) {
    int endIdx = firstLine.indexOf(" HTTP");
    if (endIdx > 4) {
      endpoint = firstLine.substring(4, endIdx);
      endpoint.trim();
    }
  }
  
  if (endpoint.length() > 1 && endpoint.endsWith("/")) {
    endpoint = endpoint.substring(0, endpoint.length() - 1);
  }
  
  int currentTubes = tubes;
  
  if (endpoint == "/" || endpoint == "/index.html") {
    sendWebPage(client);
  }
  else if (endpoint == "/count") {
    int pendingVal = max(0, currentTubes - syncedCount + offlineBuffer);
    int toNextBatch = SYNC_EVERY_N_PIECES - (currentTubes - lastBatchSyncAt);
    
    String json = "{\"count\":" + String(currentTubes) + 
                  ",\"server\":" + String(serverCount) +
                  ",\"target\":" + String(targetQuantity) +
                  ",\"pending\":" + String(pendingVal) +
                  ",\"nextBatch\":" + String(toNextBatch) +
                  ",\"rn\":\"" + workOrderNumber + "\""
                  ",\"active\":" + (hasActiveRN ? "true" : "false") +
                  ",\"running\":" + (machineRunning ? "true" : "false") +
                  ",\"ntp\":" + (ntpSynced ? "true" : "false") +
                  ",\"version\":\"5.4-DC\"}";
    sendJson(client, json);
  }
  else if (endpoint == "/reset") {
    tubes = 0;
    syncedCount = 0;
    offlineBuffer = 0;
    lastBatchSyncAt = 0;
    lastSyncLogAt = 0;
    machineRunning = false;
    pendingStopEvent = false;
    pendingStartEvent = false;
    pendingSyncLog = false;
    preferences.putInt("local", 0);
    preferences.putInt("buffer", 0);
    preferences.putInt("lastBatch", 0);
    preferences.putInt("lastLog", 0);
    sendJson(client, "{\"success\":true}");
  }
  else if (endpoint == "/refresh") {
    checkActiveWorkOrder();
    sendJson(client, "{\"success\":true,\"rn\":\"" + workOrderNumber + "\"}");
  }
  else if (endpoint == "/sync") {
    syncToSupabase(false);
    sendJson(client, "{\"success\":true}");
  }
  else if (endpoint == "/debug") {
    String json = "{\"v\":\"5.4-DC\",\"tubes\":" + String(currentTubes) + 
                  ",\"synced\":" + String(syncedCount) +
                  ",\"buffer\":" + String(offlineBuffer) +
                  ",\"running\":" + (machineRunning ? "true" : "false") +
                  ",\"pendingStop\":" + (pendingStopEvent ? "true" : "false") +
                  ",\"pendingStart\":" + (pendingStartEvent ? "true" : "false") +
                  ",\"pendingSync\":" + (pendingSyncLog ? "true" : "false") +
                  ",\"ntp\":" + (ntpSynced ? "true" : "false") +
                  ",\"countingTask\":" + (countingTaskRunning ? "true" : "false") +
                  ",\"woId\":\"" + workOrderId + "\"" +
                  ",\"woNum\":\"" + workOrderNumber + "\"}";
    sendJson(client, json);
  }
  else {
    client.println("HTTP/1.1 404 Not Found\r\n\r\n404");
  }
  
  delay(5);
  client.stop();
}

void sendJson(WiFiClient& client, String json) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: application/json");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Connection: close");
  client.println();
  client.print(json);
}

void sendWebPage(WiFiClient& client) {
  int currentTubes = tubes;
  
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html; charset=utf-8");
  client.println("Connection: close");
  client.println();
  
  client.println("<!DOCTYPE html><html><head><meta charset='UTF-8'>");
  client.println("<meta name='viewport' content='width=device-width'>");
  client.println("<title>" + String(MACHINE_CODE) + "</title>");
  client.println("<style>body{font-family:system-ui;background:#1a1a2e;color:#fff;text-align:center;padding:20px;}");
  client.println(".card{background:#1565c0;border-radius:15px;padding:20px;max-width:350px;margin:20px auto;}");
  client.println(".count{font-size:4em;font-weight:bold;}</style></head><body>");
  
  client.println("<h2>" + String(MACHINE_CODE) + " v5.4-DC</h2>");
  client.println("<div class='card'>");
  client.println("<div>" + (hasActiveRN ? workOrderNumber : "Ceka RN...") + "</div>");
  client.println("<div class='count' id='c'>" + String(currentTubes) + "</div>");
  client.println("<div id='s'>" + String(machineRunning ? "RADI" : "STOJI") + "</div>");
  client.println("<div style='margin-top:10px;font-size:0.8em;opacity:0.7;'>DUAL CORE | NTP: " + String(ntpSynced ? "DA" : "NE") + "</div>");
  client.println("</div>");
  
  client.println("<script>setInterval(()=>{fetch('/count').then(r=>r.json()).then(d=>{");
  client.println("document.getElementById('c').textContent=d.count;");
  client.println("document.getElementById('s').textContent=d.running?'RADI':'STOJI';");
  client.println("});},1000);</script></body></html>");
}
