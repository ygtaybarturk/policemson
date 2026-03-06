import 'dart:io';
// lib/screens/policeler_screen.dart – iOS Minimal Redesign
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../main.dart' show ThemeNotifier;
import 'package:intl/intl.dart';
import 'excel_import_screen.dart';
import 'html_import_screen.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'police_detay_screen.dart';
import 'police_form_screen.dart';
import 'takvim_screen.dart';

class PolicelerScreen extends StatefulWidget {
  const PolicelerScreen({super.key});
  @override State<PolicelerScreen> createState() => _PolicelerScreenState();
}

class _PolicelerScreenState extends State<PolicelerScreen>
    with SingleTickerProviderStateMixin {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  int  _yil    = DateTime.now().year;
  int  _ay     = DateTime.now().month;
  int  _tabIdx = 0;
  List<Police>     _liste    = [];
  List<ZeyilKayit> _zeyiller = [];
  bool         _yukl    = true;
  Map<int,int> _sayilar = {};
  bool _aramaAcik = false;
  final _aramaCtrl = TextEditingController();
  List<Police> _aramaListesi = [];
  bool _aramaYukl = false;

  final _filtreler = [
    ('Tümü', null), ('Bekleyen', PoliceStatus.beklemede),
    ('Yapıldı', PoliceStatus.yapildi), ('Yapılamadı', PoliceStatus.yapilamadi),
    ('Sonra', PoliceStatus.dahaSonra),
  ];

  static const _aylar = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];

  @override
  void initState() { super.initState(); _yukle(); _aramaCtrl.addListener(_aramaYap); }
  @override
  void dispose() { _aramaCtrl.removeListener(_aramaYap); _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukl = true);
    final r = await Future.wait([
      _db.aylik(_yil, _ay, filtre: _filtreler[_tabIdx].$2),
      _db.aylikSayilar(_yil),
      _db.aylikZeyiller(_yil, _ay),
    ]);
    setState(() {
      _liste     = r[0] as List<Police>;
      _sayilar   = r[1] as Map<int,int>;
      _zeyiller  = r[2] as List<ZeyilKayit>;
      _yukl      = false;
    });
  }

  void _oncekiAy() { setState(() { if(_ay==1){_ay=12;_yil--;}else _ay--; }); _yukle(); }
  void _sonrakiAy() { setState(() { if(_ay==12){_ay=1;_yil++;}else _ay++; }); _yukle(); }

  Future<void> _tarihSeciciAc() async {
    HapticFeedback.mediumImpact();
    final secilen = await showModalBottomSheet<Map<String, int>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TarihSecici(baslangicYil: _yil, baslangicAy: _ay),
    );
    
    if (secilen != null) {
      setState(() {
        _yil = secilen['yil']!;
        _ay = secilen['ay']!;
      });
      _yukle();
    }
  }

  Future<void> _aramaYap() async {
    final q = _aramaCtrl.text.trim();
    if (q.isEmpty) { setState(() { _aramaListesi=[]; _aramaYukl=false; }); return; }
    setState(() => _aramaYukl = true);
    final r = await _db.adSoyadAra(q, _yil);
    setState(() { _aramaListesi = r; _aramaYukl = false; });
  }

  void _fabMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => _FabSheet(
        onTekEkle: () { Navigator.pop(context); _yeniPoliceAc(); },
        onExcel:   () { Navigator.pop(context); _excelImport(); },
        onHtml:    () { Navigator.pop(context); _htmlImport(); },
      ));
  }

  Future<void> _yeniPoliceAc() async {
    final ok = await Navigator.push<bool>(context, _slide(const PoliceFormScreen()));
    if (ok == true) _yukle();
  }

  Future<void> _excelImport() async {
    final ok = await Navigator.push<bool>(context, _slide(const ExcelImportScreen()));
    if (ok == true) _yukle();
  }

  Future<void> _htmlImport() async {
    final ok = await Navigator.push<bool>(context, _slide(const HtmlImportScreen()));
    if (ok == true) _yukle();
  }

  Future<void> _dahaSonraTakvim(Police p) async {
    // Önce seçenek sor: alarm kur mu, sadece sonraya al mı
    final secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Text('⏰', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Daha Sonra',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          Text('Ne yapmak istiyorsunuz?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          // Alarm kur butonu
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(_, 'alarm'),
              icon: const Icon(Icons.alarm_add_rounded),
              label: const Text('Alarm Kur',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              style: FilledButton.styleFrom(
                backgroundColor: kWarn,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Sadece sonraya al
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(_, 'sonra'),
              icon: const Icon(Icons.watch_later_outlined),
              label: const Text('Sadece Sonraya Al',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );

    if (secim == null) return; // iptal edildi

    if (secim == 'sonra') {
      // Sadece durum değiştir, alarm yok
      HapticFeedback.lightImpact();
      await _db.durumGuncelle(p.id!, PoliceStatus.dahaSonra);
      _yukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.watch_later_rounded, color: Colors.white, size: 17),
            SizedBox(width: 9),
            Text('Sonraya alındı', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: kWarn,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(milliseconds: 800),
        ));
      }
      return;
    }

    // 'alarm' seçildi → alarm sheet aç
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SonraSheet(
        police: p,
        onKaydet: (tarih, not) async {
          HapticFeedback.lightImpact();
          await _db.durumGuncelle(p.id!, PoliceStatus.dahaSonra);
          final guncellenmis = p.copyWith(
            hatirlaticiTarihi: tarih,
            hatirlaticiNotu: not.isNotEmpty ? not : null,
          );
          await _db.guncelle(guncellenmis);
          await _notif.policeIcinIptal(p.id!);
          final policeAdi = '${p.musteriAdi} ${p.soyadi}';
          final turAdi = p.goruntulenenTur;
          await _notif.hatirlaticiPlanla(
            id: p.id! * 1000 + 500,
            baslik: '📞 ${p.tur.emoji} $policeAdi',
            icerik: not.isNotEmpty
                ? not
                : '$turAdi · ${p.sirket} poliçesini yenile!',
            tarih: tarih,
          );
          _yukle();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  'Alarm kuruldu: ${DateFormat('d MMM, HH:mm', 'tr').format(tarih)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )),
              ]),
              backgroundColor: kWarn,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(milliseconds: 1000),
            ));
          }
        },
      ),
    );
    _yukle();
  }

  Future<void> _durumDegistir(Police p, PoliceStatus d) async {
    if (d == PoliceStatus.dahaSonra) { _dahaSonraTakvim(p); return; }
    HapticFeedback.lightImpact();
    await _db.durumGuncelle(p.id!, d);
    if (d != PoliceStatus.beklemede) await _notif.policeIcinIptal(p.id!);
    _yukle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(d == PoliceStatus.yapildi ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: Colors.white, size: 17),
        const SizedBox(width: 9),
        Text(d == PoliceStatus.yapildi ? 'Yapıldı olarak işaretlendi' : 'Yapılamadı olarak işaretlendi',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: d == PoliceStatus.yapildi ? kSuccess : kDanger,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(milliseconds: 800),
    ));
  }

  PageRoute<T> _slide<T>(Widget page) => PageRouteBuilder<T>(
    pageBuilder: (_, a, __) => page,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, a, __, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: a.drive(tween), child: child);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: _aramaAcik ? _aramaEkrani() : _anaEkran(),
      floatingActionButton: _aramaAcik ? null : _buildFab(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: kBgCard,
    title: _aramaAcik
        ? TextField(
            controller: _aramaCtrl, autofocus: true,
            style: const TextStyle(fontSize: 16, color: kText),
            decoration: const InputDecoration(
              hintText: 'Müşteri ara...', border: InputBorder.none, filled: false,
              hintStyle: TextStyle(color: kTextHint),
            ),
          )
        : RichText(text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: kText),
            children: [TextSpan(text: 'Poli'), TextSpan(text: 'çem', style: TextStyle(color: kPrimary))],
          )),
    bottom: PreferredSize(preferredSize: const Size.fromHeight(0.8),
        child: Container(height: 0.8, color: kBorder)),
    actions: [
      if (_aramaAcik)
        IconButton(icon: const Icon(Icons.close_rounded, color: kTextSub),
            onPressed: () => setState(() { _aramaAcik=false; _aramaCtrl.clear(); _aramaListesi=[]; }))
      else
        Padding(padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _aramaAcik = true),
            child: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: kPrimaryGlow, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.search_rounded, color: kPrimary, size: 20)),
          )),
    ],
  );

  Widget _buildFab() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: kPrimary.withOpacity(0.38), blurRadius: 22, offset: const Offset(0, 8)),
        BoxShadow(color: kPrimary.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    ),
    child: FloatingActionButton(
      onPressed: _fabMenu, backgroundColor: kPrimary, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: const Icon(Icons.add_rounded, size: 28),
    ),
  );

  Widget _anaEkran() => Column(children: [
    // Ay navigasyon
    Container(
      color: kBgCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _NavBtn(icon: Icons.chevron_left_rounded, onTap: _oncekiAy),
        Expanded(
          child: GestureDetector(
            onTap: _tarihSeciciAc,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${_aylar[_ay]} $_yil',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText, letterSpacing: -0.4)),
            ),
          ),
        ),
        _NavBtn(icon: Icons.chevron_right_rounded, onTap: _sonrakiAy),
      ]),
    ),
    // Ay chip'leri
    Container(
      color: kBgCard,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 12,
          itemBuilder: (_, i) {
            final m = i+1; final on = m == _ay; final sayi = _sayilar[m] ?? 0;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(()=>_ay=m); _yukle(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? kPrimary : kBgCard2,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: on ? [BoxShadow(color: kPrimary.withOpacity(0.30), blurRadius: 8, offset: const Offset(0,3))] : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_aylar[m], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : kTextSub)),
                  if (sayi > 0) ...[const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: on ? Colors.white.withOpacity(0.25) : kPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text('$sayi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                          color: on ? Colors.white : kPrimary)))],
                ]),
              ),
            );
          },
        ),
      ),
    ),
    // Filtre pill'leri
    Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: SizedBox(height: 32,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filtreler.length,
          itemBuilder: (_, i) {
            final on = i == _tabIdx;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(()=>_tabIdx=i); _yukle(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: on ? kPrimary : kBgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: on ? kPrimary : kBorder),
                  boxShadow: on ? [BoxShadow(color: kPrimary.withOpacity(0.22), blurRadius: 6, offset: const Offset(0,2))] : [],
                ),
                child: Text(_filtreler[i].$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                    color: on ? Colors.white : kTextSub)),
              ),
            );
          },
        ),
      ),
    ),
    // Liste
    Expanded(
      child: _yukl
          ? Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
          : _liste.isEmpty && _zeyiller.isEmpty
              ? _bosEkran()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                  cacheExtent: 800,
                  children: [
                    if (_liste.isEmpty)
                      _bosEkran()
                    else
                      ...List.generate(_liste.length, (i) => _PoliceKarti(
                        police: _liste[i],
                        onTap: () async {
                          await Navigator.push(context, _slide(PoliceDetayScreen(policeId: _liste[i].id!)));
                          _yukle();
                        },
                        onBilgiler: () async {
                          await Navigator.push(context, _slide(PoliceDetayScreen(policeId: _liste[i].id!)));
                          _yukle();
                        },
                        onYapildi:    () => _durumDegistir(_liste[i], PoliceStatus.yapildi),
                        onYapilamadi: () => _durumDegistir(_liste[i], PoliceStatus.yapilamadi),
                        onDahaSonra:  () => _durumDegistir(_liste[i], PoliceStatus.dahaSonra),
                      )),
                    // Zeyil özet
                    if (_zeyiller.isNotEmpty) _ZeyilOzet(zeyiller: _zeyiller),
                  ],
                ),
    ),
  ]);

  Widget _bosEkran() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 84, height: 84,
      decoration: BoxDecoration(
        color: kPrimary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kBorder)),
      child: const Icon(Icons.shield_outlined, size: 40, color: kTextHint)),
    const SizedBox(height: 18),
    const Text('Bu ay poliçe yok', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
    const SizedBox(height: 5),
    const Text('+ ile yeni poliçe ekleyebilirsiniz', style: TextStyle(fontSize: 13, color: kTextSub)),
  ]));

  Widget _aramaEkrani() {
    if (_aramaCtrl.text.trim().isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_rounded, size: 52, color: kTextHint.withOpacity(0.5)),
      const SizedBox(height: 12),
      const Text('Ad veya soyad yazın', style: TextStyle(color: kTextSub, fontSize: 14)),
    ]));
    if (_aramaYukl) return Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5));
    if (_aramaListesi.isEmpty) return const Center(child: Text('Sonuç bulunamadı', style: TextStyle(color: kTextSub)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _aramaListesi.length,
      itemBuilder: (_, i) => _PoliceKarti(
        police: _aramaListesi[i],
        onTap: () async { await Navigator.push(context, _slide(PoliceDetayScreen(policeId: _aramaListesi[i].id!))); _aramaYap(); },
        onBilgiler: () async { await Navigator.push(context, _slide(PoliceDetayScreen(policeId: _aramaListesi[i].id!))); _aramaYap(); },
        onYapildi:    () => _durumDegistir(_aramaListesi[i], PoliceStatus.yapildi),
        onYapilamadi: () => _durumDegistir(_aramaListesi[i], PoliceStatus.yapilamadi),
        onDahaSonra:  () => _durumDegistir(_aramaListesi[i], PoliceStatus.dahaSonra),
      ),
    );
  }
}

// ── Animasyonlu kart wrapper ────────────────────────────────
// ── Zeyil Özet Widget ────────────────────────────────────────
class _ZeyilOzet extends StatefulWidget {
  final List<ZeyilKayit> zeyiller;
  const _ZeyilOzet({required this.zeyiller});
  @override State<_ZeyilOzet> createState() => _ZeyilOzetState();
}

class _ZeyilOzetState extends State<_ZeyilOzet> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat('#,##0.##', 'tr');
    final toplamTutar    = widget.zeyiller.fold(0.0, (s, z) => s + z.tutar);
    final toplamKomisyon = widget.zeyiller.fold(0.0, (s, z) => s + z.komisyon);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: kBgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(children: [
        // Başlık — tıklanınca açılır/kapanır
        InkWell(
          onTap: () => setState(() => _acik = !_acik),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.swap_vert_rounded, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bu Ayın Zeylleri',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                        color: Colors.orange.shade800)),
                Text('${widget.zeyiller.length} kayıt',
                    style: TextStyle(fontSize: 11, color: kTextSub)),
              ])),
              // Toplam tutar
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₺${fmt.format(toplamTutar)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                        color: toplamTutar >= 0 ? Colors.green.shade700 : Colors.red.shade600)),
                Text('Kom: ₺${fmt.format(toplamKomisyon)}',
                    style: TextStyle(fontSize: 10, color: Colors.purple.shade600,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: 8),
              Icon(_acik ? Icons.expand_less : Icons.expand_more,
                  color: kTextSub, size: 20),
            ]),
          ),
        ),

        // Detay satırları — açıldığında göster
        if (_acik) ...[
          Divider(height: 1, color: Colors.orange.shade100),
          ...widget.zeyiller.map((z) {
            final artiBool = z.tutar >= 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Text(z.tur.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(z.musteriAdi,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: kText),
                      overflow: TextOverflow.ellipsis),
                  Text('${z.sirket} · ${z.policeNo}',
                      style: const TextStyle(fontSize: 10, color: kTextSub),
                      overflow: TextOverflow.ellipsis),
                  Text(z.kayitTuru,
                      style: TextStyle(fontSize: 9, color: Colors.orange.shade600,
                          fontWeight: FontWeight.w700)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₺${fmt.format(z.tutar)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: artiBool ? Colors.green.shade700 : Colors.red.shade600)),
                  if (z.komisyon != 0)
                    Text('₺${fmt.format(z.komisyon)}',
                        style: TextStyle(fontSize: 10, color: Colors.purple.shade500,
                            fontWeight: FontWeight.w600)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

// ── Nav butonu ──────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 34, height: 34,
      decoration: BoxDecoration(color: kBgCard2, borderRadius: BorderRadius.circular(11), border: Border.all(color: kBorder)),
      child: Icon(icon, size: 20, color: kPrimary)),
  );
}

// ── FAB Sheet ───────────────────────────────────────────────
class _FabSheet extends StatelessWidget {
  final VoidCallback onTekEkle, onExcel, onHtml;
  const _FabSheet({required this.onTekEkle, required this.onExcel, required this.onHtml});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: kGlass, borderRadius: BorderRadius.circular(28),
      border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 30, offset: const Offset(0, 10))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 38, height: 4, decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      _SheetTile(icon: Icons.post_add_rounded, bg: const Color(0xFFECF2FF), iconColor: kPrimary,
          title: 'Tek Poliçe Ekle', sub: 'Formu doldurarak ekle', onTap: onTekEkle),
      const SizedBox(height: 10),
      _SheetTile(icon: Icons.table_chart_rounded, bg: const Color(0xFFEAF8F0), iconColor: Color(0xFF00955A),
          title: "Excel'den Toplu Aktar", sub: 'Üretim listesini yükle (.xlsx / .xls)', onTap: onExcel),
      const SizedBox(height: 10),
      _SheetTile(icon: Icons.html_rounded, bg: const Color(0xFFFFF3E0), iconColor: Color(0xFFE65100),
          title: "HTML'den Toplu Aktar", sub: 'Web listesini yükle (.html / .htm)', onTap: onHtml),
      const SizedBox(height: 6),
    ]),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon; final Color bg, iconColor;
  final String title, sub; final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.bg, required this.iconColor, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: kBg, borderRadius: BorderRadius.circular(16),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(width: 46, height: 46,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kText)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: kTextSub)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kTextHint),
        ])),
    ),
  );
}

// ══════════════════════════════════════════════════════════
// Poliçe Kartı – Glassmorphism + Per-type Gradient
// ══════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════
// Poliçe Kartı – Tam Bilgi Tasarımı
// ══════════════════════════════════════════════════════════
class _PoliceKarti extends StatefulWidget {
  final Police police;
  final VoidCallback onTap, onYapildi, onYapilamadi, onDahaSonra, onBilgiler;
  const _PoliceKarti({
    required this.police, required this.onTap,
    required this.onYapildi, required this.onYapilamadi,
    required this.onDahaSonra, required this.onBilgiler,
  });
  @override State<_PoliceKarti> createState() => _PoliceKartiState();
}

class _PoliceKartiState extends State<_PoliceKarti> {
  bool _komisyonGoster = false;

  static (List<Color>, Color) _turPalette(PoliceType t) => switch (t) {
    PoliceType.trafik            => ([const Color(0xFF1B4FD8), const Color(0xFF4F7BF7)], const Color(0xFF1B4FD8)),
    PoliceType.kasko             => ([const Color(0xFF312E81), const Color(0xFF6D6BCF)], const Color(0xFF4338CA)),
    PoliceType.dask              => ([const Color(0xFF6B21A8), const Color(0xFFA855F7)], const Color(0xFF7C3AED)),
    PoliceType.konut             => ([const Color(0xFFBE185D), const Color(0xFFF472B6)], const Color(0xFFDB2777)),
    PoliceType.ozelSaglik        => ([const Color(0xFFB91C1C), const Color(0xFFF87171)], const Color(0xFFDC2626)),
    PoliceType.tamamlayiciSaglik => ([const Color(0xFF9D174D), const Color(0xFFFDA4AF)], const Color(0xFFBE185D)),
    PoliceType.hayat             => ([const Color(0xFF14532D), const Color(0xFF4ADE80)], const Color(0xFF16A34A)),
    PoliceType.ferdiKaza         => ([const Color(0xFFC2410C), const Color(0xFFFB923C)], const Color(0xFFEA580C)),
    PoliceType.isyeri            => ([const Color(0xFF064E3B), const Color(0xFF34D399)], const Color(0xFF059669)),
    PoliceType.nakliyat          => ([const Color(0xFF164E63), const Color(0xFF22D3EE)], const Color(0xFF0E7490)),
    PoliceType.tarim             => ([const Color(0xFF365314), const Color(0xFFA3E635)], const Color(0xFF65A30D)),
    PoliceType.seyahat           => ([const Color(0xFF0C4A6E), const Color(0xFF38BDF8)], const Color(0xFF0284C7)),
    _                            => ([const Color(0xFF1F2937), const Color(0xFF6B7280)], const Color(0xFF374151)),
  };

  @override
  Widget build(BuildContext context) {
    final p           = widget.police;
    final fmt         = DateFormat('d MMM y', 'tr');
    final moneyFmt    = NumberFormat.currency(locale: 'tr', symbol: '₺', decimalDigits: 2);
    final acil        = p.kalanGun <= 10 && p.durum != PoliceStatus.yapildi;
    final showBtn     = true; // Her zaman durum butonları göster
    final (gradColors, accent) = _turPalette(p.tur);
    final isYapildi   = p.durum == PoliceStatus.yapildi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: kBgCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: acil ? kDanger.withOpacity(0.35) : kBorder,
              width: acil ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(color: acil ? kDanger.withOpacity(0.12) : accent.withOpacity(0.10),
                  blurRadius: 20, offset: const Offset(0, 6)),
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: [

            // ── 1. Gradient Header: İsim + Soyisim + Uyarı ──
            Stack(children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradColors),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Emoji box
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.white.withOpacity(0.28)),
                    ),
                    child: Center(child: Text(p.tur.emoji, style: const TextStyle(fontSize: 21))),
                  ),
                  const SizedBox(width: 11),
                  // İsim + poliçe türü + şirket
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // İSİM SOYİSİM – büyük ve belirgin + KİŞİ SAYISI
                    Row(children: [
                      Expanded(child: Text(
                        '${p.musteriAdi} ${p.soyadi}',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.4,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                      // Grup kişi sayısı badge
                      if (p.kisiSayisi != null && p.kisiSayisi! > 1)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Text('${p.kisiSayisi} kişi',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                    ]),
                    const SizedBox(height: 5),
                    // Poliçe türü pill + şirket
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.28)),
                        ),
                        child: Text(p.goruntulenenTur,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      const SizedBox(width: 7),
                      Flexible(child: Text(p.sirket,
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.82), fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ])),
                  // Sağ üst: yapıldı ya da kalan gün badge
                  const SizedBox(width: 8),
                  Column(children: [
                    _HeaderBadge(durum: p.durum, kalanGun: p.kalanGun),
                    if (p.pdfDosyaYolu != null && p.pdfDosyaYolu!.isNotEmpty && File(p.pdfDosyaYolu!).existsSync()) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.picture_as_pdf_rounded, size: 11, color: Colors.white),
                          SizedBox(width: 3),
                          Text('PDF', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ]),
                ]),
              ),
              // ── 10 gün uyarı ışığı (sol üst köşe) ──
              if (acil)
                Positioned(
                  top: 0, left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.kalanGun <= 3 ? kDanger : kWarn,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        p.kalanGun <= 0 ? 'BUGÜN!' : '${p.kalanGun} GÜN',
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 0.3,
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),

            // ── 2. Kart Gövdesi ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Poliçe Numarası (varsa)
                if (p.policeNo != null && p.policeNo!.isNotEmpty) ...[
                  Row(children: [
                    const Icon(Icons.numbers_rounded, size: 12, color: kTextSub),
                    const SizedBox(width: 5),
                    Expanded(child: Text('Poliçe No: ${p.policeNo!}',
                        style: const TextStyle(fontSize: 11, color: kTextSub, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 8),
                ],

                // Plaka (araç varsa)
                if (p.aracPlaka != null && p.aracPlaka!.isNotEmpty) ...[
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: accent.withOpacity(0.18)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.directions_car_rounded, size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(p.aracPlaka!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: accent)),
                      ]),
                    ),
                    if (p.aracMarka != null && p.aracMarka!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('${p.aracMarka}${p.aracModel != null ? " ${p.aracModel}" : ""}${p.aracYil != null ? " (${p.aracYil})" : ""}',
                          style: const TextStyle(fontSize: 11, color: kTextSub)),
                    ],
                  ]),
                  const SizedBox(height: 10),
                ],

                // ── Tarih satırı: başlangıç → bitiş ──────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: kBgCard2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(children: [
                    // Başlangıç
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Başlangıç', style: const TextStyle(fontSize: 9.5, color: kTextHint, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(fmt.format(p.baslangicTarihi),
                          style: const TextStyle(fontSize: 12.5, color: kText, fontWeight: FontWeight.w800)),
                    ])),
                    // Ok
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kBorder,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, size: 12, color: kTextSub),
                      ),
                    ),
                    // Bitiş
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Bitiş', style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w700,
                          color: acil ? kDanger.withOpacity(0.7) : kTextHint)),
                      const SizedBox(height: 2),
                      Text(fmt.format(p.bitisTarihi),
                          style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w800,
                            color: acil ? kDanger : kText,
                          )),
                    ])),
                  ]),
                ),
                const SizedBox(height: 9),

                // ── Kalan gün + durum ─────────────────────
                Row(children: [
                  // Kalan gün pill
                  _KalanGunPill(kalanGun: p.kalanGun, yapildi: isYapildi),
                  const SizedBox(width: 6),
                  // Yapıldı bilgisi – yeşil, belirgin
                  if (isYapildi)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kSuccess.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kSuccess.withOpacity(0.30)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded, size: 13, color: kSuccess),
                        const SizedBox(width: 4),
                        const Text('Yapıldı',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kSuccess)),
                      ]),
                    ),
                  if (p.durum == PoliceStatus.yapilamadi)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kDanger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kDanger.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cancel_rounded, size: 13, color: kDanger),
                        const SizedBox(width: 4),
                        const Text('Yapılamadı',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kDanger)),
                      ]),
                    ),
                  if (p.durum == PoliceStatus.dahaSonra)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kWarn.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kWarn.withOpacity(0.25)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.watch_later_rounded, size: 13, color: kWarn),
                        const SizedBox(width: 4),
                        const Text('Daha Sonra',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kWarn)),
                      ]),
                    ),
                ]),

                // Prim tutarı
                if (p.tutar > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.payments_outlined, size: 13, color: kTextSub),
                    const SizedBox(width: 5),
                    Text('Prim: ', style: const TextStyle(fontSize: 11.5, color: kTextSub)),
                    Text(moneyFmt.format(p.tutar),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
                    if (p.komisyon > 0) ...[
                      const SizedBox(width: 8),
                      Text('• Komisyon: ${moneyFmt.format(p.komisyon)}',
                          style: const TextStyle(fontSize: 11, color: kTextSub)),
                    ],
                  ]),
                ],

                // Hatırlatıcı - sadece gelecekte ise göster
                if (p.hatirlaticiTarihi != null &&
                    p.hatirlaticiTarihi!.isAfter(DateTime.now())) ...[
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kWarn.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: kWarn.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.alarm_rounded, size: 12, color: kWarn),
                      const SizedBox(width: 5),
                      Text(DateFormat('d MMM, HH:mm', 'tr').format(p.hatirlaticiTarihi!),
                          style: const TextStyle(fontSize: 11, color: kWarn, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],

                // ── Aksiyon butonlar + Bilgiler ───────────
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: kDivider))),
                  child: Column(children: [
                    if (showBtn) ...[
                      Row(children: [
                        Expanded(child: _ActBtn('Yapıldı',    Icons.check_circle_outline_rounded, kSuccess, widget.onYapildi,    secili: p.durum == PoliceStatus.yapildi)),
                        const SizedBox(width: 6),
                        Expanded(child: _ActBtn('Yapılamadı', Icons.cancel_outlined,              kDanger,  widget.onYapilamadi, secili: p.durum == PoliceStatus.yapilamadi)),
                        const SizedBox(width: 6),
                        Expanded(child: _ActBtn('Sonra',      Icons.watch_later_outlined,         kWarn,    widget.onDahaSonra,  secili: p.durum == PoliceStatus.dahaSonra)),
                      ]),
                      const SizedBox(height: 8),
                    ],
                    // BİLGİLER BUTONU – her zaman en altta, tam genişlik
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: accent.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          onTap: widget.onBilgiler,
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: accent.withOpacity(0.22)),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.open_in_new_rounded, size: 15, color: accent),
                              const SizedBox(width: 7),
                              Text('Tüm Bilgileri Gör',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent)),
                            ]),
                          ),
                        ),
                      ),
                    ),
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

// ── Yardımcı Widget'lar ─────────────────────────────────────

class _HeaderBadge extends StatelessWidget {
  final PoliceStatus durum;
  final int kalanGun;
  const _HeaderBadge({required this.durum, required this.kalanGun});

  @override
  Widget build(BuildContext context) {
    final (label, bg) = switch (durum) {
      PoliceStatus.yapildi    => ('✓ Yapıldı',     Colors.white.withOpacity(0.25)),
      PoliceStatus.yapilamadi => ('✗ Yapılamadı',  Colors.red.withOpacity(0.38)),
      PoliceStatus.dahaSonra  => ('◷ Sonra',        Colors.orange.withOpacity(0.32)),
      _ => kalanGun < 0    ? ('🔴 Bitti',       Colors.red.withOpacity(0.5))
         : kalanGun == 0   ? ('🔴 Bugün',       Colors.red.withOpacity(0.5))
         : kalanGun <= 3   ? ('🔴 ${kalanGun}g', Colors.red.withOpacity(0.42))
         : kalanGun <= 10  ? ('⚠️ ${kalanGun}g', Colors.orange.withOpacity(0.32))
         :                   ('⏳ ${kalanGun}g', Colors.white.withOpacity(0.18)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _KalanGunPill extends StatelessWidget {
  final int kalanGun;
  final bool yapildi;
  const _KalanGunPill({required this.kalanGun, this.yapildi = false});

  @override
  Widget build(BuildContext context) {
    if (yapildi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSuccess.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kSuccess.withOpacity(0.18)),
        ),
        child: Text(kalanGun > 0 ? '📅 $kalanGun gün sonra bitiyor' : '🏁 Tamamlandı',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: kSuccess)),
      );
    }
    final (t, bg, fg) = kalanGun < 0
        ? ('🔴 Poliçe Bitti', kDanger.withOpacity(0.10), kDanger)
        : kalanGun == 0
        ? ('🔴 Bugün bitiyor!', kDanger.withOpacity(0.10), kDanger)
        : kalanGun <= 3
        ? ('🔴 $kalanGun gün kaldı', kDanger.withOpacity(0.10), kDanger)
        : kalanGun <= 10
        ? ('⚠️ $kalanGun gün kaldı', kWarn.withOpacity(0.10), kWarn)
        : ('📅 $kalanGun gün kaldı', kPrimary.withOpacity(0.08), kPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.20)),
      ),
      child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  final bool secili;
  const _ActBtn(this.label, this.icon, this.color, this.onTap, {this.secili = false});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(secili ? _doluIcon(icon) : icon, size: 12),
    label: Text(label, style: TextStyle(fontSize: 10.5, letterSpacing: -0.2, fontWeight: secili ? FontWeight.w900 : FontWeight.w600)),
    style: OutlinedButton.styleFrom(
      foregroundColor: secili ? Colors.white : color,
      backgroundColor: secili ? color : color.withOpacity(0.06),
      side: BorderSide(color: secili ? color : color.withOpacity(0.35), width: secili ? 1.5 : 1),
      padding: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );

  IconData _doluIcon(IconData icon) {
    if (icon == Icons.check_circle_outline_rounded) return Icons.check_circle_rounded;
    if (icon == Icons.cancel_outlined) return Icons.cancel_rounded;
    if (icon == Icons.watch_later_outlined) return Icons.watch_later_rounded;
    return icon;
  }
}

// ── Sonra Sheet ──────────────────────────────────────────────
class _SonraSheet extends StatefulWidget {
  final Police police;
  final void Function(DateTime tarih, String not) onKaydet;
  const _SonraSheet({required this.police, required this.onKaydet});
  @override State<_SonraSheet> createState() => _SonraSheetState();
}

class _SonraSheetState extends State<_SonraSheet> {
  final _notCtrl = TextEditingController();
  DateTime _tarih = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _saat = const TimeOfDay(hour: 9, minute: 0);
  bool _kaydediliyor = false;

  @override void dispose() { _notCtrl.dispose(); super.dispose(); }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _saatSec() async {
    final s = await showTimePicker(context: context, initialTime: _saat);
    if (s != null) setState(() => _saat = s);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    final tam = DateTime(_tarih.year, _tarih.month, _tarih.day, _saat.hour, _saat.minute);
    widget.onKaydet(tam, _notCtrl.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.police;
    final fmt = DateFormat('d MMM y', 'tr');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tutamaç
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Başlık
            Row(children: [
              const Icon(Icons.watch_later_rounded, color: kWarn, size: 22),
              const SizedBox(width: 8),
              const Text('Daha Sonra – Hatırlatıcı',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 14),

            // Poliçe bilgi kartı
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kWarn.withOpacity(.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kWarn.withOpacity(.2)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: kWarn.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(p.tur.emoji, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.musteriAdi} ${p.soyadi}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text('${p.goruntulenenTur} · ${p.sirket}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text('Bitiş: ${fmt.format(p.bitisTarihi)} · ${p.kalanGun} gün kaldı',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: p.kalanGun <= 14 ? kDanger : Colors.grey.shade500,
                          fontWeight: FontWeight.w700)),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // Not alanı
            const Text('Not (isteğe bağlı)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _notCtrl,
              maxLines: 3,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Bildirimde gösterilecek not…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Tarih + Saat seçici
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tarih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _tarihSec,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: kPrimary),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM y', 'tr').format(_tarih),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Saat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _saatSec,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_outlined, size: 15, color: kPrimary),
                      const SizedBox(width: 8),
                      Text(_saat.format(context),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 20),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: _kaydediliyor
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.alarm_add_rounded),
                label: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Hatırlatıcı Kur',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: kWarn,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ── Tarih Seçici ──────────────────────────────────────────────
class _TarihSecici extends StatefulWidget {
  final int baslangicYil;
  final int baslangicAy;
  const _TarihSecici({required this.baslangicYil, required this.baslangicAy});
  @override State<_TarihSecici> createState() => _TarihSeciciState();
}

class _TarihSeciciState extends State<_TarihSecici> {
  late int _yil;
  late int _ay;
  
  static const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                         'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  @override
  void initState() {
    super.initState();
    _yil = widget.baslangicYil;
    _ay = widget.baslangicAy;
  }

  @override
  Widget build(BuildContext context) {
    final yillar = List.generate(11, (i) => 2022 + i); // 2022'den 2032'ye kadar (11 yıl)
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        
        Row(children: [
          const Icon(Icons.calendar_month_rounded, color: kPrimary, size: 22),
          const SizedBox(width: 8),
          const Text('Tarih Seç', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 20),
        
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Yıl', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: yillar.length,
            itemBuilder: (_, i) {
              final yil = yillar[i];
              final secili = yil == _yil;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _yil = yil);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: secili ? kPrimary : kBgCard2,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: secili ? [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Center(
                    child: Text('$yil', style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: secili ? Colors.white : kTextSub,
                    )),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Ay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: 12,
          itemBuilder: (_, i) {
            final ay = i + 1;
            final secili = ay == _ay;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _ay = ay);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: secili ? kPrimary : kBgCard2,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: secili ? [BoxShadow(color: kPrimary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text(_aylar[ay], style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secili ? Colors.white : kTextSub,
                  )),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, {'yil': _yil, 'ay': _ay}),
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('${_aylar[_ay]} $_yil - Görüntüle',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}
