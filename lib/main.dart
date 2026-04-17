import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const RoboLineApp());
}

class RoboLineApp extends StatelessWidget {
  const RoboLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MqttTestScreen(),
    );
  }
}

class MqttTestScreen extends StatefulWidget {
  const MqttTestScreen({super.key});

  @override
  State<MqttTestScreen> createState() => _MqttTestScreenState();
}

class _MqttTestScreenState extends State<MqttTestScreen> {
  String statusText = "Bağlantı Bekleniyor...";
  late MqttServerClient client;

  Future<void> connectMQTT() async {
    // HiveMQ Public Broker ayarları
    client = MqttServerClient(
      'broker.hivemq.com',
      'flutter_ui_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    try {
      setState(() => statusText = "Sunucuya Bağlanılıyor...");
      await client.connect();
    } catch (e) {
      setState(() => statusText = "Bağlantı Hatası: $e");
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() => statusText = "Bağlandı! ESP32 Bekleniyor...");

      // ESP32'nin mesaj atacağı kanalı (topic) dinlemeye başlıyoruz
      const topic = 'roboline/telemetry/status';
      client.subscribe(topic, MqttQos.atMostOnce);

      // Kanala yeni bir mesaj düştüğünde tetiklenen dinleyici
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        setState(() {
          statusText = "ESP32'den Gelen Mesaj:\n$pt";
        });

        // Gelen veriyi geliştirici konsoluna da yazdırıyoruz
        print('MQTT Mesajı Alındı: $pt');
      });
    } else {
      setState(() => statusText = "Bağlantı Reddedildi.");
      client.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoboLine MQTT Testi'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: connectMQTT,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'HiveMQ Sunucusuna Bağlan',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
