// lib/screens/profil_screen.dart – v3.2 Material Design 3
// Profil + Toplu PDF Yükleme + M3 Tasarım
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart' show ThemeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});
  @override State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Profil
  String _ad = 'Acente Adı';
  String _unvan = 'Sigorta Acentesi';
  String _tel = '';
  String _email = '';
  bool _editing = false;
  late TextEditingController _adC, _unvanC, _telC, _emailC;

  // Stats
  Map<int, int> _aylikSayilar = {};
  int _toplamPolice = 0;
  int _seciliYil = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _adC = TextEditingController();
    _unvanC = TextEditingController();
    _telC = TextEditingController();
    _emailC = TextEditingController();
    _profilYukle();
    _istatistikYukle();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in [_adC, _unvanC, _telC, _emailC]) c.dispose();
    super.dispose();
  }

  Future<void> _profilYukle() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _ad    = p.getString('profil_ad')    ?? 'Acente Adı';
      _unvan = p.getString('profil_unvan') ?? 'Sigorta Acentesi';
      _tel   = p.getString('profil_tel')   ?? '';
      _email = p.getString('profil_email') ?? '';
      _adC.text = _ad; _unvanC.text = _unvan;
      _telC.text = _tel; _emailC.text = _email;
    });
  }

  Future<void> _profilKaydet() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('profil_ad',    _adC.text.trim());
    await p.setString('profil_unvan', _unvanC.text.trim());
    await p.setString('profil_tel',   _telC.text.trim());
    await p.setString('profil_email', _emailC.text.trim());
    setState(() {
      _ad = _adC.text.trim(); _unvan = _unvanC.text.trim();
      _tel = _telC.text.trim(); _email = _emailC.text.trim();
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('Profil kaydedildi')]),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _istatistikYukle() async {
    final s = await _db.aylikSayilar(_seciliYil);
    setState(() {
      _aylikSayilar = s;
      _toplamPolice = s.values.fold(0, (a, b) => a + b);
    });
  }

  // ── PDF Seç ─────────────────────────────────────────────
  Future<void> _pdfSec() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _yukleniyor = true);
    final yeni = <_PdfItem>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final tahmin = _dosyaAdindanTarih(f.name);
      yeni.add(_PdfItem(
        dosyaAdi: f.name, dosyaYolu: f.path!, boyut: f.size,
        tahminAy: tahmin?.month ?? DateTime.now().month,
        tahminYil: tahmin?.year  ?? DateTime.now().year,
        seciliAy:  tahmin?.month ?? DateTime.now().month,
        seciliYil: tahmin?.year  ?? DateTime.now().year,
        atandi: false,
      ));
    }
    setState(() { _pdfler.addAll(yeni); _yukleniyor = false; });
  }

  DateTime? _dosyaAdindanTarih(String ad) {
    final lower = ad.toLowerCase();
    final aylar = {
      'ocak':1,'subat':2,'mart':3,'nisan':4,'mayis':5,'haziran':6,
      'temmuz':7,'agustos':8,'eylul':9,'ekim':10,'kasim':11,'aralik':12,
      'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
      'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12,
    };
    for (final e in aylar.entries) {
      if (lower.contains(e.key)) {
        final ym = RegExp(r'20\d{2}').firstMatch(lower);
        return DateTime(ym != null ? int.parse(ym.group(0)!) : DateTime.now().year, e.value);
      }
    }
    final r = RegExp(r'(\d{1,2})[-_./](\d{4})|(\d{4})[-_./](\d{1,2})').firstMatch(lower);
    if (r != null) {
      if (r.group(1) != null) {
        final ay = int.tryParse(r.group(1)!) ?? 0;
        final yil = int.tryParse(r.group(2)!) ?? DateTime.now().year;
        if (ay >= 1 && ay <= 12) return DateTime(yil, ay);
      } else {
        final yil = int.tryParse(r.group(3)!) ?? DateTime.now().year;
        final ay  = int.tryParse(r.group(4)!) ?? 0;
        if (ay >= 1 && ay <= 12) return DateTime(yil, ay);
      }
    }
    return null;
  }

  String _ayAdi(int m) => const ['','Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
    'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'][m];
  String _ayKisa(int m) => const ['','Oca','Şub','Mar','Nis','May','Haz',
    'Tem','Ağu','Eyl','Eki','Kas','Ara'][m];
  String _boyutStr(int b) => b < 1024*1024 ? '${(b/1024).toStringAsFixed(0)} KB'
    : '${(b/1024/1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: sc.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── M3 Large TopAppBar ──────────────────────────
            SliverAppBar.large(
              backgroundColor: sc.surface,
              expandedHeight: 160,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text('Profil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [sc.primaryContainer, sc.surface])),
                ),
              ),
              actions: [
                if (!_editing)
                  Padding(padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Düzenle'),
                    ))
                else
                  Padding(padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.icon(
                      onPressed: _profilKaydet,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Kaydet'),
                    )),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // ── Profil Kartı ──────────────────────────
                Card(
                  elevation: 0,
                  color: sc.surfaceVariant.withOpacity(.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: !_editing
                      ? _profilGorunum(sc)
                      : _profilForm(sc),
                  ),
                ),
                const SizedBox(height: 16),


                // ── Gece Modu ────────────────────────────
                ListenableBuilder(
                  listenable: ThemeNotifier(),
                  builder: (_, __) => Card(
                    elevation: 0,
                    color: sc.surfaceVariant.withOpacity(.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: ThemeNotifier().dark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F0FF),
                          borderRadius: BorderRadius.circular(12)),
                        child: Icon(
                          ThemeNotifier().dark ? Icons.dark_mode : Icons.light_mode_outlined,
                          color: sc.primary, size: 20)),
                      title: const Text('Gece Modu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Text(ThemeNotifier().dark ? 'Açık — koyu tema aktif' : 'Kapalı — açık tema aktif',
                        style: TextStyle(fontSize: 11, color: sc.onSurfaceVariant)),
                      trailing: Switch.adaptive(
                        value: ThemeNotifier().dark,
                        onChanged: (_) => ThemeNotifier().toggle(),
                        activeColor: sc.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── İstatistik Satırı ─────────────────────
                Row(children: [
                  Expanded(child: _StatKart(
                    icon: Icons.description_outlined,
                    deger: '$_toplamPolice',
                    etiket: 'Toplam Poliçe',
                    renk: sc.primary,
                    bgRenk: sc.primaryContainer,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatKart(
                    icon: Icons.trending_up,
                    deger: '${(_aylikSayilar.values.isEmpty ? 0 : _aylikSayilar.values.reduce((a,b)=>a>b?a:b))}',
                    etiket: 'En Yoğun Ay',
                    renk: Colors.green.shade700,
                    bgRenk: Colors.green.shade50,
                  )),
                ]),
                const SizedBox(height: 20),

                // ── Bar Chart Kartı ───────────────────────
                Card(
                  elevation: 0,
                  color: sc.surfaceVariant.withOpacity(.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: List.generate(12, (i) {
                        final m = i + 1;
                        final sayi = _aylikSayilar[m] ?? 0;
                        final mx = _aylikSayilar.values.isEmpty ? 1
                          : _aylikSayilar.values.reduce((a,b) => a > b ? a : b);
                        final w = mx == 0 ? 0.0 : sayi / mx;
                        final isThisMonth = m == DateTime.now().month && _seciliYil == DateTime.now().year;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            SizedBox(width: 32,
                              child: Text(_ayKisa(m), style: TextStyle(
                                fontSize: 11, fontWeight: isThisMonth ? FontWeight.w900 : FontWeight.w600,
                                color: isThisMonth ? sc.primary : sc.onSurfaceVariant))),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: w, minHeight: 16,
                                backgroundColor: sc.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation(
                                  isThisMonth ? sc.primary : sc.primary.withOpacity(.45))))),
                            const SizedBox(width: 10),
                            SizedBox(width: 24, child: Text('$sayi',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800,
                                color: isThisMonth ? sc.primary : sc.onSurfaceVariant))),
                          ]),
                        );
                      }),
                    ),
                  ),
                ),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilGorunum(ColorScheme sc) => Column(children: [
    CircleAvatar(radius: 40, backgroundColor: sc.primaryContainer,
      child: Text(_ad.isNotEmpty ? _ad[0].toUpperCase() : 'A',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: sc.primary))),
    const SizedBox(height: 14),
    Text(_ad, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(_unvan, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
    if (_tel.isNotEmpty) ...[
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.phone_outlined, size: 14, color: sc.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(_tel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sc.onSurfaceVariant)),
      ]),
    ],
    if (_email.isNotEmpty) ...[
      const SizedBox(height: 3),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.mail_outline, size: 14, color: sc.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(_email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sc.onSurfaceVariant)),
      ]),
    ],
  ]);

  Widget _profilForm(ColorScheme sc) => Column(children: [
    _formAlan(_adC, 'Ad / Acente Adı', Icons.business_outlined),
    const SizedBox(height: 10),
    _formAlan(_unvanC, 'Unvan', Icons.badge_outlined),
    const SizedBox(height: 10),
    _formAlan(_telC, 'Telefon', Icons.phone_outlined, tip: TextInputType.phone),
    const SizedBox(height: 10),
    _formAlan(_emailC, 'E-posta', Icons.mail_outline, tip: TextInputType.emailAddress),
  ]);

  Widget _formAlan(TextEditingController c, String l, IconData i, {TextInputType? tip}) =>
    TextField(controller: c, keyboardType: tip,
      decoration: InputDecoration(
        labelText: l, prefixIcon: Icon(i, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface));
}

// ── Poliçe Seç Bottom Sheet ────────────────────────────────
class _StatKart extends StatelessWidget {
  final IconData icon;
  final String deger, etiket;
  final Color renk, bgRenk;
  const _StatKart({required this.icon, required this.deger, required this.etiket,
    required this.renk, required this.bgRenk});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0, color: bgRenk,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: renk, size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deger, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: renk)),
          Text(etiket, style: TextStyle(fontSize: 10, color: renk.withOpacity(.8), fontWeight: FontWeight.w600)),
        ]),
      ])),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: sc.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sc.onSurfaceVariant)),
        ])),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// Veri sınıfı
class _PdfItem {
  String dosyaAdi, dosyaYolu;
  int boyut, tahminAy, tahminYil, seciliAy, seciliYil;
  bool atandi;
  _PdfItem({required this.dosyaAdi, required this.dosyaYolu, required this.boyut,
    required this.tahminAy, required this.tahminYil,
    required this.seciliAy, required this.seciliYil, required this.atandi});
}
