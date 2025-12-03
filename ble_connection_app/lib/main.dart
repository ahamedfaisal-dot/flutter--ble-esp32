import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // Ensure status bar is transparent for full-screen gradient effect
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LedControllerPage(),
  ));
}

class LedControllerPage extends StatefulWidget {
  const LedControllerPage({super.key});

  @override
  State<LedControllerPage> createState() => _LedControllerPageState();
}

class _LedControllerPageState extends State<LedControllerPage> with SingleTickerProviderStateMixin {
  // UUIDs must match ESP32 code
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID_RX = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  final String TARGET_DEVICE_NAME = "ESP32_LED_Controller";

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? writeCharacteristic;
  String connectionStatus = "Disconnected";
  bool isScanning = false;

  // LED States
  bool led1 = false;
  bool led2 = false;
  bool led3 = false;

  // Animation Controller for pulsing effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for scanning status
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    checkPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 1. Request Permissions (Android 12+ specific)
  Future<void> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    
    // Check if permission is granted for scanning
    if (statuses[Permission.bluetoothScan] == PermissionStatus.granted) {
      scanForDevice(); 
    }
  }

  // 2. Scan for the specific ESP32
  void scanForDevice() async {
    setState(() {
      isScanning = true;
      connectionStatus = "Scanning...";
    });

    var subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (ScanResult r in results) {
          if (r.device.platformName == TARGET_DEVICE_NAME) {
            connectToDevice(r.device);
            FlutterBluePlus.stopScan(); // Stop scanning once found
            break; 
          }
        }
      },
      onError: (e) => print(e),
    );

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    
    // Cleanup if not found
    await Future.delayed(const Duration(seconds: 10));
    if (targetDevice == null && mounted) {
      setState(() {
        isScanning = false;
        connectionStatus = "Device not found";
      });
    }
    subscription.cancel();
  }

  // 3. Connect and Discover Services
  void connectToDevice(BluetoothDevice device) async {
    setState(() => connectionStatus = "Connecting...");
    
    try {
      await device.connect();
      if (!mounted) return;
      
      setState(() {
        targetDevice = device;
        connectionStatus = "Connected";
      });

      // Discover Services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == CHARACTERISTIC_UUID_RX) {
              writeCharacteristic = characteristic;
              if (mounted) setState(() => connectionStatus = "Ready");
            }
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => connectionStatus = "Connection Failed");
    }
  }

  // 4. Send Command to ESP32
  void sendLedCommand(int ledIndex, bool state) async {
    if (writeCharacteristic == null) return;

    // Protocol: "ID,STATE" (e.g., "1,1" or "2,0")
    String command = "$ledIndex,${state ? '1' : '0'}";
    
    try {
      await writeCharacteristic!.write(utf8.encode(command));
    } catch (e) {
      print("Error sending command: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Dark Blue
              Color(0xFF16213E), // Deep Blue
              Color(0xFF0F3460), // Navy
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ESP32",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Controller",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusIndicator(),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Main Controls
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    children: [
                      _buildLedCard(
                        title: "Red Light",
                        subtitle: "GPIO 21",
                        isActive: led1,
                        color: Colors.redAccent,
                        icon: Icons.lightbulb,
                        onChanged: (val) {
                          setState(() => led1 = val);
                          sendLedCommand(1, val);
                        },
                      ),
                      _buildLedCard(
                        title: "Green Light",
                        subtitle: "GPIO 19",
                        isActive: led2,
                        color: Colors.greenAccent,
                        icon: Icons.lightbulb,
                        onChanged: (val) {
                          setState(() => led2 = val);
                          sendLedCommand(2, val);
                        },
                      ),
                      _buildLedCard(
                        title: "Blue Light",
                        subtitle: "GPIO 4",
                        isActive: led3,
                        color: Colors.blueAccent,
                        icon: Icons.lightbulb,
                        onChanged: (val) {
                          setState(() => led3 = val);
                          sendLedCommand(3, val);
                        },
                      ),
                      // Scan/Retry Card
                      _buildActionCard(
                        title: isScanning ? "Scanning..." : "Scan Device",
                        icon: isScanning ? Icons.radar : Icons.refresh,
                        onTap: isScanning ? null : scanForDevice,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    IconData statusIcon;
    
    if (connectionStatus == "Connected" || connectionStatus == "Ready") {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.bluetooth_connected;
    } else if (isScanning) {
      statusColor = Colors.amberAccent;
      statusIcon = Icons.bluetooth_searching;
    } else {
      statusColor = Colors.redAccent;
      statusIcon = Icons.bluetooth_disabled;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          isScanning 
            ? ScaleTransition(
                scale: _pulseAnimation,
                child: Icon(statusIcon, color: statusColor, size: 20),
              )
            : Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            connectionStatus,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedCard({
    required String title,
    required String subtitle,
    required bool isActive,
    required Color color,
    required IconData icon,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: targetDevice == null ? null : () => onChanged(!isActive),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isActive 
              ? color.withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive ? color : Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: isActive ? Colors.white : Colors.white54,
                          size: 24,
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: targetDevice == null ? null : onChanged,
                        activeColor: color,
                        activeTrackColor: color.withOpacity(0.3),
                        inactiveThumbColor: Colors.white54,
                        inactiveTrackColor: Colors.white10,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: Colors.white70,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
