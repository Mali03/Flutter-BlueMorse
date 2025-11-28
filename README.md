# 💠 Flutter Bluetooth Morse Code Transmitter

![Flutter](https://img.shields.io/badge/Flutter-3.29.3-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.7.2-blue?logo=dart)
![IoT](https://img.shields.io/badge/IoT-green?logo=iot)

EN - A Flutter + ESP32 project that lets you send Morse-coded messages wirelessly using BLE. The ESP32 detects Morse button presses, converts them into letters/words, and sends the decoded text to the Flutter app using Bluetooth Low Energy (BLE) notifications.

TR - BLE üzerinden kablosuz olarak Mors kodu mesajları göndermenizi sağlayan bir Flutter + ESP32 projesi. ESP32, Mors kodu için yapılan buton basışlarını algılar, bunları harf ve kelimelere dönüştürür ve çözümlenen metni Bluetooth Low Energy (BLE) bildirimleri aracılığıyla Flutter uygulamasına gönderir.

<video width="300" controls>
  <source src="Example.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

<p float="left">
  <img src="https://i.imgur.com/DjS6WuR.jpeg" width="250" />
  <img src="https://i.imgur.com/exXS2Ay.jpeg" width="250" />
  <img src="https://i.imgur.com/8LDF93w.jpeg" width="250" />
</p>

# 🌍 Languages
You can select your preferred languages below:

- [English](#English)
- [Türkçe](#Türkçe)

# English
## 🔍 Features
- Real-time BLE scanning (Flutter Blue Plus)
- Secure BLE pairing (bonding) on ESP32
- Morse input via physical buttons
- Automatic dot/dash detection
- Automatic letter & word parsing
- Message sending through BLE Notify
- Live message stream on Flutter app
- Clean UI with device list, connection screen & live console output

## 🛠 Hardware Requirements
- ESP32
- 2x momentary buttons
  - Morse button → GPIO 35
  - Send button → GPIO 12
- USB cable
- (Optional) Resistors for stable input
- Flutter-supported device (Android recommended)

## 🧠 Morse Logic
The ESP32 measures the press duration:
- `< 300 ms` → `.` dot
- `>= 300 ms` → `-` dash

Letter / word detection:
- Letter gap: **1 second**
- Word gap: **5 seconds**

Sends the entire message when the **Send button** is pressed.

## 🔧 Installation
**ESP32 Side**

1. Wire cables like `Cable Notations.jpg`
2. Open Arduino IDE
3. Install ESP32 board support
4. Install libraries:
- `BLEDevice`
- `BLEUtils`
- `BLEServer`

5. Upload the provided `Esp32_mors.ino` file
6. Open Serial Monitor to view Morse decoding

**Flutter Side**
1. Clone the repo

2. Run:
```
flutter pub get
flutter run
```

_NOTE: Make sure Bluetooth + Location permissions are enabled_

## 📚 License
This project is licensed under the **MIT License** - see the [LICENSE](https://github.com/Mali03/FlutterNoteApp/blob/main/LICENSE) file for details.

## ❓ Need Help
If you need any help contact me on [LinkedIn](https://www.linkedin.com/in/mali03/).

# Türkçe
