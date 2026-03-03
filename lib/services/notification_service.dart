// ============================================================
// lib/services/notification_service.dart
// Ayarlanabilir bildirim sistemi:
//   • Kullanıcı kaç gün önce, kaç saatte bir, saat kaçta
//     istediğini BildirimAyarlari ile belirler
//   • Bitiş günü ek uyarılar (sabah + öğle)
//   • "Daha Sonra" hatırlatıcısı
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/police_model.dart';
import '../models/bildirim_ayarlari.dart';

class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _normalKanal = AndroidNotificationDetails(
    'policem_normal', 'Poliçe Hatırlatıcıları',
    channelDescription: 'Yaklaşan poliçe yenileme bildirimleri',
    importance: Importance.high, priority: Priority.high,
    color: Color(0xFF1565C0),
  );

  static const _kritikKanal = AndroidNotificationDetails(
    'policem_kritik', 'Kritik Poliçe Uyarıları',
    channelDescription: 'Bugün biten poliçeler için kritik uyarılar',
    importance: Importance.max, priority: Priority.max,
    playSound: true, enableVibration: true,
    color: Color(0xFFD32F2F),
  );

  static const _hatirlaticiKanal = AndroidNotificationDetails(
    'policem_hatir', 'Müşteri Arama Hatırlatıcıları',
    channelDescription: '"Daha Sonra" müşteri aramaları',
    importance: Importance.high, priority: Priority.high,
    color: Color(0xFFE65100),
  );

  // ── Başlatma ─────────────────────────────────────────────
  Future<void> baslat() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Ayarları Yükle / Kaydet ───────────────────────────────
  Future<BildirimAyarlari> ayarlariGetir() async {
    final prefs = await SharedPreferences.getInstance();
    final json  = prefs.getString('bildirim_ayarlari');
    if (json == null) return const BildirimAyarlari();
    return BildirimAyarlari.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> ayarlariKaydet(BildirimAyarlari a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bildirim_ayarlari', jsonEncode(a.toJson()));
  }

  // ── Poliçe türüne göre bildirim emojisi ─────────────────
  static String _turEmoji(PoliceType tur) {
    const m = {
      PoliceType.trafik: '🚗', PoliceType.kasko: '🛡️',
      PoliceType.dask: '🏚️', PoliceType.konut: '🏠',
      PoliceType.ozelSaglik: '🏥', PoliceType.tamamlayiciSaglik: '❤️',
      PoliceType.hayat: '💚', PoliceType.ferdiKaza: '🦺',
      PoliceType.isyeri: '🏢', PoliceType.nakliyat: '🚢',
      PoliceType.tarim: '🌾', PoliceType.seyahat: '✈️',
    };
    return m[tur] ?? '📄';
  }

  // ── Ana Algoritma ─────────────────────────────────────────
  Future<void> policeIcinBildirimler(Police police) async {
    if (police.id == null) return;
    await policeIcinIptal(police.id!);

    final ayarlar = await ayarlariGetir();
    if (!ayarlar.bildirimlerAktif) return;

    if (police.durum == PoliceStatus.yapilamadi) return;
    // Yapıldi poliçeler de bitiş tarihi yaklaşınca bildirim alsın

    final bitis    = police.bitisTarihi;
    final simdi    = DateTime.now();
    final kalanGun = bitis.difference(simdi).inDays;
    final turAdi   = police.goruntulenenTur;
    final turEmoji = _turEmoji(police.tur);

    // ── 10 gün önceden özel "Teklif Hazırla" bildirimi ──
    const onGun = 10;
    final onGunOncesi = DateTime(
      bitis.year, bitis.month, bitis.day,
      9, 0, // Sabah 9:00
    ).subtract(const Duration(days: onGun));

    if (onGunOncesi.isAfter(simdi)) {
      await _planla(
        id: _bid(police.id!, 90),
        baslik: '$turEmoji ${turAdi} Yenileme – 10 Gün Kaldı!',
        icerik:
            '${police.tamAd} müşterisinin $turAdi poliçesi bitmesine '
            '10 gün kaldı. Teklif hazırla! 📋',
        tarih: onGunOncesi,
        kanal: _normalKanal,
      );
    }

    // ── 5 gün önceden hatırlatma ──
    if (kalanGun <= onGun) {
      final besGunOncesi = DateTime(
        bitis.year, bitis.month, bitis.day,
        9, 0,
      ).subtract(const Duration(days: 5));
      if (besGunOncesi.isAfter(simdi)) {
        await _planla(
          id: _bid(police.id!, 91),
          baslik: '$turEmoji ${turAdi} – Son 5 Gün!',
          icerik:
              '${police.tamAd} – ${police.sirket} $turAdi poliçesi '
              '5 gün sonra bitiyor. Müşteriyi ara! 📞',
          tarih: besGunOncesi,
          kanal: _normalKanal,
        );
      }
    }

    if (kalanGun > ayarlar.ilkBildirimGunOnce) {
      // İlk bildirim tarihini planla
      final ilk = DateTime(
        bitis.year, bitis.month, bitis.day,
        ayarlar.sabahBildirimSaat, ayarlar.sabahBildirimDakika,
      ).subtract(Duration(days: ayarlar.ilkBildirimGunOnce));

      if (ilk.isAfter(simdi)) {
        await _planla(
          id: _bid(police.id!, 0),
          baslik: '$turEmoji Poliçe Yenileme Yaklaşıyor',
          icerik:
              '${police.tamAd} – $turAdi '
              '${ayarlar.ilkBildirimGunOnce} gün sonra bitiyor.',
          tarih: ilk,
          kanal: _normalKanal,
        );
      }
      return;
    }

    // İçindeyiz: tekrar sıklığına göre bildirimler
    int sayac = 1;
    int gun   = kalanGun;
    while (gun > 0) {
      final zaman = DateTime(
        bitis.year, bitis.month, bitis.day,
        ayarlar.sabahBildirimSaat, ayarlar.sabahBildirimDakika,
      ).subtract(Duration(days: gun));

      if (zaman.isAfter(simdi)) {
        await _planla(
          id: _bid(police.id!, sayac),
          baslik: '$turEmoji $turAdi Hatırlatıcısı – $gun Gün Kaldı',
          icerik:
              '${police.tamAd} – ${police.sirket} $turAdi. '
              'Müşteriyi aramayı unutma! 📞',
          tarih: zaman,
          kanal: _normalKanal,
        );
        sayac++;
      }
      gun -= ayarlar.tekrarSikligi;
    }

    // Bitiş günü ekstra uyarılar
    if (ayarlar.bitisSabahUyarisi) {
      final sabah = DateTime(
        bitis.year, bitis.month, bitis.day,
        ayarlar.bitisSabahSaat, 0,
      );
      if (sabah.isAfter(simdi)) {
        await _planla(
          id: _bid(police.id!, 98),
          baslik: '🚨 BUGÜN BİTİYOR – Sabah Uyarısı',
          icerik:
              '${police.tamAd} müşterisinin '
              '${police.goruntulenenTur} poliçesi BUGÜN bitiyor!',
          tarih: sabah,
          kanal: _kritikKanal,
        );
      }
    }

    if (ayarlar.bitisOgleUyarisi) {
      final ogle = DateTime(
        bitis.year, bitis.month, bitis.day,
        ayarlar.bitisOgleSaat, 0,
      );
      if (ogle.isAfter(simdi)) {
        await _planla(
          id: _bid(police.id!, 99),
          baslik: '🚨 BUGÜN BİTİYOR – Son Hatırlatma',
          icerik:
              '${police.tamAd} – ${police.goruntulenenTur}. '
              'İşlemi tamamladın mı?',
          tarih: ogle,
          kanal: _kritikKanal,
        );
      }
    }
  }

  // ── "Daha Sonra" Hatırlatıcısı ────────────────────────────
  Future<void> dahaSonraHatirlatici(Police police) async {
    if (police.hatirlaticiTarihi == null || police.id == null) return;
    if (police.hatirlaticiTarihi!.isBefore(DateTime.now())) return;

    await _planla(
      id: _bid(police.id!, 100),
      baslik: '📞 Müşteri Arama Vakti!',
      icerik:
          '${police.tamAd} – '
          '${police.hatirlaticiNotu ?? police.goruntulenenTur}',
      tarih: police.hatirlaticiTarihi!,
      kanal: _hatirlaticiKanal,
    );
  }

  // ── İptal ─────────────────────────────────────────────────
  Future<void> policeIcinIptal(int policeId) async {
    for (int i = 0; i <= 100; i++) {
      await _plugin.cancel(_bid(policeId, i));
    }
  }

  // ── Düşük Seviye ──────────────────────────────────────────
  Future<void> _planla({
    required int id,
    required String baslik,
    required String icerik,
    required DateTime tarih,
    required AndroidNotificationDetails kanal,
  }) async {
    await _plugin.zonedSchedule(
      id, baslik, icerik,
      tz.TZDateTime.from(tarih, tz.local),
      NotificationDetails(android: kanal),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  int _bid(int policeId, int slot) => policeId * 101 + slot;

  // ── Tüm aktif poliçeler için bildirimleri yenile ──────────
  // (Ayarlar değişince çağrılır)
  Future<void> tumBildirimleriYenile(List<Police> policeler) async {
    for (final p in policeler) {
      await policeIcinBildirimler(p);
      if (p.durum == PoliceStatus.dahaSonra &&
          p.hatirlaticiTarihi != null) {
        await dahaSonraHatirlatici(p);
      }
    }
  }
}
