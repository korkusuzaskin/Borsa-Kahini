import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
      ),
      home: const BorsaEkrani(),
    );
  }
}

class BorsaEkrani extends StatefulWidget {
  const BorsaEkrani({super.key});

  @override
  State<BorsaEkrani> createState() => _BorsaEkraniState();
}

class _BorsaEkraniState extends State<BorsaEkrani> {
  final TextEditingController _controller = TextEditingController(text: "THYAO.IS");
  Map<String, dynamic>? _sonuc;
  bool _yukleniyor = false;
  String? _hataMesaji;

  // API İSTEĞİ GÖNDERME
  Future<void> analizEt() async {
    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
      _sonuc = null;
    });

    // NOT: Android Emülatör kullanıyorsan '10.0.2.2' kullanmalısın.
    // Gerçek telefonda test ediyorsan bilgisayarının IP adresini yaz (Örn: 192.168.1.25)
    final url = Uri.parse('http://10.0.2.2:8000/analiz');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sembol": _controller.text.toUpperCase()}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _sonuc = jsonDecode(response.body);
        });
      } else {
        setState(() {
          _hataMesaji = "Analiz başarısız. Hisse kodunu kontrol edin.";
        });
      }
    } catch (e) {
      setState(() {
        _hataMesaji = "Sunucuya bağlanılamadı. Backend açık mı?";
      });
    } finally {
      setState(() {
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Borsa Kâhini 🧠"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // GİRİŞ ALANI
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Hisse Kodu (Örn: THYAO.IS)",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF2D2D44),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                  onPressed: analizEt,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ANALİZ BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _yukleniyor ? null : analizEt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _yukleniyor
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Yapay Zekaya Sor 🚀", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 30),

            // SONUÇ ALANI
            if (_hataMesaji != null)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(_hataMesaji!, style: const TextStyle(color: Colors.red)),
              ),

            if (_sonuc != null) ...[
              _buildSonucKarti(),
            ]
          ],
        ),
      ),
    );
  }

  // SONUÇ KARTI TASARIMI
  Widget _buildSonucKarti() {
    final sinyal = _sonuc!['sinyal'];
    final renk = sinyal.contains("AL") ? Colors.green : (sinyal.contains("SAT") ? Colors.red : Colors.grey);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withOpacity(0.5), width: 2),
        boxShadow: [BoxShadow(color: renk.withOpacity(0.2), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Text(_sonuc!['hisse'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const Divider(color: Colors.grey),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBilgiKutusu("Şu An", "\$${_sonuc!['fiyat']}"),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              _buildBilgiKutusu("Tahmin", "\$${_sonuc!['tahmin']}"),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(30)),
            child: Text(
              sinyal,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text("Beklenen Değişim: %${_sonuc!['fark']}", style: TextStyle(color: renk)),
        ],
      ),
    );
  }

  Widget _buildBilgiKutusu(String baslik, String deger) {
    return Column(
      children: [
        Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 5),
        Text(deger, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
