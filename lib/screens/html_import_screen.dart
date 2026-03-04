// lib/screens/html_import_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

class HtmlImportScreen extends StatefulWidget {
  const HtmlImportScreen({super.key});
  @override
  State<HtmlImportScreen> createState() => _HtmlImportScreenState();
}

// ── Önizleme satırı (Excel ile aynı yapı) ───────────────────
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
    final bas   = baslangic ?? DateTime.now();
    final bit   = bitis ?? bas.add(const Duration(days: 365));
    final simdi = DateTime.now();
    final durum = (bas.isBefore(simdi) ||
        (bas.year == simdi.year && bas.month == simdi.month && bas.day == simdi.day))
        ? PoliceStatus.yapildi
        : PoliceStatus.beklemede;

    return Police(
      musteriAdi:      musteriAdi,
      soyadi:          soyadi,
      telefon:         telefon.isEmpty ? '-' : telefon,
      tcKimlikNo:      tcKimlik.isEmpty ? null : tcKimlik,
      sirket:          sirket,
      tur:             tur,
      policeNo:        policeNo.isEmpty ? null : policeNo,
      belgeSeriNo:     belgeSeriNo.isEmpty ? null : belgeSeriNo,
      aracPlaka:       plaka.isEmpty ? null : plaka,
      baslangicTarihi: bas,
      bitisTarihi:     bit,
      tutar:           tutar,
      komisyon:        komisyon,
      durum:           durum,
    );
  }
}

class _HtmlImportScreenState extends State<HtmlImportScreen> {
  final _db = DatabaseService();

  List<_Satir> _satirlar    = [];
  bool         _yukleniyor  = false;
  bool         _kaydediliyor = false;
  String?      _dosyaAdi;
  List<String> _hatalar     = [];

  // ── HTML dosyası seç ve parse et ────────────────────────────
  Future<void> _dosyaSec() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final file = res.files.first;
    if (file.bytes == null) return;

    setState(() { _yukleniyor = true; _hatalar = []; _satirlar = []; });

    try {
      final html = String.fromCharCodes(file.bytes!);
      final parsed = _parseHtml(html);

      setState(() {
        _satirlar   = parsed;
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

  // ── HTML parser ─────────────────────────────────────────────
  List<_Satir> _parseHtml(String html) {
    // 1. Tüm <table> bloklarını bul
    final tableRegex = RegExp(r'<table[^>]*>([\s\S]*?)</table>', caseSensitive: false);
    final tableMatches = tableRegex.allMatches(html).toList();
    if (tableMatches.isEmpty) {
      _hatalar = ['HTML içinde tablo bulunamadı'];
      return [];
    }

    // En fazla satır içeren tabloyu kullan
    List<List<String>> enIyiTablo = [];
    for (final tm in tableMatches) {
      final rows = _satirlariCikar(tm.group(0) ?? '');
      if (rows.length > enIyiTablo.length) enIyiTablo = rows;
    }

    if (enIyiTablo.isEmpty) return [];

    // 2. Başlık satırını bul (ilk satır)
    final header = enIyiTablo.first.map((h) =>
      h.toUpperCase().trim()
        .replaceAll('İ', 'I').replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G').replaceAll('Ç', 'C')
        .replaceAll('Ö', 'O').replaceAll('Ü', 'U')
    ).toList();

    // Sütun eşleme
    int? col(List<String> keys) {
      for (int i = 0; i < header.length; i++) {
        for (final k in keys) {
          if (header[i].contains(k)) return i;
        }
      }
      return null;
    }

    final iSirket    = col(['SIRKET', 'SIGORTA SIRKETI', 'FIRMA']);
    final iPolice    = col(['POLICE TURU', 'BRANS', 'TUR', 'SIGORTA TURU', 'URUN']);
    final iMusteri   = col(['MUSTERI', 'AD SOYAD', 'SIGORTALI', 'ISIM']);
    final iTC        = col(['TC', 'KIMLIK NO', 'TC NO']);
    final iTelefon   = col(['TELEFON', 'GSM', 'CEP']);
    final iPoliceNo  = col(['POLICE NO', 'POLICENO', 'BELGE NO']);
    final iBelgeSeri = col(['BELGE SERI', 'SERI NO']);
    final iPlaka     = col(['PLAKA', 'ARAC PLAKA']);
    final iBaslangic = col(['BASLANGIC', 'BASLANGIÇ', 'BASL', 'TANZIM', 'BASLAMA']);
    final iBitis     = col(['BITIS', 'BITIS TARIHI', 'VADE', 'BITIS TARIHI']);
    final iBrut      = col(['BRUT', 'PRIM', 'PRM', 'TUTAR', 'NET PRIM', 'TOPLAM']);
    final iKomisyon  = col(['KOMISYON', 'KOM']);

    final satirlar = <_Satir>[];

    String get(List<String> row, int? idx) =>
        (idx != null && idx < row.length) ? _temizle(row[idx]) : '';

    for (int r = 1; r < enIyiTablo.length; r++) {
      final row = enIyiTablo[r];
      if (row.every((c) => c.trim().isEmpty)) continue;

      final musteriTam = get(row, iMusteri).trim();
      if (musteriTam.isEmpty) continue;

      final parcalar = musteriTam.split(RegExp(r'\s+'));
      final ad   = parcalar.first;
      final soyad = parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '';

      final basStr = get(row, iBaslangic);
      final bitStr = get(row, iBitis);
      final bas    = _tarihParse(basStr);
      final bit    = _tarihParse(bitStr);

      String? hata;
      if (bas == null && basStr.isNotEmpty) hata = 'Başlangıç tarihi okunamadı';
      if (bit == null && bitStr.isNotEmpty) hata = (hata != null ? '$hata, ' : '') + 'Bitiş tarihi okunamadı';

      final tutar    = _sayiParse(get(row, iBrut));
      final komisyon = _sayiParse(get(row, iKomisyon));

      satirlar.add(_Satir(
        idx:        r,
        musteriAdi: ad,
        soyadi:     soyad,
        telefon:    get(row, iTelefon),
        tcKimlik:   get(row, iTC),
        sirket:     get(row, iSirket),
        tur:        PoliceTypeX.fromExcel(get(row, iPolice)),
        policeNo:   get(row, iPoliceNo),
        belgeSeriNo:get(row, iBelgeSeri),
        plaka:      get(row, iPlaka),
        baslangic:  bas,
        bitis:      bit,
        tutar:      tutar,
        komisyon:   komisyon,
        hata:       hata,
        secili:     hata == null,
      ));
    }

    return satirlar;
  }

  // HTML tablodaki satır ve hücreleri çıkar
  List<List<String>> _satirlariCikar(String tableHtml) {
    final rows   = <List<String>>[];
    final trReg  = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final tdReg  = RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false);

    for (final trMatch in trReg.allMatches(tableHtml)) {
      final cells = <String>[];
      for (final tdMatch in tdReg.allMatches(trMatch.group(1) ?? '')) {
        cells.add(_htmlMetin(tdMatch.group(1) ?? ''));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  // HTML tag'leri temizle, entity decode et
  String _htmlMetin(String html) {
    String s = html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
    return s;
  }

  String _temizle(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  double _sayiParse(String s) {
    s = s.replaceAll('₺', '').replaceAll(' ', '').replaceAll('\u00a0', '').trim();
    if (s.isEmpty) return 0;
    final raw = double.tryParse(s);
    if (raw != null) return raw;
    if (s.contains(',') && s.contains('.')) {
      final lastComma = s.lastIndexOf(',');
      final lastDot   = s.lastIndexOf('.');
      if (lastComma > lastDot) {
        return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
      } else {
        return double.tryParse(s.replaceAll(',', '')) ?? 0;
      }
    }
    if (s.contains(',')) return double.tryParse(s.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  DateTime? _tarihParse(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
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
    ];
    for (final f in formatlar) {
      try { return f.parseStrict(s); } catch (_) {}
    }
    return DateTime.tryParse(s);
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

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final secili   = _satirlar.where((s) => s.secili).length;
    final fmt      = DateFormat('d MMM yyyy', 'tr');
    final moneyFmt = NumberFormat.currency(locale: 'tr', symbol: '₺', decimalDigits: 2);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBgCard,
        title: const Text("HTML'den Aktar",
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
              const Row(children: [
                Icon(Icons.error_outline, color: kDanger, size: 16),
                SizedBox(width: 6),
                Text('Uyarılar', style: TextStyle(fontWeight: FontWeight.w800, color: kDanger)),
              ]),
              const SizedBox(height: 6),
              ..._hatalar.map((e) => Text(e,
                  style: const TextStyle(fontSize: 12.5, color: kDanger))),
            ]),
          ),

        // Dosya seç ekranı
        if (_satirlar.isEmpty && !_yukleniyor)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.html_rounded, color: Color(0xFF2E7D32), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('HTML dosyası seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 6),
            const Text(
              'Şirket, Poliçe Türü, Müşteri, TC, Telefon,\nPoliçe No, Belge Seri, Plaka, Başlangıç, Bitiş,\nPrim, Komisyon sütunlarını otomatik okur',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSub, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _dosyaSec,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Dosya Seç (.html / .htm)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),
            // Bilgi notu
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withOpacity(0.15)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, size: 14, color: kPrimary),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Sigorta şirketlerinin web sitesinden indirilen üretim listesi HTML dosyaları desteklenir. Dosyada en az bir HTML tablosu (<table>) bulunmalıdır.',
                  style: TextStyle(fontSize: 11, color: kPrimary, height: 1.4),
                )),
              ]),
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
                Text(_dosyaAdi ?? '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText),
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
                    Row(children: [
                      Text(s.tur.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${s.musteriAdi} ${s.soyadi}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kText))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(s.tur.label,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32))),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    Row(children: [
                      if (s.sirket.isNotEmpty) ...[
                        const Icon(Icons.business_rounded, size: 11, color: kTextSub),
                        const SizedBox(width: 4),
                        Text(s.sirket,
                            style: const TextStyle(fontSize: 11.5, color: kTextSub, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                      ],
                      if (s.tcKimlik.isNotEmpty) ...[
                        const Icon(Icons.badge_outlined, size: 11, color: kTextSub),
                        const SizedBox(width: 4),
                        Text(s.tcKimlik,
                            style: const TextStyle(fontSize: 11, color: kTextSub)),
                      ],
                    ]),

                    if (s.policeNo.isNotEmpty || s.belgeSeriNo.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
                    ],

                    if (s.plaka.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.directions_car_rounded, size: 11, color: kPrimary),
                        const SizedBox(width: 4),
                        Text(s.plaka,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kPrimary)),
                      ]),
                    ],
                    const SizedBox(height: 6),

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
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
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
