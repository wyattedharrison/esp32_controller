import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const ESP32ControllerApp());
}

class ESP32ControllerApp extends StatelessWidget {
  const ESP32ControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const ControllerPage(),
    );
  }
}

class ControllerPage extends StatefulWidget {
  const ControllerPage({super.key});

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  // List of Bluetooth devices discovered during scanning.
  List<ScanResult> scanResults = [];

  // The brightness characteristic on the ESP32.
  BluetoothCharacteristic? brightnessCharacteristic;

  // Keep track of whether we are connected.
  bool deviceConnected = false;

  // UUID for our custom BLE service.
  static const String serviceUuid =
      '7b7b0001-4e4e-4f4f-8a8a-123456789001';

  // UUID for the brightness characteristic.
  static const String brightnessUuid =
      '7b7b0001-4e4e-4f4f-8a8a-123456789002';

  // ------------------------------------------------------------
  // Scan for nearby Bluetooth devices
  // ------------------------------------------------------------

  Future<void> scanForDevices() async {
    setState(() {
      scanResults = [];
    });

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );
  }

  // ------------------------------------------------------------
  // Connect to the ESP32 and find its brightness characteristic
  // ------------------------------------------------------------

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print('Connecting to ${device.platformName}...');

      await device.connect(
        license: License.free,
      );

      print('Connected!');

      // Ask the ESP32 what BLE services it provides.
      final services = await device.discoverServices();

      print('Services discovered:');

      for (final service in services) {
        print('Service: ${service.uuid}');

        for (final characteristic in service.characteristics) {
          print('  Characteristic: ${characteristic.uuid}');

          // Look for our brightness characteristic.
          if (characteristic.uuid.toString().toLowerCase() ==
              brightnessUuid.toLowerCase()) {
            brightnessCharacteristic = characteristic;

            print('Brightness characteristic found!');
          }
        }
      }

      // Make sure we actually found the characteristic.
      if (brightnessCharacteristic == null) {
        print('ERROR: Brightness characteristic not found.');
        return;
      }

      setState(() {
        deviceConnected = true;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to ESP32!'),
        ),
      );
    } catch (e) {
      print('Connection error: $e');
    }
  }

  // ------------------------------------------------------------
  // Send a brightness value to the ESP32
  // ------------------------------------------------------------

  Future<void> setBrightness(int value) async {
    if (brightnessCharacteristic == null) {
      print('ERROR: Not connected to the brightness characteristic.');
      return;
    }

    try {
      // Convert the integer into a single byte.
      final data = [value];

      // Send the byte to the ESP32.
      await brightnessCharacteristic!.write(data);

      print('Sent brightness: $value');
    } catch (e) {
      print('Error sending brightness: $e');
    }
  }

  // ------------------------------------------------------------
  // User interface
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 Controller'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // --------------------------------------------------
            // Scan button
            // --------------------------------------------------

            ElevatedButton(
              onPressed: scanForDevices,
              child: const Text(
                'Scan for Bluetooth Devices',
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // Device list
            // --------------------------------------------------

            Expanded(
              child: ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  final result = scanResults[index];
                  final device = result.device;

                  return ListTile(
                    title: Text(
                      device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device',
                    ),

                    subtitle: Text(
                      device.remoteId.toString(),
                    ),

                    onTap: () {
                      connectToDevice(device);
                    },
                  );
                },
              ),
            ),

            // --------------------------------------------------
            // LED controls
            // --------------------------------------------------

            if (deviceConnected) ...[
              const Divider(),

              const SizedBox(height: 10),

              const Text(
                'LED Brightness',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  // OFF button
                  ElevatedButton(
                    onPressed: () {
                      setBrightness(0);
                    },
                    child: const Text('OFF'),
                  ),

                  // 50% button
                  ElevatedButton(
                    onPressed: () {
                      setBrightness(128);
                    },
                    child: const Text('50%'),
                  ),

                  // ON button
                  ElevatedButton(
                    onPressed: () {
                      setBrightness(255);
                    },
                    child: const Text('ON'),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}