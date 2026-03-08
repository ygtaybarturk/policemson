// lib/screens/analizler_screen.dart – v10 (ay seçici + doğru hesap)
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart' show goPoliceler;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
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

  final int _minYil = 2022;
  final int _maxYil = 2032;
  late int  _seciliYil;
  int?      _seciliAy;   // null = yıllık mod, 1-12 = aylık mod
  int?      _karsilastirYil;

  Map<String, dynamic> _veri  = {};
  Map<String, dynamic> _veri2 = {};
  bool _yukleniyor = true;
  int? _acikAy;

  static const _ayKisa = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
  static const _ayTam  = ['','Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
      'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];

  final _fmt  = NumberFormat('#,##0', 'tr');
  final _fmt2 = NumberFormat('#,##0.##', 'tr');

  final _renkler = [
    Colors.blue.shade600, Colors.green.shade600, Colors.orange.shade600,
    Colors.purple.shade600, Colors.red.shade600, Colors.teal.shade600,
    Colors.pink.shade600, Colors.indigo.shade600, Colors.brown.shade600,
  ];

  @override
  void initState() {
    super.initState();
    _seciliYil = DateTime.now().year;
    _tabCtrl   = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() { _yukleniyor = true; _acikAy = null; });
    try {
      final v1 = _seciliAy == null
          ? await _db.yillikOzet(_seciliYil)
          : await _db.aylikOzet(_seciliYil, _seciliAy!);
      Map<String, dynamic> v2 = {};
      if (_karsilastirYil != null && _seciliAy == null) {
        v2 = await _db.yillikOzet(_karsilastirYil!);
      }
      if (mounted) setState(() { _veri = v1; _veri2 = v2; _yukleniyor = false; });
    } catch (e) {
      if (mounted) setState(() { _veri = {}; _veri2 = {}; _yukleniyor = false; });
    }
  }

  double _g(Map m, String k, {double def = 0}) => (m[k] as num? ?? def).toDouble();
  int    _gi(Map m, String k, {int def = 0})   => (m[k] as num? ?? def).toInt();
  Map<String,int>    _turD(Map m) => (m['turDagilimi'] as Map<String,int>?)    ?? {};
  Map<String,double> _turP(Map m) => (m['turPrim']     as Map<String,double>?) ?? {};
  Map<String,double> _turK(Map m) => (m['turKomisyon'] as Map<String,double>?) ?? {};
  Map<String,String> _turE(Map m) => (m['turEmoji']    as Map<String,String>?) ?? {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => goPoliceler(),
          child: const Padding(padding: EdgeInsets.all(12),
              child: Icon(Icons.shield, color: kPrimary)),
        ),
        title: const Text('Analizler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Özet'), Tab(text: 'Üretim'), Tab(text: 'Portföy')],
        ),
      ),
      body: Column(children: [
        _filtrePaneli(),
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : _veri.isEmpty
                  ? _bosEkran()
                  : TabBarView(controller: _tabCtrl, children: [
                      _ozetTab(), _uretimTab(), _portfoyTab(),
                    ]),
        ),
      ]),
    );
  }

  // ── Filtre paneli ─────────────────────────────────────────
  Widget _filtrePaneli() {
    return Container(
      color: kBgCard,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Yıl
        Row(children: [
          const Text('Yıl:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: List.generate(_maxYil - _minYil + 1, (i) {
              final y = _minYil + i;
              return Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() { _seciliYil = y; _seciliAy = null;
                    if (_karsilastirYil == y) _karsilastirYil = null; }); _yukle(); },
                  child: _pill('$y', y == _seciliYil, kPrimary),
                ));
            })),
          )),
        ]),
        const SizedBox(height: 8),
        // Ay
        Row(children: [
          const Text('Ay:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _seciliAy = null); _yukle(); },
                  child: _pill('Tümü', _seciliAy == null, Colors.grey.shade600),
                )),
              ...List.generate(12, (i) {
                final ay = i + 1;
                return Padding(padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () { setState(() { _seciliAy = ay; _karsilastirYil = null; }); _yukle(); },
                    child: _pill(_ayKisa[ay], _seciliAy == ay, kPrimary),
                  ));
              }),
            ]),
          )),
        ]),
        // Karşılaştır — sadece yıllık mod
        if (_seciliAy == null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Karşılaştır:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: kTextSub)),
            const SizedBox(width: 8),
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () { setState(() => _karsilastirYil = null); _yukle(); },
                    child: _pill('Yok', _karsilastirYil == null, Colors.grey.shade600),
                  )),
                ...List.generate(_maxYil - _minYil + 1, (i) {
                  final y = _minYil + i;
                  if (y == _seciliYil) return const SizedBox();
                  final sec = y == _karsilastirYil;
                  return Padding(padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () { setState(() => _karsilastirYil = sec ? null : y); _yukle(); },
                      child: _pill('$y', sec, Colors.orange.shade600),
                    ));
                }),
              ]),
            )),
          ]),
        ],
      ]),
    );
  }

  Widget _pill(String label, bool sec, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: sec ? renk : kBg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: sec ? renk : kBorder),
    ),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: sec ? Colors.white : kText)),
  );

  // ══════════════════════════════════════════════════════════
  // TAB 1 — ÖZET
  // ══════════════════════════════════════════════════════════
  Widget _ozetTab() {
    final baslik   = _seciliAy == null ? '$_seciliYil Yılı Özeti' : '${_ayTam[_seciliAy!]} $_seciliYil';
    final toplam   = _gi(_veri, 'toplam');
    final netGelir = _g(_veri, 'netGelir');
    final netKomis = _g(_veri, 'netKomisyon');
    final gelir    = _g(_veri, 'gelir');
    final komis    = _g(_veri, 'komisyon');
    final zArti    = _g(_veri, 'zeyilArti');
    final zEksi    = _g(_veri, 'zeyilEksi');
    final zArtiKom = _g(_veri, 'zeyilArtiKom');
    final zEksiKom = _g(_veri, 'zeyilEksiKom');
    final zeyilVar = zArti != 0 || zEksi != 0;
    final aylikVeri = _seciliAy == null
        ? ((_veri['aylikVeri'] as List<Map<String,dynamic>>?) ?? [])
        : <Map<String,dynamic>>[];
    final karVar    = _karsilastirYil != null && _veri2.isNotEmpty && _seciliAy == null;

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Başlık bandı
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(_seciliAy == null ? Icons.calendar_today_rounded : Icons.calendar_month_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          if (karVar) ...[
            const SizedBox(width: 10),
            const Text('vs', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.shade600, borderRadius: BorderRadius.circular(8)),
              child: Text('$_karsilastirYil',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),

      if (karVar) _karsilastirmaKart(
        yil1: _seciliYil, yil2: _karsilastirYil!,
        toplam1: toplam, toplam2: _gi(_veri2, 'toplam'),
        gelir1: netGelir, gelir2: _g(_veri2, 'netGelir'),
        komis1: netKomis, komis2: _g(_veri2, 'netKomisyon'),
      ),

      if (!karVar) ...[
        Row(children: [
          Expanded(child: _paraKart('💰 Net Prim', netGelir, Colors.orange,
              alt: zeyilVar ? 'Poliçe: ₺${_fmt2.format(gelir)}' : null)),
          const SizedBox(width: 10),
          Expanded(child: _paraKart('📈 Net Komisyon', netKomis, Colors.purple,
              alt: zeyilVar ? 'Poliçe: ₺${_fmt2.format(komis)}' : null)),
        ]),
        const SizedBox(height: 10),
        if (zeyilVar) _kart('🔄 Zeyil Özeti', _zeyilOzetWidget(
          zArti: zArti, zEksi: zEksi, zArtiKom: zArtiKom, zEksiKom: zEksiKom,
          zArtiAdet: _gi(_veri, 'zeyilArtiAdet'), zEksiAdet: _gi(_veri, 'zeyilEksiAdet'),
        )),
        Row(children: [
          Expanded(child: _sayiKart('Toplam', toplam, Colors.blue, '📋')),
          const SizedBox(width: 6),
          Expanded(child: _sayiKart('Yapılan', _gi(_veri,'yapildi'), Colors.green, '✅')),
          const SizedBox(width: 6),
          Expanded(child: _sayiKart('Yapılamayan', _gi(_veri,'yapilamadi'), Colors.red, '❌')),
          const SizedBox(width: 6),
          Expanded(child: _sayiKart('Bekleyen',
              _gi(_veri,'beklemede') + _gi(_veri,'dahaSonra'), Colors.blueGrey, '⏳')),
        ]),
        const SizedBox(height: 14),
      ],

      // Ay modunda tür dağılımı burada da göster
      if (_seciliAy != null) ...[
        _kart('🗂 Sigorta Türü Dağılımı',
            _turDagilimWidget(_turD(_veri), _turP(_veri), _turK(_veri), _turE(_veri))),
      ],

      // Yıllık modda aylık tablo
      if (_seciliAy == null && aylikVeri.isNotEmpty)
        _kart('📅 Aylık Detay  (aya tıkla → detay)', _aylikTabloWidget(aylikVeri)),

      const SizedBox(height: 20),
    ]);
  }

  // ── Tür dağılımı kartları ─────────────────────────────────
  Widget _turDagilimWidget(
    Map<String,int> td, Map<String,double> tp,
    Map<String,double> tk, Map<String,String> te,
  ) {
    if (td.isEmpty) return const Text('Veri yok', style: TextStyle(color: kTextSub));
    final sirali = td.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final toplam = td.values.fold(0, (s,v) => s+v);
    return Column(children: sirali.asMap().entries.map((e) {
      final renk  = _renkler[e.key % _renkler.length];
      final tur   = e.value.key;
      final adet  = e.value.value;
      final prim  = tp[tur] ?? 0.0;
      final komis = tk[tur] ?? 0.0;
      final emoji = te[tur] ?? '📄';
      final yuzde = toplam > 0 ? adet / toplam : 0.0;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: renk.withOpacity(.05), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: renk.withOpacity(.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('$emoji $tur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: renk)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: renk.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$adet adet  %${(yuzde*100).toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: yuzde, minHeight: 6,
                backgroundColor: renk.withOpacity(.12),
                valueColor: AlwaysStoppedAnimation(renk))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Toplam Prim', style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
              Text('₺${_fmt.format(prim)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orange.shade700)),
            ])),
            Container(width: 1, height: 32, color: renk.withOpacity(.15)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('Komisyon', style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
              Text('₺${_fmt.format(komis)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.purple.shade600)),
            ])),
            Container(width: 1, height: 32, color: renk.withOpacity(.15)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Ort. Prim', style: TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
              Text(adet > 0 ? '₺${_fmt.format(prim / adet)}' : '-',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.teal.shade600)),
            ])),
          ]),
        ]),
      );
    }).toList());
  }

  // ── Aylık tablo ───────────────────────────────────────────
  Widget _aylikTabloWidget(List<Map<String,dynamic>> aylikVeri) {
    if (aylikVeri.isEmpty) return const Text('Veri yok', style: TextStyle(color: kTextSub));
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(color: kPrimary.withOpacity(.07), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          _hdr('Ay', flex: 1, bold: true),
          _hdr('Adet', flex: 1, bold: true),
          _hdr('Prim', flex: 3, bold: true, renk: Colors.orange.shade700),
          _hdr('Komisyon', flex: 3, bold: true, renk: Colors.purple.shade700),
          const SizedBox(width: 20),
        ]),
      ),
      ...aylikVeri.map((r) => _aylikSatirWidget(r)),
      const Divider(height: 12),
      _toplamSatirWidget(aylikVeri),
    ]);
  }

  Widget _aylikSatirWidget(Map<String,dynamic> r) {
    final ay        = r['ay'] as int;
    final top       = r['toplam'] as int;
    final gelir     = (r['netGelir']    as double?) ?? (r['gelir']    as double? ?? 0.0);
    final komis     = (r['netKomisyon'] as double?) ?? (r['komisyon'] as double? ?? 0.0);
    final zArti     = (r['zeyilArti']   as double?) ?? 0.0;
    final zEksi     = (r['zeyilEksi']   as double?) ?? 0.0;
    final zArtiAdet = (r['zeyilArtiAdet'] as int?) ?? 0;
    final zEksiAdet = (r['zeyilEksiAdet'] as int?) ?? 0;
    final zeyilVar  = zArti != 0 || zEksi != 0;
    final turD      = (r['turDagilimi'] as Map<String,int>?)    ?? {};
    final turP      = (r['turPrim']     as Map<String,double>?) ?? {};
    final turK      = (r['turKomisyon'] as Map<String,double>?) ?? {};
    final turE      = (r['turEmoji']    as Map<String,String>?) ?? {};
    final acik      = _acikAy == ay;

    if (top == 0 && !zeyilVar) return const SizedBox();

    return Column(children: [
      InkWell(
        onTap: () => setState(() => _acikAy = acik ? null : ay),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: acik ? kPrimary.withOpacity(.05) : null,
            border: Border(bottom: BorderSide(color: acik ? kPrimary.withOpacity(.2) : kDivider)),
          ),
          child: Row(children: [
            // Ay adına tıklayınca o aya geç
            Expanded(flex: 1, child: GestureDetector(
              onTap: () { setState(() { _seciliAy = ay; _karsilastirYil = null; }); _yukle(); },
              child: Text(_ayKisa[ay], textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: kPrimary, decoration: TextDecoration.underline)),
            )),
            _hdr('$top', flex: 1),
            _hdr(gelir > 0 ? '₺${_fmt.format(gelir)}' : '-', flex: 3, renk: Colors.orange.shade700),
            _hdr(komis > 0 ? '₺${_fmt.format(komis)}' : '-', flex: 3, renk: Colors.purple.shade700),
            Icon(acik ? Icons.expand_less : Icons.expand_more, size: 16, color: kTextSub),
          ]),
        ),
      ),
      if (acik) Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_ayTam[ay], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: () { setState(() { _seciliAy = ay; _karsilastirYil = null; }); _yukle(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: kPrimary.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Ay detayı →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (turD.isNotEmpty) ...[
            const Text('🗂 Sigorta Türleri',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextSub)),
            const SizedBox(height: 6),
            ...() {
              final sirali = turD.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
              return sirali.asMap().entries.map((e) {
                final renk   = _renkler[e.key % _renkler.length];
                final tur    = e.value.key;
                final adet   = e.value.value;
                final prim   = turP[tur] ?? 0.0;
                final komis2 = turK[tur] ?? 0.0;
                final emoji  = turE[tur] ?? '📄';
                return Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$emoji $tur',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: renk))),
                    Text('$adet adet',
                        style: const TextStyle(fontSize: 10, color: kTextSub, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('₺${_fmt.format(prim)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.orange.shade700)),
                    if (komis2 > 0) ...[
                      const SizedBox(width: 6),
                      Text('₺${_fmt.format(komis2)}',
                          style: TextStyle(fontSize: 10, color: Colors.purple.shade500, fontWeight: FontWeight.w600)),
                    ],
                  ]));
              });
            }(),
          ],
          if (zeyilVar) ...[
            const Divider(height: 16),
            const Text('🔄 Zeyil Detayı',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextSub)),
            const SizedBox(height: 8),
            if (zArti > 0) _zeyilDetaySatir(Icons.add_circle_outline, Colors.green.shade700,
                'Prim Zeyil+', zArtiAdet, zArti, (r['zeyilArtiKom'] as double?) ?? 0),
            if (zEksi > 0) ...[
              const SizedBox(height: 6),
              _zeyilDetaySatir(Icons.remove_circle_outline, Colors.red.shade600,
                  'İptal Zeyil-', zEksiAdet, zEksi, (r['zeyilEksiKom'] as double?) ?? 0),
            ],
            const SizedBox(height: 6),
            Row(children: [
              const Text('Net Zeyil: ',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kTextSub)),
              Text('₺${_fmt.format(zArti - zEksi)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                      color: (zArti - zEksi) >= 0 ? Colors.green.shade700 : Colors.red.shade600)),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _toplamSatirWidget(List<Map<String,dynamic>> aylikVeri) {
    final topToplam = aylikVeri.fold<int>(0, (s,r) => s + (r['toplam'] as int));
    final topGelir  = aylikVeri.fold<double>(0, (s,r) =>
        s + ((r['netGelir'] as double?) ?? (r['gelir'] as double? ?? 0)));
    final topKomis  = aylikVeri.fold<double>(0, (s,r) =>
        s + ((r['netKomisyon'] as double?) ?? (r['komisyon'] as double? ?? 0)));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(.05), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kPrimary.withOpacity(.12)),
      ),
      child: Row(children: [
        _hdr('TOPLAM', flex: 1, bold: true),
        _hdr('$topToplam', flex: 1, bold: true),
        _hdr('₺${_fmt.format(topGelir)}', flex: 3, bold: true, renk: Colors.orange.shade700),
        _hdr('₺${_fmt.format(topKomis)}', flex: 3, bold: true, renk: Colors.purple.shade700),
        const SizedBox(width: 20),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════
  // TAB 2 — ÜRETİM
  // ══════════════════════════════════════════════════════════
  Widget _uretimTab() {
    if (_seciliAy != null) {
      return ListView(padding: const EdgeInsets.all(14), children: [
        _kart('📊 ${_ayTam[_seciliAy!]} — Sigorta Türü Dağılımı',
            _turDagilimWidget(_turD(_veri), _turP(_veri), _turK(_veri), _turE(_veri))),
        const SizedBox(height: 20),
      ]);
    }
    final aylikVeri = ((_veri['aylikVeri'] as List<Map<String,dynamic>>?) ?? []);
    final vf = aylikVeri.where((r) => (r['toplam'] as int) > 0).toList();
    if (vf.isEmpty) return _bosEkran();
    final karVar  = _karsilastirYil != null && _veri2.isNotEmpty;
    final aylik2  = karVar ? ((_veri2['aylikVeri'] as List<Map<String,dynamic>>?) ?? []) : <Map<String,dynamic>>[];

    return ListView(padding: const EdgeInsets.all(14), children: [
      _kart('📊 Aylık Poliçe Üretimi', SizedBox(height: 220,
        child: BarChart(BarChartData(
          barGroups: List.generate(12, (i) {
            final ay = i + 1;
            final r  = vf.firstWhere((e) => e['ay'] == ay,
                orElse: () => {'toplam':0,'yapildi':0,'yapilamadi':0,'ay':ay});
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: (r['yapildi']    as int? ?? 0).toDouble(),
                  color: Colors.green.shade600, width: 10, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: (r['yapilamadi'] as int? ?? 0).toDouble(),
                  color: Colors.red.shade400, width: 10, borderRadius: BorderRadius.circular(3)),
            ]);
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v,_) => Padding(padding: const EdgeInsets.only(top:4),
                    child: Text(_ayKisa[v.toInt()+1], style: const TextStyle(fontSize:8))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
                getTitlesWidget: (v,_) => Text('${v.toInt()}', style: const TextStyle(fontSize:9)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(drawVerticalLine: false),
        )),
      )),
      Row(children: [_lejant(Colors.green.shade600, 'Yapılan'), const SizedBox(width: 12),
          _lejant(Colors.red.shade400, 'Yapılamayan')]),
      const SizedBox(height: 14),
      _kart('💰 Aylık Net Prim${karVar ? ' — $_seciliYil vs $_karsilastirYil' : ''}',
        SizedBox(height: 200, child: LineChart(LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(12, (i) {
                final ay = i + 1;
                final r  = vf.firstWhere((e) => e['ay'] == ay, orElse: () => {'netGelir':0.0,'ay':ay});
                return FlSpot(i.toDouble(), ((r['netGelir'] as double?) ?? 0) / 1000);
              }),
              isCurved: true, color: Colors.orange.shade700, barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.orange.shade700.withOpacity(.08)),
            ),
            if (karVar) LineChartBarData(
              spots: List.generate(12, (i) {
                final ay = i + 1;
                final r  = aylik2.firstWhere((e) => e['ay'] == ay, orElse: () => {'netGelir':0.0,'ay':ay});
                return FlSpot(i.toDouble(), ((r['netGelir'] as double?) ?? 0) / 1000);
              }),
              isCurved: true, color: Colors.orange.shade300, barWidth: 2,
              dashArray: [5,3], dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                getTitlesWidget: (v,_) => Padding(padding: const EdgeInsets.only(top:4),
                    child: Text(_ayKisa[v.toInt()+1], style: const TextStyle(fontSize:8))))),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v,_) => Text('${v.toStringAsFixed(0)}K', style: const TextStyle(fontSize:9)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
        ))),
      ),
      Row(children: [
        _lejant(Colors.orange.shade700, '$_seciliYil Prim (K₺)'),
        if (karVar) ...[const SizedBox(width: 12), _lejant(Colors.orange.shade300, '$_karsilastirYil Prim (K₺)')],
      ]),
      const SizedBox(height: 20),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // TAB 3 — PORTFÖY
  // ══════════════════════════════════════════════════════════
  Widget _portfoyTab() {
    final td = _turD(_veri); final tp = _turP(_veri);
    final tk = _turK(_veri); final te = _turE(_veri);
    if (td.isEmpty) return _bosEkran();
    final toplam = td.values.fold(0, (s,v) => s+v);
    final sirali = td.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final karVar = _karsilastirYil != null && _veri2.isNotEmpty && _seciliAy == null;
    final td2    = karVar ? _turD(_veri2) : <String,int>{};
    final baslik = _seciliAy == null
        ? '$_seciliYil — Türe Göre Toplam Adet'
        : '${_ayTam[_seciliAy!]} $_seciliYil — Türe Göre Adet';

    return ListView(padding: const EdgeInsets.all(14), children: [
      _kart('📋 $baslik', _turDagilimWidget(td, tp, tk, te)),
      _kart('🥧 Sigorta Türü Dağılımı', SizedBox(height: 220,
        child: Row(children: [
          Expanded(child: PieChart(PieChartData(
            sections: sirali.asMap().entries.map((e) {
              final renk  = _renkler[e.key % _renkler.length];
              final yuzde = toplam > 0 ? e.value.value / toplam * 100 : 0.0;
              return PieChartSectionData(value: e.value.value.toDouble(), color: renk,
                title: '${yuzde.toStringAsFixed(0)}%',
                titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                radius: 75);
            }).toList(),
            centerSpaceRadius: 28,
          ))),
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
            children: sirali.asMap().entries.map((e) {
              final renk = _renkler[e.key % _renkler.length];
              return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('${te[e.value.key] ?? ''} ${e.value.key}: ${e.value.value}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                  if (karVar && td2.containsKey(e.value.key)) ...[
                    const SizedBox(width: 4),
                    Text('(${td2[e.value.key]})',
                        style: TextStyle(fontSize: 9, color: Colors.orange.shade600)),
                  ],
                ]));
            }).toList()),
        ]),
      )),
      const SizedBox(height: 20),
    ]);
  }

  // ── Yardımcı widgetlar ────────────────────────────────────
  Widget _karsilastirmaKart({
    required int yil1, required int yil2,
    required int toplam1, required int toplam2,
    required double gelir1, required double gelir2,
    required double komis1, required double komis2,
  }) {
    Widget satir(String baslik, String v1, String v2, Color renk) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(v1, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: renk))),
        Expanded(flex: 2, child: Text(baslik, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub))),
        Expanded(child: Text(v2, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: renk.withOpacity(.6)))),
      ]));
    final gf = gelir1 - gelir2;
    final kf = komis1 - komis2;
    return _kart('📊 $yil1 vs $yil2 Karşılaştırma', Column(children: [
      Row(children: [
        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: kPrimary.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
          child: Text('$yil1', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: kPrimary)))),
        const Expanded(flex: 2, child: SizedBox()),
        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
          child: Text('$yil2', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.orange.shade700)))),
      ]),
      const SizedBox(height: 8),
      satir('Toplam Poliçe', '$toplam1', '$toplam2', Colors.blue),
      satir('Net Prim', '₺${_fmt.format(gelir1)}', '₺${_fmt.format(gelir2)}', Colors.orange.shade700),
      satir('Net Komisyon', '₺${_fmt.format(komis1)}', '₺${_fmt.format(komis2)}', Colors.purple),
      const Divider(height: 16),
      Row(children: [
        Expanded(child: Column(children: [
          Text('Prim Farkı', style: TextStyle(fontSize: 10, color: kTextSub)),
          Text('₺${_fmt.format(gf.abs())}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
              color: gf >= 0 ? Colors.green : Colors.red)),
          Text(gf >= 0 ? '▲ Artış' : '▼ Azalış', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: gf >= 0 ? Colors.green : Colors.red)),
        ])),
        Expanded(child: Column(children: [
          Text('Kom. Farkı', style: TextStyle(fontSize: 10, color: kTextSub)),
          Text('₺${_fmt.format(kf.abs())}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
              color: kf >= 0 ? Colors.green : Colors.red)),
          Text(kf >= 0 ? '▲ Artış' : '▼ Azalış', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: kf >= 0 ? Colors.green : Colors.red)),
        ])),
        Expanded(child: Column(children: [
          Text('Poliçe Farkı', style: TextStyle(fontSize: 10, color: kTextSub)),
          Text('${(toplam1 - toplam2).abs()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
              color: toplam1 >= toplam2 ? Colors.green : Colors.red)),
          Text(toplam1 >= toplam2 ? '▲ Artış' : '▼ Azalış', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: toplam1 >= toplam2 ? Colors.green : Colors.red)),
        ])),
      ]),
    ]));
  }

  Widget _zeyilOzetWidget({
    required double zArti, required double zEksi,
    required double zArtiKom, required double zEksiKom,
    required int zArtiAdet, required int zEksiAdet,
  }) {
    Widget satir(IconData ikon, Color renk, String baslik, int adet, double tutar, double komis) =>
      Row(children: [
        Icon(ikon, color: renk, size: 18), const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk)),
          Text('$adet adet', style: const TextStyle(fontSize: 10, color: kTextSub)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₺${_fmt2.format(tutar)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: renk)),
          Text('Kom: ₺${_fmt2.format(komis)}',
              style: TextStyle(fontSize: 9.5, color: Colors.purple.shade500, fontWeight: FontWeight.w600)),
        ]),
      ]);
    return Column(children: [
      satir(Icons.add_circle_outline, Colors.green.shade700, 'Prim Zeyil+ (Ekleme)', zArtiAdet, zArti, zArtiKom),
      const SizedBox(height: 10),
      satir(Icons.remove_circle_outline, Colors.red.shade600, 'İptal Zeyil- (Düşme)', zEksiAdet, zEksi, zEksiKom),
      const Divider(height: 16),
      Row(children: [
        const Text('Net Zeyil Etkisi',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSub)),
        const Spacer(),
        Text('₺${_fmt2.format(zArti - zEksi)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: (zArti - zEksi) >= 0 ? Colors.green.shade700 : Colors.red.shade600)),
      ]),
    ]);
  }

  Widget _zeyilDetaySatir(IconData ikon, Color renk, String baslik, int adet, double tutar, double komis) =>
    Row(children: [
      Icon(ikon, color: renk, size: 14), const SizedBox(width: 5),
      Expanded(child: Text('$baslik  ($adet adet)',
          style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w700))),
      Text('₺${_fmt.format(tutar)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: renk)),
      if (komis > 0) ...[
        const SizedBox(width: 6),
        Text('Kom: ₺${_fmt.format(komis)}',
            style: TextStyle(fontSize: 9.5, color: Colors.purple.shade500, fontWeight: FontWeight.w600)),
      ],
    ]);

  Widget _bosEkran() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.bar_chart_rounded, size: 56, color: kTextSub.withOpacity(.3)),
    const SizedBox(height: 12),
    Text('Bu dönem için poliçe bulunamadı', style: TextStyle(color: kTextSub, fontSize: 14)),
    const SizedBox(height: 8),
    Text('Farklı bir ay/yıl seçin', style: TextStyle(color: kTextSub.withOpacity(.6), fontSize: 12)),
  ]));

  Widget _paraKart(String baslik, double tutar, Color renk, {String? alt}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: renk.withOpacity(.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: renk.withOpacity(.22)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(baslik, style: TextStyle(fontSize: 10.5, color: kTextSub, fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text('₺${_fmt.format(tutar)}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: renk))),
      if (alt != null) ...[const SizedBox(height: 3),
        Text(alt, style: TextStyle(fontSize: 9, color: kTextSub))],
    ]),
  );

  Widget _sayiKart(String baslik, int sayi, Color renk, String emoji) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    decoration: BoxDecoration(
      color: renk.withOpacity(.07), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: renk.withOpacity(.18)),
    ),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 15)), const SizedBox(height: 2),
      Text('$sayi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: renk)),
      Text(baslik, style: TextStyle(fontSize: 8.5, color: kTextSub, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    ]),
  );

  Widget _kart(String baslik, Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: kBgCard, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0,2))],
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(baslik, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kText)),
      const SizedBox(height: 12),
      child,
    ]),
  );

  Widget _hdr(String t, {bool bold = false, Color? renk, int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, textAlign: TextAlign.center,
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
