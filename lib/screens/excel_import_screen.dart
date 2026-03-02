// lib/screens/excel_import_screen.dart – v5
// Tema uyumlu, TC/Belge/Plaka otomatik çekimi, satır düzenleme
import 'dart:io';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});
  @override State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

// ── Önizleme satırı ──────────────────────────────────────────
class _ExcelSatir {
  final int idx;
  String musteriAdi, soyadi, telefon, tcKimlik, sirket, belgeSeriNo, plaka, aracMarka, aracModel, aracYil;
  PoliceType tur;
  DateTime? baslangic, bitis;
  double tutar, komisyon;
  bool secili;
  String? hata;

  _ExcelSatir({
    required this.idx, required this.musteriAdi, this.soyadi='', this.telefon='',
    this.tcKimlik='', this.sirket='', this.belgeSeriNo='', this.plaka='',
    this.aracMarka='', this.aracModel='', this.aracYil='',
    required this.tur, this.baslangic, this.bitis,
    this.tutar=0, this.komisyon=0, this.secili=true, this.hata,
  });

  Police toPolice() => Police(
    musteriAdi: musteriAdi, soyadi: soyadi,
    telefon: telefon.isEmpty ? '-' : telefon,
    tcKimlikNo: tcKimlik.isEmpty ? null : tcKimlik,
    sirket: sirket.isEmpty ? 'Belirtilmemiş' : sirket,
    tur: tur,
    belgeSeriNo: belgeSeriNo.isEmpty ? null : belgeSeriNo,
    aracPlaka: plaka.isEmpty ? null : plaka.toUpperCase(),
    aracMarka: aracMarka.isEmpty ? null : aracMarka,
    aracModel: aracModel.isEmpty ? null : aracModel,
    aracYil: aracYil.isEmpty ? null : aracYil,
    baslangicTarihi: baslangic ?? DateTime.now(),
    bitisTarihi: bitis ?? DateTime.now().add(const Duration(days: 365)),
    tutar: tutar, komisyon: komisyon,
    durum: PoliceStatus.beklemede,
    olusturmaTarihi: DateTime.now(),
  );
}

// ── Excel kolon → alan eşlemesi ──────────────────────────────
const _kolonMap = <String, String>{
  'müşteri adı':'musteriAdi', 'musteri adi':'musteriAdi', 'ad':'musteriAdi',
  'isim':'musteriAdi', 'name':'musteriAdi', 'müşteri':'musteriAdi', 'musteri':'musteriAdi',
  'soyad':'soyadi', 'soyadı':'soyadi', 'surname':'soyadi',
  'telefon':'telefon', 'tel':'telefon', 'phone':'telefon', 'gsm':'telefon',
  'tc kimlik no':'tcKimlik', 'tc kimlik':'tcKimlik', 'tc no':'tcKimlik',
  'kimlik no':'tcKimlik', 'tc':'tcKimlik', 'tckn':'tcKimlik',
  'sigorta türü':'tur', 'sigorta turu':'tur', 'poliçe türü':'tur',
  'police turu':'tur', 'tür':'tur', 'tur':'tur', 'type':'tur', 'branş':'tur', 'brans':'tur',
  'sigorta şirketi':'sirket', 'şirket':'sirket', 'sirket':'sirket',
  'company':'sirket', 'acente':'sirket', 'şirket adı':'sirket',
  'başlangıç':'baslangic', 'baslangic':'baslangic', 'başlangıç tarihi':'baslangic',
  'start date':'baslangic', 'start':'baslangic', 'tanzim tarihi':'baslangic',
  'bitiş':'bitis', 'bitis':'bitis', 'bitiş tarihi':'bitis',
  'end date':'bitis', 'end':'bitis', 'vade':'bitis', 'vade tarihi':'bitis',
  'tutar':'tutar', 'prim':'tutar', 'fiyat':'tutar', 'price':'tutar',
  'amount':'tutar', 'prim tutarı':'tutar', 'net prim':'tutar',
  'komisyon':'komisyon', 'komisyon %':'komisyon', 'komisyon tutarı':'komisyon',
  'commission':'komisyon', 'komisyon oranı':'komisyon',
  'plaka':'plaka', 'plate':'plaka', 'araç plaka':'plaka', 'araç plakası':'plaka',
  'belge no':'belgeSeriNo', 'poliçe no':'belgeSeriNo', 'police no':'belgeSeriNo',
  'seri no':'belgeSeriNo', 'belge seri no':'belgeSeriNo', 'poliçe numarası':'belgeSeriNo',
  'ruhsat seri':'ruhsat', 'ruhsat':'ruhsat',
  'araç marka':'aracMarka', 'marka':'aracMarka',
  'araç model':'aracModel', 'model':'aracModel',
  'araç yıl':'aracYil', 'yıl':'aracYil', 'model yılı':'aracYil',
};

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final _db    = DatabaseService();
  final _notif = NotificationService();

  int _adim = 0; // 0=yükle 1=önizle 2=tamam
  bool _yukl = false, _akt = false;
  String _dosyaAdi = '';
  List<_ExcelSatir> _satirlar = [];
  List<Police> _aktarildi = [];
  List<String> _hatalar = [];
  int? _duzenlenenIdx;

  PoliceType _turTahmin(String? v) {
    if (v == null) return PoliceType.diger;
    final s = v.toLowerCase().trim();
    if (s.contains('trafik') || s.contains('traffic') || s.contains('mtpl')) return PoliceType.trafik;
    if (s.contains('kasko') || s.contains('casco') || s.contains('kask')) return PoliceType.kasko;
    if (s.contains('dask') || s.contains('deprem') || s.contains('earthquake')) return PoliceType.dask;
    if (s.contains('konut') || s.contains('ev sigortası') || s.contains('house')) return PoliceType.konut;
    if (s.contains('tamamlay')) return PoliceType.tamamlayiciSaglik;
    if (s.contains('sağlık') || s.contains('saglik') || s.contains('health') || s.contains('medikal')) return PoliceType.ozelSaglik;
    if (s.contains('hayat') || s.contains('life') || s.contains('yaşam')) return PoliceType.hayat;
    if (s.contains('ferdi') || s.contains('kaza') || s.contains('accident')) return PoliceType.ferdiKaza;
    if (s.contains('işyeri') || s.contains('isyeri') || s.contains('iş yeri')) return PoliceType.isyeri;
    if (s.contains('nakliyat') || s.contains('cargo') || s.contains('taşıma')) return PoliceType.nakliyat;
    if (s.contains('tarım') || s.contains('tarim') || s.contains('agri')) return PoliceType.tarim;
    if (s.contains('seyahat') || s.contains('travel') || s.contains('turist')) return PoliceType.seyahat;
    return PoliceType.diger;
  }

  DateTime? _tarihParse(dynamic val) {
    if (val == null) return null;
    if (val is int || val is double) {
      try {
        final days = val is int ? val : (val as double).round();
        return DateTime(1899, 12, 30).add(Duration(days: days));
      } catch (_) {}
    }
    final s = val.toString().trim();
    final p1 = RegExp(r'^(\d{1,2})[.\/\-](\d{1,2})[.\/\-](\d{4})$');
    final p2 = RegExp(r'^(\d{4})[.\/\-](\d{1,2})[.\/\-](\d{1,2})$');
    final m1 = p1.firstMatch(s);
    if (m1 != null) {
      try { return DateTime(int.parse(m1.group(3)!), int.parse(m1.group(2)!), int.parse(m1.group(1)!)); } catch (_) {}
    }
    final m2 = p2.firstMatch(s);
    if (m2 != null) {
      try { return DateTime(int.parse(m2.group(1)!), int.parse(m2.group(2)!), int.parse(m2.group(3)!)); } catch (_) {}
    }
    try { return DateFormat('d.M.yyyy').parse(s); } catch (_) {}
    try { return DateFormat('yyyy-MM-dd').parse(s); } catch (_) {}
    return null;
  }

  double _parasalParse(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(RegExp(r'[^\d,\.]'), '');
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  Future<void> _dosyaSec() async {
    setState(() { _yukl = true; _hatalar = []; });
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (r == null || r.files.single.path == null) { setState(() => _yukl = false); return; }
      setState(() => _dosyaAdi = r.files.single.name);
      await _excelOku(r.files.single.path!);
    } catch (e) {
      setState(() { _yukl = false; _hatalar = ['Dosya açılamadı: $e']; });
    }
  }

  Future<void> _excelOku(String path) async {
    final bytes = File(path).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows  = sheet.rows;
    if (rows.isEmpty) { setState(() { _yukl=false; _hatalar=['Excel boş.']; }); return; }

    // Başlıkları eşle
    final headers = rows[0].map((c) => c?.value?.toString().toLowerCase().trim() ?? '').toList();
    final colIdx = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final mapped = _kolonMap[headers[i]];
      if (mapped != null) colIdx[mapped] = i;
    }

    final errs = <String>[];
    if (!colIdx.containsKey('musteriAdi')) errs.add('"Müşteri Adı" kolonu bulunamadı');
    if (errs.isNotEmpty) { setState(() { _yukl=false; _hatalar=errs; }); return; }

    String get(List row, String key) {
      final idx = colIdx[key];
      if (idx == null || idx >= row.length) return '';
      return row[idx]?.toString().trim() ?? '';
    }
    dynamic getRaw(int rowIndex, String key) {
      final idx = colIdx[key];
      if (idx == null || idx >= rows[rowIndex].length) return null;
      final cell = rows[rowIndex][idx];
      return cell?.value;
    }

    final satirlar = <_ExcelSatir>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i].map((c) => c?.value?.toString() ?? '').toList();
      final ad = (colIdx['musteriAdi'] != null && colIdx['musteriAdi']! < rows[i].length)
          ? (rows[i][colIdx['musteriAdi']!]?.value?.toString().trim() ?? '') : '';
      if (ad.isEmpty) continue;

      final turRaw = colIdx['tur'] != null && colIdx['tur']! < rows[i].length
          ? rows[i][colIdx['tur']!]?.value?.toString() : null;
      final bas = colIdx['baslangic'] != null && colIdx['baslangic']! < rows[i].length
          ? _tarihParse(rows[i][colIdx['baslangic']!]?.value) : null;
      final bit = colIdx['bitis'] != null && colIdx['bitis']! < rows[i].length
          ? _tarihParse(rows[i][colIdx['bitis']!]?.value) : null;

      String getStr(String key) {
        final idx = colIdx[key]; if (idx == null || idx >= rows[i].length) return '';
        return rows[i][idx]?.value?.toString().trim() ?? '';
      }
      double getDbl(String key) {
        final idx = colIdx[key]; if (idx == null || idx >= rows[i].length) return 0;
        return _parasalParse(rows[i][idx]?.value);
      }

      satirlar.add(_ExcelSatir(
        idx: i, musteriAdi: ad,
        soyadi: getStr('soyadi'), telefon: getStr('telefon'),
        tcKimlik: getStr('tcKimlik'),
        sirket: getStr('sirket'), belgeSeriNo: getStr('belgeSeriNo'),
        plaka: getStr('plaka').toUpperCase(),
        aracMarka: getStr('aracMarka'), aracModel: getStr('aracModel'),
        aracYil: getStr('aracYil'),
        tur: _turTahmin(turRaw),
        baslangic: bas, bitis: bit,
        tutar: getDbl('tutar'), komisyon: getDbl('komisyon'),
        secili: bit != null,
        hata: bit == null ? 'Bitiş tarihi okunamadı' : null,
      ));
    }

    setState(() { _satirlar=satirlar; _hatalar=[]; _yukl=false; _adim=1; });
  }

  Future<void> _aktar() async {
    final secili = _satirlar.where((s) => s.secili).toList();
    if (secili.isEmpty) return;
    setState(() => _akt = true);
    final list = <Police>[];
    for (final s in secili) {
      final id = await _db.ekle(s.toPolice());
      final p  = s.toPolice().copyWith(id: id);
      await _notif.policeIcinBildirimler(p);
      list.add(p);
    }
    setState(() { _aktarildi=list; _akt=false; _adim=2; });
  }

  int get _seciliSayi => _satirlar.where((s) => s.secili).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(text: TextSpan(
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface),
          children: [
            const TextSpan(text: 'Excel '),
            TextSpan(text: 'İçe Aktar',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ],
        )),
        actions: _adim == 1 ? [
          TextButton(
            onPressed: () => setState(() { _adim=0; _satirlar=[]; }),
            child: const Text('← Geri'),
          ),
        ] : null,
        bottom: _adim == 1 ? PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _OzetBar(satirlar: _satirlar),
        ) : null,
      ),
      body: switch (_adim) {
        0 => _yukleEkrani(),
        1 => _onizleEkrani(),
        _ => _tamamEkrani(),
      },
    );
  }

  // ── ADIM 0: Yükle ────────────────────────────────────────
  Widget _yukleEkrani() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.table_chart_outlined, size: 40, color: cs.primary),
        ),
        const SizedBox(height: 18),
        Text('Üretim Listesini Yükle',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('TC Kimlik, Poliçe Türü, Belge No ve Plaka\notomatik olarak Excel\'den okunur',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6), height: 1.5)),
        const SizedBox(height: 28),

        // Yükle butonu
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _yukl ? null : _dosyaSec,
            icon: _yukl
              ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              : const Icon(Icons.upload_file_outlined),
            label: Text(_yukl ? 'Yükleniyor…' : 'Excel Dosyası Seç (.xlsx)'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Hatalar
        if (_hatalar.isNotEmpty) Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.error_outline, color: cs.error, size: 16), const SizedBox(width:6),
              Text('Hata', style: TextStyle(fontWeight: FontWeight.w800, color: cs.error))]),
            const SizedBox(height: 6),
            ..._hatalar.map((e) => Text(e, style: TextStyle(fontSize: 12.5, color: cs.error))),
          ]),
        ),
        const SizedBox(height: 20),

        // Kolon rehberi
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: cs.primary),
              const SizedBox(width: 7),
              Text('Desteklenen Excel Sütunları',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary)),
            ]),
            const SizedBox(height: 14),
            ...[
              ('Müşteri Adı', true, 'zorunlu'),
              ('TC Kimlik No', false, 'otomatik okunur 🆕'),
              ('Sigorta Türü', false, 'Trafik/Kasko/Sağlık... tanır'),
              ('Sigorta Şirketi', false, 'isteğe bağlı'),
              ('Başlangıç Tarihi', false, 'GG.AA.YYYY'),
              ('Bitiş / Vade', true, 'zorunlu'),
              ('Tutar / Prim', true, 'zorunlu'),
              ('Komisyon', false, 'isteğe bağlı'),
              ('Plaka', false, 'kasko/trafik için 🆕'),
              ('Belge / Seri No', false, 'otomatik okunur 🆕'),
              ('Araç Marka / Model', false, 'isteğe bağlı'),
            ].map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(e.$2 ? Icons.check_circle : Icons.check_circle_outline,
                  size: 15, color: e.$2 ? cs.primary : cs.onSurface.withOpacity(0.4)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.$1, style: TextStyle(
                  fontWeight: e.$2 ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5, color: cs.onSurface))),
                Text(e.$3, style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
              ]),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── ADIM 1: Önizleme ─────────────────────────────────────
  Widget _onizleEkrani() {
    final cs   = Theme.of(context).colorScheme;
    final fmt  = DateFormat('d MMM y', 'tr');
    final fmtP = NumberFormat.currency(locale:'tr', symbol:'₺', decimalDigits:0);

    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: _satirlar.length,
          itemBuilder: (_, i) {
            final s = _satirlar[i];
            final on = s.secili;
            final isEdit = _duzenlenenIdx == i;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isEdit
                    ? cs.primaryContainer.withOpacity(0.4)
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: s.hata != null ? cs.error.withOpacity(0.5)
                      : on ? cs.primary : Theme.of(context).dividerColor,
                  width: on && !isEdit ? 1.5 : 1,
                ),
                boxShadow: on && !isEdit ? [BoxShadow(
                  color: cs.primary.withOpacity(0.08), blurRadius: 8)] : [],
              ),
              child: isEdit
                  ? _satiriDuzenle(i, s, cs)
                  : _satirGoster(i, s, on, fmt, fmtP, cs),
            );
          },
        ),
      ),
      // Bottom bar
      Container(
        color: Theme.of(context).navigationBarTheme.backgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: SafeArea(child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_seciliSayi poliçe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: cs.onSurface)),
            Text('aktarılacak', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
          ]),
          const Spacer(),
          FilledButton.icon(
            onPressed: _seciliSayi == 0 || _akt ? null : _aktar,
            icon: _akt
                ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2))
                : const Icon(Icons.download_done_outlined),
            label: Text(_akt ? 'Aktarılıyor…' : 'Ekle',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ])),
      ),
    ]);
  }

  Widget _satirGoster(int i, _ExcelSatir s, bool on, DateFormat fmt,
      NumberFormat fmtP, ColorScheme cs) {
    return InkWell(
      onTap: s.hata != null ? null : () => setState(() => s.secili = !s.secili),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Checkbox
          if (s.hata == null)
            GestureDetector(
              onTap: () => setState(() => s.secili = !s.secili),
              child: Container(
                width: 22, height: 22, margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: on ? cs.primary : Colors.transparent,
                  border: Border.all(color: on ? cs.primary : Theme.of(context).dividerColor, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: on ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            )
          else
            Icon(Icons.error_outline, size: 22, color: cs.error),
          const SizedBox(width: 10),
          // Tür emoji
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(s.tur.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          // İçerik
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${s.musteriAdi} ${s.soyadi}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: cs.onSurface))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(7)),
                child: Text(s.tur.adi, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: cs.primary)),
              ),
            ]),
            const SizedBox(height: 5),
            Wrap(spacing: 10, runSpacing: 4, children: [
              if (s.tcKimlik.isNotEmpty)
                _MetaChip(icon: Icons.badge_outlined, text: s.tcKimlik, cs: cs),
              if (s.belgeSeriNo.isNotEmpty)
                _MetaChip(icon: Icons.receipt_long_outlined, text: s.belgeSeriNo, cs: cs),
              if (s.plaka.isNotEmpty)
                _MetaChip(icon: Icons.directions_car_outlined, text: s.plaka, cs: cs, bold: true),
              if (s.bitis != null)
                _MetaChip(icon: Icons.event_outlined, text: fmt.format(s.bitis!), cs: cs),
              _MetaChip(icon: Icons.payments_outlined, text: fmtP.format(s.tutar), cs: cs,
                color: cs.tertiary, bold: true),
              if (s.hata != null)
                _MetaChip(icon: Icons.warning_amber_outlined, text: s.hata!, cs: cs, color: cs.error),
            ]),
          ])),
          // Düzenle butonu
          GestureDetector(
            onTap: () => setState(() => _duzenlenenIdx = _duzenlenenIdx == i ? null : i),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.edit_outlined, size: 14, color: cs.onSurface.withOpacity(0.6)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _satiriDuzenle(int i, _ExcelSatir s, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('✏️ Düzenle — ${s.musteriAdi}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: cs.primary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _duzenlenenIdx = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InpAlan(label: 'Ad', value: s.musteriAdi, onChanged: (v) => s.musteriAdi = v, cs: cs)),
          const SizedBox(width: 8),
          Expanded(child: _InpAlan(label: 'Soyad', value: s.soyadi, onChanged: (v) => s.soyadi = v, cs: cs)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _InpAlan(label: 'TC Kimlik', value: s.tcKimlik, onChanged: (v) => s.tcKimlik = v, cs: cs)),
          const SizedBox(width: 8),
          Expanded(child: _InpAlan(label: 'Belge No', value: s.belgeSeriNo, onChanged: (v) => s.belgeSeriNo = v, cs: cs)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _InpAlan(label: 'Plaka', value: s.plaka, onChanged: (v) => s.plaka = v.toUpperCase(), cs: cs)),
          const SizedBox(width: 8),
          Expanded(child: _InpAlan(label: 'Şirket', value: s.sirket, onChanged: (v) => s.sirket = v, cs: cs)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _InpAlan(label: 'Tutar ₺', value: s.tutar.toStringAsFixed(0), onChanged: (v) => s.tutar = double.tryParse(v) ?? s.tutar, cs: cs, keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: _InpAlan(label: 'Komisyon ₺', value: s.komisyon.toStringAsFixed(0), onChanged: (v) => s.komisyon = double.tryParse(v) ?? s.komisyon, cs: cs, keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        // Tür seçimi
        DropdownButtonFormField<PoliceType>(
          value: s.tur,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Sigorta Türü',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          items: PoliceType.values.map((t) => DropdownMenuItem(
            value: t, child: Text('${t.emoji} ${t.adi}', style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => setState(() => s.tur = v!),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (s.hata != null && s.bitis != null) setState(() => s.hata = null);
              setState(() { _duzenlenenIdx = null; if (!s.secili) s.secili = true; });
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('✓ Tamam', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  // ── ADIM 2: Tamamlandı ───────────────────────────────────
  Widget _tamamEkrani() {
    final cs   = Theme.of(context).colorScheme;
    final fmtP = NumberFormat.currency(locale:'tr', symbol:'₺', decimalDigits:0);
    final topTutar = _aktarildi.fold(0.0, (s, p) => s + p.tutar);
    final topKom   = _aktarildi.fold(0.0, (s, p) => s + p.komisyon);
    final byTur = <String, int>{};
    for (final p in _aktarildi) byTur[p.tur.adi] = (byTur[p.tur.adi] ?? 0) + 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 24),
        const Text('✅', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        Text('${_aktarildi.length} Poliçe Eklendi!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green.shade600)),
        const SizedBox(height: 6),
        Text('Tüm poliçeler başarıyla sisteme aktarıldı',
          style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: _OzetKart(icon: '📋', label: 'Toplam', value: '${_aktarildi.length}', cs: cs)),
          const SizedBox(width: 10),
          Expanded(child: _OzetKart(icon: '💰', label: 'Prim', value: fmtP.format(topTutar), cs: cs)),
        ]),
        if (topKom > 0) ...[
          const SizedBox(height: 10),
          _OzetKart(icon: '📈', label: 'Komisyon', value: fmtP.format(topKom), cs: cs),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tür Dağılımı', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: cs.primary)),
            const SizedBox(height: 10),
            ...byTur.entries.map((e) {
              final tur = PoliceType.values.firstWhere((t) => t.adi == e.key, orElse: () => PoliceType.diger);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text(tur.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text('${e.value}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: cs.primary)),
                  ),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Poliçe Listesine Dön', style: TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        )),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() { _adim=0; _satirlar=[]; _aktarildi=[]; }),
          icon: const Icon(Icons.upload_file_outlined, size: 16),
          label: const Text('Başka Excel Yükle'),
        ),
      ]),
    );
  }
}

// ── Yardımcı Widget'lar ──────────────────────────────────────
class _OzetBar extends StatelessWidget {
  final List<_ExcelSatir> satirlar;
  const _OzetBar({required this.satirlar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secili = satirlar.where((s) => s.secili).toList();
    final toplam = secili.fold(0.0, (s, r) => s + r.tutar);
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _OzetChip(label: 'Seçili', value: '${secili.length}/${satirlar.length}', cs: cs),
        const SizedBox(width: 16),
        _OzetChip(label: 'Toplam Prim',
          value: NumberFormat.currency(locale:'tr', symbol:'₺', decimalDigits:0).format(toplam), cs: cs),
        const Spacer(),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text('Tümünü Seç', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
        ),
      ]),
    );
  }
}

class _OzetChip extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  const _OzetChip({required this.label, required this.value, required this.cs});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 9.5, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w700)),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: cs.primary)),
  ]);
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;
  final Color? color;
  final bool bold;
  const _MetaChip({required this.icon, required this.text, required this.cs, this.color, this.bold=false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: color ?? cs.onSurface.withOpacity(0.45)),
    const SizedBox(width: 3),
    Text(text, style: TextStyle(fontSize: 11, color: color ?? cs.onSurface.withOpacity(0.7),
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
  ]);
}

class _InpAlan extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  final ColorScheme cs;
  final TextInputType? keyboardType;
  const _InpAlan({required this.label, required this.value, required this.onChanged, required this.cs, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        labelText: label, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _OzetKart extends StatelessWidget {
  final String icon, label, value;
  final ColorScheme cs;
  const _OzetKart({required this.icon, required this.label, required this.value, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.primary)),
      Text(label, style: TextStyle(fontSize: 11, color: cs.primary.withOpacity(0.7), fontWeight: FontWeight.w600)),
    ]),
  );
}
