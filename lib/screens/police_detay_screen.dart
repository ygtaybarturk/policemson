// lib/screens/police_detay_screen.dart – v5
// Bilgiler + Notlar sekmesi, PDF kaldırıldı, gece modu uyumlu
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class PoliceDetayScreen extends StatefulWidget {
  final int policeId;
  const PoliceDetayScreen({super.key, required this.policeId});
  @override State<PoliceDetayScreen> createState() => _PoliceDetayScreenState();
}

class _PoliceDetayScreenState extends State<PoliceDetayScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  Police? _p;
  bool _yukleniyor = true;
  bool _duzenleme  = false;
  late TabController _tc;

  // Form kontrolcüleri
  late TextEditingController _tcCtrl, _dogumCtrl, _emailCtrl,
      _belgeSeriCtrl, _plakaCtrl, _markaCtrl, _modelCtrl,
      _yilCtrl, _ruhsatCtrl, _adresCtrl, _uavtCtrl, _notlarCtrl,
      _sirketCtrl, _tutarCtrl, _komisyonCtrl,
      _musteriAdiCtrl, _soyadiCtrl, _telCtrl;
  PoliceType _tur = PoliceType.trafik;
  String? _ozelTurAdi;
  DateTime? _bitisT, _baslangicT;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tc.dispose();
    for (final c in [_tcCtrl, _dogumCtrl, _emailCtrl, _belgeSeriCtrl,
      _plakaCtrl, _markaCtrl, _modelCtrl, _yilCtrl, _ruhsatCtrl,
      _adresCtrl, _uavtCtrl, _notlarCtrl, _sirketCtrl, _tutarCtrl,
      _komisyonCtrl, _musteriAdiCtrl, _soyadiCtrl, _telCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final p = await _db.getir(widget.policeId);
    if (p != null) setState(() { _p = p; _yukleniyor = false; _doldur(p); });
  }

  void _doldur(Police p) {
    _musteriAdiCtrl = TextEditingController(text: p.musteriAdi);
    _soyadiCtrl     = TextEditingController(text: p.soyadi);
    _telCtrl        = TextEditingController(text: p.telefon);
    _emailCtrl      = TextEditingController(text: p.email ?? '');
    _tcCtrl         = TextEditingController(text: p.tcKimlikNo ?? '');
    _dogumCtrl      = TextEditingController(text: p.dogumTarihi ?? '');
    _sirketCtrl     = TextEditingController(text: p.sirket);
    _tutarCtrl      = TextEditingController(text: p.tutar == 0 ? '' : p.tutar.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''));
    _komisyonCtrl   = TextEditingController(text: p.komisyon == 0 ? '' : p.komisyon.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), ''));
    _belgeSeriCtrl  = TextEditingController(text: p.belgeSeriNo ?? '');
    _plakaCtrl      = TextEditingController(text: p.aracPlaka ?? '');
    _markaCtrl      = TextEditingController(text: p.aracMarka ?? '');
    _modelCtrl      = TextEditingController(text: p.aracModel ?? '');
    _yilCtrl        = TextEditingController(text: p.aracYil ?? '');
    _ruhsatCtrl     = TextEditingController(text: p.ruhsatSeriNo ?? '');
    _adresCtrl      = TextEditingController(text: p.adres ?? '');
    _uavtCtrl       = TextEditingController(text: p.uavt ?? '');
    _notlarCtrl     = TextEditingController(text: p.notlar ?? '');
    _tur            = p.tur;
    _ozelTurAdi     = p.ozelTurAdi;
    _bitisT         = p.bitisTarihi;
    _baslangicT     = p.baslangicTarihi;
  }

  Future<void> _kaydet() async {
    if (_p == null) return;
    final g = _p!.copyWith(
      musteriAdi:      _musteriAdiCtrl.text.trim(),
      soyadi:          _soyadiCtrl.text.trim(),
      telefon:         _telCtrl.text.trim(),
      email:           _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      tcKimlikNo:      _tcCtrl.text.trim().isEmpty ? null : _tcCtrl.text.trim(),
      dogumTarihi:     _dogumCtrl.text.trim().isEmpty ? null : _dogumCtrl.text.trim(),
      sirket:          _sirketCtrl.text.trim(),
      tur:             _tur,
      ozelTurAdi:      _ozelTurAdi,
      bitisTarihi:     _bitisT ?? _p!.bitisTarihi,
      baslangicTarihi: _baslangicT ?? _p!.baslangicTarihi,
      tutar:           double.tryParse(_tutarCtrl.text.replaceAll(',', '.')) ?? _p!.tutar,
      komisyon:        double.tryParse(_komisyonCtrl.text.replaceAll(',', '.')) ?? _p!.komisyon,
      belgeSeriNo:     _belgeSeriCtrl.text.trim().isEmpty ? null : _belgeSeriCtrl.text.trim(),
      aracPlaka:       _plakaCtrl.text.trim().isEmpty ? null : _plakaCtrl.text.trim().toUpperCase(),
      aracMarka:       _markaCtrl.text.trim().isEmpty ? null : _markaCtrl.text.trim(),
      aracModel:       _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      aracYil:         _yilCtrl.text.trim().isEmpty ? null : _yilCtrl.text.trim(),
      ruhsatSeriNo:    _ruhsatCtrl.text.trim().isEmpty ? null : _ruhsatCtrl.text.trim(),
      adres:           _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
      uavt:            _uavtCtrl.text.trim().isEmpty ? null : _uavtCtrl.text.trim(),
      notlar:          _notlarCtrl.text.trim().isEmpty ? null : _notlarCtrl.text.trim(),
    );
    await _db.guncelle(g);
    setState(() { _p = g; _duzenleme = false; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 16), SizedBox(width:8), Text('Bilgiler kaydedildi')]),
      backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p   = _p!;
    final cs  = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM y', 'tr');

    // Gradient renkleri türe göre
    final (g1, g2) = _turGradient(p.tur);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.tamAd),
        actions: [
          if (_duzenleme)
            TextButton.icon(
              onPressed: _kaydet,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: () => setState(() => _duzenleme = true),
            ),
        ],
        bottom: TabBar(
          controller: _tc,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Bilgiler'),
            Tab(icon: Icon(Icons.notes_outlined), text: 'Notlar'),
          ],
        ),
      ),
      body: Column(children: [
        // Gradient özet banner
        Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [g1, g2], begin: Alignment.centerLeft, end: Alignment.centerRight)),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            Text(p.tur.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.goruntulenenTur} – ${p.sirket}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
              Text('${fmt.format(p.bitisTarihi)} · ₺${NumberFormat('#,##0.##','tr').format(p.tutar)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
            _DurumChip(durum: p.durum),
          ]),
        ),
        Expanded(child: TabBarView(controller: _tc, children: [
          _bilgiFormu(p),
          _notlarSekme(),
        ])),
      ]),
    );
  }

  // ── TAB 1: Bilgi Formu ─────────────────────────────────────
  Widget _bilgiFormu(Police p) {
    final fmt = DateFormat('d MMMM y', 'tr');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_duzenleme) ...[
          _sec('👤 Kişisel Bilgiler'),
          Row(children: [
            Expanded(child: _tf(_musteriAdiCtrl, 'Ad *')),
            const SizedBox(width: 10),
            Expanded(child: _tf(_soyadiCtrl, 'Soyad *')),
          ]),
          const SizedBox(height: 10),
          _tf(_telCtrl, 'Telefon', tip: TextInputType.phone),
          const SizedBox(height: 10),
          _tf(_emailCtrl, 'E-posta', tip: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _tf(_tcCtrl, 'TC Kimlik No', tip: TextInputType.number, max: 11),
          const SizedBox(height: 10),
          _tf(_dogumCtrl, 'Doğum Tarihi (GG.AA.YYYY)'),
          const SizedBox(height: 16),

          _sec('📋 Poliçe Bilgileri'),
          _tf(_sirketCtrl, 'Sigorta Şirketi'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _tf(_tutarCtrl, 'Prim Tutarı (₺)', tip: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _tf(_komisyonCtrl, 'Komisyon (₺)', tip: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<PoliceType>(
            value: _tur, isExpanded: true,
            decoration: InputDecoration(labelText: 'Sigorta Türü',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            items: PoliceType.values.map((t) => DropdownMenuItem(value: t, child: Text('${t.emoji} ${t.adi}'))).toList(),
            onChanged: (v) => setState(() => _tur = v!),
          ),
          const SizedBox(height: 10),
          _tarihSec('Başlangıç Tarihi', _baslangicT, (d) => setState(() => _baslangicT = d)),
          const SizedBox(height: 10),
          _tarihSec('Bitiş Tarihi', _bitisT, (d) => setState(() => _bitisT = d)),
          const SizedBox(height: 10),
          _tf(_belgeSeriCtrl, 'Belge / Poliçe Seri No'),
          const SizedBox(height: 16),

          if (_tur.aracGerektiriyor) ...[
            _sec('🚗 Araç Bilgileri'),
            _tf(_plakaCtrl, 'Araç Plakası'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _tf(_markaCtrl, 'Marka')),
              const SizedBox(width: 10),
              Expanded(child: _tf(_modelCtrl, 'Model')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _tf(_yilCtrl, 'Yıl', tip: TextInputType.number, max: 4)),
              const SizedBox(width: 10),
              Expanded(child: _tf(_ruhsatCtrl, 'Ruhsat Seri No')),
            ]),
            const SizedBox(height: 16),
          ],

          if (_tur.adresGerektiriyor) ...[
            _sec('🏠 Konut Bilgileri'),
            _tf(_adresCtrl, 'Sigortalı Adres', satir: 2),
            const SizedBox(height: 10),
            _tf(_uavtCtrl, 'UAVT Kodu'),
            const SizedBox(height: 16),
          ],

          FilledButton.icon(
            onPressed: _kaydet,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 20),
        ] else ...[
          // Okuma modu
          _infoKarti('👤 Müşteri', [
            _satir('Ad Soyad', p.tamAd),
            _satir('Telefon',  p.telefon),
            if (p.email != null) _satir('E-posta', p.email!),
            if (p.tcKimlikNo != null) _satir('TC Kimlik', p.tcKimlikNo!),
            if (p.dogumTarihi != null) _satir('Doğum', p.dogumTarihi!),
          ]),
          const SizedBox(height: 10),
          _infoKarti('📋 Poliçe', [
            _satir('Tür', '${p.tur.emoji} ${p.goruntulenenTur}'),
            _satir('Şirket', p.sirket),
            _satir('Prim', '₺${NumberFormat('#,##0.##','tr').format(p.tutar)}'),
            if (p.komisyon > 0) _satir('Komisyon', '₺${NumberFormat('#,##0.##','tr').format(p.komisyon)}'),
            _satir('Başlangıç', fmt.format(p.baslangicTarihi)),
            _satir('Bitiş', fmt.format(p.bitisTarihi)),
            if (p.belgeSeriNo != null) _satir('Belge No', p.belgeSeriNo!),
          ]),
          if (p.tur.aracGerektiriyor && (p.aracPlaka != null || p.aracMarka != null)) ...[
            const SizedBox(height: 10),
            _infoKarti('🚗 Araç', [
              if (p.aracPlaka != null) _satir('Plaka', p.aracPlaka!),
              if (p.aracMarka != null) _satir('Araç', '${p.aracMarka} ${p.aracModel ?? ''} ${p.aracYil ?? ''}'),
              if (p.ruhsatSeriNo != null) _satir('Ruhsat', p.ruhsatSeriNo!),
            ]),
          ],
          if (p.tur.adresGerektiriyor && p.adres != null) ...[
            const SizedBox(height: 10),
            _infoKarti('🏠 Konut', [
              _satir('Adres', p.adres!),
              if (p.uavt != null) _satir('UAVT', p.uavt!),
            ]),
          ],
          const SizedBox(height: 12),
          // İletişim butonları
          if (p.telefon.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => _ara(p.telefon),
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: Text('Ara – ${p.telefon}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
            ),
            const SizedBox(height: 8),
          ],
          if (p.email != null) ...[
            OutlinedButton.icon(
              onPressed: () => _eposta(p.email!),
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('E-posta Gönder'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
            ),
            const SizedBox(height: 8),
          ],

          // ── PDF Bölümü ──────────────────────────────────
          const Divider(height: 24),
          Text('📎 Poliçe Dosyası',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 10),
          if (p.pdfDosyaYolu != null && File(p.pdfDosyaYolu!).existsSync()) ...[
            // Dosya var → aç, paylaş, sil
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pdfAc(p.pdfDosyaYolu!),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Poliçeyi Aç'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pdfPaylas(p.pdfDosyaYolu!),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Gönder'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pdfYukle(p),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Farklı Dosya Yükle'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pdfSil(p),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Dosyayı Sil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ]),
          ] else ...[
            // Dosya yok → yükle butonu
            OutlinedButton.icon(
              onPressed: () => _pdfYukle(p),
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('Poliçe Yükle (PDF / Görsel)'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ]),
    );
  }

  // ── TAB 2: Notlar ──────────────────────────────────────────
  List<Map<String, dynamic>> _notListesi() {
    final raw = _notlarCtrl.text.trim();
    if (raw.isEmpty) return [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) return List<Map<String, dynamic>>.from(parsed);
    } catch (_) {
      // Eski düz metin formatı - tek not olarak göster
      if (raw.isNotEmpty) {
        return [{'metin': raw, 'tarih': ''}];
      }
    }
    return [];
  }

  Future<void> _notEkle(String metin) async {
    if (metin.trim().isEmpty) return;
    final mevcut = _notListesi();
    mevcut.add({
      'metin': metin.trim(),
      'tarih': DateTime.now().toIso8601String(),
    });
    _notlarCtrl.text = jsonEncode(mevcut);
    await _kaydet();
  }

  Future<void> _notSil(int index) async {
    final mevcut = _notListesi();
    mevcut.removeAt(index);
    _notlarCtrl.text = mevcut.isEmpty ? '' : jsonEncode(mevcut);
    await _kaydet();
  }

  Widget _notlarSekme() {
    final fmt = DateFormat('d MMM y, HH:mm', 'tr');
    final notlar = _notListesi();
    final yeniNotCtrl = TextEditingController();

    return StatefulBuilder(
      builder: (ctx, setS) => SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Not Ekle Kutusu ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBgCard2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Column(children: [
              TextField(
                controller: yeniNotCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Not yaz…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final metin = yeniNotCtrl.text;
                    yeniNotCtrl.clear();
                    await _notEkle(metin);
                    setS(() {});
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Kaydet'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Not Listesi ──
          if (notlar.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kBgCard2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Text('Henüz not eklenmemiş.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSub, fontSize: 13)),
            )
          else
            ...notlar.asMap().entries.map((e) {
              final idx = e.key;
              final not = e.value;
              DateTime? tarih;
              try { tarih = DateTime.parse(not['tarih'] ?? ''); } catch (_) {}
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 6)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(not['metin'] ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (tarih != null)
                      Text(fmt.format(tarih),
                          style: TextStyle(fontSize: 10, color: context.textSub)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final onay = await showDialog<bool>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            title: const Text('Notu Sil'),
                            content: const Text('Bu not silinecek. Emin misin?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sil', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (onay == true) {
                          await _notSil(idx);
                          setS(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.08),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.red.withOpacity(.2)),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline_rounded, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Sil', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              );
            }),
        ]),
      ),
    );
  }

  // ── Yardımcılar ───────────────────────────────────────────
  Widget _sec(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
      color: Theme.of(context).colorScheme.primary)));

  Widget _tf(TextEditingController c, String l, {TextInputType? tip, int? max, int satir = 1}) =>
    TextFormField(controller: c, keyboardType: tip, maxLength: max, maxLines: satir,
      decoration: InputDecoration(labelText: l, counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)));

  Widget _tarihSec(String l, DateTime? val, Function(DateTime) cb) => GestureDetector(
    onTap: () async {
      final t = await showDatePicker(context: context,
        initialDate: val ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2040));
      if (t != null) cb(t);
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: l, prefixIcon: const Icon(Icons.event_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      child: Text(val != null ? DateFormat('d MMMM y', 'tr').format(val) : '—'),
    ),
  );

  Widget _infoKarti(String baslik, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Text(baslik, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
          color: Theme.of(context).colorScheme.primary))),
      const Divider(height: 1),
      ...children,
    ]),
  );

  Widget _satir(String e, String v) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(e, style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
    ]),
  );

  Future<void> _pdfYukle(Police p) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;
    final srcPath = result.files.single.path!;
    // Kalıcı klasöre kopyala
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${appDir.path}/policeler');
    await destDir.create(recursive: true);
    final ext = srcPath.split('.').last;
    final destPath = '${destDir.path}/police_${p.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(srcPath).copy(destPath);
    final guncellenmis = p.copyWith(pdfDosyaYolu: destPath);
    await _db.guncelle(guncellenmis);
    setState(() => _p = guncellenmis);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Dosya yüklendi')));
    }
  }

  Future<void> _pdfAc(String dosyaYolu) async {
    final result = await OpenFilex.open(dosyaYolu);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya açılamadı: ${result.message}')));
    }
  }

  Future<void> _pdfPaylas(String dosyaYolu) async {
    await Share.shareXFiles([XFile(dosyaYolu)], text: 'Poliçe dosyası');
  }

  Future<void> _pdfSil(Police p) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dosyayı Sil'),
        content: const Text('Yüklenen poliçe dosyası silinecek. Emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true) return;
    // Fiziksel dosyayı sil
    try { await File(p.pdfDosyaYolu!).delete(); } catch (_) {}
    // DB'den temizle
    final guncellenmis = p.copyWith(pdfDosyaYolu: '');
    await _db.guncelle(guncellenmis);
    setState(() => _p = guncellenmis.copyWith(pdfDosyaYolu: null));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Dosya silindi')));
    }
  }

  Future<void> _ara(String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _eposta(String mail) async {
    final uri = Uri(scheme: 'mailto', path: mail);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  (Color, Color) _turGradient(PoliceType t) => switch (t) {
    PoliceType.trafik            => (const Color(0xFF1565C0), const Color(0xFF1E88E5)),
    PoliceType.kasko             => (const Color(0xFF283593), const Color(0xFF3949AB)),
    PoliceType.dask              => (const Color(0xFF4A148C), const Color(0xFF7B1FA2)),
    PoliceType.konut             => (const Color(0xFF880E4F), const Color(0xFFC2185B)),
    PoliceType.ozelSaglik        => (const Color(0xFFB71C1C), const Color(0xFFD32F2F)),
    PoliceType.tamamlayiciSaglik => (const Color(0xFF880E4F), const Color(0xFFE91E63)),
    PoliceType.hayat             => (const Color(0xFF1B5E20), const Color(0xFF388E3C)),
    PoliceType.ferdiKaza         => (const Color(0xFFE65100), const Color(0xFFF57C00)),
    PoliceType.isyeri            => (const Color(0xFF004D40), const Color(0xFF00897B)),
    PoliceType.nakliyat          => (const Color(0xFF006064), const Color(0xFF0097A7)),
    PoliceType.tarim             => (const Color(0xFF33691E), const Color(0xFF558B2F)),
    PoliceType.seyahat           => (const Color(0xFF01579B), const Color(0xFF0288D1)),
    _                            => (const Color(0xFF37474F), const Color(0xFF546E7A)),
  };
}

// ── Durum Chip ───────────────────────────────────────────────
class _DurumChip extends StatelessWidget {
  final PoliceStatus durum;
  const _DurumChip({required this.durum});
  @override
  Widget build(BuildContext context) {
    final (lbl, bg, fg) = switch (durum) {
      PoliceStatus.yapildi    => ('✓ Yapıldı',    Colors.white24, Colors.white),
      PoliceStatus.yapilamadi => ('✗ Yapılamadı', Colors.white24, Colors.white),
      PoliceStatus.dahaSonra  => ('◷ Sonra',      Colors.white24, Colors.white),
      _                       => ('⏳ Beklemede', Colors.white24, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(lbl, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}
