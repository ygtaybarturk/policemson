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
    
    // Sadece başlangıç tarihine göre durum belirle
    // Başlangıç tarihi geçmişte/bugünse → Yapıldı
    // Başlangıç tarihi gelecekteyse → Beklemede
    final simdi = DateTime.now();
    final bugunBaslangic = DateTime(simdi.year, simdi.month, simdi.day);
    final basBaslangic = DateTime(bas.year, bas.month, bas.day);
    final durum = basBaslangic.isAfter(bugunBaslangic) 
        ? PoliceStatus.beklemede 
        : PoliceStatus.yapildi;

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

  List<_Satir>     _satirlar     = [];
  List<ZeyilKayit> _zeyiller     = [];
  bool  _yukleniyor   = false;
  bool  _kaydediliyor = false;
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

    setState(() { _yukleniyor = true; _hatalar = []; _satirlar = []; _zeyiller = []; });

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

      final iSirket    = col('SIRKET') ?? col('ŞIRKET');
      final iPolice    = col('POLICE');
      final iKayitTuru = col('KAYIT TURU') ?? col('KAYIT');
      final iTC        = col('TC');
      final iMusteri   = col('MUSTERI') ?? col('MÜŞTERI');
      final iTanzim    = col('TANZIM');
      final iPoliceNo  = col('POLICE NO');
      final iBelgeSeri = col('BELGE SERI') ?? col('BELGE');
      final iPlaka     = col('PLAKA');
      final iBaslangic = col('BASLANGIC') ?? col('BAŞLANGIÇ') ?? col('BASLANGIÇ');
      final iBitis     = col('BITIS') ?? col('BITIŞ') ?? col('BITIS');
      final iBrut      = col('BRUT') ?? col('PRIM') ?? col('PRM') ?? col('TUTAR') ?? col('NET') ?? col('TOPLAM');
      final iKomisyon  = col('KOMISYON');

      final satirlar  = <_Satir>[];
      final zeyilList = <ZeyilKayit>[];
      final hatalar   = <String>[];

      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        if (row.every((c) => _str(c?.value).isEmpty)) continue;

        String get(int? i) => i != null && i < row.length ? _str(row[i]?.value) : '';

        // Son satır kontrolü
        final sirketVal = get(iSirket).trim();
        if (sirketVal.isEmpty || RegExp(r'^\d+\s*(Adet|adet|ADET)').hasMatch(sirketVal)) continue;

        final musteriTam = get(iMusteri).trim();
        if (musteriTam.isEmpty) continue;

        final kayitTuruRaw = get(iKayitTuru);
        final kayitTuruUp  = kayitTuruRaw.toUpperCase()
            .replaceAll('İ', 'I').replaceAll('Ç', 'C');

        double _sayi(String s) {
          s = s.replaceAll('₺','').replaceAll(' ','').replaceAll('\u00a0','').trim();
          if (s.isEmpty) return 0;
          final raw = double.tryParse(s);
          if (raw != null) return raw;
          if (s.contains(',') && s.contains('.')) {
            final lastComma = s.lastIndexOf(',');
            final lastDot   = s.lastIndexOf('.');
            if (lastComma > lastDot) {
              return double.tryParse(s.replaceAll('.','').replaceAll(',','.')) ?? 0;
            } else {
              return double.tryParse(s.replaceAll(',','')) ?? 0;
            }
          }
          if (s.contains(',')) return double.tryParse(s.replaceAll(',','.')) ?? 0;
          return 0;
        }

        final tutar     = _sayi(get(iBrut));
        final komisyon  = _sayi(get(iKomisyon));
        final policeStr = get(iPolice);

        // ── Zeyil/İptal satırı ──
        if (iKayitTuru != null &&
            (kayitTuruUp.contains('ZEYIL') || kayitTuruUp.contains('IPTAL'))) {
          final tanzimStr = get(iTanzim);
          final tanzim    = _tarihParse(tanzimStr, row[iTanzim ?? 0]?.value) ??
                            _tarihParse(get(iBaslangic), row[iBaslangic ?? 0]?.value) ??
                            DateTime.now();
          final isIptal       = kayitTuruUp.contains('IPTAL');
          final zeyilTutar    = isIptal ? -tutar.abs()    : tutar.abs();
          final zeyilKomisyon = isIptal ? -komisyon.abs() : komisyon.abs();

          zeyilList.add(ZeyilKayit(
            yil:          tanzim.year,
            ay:           tanzim.month,
            sirket:       sirketVal,
            musteriAdi:   musteriTam,
            policeNo:     get(iPoliceNo),
            tur:          PoliceTypeX.fromExcel(policeStr),
            tutar:        zeyilTutar,
            komisyon:     zeyilKomisyon,
            kayitTuru:    kayitTuruRaw,
            tanzimTarihi: tanzim,
          ));
          continue;
        }

        // ── Normal poliçe ──
        final parcalar = musteriTam.split(' ');
        final ad    = parcalar.first;
        final soyad = parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '';

        final bas = _tarihParse(get(iBaslangic), row[iBaslangic ?? 0]?.value);
        final bit = _tarihParse(get(iBitis),     row[iBitis     ?? 0]?.value);

        String? hata;
        if (bas == null) hata = 'Başlangıç tarihi okunamadı';
        if (bit == null) hata = (hata != null ? '$hata, ' : '') + 'Bitiş tarihi okunamadı';

        satirlar.add(_Satir(
          idx:        r,
          musteriAdi: ad,
          soyadi:     soyad,
          tcKimlik:   get(iTC),
          sirket:     sirketVal,
          tur:        PoliceTypeX.fromExcel(policeStr),
          policeNo:   get(iPoliceNo),
          belgeSeriNo:get(iBelgeSeri),
          plaka:      get(iPlaka),
          baslangic:  bas,
          bitis:      bit,
          tutar:      tutar,
          komisyon:   komisyon,
          hata:       hata,
          secili:     hata == null,
        ));
      }

      setState(() {
        _satirlar   = satirlar;
        _zeyiller   = zeyilList;
        _hatalar    = hatalar;
        _dosyaAdi   = file.name;
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
    if (secilenler.isEmpty && _zeyiller.isEmpty) return;

    setState(() => _kaydediliyor = true);
    int basarili = 0;
    int guncellenen = 0;
    
    for (final s in secilenler) {
      try { 
        await _db.ekleVeyaGuncelle(s.toPolice()); 
        basarili++; 
      } catch (_) {}
    }
    
    if (_zeyiller.isNotEmpty) {
      try { await _db.zeyillerEkle(_zeyiller); } catch (_) {}
    }
    setState(() => _kaydediliyor = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$basarili poliçe'
          '${_zeyiller.isNotEmpty ? ' · ${_zeyiller.length} zeyil' : ''} kaydedildi'),
      backgroundColor: kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(milliseconds: 1000),
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
                Row(children: [
                  Text('${_satirlar.length} satır · $secili seçili',
                      style: const TextStyle(fontSize: 12, color: kTextSub)),
                  if (_zeyiller.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text('${_zeyiller.length} zeyil',
                          style: TextStyle(fontSize: 10, color: Colors.orange.shade700,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
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