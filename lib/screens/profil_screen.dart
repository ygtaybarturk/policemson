// lib/screens/profil_screen.dart – iOS Minimal Redesign
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../main.dart' show ThemeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
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

  String _ad = 'Acente Adı';
  String _unvan = 'Sigorta Acentesi';
  String _tel = '', _email = '';
  bool _editing = false;
  late TextEditingController _adC, _unvanC, _telC, _emailC;

  Map<int, int> _aylikSayilar = {};
  int _toplamPolice = 0;
  int _seciliYil = DateTime.now().year;
  bool _yukleniyor = false;
  List<_PdfItem> _pdfler = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _adC = TextEditingController(); _unvanC = TextEditingController();
    _telC = TextEditingController(); _emailC = TextEditingController();
    _profilYukle(); _istatistikYukle(); _fadeCtrl.forward();
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
      _ad = p.getString('profil_ad') ?? 'Acente Adı';
      _unvan = p.getString('profil_unvan') ?? 'Sigorta Acentesi';
      _tel = p.getString('profil_tel') ?? '';
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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.white, size: 17), SizedBox(width: 8), Text('Profil kaydedildi', style: TextStyle(fontWeight: FontWeight.w600))]),
      backgroundColor: kSuccess, behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _istatistikYukle() async {
    final s = await _db.aylikSayilar(_seciliYil);
    setState(() { _aylikSayilar = s; _toplamPolice = s.values.fold(0, (a, b) => a + b); });
  }

  Future<void> _pdfSec() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _yukleniyor = true);
    final yeni = <_PdfItem>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final tahmin = _dosyaAdindanTarih(f.name);
      yeni.add(_PdfItem(
        dosyaAdi: f.name, dosyaYolu: f.path!, boyut: f.size,
        tahminAy: tahmin?.month ?? DateTime.now().month,
        tahminYil: tahmin?.year ?? DateTime.now().year,
        seciliAy: tahmin?.month ?? DateTime.now().month,
        seciliYil: tahmin?.year ?? DateTime.now().year, atandi: false,
      ));
    }
    setState(() { _pdfler.addAll(yeni); _yukleniyor = false; });
  }

  DateTime? _dosyaAdindanTarih(String ad) {
    final lower = ad.toLowerCase();
    final aylar = {'ocak':1,'subat':2,'mart':3,'nisan':4,'mayis':5,'haziran':6,'temmuz':7,'agustos':8,'eylul':9,'ekim':10,'kasim':11,'aralik':12,'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
    for (final e in aylar.entries) {
      if (lower.contains(e.key)) {
        final ym = RegExp(r'20\d{2}').firstMatch(lower);
        return DateTime(ym != null ? int.parse(ym.group(0)!) : DateTime.now().year, e.value);
      }
    }
    return null;
  }

  String _ayKisa(int m) => const ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'][m];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── iOS tarzı Collapsing Header ────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: kBgCard,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text('Profil', style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: kText, letterSpacing: -0.5)),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [kPrimary.withOpacity(0.08), kBgCard],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Avatar
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [kPrimary, kPrimaryLight]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: kPrimary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: Center(child: Text(
                            _ad.isNotEmpty ? _ad[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                          )),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_ad, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText)),
                          const SizedBox(height: 3),
                          Text(_unvan, style: const TextStyle(fontSize: 12.5, color: kPrimary, fontWeight: FontWeight.w600)),
                        ])),
                      ]),
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(padding: const EdgeInsets.only(right: 12),
                  child: _editing
                      ? FilledButton.icon(
                          onPressed: _profilKaydet,
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Kaydet'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kSuccess, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _editing = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: kPrimaryGlow, borderRadius: BorderRadius.circular(12)),
                            child: const Row(children: [
                              Icon(Icons.edit_outlined, size: 15, color: kPrimary),
                              SizedBox(width: 5),
                              Text('Düzenle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
                            ]),
                          ),
                        )),
              ],
              bottom: PreferredSize(preferredSize: const Size.fromHeight(0.8),
                  child: Container(height: 0.8, color: kBorder)),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([

                // ── Profil kartı ──────────────────────────
                if (_editing) ...[
                  _SectionTitle('Profil Bilgileri'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDeco(),
                    child: Column(children: [
                      _FormField(_adC,    'Ad / Acente Adı', Icons.business_rounded),
                      const SizedBox(height: 10),
                      _FormField(_unvanC, 'Unvan',           Icons.badge_rounded),
                      const SizedBox(height: 10),
                      _FormField(_telC,   'Telefon',         Icons.phone_rounded, tip: TextInputType.phone),
                      const SizedBox(height: 10),
                      _FormField(_emailC, 'E-posta',         Icons.mail_rounded,  tip: TextInputType.emailAddress),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // İletişim bilgileri
                  if (_tel.isNotEmpty || _email.isNotEmpty) ...[
                    _SectionTitle('İletişim'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDeco(),
                      child: Column(children: [
                        if (_tel.isNotEmpty)
                          _InfoRow(Icons.phone_rounded, 'Telefon', _tel),
                        if (_tel.isNotEmpty && _email.isNotEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(color: kDivider, height: 1)),
                        if (_email.isNotEmpty)
                          _InfoRow(Icons.mail_rounded, 'E-posta', _email),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],

                // ── İstatistik satırı ─────────────────────
                _SectionTitle('İstatistikler'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(Icons.shield_rounded, '$_toplamPolice', 'Toplam Poliçe', kPrimary)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(Icons.trending_up_rounded,
                      '${_aylikSayilar.values.isEmpty ? 0 : _aylikSayilar.values.reduce((a,b) => a > b ? a : b)}',
                      'En Yoğun Ay', kSuccess)),
                ]),
                const SizedBox(height: 20),

                // ── Bar chart ─────────────────────────────
                _SectionTitle('Aylık Üretim'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: _cardDeco(),
                  child: Column(
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final sayi = _aylikSayilar[m] ?? 0;
                      final mx = _aylikSayilar.values.isEmpty ? 1
                          : _aylikSayilar.values.reduce((a, b) => a > b ? a : b);
                      final w = mx == 0 ? 0.0 : sayi / mx;
                      final isNow = m == DateTime.now().month && _seciliYil == DateTime.now().year;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(children: [
                          SizedBox(width: 30, child: Text(_ayKisa(m), style: TextStyle(
                            fontSize: 11, fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                            color: isNow ? kPrimary : kTextSub))),
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: w, minHeight: 14,
                              backgroundColor: kBgCard2,
                              valueColor: AlwaysStoppedAnimation(isNow ? kPrimary : kPrimary.withOpacity(0.4))),
                          )),
                          const SizedBox(width: 8),
                          SizedBox(width: 22, child: Text('$sayi', textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                color: isNow ? kPrimary : kTextSub))),
                        ]),
                      );
                    }),
                  ),
                ),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: kBgCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: kBorder, width: 0.8),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
    ],
  );
}

Widget _SectionTitle(String t) => Text(t,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kTextSub, letterSpacing: 0.3));

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, val;
  const _InfoRow(this.icon, this.label, this.val);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 34, height: 34,
      decoration: BoxDecoration(color: kPrimaryGlow, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 16, color: kPrimary)),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10.5, color: kTextHint, fontWeight: FontWeight.w600)),
      Text(val, style: const TextStyle(fontSize: 13.5, color: kText, fontWeight: FontWeight.w600)),
    ]),
  ]);
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl; final String label; final IconData icon; final TextInputType? tip;
  const _FormField(this.ctrl, this.label, this.icon, {this.tip});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tip,
    style: const TextStyle(fontSize: 14, color: kText),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: kTextSub),
      filled: true, fillColor: kBgCard2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kPrimary, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon; final String deger, etiket; final Color renk;
  const _StatCard(this.icon, this.deger, this.etiket, this.renk);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: renk.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: renk.withOpacity(0.15)),
    ),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: renk.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: renk, size: 22)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deger, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: renk, letterSpacing: -0.5)),
        Text(etiket, style: TextStyle(fontSize: 10, color: renk.withOpacity(0.8), fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Widget? trailing;
  const _SectionHeader({required this.icon, required this.title, required this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: kPrimary, size: 18),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kText)),
      Text(subtitle, style: const TextStyle(fontSize: 11.5, color: kTextSub)),
    ])),
    if (trailing != null) trailing!,
  ]);
}

class _StatKart extends StatelessWidget {
  final IconData icon; final String deger, etiket; final Color renk, bgRenk;
  const _StatKart({required this.icon, required this.deger, required this.etiket, required this.renk, required this.bgRenk});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: bgRenk, borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      Icon(icon, color: renk, size: 26), const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deger, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: renk)),
        Text(etiket, style: TextStyle(fontSize: 10, color: renk.withOpacity(0.8), fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

class _PdfItem {
  String dosyaAdi, dosyaYolu; int boyut, tahminAy, tahminYil, seciliAy, seciliYil; bool atandi;
  _PdfItem({required this.dosyaAdi, required this.dosyaYolu, required this.boyut, required this.tahminAy, required this.tahminYil, required this.seciliAy, required this.seciliYil, required this.atandi});
}
