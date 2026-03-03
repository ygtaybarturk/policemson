// lib/models/police_model.dart
import 'package:flutter/material.dart';

enum PoliceStatus { beklemede, yapildi, yapilamadi, dahaSonra }

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

  /// Excel'deki Police sütunundan tür belirle
  static PoliceType fromExcel(String? val) {
    if (val == null) return PoliceType.diger;
    final v = val.toUpperCase().trim()
        .replaceAll('İ', 'I').replaceAll('Ş', 'S')
        .replaceAll('Ğ', 'G').replaceAll('Ç', 'C')
        .replaceAll('Ö', 'O').replaceAll('Ü', 'U');
    if (v.contains('TRAFIK'))              return PoliceType.trafik;
    if (v.contains('KASKO'))              return PoliceType.kasko;
    if (v.contains('DASK'))               return PoliceType.dask;
    if (v.contains('KONUT'))              return PoliceType.konut;
    if (v.contains('TAMAMLAYICI') || v.contains('TAMAMLAY')) return PoliceType.tamamlayiciSaglik;
    if (v.contains('SAGLIK') || v.contains('SAĞLIK') || v.contains('OZEL')) return PoliceType.ozelSaglik;
    if (v.contains('HAYAT'))              return PoliceType.hayat;
    if (v.contains('FERDI') || v.contains('KAZA')) return PoliceType.ferdiKaza;
    if (v.contains('ISYERI') || v.contains('ISYERI') || v.contains('ISVERI')) return PoliceType.isyeri;
    if (v.contains('NAKLIYAT'))           return PoliceType.nakliyat;
    if (v.contains('TARIM'))              return PoliceType.tarim;
    if (v.contains('SEYAHAT'))            return PoliceType.seyahat;
    return PoliceType.diger;
  }
}

class Police {
  final int? id;
  final String musteriAdi;
  final String soyadi;
  final String telefon;
  final String? tcKimlikNo;
  final String sirket;
  final PoliceType tur;
  final String? policeNo;        // Police No (sigorta poliçe numarası)
  final String? belgeSeriNo;     // Belge Seri (ruhsat seri no)
  final String? aracPlaka;
  final String? aracMarka;
  final String? aracModel;
  final String? aracYil;
  final DateTime baslangicTarihi;
  final DateTime bitisTarihi;
  final double tutar;
  final double komisyon;
  final PoliceStatus durum;
  final DateTime? hatirlaticiTarihi;
  final String? notlar;

  const Police({
    this.id,
    required this.musteriAdi,
    required this.soyadi,
    required this.telefon,
    this.tcKimlikNo,
    required this.sirket,
    required this.tur,
    this.policeNo,
    this.belgeSeriNo,
    this.aracPlaka,
    this.aracMarka,
    this.aracModel,
    this.aracYil,
    required this.baslangicTarihi,
    required this.bitisTarihi,
    this.tutar = 0,
    this.komisyon = 0,
    this.durum = PoliceStatus.beklemede,
    this.hatirlaticiTarihi,
    this.notlar,
  });

  int get kalanGun => bitisTarihi.difference(DateTime.now()).inDays;

  String get goruntulenenTur => tur.label;

  Police copyWith({
    int? id, String? musteriAdi, String? soyadi, String? telefon,
    String? tcKimlikNo, String? sirket, PoliceType? tur,
    String? policeNo, String? belgeSeriNo,
    String? aracPlaka, String? aracMarka, String? aracModel, String? aracYil,
    DateTime? baslangicTarihi, DateTime? bitisTarihi,
    double? tutar, double? komisyon, PoliceStatus? durum,
    DateTime? hatirlaticiTarihi, String? notlar,
  }) => Police(
    id: id ?? this.id,
    musteriAdi: musteriAdi ?? this.musteriAdi,
    soyadi: soyadi ?? this.soyadi,
    telefon: telefon ?? this.telefon,
    tcKimlikNo: tcKimlikNo ?? this.tcKimlikNo,
    sirket: sirket ?? this.sirket,
    tur: tur ?? this.tur,
    policeNo: policeNo ?? this.policeNo,
    belgeSeriNo: belgeSeriNo ?? this.belgeSeriNo,
    aracPlaka: aracPlaka ?? this.aracPlaka,
    aracMarka: aracMarka ?? this.aracMarka,
    aracModel: aracModel ?? this.aracModel,
    aracYil: aracYil ?? this.aracYil,
    baslangicTarihi: baslangicTarihi ?? this.baslangicTarihi,
    bitisTarihi: bitisTarihi ?? this.bitisTarihi,
    tutar: tutar ?? this.tutar,
    komisyon: komisyon ?? this.komisyon,
    durum: durum ?? this.durum,
    hatirlaticiTarihi: hatirlaticiTarihi ?? this.hatirlaticiTarihi,
    notlar: notlar ?? this.notlar,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'musteriAdi': musteriAdi,
    'soyadi': soyadi,
    'telefon': telefon,
    'tcKimlikNo': tcKimlikNo,
    'sirket': sirket,
    'tur': tur.index,
    'policeNo': policeNo,
    'belgeSeriNo': belgeSeriNo,
    'aracPlaka': aracPlaka,
    'aracMarka': aracMarka,
    'aracModel': aracModel,
    'aracYil': aracYil,
    'baslangicTarihi': baslangicTarihi.toIso8601String(),
    'bitisTarihi': bitisTarihi.toIso8601String(),
    'tutar': tutar,
    'komisyon': komisyon,
    'durum': durum.index,
    'hatirlaticiTarihi': hatirlaticiTarihi?.toIso8601String(),
    'notlar': notlar,
  };

  factory Police.fromMap(Map<String, dynamic> m) => Police(
    id: m['id'],
    musteriAdi: m['musteriAdi'] ?? '',
    soyadi: m['soyadi'] ?? '',
    telefon: m['telefon'] ?? '',
    tcKimlikNo: m['tcKimlikNo'],
    sirket: m['sirket'] ?? '',
    tur: PoliceType.values[m['tur'] ?? 0],
    policeNo: m['policeNo'],
    belgeSeriNo: m['belgeSeriNo'],
    aracPlaka: m['aracPlaka'],
    aracMarka: m['aracMarka'],
    aracModel: m['aracModel'],
    aracYil: m['aracYil'],
    baslangicTarihi: DateTime.parse(m['baslangicTarihi']),
    bitisTarihi: DateTime.parse(m['bitisTarihi']),
    tutar: (m['tutar'] ?? 0).toDouble(),
    komisyon: (m['komisyon'] ?? 0).toDouble(),
    durum: PoliceStatus.values[m['durum'] ?? 0],
    hatirlaticiTarihi: m['hatirlaticiTarihi'] != null
        ? DateTime.tryParse(m['hatirlaticiTarihi'])
        : null,
    notlar: m['notlar'],
  );
}