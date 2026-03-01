// ============================================================
// lib/models/bildirim_ayarlari.dart
// Bildirim sıklığı, saat ve aktiflik ayarları
// SharedPreferences ile kalıcı olarak saklanır
// ============================================================

class BildirimAyarlari {
  // ── Genel Aktiflik ──────────────────────────────────────
  final bool bildirimlerAktif;

  // ── İlk Bildirim Kaç Gün Önce ──────────────────────────
  // (varsayılan: 10)
  final int ilkBildirimGunOnce;

  // ── Tekrar Sıklığı (gün) ───────────────────────────────
  // 1 = her gün, 2 = her 2 günde bir, 3 = her 3 günde bir
  final int tekrarSikligi;

  // ── Sabah Bildirimi Saati ──────────────────────────────
  final int sabahBildirimSaat;   // 0-23
  final int sabahBildirimDakika; // 0-59

  // ── Bitiş Günü Ekstra Uyarılar ─────────────────────────
  final bool bitisSabahUyarisi;   // 08:00 uyarı
  final int  bitisSabahSaat;
  final bool bitisOgleUyarisi;    // 12:00 uyarı
  final int  bitisOgleSaat;

  // ── WhatsApp Şablon Aktif ──────────────────────────────
  final bool whatsappHatirlatma;

  const BildirimAyarlari({
    this.bildirimlerAktif      = true,
    this.ilkBildirimGunOnce    = 10,
    this.tekrarSikligi         = 2,
    this.sabahBildirimSaat     = 10,
    this.sabahBildirimDakika   = 0,
    this.bitisSabahUyarisi     = true,
    this.bitisSabahSaat        = 8,
    this.bitisOgleUyarisi      = true,
    this.bitisOgleSaat         = 12,
    this.whatsappHatirlatma    = true,
  });

  // JSON dönüşümleri (SharedPreferences için)
  Map<String, dynamic> toJson() => {
    'bildirimlerAktif':      bildirimlerAktif,
    'ilkBildirimGunOnce':    ilkBildirimGunOnce,
    'tekrarSikligi':         tekrarSikligi,
    'sabahBildirimSaat':     sabahBildirimSaat,
    'sabahBildirimDakika':   sabahBildirimDakika,
    'bitisSabahUyarisi':     bitisSabahUyarisi,
    'bitisSabahSaat':        bitisSabahSaat,
    'bitisOgleUyarisi':      bitisOgleUyarisi,
    'bitisOgleSaat':         bitisOgleSaat,
    'whatsappHatirlatma':    whatsappHatirlatma,
  };

  factory BildirimAyarlari.fromJson(Map<String, dynamic> j) =>
      BildirimAyarlari(
        bildirimlerAktif:    j['bildirimlerAktif']    as bool? ?? true,
        ilkBildirimGunOnce:  j['ilkBildirimGunOnce']  as int?  ?? 10,
        tekrarSikligi:       j['tekrarSikligi']        as int?  ?? 2,
        sabahBildirimSaat:   j['sabahBildirimSaat']    as int?  ?? 10,
        sabahBildirimDakika: j['sabahBildirimDakika']  as int?  ?? 0,
        bitisSabahUyarisi:   j['bitisSabahUyarisi']   as bool? ?? true,
        bitisSabahSaat:      j['bitisSabahSaat']       as int?  ?? 8,
        bitisOgleUyarisi:    j['bitisOgleUyarisi']    as bool? ?? true,
        bitisOgleSaat:       j['bitisOgleSaat']        as int?  ?? 12,
        whatsappHatirlatma:  j['whatsappHatirlatma']  as bool? ?? true,
      );

  BildirimAyarlari copyWith({
    bool? bildirimlerAktif, int? ilkBildirimGunOnce, int? tekrarSikligi,
    int? sabahBildirimSaat, int? sabahBildirimDakika,
    bool? bitisSabahUyarisi, int? bitisSabahSaat,
    bool? bitisOgleUyarisi, int? bitisOgleSaat,
    bool? whatsappHatirlatma,
  }) => BildirimAyarlari(
    bildirimlerAktif:    bildirimlerAktif    ?? this.bildirimlerAktif,
    ilkBildirimGunOnce:  ilkBildirimGunOnce  ?? this.ilkBildirimGunOnce,
    tekrarSikligi:       tekrarSikligi       ?? this.tekrarSikligi,
    sabahBildirimSaat:   sabahBildirimSaat   ?? this.sabahBildirimSaat,
    sabahBildirimDakika: sabahBildirimDakika ?? this.sabahBildirimDakika,
    bitisSabahUyarisi:   bitisSabahUyarisi   ?? this.bitisSabahUyarisi,
    bitisSabahSaat:      bitisSabahSaat      ?? this.bitisSabahSaat,
    bitisOgleUyarisi:    bitisOgleUyarisi    ?? this.bitisOgleUyarisi,
    bitisOgleSaat:       bitisOgleSaat       ?? this.bitisOgleSaat,
    whatsappHatirlatma:  whatsappHatirlatma  ?? this.whatsappHatirlatma,
  );
}
