#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <BLE2902.h>

#define morseButton 35
#define sendButton 12

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" // unique number for two devices
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // unique data container

int morseButtonState = 0;
int sendButtonState = 0;
int lastSendButtonState = 0;
int lastMorseButtonState = 0;
unsigned long pressStartTime = 0;
unsigned long lastReleaseTime = 0;

bool letterWrote = false;
bool wordWrote = false;

String currentLetter = "";
String currentWord = "";
String message = "";

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    BLEDevice::startAdvertising();
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
  }
};

class MySecurity : public BLESecurityCallbacks {
  uint32_t onPassKeyRequest() {
    return 123456;
  }
  void onPassKeyNotify(uint32_t pass_key) {}
  bool onConfirmPIN(uint32_t pass_key) {
    return true;
  }
  bool onSecurityRequest() {
    return true;
  }
  void onAuthenticationComplete(esp_ble_auth_cmpl_t cmpl) {}
};

char decodeMorse(String morse) {
  if (morse == ".-") return 'A';
  if (morse == "-...") return 'B';
  if (morse == "-.-.") return 'C';
  if (morse == "-..") return 'D';
  if (morse == ".") return 'E';
  if (morse == "..-.") return 'F';
  if (morse == "--.") return 'G';
  if (morse == "....") return 'H';
  if (morse == "..") return 'I';
  if (morse == ".---") return 'J';
  if (morse == "-.-") return 'K';
  if (morse == ".-..") return 'L';
  if (morse == "--") return 'M';
  if (morse == "-.") return 'N';
  if (morse == "---") return 'O';
  if (morse == ".--.") return 'P';
  if (morse == "--.-") return 'Q';
  if (morse == ".-.") return 'R';
  if (morse == "...") return 'S';
  if (morse == "-") return 'T';
  if (morse == "..-") return 'U';
  if (morse == "...-") return 'V';
  if (morse == ".--") return 'W';
  if (morse == "-..-") return 'X';
  if (morse == "-.--") return 'Y';
  if (morse == "--..") return 'Z';

  if (morse == ".-.-.-") return '.';
  if (morse == "--..--") return ',';
  if (morse == "..--..") return '?';
  if (morse == "-....-") return '-';
  if (morse == "-..-.") return '/';
  return '?';
}

void setup() {
  Serial.begin(115200);
  pinMode(morseButton, INPUT);
  pinMode(sendButton, INPUT);

  // Start BLE
  BLEDevice::init("ESP32_BlueMorse");
  BLEDevice::setSecurityCallbacks(new MySecurity());

  // Create Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Create Characteristic (to transmit data we used notify)
  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY);

  // Add Descriptor
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Start the Service
  pService->start();

  // Start Advertising to be descovered by other devices
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);

  BLEDevice::startAdvertising();

  // Security Settings
  BLESecurity* pSecurity = new BLESecurity();
  pSecurity->setAuthenticationMode(ESP_LE_AUTH_REQ_SC_BOND);
  pSecurity->setCapability(ESP_IO_CAP_NONE);
  pSecurity->setInitEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);
  pSecurity->setRespEncryptionKey(ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK);

  Serial.println("Bluetooth started, ready to pair...");
}

void loop() {
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Connection has lost, starting advertising again...");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Device connected!");
  }

  morseButtonState = digitalRead(morseButton);
  sendButtonState = digitalRead(sendButton);
  unsigned long currentTime = millis();

  if (morseButtonState == HIGH && lastMorseButtonState == LOW) { // pressed
    pressStartTime = currentTime;
  }

  if (morseButtonState == LOW && lastMorseButtonState == HIGH) { // unpressed
    unsigned long pressDuration = currentTime - pressStartTime;

    if (pressDuration < 300) {
      Serial.println("short");
      currentLetter += ".";
    } else {
      Serial.println("long");
      currentLetter += "-";
    }

    lastReleaseTime = currentTime;

    delay(50);
  }

  if (morseButtonState == LOW && lastReleaseTime != 0) {
    unsigned long elapsed = currentTime - lastReleaseTime;

    if (elapsed >= 1000 && elapsed < 5000 && !letterWrote) {
      char letter = decodeMorse(currentLetter);
      currentWord += letter;
      Serial.print("Letter: ");
      Serial.println(letter);
      currentLetter = "";
      letterWrote = true;
    } else if (elapsed >= 5000 && !wordWrote) {
      message += currentWord;
      message += " ";
      Serial.print("Word: ");
      Serial.println(currentWord);
      currentWord = "";
      wordWrote = true;
    }
  }

  if (morseButtonState == HIGH && lastMorseButtonState == LOW) {
    letterWrote = false;
    wordWrote = false;
  }

  // Send Message
  if (sendButtonState == HIGH && lastSendButtonState == LOW) {
    if (message == "") {
      Serial.println("Empty messages can't be send!");
    } else {
      Serial.print("Message that will send: ");
      Serial.println(message);

      if (deviceConnected) {
        pTxCharacteristic->setValue((uint8_t*)message.c_str(), message.length());
        pTxCharacteristic->notify();
        Serial.println("Message sent to other device");
      } else {
        Serial.println("Device isn't connected");
      }

      message = "";
    }
  }

  lastMorseButtonState = morseButtonState;
  lastSendButtonState = sendButtonState;
}