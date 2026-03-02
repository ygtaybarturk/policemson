// lib/screens/policeler_screen.dart – M3 Redesign
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'police_detay_screen.dart';
import 'police_form_screen.dart';
import 'takvim_screen.dart';

// ── Renk sabitleri ────────────────────────────────────────
const _kPrimary = Color(0xFF1565C0);
const _kSurface = Color(0xFFF0F5FF);
const _kText    = Color(0xFF1A1A2E);
const _kText2   = Color(0xFF7A8AAA);
const _kBorder  = Color(0xFFE8EEFF);

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
        onTopluPdf: () { Navigator.pop(context); _topluPdfSheet(); },
      ),
    );
  }

  Future<void> _yeniPoliceAc() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PoliceFormScreen()));
    if (ok == true) _yukle();
  }

  void _topluPdfSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopluPdfSheet(db: _db, onBitti: _yukle),
    );
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
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: _aramaAcik
            ? TextField(
                controller: _aramaCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ad, soyad ara...',
                  border: InputBorder.none,
                  filled: false,
                  hintStyle: TextStyle(color: _kText2, fontSize: 16),
                ),
                style: const TextStyle(fontSize: 16, color: _kText),
              )
            : RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _kText),
                  children: [
                    TextSpan(text: 'Poli'),
                    TextSpan(text: 'çem', style: TextStyle(color: _kPrimary)),
                  ],
                ),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
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
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _ArrBtn(icon: Icons.chevron_left, onTap: _oncekiAy),
          Expanded(
            child: Text(
              '${_aylar[_ay]} $_yil',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kText),
            ),
          ),
          _ArrBtn(icon: Icons.chevron_right, onTap: _sonrakiAy),
        ]),
      ),
      // Ay chip listesi
      Container(
        color: Colors.white,
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
                    color: on ? _kPrimary : const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _aylar[m],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : _kText2,
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
        color: _kSurface,
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
                    color: on ? const Color(0xFFE3F0FF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: on ? _kPrimary : const Color(0xFFD0DCEE),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _filtreler[i].$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: on ? _kPrimary : _kText2,
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
        decoration: BoxDecoration(color: const Color(0xFFEEF3FF), borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.description_outlined, size: 40, color: Color(0xFF9AAAC0)),
      ),
      const SizedBox(height: 16),
      const Text('Bu ay için poliçe yok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText2)),
      const SizedBox(height: 6),
      const Text('+ butonuyla poliçe ekleyebilirsiniz', style: TextStyle(fontSize: 12, color: _kText2)),
    ]),
  );

  // ── Arama ekranı ─────────────────────────────────────────
  Widget _aramaEkrani() {
    if (_aramaCtrl.text.trim().isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.search, size: 48, color: _kText2.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('Ad veya soyad yazın', style: TextStyle(color: _kText2, fontSize: 14)),
        ]),
      );
    }
    if (_aramaYukl) return const Center(child: CircularProgressIndicator());
    if (_aramaListesi.isEmpty) return Center(
      child: Text('Sonuç bulunamadı', style: TextStyle(color: _kText2, fontSize: 14)),
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
        border: Border.all(color: const Color(0xFFD0DCEE), width: 1.5),
        borderRadius: BorderRadius.circular(50),
        color: Colors.white,
      ),
      child: Icon(icon, size: 18, color: _kPrimary),
    ),
  );
}

// ── FAB Menü ──────────────────────────────────────────────
class _FabSheet extends StatelessWidget {
  final VoidCallback onTekEkle, onTopluPdf;
  const _FabSheet({required this.onTekEkle, required this.onTopluPdf});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
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
          icon: Icons.upload_file_outlined,
          bg: const Color(0xFFE8F5E9), iconColor: Color(0xFF2E7D32),
          title: 'Toplu PDF Yükle',
          sub: 'PDF seç, poliçeye ata',
          onTap: onTopluPdf,
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
    color: _kSurface,
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _kText)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11.5, color: _kText2)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 13, color: _kText2),
        ]),
      ),
    ),
  );
}

// ── Toplu PDF Sheet ───────────────────────────────────────
class _TopluPdfSheet extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onBitti;
  const _TopluPdfSheet({required this.db, required this.onBitti});
  @override State<_TopluPdfSheet> createState() => _TopluPdfSheetState();
}

class _TopluPdfSheetState extends State<_TopluPdfSheet> {
  List<_PdfItem> _pdfler = [];
  bool _seciliyor = false;
  static const _aylar = ['','Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  static const _aylarK = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];

  Future<void> _pdfSec() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
    if (r == null || r.files.isEmpty) return;
    setState(() => _seciliyor = true);
    final yeni = <_PdfItem>[];
    for (final f in r.files) {
      if (f.path == null) continue;
      final tahmin = _tahmin(f.name);
      yeni.add(_PdfItem(
        dosyaAdi: f.name, dosyaYolu: f.path!, boyut: f.size,
        seciliAy: tahmin?.month ?? DateTime.now().month,
        seciliYil: tahmin?.year ?? DateTime.now().year,
      ));
    }
    setState(() { _pdfler.addAll(yeni); _seciliyor = false; });
  }

  DateTime? _tahmin(String ad) {
    final low = ad.toLowerCase();
    final ayMap = {'ocak':1,'subat':2,'mart':3,'nisan':4,'mayis':5,'haziran':6,'temmuz':7,'agustos':8,'eylul':9,'ekim':10,'kasim':11,'aralik':12,'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
    for (final e in ayMap.entries) {
      if (low.contains(e.key)) {
        final ym = RegExp(r'20\d{2}').firstMatch(low);
        return DateTime(ym!=null?int.parse(ym.group(0)!):DateTime.now().year, e.value);
      }
    }
    return null;
  }

  Future<void> _ayDegistir(_PdfItem item) async {
    int sa = item.seciliAy, sy = item.seciliYil;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ay Seç', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: ()=>ss(()=>sy--), icon: const Icon(Icons.chevron_left)),
            Text('$sy', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            IconButton(onPressed: ()=>ss(()=>sy++), icon: const Icon(Icons.chevron_right)),
          ]),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.4, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: 12,
            itemBuilder: (_, i) {
              final m = i+1; final on = m == sa;
              return GestureDetector(
                onTap: ()=>ss(()=>sa=m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    color: on ? _kPrimary : const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(_aylarK[m],
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: on ? Colors.white : _kText2))),
                ),
              );
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: (){ setState((){item.seciliAy=sa;item.seciliYil=sy;}); Navigator.pop(ctx); }, child: const Text('Uygula')),
        ],
      )),
    );
  }

  Future<void> _ata(_PdfItem item) async {
    final policeler = await widget.db.ayTumPolice(item.seciliYil, item.seciliAy);
    if (!mounted) return;
    if (policeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_aylar[item.seciliAy]} ${item.seciliYil} için poliçe bulunamadı'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final secilen = await showDialog<Police>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_aylar[item.seciliAy]} – Poliçe Seç', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        content: SizedBox(width: double.maxFinite, height: 280,
          child: ListView.builder(
            itemCount: policeler.length,
            itemBuilder: (_, i) {
              final p = policeler[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6), elevation: 0,
                color: const Color(0xFFF0F5FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Text(p.tur.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.tamAd, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${p.goruntulenenTur} · ${p.sirket}', style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('İptal'))],
      ),
    );
    if (secilen == null) return;
    await widget.db.pdfYolu(secilen.id!, item.dosyaYolu);
    setState(() => item.atandi = true);
    widget.onBitti();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ ${item.dosyaAdi} → ${secilen.tamAd}'),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _boyutStr(int b) => b < 1024*1024 ? '${(b/1024).toStringAsFixed(0)} KB' : '${(b/1024/1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final atandi = _pdfler.where((p)=>p.atandi).length;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: .7, maxChildSize: .95, minChildSize: .5,
        builder: (_, sc) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.upload_file_outlined, color: Color(0xFF2E7D32), size: 20)),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Toplu PDF Yükleme', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('Poliçe PDFlerini toplu içe aktar', style: TextStyle(fontSize: 11, color: _kText2)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: ()=>Navigator.pop(context)),
              ]),
            ]),
          ),
          const Divider(height: 20),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            // Bilgi
            Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE3F0FF), borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: _kPrimary),
                SizedBox(width: 10),
                Expanded(child: Text('Dosya adından ay bilgisi otomatik okunur.\nÖrn: "trafik_mart_2026.pdf" → Mart 2026', style: TextStyle(fontSize: 11.5, color: _kPrimary, height: 1.5))),
              ]),
            ),
            // Seç butonu
            OutlinedButton.icon(
              onPressed: _seciliyor ? null : _pdfSec,
              icon: _seciliyor ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.folder_open),
              label: Text(_seciliyor ? 'Seçiliyor…' : '📱 Telefondan PDF Seç', style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (_pdfler.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFE3F0FF), borderRadius: BorderRadius.circular(20)),
                  child: Text('${_pdfler.length} dosya · $atandi atandı', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kPrimary))),
                const Spacer(),
                TextButton.icon(onPressed: ()=>setState(()=>_pdfler.clear()), icon: Icon(Icons.clear_all, size: 14, color: Colors.red.shade400), label: Text('Temizle', style: TextStyle(fontSize: 11, color: Colors.red.shade400))),
              ]),
              const SizedBox(height: 8),
              ..._pdfler.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: item.atandi ? const Color(0xFFF1F8F1) : _kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: item.atandi ? Colors.green.shade200 : const Color(0xFFD0DCEE), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red.shade600, size: 15)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.dosyaAdi, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      if (item.atandi) const Icon(Icons.check_circle, color: Colors.green, size: 16)
                      else Text(_boyutStr(item.boyut), style: const TextStyle(fontSize: 10, color: _kText2)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      GestureDetector(
                        onTap: item.atandi ? null : () => _ayDegistir(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFEEF3FF), borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_month_outlined, size: 11, color: _kPrimary),
                            const SizedBox(width: 4),
                            Text('${_aylar[item.seciliAy]} ${item.seciliYil}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kPrimary)),
                            if (!item.atandi) ...[const SizedBox(width: 3), const Icon(Icons.edit, size: 9, color: _kPrimary)],
                          ]),
                        ),
                      ),
                      const Spacer(),
                      if (!item.atandi)
                        FilledButton.icon(
                          onPressed: () => _ata(item),
                          icon: const Icon(Icons.link, size: 12),
                          label: const Text('Poliçeye Ata', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => setState(()=>item.atandi=false),
                          icon: const Icon(Icons.undo, size: 11),
                          label: const Text('Geri Al', style: TextStyle(fontSize: 10)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ]),
                  ]),
                ),
              )),
            ] else ...[
              const SizedBox(height: 32),
              Center(child: Column(children: [
                Icon(Icons.cloud_upload_outlined, size: 44, color: _kText2.withOpacity(0.4)),
                const SizedBox(height: 10),
                const Text('Henüz PDF seçilmedi', style: TextStyle(color: _kText2, fontWeight: FontWeight.w600)),
              ])),
            ],
            const SizedBox(height: 20),
          ])),
        ]),
      ),
    );
  }
}

class _PdfItem {
  final String dosyaAdi, dosyaYolu;
  final int boyut;
  int seciliAy, seciliYil;
  bool atandi = false;
  _PdfItem({required this.dosyaAdi, required this.dosyaYolu, required this.boyut, required this.seciliAy, required this.seciliYil});
}

// ══════════════════════════════════════════════════════════
// Poliçe Kartı – M3 Gradyan Tasarım
// ══════════════════════════════════════════════════════════
class _PoliceKarti extends StatelessWidget {
  final Police police;
  final VoidCallback onTap, onYapildi, onYapilamadi, onDahaSonra;
  const _PoliceKarti({required this.police, required this.onTap,
    required this.onYapildi, required this.onYapilamadi, required this.onDahaSonra});

  static LinearGradient _gradient(PoliceType t) {
    final colors = switch (t) {
      PoliceType.trafik || PoliceType.kasko          => [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
      PoliceType.dask || PoliceType.konut            => [const Color(0xFF4A148C), const Color(0xFF7B1FA2)],
      PoliceType.ozelSaglik || PoliceType.tamamlayiciSaglik ||
      PoliceType.hayat || PoliceType.ferdiKaza       => [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
      PoliceType.isyeri                              => [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
      PoliceType.nakliyat                            => [const Color(0xFF00695C), const Color(0xFF00897B)],
      PoliceType.seyahat                             => [const Color(0xFF0277BD), const Color(0xFF0288D1)],
      PoliceType.tarim                               => [const Color(0xFF33691E), const Color(0xFF558B2F)],
      _                                              => [const Color(0xFF37474F), const Color(0xFF546E7A)],
    };
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);
  }

  @override
  Widget build(BuildContext context) {
    final p = police;
    final fmt = DateFormat('d MMM y', 'tr');
    final pFmt = NumberFormat.currency(locale:'tr', symbol:'₺', decimalDigits: 0);
    final acil = p.kalanGun <= 10 && p.durum == PoliceStatus.beklemede;
    final showBtn = p.durum == PoliceStatus.beklemede || p.durum == PoliceStatus.dahaSonra;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: acil ? 3 : 1,
        shadowColor: const Color(0x201565C0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Banner ──
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
                  Text(p.tamAd, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${p.goruntulenenTur} · ${p.sirket}', style: TextStyle(fontSize: 10.5, color: Colors.white.withOpacity(0.85))),
                ])),
                _StatusBadge(durum: p.durum, kalanGun: p.kalanGun),
              ]),
            ),
            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Meta bilgi
                Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: _kText2),
                  const SizedBox(width: 4),
                  Text(fmt.format(p.bitisTarihi), style: const TextStyle(fontSize: 12, color: _kText2)),
                  const SizedBox(width: 12),
                  const Icon(Icons.payments_outlined, size: 12, color: _kText2),
                  const SizedBox(width: 4),
                  Text(pFmt.format(p.tutar), style: const TextStyle(fontSize: 12, color: _kText2)),
                ]),
                // Acil chip
                if (acil) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.kalanGun <= 3 ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.kalanGun <= 3 ? Colors.red.shade300 : Colors.orange.shade300),
                    ),
                    child: Text(
                      p.kalanGun <= 0 ? '🔴 Bugün sona eriyor!' : '⚠️ ${p.kalanGun} gün kaldı',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: p.kalanGun <= 3 ? Colors.red.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
                // Hatırlatıcı
                if (p.hatirlaticiTarihi != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.alarm_outlined, size: 11, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('d MMM – HH:mm', 'tr').format(p.hatirlaticiTarihi!),
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
                // Aksiyon butonları
                if (showBtn) ...[
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.only(top: 9),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2FF)))),
                    child: Row(children: [
                      Expanded(child: _ActBtn(label: 'Yapıldı', icon: Icons.check_circle_outline, color: const Color(0xFF2E7D32), onTap: onYapildi)),
                      const SizedBox(width: 5),
                      Expanded(child: _ActBtn(label: 'Yapılamadı', icon: Icons.cancel_outlined, color: const Color(0xFFC62828), onTap: onYapilamadi)),
                      const SizedBox(width: 5),
                      Expanded(child: _ActBtn(label: 'Sonra', icon: Icons.schedule_outlined, color: const Color(0xFFE65100), onTap: onDahaSonra)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
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
      _                       => kalanGun <= 3
          ? ('🔴 ${kalanGun}g',   Colors.red.withOpacity(0.45))
          : ('⏳ Beklemede',      Colors.white.withOpacity(0.2)),
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
