// lib/models/police_model.dart
import 'package:flutter/material.dart';

enum PoliceStatus { beklemede, yapildi, yapilamadi, dahaSonra }

/// Bitiş tarihindeki yenileme durumu
enum YenilemeStatus { belirsiz, yenilendi, yenilenemedi }

enum PoliceType {
  trafik, kasko, dask, konut,
  ozelSaglik, tamamlayiciSaglik, hayat,
  ferdiKaza, isyeri, nakliyat, tarim, seyahat, diger,
}

extension PoliceTypeX on PoliceType {
  String get label => switch (this) {
    PoliceType.trafik            => 'Trafik',
    PoliceType.kasko             => 'Kasko',
    PoliceType.dask              => 'DASK',
    PoliceType.konut             => 'Konut',
    PoliceType.ozelSaglik        => 'Özel Sağlık',
    PoliceType.tamamlayiciSaglik => 'Tamamlayıcı Sağlık',
    PoliceType.hayat             => 'Hayat',
    PoliceType.ferdiKaza         => 'Ferdi Kaza',
    PoliceType.isyeri            => 'İşyeri',
    PoliceType.nakliyat          => 'Nakliyat',
    PoliceType.tarim             => 'Tarım',
    PoliceType.seyahat           => 'Seyahat',
    PoliceType.diger             => 'Diğer',
  };

  // 'adi' getter - police_form_screen.dart'ta kullanılıyor
  String get adi => label;

  String get emoji => switch (this) {
    PoliceType.trafik            => '🚗',
    PoliceType.kasko             => '🛡️',
    PoliceType.dask              => '🏠',
    PoliceType.konut             => '🏡',
    PoliceType.ozelSaglik        => '❤️',
    PoliceType.tamamlayiciSaglik => '💊',
    PoliceType.hayat             => '🌿',
    PoliceType.ferdiKaza         => '🦺',
    PoliceType.isyeri            => '🏢',
    PoliceType.nakliyat          => '🚢',
    PoliceType.tarim             => '🌾',
    PoliceType.seyahat           => '✈️',
    PoliceType.diger             => '📄',
  };

  // Araç bilgisi gerektiren türler
  bool get aracGerektiriyor => switch (this) {
    PoliceType.trafik => true,
    PoliceType.kasko  => true,
    _                 => false,
  };

  // Adres bilgisi gerektiren türler
  bool get adresGerektiriyor => switch (this) {
    PoliceType.dask  => true,
    PoliceType.konut => true,
    _                => false,
  };

  /// Excel'deki Police sütunundan tür belirle
  static PoliceType fromExcel(String? val) {
    if (val == null) return PoliceType.diger;
    final v = val.toUpperCase().trim()
        .replaceAll('İ', 'I').replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G').replaceAll('Ç', 'C')
        .replaceAll('Ö', 'O').replaceAll('Ü', 'U');
    if (v.contains('TRAFIK'))                           return PoliceType.trafik;
    if (v.contains('KASKO'))                            return PoliceType.kasko;
    if (v.contains('DASK'))                             return PoliceType.dask;
    if (v.contains('KONUT'))                            return PoliceType.konut;
    if (v.contains('TAMAMLAYICI') || v.contains('TAMAMLAY')) return PoliceType.tamamlayiciSaglik;
    if (v.contains('SAGLIK GRUP') || v.contains('GRUP SAGLIK')) return PoliceType.ozelSaglik;
    if (v.contains('SAGLIK') || v.contains('OZEL SAGLIK')) return PoliceType.ozelSaglik;
    if (v.contains('HAYAT'))                            return PoliceType.hayat;
    if (v.contains('FERDI') || v.contains('KAZA'))      return PoliceType.ferdiKaza;
    if (v.contains('YANGIN') || v.contains('ISYERI') || v.contains('ISVERI')) return PoliceType.isyeri;
    if (v.contains('NAKLIYAT'))                         return PoliceType.nakliyat;
    if (v.contains('TARIM'))                            return PoliceType.tarim;
    if (v.contains('SEYAHAT'))                          return PoliceType.seyahat;
    return PoliceType.diger;
  }
}

class Police {
  final int? id;
  final String musteriAdi;
  final String soyadi;
  final String telefon;
  final String? email;
  final String? tcKimlikNo;
  final String? dogumTarihi;
  final String sirket;
  final PoliceType tur;
  final String? ozelTurAdi;
  final String? policeNo;
  final String? belgeSeriNo;
  final String? aracPlaka;
  final String? aracMarka;
  final String? aracModel;
  final String? aracYil;
  final String? ruhsatSeriNo;
  final String? adres;
  final String? uavt;
  final DateTime baslangicTarihi;
  final DateTime bitisTarihi;
  final double tutar;
  final double komisyon;
  final PoliceStatus durum;
  final DateTime? hatirlaticiTarihi;
  final String? notlar;
  final String? hatirlaticiNotu;
  final String? pdfDosyaYolu;
  final DateTime? olusturmaTarihi;
  final YenilemeStatus yenilemeStatus;

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
    this.policeNo,
    this.belgeSeriNo,
    this.aracPlaka,
    this.aracMarka,
    this.aracModel,
    this.aracYil,
    this.ruhsatSeriNo,
    this.adres,
    this.uavt,
    required this.baslangicTarihi,
    required this.bitisTarihi,
    this.tutar = 0,
    this.komisyon = 0,
    this.durum = PoliceStatus.beklemede,
    this.hatirlaticiTarihi,
    this.notlar,
    this.hatirlaticiNotu,
    this.pdfDosyaYolu,
    this.olusturmaTarihi,
    this.yenilemeStatus = YenilemeStatus.belirsiz,
  });

  int get kalanGun => bitisTarihi.difference(DateTime.now()).inDays;

  String get tamAd => '$musteriAdi $soyadi';

  String get goruntulenenTur => tur.label;

  Police copyWith({
    int? id, String? musteriAdi, String? soyadi, String? telefon,
    String? email, String? tcKimlikNo, String? dogumTarihi,
    String? sirket, PoliceType? tur, String? ozelTurAdi,
    String? policeNo, String? belgeSeriNo,
    String? aracPlaka, String? aracMarka, String? aracModel, String? aracYil,
    String? ruhsatSeriNo, String? adres, String? uavt,
    DateTime? baslangicTarihi, DateTime? bitisTarihi,
    double? tutar, double? komisyon, PoliceStatus? durum,
    DateTime? hatirlaticiTarihi, String? notlar, String? hatirlaticiNotu, String? pdfDosyaYolu, DateTime? olusturmaTarihi,
    YenilemeStatus? yenilemeStatus,
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
    policeNo: policeNo ?? this.policeNo,
    belgeSeriNo: belgeSeriNo ?? this.belgeSeriNo,
    aracPlaka: aracPlaka ?? this.aracPlaka,
    aracMarka: aracMarka ?? this.aracMarka,
    aracModel: aracModel ?? this.aracModel,
    aracYil: aracYil ?? this.aracYil,
    ruhsatSeriNo: ruhsatSeriNo ?? this.ruhsatSeriNo,
    adres: adres ?? this.adres,
    uavt: uavt ?? this.uavt,
    baslangicTarihi: baslangicTarihi ?? this.baslangicTarihi,
    bitisTarihi: bitisTarihi ?? this.bitisTarihi,
    tutar: tutar ?? this.tutar,
    komisyon: komisyon ?? this.komisyon,
    durum: durum ?? this.durum,
    hatirlaticiTarihi: hatirlaticiTarihi ?? this.hatirlaticiTarihi,
    notlar: notlar ?? this.notlar,
    hatirlaticiNotu: hatirlaticiNotu ?? this.hatirlaticiNotu,
    pdfDosyaYolu: pdfDosyaYolu ?? this.pdfDosyaYolu,
    olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
    yenilemeStatus: yenilemeStatus ?? this.yenilemeStatus,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'musteriAdi': musteriAdi,
    'soyadi': soyadi,
    'telefon': telefon,
    'email': email,
    'tcKimlikNo': tcKimlikNo,
    'dogumTarihi': dogumTarihi,
    'sirket': sirket,
    'tur': tur.index,
    'ozelTurAdi': ozelTurAdi,
    'policeNo': policeNo,
    'belgeSeriNo': belgeSeriNo,
    'aracPlaka': aracPlaka,
    'aracMarka': aracMarka,
    'aracModel': aracModel,
    'aracYil': aracYil,
    'ruhsatSeriNo': ruhsatSeriNo,
    'adres': adres,
    'uavt': uavt,
    'baslangicTarihi': baslangicTarihi.toIso8601String(),
    'bitisTarihi': bitisTarihi.toIso8601String(),
    'tutar': tutar,
    'komisyon': komisyon,
    'durum': durum.index,
    'hatirlaticiTarihi': hatirlaticiTarihi?.toIso8601String(),
    'notlar': notlar,
    'hatirlaticiNotu': hatirlaticiNotu,
    'pdfDosyaYolu': pdfDosyaYolu,
    'olusturmaTarihi': olusturmaTarihi?.toIso8601String(),
    'yenilemeStatus': yenilemeStatus.index,
  };

  factory Police.fromMap(Map<String, dynamic> m) => Police(
    id: m['id'],
    musteriAdi: m['musteriAdi'] ?? '',
    soyadi: m['soyadi'] ?? '',
    telefon: m['telefon'] ?? '',
    email: m['email'],
    tcKimlikNo: m['tcKimlikNo'],
    dogumTarihi: m['dogumTarihi'],
    sirket: m['sirket'] ?? '',
    tur: PoliceType.values[m['tur'] ?? 0],
    ozelTurAdi: m['ozelTurAdi'],
    policeNo: m['policeNo'],
    belgeSeriNo: m['belgeSeriNo'],
    aracPlaka: m['aracPlaka'],
    aracMarka: m['aracMarka'],
    aracModel: m['aracModel'],
    aracYil: m['aracYil'],
    ruhsatSeriNo: m['ruhsatSeriNo'],
    adres: m['adres'],
    uavt: m['uavt'],
    baslangicTarihi: DateTime.tryParse(m['baslangicTarihi'] ?? '') ?? DateTime.now(),
    bitisTarihi: DateTime.tryParse(m['bitisTarihi'] ?? '') ?? DateTime.now().add(const Duration(days: 365)),
    tutar: (m['tutar'] ?? 0).toDouble(),
    komisyon: (m['komisyon'] ?? 0).toDouble(),
    durum: PoliceStatus.values[m['durum'] ?? 0],
    hatirlaticiTarihi: m['hatirlaticiTarihi'] != null
        ? DateTime.tryParse(m['hatirlaticiTarihi'])
        : null,
    notlar: m['notlar'],
    hatirlaticiNotu: m['hatirlaticiNotu'],
    pdfDosyaYolu: m['pdfDosyaYolu'],
    olusturmaTarihi: m['olusturmaTarihi'] != null
        ? DateTime.tryParse(m['olusturmaTarihi'])
        : null,
    yenilemeStatus: YenilemeStatus.values[m['yenilemeStatus'] ?? 0],
  );
}

// ── Zeyil Kaydı ──────────────────────────────────────────────
class ZeyilKayit {
  final int?   id;
  final int    yil;
  final int    ay;
  final String sirket;
  final String musteriAdi;
  final String policeNo;
  final PoliceType tur;
  final double tutar;
  final double komisyon;
  final String kayitTuru; // 'Prim Zeyil+', 'Iptal Zeyil-' vb.
  final DateTime tanzimTarihi;

  const ZeyilKayit({
    this.id,
    required this.yil,
    required this.ay,
    required this.sirket,
    required this.musteriAdi,
    required this.policeNo,
    required this.tur,
    required this.tutar,
    required this.komisyon,
    required this.kayitTuru,
    required this.tanzimTarihi,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'yil':          yil,
    'ay':           ay,
    'sirket':       sirket,
    'musteriAdi':   musteriAdi,
    'policeNo':     policeNo,
    'tur':          tur.index,
    'tutar':        tutar,
    'komisyon':     komisyon,
    'kayitTuru':    kayitTuru,
    'tanzimTarihi': tanzimTarihi.toIso8601String(),
  };

  factory ZeyilKayit.fromMap(Map<String, dynamic> m) => ZeyilKayit(
    id:           m['id'],
    yil:          m['yil'] ?? 0,
    ay:           m['ay']  ?? 0,
    sirket:       m['sirket']     ?? '',
    musteriAdi:   m['musteriAdi'] ?? '',
    policeNo:     m['policeNo']   ?? '',
    tur:          PoliceType.values[m['tur'] ?? 0],
    tutar:        (m['tutar']    ?? 0).toDouble(),
    komisyon:     (m['komisyon'] ?? 0).toDouble(),
    kayitTuru:    m['kayitTuru']    ?? '',
    tanzimTarihi: DateTime.tryParse(m['tanzimTarihi'] ?? '') ?? DateTime.now(),
  );
}
