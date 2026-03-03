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
      version: 4,
      onCreate: (db, v) => _createTable(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute('ALTER TABLE policeler ADD COLUMN policeNo TEXT');
          await db.execute('ALTER TABLE policeler ADD COLUMN hatirlaticiTarihi TEXT');
          await db.execute('ALTER TABLE policeler ADD COLUMN notlar TEXT');
        }
        if (oldV < 3) {
          try {
            await db.execute('ALTER TABLE policeler ADD COLUMN policeNo TEXT');
          } catch (_) {}
        }
        if (oldV < 4) {
          // Yeni alanlar ekleniyor
          final newCols = [
            'email TEXT',
            'dogumTarihi TEXT',
            'ozelTurAdi TEXT',
            'ruhsatSeriNo TEXT',
            'adres TEXT',
            'uavt TEXT',
            'olusturmaTarihi TEXT',
            'hatirlaticiNotu TEXT',
          ];
          for (final col in newCols) {
            try {
              await db.execute('ALTER TABLE policeler ADD COLUMN $col');
            } catch (_) {}
          }
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
        olusturmaTarihi  TEXT
      )
    ''');
  }

  Future<int> ekle(Police p) async {
    final d = await db;
    return d.insert('policeler', p.toMap());
  }

  Future<void> guncelle(Police p) async {
    final d = await db;
    await d.update('policeler', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
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

  // Aralık analizi - analizler_screen.dart kullanıyor
  Future<List<Map<String, dynamic>>> aralikAnaliz(int yil, int bas, int bit) async {
    final d = await db;
    final List<Map<String, dynamic>> sonuc = [];
    for (int ay = bas; ay <= bit; ay++) {
      final ayBas = DateTime(yil, ay, 1).toIso8601String();
      final ayBit = DateTime(yil, ay + 1, 0, 23, 59, 59).toIso8601String();
      final rows = await d.query('policeler',
          where: 'bitisTarihi BETWEEN ? AND ?', whereArgs: [ayBas, ayBit]);
      final policeler = rows.map(Police.fromMap).toList();
      final toplam = policeler.length;
      final yapildi = policeler.where((p) => p.durum == PoliceStatus.yapildi).length;
      final yapilamadi = policeler.where((p) => p.durum == PoliceStatus.yapilamadi).length;
      final gelir = policeler.fold<double>(0, (s, p) => s + p.tutar);
      final komisyon = policeler.fold<double>(0, (s, p) => s + p.komisyon);
      sonuc.add({
        'ay': ay,
        'yil': yil,
        'toplam': toplam,
        'yapildi': yapildi,
        'yapilamadi': yapilamadi,
        'gelir': gelir,
        'komisyon': komisyon,
      });
    }
    return sonuc;
  }

  Future<List<Police>> aylik(int yil, int ay, {PoliceStatus? filtre}) async {
    final d = await db;
    final bas = DateTime(yil, ay, 1).toIso8601String();
    final bit = DateTime(yil, ay + 1, 0, 23, 59, 59).toIso8601String();

    String where = "bitisTarihi BETWEEN ? AND ?";
    List<dynamic> args = [bas, bit];

    if (filtre != null) {
      where += " AND durum = ?";
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
        where: 'bitisTarihi BETWEEN ? AND ?',
        whereArgs: [bas, bit],
        orderBy: 'bitisTarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  Future<List<Police>> hepsiniGetir() async {
    final d = await db;
    final r = await d.query('policeler', orderBy: 'bitisTarihi ASC');
    return r.map(Police.fromMap).toList();
  }
}
