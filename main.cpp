#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- CONFIGURATION ---
// UUIDs (Must match Flutter code)
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID_RX "beb5483e-36e1-4688-b7f5-ea07361b26a8" // Rx: Write (Flutter -> ESP32)

// Pin Definitions
const int LED_PIN_1 = 21;
const int LED_PIN_2 = 19;
const int LED_PIN_3 = 4;

BLECharacteristic *pRxCharacteristic;
bool deviceConnected = false;

// Server Callbacks: Handle Connection State
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device Disconnected");
      // Restart advertising so we can reconnect
      BLEDevice::startAdvertising();
    }
};

// Characteristic Callbacks: Handle Incoming Data
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        Serial.print("Received: ");
        Serial.println(rxValue);

        // Protocol Parsing: "ID,STATE" (e.g., "1,1" or "2,0")
        // We expect a string like "1,1"
        if (rxValue.indexOf(",") != -1) {
           char ledId = rxValue[0];
           char state = rxValue[2]; // Index 2 because Index 1 is the comma

           int pinToControl = -1;
           
           if (ledId == '1') pinToControl = LED_PIN_1;
           else if (ledId == '2') pinToControl = LED_PIN_2;
           else if (ledId == '3') pinToControl = LED_PIN_3;

           if (pinToControl != -1) {
             if (state == '1') {
               digitalWrite(pinToControl, HIGH);
               Serial.printf("LED %c turned ON\n", ledId);
             } else {
               digitalWrite(pinToControl, LOW);
               Serial.printf("LED %c turned OFF\n", ledId);
             }
           }
        }
      }
    }
};

void setup() {
  Serial.begin(115200);

  // Initialize LED Pins
  pinMode(LED_PIN_1, OUTPUT);
  pinMode(LED_PIN_2, OUTPUT);
  pinMode(LED_PIN_3, OUTPUT);
  
  // Start with LEDs OFF
  digitalWrite(LED_PIN_1, LOW);
  digitalWrite(LED_PIN_2, LOW);
  digitalWrite(LED_PIN_3, LOW);

  // Initialize BLE
  BLEDevice::init("ESP32_LED_Controller");

  // Create Server
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create RX Characteristic (Flutter writes to this)
  pRxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_RX,
                        BLECharacteristic::PROPERTY_WRITE
                      );
  
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start Service
  pService->start();

  // Start Advertising
  pServer->getAdvertising()->start();
  Serial.println("Waiting for connections...");
}

void loop() {
  // Logic is handled in callbacks
  delay(100);
}