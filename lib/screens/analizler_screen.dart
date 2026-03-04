// lib/screens/analizler_screen.dart – v6
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/police_model.dart';

class AnalizlerScreen extends StatefulWidget {
  const AnalizlerScreen({super.key});
  @override
  State<AnalizlerScreen> createState() => _AnalizlerScreenState();
}

class _AnalizlerScreenState extends State<AnalizlerScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabCtrl;

  int _yil   = DateTime.now().year;
  int _donem = 3;

  List<Map<String, dynamic>> _veri = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final simdi   = DateTime.now();
      final simdiAy = simdi.month;
      final simdiYil= simdi.year;

      // bas: _donem ay öncesi, bit: bu ay
      // Örn: donem=3, simdiAy=1 → bas=-1 (Kasım önceki yıl), bit=1
      final bas = simdiAy - _donem + 1; // negatif olabilir → aralikAnaliz halleder
      final bit = simdiAy;

      final v = await _db.aralikAnaliz(simdiYil, bas, bit);
      if (mounted) setState(() { _veri = v; _yukleniyor = false; });
    } catch (e) {
      if (mounted) setState(() { _veri = []; _yukleniyor = false; });
    }
  }

  // ── Toplam hesaplamalar ──
  int    get _toplamPolice     => _veri.fold(0,   (s, r) => s + (r['toplam']     as int));
  int    get _toplamYapildi    => _veri.fold(0,   (s, r) => s + (r['yapildi']    as int));
  int    get _toplamYapilamadi => _veri.fold(0,   (s, r) => s + (r['yapilamadi'] as int));
  int    get _toplamBeklemede  => _veri.fold(0,   (s, r) => s + (r['beklemede']  as int));
  int    get _toplamSonra      => _veri.fold(0,   (s, r) => s + (r['dahaSonra']  as int));
  double get _toplamGelir      => _veri.fold(0.0, (s, r) => s + (r['gelir']      as double));
  double get _toplamKomisyon   => _veri.fold(0.0, (s, r) => s + ((r['komisyon']  as double?) ?? 0.0));
  double get _toplamZeyilTutar    => _veri.fold(0.0, (s, r) => s + ((r['zeyilTutar']    as double?) ?? 0.0));
  double get _toplamZeyilKomisyon => _veri.fold(0.0, (s, r) => s + ((r['zeyilKomisyon'] as double?) ?? 0.0));
  double get _netGelir    => _toplamGelir    + _toplamZeyilTutar;
  double get _netKomisyon => _toplamKomisyon + _toplamZeyilKomisyon;
  bool   get _zeyilVar    => _toplamZeyilTutar != 0 || _toplamZeyilKomisyon != 0;
  double get _basariOrani      => _toplamPolice > 0 ? _toplamYapildi / _toplamPolice * 100 : 0.0;

  // Tüm dönemdeki tür dağılımı birleştir
  Map<String, int>    get _turDagilimi => _birlestir<int>('turDagilimi', 0, (a, b) => a + b);
  Map<String, double> get _turPrim     => _birlestir<double>('turPrim', 0.0, (a, b) => a + b);
  Map<String, double> get _turKomisyon => _birlestir<double>('turKomisyon', 0.0, (a, b) => a + b);
  Map<String, String> get _turEmoji {
    final map = <String, String>{};
    for (final r in _veri) {
      final te = r['turEmoji'] as Map<String, String>?;
      te?.forEach((k, v) => map[k] = v);
    }
    return map;
  }

  Map<String, T> _birlestir<T>(String key, T init, T Function(T, T) combine) {
    final map = <String, T>{};
    for (final r in _veri) {
      final sub = r[key] as Map<String, T>?;
      sub?.forEach((k, v) => map[k] = combine(map[k] ?? init, v));
    }
    return map;
  }

  final _fmt  = NumberFormat('#,##0.##', 'tr');
  static const _ayAdlari = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Özet'), Tab(text: 'Üretim'), Tab(text: 'Portföy')],
        ),
      ),
      body: Column(children: [
        // ── Dönem seçici ──
        Container(
          color: context.bgScaffold,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Text('Dönem:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(width: 8),
            ...[1, 2, 3, 6, 12].map((d) => Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(d == 12 ? '1 Yıl' : '$d Ay', style: const TextStyle(fontSize: 11)),
                selected: _donem == d,
                onSelected: (_) { setState(() => _donem = d); _yukle(); },
                selectedColor: kPrimary,
                labelStyle: TextStyle(
                    color: _donem == d ? Colors.white : null,
                    fontWeight: FontWeight.w700),
              ),
            )),
          ]),
        ),
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _veri.every((r) => (r['toplam'] as int) == 0)
                  ? _bosEkran()
                  : TabBarView(controller: _tabCtrl, children: [
                      _ozetTab(),
                      _uretimTab(),
                      _portfoyTab(),
                    ]),
        ),
      ]),
    );
  }

  Widget _bosEkran() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.bar_chart_rounded, size: 56, color: kTextSub.withOpacity(.3)),
    const SizedBox(height: 12),
    Text('Bu dönem için poliçe bulunamadı', style: TextStyle(color: kTextSub, fontSize: 14)),
    const SizedBox(height: 8),
    Text('Farklı bir dönem seçin', style: TextStyle(color: kTextSub.withOpacity(.6), fontSize: 12)),
  ]));

  // ══════════════════════════════════════════════════════════
  // TAB 1: ÖZET
  // ══════════════════════════════════════════════════════════
  Widget _ozetTab() {
    final donemAdi = _donem == 12 ? '1 Yıllık' : '$_donem Aylık';
    final basariRenk = _basariOrani >= 70 ? Colors.green
        : _basariOrani >= 40 ? Colors.orange : Colors.red;

    return ListView(padding: const EdgeInsets.all(14), children: [

      // ── Dönem bandı ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('$donemAdi Özet',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Prim & Komisyon ──
      Row(children: [
        Expanded(child: _paraKart('💰 Net Prim', _netGelir, Colors.orange,
            alt: _zeyilVar ? 'Poliçe: ₺${_fmt.format(_toplamGelir)}  Zeyil: ₺${_fmt.format(_toplamZeyilTutar)}' : null)),
        const SizedBox(width: 10),
        Expanded(child: _paraKart('📈 Net Komisyon', _netKomisyon, Colors.purple,
            alt: _zeyilVar ? 'Poliçe: ₺${_fmt.format(_toplamKomisyon)}  Zeyil: ₺${_fmt.format(_toplamZeyilKomisyon)}' : null)),
      ]),
      const SizedBox(height: 10),

      // ── Poliçe sayıları ──
      Row(children: [
        Expanded(child: _sayiKart('Toplam', _toplamPolice, Colors.blue, '📋')),
        const SizedBox(width: 6),
        Expanded(child: _sayiKart('Yapılan', _toplamYapildi, Colors.green, '✅')),
        const SizedBox(width: 6),
        Expanded(child: _sayiKart('Yapılamayan', _toplamYapilamadi, Colors.red, '❌')),
        const SizedBox(width: 6),
        Expanded(child: _sayiKart('Bekleyen', _toplamBeklemede + _toplamSonra, Colors.blueGrey, '⏳')),
      ]),
      const SizedBox(height: 10),

      // ── Başarı oranı ──
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: basariRenk.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: basariRenk.withOpacity(.2)),
        ),
        child: Row(children: [
          Text('${_basariOrani.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: basariRenk)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Başarı Oranı',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextSub)),
            const SizedBox(height: 2),
            Text('$_toplamYapildi yapıldı / $_toplamPolice toplam',
                style: const TextStyle(fontSize: 11, color: kText, fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Aylık tablo ──
      _kart('📅 Aylık Detay', _aylikTablo()),
      const SizedBox(height: 20),
    ]);
  }

  Widget _aylikTablo() {
    return Column(children: [
      _satirBaslik(),
      const SizedBox(height: 4),
      ..._veri.map((r) => _aylikSatir(r)),
      const Divider(height: 12),
      _toplamSatir(),
    ]);
  }

  Widget _satirBaslik() => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
    decoration: BoxDecoration(color: kPrimary.withOpacity(.07), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      _h('Ay',       bold: true, flex: 1),
      _h('Adet',     bold: true, flex: 1),
      _h('Prim',     bold: true, renk: Colors.orange.shade700, flex: 3),
      _h('Komisyon', bold: true, renk: Colors.purple.shade700, flex: 3),
    ]),
  );

  Widget _aylikSatir(Map<String, dynamic> r) {
    final g   = (r['netGelir']    as double?) ?? (r['gelir']    as double);
    final k   = (r['netKomisyon'] as double?) ?? ((r['komisyon'] as double?) ?? 0.0);
    final top = r['toplam']   as int;
    final ay  = r['ay']       as int;
    final zVar = ((r['zeyilTutar'] as double?) ?? 0) != 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: kDivider))),
      child: Row(children: [
        _h(_ayAdlari[ay], bold: true, flex: 1),
        _h('$top${zVar ? ' ᶻ' : ''}', flex: 1),
        _h(g > 0 ? '₺${_fmt.format(g)}' : '-', renk: Colors.orange.shade700, flex: 3),
        _h(k > 0 ? '₺${_fmt.format(k)}' : '-', renk: Colors.purple.shade700, flex: 3),
      ]),
    );
  }

  Widget _toplamSatir() => Container(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
    decoration: BoxDecoration(
      color: kPrimary.withOpacity(.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kPrimary.withOpacity(.12)),
    ),
    child: Row(children: [
      _h('TOPLAM', bold: true, flex: 1),
      _h('$_toplamPolice', bold: true, flex: 1),
      _h('₺${_fmt.format(_netGelir)}',    bold: true, renk: Colors.orange.shade700, flex: 3),
      _h('₺${_fmt.format(_netKomisyon)}', bold: true, renk: Colors.purple.shade700, flex: 3),
    ]),
  );

  // ══════════════════════════════════════════════════════════
  // TAB 2: ÜRETİM
  // ══════════════════════════════════════════════════════════
  Widget _uretimTab() {
    final veriFiltreli = _veri.where((r) => (r['toplam'] as int) > 0).toList();
    if (veriFiltreli.isEmpty) return _bosEkran();

    return ListView(padding: const EdgeInsets.all(14), children: [

      _kart('📊 Aylık Poliçe Üretimi', SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          barGroups: veriFiltreli.asMap().entries.map((e) {
            final yap  = (e.value['yapildi']    as int).toDouble();
            final yap2 = (e.value['yapilamadi'] as int).toDouble();
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: yap,  color: Colors.green.shade600, width: 12, borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: yap2, color: Colors.red.shade400,   width: 12, borderRadius: BorderRadius.circular(4)),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= veriFiltreli.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(_ayAdlari[veriFiltreli[i]['ay'] as int], style: const TextStyle(fontSize: 9)));
                })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData:   FlGridData(drawVerticalLine: false),
        )),
      )),
      const SizedBox(height: 8),
      Row(children: [
        _lejant(Colors.green.shade600, 'Yapılan'),
        const SizedBox(width: 12),
        _lejant(Colors.red.shade400,   'Yapılamayan'),
      ]),
      const SizedBox(height: 14),

      _kart('💰 Aylık Net Prim & Komisyon', SizedBox(
        height: 200,
        child: LineChart(LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: veriFiltreli.asMap().entries.map((e) {
                final net = (e.value['netGelir'] as double?) ?? (e.value['gelir'] as double);
                return FlSpot(e.key.toDouble(), net / 1000);
              }).toList(),
              isCurved: true,
              color: Colors.orange.shade700,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.orange.shade700.withOpacity(.1)),
            ),
            LineChartBarData(
              spots: veriFiltreli.asMap().entries.map((e) {
                final net = (e.value['netKomisyon'] as double?) ?? ((e.value['komisyon'] as double?) ?? 0.0);
                return FlSpot(e.key.toDouble(), net / 1000);
              }).toList(),
              isCurved: true,
              color: Colors.purple.shade600,
              barWidth: 2,
              dashArray: [6, 3],
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= veriFiltreli.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(_ayAdlari[veriFiltreli[i]['ay'] as int], style: const TextStyle(fontSize: 9)));
                })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}K', style: const TextStyle(fontSize: 9)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData:   const FlGridData(drawVerticalLine: false),
        )),
      )),
      const SizedBox(height: 8),
      Row(children: [
        _lejant(Colors.orange.shade700, 'Prim (K₺)'),
        const SizedBox(width: 12),
        _lejant(Colors.purple.shade600, 'Komisyon (K₺)'),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // TAB 3: PORTFÖY
  // ══════════════════════════════════════════════════════════
  Widget _portfoyTab() {
    final td      = _turDagilimi;
    final tp      = _turPrim;
    final tk      = _turKomisyon;
    final te      = _turEmoji;
    if (td.isEmpty) return _bosEkran();

    final toplam  = td.values.fold(0, (s, v) => s + v);
    final sirali  = td.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final renkler = [
      Colors.blue.shade600,   Colors.green.shade600,  Colors.orange.shade600,
      Colors.purple.shade600, Colors.red.shade600,     Colors.teal.shade600,
      Colors.pink.shade600,   Colors.indigo.shade600,
    ];

    return ListView(padding: const EdgeInsets.all(14), children: [

      // ── Pasta grafik ──
      _kart('🥧 Sigorta Türü Dağılımı', SizedBox(
        height: 220,
        child: Row(children: [
          Expanded(
            child: PieChart(PieChartData(
              sections: sirali.asMap().entries.map((e) {
                final renk   = renkler[e.key % renkler.length];
                final yuzde  = toplam > 0 ? e.value.value / toplam * 100 : 0.0;
                return PieChartSectionData(
                  value: e.value.value.toDouble(),
                  color: renk,
                  title: '${yuzde.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  radius: 75,
                );
              }).toList(),
              centerSpaceRadius: 28,
            )),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sirali.asMap().entries.map((e) {
              final renk = renkler[e.key % renkler.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${te[e.value.key] ?? ''} ${e.value.key}: ${e.value.value}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),
        ]),
      )),
      const SizedBox(height: 14),

      // ── Türe göre detay kartları ──
      _kart('📋 Türe Göre Detay', Column(
        children: sirali.asMap().entries.map((e) {
          final renk     = renkler[e.key % renkler.length];
          final turAdi   = e.value.key;
          final adet     = e.value.value;
          final yuzde    = toplam > 0 ? adet / toplam : 0.0;
          final prim     = tp[turAdi]  ?? 0.0;
          final komis    = tk[turAdi]  ?? 0.0;
          final emoji    = te[turAdi]  ?? '📄';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: renk.withOpacity(.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: renk.withOpacity(.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Başlık satırı
              Row(children: [
                Text('$emoji $turAdi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: renk)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: renk.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$adet adet  %${(yuzde * 100).toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: yuzde,
                  minHeight: 6,
                  backgroundColor: renk.withOpacity(.12),
                  valueColor: AlwaysStoppedAnimation(renk),
                ),
              ),
              const SizedBox(height: 10),
              // Prim & Komisyon
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Toplam Prim',
                      style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
                  Text('₺${_fmt.format(prim)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.orange.shade700)),
                ])),
                Container(width: 1, height: 32, color: renk.withOpacity(.15)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text('Komisyon',
                      style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
                  Text('₺${_fmt.format(komis)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.purple.shade600)),
                ])),
                Container(width: 1, height: 32, color: renk.withOpacity(.15)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Ort. Prim',
                      style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
                  Text(adet > 0 ? '₺${_fmt.format(prim / adet)}' : '-',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.teal.shade600)),
                ])),
              ]),
            ]),
          );
        }).toList(),
      )),
      const SizedBox(height: 20),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // YARDIMCILAR
  // ══════════════════════════════════════════════════════════
  Widget _paraKart(String baslik, double tutar, Color renk, {String? alt}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: renk.withOpacity(.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: renk.withOpacity(.22)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(baslik, style: TextStyle(fontSize: 10.5, color: kTextSub, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('₺${_fmt.format(tutar)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: renk)),
      ),
      if (alt != null) ...[
        const SizedBox(height: 3),
        Text(alt, style: TextStyle(fontSize: 9, color: kTextSub, fontWeight: FontWeight.w500)),
      ],
    ]),
  );

  Widget _sayiKart(String baslik, int sayi, Color renk, String emoji) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    decoration: BoxDecoration(
      color: renk.withOpacity(.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: renk.withOpacity(.18)),
    ),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 2),
      Text('$sayi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: renk)),
      Text(baslik, style: TextStyle(fontSize: 8.5, color: kTextSub, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _kart(String baslik, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: kBgCard,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(baslik, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kText)),
      const SizedBox(height: 12),
      child,
    ]),
  );

  Widget _h(String t, {bool bold = false, Color? renk, int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: renk ?? kText)),
  );

  Widget _lejant(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(t, style: const TextStyle(fontSize: 11)),
  ]);
}
