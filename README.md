# ESP32 BLE LED Controller Project

This project allows you to control 3 LEDs connected to an ESP32 microcontroller using a Flutter mobile app via Bluetooth Low Energy (BLE).

## Project Structure

*   **`main.cpp`**: The firmware code for the ESP32.
*   **`ble_connection_app/`**: The Flutter mobile application source code.

## Prerequisites

### Hardware
*   ESP32 Development Board
*   3x LEDs (Red, Green, Blue recommended)
*   3x Resistors (220Ω or 330Ω)
*   Breadboard and Jumper Wires
*   Android Smartphone (for the app)

### Software
*   **Arduino IDE** (for flashing ESP32)
*   **Flutter SDK** (for running the app)
*   **VS Code** or **Android Studio** (optional, for editing code)

## 1. Hardware Setup (ESP32)

Connect the LEDs to the ESP32 GPIO pins as defined in `main.cpp`:

*   **LED 1 (Red)**: GPIO **21**
*   **LED 2 (Green)**: GPIO **19**
*   **LED 3 (Blue)**: GPIO **4**

**Wiring:**
*   Connect the **Long leg (Anode)** of each LED to the respective GPIO pin.
*   Connect the **Short leg (Cathode)** of each LED to a resistor, and then to **GND** on the ESP32.

## 2. Flashing the ESP32 Firmware

1.  Open **Arduino IDE**.
2.  Install the **ESP32 Board Manager** if you haven't already (File > Preferences > Additional Boards Manager URLs: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`).
3.  Select your board: **Tools > Board > ESP32 Dev Module** (or your specific board).
4.  Select the correct **Port**.
5.  Open the `main.cpp` file content (or copy-paste it into a new sketch).
6.  Click **Upload** (Arrow icon) to flash the code to the ESP32.
7.  Open the **Serial Monitor** (Baud Rate: **115200**) to verify it says "Waiting for connections...".

## 3. Running the Mobile App

1.  Navigate to the app directory:
    ```bash
    cd ble_connection_app
    ```
2.  Ensure your Android phone is connected and USB Debugging is enabled.
3.  Run the app:
    ```bash
    flutter run
    ```
    *Note: If you encounter build errors, ensure your Android SDK and Gradle versions are compatible (this project is configured for AGP 8.5.0 and Java 21).*

## 4. How to Use

1.  **Power on** your ESP32.
2.  **Open the App** on your phone.
3.  Grant **Location** and **Bluetooth** permissions when prompted.
4.  The app will automatically scan for a device named **"ESP32_LED_Controller"**.
5.  Once connected (Status: **Connected**), tap the cards or switches to toggle the LEDs.

## Troubleshooting

*   **App won't connect:** Ensure GPS/Location is ON on your phone (required for BLE scanning on Android).
*   **Upload Failed:** Hold the "BOOT" button on the ESP32 when you see "Connecting..." in the Arduino IDE.
