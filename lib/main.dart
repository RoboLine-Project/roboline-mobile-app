import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. SUPABASE BAŞLATMA
// ==========================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eqzjvnoiqdevyqsxqrcs.supabase.co',
    anonKey: 'sb_publishable_lTDynzmQfhWOLiVffabB8Q_VHy4Orae',
  );

  runApp(const RoboLineApp());
}

class RoboLineApp extends StatelessWidget {
  const RoboLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoboLine Kontrol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const LoginScreen(),
    );
  }
}

// ==========================================
// 2. GÜVENLİ GİRİŞ EKRANI (LOGIN)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false; // YENİ: Yükleniyor durumu eklendi

  Future<void> _login() async {
    final kAdi = _usernameController.text.trim();
    final sfr = _passwordController.text.trim();

    if (kAdi.isEmpty || sfr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen kullanıcı adı ve şifre girin!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true); // Animasyonu başlat

    try {
      // YENİ: 10 Saniye Zaman Aşımı (Timeout) Koruması eklendi
      final response = await Supabase.instance.client
          .from('kullanicilar')
          .select()
          .eq('kullanici_adi', kAdi)
          .eq('sifre', sfr)
          .timeout(const Duration(seconds: 10));

      if (response.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(aktifKullanici: kAdi),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hatalı kullanıcı adı veya şifre!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      print("Giriş Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains("Timeout")
                ? 'Sunucuya ulaşılamadı (Zaman Aşımı)! İnternetinizi kontrol edin.'
                : 'Bağlantı hatası: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false); // Animasyonu durdur
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.precision_manufacturing,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                "RoboLine",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                "AGV Kontrol Sistemi",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isObscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _isObscure = !_isObscure),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _login, // Yükleniyorsa butonu kilitle
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SİSTEME GİRİŞ YAP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. KONTROL VE LOG PANELİ
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String aktifKullanici;

  const DashboardScreen({super.key, required this.aktifKullanici});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late MqttServerClient client;
  bool isConnected = false;
  String robotStatus = "Bağlantı Bekleniyor...";
  String batteryLevel = "%0";
  bool isMoving = false;

  bool manualStopTriggered = false;
  String lastTarget = "Bilinmiyor";

  final String broker = 'broker.hivemq.com';
  final String statusTopic = 'roboline/telemetry/status';
  final String commandTopic = 'roboline/commands/move';

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    connectMQTT();
  }

  Future<void> logVeritabaninaYaz(String hedef, String durum) async {
    try {
      await supabase.from('robot_logs').insert({
        'hedef': hedef,
        'durum': durum,
      });
    } catch (e) {
      print("❌ Veritabanı Hatası: $e");
    }
  }

  Future<void> connectMQTT() async {
    client = MqttServerClient(
      broker,
      'flutter_ui_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    client.onDisconnected = () {
      if (mounted) {
        setState(() {
          isConnected = false;
          robotStatus = "Bağlantı Koptu!";
          isMoving = false;
        });
      }
    };

    try {
      setState(() => robotStatus = "Bağlanılıyor...");
      await client.connect();
    } catch (e) {
      setState(() {
        robotStatus = "Bağlantı Hatası!";
        isConnected = false;
      });
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() {
        isConnected = true;
        robotStatus = "Bağlandı. Veri bekleniyor...";
      });
      client.subscribe(statusTopic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        try {
          final data = jsonDecode(pt);
          setState(() {
            String yeniDurum = data['durum'] ?? "Bilinmiyor";
            batteryLevel = data['batarya'] ?? "%--";

            if (yeniDurum == "Hedefe Ulasildi") {
              logVeritabaninaYaz(lastTarget, "Başarıyla Ulaştı");
              isMoving = false;
            } else if (yeniDurum == "Engel Tespit Edildi") {
              logVeritabaninaYaz(lastTarget, "Hata: Yol Tıkalı!");
              isMoving = false;
            } else if (yeniDurum == "Hata: Cizgi Kaybedildi") {
              logVeritabaninaYaz(lastTarget, "Raydan Çıktı!");
              isMoving = false;
            } else if (robotStatus == "Hareket Halinde" &&
                yeniDurum == "Beklemede/Durdu") {
              if (manualStopTriggered) manualStopTriggered = false;
            }

            robotStatus = yeniDurum;

            if (robotStatus == "Hareket Halinde")
              isMoving = true;
            else if (robotStatus == "Beklemede/Durdu" ||
                robotStatus == "Hedefe Ulasildi" ||
                robotStatus == "Engel Tespit Edildi")
              isMoving = false;
          });
        } catch (e) {
          print("JSON Hatası: $e");
        }
      });
    }
  }

  void sendCommand(String target, String commandType) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sunucu bağlantısı koptu!')));
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();

      builder.addString(
        jsonEncode({
          "hedef": target,
          "komut": commandType,
          "kullanici": widget.aktifKullanici,
        }),
      );

      client.publishMessage(commandTopic, MqttQos.atMostOnce, builder.payload!);

      setState(() {
        if (commandType == "GIT" || commandType == "BASLA") {
          isMoving = true;
          lastTarget = target;
          logVeritabaninaYaz(target, "Görev Başlatıldı");
        } else if (commandType == "DUR") {
          isMoving = false;
          manualStopTriggered = true;
          logVeritabaninaYaz(lastTarget, "Acil Durduruldu");
        } else if (commandType == "SIFIRLA") {
          isMoving = false;
          logVeritabaninaYaz("Base", "Konum Sıfırlandı");
        }
      });
    } catch (e) {
      print("Mesaj gönderme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RoboLine Panel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Operatör: ${widget.aktifKullanici}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue[800],
        elevation: 0,
        actions: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 15),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Çıkış Yap',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          // ÜST KISIM: DURUM KARTLARI
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusCard(
                  "Durum",
                  robotStatus,
                  Icons.precision_manufacturing,
                ),
                _buildStatusCard(
                  "Batarya",
                  batteryLevel,
                  Icons.battery_charging_full,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ORTA KISIM: KUMANDA BUTONLARI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: isMoving
                          ? null
                          : () => sendCommand(lastTarget, "BASLA"),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("DEVAM ET"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton.icon(
                      onPressed: () => sendCommand(lastTarget, "DUR"),
                      icon: const Icon(Icons.stop),
                      label: const Text("DURDUR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactRoomButton("Oda 1"),
                    _buildCompactRoomButton("Oda 2"),
                    _buildCompactRoomButton("Oda 3"),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactRoomButton("Oda 4"),
                    _buildCompactRoomButton("Oda 5"),
                    _buildCompactRoomButton("Oda 6"),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isMoving
                            ? null
                            : () => sendCommand("Base", "GIT"),
                        icon: const Icon(Icons.home),
                        label: const Text(
                          "BASE'E DÖN",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: () => sendCommand("Base", "SIFIRLA"),
                        icon: const Icon(Icons.restore),
                        label: const Text(
                          "SIFIRLA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 25, thickness: 2),

          // ALT KISIM: CANLI LOG EKRANI
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Canlı Görev Geçmişi",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('robot_logs')
                  .stream(primaryKey: ['id'])
                  .order('tarih_saat', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text("Hata: ${snapshot.error}"));

                final logs = snapshot.data ?? [];
                if (logs.isEmpty)
                  return const Center(child: Text("Henüz kayıt yok."));

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 0),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final durum = log['durum'].toString();
                    final hedef = log['hedef'].toString();

                    DateTime dt = DateTime.parse(log['tarih_saat']).toLocal();
                    String saat =
                        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

                    Color durumRengi = Colors.grey;
                    IconData durumIkona = Icons.info;

                    if (durum.contains("Başarılı") ||
                        durum.contains("Ulasildi") ||
                        durum.contains("Bitti")) {
                      durumRengi = Colors.green;
                      durumIkona = Icons.check_circle;
                    } else if (durum.contains("Hata") ||
                        durum.contains("Engel") ||
                        durum.contains("Acil")) {
                      durumRengi = Colors.red;
                      durumIkona = Icons.warning_amber_rounded;
                    } else if (durum.contains("Başlatıldı") ||
                        durum.contains("Sıfırlandı")) {
                      durumRengi = Colors.blue;
                      durumIkona = Icons.play_circle_fill;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(durumIkona, color: durumRengi, size: 28),
                        title: Text(
                          "Hedef: $hedef",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          durum,
                          style: TextStyle(color: durumRengi, fontSize: 12),
                        ),
                        trailing: Text(
                          saat,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRoomButton(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: isMoving
              ? null
              : () => sendCommand(label.replaceAll(" ", ""), "GIT"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue[900],
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
