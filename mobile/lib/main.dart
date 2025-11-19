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
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
  // 1. KONTROL DEĞİŞKENLERİ EN ÜSTTE OLMALI!
  final TextEditingController _controller = TextEditingController(text: "THYAO.IS"); // EKLENDİ
  Map<String, dynamic>? _sonuc;
  bool _yukleniyor = false;
  String? _hataMesaji;
  List<Map<String, dynamic>> _grafikVerisi = [];

  // Render adresin
  final url = Uri.parse('https://borsa-api-ompc.onrender.com/analiz');
  // API Şifren
  final String apiKey = "BorsaKahini_GizliSifre_2025";

  // 2. KATEGORİ LİSTELERİ BURADAN SONRA GELMELİ

  final List<Map<String, String>> kriptolar = [
    {"isim": "Bitcoin", "kod": "BTC-USD"},
    {"isim": "Ethereum", "kod": "ETH-USD"},
    {"isim": "Binance", "kod": "BNB-USD"},
    {"isim": "Solana", "kod": "SOL-USD"},
    {"isim": "Ripple", "kod": "XRP-USD"},
    {"isim": "Floki", "kod": "FLOKI-USD"},
    {"isim": "Fetchai", "kod": "FET-USD"},
    {"isim": "Ether.fi", "kod": "ETHFI-USD"},
    {"isim": "Polkadot", "kod": "DOT-USD"},
    {"isim": "Shiba Inu", "kod": "SHIB-USD"},
    {"isim": "Terra-Clasic", "kod": "LUNC-USD"},
    {"isim": "Pepecoin", "kod": "PEPE-USD"},
  ];

  final List<Map<String, String>> dovizler = [
    {"isim": "Dolar", "kod": "USDTRY=X"},
    {"isim": "Euro", "kod": "EURTRY=X"},
    {"isim": "Sterlin", "kod": "GBPTRY=X"},
    {"isim": "İsv. Frangı", "kod": "CHFTRY=X"},
    {"isim": "Japon Yeni", "kod": "JPYTRY=X"},
  ];

  final List<Map<String, String>> emtialar = [
    {"isim": "Altın (Ons)", "kod": "GC=F"},
    {"isim": "Gümüş", "kod": "SI=F"},
    {"isim": "Petrol", "kod": "CL=F"},
    {"isim": "Platin", "kod": "PL=F"}
  ];
  // ------------------------------------------

  final List<Map<String, String>> bistHisseleri = [
    {"isim": "THY", "kod": "THYAO.IS"},
    {"isim": "EREĞLİ", "kod": "EREGL.IS"},
    {"isim": "SAHOL", "kod": "SAHOL.IS"},
    {"isim": "TÜPRAŞ", "kod": "TUPRS.IS"},
    {"isim": "GARANTİ", "kod": "GARAN.IS"},
    {"isim": "ŞİŞECAM", "kod": "SISE.IS"},
    {"isim": "BİM", "kod": "BIMAS.IS"},
  ];
  // ------------------------------------------

  // FONSİYON GÜNCELLENDİ (ozelKod eklendi)
  Future<void> analizEt({String? ozelKod}) async {
    // Eğer butona basıldıysa text alanını güncelle ve o kodu kullan
    String sembol = ozelKod ?? _controller.text.toUpperCase();
    if (ozelKod != null) {
      _controller.text = ozelKod;
    }

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
        body: jsonEncode({"sembol": sembol}), // sembol kullanılıyor
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> rawList = data['gecmis'] ?? [];
        List<Map<String, dynamic>> processedList = [];

        if (rawList.isNotEmpty) {
           for(var item in rawList) {
             processedList.add({
               "tarih": item["tarih"],
               "fiyat": (item["fiyat"] as num).toDouble()
             });
           }
        }

        setState(() {
          _sonuc = data;
          _grafikVerisi = processedList;
        });

        if (processedList.isEmpty) {
           setState(() {
             _hataMesaji = "Veri geldi ama grafik bilgisi boş. Sunucuyu bekleyin.";
           });
        }

      } else {
        setState(() {
          // Hata mesajı sunucudan gelen kodla daha netleştirildi
          _hataMesaji = "Hata: ${response.statusCode}. Sembol bulunamadı veya sunucu hatası.";
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
    // 1. RefreshIndicator, kaydırılabilir bir widget'ı sarmalıdır (SingleChildScrollView)
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Borsa Kâhini 🧠"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator( // <<< YENİ EKLENEN WIDGET
        color: Colors.blueAccent, // Yenileme çubuğunun rengi
        onRefresh: () => analizEt(), // Aşağı çekilince analizEt fonksiyonunu çağırır

        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          // ScrollView'ın her zaman kaydırılabilir olmasını sağlar.
          // Bu, içerik kısayken bile aşağı çekmeyi mümkün kılar.
          physics: const AlwaysScrollableScrollPhysics(),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                // ... (TextField içeriği aynı kalır) ...
              ),
              const SizedBox(height: 20),

              // --- KATEGORİ SEÇİM ALANI ---
              _buildKategoriBaslik("💎 Kripto Paralar"),
              _buildYatayListe(kriptolar, Colors.orange),

              const SizedBox(height: 15),
              _buildKategoriBaslik("🌍 Döviz Piyasası"),
              _buildYatayListe(dovizler, Colors.green),

              const SizedBox(height: 15),
              _buildKategoriBaslik("🥇 Emtia (Altın/Gümüş/Petrol)"),
              _buildYatayListe(emtialar, Colors.amber),

              const SizedBox(height: 15),
              _buildKategoriBaslik("🇹🇷 BIST Popüler Hisseler"),
              _buildYatayListe(bistHisseleri, Colors.blue),

              // ---------------------------

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _yukleniyor ? null : () => analizEt(),
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
                const Text("Son 30 Gün (Dokunarak İncele 👇)", style: TextStyle(color: Colors.grey)),
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
                      : const Center(child: Text("Veri bekleniyor...", style: TextStyle(color: Colors.white54))),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

  // Kategori Başlık Widget'ı
  Widget _buildKategoriBaslik(String baslik) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 5),
      child: Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 14)),
    );
  }

  // Yatay Liste Widget'ı (ActionChip'ler)
  Widget _buildYatayListe(List<Map<String, String>> liste, Color renk) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: liste.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ActionChip(
              label: Text(item["isim"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: renk.withOpacity(0.2),
              side: BorderSide(color: renk, width: 1),
              onPressed: () => analizEt(ozelKod: item["kod"]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ... _buildGrafik, _buildSonucKarti ve _buildBilgi fonksiyonları devam etmeli ...

Widget _buildGrafik() {
    if (_grafikVerisi.isEmpty) return const SizedBox();

    // Hangi varlık olduğunu kontrol etmek için basamak sayısını belirle
    final bool isCrypto = (_sonuc!['hisse'] as String).endsWith('-USD');
    final int digits = isCrypto ? 8 : 4; // Kripto ise 8, değilse 4 basamak

    List<double> fiyatlar = _grafikVerisi.map((e) => e['fiyat'] as double).toList();

    double minY = fiyatlar.reduce((curr, next) => curr < next ? curr : next);
    double maxY = fiyatlar.reduce((curr, next) => curr > next ? curr : next);

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
        maxX: (fiyatlar.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueAccent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                int index = spot.x.toInt();
                String tarih = _grafikVerisi[index]['tarih'];
                double fiyat = _grafikVerisi[index]['fiyat'];

                return LineTooltipItem(
                  '$tarih\n${fiyat.toStringAsFixed(digits)}', // DİNAMİK FORMAT
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: fiyatlar.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
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

    // Hangi varlık olduğunu kontrol etmek için basamak sayısını belirle
    final bool isCrypto = (_sonuc!['hisse'] as String).endsWith('-USD');
    final int digits = isCrypto ? 8 : 4; // Kripto ise 8, değilse 4 basamak

    // API'dan gelen fiyatlar (num olarak varsayılıyor)
    final num currentPrice = _sonuc!['fiyat'] as num;
    final num predictedPrice = _sonuc!['tahmin'] as num;

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
              // Fiyat dinamik basamağa sabitlendi
              _buildBilgi("Şu An", "\$${currentPrice.toStringAsFixed(digits)}"),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              // Tahmin dinamik basamağa sabitlendi
              _buildBilgi("Tahmin", "\$${predictedPrice.toStringAsFixed(digits)}"),
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
