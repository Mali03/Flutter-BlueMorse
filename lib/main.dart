import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

Future<bool> requestBluetoothPermissions() async {
  var scan = await Permission.bluetoothScan.request();
  var connect = await Permission.bluetoothConnect.request();
  var location = await Permission.location.request();

  return scan.isGranted && connect.isGranted && location.isGranted;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlueMorse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  final Set<String> _seenDeviceIds = {};

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  Future<void> startScanning() async {
    setState(() {
      _devices.clear();
      _seenDeviceIds.clear();
      _isScanning = true;
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning && mounted) {
          setState(() {
            _isScanning = false;
          });
          print("Scanning stopped.");
        }
      });
    } catch (e) {
      print("Error while scanning: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> initBluetooth() async {
    bool granted = await requestBluetoothPermissions();

    if (!granted) {
      print("Permissions couldn't granted!");
      return;
    }

    print("Permissions granted. Listening to scan results...");

    FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult r = results.last;
        String deviceId = r.device.remoteId.toString();

        if (r.device.advName.isEmpty || r.device.advName.trim().isEmpty) return;

        if (!_seenDeviceIds.contains(deviceId)) {
          _seenDeviceIds.add(deviceId);
          if (mounted) {
            setState(() {
              _devices.add(r.device);
            });
          }
        }
      }
    }, onError: (e) => print(e));

    startScanning();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.advName} connecting...'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blueGrey,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await device.connect(license: License.free, autoConnect: false);
      print('${device.advName} connected successfully!');

      if (Platform.isAndroid) {
        try {
          print("Android: Pair request has sent...");
          await device.createBond();
        } catch (e) {
          print("Paired allready or failed: $e");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.advName}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      List<BluetoothService> services = await device.discoverServices();
      if (services.isNotEmpty) {
        print("Services discovered. Length: ${services.length}");
      }

      device.connectionState.listen((BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("Device connection has lost.");
        }
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => DeviceScreen(device: device)),
        );
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      device.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("BlueMorse"),
        backgroundColor: Colors.tealAccent,
        foregroundColor: Colors.black,
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              startScanning();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("List refreshing..."),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          _devices.isEmpty
              ? Center(
                child: Text(
                  _isScanning
                      ? "Scanning bluetooth devices..."
                      : "No devices found. Press refresh.",
                ),
              )
              : ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final name = device.advName;

                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(device.remoteId.toString()),
                        leading: const Icon(
                          Icons.bluetooth,
                          color: Colors.blue,
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            _connectToDevice(device);
                          },
                          child: const Text("Connect"),
                        ),
                        onTap: () {
                          _connectToDevice(device);
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  );
                },
              ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<String> messages = [];

  BluetoothCharacteristic? targetCharacteristic;
  String connectionStatus = "Connected";
  
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _valueSubscription;

  @override
  void initState() {
    super.initState();
    discoverServices();

    _connectionStateSubscription = widget.device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (mounted) {
          setState(() => connectionStatus = "Connection lost!");
        }
      }
    });
  }

  Future<void> discoverServices() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            targetCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);

           _valueSubscription =  characteristic.lastValueStream.listen((value) {
              if (value.isEmpty) {
                return;
              }

              String msg = utf8.decode(value); // Byte to String
              setState(() {
                messages.add("${widget.device.advName}: $msg");
              });
            });
          }
        }
      }
    } catch (e) {
      print("Service error: $e");
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _valueSubscription?.cancel();

    if (targetCharacteristic != null && targetCharacteristic!.properties.notify) {
      targetCharacteristic!.setNotifyValue(false); 
    }

    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.advName),
        backgroundColor: Colors.tealAccent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(
            connectionStatus,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Text(
                      messages[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
