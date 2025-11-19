import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Borsa Kâhini',
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
  List<double> _grafikVerisi = [];

  // Render adresini buraya yapıştır
  final url = Uri.parse('https://borsa-api-ompc.onrender.com/analiz');
  // API Şifreni buraya yapıştır
  final String apiKey = "BorsaKahini_GizliSifre_2025";

  Future<void> analizEt() async {
    setState(() {
      _yukleniyor = true;
      _hataMesaji = null;
      _sonuc = null;
      _grafikVerisi = [];
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": apiKey
        },
        body: jsonEncode({"sembol": _controller.text.toUpperCase()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> rawList = data['gecmis'] ?? [];
        List<double> prices = [];
        if (rawList.isNotEmpty) {
           prices = rawList.map((e) => (e as num).toDouble()).toList();
        }

        setState(() {
          _sonuc = data;
          _grafikVerisi = prices;
        });

        if (prices.isEmpty) {
           setState(() {
             _hataMesaji = "Analiz başarılı ama grafik verisi gelmedi. Sunucu güncelleniyor olabilir.";
           });
        }

      } else {
        setState(() {
          _hataMesaji = "Hata: ${response.statusCode}. Şifre veya Hisse Kodu yanlış.";
        });
      }
    } catch (e) {
      setState(() {
        _hataMesaji = "Bağlantı hatası: $e";
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Hisse Kodu (Örn: GARAN.IS)",
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
                    : const Text("Analiz Et 🚀", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
            if (_hataMesaji != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.red.withOpacity(0.1),
                child: Text(_hataMesaji!, style: const TextStyle(color: Colors.red)),
              ),

            if (_sonuc != null) ...[
              _buildSonucKarti(),
              const SizedBox(height: 30),
              const Text("Son 30 Günlük Trend", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Container(
                height: 250,
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D44),
                  borderRadius: BorderRadius.circular(15)
                ),
                child: _grafikVerisi.isNotEmpty
                    ? _buildGrafik()
                    : const Center(child: Text("Grafik verisi bekleniyor...", style: TextStyle(color: Colors.white54))),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGrafik() {
    if (_grafikVerisi.isEmpty) return const SizedBox();

    double minY = _grafikVerisi.reduce((curr, next) => curr < next ? curr : next);
    double maxY = _grafikVerisi.reduce((curr, next) => curr > next ? curr : next);

    if (minY == maxY) {
      minY = minY * 0.99;
      maxY = maxY * 1.01;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (_grafikVerisi.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _grafikVerisi.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            // DÜZELTME BURADA: 'colors' yerine 'color' yaptık
            color: Colors.blueAccent,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              // DÜZELTME BURADA: 'colors' yerine 'color' yaptık
              color: Colors.blueAccent.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

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
              _buildBilgi("Şu An", "\$${_sonuc!['fiyat']}"),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              _buildBilgi("Tahmin", "\$${_sonuc!['tahmin']}"),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
            decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(30)),
            child: Text(sinyal, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBilgi(String baslik, String deger) {
    return Column(
      children: [
        Text(baslik, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 5),
        Text(deger, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
