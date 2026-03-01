// lib/screens/takvim_screen.dart – v3 FIX
// 3 mod:
//   1) Normal takvim (navigation bar'dan açılır)
//   2) yeniPoliceFormu=true → FAB'dan açılır, tarih seç → form + bildirim
//   3) policeId verilir    → Daha Sonra modu
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class TakvimScreen extends StatefulWidget {
  final int?     policeId;           // Daha Sonra modu
  final bool     yeniPoliceFormu;    // FAB modu
  final Function(DateTime, String, Police)? onHatirlaticiSec;
  final VoidCallback? onPoliceEklendi;

  const TakvimScreen({
    super.key,
    this.policeId,
    this.yeniPoliceFormu = false,
    this.onHatirlaticiSec,
    this.onPoliceEklendi,
  });

  @override State<TakvimScreen> createState() => _TakvimScreenState();
}

class _TakvimScreenState extends State<TakvimScreen> {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  DateTime _odak   = DateTime.now();
  DateTime _secili = DateTime.now();
  Map<DateTime, List<_Olay>> _olaylar     = {};
  List<_Olay>                _gunOlaylari = [];
  Police? _dahaSonraPolice;

  // Form
  final _formKey    = GlobalKey<FormState>();
  final _adCtrl     = TextEditingController();
  final _soyadCtrl  = TextEditingController();
  final _telCtrl    = TextEditingController();
  final _sirketCtrl = TextEditingController();
  final _tutarCtrl  = TextEditingController();
  final _notCtrl    = TextEditingController();
  PoliceType _seciliTur = PoliceType.trafik;
  DateTime?  _bitisT;
  TimeOfDay  _saat = const TimeOfDay(hour: 10, minute: 0);

  bool get _dahaSonraModu  => widget.policeId != null;
  bool get _yeniPoliceModu => widget.yeniPoliceFormu;

  @override
  void initState() {
    super.initState();
    if (_dahaSonraModu) {
      _db.getir(widget.policeId!).then((p) => setState(() => _dahaSonraPolice = p));
    }
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [_adCtrl, _soyadCtrl, _telCtrl, _sirketCtrl, _tutarCtrl, _notCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final liste = await _db.aylik(DateTime.now().year, DateTime.now().month);
    final map   = <DateTime, List<_Olay>>{};
    for (final p in liste) {
      final k = _sz(p.bitisTarihi);
      map.putIfAbsent(k, () => []).add(_Olay(p, false));
      if (p.hatirlaticiTarihi != null) {
        final k2 = _sz(p.hatirlaticiTarihi!);
        map.putIfAbsent(k2, () => []).add(_Olay(p, true));
      }
    }
    setState(() {
      _olaylar     = map;
      _gunOlaylari = map[_sz(_secili)] ?? [];
    });
  }

  DateTime _sz(DateTime d) => DateTime(d.year, d.month, d.day);

  void _gunSec(DateTime s, DateTime o) {
    setState(() {
      _secili      = s;
      _odak        = o;
      _gunOlaylari = _olaylar[_sz(s)] ?? [];
    });
    // Her iki modda da tarih seçilince form aç
    if (_dahaSonraModu || _yeniPoliceModu) {
      _formGoster(s);
    }
  }

  // ══════════════════════════════════════════════════════════
  //  FORM  (hem Yeni Poliçe hem Daha Sonra için ortak)
  // ══════════════════════════════════════════════════════════
  Future<void> _formGoster(DateTime gun) async {
    // Daha Sonra modunda mevcut müşteriyi önceden doldur
    if (_dahaSonraModu && _dahaSonraPolice != null) {
      _adCtrl.text     = _dahaSonraPolice!.musteriAdi;
      _soyadCtrl.text  = _dahaSonraPolice!.soyadi;
      _telCtrl.text    = _dahaSonraPolice!.telefon;
      _sirketCtrl.text = _dahaSonraPolice!.sirket;
      _tutarCtrl.text  = _dahaSonraPolice!.tutar == 0 ? '' : _dahaSonraPolice!.tutar.toStringAsFixed(0);
      _seciliTur       = _dahaSonraPolice!.tur;
      _bitisT          = _dahaSonraPolice!.bitisTarihi;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          final scheme = Theme.of(ctx).colorScheme;
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _yeniPoliceModu ? scheme.primaryContainer : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _yeniPoliceModu ? Icons.add_circle_outline : Icons.calendar_today,
                      color: _yeniPoliceModu ? scheme.primary : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _yeniPoliceModu ? '🛡️ Yeni Poliçe' : '📅 Hatırlatıcı Kur',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      DateFormat('d MMMM y (EEEE)', 'tr').format(gun),
                      style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ])),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Divider(height: 16, color: Colors.grey.shade200),
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20, right: 20, top: 4,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── 1. Arama Saati ──────────────────────────────
                      _baslik('⏰ Arama Saati & Bildirim'),
                      GestureDetector(
                        onTap: () async {
                          final s = await showTimePicker(context: ctx, initialTime: _saat);
                          if (s != null) ss(() => _saat = s);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300, width: 1.5),
                          ),
                          child: Row(children: [
                            Icon(Icons.notifications_active, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                '${_saat.hour.toString().padLeft(2, "0")}:${_saat.minute.toString().padLeft(2, "0")}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.orange.shade700),
                              ),
                              Text('Bildirim bu saatte gelir • Değiştirmek için tıkla',
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade600)),
                            ]),
                            const Spacer(),
                            Icon(Icons.edit, size: 16, color: Colors.orange.shade400),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── 2. Müşteri Bilgileri ─────────────────────────
                      _baslik('👤 Müşteri Bilgileri'),
                      Row(children: [
                        Expanded(child: _tf(_adCtrl,    'Ad *',    zorunlu: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _tf(_soyadCtrl, 'Soyad *', zorunlu: true)),
                      ]),
                      const SizedBox(height: 10),
                      _tf(_telCtrl,    'Telefon', tip: TextInputType.phone),
                      const SizedBox(height: 18),

                      // ── 3. Poliçe Bilgileri ──────────────────────────
                      _baslik('📋 Poliçe Bilgileri'),
                      _tf(_sirketCtrl, 'Sigorta Şirketi'),
                      const SizedBox(height: 10),
                      _tf(_tutarCtrl,  'Prim Tutarı (₺)', tip: TextInputType.number),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<PoliceType>(
                        value: _seciliTur,
                        isExpanded: true,
                        decoration: _dec('Sigorta Türü *', Icons.category_outlined),
                        items: PoliceType.values.map((t) => DropdownMenuItem(
                          value: t, child: Text('${t.emoji} ${t.adi}'),
                        )).toList(),
                        onChanged: (v) => ss(() => _seciliTur = v!),
                      ),
                      const SizedBox(height: 10),
                      // Bitiş tarihi seçici
                      GestureDetector(
                        onTap: () async {
                          final t = await showDatePicker(
                            context: ctx,
                            initialDate: _bitisT ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2035),
                            helpText: 'Sigorta bitiş tarihi',
                          );
                          if (t != null) ss(() => _bitisT = t);
                        },
                        child: InputDecorator(
                          decoration: _dec('Sigorta Bitiş Tarihi *', Icons.event_outlined),
                          child: Text(
                            _bitisT != null
                                ? DateFormat('d MMMM y', 'tr').format(_bitisT!)
                                : 'Tıkla ve seç',
                            style: TextStyle(
                              color: _bitisT != null ? Colors.black87 : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── 4. Not ──────────────────────────────────────
                      _baslik('📝 Not'),
                      TextFormField(
                        controller: _notCtrl,
                        maxLines: 3,
                        decoration: _dec('Hatırlatıcı notu (isteğe bağlı)', Icons.notes),
                      ),
                      const SizedBox(height: 24),

                      // ── Kaydet butonu ────────────────────────────────
                      FilledButton.icon(
                        onPressed: () => _kaydet(gun, ctx),
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _yeniPoliceModu ? 'Poliçe & Bildirimi Kaydet' : 'Hatırlatıcı & Bildirimi Kaydet',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: _yeniPoliceModu
                              ? Theme.of(ctx).colorScheme.primary
                              : Colors.orange.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ]),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  KAYDET
  // ══════════════════════════════════════════════════════════
  Future<void> _kaydet(DateTime gun, BuildContext ctx) async {
    if (!_formKey.currentState!.validate()) return;
    if (_bitisT == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Lütfen sigorta bitiş tarihi seçin'), backgroundColor: Colors.orange),
      );
      return;
    }

    final hatZaman = DateTime(gun.year, gun.month, gun.day, _saat.hour, _saat.minute);

    // ── Daha Sonra modu: mevcut poliçeyi güncelle ──────────
    if (_dahaSonraModu && _dahaSonraPolice != null) {
      final guncellenmis = _dahaSonraPolice!.copyWith(
        durum:              PoliceStatus.dahaSonra,
        hatirlaticiTarihi:  hatZaman,
        hatirlaticiNotu:    _notCtrl.text.trim().isEmpty ? null : _notCtrl.text.trim(),
        takvimNotu_Tarih:   hatZaman,
        takvimNotu_Icerik:  _notCtrl.text.trim(),
      );
      await _db.guncelle(guncellenmis);
      await _notif.dahaSonraHatirlatici(guncellenmis);
      widget.onHatirlaticiSec?.call(hatZaman, _notCtrl.text.trim(), guncellenmis);
      if (mounted) Navigator.pop(ctx);  // formu kapat
      if (mounted) Navigator.pop(context); // takvimi kapat
      return;
    }

    // ── Yeni Poliçe modu ──────────────────────────────────
    final yeni = Police(
      musteriAdi:        _adCtrl.text.trim(),
      soyadi:            _soyadCtrl.text.trim(),
      telefon:           _telCtrl.text.trim().isEmpty ? '—' : _telCtrl.text.trim(),
      sirket:            _sirketCtrl.text.trim().isEmpty ? '—' : _sirketCtrl.text.trim(),
      tur:               _seciliTur,
      baslangicTarihi:   DateTime.now(),
      bitisTarihi:       _bitisT!,
      tutar:             double.tryParse(_tutarCtrl.text.replaceAll(',', '.')) ?? 0,
      durum:             PoliceStatus.beklemede,
      olusturmaTarihi:   DateTime.now(),
      hatirlaticiTarihi: hatZaman,
      hatirlaticiNotu:   _notCtrl.text.trim().isEmpty ? null : _notCtrl.text.trim(),
      takvimNotu_Tarih:  hatZaman,
      takvimNotu_Icerik: _notCtrl.text.trim(),
    );
    await _db.ekle(yeni);
    await _notif.policeIcinBildirimler(yeni);

    widget.onPoliceEklendi?.call();
    if (mounted) Navigator.pop(ctx);      // formu kapat
    if (mounted) Navigator.pop(context, true); // takvimi kapat, listeyi yenile

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Poliçe eklendi! Bildirim: ${DateFormat("d MMM – HH:mm", "tr").format(hatZaman)}'),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Yardımcı widget'lar ──────────────────────────────────
  Widget _baslik(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
  );

  Widget _tf(TextEditingController c, String l, {TextInputType? tip, bool zorunlu = false}) =>
      TextFormField(
        controller: c,
        keyboardType: tip,
        decoration: _dec(l, null),
        validator: zorunlu ? (v) => (v == null || v.trim().isEmpty) ? '$l gerekli' : null : null,
      );

  InputDecoration _dec(String l, IconData? i) => InputDecoration(
    labelText: l,
    prefixIcon: i != null ? Icon(i) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baslik = _yeniPoliceModu
        ? '📅 Tarih Seç → Poliçe Ekle'
        : _dahaSonraModu
            ? '📅 Tarih Seçin'
            : '📅 CRM Takvimi';

    return Scaffold(
      appBar: AppBar(
        title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: (_dahaSonraModu || _yeniPoliceModu)
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            : null,
      ),
      body: Column(children: [
        // Bilgi bandı
        if (_yeniPoliceModu)
          Container(
            color: scheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.touch_app, color: scheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Poliçe bitiş tarihini veya arama tarihini seçin → Form açılır',
                style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
              )),
            ]),
          ),
        if (_dahaSonraModu && _dahaSonraPolice != null)
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${_dahaSonraPolice!.tamAd} için bir gün seçin',
                style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w700, fontSize: 13),
              )),
            ]),
          ),
        // Takvim
        TableCalendar<_Olay>(
          locale: 'tr_TR',
          firstDay: DateTime(2020),
          lastDay: DateTime(2035),
          focusedDay: _odak,
          selectedDayPredicate: (d) => isSameDay(d, _secili),
          eventLoader: (d) => _olaylar[_sz(d)] ?? [],
          onDaySelected: _gunSec,
          onPageChanged: (o) => setState(() => _odak = o),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: scheme.primary.withOpacity(.2), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            markerDecoration: BoxDecoration(color: Colors.orange.shade700, shape: BoxShape.circle),
            markerSize: 6,
            markersMaxCount: 3,
          ),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        ),
        const Divider(height: 1),
        // Seçili gün başlığı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Text(DateFormat('d MMMM y', 'tr').format(_secili),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (_gunOlaylari.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                child: Text('${_gunOlaylari.length} olay',
                    style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            if (!_dahaSonraModu && !_yeniPoliceModu)
              TextButton.icon(
                onPressed: () => _formGoster(_secili),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Not Ekle', style: TextStyle(fontSize: 12)),
              ),
          ]),
        ),
        // Olaylar listesi
        Expanded(
          child: _gunOlaylari.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.calendar_today_outlined, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Bu gün için kayıt yok', style: TextStyle(color: Colors.grey.shade400)),
                    if (_yeniPoliceModu || _dahaSonraModu) ...[
                      const SizedBox(height: 8),
                      Text('↑ Yukarıdan gün seçin', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ],
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _gunOlaylari.length,
                  itemBuilder: (_, i) => _olayKart(_gunOlaylari[i]),
                ),
        ),
      ]),
    );
  }

  Widget _olayKart(_Olay o) {
    final renk = o.hatirlatici ? Colors.orange.shade700 : Colors.red.shade600;
    final ikon = o.hatirlatici ? Icons.phone_callback : Icons.event_busy;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: renk.withOpacity(.1),
          child: Icon(ikon, color: renk, size: 20),
        ),
        title: Text(o.police.tamAd, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.police.goruntulenenTur} · ${o.police.sirket}', style: const TextStyle(fontSize: 12)),
          Text(o.hatirlatici ? '📞 Arama Hatırlatıcısı' : '⏰ Bitiş Tarihi',
              style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w700)),
          if (o.police.hatirlaticiNotu != null)
            Text(o.police.hatirlaticiNotu!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
        isThreeLine: true,
      ),
    );
  }
}

class _Olay {
  final Police police;
  final bool   hatirlatici;
  const _Olay(this.police, this.hatirlatici);
}
