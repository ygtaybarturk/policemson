// lib/screens/policeler_screen.dart – v3.3
// FAB → BottomSheet: Tek Ekle / Toplu PDF / Arama
// Arama: yıl bazlı ad/soyad arama + canlı sonuç
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'police_detay_screen.dart';
import 'takvim_screen.dart';

class PolicelerScreen extends StatefulWidget {
  const PolicelerScreen({super.key});
  @override State<PolicelerScreen> createState() => _PolicelerScreenState();
}

class _PolicelerScreenState extends State<PolicelerScreen>
    with SingleTickerProviderStateMixin {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  int  _yil = DateTime.now().year;
  int  _ay  = DateTime.now().month;
  int  _tabIdx = 0;
  List<Police> _liste   = [];
  bool         _yukl    = true;
  Map<int,int> _sayilar = {};

  // Arama modu
  bool _aramaAcik = false;
  final _aramaCtrl = TextEditingController();
  List<Police> _aramaListesi = [];
  bool _aramaYukleniyor = false;

  final _filtreler = [
    ('Tümü',       null),
    ('Bekleyen',   PoliceStatus.beklemede),
    ('Yapıldı',    PoliceStatus.yapildi),
    ('Yapılamadı', PoliceStatus.yapilamadi),
    ('Daha Sonra', PoliceStatus.dahaSonra),
  ];

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

  void _oncekiAy() {
    setState(() { if (_ay==1){_ay=12;_yil--;}else _ay--; });
    _yukle();
  }
  void _sonrakiAy() {
    setState(() { if (_ay==12){_ay=1;_yil++;}else _ay++; });
    _yukle();
  }

  // ── Arama ────────────────────────────────────────────────
  Future<void> _aramaYap() async {
    final q = _aramaCtrl.text.trim();
    if (q.isEmpty) { setState(() { _aramaListesi=[]; _aramaYukleniyor=false; }); return; }
    setState(() => _aramaYukleniyor = true);
    final sonuc = await _db.adSoyadAra(q, _yil);
    setState(() { _aramaListesi = sonuc; _aramaYukleniyor = false; });
  }

  // ── FAB menüsü ────────────────────────────────────────────
  void _fabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FabMenuSheet(
        onTekEkle: () {
          Navigator.pop(context);
          _yeniPoliceAc();
        },
        onTopluPdf: () {
          Navigator.pop(context);
          _topluPdfSheet();
        },
      ),
    );
  }

  Future<void> _yeniPoliceAc() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => TakvimScreen(yeniPoliceFormu: true, onPoliceEklendi: () => _yukle()),
    ));
    if (ok == true) _yukle();
  }

  // ── Toplu PDF sheet ──────────────────────────────────────
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
      content: Text(d==PoliceStatus.yapildi?'✅ Yapıldı!':'❌ Yapılamadı olarak işaretlendi'),
      backgroundColor: d==PoliceStatus.yapildi?Colors.green.shade600:Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sc    = Theme.of(context).colorScheme;
    final ayAdi = DateFormat('MMMM y','tr').format(DateTime(_yil,_ay));
    final fmt   = NumberFormat.currency(locale:'tr',symbol:'₺',decimalDigits:0);
    final toplam = _liste.fold<double>(0,(s,p)=>s+p.tutar);

    final goruntuListe = _aramaAcik && _aramaCtrl.text.isNotEmpty
        ? _aramaListesi : _liste;

    return Scaffold(
      backgroundColor: sc.surface,
      body: CustomScrollView(slivers: [

        // ── Large AppBar ─────────────────────────────────
        SliverAppBar.large(
          backgroundColor: sc.surface,
          pinned: true,
          expandedHeight: 130,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Poliçem',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            background: Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [sc.primaryContainer.withOpacity(.55), sc.surface]))),
          ),
          actions: [
            // Arama ikonu
            IconButton(
              icon: Icon(_aramaAcik ? Icons.search_off : Icons.search),
              tooltip: 'Ara',
              onPressed: () {
                setState(() {
                  _aramaAcik = !_aramaAcik;
                  if (!_aramaAcik) {
                    _aramaCtrl.clear();
                    _aramaListesi = [];
                  }
                });
              },
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: _filtreler.asMap().entries.map((e) {
                  final idx = e.key; final f = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(f.$1),
                      selected: idx == _tabIdx && !_aramaAcik,
                      onSelected: (_) {
                        setState(() { _tabIdx=idx; _aramaAcik=false; _aramaCtrl.clear(); });
                        _yukle();
                      },
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: idx==_tabIdx?FontWeight.w800:FontWeight.w500, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── Arama Kutusu ─────────────────────────────────
        if (_aramaAcik)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Yıl seçici satırı
                Row(children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: sc.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Arama yılı:', style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () { setState(() => _yil--); _aramaYap(); },
                  ),
                  Text('$_yil', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () { setState(() => _yil++); _aramaYap(); },
                  ),
                ]),
                const SizedBox(height: 6),
                // Arama alanı
                TextField(
                  controller: _aramaCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ad veya soyad yazın…',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    suffixIcon: _aramaCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _aramaCtrl.clear())
                      : null,
                    filled: true,
                    fillColor: sc.surfaceVariant.withOpacity(.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (_aramaCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _aramaYukleniyor
                    ? const LinearProgressIndicator()
                    : Text(
                        _aramaListesi.isEmpty
                          ? 'Sonuç bulunamadı'
                          : '${_aramaListesi.length} poliçe bulundu',
                        style: TextStyle(fontSize: 12, color: sc.primary, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          )
        else ...[
          // ── Tarih navigator ─────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Card(
                elevation: 0, color: sc.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _oncekiAy,
                      style: IconButton.styleFrom(
                        backgroundColor: sc.primary.withOpacity(.12), foregroundColor: sc.primary)),
                    Expanded(child: Column(children: [
                      Text(ayAdi, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: sc.onPrimaryContainer)),
                      if (_liste.isNotEmpty)
                        Text('${_liste.length} poliçe · ${fmt.format(toplam)}',
                          style: TextStyle(fontSize: 11, color: sc.primary, fontWeight: FontWeight.w600)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _sonrakiAy,
                      style: IconButton.styleFrom(
                        backgroundColor: sc.primary.withOpacity(.12), foregroundColor: sc.primary)),
                  ]),
                ),
              ),
            ),
          ),

          // ── Ay Şeridi ───────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 12,
                itemBuilder: (_, i) {
                  final m = i+1; final on = m==_ay;
                  final sayi = _sayilar[m] ?? 0;
                  return GestureDetector(
                    onTap: () { setState(()=>_ay=m); _yukle(); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: on ? sc.primary : sc.surfaceVariant,
                        borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_kisaAy(m), style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: on ? Colors.white : sc.onSurfaceVariant)),
                        if (sayi > 0) ...[
                          const SizedBox(width: 3),
                          Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: on ? Colors.white.withOpacity(.25) : sc.primary.withOpacity(.15),
                              shape: BoxShape.circle),
                            child: Center(child: Text('$sayi', style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.bold,
                              color: on ? Colors.white : sc.primary)))),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // ── Liste ─────────────────────────────────────────
        if (_yukl && !_aramaAcik)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (goruntuListe.isEmpty && !(_aramaYukleniyor))
          SliverFillRemaining(child: _bos(sc, _aramaAcik))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _PoliceKarti(
                police: goruntuListe[i],
                onTap: () async {
                  final ok = await Navigator.push<bool>(context, MaterialPageRoute(
                    builder: (_) => PoliceDetayScreen(policeId: goruntuListe[i].id!)));
                  if (ok==true) _yukle();
                },
                onYapildi:    () => _durumDegistir(goruntuListe[i], PoliceStatus.yapildi),
                onYapilamadi: () => _durumDegistir(goruntuListe[i], PoliceStatus.yapilamadi),
                onDahaSonra:  () => _durumDegistir(goruntuListe[i], PoliceStatus.dahaSonra),
              ),
              childCount: goruntuListe.length,
            )),
          ),
      ]),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _fabMenu,
        icon: const Icon(Icons.add),
        label: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 4,
      ),
    );
  }

  Widget _bos(ColorScheme sc, bool aramaModu) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: sc.surfaceVariant, shape: BoxShape.circle),
        child: Icon(aramaModu ? Icons.manage_search : Icons.folder_open_outlined,
          size: 48, color: sc.onSurfaceVariant)),
      const SizedBox(height: 16),
      Text(aramaModu ? 'Sonuç bulunamadı' : 'Bu ay için poliçe yok',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: sc.onSurfaceVariant, fontWeight: FontWeight.w600)),
    ]),
  );

  String _kisaAy(int m) => const ['','Oca','Şub','Mar','Nis','May','Haz',
    'Tem','Ağu','Eyl','Eki','Kas','Ara'][m];
}

// ══════════════════════════════════════════════════════
// FAB Menu BottomSheet
// ══════════════════════════════════════════════════════
class _FabMenuSheet extends StatelessWidget {
  final VoidCallback onTekEkle;
  final VoidCallback onTopluPdf;
  const _FabMenuSheet({required this.onTekEkle, required this.onTopluPdf});

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: sc.outlineVariant, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 18),
        Text('Poliçe Ekle', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),

        // Tek ekle
        _MenuTile(
          icon: Icons.post_add_outlined,
          iconBg: sc.primaryContainer,
          iconColor: sc.primary,
          title: 'Tek Poliçe Ekle',
          subtitle: 'Takvimden tarih seç ve formu doldur',
          onTap: onTekEkle,
        ),
        const SizedBox(height: 10),

        // Toplu PDF
        _MenuTile(
          icon: Icons.upload_file_outlined,
          iconBg: Colors.green.shade50,
          iconColor: Colors.green.shade700,
          title: 'Toplu PDF Yükle',
          subtitle: 'Telefondan PDF seç, aylara otomatik ata',
          onTap: onTopluPdf,
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.iconBg, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Material(
      color: sc.surfaceVariant.withOpacity(.4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: sc.onSurfaceVariant, height: 1.4)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: sc.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// Toplu PDF Bottom Sheet
// ══════════════════════════════════════════════════════
class _TopluPdfSheet extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onBitti;
  const _TopluPdfSheet({required this.db, required this.onBitti});

  @override State<_TopluPdfSheet> createState() => _TopluPdfSheetState();
}

class _TopluPdfSheetState extends State<_TopluPdfSheet> {
  List<_PdfItem> _pdfler = [];
  bool _seciliyor = false;

  final _aylar = ['','Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
    'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  final _aylarK = ['','Oca','Şub','Mar','Nis','May','Haz',
    'Tem','Ağu','Eyl','Eki','Kas','Ara'];

  Future<void> _pdfSec() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _seciliyor = true);
    final yeni = <_PdfItem>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final tahmin = _tahminEt(f.name);
      yeni.add(_PdfItem(
        dosyaAdi: f.name, dosyaYolu: f.path!, boyut: f.size,
        seciliAy: tahmin?.month ?? DateTime.now().month,
        seciliYil: tahmin?.year ?? DateTime.now().year,
        atandi: false,
      ));
    }
    setState(() { _pdfler.addAll(yeni); _seciliyor = false; });
  }

  DateTime? _tahminEt(String ad) {
    final low = ad.toLowerCase();
    final ayMap = {
      'ocak':1,'subat':2,'mart':3,'nisan':4,'mayis':5,'haziran':6,
      'temmuz':7,'agustos':8,'eylul':9,'ekim':10,'kasim':11,'aralik':12,
      'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
      'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12,
    };
    for (final e in ayMap.entries) {
      if (low.contains(e.key)) {
        final ym = RegExp(r'20\d{2}').firstMatch(low);
        return DateTime(ym!=null?int.parse(ym.group(0)!):DateTime.now().year, e.value);
      }
    }
    final r = RegExp(r'(\d{1,2})[-_./](\d{4})|(\d{4})[-_./](\d{1,2})').firstMatch(low);
    if (r != null) {
      if (r.group(1)!=null) {
        final ay=int.tryParse(r.group(1)!)??0;
        final yil=int.tryParse(r.group(2)!)??DateTime.now().year;
        if (ay>=1&&ay<=12) return DateTime(yil,ay);
      } else {
        final yil=int.tryParse(r.group(3)!)??DateTime.now().year;
        final ay=int.tryParse(r.group(4)!)??0;
        if (ay>=1&&ay<=12) return DateTime(yil,ay);
      }
    }
    return null;
  }

  Future<void> _ayDegistir(_PdfItem item) async {
    int secAy=item.seciliAy, secYil=item.seciliYil;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx,ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ay Seç', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left),
              style: IconButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.surfaceVariant),
              onPressed: () => ss(()=>secYil--)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$secYil', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            IconButton(icon: const Icon(Icons.chevron_right),
              style: IconButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.surfaceVariant),
              onPressed: () => ss(()=>secYil++)),
          ]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, childAspectRatio: 1.4, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: 12,
            itemBuilder: (_, i) {
              final m=i+1; final on=m==secAy;
              final sc=Theme.of(ctx).colorScheme;
              return GestureDetector(
                onTap: ()=>ss(()=>secAy=m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  decoration: BoxDecoration(
                    color: on?sc.primary:sc.surfaceVariant,
                    borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(_aylarK[m],
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                      color: on?Colors.white:sc.onSurfaceVariant)))));
            },
          ),
        ]),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () {
              setState((){item.seciliAy=secAy;item.seciliYil=secYil;});
              Navigator.pop(ctx);
            },
            child: const Text('Uygula')),
        ],
      )),
    );
  }

  Future<void> _ata(_PdfItem item) async {
    // Başlangıç tarihine göre poliçeleri ara
    final policeler = await widget.db.ayTumPolice(item.seciliYil, item.seciliAy);
    if (!mounted) return;
    if (policeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_aylar[item.seciliAy]} ${item.seciliYil} için poliçe bulunamadı'),
        backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    final secilen = await showDialog<Police>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${_aylar[item.seciliAy]} – Poliçe Seç',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: ListView.builder(
            itemCount: policeler.length,
            itemBuilder: (_, i) {
              final p = policeler[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6), elevation: 0,
                color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Text(p.tur.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(p.tamAd, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: Text('${p.goruntulenenTur} · ${p.sirket}',
                    style: const TextStyle(fontSize: 11)),
                  onTap: () => Navigator.pop(ctx, p),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('İptal')),
        ],
      ),
    );
    if (secilen == null) return;
    await widget.db.pdfYolu(secilen.id!, item.dosyaYolu);
    setState(() => item.atandi = true);
    widget.onBitti();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${item.dosyaAdi} → ${secilen.tamAd}'),
        backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }

  String _boyut(int b) => b<1024*1024 ? '${(b/1024).toStringAsFixed(0)} KB'
    : '${(b/1024/1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final atandi = _pdfler.where((p)=>p.atandi).length;
    return Container(
      decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: .7, maxChildSize: .95, minChildSize: .5,
        builder: (_, sc2) => Column(children: [
          // Handle + başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Column(children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: sc.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.upload_file_outlined, color: Colors.green.shade700, size: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Toplu PDF Yükleme',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Poliçe PDFlerini toplu içe aktar',
                    style: TextStyle(fontSize: 11, color: sc.onSurfaceVariant)),
                ])),
                IconButton(icon: const Icon(Icons.close), onPressed: ()=>Navigator.pop(context)),
              ]),
            ]),
          ),
          const Divider(height: 20),

          // İçerik
          Expanded(child: ListView(controller: sc2, padding: const EdgeInsets.symmetric(horizontal: 16), children: [

            // Bilgi banner
            Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: sc.primaryContainer.withOpacity(.5),
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 18, color: sc.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Sistem, dosya adından ay bilgisini otomatik okur.\n'
                  'Örn: "trafik_mart_2026.pdf" → Mart 2026\n'
                  'Poliçe başlangıç tarihine göre eşleştirir.',
                  style: TextStyle(fontSize: 11.5, color: sc.onPrimaryContainer, height: 1.5))),
              ]),
            ),

            // Seç butonu
            OutlinedButton.icon(
              onPressed: _seciliyor ? null : _pdfSec,
              icon: _seciliyor
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: sc.primary))
                : const Icon(Icons.folder_open),
              label: Text(_seciliyor ? 'Seçiliyor…' : '📱 Telefondan PDF Seç',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: sc.outline, width: 1.5)),
            ),

            if (_pdfler.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Özet şeridi
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sc.primaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_pdfler.length} dosya  ·  $atandi atandı',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc.primary))),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(()=>_pdfler.clear()),
                  icon: Icon(Icons.clear_all, size: 14, color: sc.error),
                  label: Text('Temizle', style: TextStyle(fontSize: 12, color: sc.error))),
              ]),
              const SizedBox(height: 8),

              // PDF listesi
              ..._pdfler.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: item.atandi ? Colors.green.shade50 : sc.surfaceVariant.withOpacity(.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.atandi ? Colors.green.shade200 : sc.outlineVariant,
                    width: 1.5)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Dosya adı
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red.shade600, size: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.dosyaAdi,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                      if (item.atandi)
                        const Icon(Icons.check_circle, color: Colors.green, size: 18)
                      else
                        Text(_boyut(item.boyut),
                          style: TextStyle(fontSize: 11, color: sc.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 8),
                    // Alt satır: Ay chip + buton
                    Row(children: [
                      GestureDetector(
                        onTap: item.atandi ? null : () => _ayDegistir(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: sc.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.calendar_month_outlined, size: 12, color: sc.onSecondaryContainer),
                            const SizedBox(width: 5),
                            Text('${_aylar[item.seciliAy]} ${item.seciliYil}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                color: sc.onSecondaryContainer)),
                            if (!item.atandi) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 10, color: sc.onSecondaryContainer),
                            ],
                          ]),
                        ),
                      ),
                      const Spacer(),
                      if (!item.atandi)
                        FilledButton.icon(
                          onPressed: () => _ata(item),
                          icon: const Icon(Icons.link, size: 13),
                          label: const Text('Poliçeye Ata', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))
                      else
                        OutlinedButton.icon(
                          onPressed: () => setState(()=>item.atandi=false),
                          icon: const Icon(Icons.undo, size: 12),
                          label: const Text('Geri Al', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: sc.tertiary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                    ]),
                  ]),
                ),
              )),
            ] else ...[
              const SizedBox(height: 32),
              Center(child: Column(children: [
                Icon(Icons.cloud_upload_outlined, size: 48, color: sc.onSurfaceVariant),
                const SizedBox(height: 10),
                Text('Henüz PDF seçilmedi', style: TextStyle(color: sc.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Birden fazla dosya seçebilirsiniz',
                  style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant.withOpacity(.7))),
              ])),
            ],
            const SizedBox(height: 20),
          ])),
        ]),
      ),
    );
  }
}

// ── PDF veri ─────────────────────────────────────────────
class _PdfItem {
  String dosyaAdi, dosyaYolu;
  int boyut, seciliAy, seciliYil;
  bool atandi;
  _PdfItem({required this.dosyaAdi, required this.dosyaYolu, required this.boyut,
    required this.seciliAy, required this.seciliYil, required this.atandi});
}

// ══════════════════════════════════════════════════════
// M3 Police Kartı
// ══════════════════════════════════════════════════════
class _PoliceKarti extends StatelessWidget {
  final Police police;
  final VoidCallback onTap, onYapildi, onYapilamadi, onDahaSonra;
  const _PoliceKarti({required this.police, required this.onTap,
    required this.onYapildi, required this.onYapilamadi, required this.onDahaSonra});

  static Color _bannerRenk(PoliceType t) => switch (t) {
    PoliceType.trafik || PoliceType.kasko           => const Color(0xFF1565C0),
    PoliceType.dask   || PoliceType.konut           => const Color(0xFF5D4037),
    PoliceType.ozelSaglik || PoliceType.tamamlayiciSaglik ||
    PoliceType.hayat  || PoliceType.ferdiKaza       => const Color(0xFFC62828),
    PoliceType.isyeri                               => const Color(0xFF37474F),
    PoliceType.nakliyat                             => const Color(0xFF00695C),
    PoliceType.tarim                                => const Color(0xFF33691E),
    PoliceType.seyahat                              => const Color(0xFF4527A0),
    _                                               => const Color(0xFF455A64),
  };

  @override
  Widget build(BuildContext context) {
    final sc    = Theme.of(context).colorScheme;
    final p     = police;
    final renk  = _bannerRenk(p.tur);
    final fmt   = DateFormat('d MMM y', 'tr');
    final pFmt  = NumberFormat.currency(locale:'tr',symbol:'₺',decimalDigits:0);
    final showBtn = p.durum==PoliceStatus.beklemede || p.durum==PoliceStatus.dahaSonra;
    final acil  = p.kalanGun<=10 && p.durum==PoliceStatus.beklemede;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: acil ? 3 : 1,
        shadowColor: acil ? Colors.red.withOpacity(.25) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Banner
            Container(
              height: 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [renk, renk.withOpacity(.75)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(p.tur.emoji, style: const TextStyle(fontSize: 22)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.tamAd, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                    Text('${p.goruntulenenTur} · ${p.sirket}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.8))),
                  ])),
                  _DurumBadge(durum: p.durum),
                ]),
              ),
            ),

            // Gövde
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _InfoChip(icon: Icons.calendar_today_outlined, text: fmt.format(p.bitisTarihi)),
                  const SizedBox(width: 12),
                  _InfoChip(icon: Icons.payments_outlined, text: pFmt.format(p.tutar)),
                  if (acil) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.kalanGun<=3 ? Colors.red.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.kalanGun<=3?Colors.red.shade300:Colors.amber.shade300)),
                      child: Text(
                        p.kalanGun<=0 ? '🔴 Bugün!' : '⚠️ ${p.kalanGun}g',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: p.kalanGun<=3?Colors.red.shade700:Colors.amber.shade800))),
                  ],
                ]),
                if (p.hatirlaticiTarihi != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(children: [
                      Icon(Icons.alarm_outlined, size: 12, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(DateFormat('d MMM – HH:mm','tr').format(p.hatirlaticiTarihi!),
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                if (showBtn) ...[
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: _ActBtn(label:'Yapıldı',icon:Icons.check_circle_outline,
                      color:Colors.green.shade600,onTap:onYapildi)),
                    const SizedBox(width: 5),
                    Expanded(child: _ActBtn(label:'Yapılamadı',icon:Icons.cancel_outlined,
                      color:Colors.red.shade600,onTap:onYapilamadi)),
                    const SizedBox(width: 5),
                    Expanded(child: _ActBtn(label:'Sonra',icon:Icons.schedule_outlined,
                      color:Colors.orange.shade700,onTap:onDahaSonra)),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DurumBadge extends StatelessWidget {
  final PoliceStatus durum;
  const _DurumBadge({required this.durum});
  @override Widget build(BuildContext context) {
    final (lbl,_) = switch (durum) {
      PoliceStatus.yapildi    => ('✓ Yapıldı',   Colors.green),
      PoliceStatus.yapilamadi => ('✗ Yapılamadı',Colors.red),
      PoliceStatus.dahaSonra  => ('◷ Sonra',      Colors.orange),
      _                       => ('⏳ Beklemede', Colors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(12)),
      child: Text(lbl, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoChip({required this.icon, required this.text});
  @override Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: sc.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant)),
    ]);
  }
}

class _ActBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActBtn({required this.label,required this.icon,required this.color,required this.onTap});
  @override Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 12),
    label: Text(label, style: const TextStyle(fontSize: 10)),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withOpacity(.5), width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
}
