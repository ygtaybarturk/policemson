// lib/screens/takvim_screen.dart – M3 Redesign
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kWarn    = Color(0xFFE65100);
const _kErr     = Color(0xFFC62828);
// Dinamik: context.bgCard, context.bgScaffold, context.textMain vb.

class TakvimScreen extends StatefulWidget {
  final int? policeId;
  final void Function(DateTime, String, Police)? onHatirlaticiSec;

  const TakvimScreen({super.key, this.policeId, this.onHatirlaticiSec});

  @override State<TakvimScreen> createState() => _TakvimScreenState();
}

class _TakvimScreenState extends State<TakvimScreen> {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  int _yil = DateTime.now().year;
  int _ay  = DateTime.now().month;

  DateTime?       _seciliGun;
  List<Police>    _ayListe       = [];
  List<Police>    _tumPoliceler  = [];   // tüm poliçeler (not ekle seçimi için)
  List<Police>    _gunListe      = [];
  Map<int,List<Police>> _ayEtkinlikleri = {};
  bool _yukl = true;

  static const _aylar  = ['','Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
  static const _aylarK = ['','Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
  static const _gunler = ['Pt','Sa','Ça','Pe','Cu','Ct','Pz'];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukl = true);
    final liste = await _db.aylik(_yil, _ay);
    // Not ekleme için tüm yılın poliçelerini yükle
    final tumListe = await _db.yillikTumPoliceler(_yil);
    final etk = <int, List<Police>>{};
    for (final p in liste) {
      final gun = p.bitisTarihi.day;
      etk.putIfAbsent(gun, () => []).add(p);
      if (p.hatirlaticiTarihi != null) {
        final hgun = p.hatirlaticiTarihi!.day;
        if (p.hatirlaticiTarihi!.month == _ay && p.hatirlaticiTarihi!.year == _yil) {
          etk.putIfAbsent(hgun, () => []);
        }
      }
    }
    setState(() {
      _ayListe = liste;
      _tumPoliceler = tumListe;
      _ayEtkinlikleri = etk;
      _yukl = false;
    });
    if (_seciliGun != null) _gunSecildi(_seciliGun!);
  }

  void _gunSecildi(DateTime gun) {
    final liste = _ayListe.where((p) {
      if (p.bitisTarihi.day == gun.day &&
          p.bitisTarihi.month == gun.month &&
          p.bitisTarihi.year == gun.year) return true;
      if (p.hatirlaticiTarihi != null &&
          p.hatirlaticiTarihi!.day == gun.day &&
          p.hatirlaticiTarihi!.month == gun.month &&
          p.hatirlaticiTarihi!.year == gun.year) return true;
      return false;
    }).toList();
    setState(() { _seciliGun = gun; _gunListe = liste; });
  }

  void _oncekiAy() { setState(() { if (_ay==1){_ay=12;_yil--;}else _ay--; _seciliGun=null; _gunListe=[]; }); _yukle(); }
  void _sonrakiAy() { setState(() { if (_ay==12){_ay=1;_yil++;}else _ay++; _seciliGun=null; _gunListe=[]; }); _yukle(); }

  void _notEkle() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotSheet(
        gun: _seciliGun ?? DateTime(_yil, _ay),
        policeler: _tumPoliceler,
        onKaydet: (tarih, not, police) async {
          final guncellenmis = police.copyWith(hatirlaticiTarihi: tarih, hatirlaticiNotu: not);
          await _db.guncelle(guncellenmis);
          await _notif.policeIcinIptal(guncellenmis.id!);
          await _notif.dahaSonraHatirlatici(guncellenmis);
          _yukle();
          if (widget.onHatirlaticiSec != null) widget.onHatirlaticiSec!(tarih, not, guncellenmis);
          if (mounted && widget.policeId != null) Navigator.pop(context);
        },
        policeId: widget.policeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool modal = widget.policeId != null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: modal ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: RichText(text: const TextSpan(
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: context.textMain),
          children: [
            TextSpan(text: 'CRM '),
            TextSpan(text: 'Takvimi', style: TextStyle(color: _kPrimary)),
          ],
        )),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: _kPrimary),
            onPressed: _notEkle,
          ),
        ],
      ),
      body: _yukl
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // ── Ay nav ──
              Container(
                color: Colors.white,
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
              // ── Gün başlıkları ──
              Container(
                color: context.bgScaffold,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(children: _gunler.map((g) => Expanded(
                  child: Text(g,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: (g=='Ct'||g=='Pz') ? _kWarn : context.textSub,
                    ),
                  ),
                )).toList()),
              ),
              // ── Takvim grid ──
              _TakvimGrid(
                yil: _yil, ay: _ay,
                etkinlikleri: _ayEtkinlikleri,
                seciliGun: _seciliGun,
                onGunSec: _gunSecildi,
              ),
              Divider(height: 1, color: context.border),
              // ── Seçili gün başlığı ──
              if (_seciliGun != null)
                Container(
                  color: context.bgCard,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    Text(
                      DateFormat('d MMMM y', 'tr').format(_seciliGun!),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.textMain),
                    ),
                    const SizedBox(width: 8),
                    if (_gunListe.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_gunListe.length} olay',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kWarn),
                        ),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _notEkle,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Not Ekle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(foregroundColor: _kPrimary),
                    ),
                  ]),
                ),
              // ── Etkinlik listesi ──
              Expanded(child: _gunListe.isEmpty && _seciliGun != null
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.event_note_outlined, size: 40, color: _kText2.withOpacity(0.4)),
                    const SizedBox(height: 10),
                    const Text('Bu gün için etkinlik yok', style: TextStyle(color: _kText2, fontSize: 13)),
                  ]))
                : _seciliGun == null
                  ? _tumEtkinlikler()
                  : _etkinlikListesi(_gunListe),
              ),
            ]),
    );
  }

  Widget _tumEtkinlikler() {
    if (_ayListe.isEmpty) return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_month_outlined, size: 40, color: _kText2.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('Bu ay için poliçe yok', style: TextStyle(color: _kText2)),
      ]),
    );
    return _etkinlikListesi(_ayListe);
  }

  Widget _etkinlikListesi(List<Police> liste) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: liste.length,
      itemBuilder: (_, i) => _EtkinlikKart(police: liste[i], yil: _yil, ay: _ay),
    );
  }
}

// ── Takvim Grid ─────────────────────────────────────────────
class _TakvimGrid extends StatelessWidget {
  final int yil, ay;
  final Map<int, List<Police>> etkinlikleri;
  final DateTime? seciliGun;
  final void Function(DateTime) onGunSec;

  const _TakvimGrid({
    required this.yil, required this.ay, required this.etkinlikleri,
    required this.seciliGun, required this.onGunSec,
  });

  @override
  Widget build(BuildContext context) {
    final ilkGun = DateTime(yil, ay, 1);
    final baslangic = ilkGun.weekday - 1; // Pzt=0
    final sonGun = DateTime(yil, ay + 1, 0).day;
    final bugun = DateTime.now();
    final cells = baslangic + sonGun;
    final satirSayisi = (cells / 7).ceil();

    return Container(
      color: context.bgScaffold,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(children: List.generate(satirSayisi, (satir) {
        return Row(children: List.generate(7, (sutun) {
          final idx = satir * 7 + sutun;
          final gun = idx - baslangic + 1;
          if (gun < 1 || gun > sonGun) return const Expanded(child: SizedBox(height: 40));

          final tarih = DateTime(yil, ay, gun);
          final bugunMu = tarih.day == bugun.day && tarih.month == bugun.month && tarih.year == bugun.year;
          final seciliMu = seciliGun != null && tarih.day == seciliGun!.day && tarih.month == seciliGun!.month && tarih.year == seciliGun!.year;
          final haftatatiMi = sutun >= 5;
          final etkinlikVar = etkinlikleri.containsKey(gun);

          return Expanded(
            child: GestureDetector(
              onTap: () => onGunSec(tarih),
              child: Container(
                height: 40,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: seciliMu ? _kPrimary : bugunMu ? const Color(0xFFE3F0FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    '$gun',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: seciliMu ? Colors.white
                           : bugunMu ? _kPrimary
                           : haftatatiMi ? _kWarn
                           : context.textMain,
                    ),
                  ),
                  if (etkinlikVar) Container(
                    width: 4, height: 4,
                    decoration: BoxDecoration(
                      color: seciliMu ? Colors.white.withOpacity(0.8) : _kWarn,
                      shape: BoxShape.circle,
                    ),
                  ),
                ]),
              ),
            ),
          );
        }));
      })),
    );
  }
}

// ── Etkinlik Kartı ───────────────────────────────────────────
class _EtkinlikKart extends StatelessWidget {
  final Police police;
  final int yil, ay;
  const _EtkinlikKart({required this.police, required this.yil, required this.ay});

  @override
  Widget build(BuildContext context) {
    final p = police;
    final bitisMi = p.bitisTarihi.month == ay && p.bitisTarihi.year == yil;
    final hatirMi = p.hatirlaticiTarihi != null &&
        p.hatirlaticiTarihi!.month == ay && p.hatirlaticiTarihi!.year == yil;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: bitisMi ? _kErr : _kWarn, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: bitisMi ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(p.tur.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.tamAd, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.textMain)),
            Text('\${p.goruntulenenTur} · \${p.sirket}', style: TextStyle(fontSize: 10.5, color: context.textSub)),
            const SizedBox(height: 3),
            if (bitisMi) Row(children: [
              Icon(Icons.event_busy_outlined, size: 11, color: _kErr),
              const SizedBox(width: 3),
              Text(
                'Bitiş: ${DateFormat('d MMM y', 'tr').format(p.bitisTarihi)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kErr),
              ),
            ]),
            if (hatirMi) Row(children: [
              Icon(Icons.alarm_outlined, size: 11, color: _kWarn),
              const SizedBox(width: 3),
              Text(
                'Hatırlatıcı: ${DateFormat('d MMM – HH:mm', 'tr').format(p.hatirlaticiTarihi!)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kWarn),
              ),
            ]),
          ])),
          _DurumChip(durum: p.durum),
        ]),
      ),
    );
  }
}

class _DurumChip extends StatelessWidget {
  final PoliceStatus durum;
  const _DurumChip({required this.durum});
  @override
  Widget build(BuildContext context) {
    final (lbl, bg, fg) = switch (durum) {
      PoliceStatus.yapildi    => ('✓', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      PoliceStatus.yapilamadi => ('✗', const Color(0xFFFFEBEE), _kErr),
      PoliceStatus.dahaSonra  => ('⏰', const Color(0xFFFFF3E0), _kWarn),
      _                       => ('⏳', const Color(0xFFE3F0FF), _kPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(lbl, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w800)),
    );
  }
}

// ── Not Sheet ────────────────────────────────────────────────
class _NotSheet extends StatefulWidget {
  final DateTime gun;
  final List<Police> policeler;
  final void Function(DateTime, String, Police) onKaydet;
  final int? policeId;

  const _NotSheet({required this.gun, required this.policeler, required this.onKaydet, this.policeId});
  @override State<_NotSheet> createState() => _NotSheetState();
}

class _NotSheetState extends State<_NotSheet> {
  Police? _seciliPolice;
  final _notCtrl = TextEditingController();
  TimeOfDay _saat = const TimeOfDay(hour: 9, minute: 0);
  late DateTime _tarih;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _tarih = widget.gun;
    if (widget.policeId != null) {
      try { _seciliPolice = widget.policeler.firstWhere((p) => p.id == widget.policeId); }
      catch (_) {}
    }
  }

  @override void dispose() { _notCtrl.dispose(); super.dispose(); }

  Future<void> _saatSec() async {
    final s = await showTimePicker(context: context, initialTime: _saat);
    if (s != null) setState(() => _saat = s);
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _kaydet() async {
    if (_seciliPolice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Lütfen bir poliçe seçin'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _kaydediliyor = true);
    final tam = DateTime(_tarih.year, _tarih.month, _tarih.day, _saat.hour, _saat.minute);
    widget.onKaydet(tam, _notCtrl.text.trim(), _seciliPolice!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Hatırlatıcı Ekle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: context.textMain)),
            const SizedBox(height: 16),

            // Poliçe seç
            if (widget.policeId == null) ...[
              const Text('Poliçe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText2)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Police>(
                    value: _seciliPolice,
                    isExpanded: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    hint: const Text('Poliçe seçin…', style: TextStyle(color: _kText2, fontSize: 13)),
                    items: widget.policeler.map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.tur.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Flexible(child: Text(
                            '${p.tamAd} – ${p.goruntulenenTur}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          )),
                        ],
                      ),
                    )).toList(),
                    onChanged: (p) => setState(() => _seciliPolice = p),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ] else if (_seciliPolice != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Text(_seciliPolice!.tur.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_seciliPolice!.tamAd, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('${_seciliPolice!.goruntulenenTur} · ${_seciliPolice!.sirket}',
                      style: const TextStyle(fontSize: 11, color: _kText2)),
                    Text('Bitiş: ${DateFormat('d MMM y', 'tr').format(_seciliPolice!.bitisTarihi)} · ${_seciliPolice!.kalanGun} gün kaldı',
                      style: TextStyle(fontSize: 10, color: _seciliPolice!.kalanGun <= 10 ? _kErr : _kText2, fontWeight: FontWeight.w700)),
                  ])),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            // Tarih + Saat
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tarih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText2)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _tarihSec,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.border),
                      borderRadius: BorderRadius.circular(12),
                      color: context.bgScaffold,
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 15, color: _kPrimary),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM y', 'tr').format(_tarih),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Saat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText2)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _saatSec,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.border),
                      borderRadius: BorderRadius.circular(12),
                      color: context.bgScaffold,
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time_outlined, size: 15, color: _kPrimary),
                      const SizedBox(width: 8),
                      Text(_saat.format(context),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 14),

            // Not
            const Text('Not (isteğe bağlı)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText2)),
            const SizedBox(height: 6),
            TextField(
              controller: _notCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Hatırlatıcı notu…',
                hintStyle: const TextStyle(color: _kText2, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Kaydet
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: _kaydediliyor
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.alarm_add_outlined),
                label: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Hatırlatıcı Kur',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: FilledButton.styleFrom(
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
