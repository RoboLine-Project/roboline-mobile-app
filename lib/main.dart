import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
// ORTAK ÇIKIŞ YAP FONKSİYONU
// ==========================================
Future<void> cikisYap(BuildContext context, {String? kAdi}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // Eski kalıntıları temizler

  // Eğer çıkış yapan kişi sıradaysa veya robotu kullanıyorsa, yetkisini elinden al
  if (kAdi != null) {
    try {
      await Supabase.instance.client
          .from('kullanicilar')
          .update({'kuyruk_zamani': null, 'robotu_kullaniyor': false})
          .eq('kullanici_adi', kAdi);
    } catch (e) {}
  }

  if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}

// ==========================================
// 2. GÜVENLİ GİRİŞ VE KAYIT EKRANI (LOGIN)
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
  bool _isLoading = false;

  Future<void> _login() async {
    final kAdi = _usernameController.text.trim();
    final sfr = _passwordController.text.trim();

    if (kAdi.isEmpty || sfr.isEmpty) {
      _showSnackBar('Lütfen kullanıcı adı ve şifre girin!', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('kullanicilar')
          .select()
          .eq('kullanici_adi', kAdi)
          .eq('sifre', sfr)
          .maybeSingle();

      if (response != null) {
        String rol = response['rol'] ?? 'kullanici';
        String durum = response['durum'] ?? 'bekliyor';

        if (rol == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminScreen(aktifAdmin: kAdi),
            ),
          );
        } else if (durum == 'onaylandi') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QueueScreen(kullaniciAdi: kAdi),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PendingApprovalScreen(kullaniciAdi: kAdi, ilkDurum: durum),
            ),
          );
        }
      } else {
        _showSnackBar('Hatalı kullanıcı adı veya şifre!', Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar('Bağlantı hatası: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _kayitOl() async {
    final kAdi = _usernameController.text.trim();
    final sfr = _passwordController.text.trim();

    if (kAdi.isEmpty || sfr.isEmpty) {
      _showSnackBar(
        'Kayıt için kullanıcı adı ve şifre belirleyin!',
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final checkUser = await Supabase.instance.client
          .from('kullanicilar')
          .select()
          .eq('kullanici_adi', kAdi)
          .maybeSingle();

      if (checkUser != null) {
        _showSnackBar('Bu kullanıcı adı zaten alınmış!', Colors.redAccent);
      } else {
        await Supabase.instance.client.from('kullanicilar').insert({
          'kullanici_adi': kAdi,
          'sifre': sfr,
          'rol': 'kullanici',
          'durum': 'bekliyor',
        });
        if (context.mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PendingApprovalScreen(
                kullaniciAdi: kAdi,
                ilkDurum: 'bekliyor',
              ),
            ),
          );
      }
    } catch (e) {
      _showSnackBar('Kayıt hatası: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[900]!.withOpacity(0.8),
                    Colors.blue[800]!.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
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
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'GİRİŞ YAP',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _kayitOl,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[800],
                              side: BorderSide(
                                color: Colors.blue[800]!,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'KAYIT TALEP ET',
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
        ],
      ),
    );
  }
}

// ==========================================
// YENİ EKRAN: KUYRUK VE BEKLEME ODASI
// ==========================================
class QueueScreen extends StatefulWidget {
  final String kullaniciAdi;
  const QueueScreen({super.key, required this.kullaniciAdi});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  StreamSubscription? _subscription;
  Timer? _timer;
  int _kalanSaniye = 45;
  bool _siraBende = false;
  int _siram = 0;
  bool _isAnyoneUsing = false;
  String _aktifOperator = "";

  @override
  void initState() {
    super.initState();
    _kuyrugaGir();
  }

  Future<void> _kuyrugaGir() async {
    final supabase = Supabase.instance.client;

    await supabase
        .from('kullanicilar')
        .update({
          'kuyruk_zamani': DateTime.now().toUtc().toIso8601String(),
          'robotu_kullaniyor': false,
        })
        .eq('kullanici_adi', widget.kullaniciAdi);

    _subscription = supabase
        .from('kullanicilar')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> users) {
          bool isUsing = false;
          String kullananKisi = "";

          for (var u in users) {
            if (u['robotu_kullaniyor'] == true) {
              isUsing = true;
              kullananKisi = u['kullanici_adi'] ?? "";
              break;
            }
          }

          var queuedUsers = users
              .where((u) => u['kuyruk_zamani'] != null)
              .toList();
          queuedUsers.sort(
            (a, b) => DateTime.parse(
              a['kuyruk_zamani'],
            ).compareTo(DateTime.parse(b['kuyruk_zamani'])),
          );

          int myIndex = queuedUsers.indexWhere(
            (u) => u['kullanici_adi'] == widget.kullaniciAdi,
          );
          if (myIndex == -1) return;

          setState(() {
            _siram = myIndex + 1;
            _isAnyoneUsing = isUsing;
            _aktifOperator = kullananKisi;
          });

          if (!isUsing && myIndex == 0) {
            if (!_siraBende) {
              setState(() {
                _siraBende = true;
                _kalanSaniye = 45;
              });
              _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (_kalanSaniye > 0) {
                  setState(() => _kalanSaniye--);
                } else {
                  timer.cancel();
                  _sureBitti();
                }
              });
            }
          } else {
            if (_siraBende) {
              _timer?.cancel();
              setState(() => _siraBende = false);
            }
          }
        });
  }

  Future<void> _sureBitti() async {
    await Supabase.instance.client
        .from('kullanicilar')
        .update({'kuyruk_zamani': null})
        .eq('kullanici_adi', widget.kullaniciAdi);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Süreniz dolduğu için sıradan çıkarıldınız!'),
          backgroundColor: Colors.red,
        ),
      );
      cikisYap(context);
    }
  }

  Future<void> _robotuKullan() async {
    _timer?.cancel();

    await Supabase.instance.client
        .from('kullanicilar')
        .update({'robotu_kullaniyor': true, 'kuyruk_zamani': null})
        .eq('kullanici_adi', widget.kullaniciAdi);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DashboardScreen(aktifKullanici: widget.kullaniciAdi),
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Kuyruk / Bekleme Odası"),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: "Sıradan Çık",
            onPressed: () => cikisYap(context, kAdi: widget.kullaniciAdi),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_alt, size: 100, color: Colors.blue[800]),
              const SizedBox(height: 20),
              Text(
                "Sıranız: $_siram",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 30),
              if (_siraBende) ...[
                const Text(
                  "SIRA SİZDE!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Robotu devralmak için son $_kalanSaniye saniye!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _robotuKullan,
                    icon: const Icon(Icons.precision_manufacturing),
                    label: const Text(
                      "ROBOTU KULLAN",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                    children: _isAnyoneUsing
                        ? [
                            const TextSpan(text: "Şu an robot "),
                            TextSpan(
                              text: "[$_aktifOperator]",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 18,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  " tarafından kullanılıyor. Lütfen işleminin bitmesini bekleyin...",
                            ),
                          ]
                        : [
                            const TextSpan(
                              text: "Sıranızın gelmesi bekleniyor...",
                            ),
                          ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// AKILLI BEKLEME ODASI (Reddedilme Kontrollü)
// ==========================================
class PendingApprovalScreen extends StatefulWidget {
  final String kullaniciAdi;
  final String ilkDurum;
  const PendingApprovalScreen({
    super.key,
    required this.kullaniciAdi,
    required this.ilkDurum,
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isLoading = false;
  late String _guncelDurum;

  @override
  void initState() {
    super.initState();
    _guncelDurum = widget.ilkDurum;
  }

  Future<void> _durumuKontrolEt() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('kullanicilar')
          .select('durum')
          .eq('kullanici_adi', widget.kullaniciAdi)
          .maybeSingle();
      if (response != null) {
        if (response['durum'] == 'onaylandi') {
          if (context.mounted)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    QueueScreen(kullaniciAdi: widget.kullaniciAdi),
              ),
            );
        } else if (response['durum'] == 'reddedildi') {
          setState(() => _guncelDurum = 'reddedildi');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hesabınız hala onay bekliyor...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _tekrarIstekGonder() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('kullanicilar')
          .update({'durum': 'bekliyor'})
          .eq('kullanici_adi', widget.kullaniciAdi);
      setState(() => _guncelDurum = 'bekliyor');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yöneticiye tekrar istek gönderildi!'),
            backgroundColor: Colors.green,
          ),
        );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isRejected = _guncelDurum == 'reddedildi';
    return Scaffold(
      backgroundColor: isRejected ? Colors.red[50] : Colors.blue[50],
      appBar: AppBar(
        title: Text(isRejected ? "Erişim Reddedildi" : "Onay Bekleniyor"),
        backgroundColor: isRejected ? Colors.red[800] : Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => cikisYap(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isRejected
                    ? Icons.cancel_outlined
                    : Icons.hourglass_empty_rounded,
                size: 100,
                color: isRejected ? Colors.red[700] : Colors.orange[400],
              ),
              const SizedBox(height: 30),
              Text(
                "Merhaba ${widget.kullaniciAdi},",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isRejected
                    ? "Kayıt talebiniz reddedildi."
                    : "Kayıt talebiniz yöneticiye iletildi.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : (isRejected ? _tekrarIstekGonder : _durumuKontrolEt),
                  icon: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Icon(isRejected ? Icons.send : Icons.refresh),
                  label: Text(
                    isRejected ? "TEKRAR İSTEK GÖNDER" : "Durumumu Yenile",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRejected
                        ? Colors.red[700]
                        : Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => cikisYap(context),
                child: const Text(
                  "Farklı Hesapla Giriş Yap",
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
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
// 3. YÖNETİCİ (ADMIN) KONTROL PANELİ
// ==========================================
class AdminScreen extends StatefulWidget {
  final String aktifAdmin;
  const AdminScreen({super.key, required this.aktifAdmin});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final supabase = Supabase.instance.client;

  Future<void> _kullaniciOnayla(int id, String isim) async {
    await supabase
        .from('kullanicilar')
        .update({'durum': 'onaylandi'})
        .eq('id', id);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$isim onaylandı!'),
          backgroundColor: Colors.green,
        ),
      );
    setState(() {});
  }

  Future<void> _kullaniciReddet(int id, String isim) async {
    await supabase
        .from('kullanicilar')
        .update({
          'durum': 'reddedildi',
          'kuyruk_zamani': null,
          'robotu_kullaniyor': false,
        })
        .eq('id', id);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$isim isteği reddedildi!'),
          backgroundColor: Colors.redAccent,
        ),
      );
    setState(() {});
  }

  Future<void> _kuyruktanCikar(int id, String isim) async {
    await supabase
        .from('kullanicilar')
        .update({'kuyruk_zamani': null, 'robotu_kullaniyor': false})
        .eq('id', id);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$isim yetkisi alındı, robot boşta!'),
          backgroundColor: Colors.orange,
        ),
      );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yönetici Paneli',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Admin: ${widget.aktifAdmin}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Çıkış Yap',
            onPressed: () => cikisYap(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('kullanicilar')
            .stream(primaryKey: ['id'])
            .neq('rol', 'admin'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final users = snapshot.data ?? [];
          final bekleyenler = users
              .where((u) => u['durum'] == 'bekliyor')
              .toList();
          final onaylananlar = users
              .where((u) => u['durum'] == 'onaylandi')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              _buildSectionTitle("Onay Bekleyen İstekler", Colors.orange),
              if (bekleyenler.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    "Yeni istek bulunmuyor.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ...bekleyenler.map(
                (u) => _buildUserCard(u, isOnayBekliyor: true),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle("Aktif (Onaylı) Kullanıcılar", Colors.green),
              if (onaylananlar.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    "Sistemde onaylı kullanıcı yok.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ...onaylananlar.map(
                (u) => _buildUserCard(u, isOnayBekliyor: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.label_important, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user, {
    required bool isOnayBekliyor,
  }) {
    bool isUsing = user['robotu_kullaniyor'] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUsing
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOnayBekliyor
              ? Colors.orange[100]
              : Colors.green[100],
          child: Icon(
            Icons.person,
            color: isOnayBekliyor ? Colors.orange[800] : Colors.green[800],
          ),
        ),
        title: Text(
          user['kullanici_adi'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isUsing
              ? "Şu an Robotu Kullanıyor!"
              : (isOnayBekliyor ? "Erişim İzni İstiyor" : "Erişim İzni Var"),
          style: TextStyle(
            color: isUsing ? Colors.green : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnayBekliyor)
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),
                tooltip: "Onayla",
                onPressed: () =>
                    _kullaniciOnayla(user['id'], user['kullanici_adi']),
              ),
            if (!isOnayBekliyor)
              IconButton(
                icon: const Icon(
                  Icons.sync_disabled,
                  color: Colors.orange,
                  size: 28,
                ),
                tooltip: "Robot Yetkisini Sıfırla",
                onPressed: () =>
                    _kuyruktanCikar(user['id'], user['kullanici_adi']),
              ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
              tooltip: "Reddet / Sil",
              onPressed: () =>
                  _kullaniciReddet(user['id'], user['kullanici_adi']),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. KONTROL VE LOG PANELİ (DASHBOARD)
// ==========================================
class DashboardScreen extends StatefulWidget {
  final String aktifKullanici;
  const DashboardScreen({super.key, required this.aktifKullanici});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late MqttServerClient client;
  bool isConnected = false;
  String robotStatus = "Bağlantı Bekleniyor...";
  String batteryLevel = "%0";
  bool isMoving = false;
  bool isMissionActive = false;

  bool manualStopTriggered = false;
  String lastTarget = "Bilinmiyor";

  final String broker = 'test.mosquitto.org';
  final String statusTopic = 'roboline/telemetry/status';
  final String commandTopic = 'roboline/commands/move';

  final supabase = Supabase.instance.client;

  // YENİ: Stream'i zorla yenilemek için benzersiz anahtar
  Key _streamKey = UniqueKey();

  Future<void> _loadMissionState() async {
    try {
      final response = await supabase
          .from('robot_logs')
          .select()
          .order('tarih_saat', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final sonKayit = response[0];
        final durum = sonKayit['durum'].toString();
        final hedef = sonKayit['hedef'].toString();

        setState(() {
          lastTarget = hedef;

          if (durum.contains("Görev Başlatıldı") || durum.contains("Hareket")) {
            isMissionActive = true;
            isMoving = true;
            manualStopTriggered = false;
          } else if (durum.contains("Durduruldu") || durum.contains("Durdu")) {
            isMissionActive = true;
            isMoving = false;
            manualStopTriggered = true;
          } else {
            isMissionActive = false;
            isMoving = false;
            manualStopTriggered = false;
          }
        });
      }
    } catch (e) {
      print("Durum kurtarma hatası: $e");
    }

    connectMQTT();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMissionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    client.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        connectMQTT();
      }
      // YENİ: Uygulama uyandığında logları otomatik olarak tazelemeyi dener
      setState(() {
        _streamKey = UniqueKey();
      });
    }
  }

  // --- YENİ: MANUEL YENİLEME FONKSİYONU ---
  void _verileriYenile() {
    setState(() {
      _streamKey = UniqueKey(); // StreamBuilder'ı zorla yeniden başlatır
    });

    _loadMissionState(); // Butonların durumunu DB'den kontrol et

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      connectMQTT(); // Kopmuşsa MQTT'yi tekrar bağla
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sistem ve geçmiş yenilendi!'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _islemOnayiIste(
    String target,
    String commandType,
    String islemAdi,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('İşlem Onayı'),
            ],
          ),
          content: Text(
            '"$islemAdi" işlemini gerçekleştirmek istediğinize emin misiniz?',
            style: const TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Evet, Onayla',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                sendCommand(target, commandType);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _gecmisiTemizle() async {
    try {
      final sonKayit = await supabase
          .from('robot_logs')
          .select('id')
          .order('tarih_saat', ascending: false)
          .limit(1);
      if (sonKayit.isNotEmpty) {
        final int sonId = sonKayit[0]['id'];
        await supabase.from('robot_logs').delete().neq('id', sonId);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geçmiş temizlendi (Son konum saklandı)!'),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
    }
  }

  Future<void> logVeritabaninaYaz(String hedef, String durum) async {
    try {
      await supabase.from('robot_logs').insert({
        'hedef': hedef,
        'durum': durum,
      });
    } catch (e) {}
  }

  Future<void> connectMQTT() async {
    client = MqttServerClient(
      broker,
      'flutter_ui_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = 1883;
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    client.onDisconnected = () async {
      if (mounted)
        setState(() {
          isConnected = false;
          robotStatus = "Bağlantı Koptu! Yeniden deneniyor...";
        });
      await Future.delayed(const Duration(seconds: 3));
      if (!isConnected && mounted) connectMQTT();
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
        final String pt = MqttPublishPayload.bytesToStringAsString(
          (c[0].payload as MqttPublishMessage).payload.message,
        );
        try {
          final data = jsonDecode(pt);
          setState(() {
            String yeniDurum = data['durum'] ?? "Bilinmiyor";
            batteryLevel = data['batarya'] ?? "%--";

            if (yeniDurum.contains("Ulaşıldı") &&
                !robotStatus.contains("Ulaşıldı")) {
              logVeritabaninaYaz(lastTarget, "Başarıyla Ulaştı");
              isMissionActive = false;
              manualStopTriggered = false;
            } else if ((yeniDurum.contains("Boşta") ||
                    yeniDurum.contains("Durdu")) &&
                isMissionActive &&
                !manualStopTriggered) {
              logVeritabaninaYaz(lastTarget, "Başarıyla Ulaştı");
              isMissionActive = false;
              manualStopTriggered = false;
            } else if (yeniDurum.contains("Engel") &&
                !robotStatus.contains("Engel")) {
              logVeritabaninaYaz(lastTarget, "Hata: Yol Tıkalı!");
            } else if (yeniDurum.contains("Raydan") &&
                !robotStatus.contains("Raydan")) {
              logVeritabaninaYaz(lastTarget, "Raydan Çıktı!");
            }

            robotStatus = yeniDurum;

            if (yeniDurum.contains("Ulaşıldı") || yeniDurum.contains("Boşta")) {
              isMoving = false;
              isMissionActive = false;
              manualStopTriggered = false;
            } else if (yeniDurum.contains("Durdu") ||
                yeniDurum.contains("Engel") ||
                yeniDurum.contains("Raydan")) {
              isMoving = false;
            } else if (yeniDurum.contains("Hareket")) {
              isMoving = true;
              isMissionActive = true;
            }
          });
        } catch (e) {}
      });
    }
  }

  void sendCommand(String target, String commandType) {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;
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
          isMissionActive = true;
          manualStopTriggered = false;
          lastTarget = target;
          logVeritabaninaYaz(target, "Görev Başlatıldı");
        } else if (commandType == "DUR") {
          isMoving = false;
          manualStopTriggered = true;
          logVeritabaninaYaz(lastTarget, "Acil Durduruldu");
        } else if (commandType == "SIFIRLA") {
          isMoving = false;
          isMissionActive = false;
          manualStopTriggered = false;
          logVeritabaninaYaz("Base", "Konum Sıfırlandı");
        }
      });
    } catch (e) {}
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
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Robotu Bırak ve Çıkış Yap',
            onPressed: () => cikisYap(context, kAdi: widget.aktifKullanici),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (!isMoving && isMissionActive)
                          ? () => _islemOnayiIste(
                              lastTarget,
                              "BASLA",
                              "Göreve Devam Etme",
                            )
                          : null,
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
                      onPressed: isMoving
                          ? () => sendCommand(lastTarget, "DUR")
                          : null,
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
                        onPressed: isMissionActive
                            ? null
                            : () => _islemOnayiIste(
                                "Base",
                                "GIT",
                                "Base'e Dönme",
                              ),
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
                        onPressed: isMoving
                            ? null
                            : () => _islemOnayiIste(
                                "Base",
                                "SIFIRLA",
                                "Konumu Sıfırlama",
                              ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Canlı Görev Geçmişi",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                // YENİ: İkonları yan yana koyabilmek için Row içine alındı
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.blue,
                        size: 28,
                      ),
                      tooltip: "Geçmişi Yenile",
                      onPressed: _verileriYenile, // YENİ: Buton eklendi
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      tooltip: "Görev Geçmişini Temizle",
                      onPressed: _gecmisiTemizle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: _streamKey, // YENİ: Bu anahtar ile Stream zorla yenilenir
              stream: supabase
                  .from('robot_logs')
                  .stream(primaryKey: ['id'])
                  .order('tarih_saat', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
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

                    Color durumRengi;
                    IconData durumIkona;

                    if (durum.contains("Ulaştı") ||
                        durum.contains("Başarıyla")) {
                      durumRengi = Colors.green;
                      durumIkona = Icons.check_circle;
                    } else if (durum.contains("Hata") ||
                        durum.contains("Acil") ||
                        durum.contains("Raydan") ||
                        durum.contains("Durduruldu")) {
                      durumRengi = Colors.red;
                      durumIkona = Icons.warning_amber_rounded;
                    } else if (durum.contains("Sıfırlandı")) {
                      durumRengi = Colors.blueGrey;
                      durumIkona = Icons.restore;
                    } else {
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
          onPressed: isMissionActive
              ? null
              : () => _islemOnayiIste(
                  label.replaceAll(" ", ""),
                  "GIT",
                  "$label hedefine gitme",
                ),
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
