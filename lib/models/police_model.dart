// ============================================================
// lib/models/police_model.dart  –  v3
// Tüm sigorta türleri, takvim notu desteği, genişletilmiş form
// ============================================================

enum PoliceStatus { beklemede, yapildi, yapilamadi, dahaSonra }

// ── Tüm sigorta türleri ──────────────────────────────────────
enum PoliceType {
  trafik,             // Zorunlu Trafik
  kasko,              // Kasko
  dask,               // DASK (Zorunlu Deprem)
  konut,              // Konut Sigortası
  ozelSaglik,         // Özel Sağlık Sigortası
  tamamlayiciSaglik,  // Tamamlayıcı Sağlık Sigortası
  hayat,              // Hayat Sigortası
  ferdiKaza,          // Ferdi Kaza
  isyeri,             // İşyeri Sigortası
  nakliyat,           // Nakliyat Sigortası
  tarim,              // Tarım Sigortası
  seyahat,            // Seyahat Sağlık Sigortası
  diger,              // Diğer
}

extension PoliceTypeExt on PoliceType {
  String get adi {
    const m = {
      PoliceType.trafik:            'Trafik',
      PoliceType.kasko:             'Kasko',
      PoliceType.dask:              'DASK',
      PoliceType.konut:             'Konut',
      PoliceType.ozelSaglik:        'Özel Sağlık',
      PoliceType.tamamlayiciSaglik: 'Tamamlayıcı Sağlık',
      PoliceType.hayat:             'Hayat',
      PoliceType.ferdiKaza:         'Ferdi Kaza',
      PoliceType.isyeri:            'İşyeri',
      PoliceType.nakliyat:          'Nakliyat',
      PoliceType.tarim:             'Tarım',
      PoliceType.seyahat:           'Seyahat Sağlık',
      PoliceType.diger:             'Diğer',
    };
    return m[this]!;
  }

  String get emoji {
    const m = {
      PoliceType.trafik:            '🚗',
      PoliceType.kasko:             '🛡️',
      PoliceType.dask:              '🏚️',
      PoliceType.konut:             '🏠',
      PoliceType.ozelSaglik:        '🏥',
      PoliceType.tamamlayiciSaglik: '❤️‍🩹',
      PoliceType.hayat:             '💚',
      PoliceType.ferdiKaza:         '🦺',
      PoliceType.isyeri:            '🏢',
      PoliceType.nakliyat:          '🚢',
      PoliceType.tarim:             '🌾',
      PoliceType.seyahat:           '✈️',
      PoliceType.diger:             '📄',
    };
    return m[this]!;
  }

  // Araç bilgisi gerektiren türler
  bool get aracGerektiriyor =>
      this == PoliceType.trafik || this == PoliceType.kasko;

  // Konut/DASK için adres
  bool get adresGerektiriyor =>
      this == PoliceType.konut || this == PoliceType.dask;
}

// ── Ana Model ────────────────────────────────────────────────
class Police {
  final int?    id;

  // Müşteri
  final String  musteriAdi;
  final String  soyadi;
  final String  telefon;
  final String? email;
  final String? tcKimlikNo;
  final String? dogumTarihi;

  // Poliçe
  final String     sirket;
  final PoliceType tur;
  final String?    ozelTurAdi;     // Tür=Diğer ise özel isim
  final DateTime   baslangicTarihi;
  final DateTime   bitisTarihi;
  final double     tutar;
  final String?    belgeSeriNo;
  final PoliceStatus durum;
  final DateTime   olusturmaTarihi;

  // Araç (Kasko/Trafik)
  final String? aracPlaka;
  final String? aracMarka;
  final String? aracModel;
  final String? aracYil;
  final String? ruhsatSeriNo;

  // Konut/DASK
  final String? adres;
  final String? uavt;             // Adres kodu

  // PDF
  final String? pdfDosyaYolu;

  // "Daha Sonra" hatırlatıcı
  final DateTime? hatirlaticiTarihi;
  final String?   hatirlaticiNotu;

  // Takvim notu (ileri tarihli)
  final DateTime? takvimNotu_Tarih;
  final String?   takvimNotu_Icerik;

  // Genel not
  final String? notlar;

  const Police({
    this.id,
    required this.musteriAdi,
    required this.soyadi,
    required this.telefon,
    this.email,
    this.tcKimlikNo,
    this.dogumTarihi,
    required this.sirket,
    required this.tur,
    this.ozelTurAdi,
    required this.baslangicTarihi,
    required this.bitisTarihi,
    required this.tutar,
    this.belgeSeriNo,
    this.durum = PoliceStatus.beklemede,
    required this.olusturmaTarihi,
    this.aracPlaka,
    this.aracMarka,
    this.aracModel,
    this.aracYil,
    this.ruhsatSeriNo,
    this.adres,
    this.uavt,
    this.pdfDosyaYolu,
    this.hatirlaticiTarihi,
    this.hatirlaticiNotu,
    this.takvimNotu_Tarih,
    this.takvimNotu_Icerik,
    this.notlar,
  });

  String get tamAd => '$musteriAdi $soyadi';
  int    get kalanGun => bitisTarihi.difference(DateTime.now()).inDays;
  bool   get pdfVarMi => pdfDosyaYolu != null && pdfDosyaYolu!.isNotEmpty;

  /// Eğer tür "Diğer" ise ozelTurAdi, aksi hâlde tur.adi döner.
  String get goruntulenenTur =>
      ozelTurAdi?.isNotEmpty == true ? ozelTurAdi! : tur.adi;

  // ── DB Dönüşümleri ──────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'id':                    id,
    'musteri_adi':           musteriAdi,
    'soyadi':                soyadi,
    'telefon':               telefon,
    'email':                 email,
    'tc_kimlik_no':          tcKimlikNo,
    'dogum_tarihi':          dogumTarihi,
    'sirket':                sirket,
    'tur':                   tur.index,
    'ozel_tur_adi':          ozelTurAdi,
    'baslangic_tarihi':      baslangicTarihi.toIso8601String(),
    'bitis_tarihi':          bitisTarihi.toIso8601String(),
    'tutar':                 tutar,
    'belge_seri_no':         belgeSeriNo,
    'durum':                 durum.index,
    'olusturma_tarihi':      olusturmaTarihi.toIso8601String(),
    'arac_plaka':            aracPlaka,
    'arac_marka':            aracMarka,
    'arac_model':            aracModel,
    'arac_yil':              aracYil,
    'ruhsat_seri_no':        ruhsatSeriNo,
    'adres':                 adres,
    'uavt':                  uavt,
    'pdf_dosya_yolu':        pdfDosyaYolu,
    'hatirlatici_tarihi':    hatirlaticiTarihi?.toIso8601String(),
    'hatirlatici_notu':      hatirlaticiNotu,
    'takvim_notu_tarih':     takvimNotu_Tarih?.toIso8601String(),
    'takvim_notu_icerik':    takvimNotu_Icerik,
    'notlar':                notlar,
  };

  factory Police.fromMap(Map<String, dynamic> m) => Police(
    id:                   m['id'] as int?,
    musteriAdi:           m['musteri_adi'] as String,
    soyadi:               m['soyadi'] as String,
    telefon:              m['telefon'] as String,
    email:                m['email'] as String?,
    tcKimlikNo:           m['tc_kimlik_no'] as String?,
    dogumTarihi:          m['dogum_tarihi'] as String?,
    sirket:               m['sirket'] as String,
    tur:                  PoliceType.values[m['tur'] as int],
    ozelTurAdi:           m['ozel_tur_adi'] as String?,
    baslangicTarihi:      DateTime.parse(m['baslangic_tarihi'] as String),
    bitisTarihi:          DateTime.parse(m['bitis_tarihi'] as String),
    tutar:                (m['tutar'] as num).toDouble(),
    belgeSeriNo:          m['belge_seri_no'] as String?,
    durum:                PoliceStatus.values[m['durum'] as int],
    olusturmaTarihi:      DateTime.parse(m['olusturma_tarihi'] as String),
    aracPlaka:            m['arac_plaka'] as String?,
    aracMarka:            m['arac_marka'] as String?,
    aracModel:            m['arac_model'] as String?,
    aracYil:              m['arac_yil'] as String?,
    ruhsatSeriNo:         m['ruhsat_seri_no'] as String?,
    adres:                m['adres'] as String?,
    uavt:                 m['uavt'] as String?,
    pdfDosyaYolu:         m['pdf_dosya_yolu'] as String?,
    hatirlaticiTarihi:    m['hatirlatici_tarihi'] != null
                              ? DateTime.parse(m['hatirlatici_tarihi'] as String)
                              : null,
    hatirlaticiNotu:      m['hatirlatici_notu'] as String?,
    takvimNotu_Tarih:     m['takvim_notu_tarih'] != null
                              ? DateTime.parse(m['takvim_notu_tarih'] as String)
                              : null,
    takvimNotu_Icerik:    m['takvim_notu_icerik'] as String?,
    notlar:               m['notlar'] as String?,
  );

  Police copyWith({
    int? id, String? musteriAdi, String? soyadi, String? telefon,
    String? email, String? tcKimlikNo, String? dogumTarihi,
    String? sirket, PoliceType? tur, String? ozelTurAdi,
    DateTime? baslangicTarihi, DateTime? bitisTarihi, double? tutar,
    String? belgeSeriNo, PoliceStatus? durum, DateTime? olusturmaTarihi,
    String? aracPlaka, String? aracMarka, String? aracModel,
    String? aracYil, String? ruhsatSeriNo, String? adres, String? uavt,
    String? pdfDosyaYolu, DateTime? hatirlaticiTarihi,
    String? hatirlaticiNotu, DateTime? takvimNotu_Tarih,
    String? takvimNotu_Icerik, String? notlar,
  }) => Police(
    id: id ?? this.id,
    musteriAdi: musteriAdi ?? this.musteriAdi,
    soyadi: soyadi ?? this.soyadi,
    telefon: telefon ?? this.telefon,
    email: email ?? this.email,
    tcKimlikNo: tcKimlikNo ?? this.tcKimlikNo,
    dogumTarihi: dogumTarihi ?? this.dogumTarihi,
    sirket: sirket ?? this.sirket,
    tur: tur ?? this.tur,
    ozelTurAdi: ozelTurAdi ?? this.ozelTurAdi,
    baslangicTarihi: baslangicTarihi ?? this.baslangicTarihi,
    bitisTarihi: bitisTarihi ?? this.bitisTarihi,
    tutar: tutar ?? this.tutar,
    belgeSeriNo: belgeSeriNo ?? this.belgeSeriNo,
    durum: durum ?? this.durum,
    olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
    aracPlaka: aracPlaka ?? this.aracPlaka,
    aracMarka: aracMarka ?? this.aracMarka,
    aracModel: aracModel ?? this.aracModel,
    aracYil: aracYil ?? this.aracYil,
    ruhsatSeriNo: ruhsatSeriNo ?? this.ruhsatSeriNo,
    adres: adres ?? this.adres,
    uavt: uavt ?? this.uavt,
    pdfDosyaYolu: pdfDosyaYolu ?? this.pdfDosyaYolu,
    hatirlaticiTarihi: hatirlaticiTarihi ?? this.hatirlaticiTarihi,
    hatirlaticiNotu: hatirlaticiNotu ?? this.hatirlaticiNotu,
    takvimNotu_Tarih: takvimNotu_Tarih ?? this.takvimNotu_Tarih,
    takvimNotu_Icerik: takvimNotu_Icerik ?? this.takvimNotu_Icerik,
    notlar: notlar ?? this.notlar,
  );
}
