import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:intl/intl.dart';
import '../models/police_model.dart';
import '../services/database_service.dart';

// Grup içindeki kişi detayları
class _KisiDetay {
  final String ad;
  final String soyad;
  final String tcKimlik;
  
  _KisiDetay({
    required this.ad,
    required this.soyad,
    this.tcKimlik = '',
  });
}

class HtmlImportScreen extends StatefulWidget {
  const HtmlImportScreen({super.key});
  @override
  State<HtmlImportScreen> createState() => _HtmlImportScreenState();
}

class _Satir {
  final int idx;
  String musteriAdi, soyadi, tcKimlik;
  String sirket, policeNo, belgeSeriNo, plaka;
  PoliceType tur;
  DateTime? baslangic, bitis;
  double tutar, komisyon;
  bool secili;
  String? hata;
  
  // Grup bilgileri
  List<_KisiDetay>? grupKisileri;
  bool isGrupBasligi;
  String? grupTipi; // 'bireysel', 'aile', 'grup'

  _Satir({
    required this.idx,
    required this.musteriAdi,
    this.soyadi = '',
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
    this.grupKisileri,
    this.isGrupBasligi = false,
    this.grupTipi,
  });

  Police toPolice() {
    final bas   = baslangic ?? DateTime.now();
    final bit   = bitis ?? bas.add(const Duration(days: 365));
    
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
      musteriAdi:      musteriAdi,
      soyadi:          soyadi,
      telefon:         '-',
      tcKimlikNo:      tcKimlik.isEmpty ? null : tcKimlik,
      sirket:          sirket,
      tur:             tur,
      policeNo:        null,
      belgeSeriNo:     policeNo.isEmpty ? null : policeNo,  // HTML'deki Police No → Poliçe Numarası alanı
      ruhsatSeriNo:    belgeSeriNo.isEmpty ? null : belgeSeriNo, // HTML'deki Belge Seri → Ruhsat Seri No
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

  List<_Satir>     _satirlar     = [];
  List<ZeyilKayit> _zeyiller     = [];
  bool             _yukleniyor   = false;
  bool             _kaydediliyor = false;
  String?          _dosyaAdi;
  List<String>     _hatalar      = [];

  Future<void> _dosyaSec() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.bytes == null) return;

    setState(() { _yukleniyor = true; _hatalar = []; _satirlar = []; _zeyiller = []; });

    try {
      String html;
      try {
        html = String.fromCharCodes(file.bytes!);
      } catch (_) {
        html = String.fromCharCodes(file.bytes!);
      }

      final result = _parseHtml(html);
      setState(() {
        _satirlar   = result.$1;
        _zeyiller   = result.$2;
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

  // ── HTML Entity decode ───────────────────────────────────────
  String _decodeHtmlEntities(String s) {
    return s
      // Türkçe karakterler (numeric entity)
      .replaceAll('&#220;', 'Ü').replaceAll('&#252;', 'ü')
      .replaceAll('&#214;', 'Ö').replaceAll('&#246;', 'ö')
      .replaceAll('&#199;', 'Ç').replaceAll('&#231;', 'ç')
      .replaceAll('&#350;', 'Ş').replaceAll('&#351;', 'ş')
      .replaceAll('&#304;', 'İ').replaceAll('&#305;', 'ı')
      .replaceAll('&#286;', 'Ğ').replaceAll('&#287;', 'ğ')
      // Named entities
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      // Hex entities yaygın olanlar
      .replaceAll('&#xDC;', 'Ü').replaceAll('&#xfc;', 'ü')
      .replaceAll('&#xD6;', 'Ö').replaceAll('&#xf6;', 'ö')
      .replaceAll('&#xC7;', 'Ç').replaceAll('&#xe7;', 'ç')
      .replaceAll('&#x15E;', 'Ş').replaceAll('&#x15f;', 'ş')
      .replaceAll('&#x130;', 'İ').replaceAll('&#x131;', 'ı')
      .replaceAll('&#x11E;', 'Ğ').replaceAll('&#x11f;', 'ğ');
  }

  // ── HTML Parser ──────────────────────────────────────────────
  (List<_Satir>, List<ZeyilKayit>) _parseHtml(String html) {
    // Entity decode önce
    html = _decodeHtmlEntities(html);

    // En büyük tabloyu bul
    final tableReg = RegExp(r'<table[^>]*>([\s\S]*?)</table>', caseSensitive: false);
    final tables   = tableReg.allMatches(html).toList();
    if (tables.isEmpty) {
      _hatalar = ['HTML içinde <table> bulunamadı'];
      return ([], []);
    }

    List<List<String>> enIyi = [];
    for (final t in tables) {
      final rows = _rowlariCikar(t.group(0) ?? '');
      if (rows.length > enIyi.length) enIyi = rows;
    }
    if (enIyi.isEmpty) return ([], []);

    // ── Başlık satırından sütun indekslerini bul ──
    final header = enIyi.first.map((h) => h.trim().toUpperCase()
        .replaceAll('İ', 'I').replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G').replaceAll('Ç', 'C')
        .replaceAll('Ö', 'O').replaceAll('Ü', 'U')).toList();

    int? idx(List<String> keys) {
      for (int i = 0; i < header.length; i++) {
        for (final k in keys) {
          if (header[i].contains(k)) return i;
        }
      }
      return null;
    }

    // Sütun eşleştirme — HTML dosyasındaki gerçek başlıklara göre
    final iSirket    = idx(['SIRKET']);
    final iPolice    = idx(['POLICE']) ?? idx(['BRANS']);
    final iKayitTuru = idx(['KAYIT TURU', 'KAYIT']);
    final iTC        = idx(['TC', 'VERGI NO', 'TC / VERGI']);
    final iMusteri   = idx(['MUSTERI', 'SIGORTALI', 'AD SOYAD']);
    final iPoliceNo  = idx(['POLICE NO', 'POLICENO']);
    final iPlaka     = idx(['PLAKA']);
    final iBelgeSeri = idx(['BELGE SERI', 'BELGE']);
    final iTanzim    = idx(['TANZIM']);
    final iBaslangic = idx(['BASLANGIC', 'BASLANGIÇ']);
    final iBitis     = idx(['BITIS']);
    final iBrut      = idx(['BRUT']);
    final iKomisyon  = idx(['KOMISYON']);

    final satirlar  = <_Satir>[];
    final zeyilList = <ZeyilKayit>[];

    String get(List<String> row, int? i) =>
        (i != null && i < row.length) ? row[i].trim() : '';

    for (int r = 1; r < enIyi.length; r++) {
      final row = enIyi[r];
      if (row.every((c) => c.trim().isEmpty)) continue;

      final kayitTuruRaw = get(row, iKayitTuru);
      final kayitTuruUp  = kayitTuruRaw.toUpperCase()
          .replaceAll('İ', 'I').replaceAll('Ç', 'C');

      // Son satır kontrolü (örn: "26 Adet")
      final sirketVal = get(row, iSirket).trim();
      if (sirketVal.isEmpty || RegExp(r'^\d+\s*(Adet|adet|ADET)').hasMatch(sirketVal)) continue;

      final tutar    = _sayiParse(get(row, iBrut));
      final komisyon = _sayiParse(get(row, iKomisyon));
      final policeStr = get(row, iPolice);
      final musteriTam = get(row, iMusteri).trim();
      if (musteriTam.isEmpty) continue;

      // ── Zeyil/İptal → zeyiller tablosuna kaydet ──
      if (kayitTuruUp.contains('ZEYIL') || kayitTuruUp.contains('IPTAL')) {
        final tanzimStr = get(row, iTanzim);
        final tanzim    = _tarihParse(tanzimStr) ??
                          _tarihParse(get(row, iBaslangic)) ??
                          DateTime.now();

        // İptal → eksi, Prim Zeyil+ → artı (mutlak değer al, işareti kayitTuru belirler)
        final rawTutar    = _sayiParse(get(row, iBrut));
        final rawKomisyon = _sayiParse(get(row, iKomisyon));
        final isIptal     = kayitTuruUp.contains('IPTAL');
        final zeyilTutar    = isIptal ? -rawTutar.abs()    : rawTutar.abs();
        final zeyilKomisyon = isIptal ? -rawKomisyon.abs() : rawKomisyon.abs();

        zeyilList.add(ZeyilKayit(
          yil:          tanzim.year,
          ay:           tanzim.month,
          sirket:       sirketVal,
          musteriAdi:   musteriTam,
          policeNo:     get(row, iPoliceNo),
          tur:          PoliceTypeX.fromExcel(policeStr),
          tutar:        zeyilTutar,
          komisyon:     zeyilKomisyon,
          kayitTuru:    kayitTuruRaw,
          tanzimTarihi: tanzim,
        ));
        continue;
      }

      // ── Normal poliçe ──
      final parcalar = musteriTam.split(RegExp(r'\s+'));
      final ad    = parcalar.first;
      final soyad = parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '';

      final basStr = get(row, iBaslangic);
      final bitStr = get(row, iBitis);
      final bas    = _tarihParse(basStr);
      final bit    = _tarihParse(bitStr);

      String? hata;
      if (bas == null && basStr.isNotEmpty) hata = 'Başlangıç tarihi okunamadı';
      if (bit == null && bitStr.isNotEmpty) hata = (hata != null ? '$hata, ' : '') + 'Bitiş tarihi okunamadı';

      satirlar.add(_Satir(
        idx:         r,
        musteriAdi:  ad,
        soyadi:      soyad,
        tcKimlik:    get(row, iTC),
        sirket:      sirketVal,
        tur:         PoliceTypeX.fromExcel(policeStr),
        policeNo:    get(row, iPoliceNo),
        belgeSeriNo: get(row, iBelgeSeri),
        plaka:       get(row, iPlaka),
        baslangic:   bas,
        bitis:       bit,
        tutar:       tutar,
        komisyon:    komisyon,
        hata:        hata,
        secili:      hata == null,
      ));
    }

    return (_grupla(satirlar), zeyilList);
  }

  // ── Poliçe numarasına göre gruplama ──
  List<_Satir> _grupla(List<_Satir> satirlar) {
    if (satirlar.isEmpty) return [];
    
    // Poliçe numarasına göre grupla
    final Map<String, List<_Satir>> gruplar = {};
    
    for (final satir in satirlar) {
      final policeNo = satir.policeNo.trim();
      if (policeNo.isEmpty) {
        // Poliçe numarası yoksa tek başına göster
        gruplar[satir.idx.toString()] = [satir];
        continue;
      }
      
      if (!gruplar.containsKey(policeNo)) {
        gruplar[policeNo] = [];
      }
      gruplar[policeNo]!.add(satir);
    }
    
    // Grupları işle ve tek liste haline getir
    final sonuc = <_Satir>[];
    
    for (final entry in gruplar.entries) {
      final grup = entry.value;
      
      if (grup.length == 1) {
        // Tek kişi → olduğu gibi ekle
        sonuc.add(grup.first);
      } else if (grup.length >= 2 && grup.length < 10) {
        // 2-9 kişi → Aile/Bireysel grup poliçesi
        final ilk = grup.first;
        final kisiDetaylar = grup.map((s) => _KisiDetay(
          ad: s.musteriAdi,
          soyad: s.soyadi,
          tcKimlik: s.tcKimlik,
        )).toList();
        
        // Toplam tutar ve komisyon hesapla
        final toplamTutar = grup.fold(0.0, (sum, s) => sum + s.tutar);
        final toplamKomisyon = grup.fold(0.0, (sum, s) => sum + s.komisyon);
        
        // İsimleri birleştir (ilk 5 kişi)
        final kisiSayisi = grup.length;
        final gosterilecekKisiSayisi = kisiSayisi > 5 ? 5 : kisiSayisi;
        final isimler = grup.take(gosterilecekKisiSayisi).map((s) => '${s.musteriAdi} ${s.soyadi}').join(', ');
        final ekMesaj = kisiSayisi > 5 ? ' +${kisiSayisi - 5} kişi' : '';
        
        sonuc.add(_Satir(
          idx: ilk.idx,
          musteriAdi: isimler + ekMesaj,
          soyadi: '',
          tcKimlik: ilk.tcKimlik,
          sirket: ilk.sirket,
          tur: ilk.tur,
          policeNo: ilk.policeNo,
          belgeSeriNo: ilk.belgeSeriNo,
          plaka: ilk.plaka,
          baslangic: ilk.baslangic,
          bitis: ilk.bitis,
          tutar: toplamTutar,
          komisyon: toplamKomisyon,
          hata: ilk.hata,
          secili: ilk.secili,
          grupKisileri: kisiDetaylar,
          isGrupBasligi: true,
          grupTipi: kisiSayisi <= 5 ? 'aile' : 'bireysel',
        ));
      } else if (grup.length >= 10) {
        // 10+ kişi → Grup Sağlık Sigortası
        final ilk = grup.first;
        final kisiDetaylar = grup.map((s) => _KisiDetay(
          ad: s.musteriAdi,
          soyad: s.soyadi,
          tcKimlik: s.tcKimlik,
        )).toList();
        
        final toplamTutar = grup.fold(0.0, (sum, s) => sum + s.tutar);
        final toplamKomisyon = grup.fold(0.0, (sum, s) => sum + s.komisyon);
        
        sonuc.add(_Satir(
          idx: ilk.idx,
          musteriAdi: 'Grup Sağlık Sigortası (${grup.length} kişi)',
          soyadi: '',
          tcKimlik: ilk.tcKimlik,
          sirket: ilk.sirket,
          tur: ilk.tur,
          policeNo: ilk.policeNo,
          belgeSeriNo: ilk.belgeSeriNo,
          plaka: ilk.plaka,
          baslangic: ilk.baslangic,
          bitis: ilk.bitis,
          tutar: toplamTutar,
          komisyon: toplamKomisyon,
          hata: ilk.hata,
          secili: ilk.secili,
          grupKisileri: kisiDetaylar,
          isGrupBasligi: true,
          grupTipi: 'grup',
        ));
      }
    }
    
    return sonuc;
  }

  // ── HTML tablo satır/hücre çıkarma ───────────────────────────
  List<List<String>> _rowlariCikar(String tableHtml) {
    final rows  = <List<String>>[];
    final trReg = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final tdReg = RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false);

    for (final tr in trReg.allMatches(tableHtml)) {
      final cells = <String>[];
      for (final td in tdReg.allMatches(tr.group(1) ?? '')) {
        cells.add(_htmlMetin(td.group(1) ?? ''));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  String _htmlMetin(String html) => html
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

  double _sayiParse(String s) {
    s = s.replaceAll('₺', '').replaceAll('\u00a0', '').replaceAll(' ', '').trim();
    if (s.isEmpty || s == '-') return 0;
    // Negatif değerler (iptal zeyil) — zaten filtrelendi ama yine de
    final neg = s.startsWith('-');
    s = s.replaceAll('-', '');
    double val = 0;
    if (s.contains(',') && s.contains('.')) {
      final lastComma = s.lastIndexOf(',');
      final lastDot   = s.lastIndexOf('.');
      val = lastComma > lastDot
          ? double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0
          : double.tryParse(s.replaceAll(',', '')) ?? 0;
    } else if (s.contains(',')) {
      val = double.tryParse(s.replaceAll(',', '.')) ?? 0;
    } else {
      val = double.tryParse(s) ?? 0;
    }
    return neg ? -val : val;
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
    ];
    for (final f in formatlar) {
      try { return f.parseStrict(s); } catch (_) {}
    }
    return DateTime.tryParse(s);
  }

  // ── Kaydet ───────────────────────────────────────────────────
  Future<void> _kaydet() async {
    final secilenler = _satirlar.where((s) => s.secili).toList();
    if (secilenler.isEmpty && _zeyiller.isEmpty) return;
    setState(() => _kaydediliyor = true);

    int basarili = 0;
    for (final s in secilenler) {
      try {
        if (s.isGrupBasligi && s.grupKisileri != null && s.grupKisileri!.isNotEmpty) {
          // Grup poliçesi - her kişi için ayrı kayıt oluştur
          for (final kisi in s.grupKisileri!) {
            final police = Police(
              musteriAdi:      kisi.ad,
              soyadi:          kisi.soyad,
              telefon:         '-',
              tcKimlikNo:      kisi.tcKimlik.isEmpty ? null : kisi.tcKimlik,
              sirket:          s.sirket,
              tur:             s.tur,
              policeNo:        null,
              belgeSeriNo:     s.policeNo.isEmpty ? null : s.policeNo,
              ruhsatSeriNo:    s.belgeSeriNo.isEmpty ? null : s.belgeSeriNo,
              aracPlaka:       s.plaka.isEmpty ? null : s.plaka,
              baslangicTarihi: s.baslangic ?? DateTime.now(),
              bitisTarihi:     s.bitis ?? (s.baslangic ?? DateTime.now()).add(const Duration(days: 365)),
              tutar:           s.tutar / s.grupKisileri!.length, // Tutarı kişi sayısına böl
              komisyon:        s.komisyon / s.grupKisileri!.length, // Komisyonu kişi sayısına böl
              durum:           (s.baslangic ?? DateTime.now()).isAfter(DateTime.now()) 
                  ? PoliceStatus.beklemede 
                  : PoliceStatus.yapildi,
            );
            await _db.ekleVeyaGuncelle(police);
          }
          basarili += s.grupKisileri!.length;
        } else {
          // Normal tekil poliçe
          await _db.ekleVeyaGuncelle(s.toPolice());
          basarili++;
        }
      } catch (_) {}
    }

    // Zeyilleri kaydet
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

  // ── Build ─────────────────────────────────────────────────────
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

        // Dosya seç
        if (_satirlar.isEmpty && !_yukleniyor)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.html_rounded, color: Color(0xFF2E7D32), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('HTML dosyası seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 6),
            const Text(
              'Sirket · Police · TC · Musteri · Police No\nPlaka · Belge Seri · Baslangic · Bitis · Brut · Komisyon',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSub, height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 13, color: Colors.orange),
                SizedBox(width: 6),
                Expanded(child: Text(
                  'Zeyil ve İptal kayıtları otomatik atlanır',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                )),
              ]),
            ),
            const SizedBox(height: 24),
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
          ]))),

        if (_yukleniyor)
          const Expanded(child: Center(child: CircularProgressIndicator(color: kPrimary))),

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
                Row(children: [
                  Text('${_satirlar.length} poliçe · $secili seçili',
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
                      child: Text('${_zeyiller.length} zeyil kaydedilecek',
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

          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
            cacheExtent: 600,
            itemCount: _satirlar.length,
            itemBuilder: (_, i) {
              final s = _satirlar[i];
              
              // Grup tipine göre başlık oluştur
              String baslik;
              if (s.isGrupBasligi && s.grupTipi == 'grup') {
                baslik = s.musteriAdi; // 'Grup Sağlık Sigortası (X kişi)' zaten hazır
              } else if (s.isGrupBasligi && s.grupKisileri != null) {
                // İsimleri göster
                baslik = s.musteriAdi; // İsimler zaten birleştirilmiş
              } else {
                baslik = '${s.musteriAdi} ${s.soyadi}';
              }
              
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
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: s.secili,
                      onChanged: (v) => setState(() => s.secili = v ?? false),
                      activeColor: kPrimary,
                      contentPadding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // İsim + tür
                        Row(children: [
                          Text(s.tur.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(baslik,
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
                        
                        // Grup badge'i
                        if (s.isGrupBasligi && s.grupKisileri != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: s.grupTipi == 'grup' 
                                    ? Colors.purple.shade50 
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: s.grupTipi == 'grup' 
                                      ? Colors.purple.shade200 
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  s.grupTipi == 'grup' 
                                      ? Icons.groups_rounded 
                                      : Icons.family_restroom_rounded,
                                  size: 12,
                                  color: s.grupTipi == 'grup' 
                                      ? Colors.purple.shade700 
                                      : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${s.grupKisileri!.length} kişi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: s.grupTipi == 'grup' 
                                        ? Colors.purple.shade700 
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ]),
                            ),
                          ]),
                        ],
                        const SizedBox(height: 6),

                        // Şirket + TC
                        Row(children: [
                          if (s.sirket.isNotEmpty) ...[
                            const Icon(Icons.business_rounded, size: 11, color: kTextSub),
                            const SizedBox(width: 4),
                            Text(s.sirket,
                                style: const TextStyle(fontSize: 11.5, color: kTextSub,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 10),
                          ],
                          if (s.tcKimlik.isNotEmpty && !s.isGrupBasligi) ...[
                            const Icon(Icons.badge_outlined, size: 11, color: kTextSub),
                            const SizedBox(width: 4),
                            Expanded(child: Text(s.tcKimlik,
                                style: const TextStyle(fontSize: 11, color: kTextSub),
                                overflow: TextOverflow.ellipsis)),
                          ],
                        ]),
                        const SizedBox(height: 4),

                        // Poliçe No + Belge Seri
                        if (s.policeNo.isNotEmpty || s.belgeSeriNo.isNotEmpty)
                          Row(children: [
                            if (s.policeNo.isNotEmpty) ...[
                              const Icon(Icons.numbers_rounded, size: 11, color: kTextSub),
                              const SizedBox(width: 3),
                              Flexible(child: Text('No: ${s.policeNo}',
                                  style: const TextStyle(fontSize: 11, color: kTextSub),
                                  overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 10),
                            ],
                            if (s.belgeSeriNo.isNotEmpty) ...[
                              const Icon(Icons.confirmation_number_outlined, size: 11, color: kTextSub),
                              const SizedBox(width: 3),
                              Flexible(child: Text('Belge Seri: ${s.belgeSeriNo}',
                                  style: const TextStyle(fontSize: 11, color: kTextSub),
                                  overflow: TextOverflow.ellipsis)),
                            ],
                          ]),

                        // Plaka
                        if (s.plaka.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.directions_car_rounded, size: 11, color: kPrimary),
                            const SizedBox(width: 4),
                            Text(s.plaka,
                                style: const TextStyle(fontSize: 11.5,
                                    fontWeight: FontWeight.w700, color: kPrimary)),
                          ]),
                        ],
                        const SizedBox(height: 6),

                        // Tarih + Tutar
                        Row(children: [
                          if (s.baslangic != null)
                            Text(fmt.format(s.baslangic!),
                                style: const TextStyle(fontSize: 11, color: kText,
                                    fontWeight: FontWeight.w600)),
                          if (s.baslangic != null && s.bitis != null)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.arrow_forward_rounded, size: 11, color: kTextSub),
                            ),
                          if (s.bitis != null)
                            Text(fmt.format(s.bitis!),
                                style: const TextStyle(fontSize: 11, color: kText,
                                    fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (s.tutar > 0)
                            Text(moneyFmt.format(s.tutar),
                                style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w800, color: kPrimary)),
                        ]),

                        // Komisyon
                        if (s.komisyon > 0) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.trending_up_rounded, size: 11, color: Colors.purple),
                            const SizedBox(width: 4),
                            Text('Komisyon: ${moneyFmt.format(s.komisyon)}',
                                style: const TextStyle(fontSize: 10.5,
                                    color: Colors.purple, fontWeight: FontWeight.w700)),
                          ]),
                        ],

                        if (s.hata != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.warning_amber_rounded, size: 12, color: kDanger),
                            const SizedBox(width: 4),
                            Expanded(child: Text(s.hata!,
                                style: const TextStyle(fontSize: 11, color: kDanger,
                                    fontWeight: FontWeight.w600))),
                          ]),
                        ],
                      ]),
                    ),
                    
                    // Grup kişileri gösterimi (açılabilir liste)
                    if (s.isGrupBasligi && s.grupKisileri != null && s.grupKisileri!.length > 1)
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          title: Text(
                            'Kişileri Görüntüle (${s.grupKisileri!.length})',
                            style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: s.grupKisileri!.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final kisi = entry.value;
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: idx < s.grupKisileri!.length - 1 ? 8 : 0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: kPrimary.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: kPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${kisi.ad} ${kisi.soyad}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: kText,
                                                ),
                                              ),
                                              if (kisi.tcKimlik.isNotEmpty)
                                                Text(
                                                  kisi.tcKimlik,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: kTextSub,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          )),
        ],
      ]),

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
