// lib/screens/excel_import_screen.dart
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});
  @override State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

// ── Önizleme satırı ──────────────────────────────────────────
class _Satir {
  final int idx;
  String musteriAdi, soyadi, telefon, tcKimlik;
  String sirket, policeNo, belgeSeriNo, plaka;
  PoliceType tur;
  DateTime? baslangic, bitis;
  double tutar, komisyon;
  bool secili;
  String? hata;

  _Satir({
    required this.idx,
    required this.musteriAdi,
    this.soyadi = '',
    this.telefon = '',
    this.tcKimlik = '',
    this.sirket = '',
    this.policeNo = '',
    this.belgeSeriNo = '',
    this.plaka = '',
    required this.tur,
    this.baslangic,
    this.bitis,
    this.tutar = 0,
    this.komisyon = 0,
    this.secili = true,
    this.hata,
  });

  Police toPolice() {
    final bas = baslangic ?? DateTime.now();
    final bit = bitis ?? bas.add(const Duration(days: 365));
    final simdi = DateTime.now();
    final durum = (bas.isBefore(simdi) ||
        (bas.year == simdi.year && bas.month == simdi.month && bas.day == simdi.day))
        ? PoliceStatus.yapildi
        : PoliceStatus.beklemede;

    return Police(
      musteriAdi: musteriAdi,
      soyadi: soyadi,
      telefon: telefon.isEmpty ? '-' : telefon,
      tcKimlikNo: tcKimlik.isEmpty ? null : tcKimlik,
      sirket: sirket,
      tur: tur,
      policeNo: policeNo.isEmpty ? null : policeNo,
      belgeSeriNo: belgeSeriNo.isEmpty ? null : belgeSeriNo,
      aracPlaka: plaka.isEmpty ? null : plaka,
      baslangicTarihi: bas,
      bitisTarihi: bit,
      tutar: tutar,
      komisyon: komisyon,
      durum: durum,
    );
  }
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final _db = DatabaseService();

  List<_Satir> _satirlar = [];
  bool _yukleniyor = false;
  bool _kaydediliyor = false;
  String? _dosyaAdi;
  List<String> _hatalar = [];

  // ── Excel dosyası seç ve parse et ───────────────────────────
  Future<void> _dosyaSec() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final file = res.files.first;
    if (file.bytes == null) return;

    setState(() { _yukleniyor = true; _hatalar = []; _satirlar = []; });

    try {
      final excel = Excel.decodeBytes(file.bytes!);
      final sheet = excel.tables.values.first;
      final rows = sheet.rows;
      if (rows.isEmpty) { setState(() => _yukleniyor = false); return; }

      // ── Sütun başlıklarını bul ──────────────────────────────
      final header = rows.first;
      final Map<String, int> cols = {};
      for (int i = 0; i < header.length; i++) {
        final val = _str(header[i]?.value).toUpperCase().trim()
            .replaceAll('İ', 'I').replaceAll('Ş', 'S')
            .replaceAll('Ğ', 'G').replaceAll('Ç', 'C')
            .replaceAll('Ö', 'O').replaceAll('Ü', 'U');
        if (val.isNotEmpty) cols[val] = i;
      }

      // Sütun indeks yardımcıları
      int? col(String key) {
        for (final k in cols.keys) {
          if (k.contains(key)) return cols[k];
        }
        return null;
      }

      final iSirket     = col('SIRKET') ?? col('ŞIRKET');
      final iPolice     = col('POLICE');       // poliçe türü
      final iTC         = col('TC');
      final iMusteri    = col('MUSTERI') ?? col('MÜŞTERI');
      final iPoliceNo   = col('POLICE NO');    // poliçe numarası
      final iBelgeSeri  = col('BELGE SERI') ?? col('BELGE');
      final iPlaka      = col('PLAKA');
      final iBaslangic  = col('BASLANGIC') ?? col('BAŞLANGIÇ') ?? col('BASLANGIÇ');
      final iBitis      = col('BITIS') ?? col('BITIŞ') ?? col('BITIS');
      final iBrut       = col('BRUT') ?? col('PRIM') ?? col('PRM') ?? col('TUTAR') ?? col('NET') ?? col('TOPLAM');
      final iKomisyon   = col('KOMISYON') ?? col('KOMISYON');

      final satirlar = <_Satir>[];
      final hatalar  = <String>[];

      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.every((c) => _str(c?.value).isEmpty)) continue;

        String get(int? i) => i != null && i < row.length ? _str(row[i]?.value) : '';

        // Müşteri adı + soyad
        final musteriTam = get(iMusteri).trim();
        if (musteriTam.isEmpty) continue;
        final parcalar = musteriTam.split(' ');
        final ad    = parcalar.first;
        final soyad = parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '';

        // Tarihler
        final bas = _tarihParse(get(iBaslangic), row[iBaslangic ?? 0]?.value);
        final bit = _tarihParse(get(iBitis),     row[iBitis     ?? 0]?.value);

        String? hata;
        if (bas == null) hata = 'Başlangıç tarihi okunamadı';
        if (bit == null) hata = (hata != null ? '$hata, ' : '') + 'Bitiş tarihi okunamadı';

        // Tutar
        double _sayi(String s) {
          s = s.replaceAll('₺','').replaceAll(' ','').replaceAll(' ','').trim();
          if (s.isEmpty) return 0;
          // raw numeric from Excel cell
          final raw = double.tryParse(s);
          if (raw != null) return raw;
          // Turkish format: 1.234,56
          if (s.contains(',') && s.contains('.')) {
            final lastComma = s.lastIndexOf(',');
            final lastDot   = s.lastIndexOf('.');
            if (lastComma > lastDot) {
              // 1.234,56 → Turkish (dot=thousands, comma=decimal)
              return double.tryParse(s.replaceAll('.','').replaceAll(',','.')) ?? 0;
            } else {
              // 1,234.56 → English (comma=thousands, dot=decimal)
              return double.tryParse(s.replaceAll(',','')) ?? 0;
            }
          }
          // only comma: could be 1234,56 → treat as decimal
          if (s.contains(',')) return double.tryParse(s.replaceAll(',','.')) ?? 0;
          return 0;
        }
        final tutar    = _sayi(get(iBrut));
        final komisyon = _sayi(get(iKomisyon));

        satirlar.add(_Satir(
          idx: r,
          musteriAdi: ad,
          soyadi: soyad,
          tcKimlik: get(iTC),
          sirket: get(iSirket),
          tur: PoliceTypeX.fromExcel(get(iPolice)),
          policeNo: get(iPoliceNo),
          belgeSeriNo: get(iBelgeSeri),
          plaka: get(iPlaka),
          baslangic: bas,
          bitis: bit,
          tutar: tutar,
          komisyon: komisyon,
          hata: hata,
          secili: hata == null,
        ));
      }

      setState(() {
        _satirlar  = satirlar;
        _hatalar   = hatalar;
        _dosyaAdi  = file.name;
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _hatalar   = ['Dosya okunurken hata: $e'];
        _yukleniyor = false;
      });
    }
  }

  // ── Tarih parse ──────────────────────────────────────────────
  DateTime? _tarihParse(String str, dynamic raw) {
    // Excel sayısal tarih (OLE Automation Date)
    if (raw is int || raw is double) {
      try {
        final n = (raw as num).toInt();
        if (n > 10000) {
          return DateTime(1899, 12, 30).add(Duration(days: n));
        }
      } catch (_) {}
    }

    // raw String ise direkt kullan
    final s = (raw is String && raw.trim().isNotEmpty) ? raw.trim() : str.trim();
    if (s.isEmpty) return null;

    // GG.AA.YYYY, GG/AA/YYYY, GG-AA-YYYY, GG.AA.YY (2 haneli yıl) vb.
    final formatlar = [
      DateFormat('dd.MM.yyyy'),
      DateFormat('d.M.yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
      DateFormat('d-M-yyyy'),
      DateFormat('dd.MM.yy'),
      DateFormat('d.M.yy'),
      DateFormat('dd/MM/yy'),
    ];
    for (final f in formatlar) {
      try { return f.parseStrict(s); } catch (_) {}
    }
    // ISO fallback
    return DateTime.tryParse(s);
  }

  String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is int || v is double) {
      final d = (v as num).toDouble();
      if (d == d.truncateToDouble()) return d.toInt().toString();
      return d.toString();
    }
    return v.toString();
  }

  // ── Kaydet ──────────────────────────────────────────────────
  Future<void> _kaydet() async {
    final secilenler = _satirlar.where((s) => s.secili).toList();
    if (secilenler.isEmpty) return;

    setState(() => _kaydediliyor = true);
    int basarili = 0;
    for (final s in secilenler) {
      try {
        await _db.ekle(s.toPolice());
        basarili++;
      } catch (_) {}
    }
    setState(() => _kaydediliyor = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$basarili poliçe başarıyla aktarıldı'),
      backgroundColor: kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final secili = _satirlar.where((s) => s.secili).length;
    final fmt = DateFormat('d MMM yyyy', 'tr');
    final moneyFmt = NumberFormat.currency(locale: 'tr', symbol: '₺', decimalDigits: 2);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBgCard,
        title: const Text("Excel'den Aktar",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.8),
          child: Container(height: 0.8, color: kBorder),
        ),
      ),
      body: Column(children: [
        // Hata kutusu
        if (_hatalar.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kDangerContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDanger.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.error_outline, color: kDanger, size: 16),
                const SizedBox(width: 6),
                Text('Uyarılar', style: TextStyle(fontWeight: FontWeight.w800, color: kDanger)),
              ]),
              const SizedBox(height: 6),
              ..._hatalar.map((e) => Text(e, style: TextStyle(fontSize: 12.5, color: kDanger))),
            ]),
          ),

        // Dosya seç butonu
        if (_satirlar.isEmpty && !_yukleniyor)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kPrimaryGlow, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.table_chart_rounded, color: kPrimary, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Excel dosyası seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 6),
            const Text('Sirket, Police, Musteri, Police No,\nBelge Seri, Plaka, Baslangic, Bitis, Brut, Komisyon',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kTextSub)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _dosyaSec,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Dosya Seç (.xlsx / .xls)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]))),

        // Yükleniyor
        if (_yukleniyor)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary))),

        // Önizleme listesi
        if (_satirlar.isNotEmpty) ...[
          // Özet bar
          Container(
            color: kBgCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_dosyaAdi ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText),
                    overflow: TextOverflow.ellipsis),
                Text('${_satirlar.length} satır · $secili seçili',
                    style: const TextStyle(fontSize: 12, color: kTextSub)),
              ])),
              TextButton(
                onPressed: _dosyaSec,
                child: const Text('Değiştir', style: TextStyle(color: kPrimary)),
              ),
            ]),
          ),
          Container(height: 0.8, color: kBorder),

          // Liste
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            itemCount: _satirlar.length,
            itemBuilder: (_, i) {
              final s = _satirlar[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: kBgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: s.hata != null ? kDanger.withOpacity(0.4) : kBorder,
                    width: s.hata != null ? 1.2 : 0.8,
                  ),
                ),
                child: CheckboxListTile(
                  value: s.secili,
                  onChanged: (v) => setState(() => s.secili = v ?? false),
                  activeColor: kPrimary,
                  contentPadding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // İsim + tür
                    Row(children: [
                      Text(s.tur.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${s.musteriAdi} ${s.soyadi}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kText))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimaryGlow, borderRadius: BorderRadius.circular(8)),
                        child: Text(s.tur.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary)),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // Şirket + TC
                    Row(children: [
                      if (s.sirket.isNotEmpty) ...[
                        const Icon(Icons.business_rounded, size: 11, color: kTextSub),
                        const SizedBox(width: 4),
                        Text(s.sirket, style: const TextStyle(fontSize: 11.5, color: kTextSub, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                      ],
                      if (s.tcKimlik.isNotEmpty) ...[
                        const Icon(Icons.badge_outlined, size: 11, color: kTextSub),
                        const SizedBox(width: 4),
                        Text(s.tcKimlik, style: const TextStyle(fontSize: 11, color: kTextSub)),
                      ],
                    ]),
                    const SizedBox(height: 4),

                    // Police No + Belge Seri
                    if (s.policeNo.isNotEmpty || s.belgeSeriNo.isNotEmpty)
                      Row(children: [
                        if (s.policeNo.isNotEmpty) ...[
                          const Icon(Icons.numbers_rounded, size: 11, color: kTextSub),
                          const SizedBox(width: 3),
                          Text('Poliçe: ${s.policeNo}',
                              style: const TextStyle(fontSize: 11, color: kTextSub)),
                          const SizedBox(width: 10),
                        ],
                        if (s.belgeSeriNo.isNotEmpty) ...[
                          const Icon(Icons.confirmation_number_outlined, size: 11, color: kTextSub),
                          const SizedBox(width: 3),
                          Text('Belge: ${s.belgeSeriNo}',
                              style: const TextStyle(fontSize: 11, color: kTextSub)),
                        ],
                      ]),

                    // Plaka
                    if (s.plaka.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.directions_car_rounded, size: 11, color: kPrimary),
                        const SizedBox(width: 4),
                        Text(s.plaka, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimary)),
                      ]),
                    ],
                    const SizedBox(height: 6),

                    // Tarihler + Tutar
                    Row(children: [
                      if (s.baslangic != null)
                        Text(fmt.format(s.baslangic!),
                            style: const TextStyle(fontSize: 11, color: kText, fontWeight: FontWeight.w600)),
                      if (s.baslangic != null && s.bitis != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 11, color: kTextSub),
                        ),
                      if (s.bitis != null)
                        Text(fmt.format(s.bitis!),
                            style: const TextStyle(fontSize: 11, color: kText, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (s.tutar > 0)
                        Text(moneyFmt.format(s.tutar),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
                    ]),

                    // Hata
                    if (s.hata != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.warning_amber_rounded, size: 12, color: kDanger),
                        const SizedBox(width: 4),
                        Expanded(child: Text(s.hata!,
                            style: const TextStyle(fontSize: 11, color: kDanger, fontWeight: FontWeight.w600))),
                      ]),
                    ],
                  ]),
                ),
              );
            },
          )),
        ],
      ]),

      // Kaydet butonu
      bottomNavigationBar: _satirlar.isNotEmpty
          ? SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ElevatedButton(
              onPressed: secili == 0 || _kaydediliyor ? null : _kaydet,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: _kaydediliyor
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text('$secili Poliçeyi Aktar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ))
          : null,
    );
  }
}