// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/police_model.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'policem.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, v) async {
        await _createTable(db);
        await _createZeyilTable(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE policeler ADD COLUMN policeNo TEXT');
          await db.execute('ALTER TABLE policeler ADD COLUMN hatirlaticiTarihi TEXT');
          await db.execute('ALTER TABLE policeler ADD COLUMN notlar TEXT');
        }
        if (oldV < 3) {
          try { await db.execute('ALTER TABLE policeler ADD COLUMN policeNo TEXT'); } catch (_) {}
        }
        if (oldV < 4) {
          final newCols = [
            'email TEXT', 'dogumTarihi TEXT', 'ozelTurAdi TEXT',
            'ruhsatSeriNo TEXT', 'adres TEXT', 'uavt TEXT',
            'olusturmaTarihi TEXT', 'hatirlaticiNotu TEXT', 'pdfDosyaYolu TEXT',
          ];
          for (final col in newCols) {
            try { await db.execute('ALTER TABLE policeler ADD COLUMN $col'); } catch (_) {}
          }
        }
        if (oldV < 5) {
          try { await db.execute('ALTER TABLE policeler ADD COLUMN yenilemeStatus INTEGER DEFAULT 0'); } catch (_) {}
        }
        if (oldV < 6) {
          await _createZeyilTable(db);
        }
      },
    );
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE policeler (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        musteriAdi       TEXT NOT NULL,
        soyadi           TEXT,
        telefon          TEXT,
        email            TEXT,
        tcKimlikNo       TEXT,
        dogumTarihi      TEXT,
        sirket           TEXT,
        tur              INTEGER,
        ozelTurAdi       TEXT,
        policeNo         TEXT,
        belgeSeriNo      TEXT,
        aracPlaka        TEXT,
        aracMarka        TEXT,
        aracModel        TEXT,
        aracYil          TEXT,
        ruhsatSeriNo     TEXT,
        adres            TEXT,
        uavt             TEXT,
        baslangicTarihi  TEXT,
        bitisTarihi      TEXT,
        tutar            REAL,
        komisyon         REAL,
        durum            INTEGER DEFAULT 0,
        hatirlaticiTarihi TEXT,
        notlar           TEXT,
        hatirlaticiNotu  TEXT,
        pdfDosyaYolu     TEXT,
        olusturmaTarihi  TEXT,
        yenilemeStatus   INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createZeyilTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zeyiller (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        yil           INTEGER NOT NULL,
        ay            INTEGER NOT NULL,
        sirket        TEXT,
        musteriAdi    TEXT,
        policeNo      TEXT,
        tur           INTEGER DEFAULT 0,
        tutar         REAL DEFAULT 0,
        komisyon      REAL DEFAULT 0,
        kayitTuru     TEXT,
        tanzimTarihi  TEXT
      )
    ''');
  }

  // ── Zeyil CRUD ───────────────────────────────────────────────
  Future<void> zeyilEkle(ZeyilKayit z) async {
    final d = await db;
    await d.insert('zeyiller', z.toMap());
  }

  Future<void> zeyillerEkle(List<ZeyilKayit> liste) async {
    final d  = await db;
    final tx = await d.transaction((txn) async {
      for (final z in liste) {
        await txn.insert('zeyiller', z.toMap());
      }
    });
    return tx;
  }

  Future<List<ZeyilKayit>> aylikZeyiller(int yil, int ay) async {
    final d = await db;
    final r = await d.query('zeyiller',
        where: 'yil = ? AND ay = ?',
        whereArgs: [yil, ay],
        orderBy: 'tanzimTarihi ASC');
    return r.map(ZeyilKayit.fromMap).toList();
  }

  /// Ay bazında zeyil toplamları — analizler için
  Future<Map<String, double>> aylikZeyilToplam(int yil, int ay) async {
    final d    = await db;
    final rows = await d.query('zeyiller',
        where: 'yil = ? AND ay = ?', whereArgs: [yil, ay]);

    double toplamTutar    = 0;
    double toplamKomisyon = 0;

    for (final r in rows) {
      final kayit = (r['kayitTuru'] as String? ?? '').toUpperCase()
          .replaceAll('İ', 'I').replaceAll('Ç', 'C');
      final tutar    = (r['tutar']    as num? ?? 0).toDouble();
      final komisyon = (r['komisyon'] as num? ?? 0).toDouble();

      if (kayit.contains('IPTAL')) {
        // İptal zeyil → her zaman eksi (mutlak değer al, eksi yap)
        toplamTutar    -= tutar.abs();
        toplamKomisyon -= komisyon.abs();
      } else {
        // Prim zeyil+ veya diğer → artı
        toplamTutar    += tutar.abs();
        toplamKomisyon += komisyon.abs();
      }
    }

    return {'tutar': toplamTutar, 'komisyon': toplamKomisyon};
  }

  Future<int> ekle(Police p) async {
    final d = await db;
    return d.insert('policeler', p.toMap());
  }

  Future<void> guncelle(Police p) async {
    final d = await db;
    await d.update('policeler', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  /// Akıllı ekleme: Aynı isimde VE aynı türde müşteri varsa günceller, yoksa ekler
  /// Önce başlangıç, sonra bitiş tarihinde kontrol eder
  Future<int> ekleVeyaGuncelle(Police p) async {
    final d = await db;
    final bas = p.baslangicTarihi.toIso8601String();
    final bit = p.bitisTarihi.toIso8601String();
    
    // Önce başlangıç tarihinde ara (aynı isim + aynı tür)
    final basYil = p.baslangicTarihi.year;
    final basAy = p.baslangicTarihi.month;
    final basAyBas = DateTime(basYil, basAy, 1).toIso8601String();
    final basAyBit = DateTime(basYil, basAy + 1, 0, 23, 59, 59).toIso8601String();
    
    var mevcut = await d.query('policeler',
        where: 'musteriAdi = ? AND soyadi = ? AND tur = ? AND baslangicTarihi BETWEEN ? AND ?',
        whereArgs: [p.musteriAdi, p.soyadi ?? '', p.tur.index, basAyBas, basAyBit],
        limit: 1);
    
    // Başlangıçta bulamadıysa bitiş tarihinde ara (aynı isim + aynı tür)
    if (mevcut.isEmpty) {
      final bitYil = p.bitisTarihi.year;
      final bitAy = p.bitisTarihi.month;
      final bitAyBas = DateTime(bitYil, bitAy, 1).toIso8601String();
      final bitAyBit = DateTime(bitYil, bitAy + 1, 0, 23, 59, 59).toIso8601String();
      
      mevcut = await d.query('policeler',
          where: 'musteriAdi = ? AND soyadi = ? AND tur = ? AND bitisTarihi BETWEEN ? AND ?',
          whereArgs: [p.musteriAdi, p.soyadi ?? '', p.tur.index, bitAyBas, bitAyBit],
          limit: 1);
    }
    
    if (mevcut.isNotEmpty) {
      // Mevcut kayıt var - sadece belirli alanları güncelle
      final eskiPolice = Police.fromMap(mevcut.first);
      final guncelMap = {
        'policeNo': p.policeNo,
        'belgeSeriNo': p.belgeSeriNo,
        'sirket': p.sirket,
        'tur': p.tur.index,
        'baslangicTarihi': bas,
        'bitisTarihi': bit,
        'tutar': p.tutar,
        'komisyon': p.komisyon,
        'aracPlaka': p.aracPlaka,
        'telefon': p.telefon,
        'tcKimlikNo': p.tcKimlikNo,
        // Durum ve diğer kullanıcı ayarları korunur
      };
      await d.update('policeler', guncelMap, 
          where: 'id = ?', whereArgs: [eskiPolice.id]);
      return eskiPolice.id!;
    } else {
      // Yeni kayıt (aynı isim ama farklı tür VEYA tamamen yeni kişi)
      return d.insert('policeler', p.toMap());
    }
  }

  /// Bitiş tarihine poliçe ekler - Başlangıç tarihinden "Yapıldı" olanları kopyalar
  /// Durum her zaman "Beklemede" olarak eklenir
  Future<void> bitiseTarihineEkle(int yil, int ay) async {
    final d = await db;
    
    // 1 yıl önceki aynı ay
    final oncekiYil = yil - 1;
    final baslangicBas = DateTime(oncekiYil, ay, 1).toIso8601String();
    final baslangicBit = DateTime(oncekiYil, ay + 1, 0, 23, 59, 59).toIso8601String();
    
    // Başlangıç tarihinde "Yapıldı" olanları getir
    final yapildilar = await d.query('policeler',
        where: 'baslangicTarihi BETWEEN ? AND ? AND durum = ?',
        whereArgs: [baslangicBas, baslangicBit, PoliceStatus.yapildi.index]);
    
    // Bitiş tarihine ekle
    for (final row in yapildilar) {
      final eskiPolice = Police.fromMap(row);
      
      // Bitiş tarihine yeni kart oluştur
      final yeniPolice = Police(
        musteriAdi: eskiPolice.musteriAdi,
        soyadi: eskiPolice.soyadi,
        telefon: eskiPolice.telefon,
        tcKimlikNo: eskiPolice.tcKimlikNo,
        sirket: eskiPolice.sirket,
        tur: eskiPolice.tur,
        policeNo: eskiPolice.policeNo,
        belgeSeriNo: eskiPolice.belgeSeriNo,
        aracPlaka: eskiPolice.aracPlaka,
        aracMarka: eskiPolice.aracMarka,
        aracModel: eskiPolice.aracModel,
        aracYil: eskiPolice.aracYil,
        baslangicTarihi: eskiPolice.baslangicTarihi,
        bitisTarihi: eskiPolice.bitisTarihi,
        tutar: eskiPolice.tutar,
        komisyon: eskiPolice.komisyon,
        durum: PoliceStatus.beklemede, // Durum her zaman beklemede
      );
      
      // Aynı isimde kart zaten varsa ekleme
      final bitisBas = DateTime(yil, ay, 1).toIso8601String();
      final bitisBit = DateTime(yil, ay + 1, 0, 23, 59, 59).toIso8601String();
      final mevcutBitis = await d.query('policeler',
          where: 'musteriAdi = ? AND soyadi = ? AND bitisTarihi BETWEEN ? AND ?',
          whereArgs: [yeniPolice.musteriAdi, yeniPolice.soyadi ?? '', bitisBas, bitisBit],
          limit: 1);
      
      if (mevcutBitis.isEmpty) {
        await d.insert('policeler', yeniPolice.toMap());
      }
    }
  }

  /// Sadece yenileme durumunu günceller
  Future<void> yenilemeGuncelle(int id, YenilemeStatus status) async {
    final d = await db;
    await d.update(
      'policeler',
      {'yenilemeStatus': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> sil(int id) async {
    final d = await db;
    await d.delete('policeler', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> durumGuncelle(int id, PoliceStatus durum) async {
    final d = await db;
    await d.update('policeler', {'durum': durum.index}, where: 'id = ?', whereArgs: [id]);
  }

  Future<Police?> getirId(int id) async {
    final d = await db;
    final r = await d.query('policeler', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? Police.fromMap(r.first) : null;
  }

  // 'getir' alias - police_detay_screen.dart kullanıyor
  Future<Police?> getir(int id) => getirId(id);
  Future<Police?> getById(int id) => getirId(id);

  // Aralık analizi - analizler_screen.dart kullanıyor
  Future<List<Map<String, dynamic>>> aralikAnaliz(int yil, int bas, int bit) async {
    final d = await db;
    final List<Map<String, dynamic>> sonuc = [];
    for (int ay = bas; ay <= bit; ay++) {
      // Yıl taşması desteği
      int gercekYil = yil;
      int gercekAy  = ay;
      if (gercekAy < 1)  { gercekYil -= 1; gercekAy += 12; }
      if (gercekAy > 12) { gercekYil += 1; gercekAy -= 12; }

      final ayBas = DateTime(gercekYil, gercekAy, 1).toIso8601String();
      final ayBit = DateTime(gercekYil, gercekAy + 1, 0, 23, 59, 59).toIso8601String();

      // Başlangıç tarihine göre çek (poliçenin yapıldığı ay)
      final rows = await d.query('policeler',
          where: 'baslangicTarihi BETWEEN ? AND ?', whereArgs: [ayBas, ayBit]);
      final policeler = rows.map(Police.fromMap).toList();
      final toplam     = policeler.length;
      final yapildi    = policeler.where((p) => p.durum == PoliceStatus.yapildi).length;
      final yapilamadi = policeler.where((p) => p.durum == PoliceStatus.yapilamadi).length;
      final beklemede  = policeler.where((p) => p.durum == PoliceStatus.beklemede).length;
      final dahaSonra  = policeler.where((p) => p.durum == PoliceStatus.dahaSonra).length;
      final gelir      = policeler.fold<double>(0, (s, p) => s + p.tutar);
      final komisyon   = policeler.fold<double>(0, (s, p) => s + p.komisyon);

      // Tür dağılımı — adet + prim + komisyon
      final turDagilimi = <String, int>{};
      final turPrim     = <String, double>{};
      final turKomisyon = <String, double>{};
      final turEmoji    = <String, String>{};
      for (final p in policeler) {
        final turAdi = p.goruntulenenTur;
        turDagilimi[turAdi] = (turDagilimi[turAdi] ?? 0) + 1;
        turPrim[turAdi]     = (turPrim[turAdi]     ?? 0) + p.tutar;
        turKomisyon[turAdi] = (turKomisyon[turAdi] ?? 0) + p.komisyon;
        turEmoji[turAdi]    = p.tur.emoji;
      }

      // Zeyil toplamları — arti/eksi ayrımlı
      final zeyilAyRows = await d.query('zeyiller',
          where: 'yil = ? AND ay = ?', whereArgs: [gercekYil, gercekAy]);
      double zeyilArti = 0, zeyilEksi = 0;
      double zeyilArtiKom = 0, zeyilEksiKom = 0;
      int    zeyilArtiAdet = 0, zeyilEksiAdet = 0;
      for (final zr in zeyilAyRows) {
        final kt  = (zr['kayitTuru'] as String? ?? '').toUpperCase()
            .replaceAll('İ', 'I').replaceAll('Ç', 'C');
        final zt  = (zr['tutar']    as num? ?? 0).toDouble();
        final zk  = (zr['komisyon'] as num? ?? 0).toDouble();
        if (kt.contains('IPTAL')) {
          zeyilEksi    += zt.abs(); zeyilEksiKom += zk.abs(); zeyilEksiAdet++;
        } else {
          zeyilArti    += zt.abs(); zeyilArtiKom += zk.abs(); zeyilArtiAdet++;
        }
      }
      final zeyilTutar    = zeyilArti - zeyilEksi;
      final zeyilKomisyon = zeyilArtiKom - zeyilEksiKom;

      sonuc.add({
        'ay':             gercekAy,
        'yil':            gercekYil,
        'toplam':         toplam,
        'yapildi':        yapildi,
        'yapilamadi':     yapilamadi,
        'beklemede':      beklemede,
        'dahaSonra':      dahaSonra,
        'gelir':          gelir,
        'komisyon':       komisyon,
        'zeyilTutar':     zeyilTutar,
        'zeyilKomisyon':  zeyilKomisyon,
        'zeyilArti':      zeyilArti,
        'zeyilEksi':      zeyilEksi,
        'zeyilArtiKom':   zeyilArtiKom,
        'zeyilEksiKom':   zeyilEksiKom,
        'zeyilArtiAdet':  zeyilArtiAdet,
        'zeyilEksiAdet':  zeyilEksiAdet,
        'netGelir':       gelir    + zeyilTutar,
        'netKomisyon':    komisyon + zeyilKomisyon,
        'turDagilimi':    turDagilimi,
        'turPrim':        turPrim,
        'turKomisyon':    turKomisyon,
        'turEmoji':       turEmoji,
      });
    }
    return sonuc;
  }

  Future<List<Police>> aylik(int yil, int ay, {PoliceStatus? filtre}) async {
    final d = await db;
    final bas = DateTime(yil, ay, 1).toIso8601String();
    final bit = DateTime(yil, ay + 1, 0, 23, 59, 59).toIso8601String();

    // Hem başlangıç hem bitiş tarihine göre getir
    String where = "(bitisTarihi BETWEEN ? AND ?) OR (baslangicTarihi BETWEEN ? AND ?)";
    List<dynamic> args = [bas, bit, bas, bit];

    if (filtre != null) {
      where = "($where) AND durum = ?";
      args.add(filtre.index);
    }

    final r = await d.query('policeler',
        where: where, whereArgs: args, orderBy: 'bitisTarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  Future<Map<int, int>> aylikSayilar(int yil) async {
    final d = await db;
    final Map<int, int> sayilar = {};
    for (int ay = 1; ay <= 12; ay++) {
      final bas = DateTime(yil, ay, 1).toIso8601String();
      final bit = DateTime(yil, ay + 1, 0, 23, 59, 59).toIso8601String();
      final r = await d.rawQuery(
          'SELECT COUNT(*) as c FROM policeler WHERE bitisTarihi BETWEEN ? AND ?',
          [bas, bit]);
      sayilar[ay] = (r.first['c'] as int?) ?? 0;
    }
    return sayilar;
  }

  Future<List<Police>> adSoyadAra(String q, int yil) async {
    final d = await db;
    final bas = DateTime(yil, 1, 1).toIso8601String();
    final bit = DateTime(yil, 12, 31, 23, 59, 59).toIso8601String();
    final r = await d.query('policeler',
        where: "(musteriAdi LIKE ? OR soyadi LIKE ? OR aracPlaka LIKE ?) AND bitisTarihi BETWEEN ? AND ?",
        whereArgs: ['%$q%', '%$q%', '%$q%', bas, bit],
        orderBy: 'bitisTarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  Future<List<Police>> yillikTumPoliceler(int yil) async {
    final d = await db;
    final bas = DateTime(yil, 1, 1).toIso8601String();
    final bit = DateTime(yil, 12, 31, 23, 59, 59).toIso8601String();
    final r = await d.query('policeler',
        where: 'baslangicTarihi BETWEEN ? AND ?',
        whereArgs: [bas, bit],
        orderBy: 'baslangicTarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  /// Yıllık özet — tek yıl için tüm metrikler + aylık kırılım
  Future<Map<String, dynamic>> yillikOzet(int yil) async {
    final policeler = await yillikTumPoliceler(yil);
    final toplam     = policeler.length;
    final gelir      = policeler.fold<double>(0, (s, p) => s + p.tutar);
    final komisyon   = policeler.fold<double>(0, (s, p) => s + p.komisyon);

    // Tür dağılımı
    final turDagilimi = <String, int>{};
    final turPrim     = <String, double>{};
    final turKomisyon = <String, double>{};
    final turEmoji    = <String, String>{};
    for (final p in policeler) {
      final t = p.goruntulenenTur;
      turDagilimi[t] = (turDagilimi[t] ?? 0) + 1;
      turPrim[t]     = (turPrim[t]     ?? 0) + p.tutar;
      turKomisyon[t] = (turKomisyon[t] ?? 0) + p.komisyon;
      turEmoji[t]    = p.tur.emoji;
    }

    // Zeyil toplamları (yıl geneli)
    final d = await db;
    final zr = await d.rawQuery('''
      SELECT kayitTuru,
             COALESCE(SUM(tutar), 0)    AS t,
             COALESCE(SUM(komisyon), 0) AS k,
             COUNT(*)                   AS adet
      FROM zeyiller WHERE yil = ?
      GROUP BY kayitTuru
    ''', [yil]);

    double zeyilArti = 0, zeyilEksi = 0;
    double zeyilArtiKom = 0, zeyilEksiKom = 0;
    int    zeyilArtiAdet = 0, zeyilEksiAdet = 0;
    for (final r in zr) {
      final kt   = (r['kayitTuru'] as String? ?? '').toUpperCase()
          .replaceAll('İ', 'I').replaceAll('Ç', 'C');
      final tutar = (r['t'] as num).toDouble();
      final kom   = (r['k'] as num).toDouble();
      final adet  = (r['adet'] as int);
      if (kt.contains('IPTAL')) {
        zeyilEksi    += tutar.abs();
        zeyilEksiKom += kom.abs();
        zeyilEksiAdet += adet;
      } else {
        zeyilArti    += tutar.abs();
        zeyilArtiKom += kom.abs();
        zeyilArtiAdet += adet;
      }
    }

    // Aylık kırılım
    final aylikVeri = await aralikAnaliz(yil, 1, 12);

    return {
      'yil':           yil,
      'toplam':        toplam,
      'gelir':         gelir,
      'komisyon':      komisyon,
      'netGelir':      gelir    + zeyilArti - zeyilEksi,
      'netKomisyon':   komisyon + zeyilArtiKom - zeyilEksiKom,
      'zeyilArti':     zeyilArti,
      'zeyilEksi':     zeyilEksi,
      'zeyilArtiKom':  zeyilArtiKom,
      'zeyilEksiKom':  zeyilEksiKom,
      'zeyilArtiAdet': zeyilArtiAdet,
      'zeyilEksiAdet': zeyilEksiAdet,
      'turDagilimi':   turDagilimi,
      'turPrim':       turPrim,
      'turKomisyon':   turKomisyon,
      'turEmoji':      turEmoji,
      'aylikVeri':     aylikVeri,
    };
  }

  Future<List<Police>> hepsiniGetir() async {
    final d = await db;
    final r = await d.query('policeler', orderBy: 'bitisTarihi ASC');
    return r.map(Police.fromMap).toList();
  }
}
