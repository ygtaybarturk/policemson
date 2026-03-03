// lib/screens/policeler_screen.dart – M3 Redesign
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart' show ThemeNotifier;
import 'package:intl/intl.dart';
import 'excel_import_screen.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'police_detay_screen.dart';
import 'police_form_screen.dart';
import 'takvim_screen.dart';

// Renkler context.bgCard, context.textMain vb. ile alınır (app_colors.dart)
const _kPrimary = Color(0xFF1565C0);

class PolicelerScreen extends StatefulWidget {
  const PolicelerScreen({super.key});
  @override State<PolicelerScreen> createState() => _PolicelerScreenState();
}

class _PolicelerScreenState extends State<PolicelerScreen>
    with SingleTickerProviderStateMixin {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  int  _yil   = DateTime.now().year;
  int  _ay    = DateTime.now().month;
  int  _tabIdx = 0;
  List<Police> _liste   = [];
  bool         _yukl    = true;
  Map<int,int> _sayilar = {};

  bool _aramaAcik = false;
  final _aramaCtrl = TextEditingController();
  List<Police> _aramaListesi = [];
  bool _aramaYukl = false;

  final _filtreler = [
    ('Tümü',       null),
    ('Bekleyen',   PoliceStatus.beklemede),
    ('Yapıldı',    PoliceStatus.yapildi),
    ('Yapılamadı', PoliceStatus.yapilamadi),
    ('Daha Sonra', PoliceStatus.dahaSonra),
  ];

  static const _aylar = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];

  @override
  void initState() {
    super.initState();
    _yukle();
    _aramaCtrl.addListener(_aramaYap);
  }

  @override
  void dispose() {
    _aramaCtrl.removeListener(_aramaYap);
    _aramaCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukl = true);
    final filtre = _filtreler[_tabIdx].$2;
    final results = await Future.wait([
      _db.aylik(_yil, _ay, filtre: filtre),
      _db.aylikSayilar(_yil),
    ]);
    setState(() {
      _liste   = results[0] as List<Police>;
      _sayilar = results[1] as Map<int,int>;
      _yukl    = false;
    });
  }

  void _oncekiAy() { setState(() { if (_ay==1){_ay=12;_yil--;}else _ay--; }); _yukle(); }
  void _sonrakiAy() { setState(() { if (_ay==12){_ay=1;_yil++;}else _ay++; }); _yukle(); }

  Future<void> _aramaYap() async {
    final q = _aramaCtrl.text.trim();
    if (q.isEmpty) { setState(() { _aramaListesi=[]; _aramaYukl=false; }); return; }
    setState(() => _aramaYukl = true);
    final r = await _db.adSoyadAra(q, _yil);
    setState(() { _aramaListesi = r; _aramaYukl = false; });
  }

  void _fabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FabSheet(
        onTekEkle: () { Navigator.pop(context); _yeniPoliceAc(); },
        onExcel: () { Navigator.pop(context); _excelImport(); },
      ),
    );
  }

  Future<void> _yeniPoliceAc() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PoliceFormScreen()));
    if (ok == true) _yukle();
  }

  Future<void> _excelImport() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ExcelImportScreen()));
    if (ok == true) _yukle();
  }

  Future<void> _dahaSonraTakvim(Police p) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TakvimScreen(
        policeId: p.id,
        onHatirlaticiSec: (tarih, not, guncellenmis) async {
          await _notif.policeIcinIptal(p.id!);
          await _notif.dahaSonraHatirlatici(guncellenmis);
          _yukle();
        },
      ),
    ));
    _yukle();
  }

  Future<void> _durumDegistir(Police p, PoliceStatus d) async {
    if (d == PoliceStatus.dahaSonra) { _dahaSonraTakvim(p); return; }
    await _db.durumGuncelle(p.id!, d);
    if (d != PoliceStatus.beklemede) await _notif.policeIcinIptal(p.id!);
    _yukle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(d == PoliceStatus.yapildi ? '✅ Yapıldı olarak işaretlendi' : '❌ Yapılamadı olarak işaretlendi'),
      backgroundColor: d == PoliceStatus.yapildi ? Colors.green.shade600 : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.bgCard,
        title: _aramaAcik
            ? TextField(
                controller: _aramaCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ad, soyad ara...',
                  border: InputBorder.none,
                  filled: false,
                  hintStyle: TextStyle(color: context.textSub, fontSize: 16),
                ),
                style: TextStyle(fontSize: 16, color: context.textMain),
              )
            : RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.textMain),
                  children: [
                    TextSpan(text: 'Poli'),
                    TextSpan(text: 'çem', style: TextStyle(color: _kPrimary)),
                  ],
                ),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.border),
        ),
        actions: [
          if (_aramaAcik)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() { _aramaAcik = false; _aramaCtrl.clear(); _aramaListesi = []; });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              color: _kPrimary,
              onPressed: () => setState(() => _aramaAcik = true),
            ),
        ],
      ),
      body: _aramaAcik ? _aramaEkrani() : _anaEkran(),
      floatingActionButton: _aramaAcik ? null : FloatingActionButton(
        onPressed: _fabMenu,
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // ── Ana ekran ───────────────────────────────────────────
  Widget _anaEkran() {
    return Column(children: [
      // Ay navigasyon
      Container(
        color: context.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _ArrBtn(icon: Icons.chevron_left, onTap: _oncekiAy),
          Expanded(
            child: Text(
              '${_aylar[_ay]} $_yil',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textMain),
            ),
          ),
          _ArrBtn(icon: Icons.chevron_right, onTap: _sonrakiAy),
        ]),
      ),
      // Ay chip listesi
      Container(
        color: context.bgCard,
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 12,
            itemBuilder: (_, i) {
              final m = i + 1;
              final on = m == _ay;
              final sayi = _sayilar[m] ?? 0;
              return GestureDetector(
                onTap: () { setState(() => _ay = m); _yukle(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? _kPrimary : context.bgSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _aylar[m],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : context.textSub,
                      ),
                    ),
                    if (sayi > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: on ? Colors.white.withOpacity(0.25) : const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$sayi',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: on ? Colors.white : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
      ),
      // Filtre tabları
      Container(
        color: context.bgScaffold,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _filtreler.length,
            itemBuilder: (_, i) {
              final on = i == _tabIdx;
              return GestureDetector(
                onTap: () { setState(() => _tabIdx = i); _yukle(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? context.primaryContainer : context.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: on ? _kPrimary : context.border,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _filtreler[i].$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on ? _kPrimary : context.textSub,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // Liste
      Expanded(
        child: _yukl
            ? const Center(child: CircularProgressIndicator())
            : _liste.isEmpty
                ? _bosEkran()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                    itemCount: _liste.length,
                    itemBuilder: (_, i) => _PoliceKarti(
                      police: _liste[i],
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PoliceDetayScreen(policeId: _liste[i].id!),
                        ));
                        _yukle();
                      },
                      onBilgiler: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PoliceDetayScreen(policeId: _liste[i].id!),
                        ));
                        _yukle();
                      },
                      onYapildi:    () => _durumDegistir(_liste[i], PoliceStatus.yapildi),
                      onYapilamadi: () => _durumDegistir(_liste[i], PoliceStatus.yapilamadi),
                      onDahaSonra:  () => _durumDegistir(_liste[i], PoliceStatus.dahaSonra),
                    ),
                  ),
      ),
    ]);
  }

  Widget _bosEkran() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: context.bgSurface, borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.description_outlined, size: 40, color: Color(0xFF9AAAC0)),
      ),
      const SizedBox(height: 16),
      Text('Bu ay için poliçe yok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.textSub)),
      const SizedBox(height: 6),
      Text('+ butonuyla poliçe ekleyebilirsiniz', style: TextStyle(fontSize: 12, color: context.textSub)),
    ]),
  );

  // ── Arama ekranı ─────────────────────────────────────────
  Widget _aramaEkrani() {
    if (_aramaCtrl.text.trim().isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search, size: 48, color: context.textSub.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('Ad veya soyad yazın', style: TextStyle(color: context.textSub, fontSize: 14)),
        ]),
      );
    }
    if (_aramaYukl) return const Center(child: CircularProgressIndicator());
    if (_aramaListesi.isEmpty) return Center(
      child: Text('Sonuç bulunamadı', style: TextStyle(color: context.textSub, fontSize: 14)),
    );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _aramaListesi.length,
      itemBuilder: (_, i) => _PoliceKarti(
        police: _aramaListesi[i],
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => PoliceDetayScreen(policeId: _aramaListesi[i].id!),
          ));
          _aramaYap();
        },
        onBilgiler: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => PoliceDetayScreen(policeId: _aramaListesi[i].id!),
          ));
          _aramaYap();
        },
        onYapildi:    () => _durumDegistir(_aramaListesi[i], PoliceStatus.yapildi),
        onYapilamadi: () => _durumDegistir(_aramaListesi[i], PoliceStatus.yapilamadi),
        onDahaSonra:  () => _durumDegistir(_aramaListesi[i], PoliceStatus.dahaSonra),
      ),
    );
  }
}

// ── Ok butonu ─────────────────────────────────────────────
class _ArrBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: context.border, width: 1.5),
        borderRadius: BorderRadius.circular(50),
        color: context.bgCard,
      ),
      child: Icon(icon, size: 18, color: _kPrimary),
    ),
  );
}

// ── FAB Menü ──────────────────────────────────────────────
class _FabSheet extends StatelessWidget {
  final VoidCallback onTekEkle, onExcel;
  const _FabSheet({required this.onTekEkle, required this.onExcel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(28)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        _MenuTile(
          icon: Icons.post_add_outlined,
          bg: const Color(0xFFE3F0FF), iconColor: _kPrimary,
          title: 'Tek Poliçe Ekle',
          sub: 'Formu doldur, poliçe oluştur',
          onTap: onTekEkle,
        ),
        const SizedBox(height: 10),
        _MenuTile(
          icon: Icons.table_chart_outlined,
          bg: const Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32),
          title: 'Excel\'den Toplu Aktar',
          sub: 'Üretim listesini yükle, otomatik ekle',
          onTap: onExcel,
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}


class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color bg, iconColor;
  final String title, sub;
  final VoidCallback onTap;
  const _MenuTile({required this.icon,required this.bg,required this.iconColor,
    required this.title,required this.sub,required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: context.bgScaffold,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.textMain)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11.5, color: context.textSub)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 13, color: context.textSub),
        ]),
      ),
    ),
  );
}

// Poliçe Kartı – M3 Gradyan Tasarım
// ══════════════════════════════════════════════════════════

class _PoliceKarti extends StatelessWidget {
  final Police police;
  final VoidCallback onTap, onYapildi, onYapilamadi, onDahaSonra, onBilgiler;
  const _PoliceKarti({required this.police, required this.onTap,
    required this.onYapildi, required this.onYapilamadi,
    required this.onDahaSonra, required this.onBilgiler});

  static LinearGradient _gradient(PoliceType t) {
    final colors = switch (t) {
      PoliceType.trafik            => [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
      PoliceType.kasko             => [const Color(0xFF283593), const Color(0xFF3949AB)],
      PoliceType.dask              => [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
      PoliceType.konut             => [const Color(0xFF880E4F), const Color(0xFFC2185B)],
      PoliceType.ozelSaglik        => [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
      PoliceType.tamamlayiciSaglik => [const Color(0xFF880E4F), const Color(0xFFE91E63)],
      PoliceType.hayat             => [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
      PoliceType.ferdiKaza         => [const Color(0xFFE65100), const Color(0xFFF57C00)],
      PoliceType.isyeri            => [const Color(0xFF004D40), const Color(0xFF00897B)],
      PoliceType.nakliyat          => [const Color(0xFF006064), const Color(0xFF0097A7)],
      PoliceType.tarim             => [const Color(0xFF33691E), const Color(0xFF558B2F)],
      PoliceType.seyahat           => [const Color(0xFF01579B), const Color(0xFF0288D1)],
      _                            => [const Color(0xFF37474F), const Color(0xFF546E7A)],
    };
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);
  }

  @override
  Widget build(BuildContext context) {
    final p   = police;
    final fmt = DateFormat('d MMM y', 'tr');
    final acil   = p.kalanGun <= 10 && p.durum == PoliceStatus.beklemede;
    final baslandiMi = DateTime.now().isAfter(p.baslangicTarihi) || DateTime.now().isAtSameMomentAs(p.baslangicTarihi);
    final showBtn = p.durum == PoliceStatus.beklemede || p.durum == PoliceStatus.dahaSonra;
    final cs     = Theme.of(context).colorScheme;
    final cardColor = context.bgCard;
    final borderColor = Theme.of(context).dividerColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : const Color(0x141565C0),
            blurRadius: 10, offset: const Offset(0, 2),
          )],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Gradient Banner ──
            Container(
              decoration: BoxDecoration(
                gradient: _gradient(p.tur),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(p.tur.emoji, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.tamAd,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${p.goruntulenenTur} · ${p.sirket}',
                    style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.85))),
                ])),
                _StatusBadge(durum: p.durum, kalanGun: p.kalanGun),
              ]),
            ),
            // ── Kart Body: sadece özet bilgiler ──
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Plaka (varsa)
                if (p.aracPlaka != null) ...[
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.primary.withOpacity(0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.directions_car_outlined, size: 12, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(p.aracPlaka!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.primary)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 7),
                ],
                // Tarih bilgileri
                Row(children: [
                  _MetaBit(icon: Icons.play_circle_outline, label: 'Başlangıç', val: fmt.format(p.baslangicTarihi)),
                  const SizedBox(width: 14),
                  _MetaBit(icon: Icons.flag_outlined, label: 'Bitiş', val: fmt.format(p.bitisTarihi),
                      color: acil ? Colors.red.shade600 : null),
                ]),
                const SizedBox(height: 6),
                // Kalan gün - her zaman göster
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.kalanGun <= 0
                          ? const Color(0xFFFFEBEE)
                          : p.kalanGun <= 3
                              ? const Color(0xFFFFEBEE)
                              : p.kalanGun <= 10
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFE3F0FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.kalanGun <= 3
                          ? Colors.red.shade200
                          : p.kalanGun <= 10
                              ? Colors.orange.shade200
                              : Colors.blue.shade100),
                    ),
                    child: Text(
                      p.kalanGun <= 0 ? '🔴 Bugün sona eriyor!'
                          : p.kalanGun <= 10 ? '⚠️ ${p.kalanGun} gün kaldı'
                          : '📅 ${p.kalanGun} gün kaldı',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: p.kalanGun <= 3
                            ? Colors.red.shade700
                            : p.kalanGun <= 10
                                ? Colors.orange.shade800
                                : Colors.blue.shade700),
                    ),
                  ),
                  if (baslandiMi && p.durum != PoliceStatus.yapildi && p.durum != PoliceStatus.yapilamadi) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text('✅ Başladı',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                    ),
                  ],
                ]),
                // Hatırlatıcı
                if (p.hatirlaticiTarihi != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.alarm_outlined, size: 11, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(DateFormat('d MMM – HH:mm', 'tr').format(p.hatirlaticiTarihi!),
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                  ]),
                ],
                // Alt butonlar
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                  child: Row(children: [
                    // Bilgiler butonu (her zaman görünür)
                    Expanded(child: FilledButton.tonal(
                      onPressed: onBilgiler,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.info_outline, size: 13),
                        SizedBox(width: 5),
                        Text('Bilgiler', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ]),
                    )),
                    if (showBtn) ...[
                      const SizedBox(width: 5),
                      Expanded(child: _ActBtn(label: 'Yapıldı', icon: Icons.check_circle_outline, color: const Color(0xFF2E7D32), onTap: onYapildi)),
                      const SizedBox(width: 5),
                      Expanded(child: _ActBtn(label: 'Yapılamadı', icon: Icons.cancel_outlined, color: const Color(0xFFC62828), onTap: onYapilamadi)),
                    ],
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MetaBit extends StatelessWidget {
  final IconData icon;
  final String label, val;
  final Color? color;
  const _MetaBit({required this.icon, required this.label, required this.val, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: c),
      const SizedBox(width: 4),
      Text(val, style: TextStyle(fontSize: 11.5, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.65), fontWeight: color != null ? FontWeight.w700 : FontWeight.w500)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  final PoliceStatus durum;
  final int kalanGun;
  const _StatusBadge({required this.durum, required this.kalanGun});

  @override
  Widget build(BuildContext context) {
    final (lbl, bg) = switch (durum) {
      PoliceStatus.yapildi    => ('✓ Yapıldı',   Colors.green.withOpacity(0.3)),
      PoliceStatus.yapilamadi => ('✗ Yapılamadı', Colors.red.withOpacity(0.3)),
      PoliceStatus.dahaSonra  => ('◷ Sonra',      Colors.orange.withOpacity(0.3)),
      _ => kalanGun <= 0
          ? ('🔴 Bugün bitiyor',  Colors.red.withOpacity(0.5))
          : kalanGun <= 3
          ? ('🔴 ${kalanGun}g',   Colors.red.withOpacity(0.45))
          : kalanGun <= 10
          ? ('⚠️ ${kalanGun}g',   Colors.orange.withOpacity(0.35))
          : ('⏳ ${kalanGun}g',   Colors.white.withOpacity(0.2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(lbl, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 12),
    label: Text(label, style: const TextStyle(fontSize: 10)),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withOpacity(0.5), width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
