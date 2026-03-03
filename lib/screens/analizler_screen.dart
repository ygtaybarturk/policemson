// lib/screens/analizler_screen.dart – v4
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class AnalizlerScreen extends StatefulWidget {
  const AnalizlerScreen({super.key});
  @override
  State<AnalizlerScreen> createState() => _AnalizlerScreenState();
}

class _AnalizlerScreenState extends State<AnalizlerScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabCtrl;

  int _yil = DateTime.now().year;
  int _donem = 3;
  List<Map<String, dynamic>> _veri = [];
  bool _yukleniyor = true;

  final _donemler = [1, 2, 3, 6, 12];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final simdiAy = DateTime.now().month;
      final bas = (simdiAy - _donem + 1).clamp(1, 12);
      final bit = simdiAy;
      final v = await _db.aralikAnaliz(_yil, bas, bit);
      setState(() { _veri = v; _yukleniyor = false; });
    } catch (e) {
      setState(() { _veri = []; _yukleniyor = false; });
    }
  }

  // ── Hesaplama yardımcıları ─────────────────────────────
  int get _toplamPolice     => _veri.fold(0, (s, r) => s + (r['toplam'] as int));
  int get _toplamYapildi    => _veri.fold(0, (s, r) => s + (r['yapildi'] as int));
  int get _toplamYapilamadi => _veri.fold(0, (s, r) => s + (r['yapilamadi'] as int));
  int get _toplamBeklemede  => _veri.fold(0, (s, r) => s + (r['beklemede'] as int));
  double get _toplamGelir   => _veri.fold(0.0, (s, r) => s + (r['gelir'] as double));
  double get _toplamKomisyon => _veri.fold(0.0, (s, r) => s + ((r['komisyon'] as double?) ?? 0.0));
  double get _basariOrani   => _toplamPolice > 0 ? _toplamYapildi / _toplamPolice * 100 : 0;

  static const List<Color> _ayRenkleri = [
    Color(0xFF1565C0), Color(0xFF1E88E5), Color(0xFF42A5F5),
    Color(0xFF66BB6A), Color(0xFF2E7D32), Color(0xFF81C784),
    Color(0xFFE65100), Color(0xFFFF7043), Color(0xFFFFA726),
    Color(0xFF7B1FA2), Color(0xFF9C27B0), Color(0xFFBA68C8),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5, color: kText)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Özet'),
            Tab(text: 'Üretim'),
            Tab(text: 'Başarı'),
            Tab(text: 'Karşılaştır'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Dönem Seçici ──────────────────────────────
          Container(
            color: context.bgScaffold,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Text('Dönem:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 10),
                ..._donemler.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(d == 12 ? '1 Yıl' : '$d Ay'),
                    selected: _donem == d,
                    onSelected: (_) { setState(() => _donem = d); _yukle(); },
                    selectedColor: kPrimary,
                    labelStyle: TextStyle(
                      color: _donem == d ? Colors.white : null,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )),
                const Spacer(),
                Text(_yil.toString(),
                    style: TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
              ],
            ),
          ),
          // ── İçerik ────────────────────────────────────
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _ozet(),
                      _uretimGrafigi(),
                      _basariGrafigi(),
                      _karsilastirma(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 1: ÖZET
  // ══════════════════════════════════════════════════════════
  Widget _ozet() {
    final fmt = NumberFormat('#,##0.##', 'tr');
    final donemAdi = _donem == 12 ? '1 Yıllık' : '$_donem Aylık';
    final basariRenk = _basariOrani >= 70
        ? Colors.green
        : _basariOrani >= 40 ? Colors.orange : Colors.red;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [

        // ── Dönem başlık bandı ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('$donemAdi Özet · $_yil',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Toplam Prim & Komisyon ──
        Row(children: [
          Expanded(child: _paraKarti('💰 Toplam Prim', _toplamGelir, Colors.orange)),
          const SizedBox(width: 10),
          Expanded(child: _paraKarti('📈 Komisyon', _toplamKomisyon, Colors.purple)),
        ]),
        const SizedBox(height: 10),

        // ── Poliçe sayıları ──
        Row(children: [
          Expanded(child: _sayiKarti('Toplam', _toplamPolice, Colors.blue, '📋')),
          const SizedBox(width: 8),
          Expanded(child: _sayiKarti('Yapılan', _toplamYapildi, Colors.green, '✅')),
          const SizedBox(width: 8),
          Expanded(child: _sayiKarti('Yapılamayan', _toplamYapilamadi, Colors.red, '❌')),
          const SizedBox(width: 8),
          Expanded(child: _sayiKarti('Bekleyen', _toplamBeklemede, Colors.blue.shade300, '⏳')),
        ]),
        const SizedBox(height: 10),

        // ── Başarı oranı ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: basariRenk.withOpacity(.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: basariRenk.withOpacity(.2)),
          ),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Başarı Oranı',
                  style: TextStyle(fontSize: 11, color: context.textSub)),
              Text('${_basariOrani.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: basariRenk.shade700)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$_toplamYapildi / $_toplamPolice',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: context.textMain)),
              Text('yapıldı / toplam',
                  style: TextStyle(fontSize: 10, color: context.textSub)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Aylık prim & komisyon tablosu ──
        _kartBaslikli('📅 Aylık Prim & Komisyon Tablosu', _aylikParaTablo()),
        const SizedBox(height: 12),

        // ── Portföy dağılımı ──
        _kartBaslikli('🥧 Sigorta Türüne Göre Portföy Dağılımı', _portfoyDagilimi()),
        const SizedBox(height: 12),

        // ── Durum dağılımı pasta ──
        _kartBaslikli('📊 Durum Dağılımı', _pastaGrafik()),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _paraKarti(String baslik, double tutar, Color renk) {
    final fmt = NumberFormat('#,##0.##', 'tr');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withOpacity(.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik,
            style: TextStyle(
                fontSize: 11, color: context.textSub, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('₺${fmt.format(tutar)}',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: renk)),
        ),
      ]),
    );
  }

  Widget _sayiKarti(String baslik, int sayi, Color renk, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: renk.withOpacity(.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withOpacity(.2)),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text('$sayi',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: renk)),
        const SizedBox(height: 2),
        Text(baslik,
            style: TextStyle(
                fontSize: 9, color: context.textSub, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _aylikParaTablo() {
    if (_veri.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('Veri yok'));
    const aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final fmt = NumberFormat('#,##0.##', 'tr');

    return Column(children: [
      // Başlık
      Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          _hucre('Ay', bold: true, flex: 1),
          _hucre('Adet', bold: true, flex: 1),
          _hucre('Prim (₺)', bold: true, renk: Colors.orange.shade800, flex: 3),
          _hucre('Komisyon (₺)', bold: true, renk: Colors.purple.shade700, flex: 3),
        ]),
      ),
      const SizedBox(height: 2),
      ..._veri.map((r) {
        final g   = r['gelir'] as double;
        final k   = (r['komisyon'] as double?) ?? 0.0;
        final top = r['toplam'] as int;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: kDivider)),
          ),
          child: Row(children: [
            _hucre(aylar[r['ay'] as int], bold: true, flex: 1),
            _hucre('$top', flex: 1),
            _hucre(g > 0 ? fmt.format(g) : '-', renk: Colors.orange.shade800, flex: 3),
            _hucre(k > 0 ? fmt.format(k) : '-', renk: Colors.purple.shade700, flex: 3),
          ]),
        );
      }),
      // TOPLAM satırı
      Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimary.withOpacity(.15)),
        ),
        child: Row(children: [
          _hucre('TOPLAM', bold: true, flex: 1),
          _hucre('$_toplamPolice', bold: true, flex: 1),
          _hucre('₺${fmt.format(_toplamGelir)}', bold: true, renk: Colors.orange.shade800, flex: 3),
          _hucre('₺${fmt.format(_toplamKomisyon)}', bold: true, renk: Colors.purple.shade700, flex: 3),
        ]),
      ),
    ]);
  }

  Widget _portfoyDagilimi() {
    // Tüm poliçeleri dönem içinde türe göre say
    if (_veri.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('Veri yok'));

    // turDagilimi: her türün toplam poliçe sayısını tut
    // Bunu _veri'den değil doğrudan DB'den çekemiyoruz ama
    // _veri içinde turDagilimi yoksa göster: pasta yerine yazılı liste
    final turMap = <String, int>{};
    for (final r in _veri) {
      final turDagilim = r['turDagilimi'] as Map<String, int>?;
      if (turDagilim != null) {
        turDagilim.forEach((k, v) {
          turMap[k] = (turMap[k] ?? 0) + v;
        });
      }
    }

    if (turMap.isEmpty) {
      // turDagilimi yok, genel bilgi göster
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          _portfoyRow('🚗 Trafik + Kasko', _toplamPolice, Colors.blue),
          const SizedBox(height: 6),
          _portfoyRow('📋 Toplam Poliçe', _toplamPolice, kPrimary),
          const SizedBox(height: 6),
          _portfoyRow('✅ Yapılan', _toplamYapildi, Colors.green),
          const SizedBox(height: 6),
          _portfoyRow('❌ Yapılamayan', _toplamYapilamadi, Colors.red),
          const SizedBox(height: 6),
          _portfoyRow('⏳ Bekleyen', _toplamBeklemede, Colors.orange),
        ]),
      );
    }

    final toplam = turMap.values.fold(0, (s, v) => s + v);
    final renkler = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.pink, Colors.indigo,
    ];
    final entries = turMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries.asMap().entries.map((e) {
        final renk = renkler[e.key % renkler.length];
        final label = e.value.key;
        final count = e.value.value;
        final yuzde = toplam > 0 ? count / toplam * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$count adet  ${yuzde.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: toplam > 0 ? count / toplam : 0,
                backgroundColor: renk.withOpacity(.12),
                valueColor: AlwaysStoppedAnimation(renk),
                minHeight: 8,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _portfoyRow(String label, int sayi, Color renk) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: renk.withOpacity(.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$sayi adet',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: renk)),
      ),
    ]);
  }

  Widget _pastaGrafik() {
    if (_veri.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('Veri yok')));
    final yap  = _toplamYapildi.toDouble();
    final yap2 = _toplamYapilamadi.toDouble();
    final bekl = _toplamBeklemede.toDouble();
    final son  = _veri.fold(0, (s, r) => s + (r['dahaSonra'] as int)).toDouble();
    final top  = yap + yap2 + bekl + son;
    if (top == 0) return const SizedBox(height: 80, child: Center(child: Text('Henüz veri yok')));

    return SizedBox(
      height: 200,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sections: [
              if (yap  > 0) PieChartSectionData(value: yap,  color: Colors.green.shade600, title: '${(yap/top*100).toStringAsFixed(0)}%',  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), radius: 70),
              if (yap2 > 0) PieChartSectionData(value: yap2, color: Colors.red.shade600,   title: '${(yap2/top*100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), radius: 70),
              if (bekl > 0) PieChartSectionData(value: bekl, color: Colors.blue.shade400,  title: '${(bekl/top*100).toStringAsFixed(0)}%', titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), radius: 70),
              if (son  > 0) PieChartSectionData(value: son,  color: Colors.orange.shade600,title: '${(son/top*100).toStringAsFixed(0)}%',  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), radius: 70),
            ],
            centerSpaceRadius: 30,
          )),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lejantItem(Colors.green.shade600,  'Yapıldı: ${yap.toInt()}'),
            _lejantItem(Colors.red.shade600,    'Yapılamadı: ${yap2.toInt()}'),
            _lejantItem(Colors.blue.shade400,   'Beklemede: ${bekl.toInt()}'),
            _lejantItem(Colors.orange.shade600, 'Daha Sonra: ${son.toInt()}'),
          ],
        ),
        const SizedBox(width: 8),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 2: ÜRETİM
  // ══════════════════════════════════════════════════════════
  Widget _uretimGrafigi() {
    if (_veri.isEmpty) return const Center(child: Text('Veri yok'));
    const aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📊 Aylık Toplam Poliçe Sayısı',
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              barGroups: _veri.asMap().entries.map((e) {
                final r    = e.value;
                final yap  = (r['yapildi']    as int).toDouble();
                final yap2 = (r['yapilamadi'] as int).toDouble();
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: yap,  color: Colors.green.shade600, width: 10, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: yap2, color: Colors.red.shade500,   width: 10, borderRadius: BorderRadius.circular(4)),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= _veri.length) return const SizedBox();
                    return Text(aylar[_veri[idx]['ay'] as int], style: const TextStyle(fontSize: 9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData:   FlGridData(drawVerticalLine: false),
            )),
          ),
        ),
        const SizedBox(height: 12),
        _kartBaslikli(
          '💰 Aylık Gelir (₺)',
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), (e.value['gelir'] as double) / 1000)).toList(),
                  isCurved: true,
                  color: Colors.orange.shade700,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.orange.shade700.withOpacity(.1)),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= _veri.length) return const SizedBox();
                    return Text(aylar[_veri[idx]['ay'] as int], style: const TextStyle(fontSize: 9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                    getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}K', style: const TextStyle(fontSize: 9)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData:   const FlGridData(drawVerticalLine: false),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _lejantItem(Colors.green.shade600, 'Yapılan'),
          const SizedBox(width: 16),
          _lejantItem(Colors.red.shade500,   'Yapılamayan'),
          const SizedBox(width: 16),
          _lejantItem(Colors.orange.shade700,'Gelir'),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 3: BAŞARI
  // ══════════════════════════════════════════════════════════
  Widget _basariGrafigi() {
    if (_veri.isEmpty) return const Center(child: Text('Veri yok'));
    const aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📈 Aylık Başarı Oranı (%)',
          SizedBox(
            height: 220,
            child: BarChart(BarChartData(
              maxY: 100,
              barGroups: _veri.asMap().entries.map((e) {
                final r   = e.value;
                final top = r['toplam'] as int;
                final yap = r['yapildi'] as int;
                final oran = top > 0 ? yap / top * 100 : 0.0;
                final renk = oran >= 70 ? Colors.green.shade600
                           : oran >= 40 ? Colors.orange.shade600
                           : Colors.red.shade600;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(toY: oran, color: renk, width: 18, borderRadius: BorderRadius.circular(6)),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= _veri.length) return const SizedBox();
                    return Text(aylar[_veri[i]['ay'] as int], style: const TextStyle(fontSize: 9));
                  },
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 9)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(.15), strokeWidth: 1),
              ),
            )),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _yuzdKarti('Ortalama Başarı', '${_basariOrani.toStringAsFixed(1)}%',
              _basariOrani >= 70 ? Colors.green : _basariOrani >= 40 ? Colors.orange : Colors.red)),
          const SizedBox(width: 10),
          Expanded(child: _yuzdKarti('Kayıp Oranı',
              '${(_toplamPolice > 0 ? _toplamYapilamadi / _toplamPolice * 100 : 0).toStringAsFixed(1)}%',
              Colors.red)),
        ]),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 4: KARŞILAŞTIRMA
  // ══════════════════════════════════════════════════════════
  Widget _karsilastirma() {
    if (_veri.length < 2) return const Center(child: Text('En az 2 aylık veri gerekli'));
    const aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _kartBaslikli(
          '📈 Üretim Trendi',
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), (e.value['toplam'] as int).toDouble())).toList(),
                  isCurved: true, color: Colors.blue.shade600, barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.blue.shade600.withOpacity(.08)),
                ),
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), (e.value['yapildi'] as int).toDouble())).toList(),
                  isCurved: true, color: Colors.green.shade600, barWidth: 2,
                  dotData: const FlDotData(show: true),
                ),
                LineChartBarData(
                  spots: _veri.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), (e.value['yapilamadi'] as int).toDouble())).toList(),
                  isCurved: true, color: Colors.red.shade500, barWidth: 2,
                  dashArray: [5, 5],
                  dotData: const FlDotData(show: true),
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                    getTitlesWidget: (v, _) { final i = v.toInt(); if (i < 0 || i >= _veri.length) return const SizedBox(); return Text(aylar[_veri[i]['ay'] as int], style: const TextStyle(fontSize: 9)); })),
                leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(drawVerticalLine: false),
            )),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _lejantItem(Colors.blue.shade600,  'Toplam'),
          const SizedBox(width: 14),
          _lejantItem(Colors.green.shade600, 'Yapılan'),
          const SizedBox(width: 14),
          _lejantItem(Colors.red.shade500,   'Yapılamayan'),
        ]),
        const SizedBox(height: 14),
        _kartBaslikli('🏆 Performans Özeti', _performansOzet(aylar)),
      ],
    );
  }

  Widget _performansOzet(List<String> aylar) {
    if (_veri.isEmpty) return const SizedBox();
    final sorted = [..._veri]..sort((a, b) => (b['yapildi'] as int).compareTo(a['yapildi'] as int));
    final enIyi  = sorted.first;
    final enKotu = sorted.last;
    final byGelir = [..._veri]..sort((a, b) => (b['gelir'] as double).compareTo(a['gelir'] as double));
    final fmt = NumberFormat('#,##0.##', 'tr');

    return Column(children: [
      _performansSatiri('🏆 En İyi Ay', aylar[enIyi['ay'] as int], '${enIyi["yapildi"]} yapılan', Colors.green),
      _performansSatiri('📉 En Düşük Ay', aylar[enKotu['ay'] as int], '${enKotu["yapildi"]} yapılan', Colors.red),
      _performansSatiri('💰 En Yüksek Gelir', aylar[byGelir.first['ay'] as int],
          '₺${fmt.format(byGelir.first["gelir"])}', Colors.orange),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ══════════════════════════════════════════════════════════
  Widget _lejantItem(Color c, String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(fontSize: 11)),
    ]),
  );

  Widget _hucre(String t, {bool bold = false, Color? renk, int flex = 1}) => Expanded(
    flex: flex,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      child: Text(t,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: renk)),
    ),
  );

  Widget _yuzdKarti(String baslik, String deger, Color renk) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: renk.withOpacity(.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: renk.withOpacity(.2)),
    ),
    child: Column(children: [
      Text(deger, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: renk)),
      Text(baslik, style: TextStyle(fontSize: 11, color: context.textSub)),
    ]),
  );

  Widget _performansSatiri(String etiket, String ay, String deger, Color renk) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(etiket, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: renk.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
        child: Text('$ay · $deger',
            style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );

  Widget _kartBaslikli(String baslik, Widget child) => Container(
    decoration: BoxDecoration(
      color: context.bgCard,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(baslik,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textMain)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}
