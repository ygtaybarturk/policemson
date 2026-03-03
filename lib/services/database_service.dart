// lib/services/database_service.dart – v4 (komisyon + migration)
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/police_model.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._();
  factory DatabaseService() => _i;
  DatabaseService._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final p = join(await getDatabasesPath(), 'policem_v3.db');
    return openDatabase(p, version: 2, onCreate: _create, onUpgrade: _upgrade);
  }

  Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE policeler (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        musteri_adi          TEXT NOT NULL,
        soyadi               TEXT NOT NULL,
        telefon              TEXT NOT NULL,
        email                TEXT,
        tc_kimlik_no         TEXT,
        dogum_tarihi         TEXT,
        sirket               TEXT NOT NULL,
        tur                  INTEGER NOT NULL,
        ozel_tur_adi         TEXT,
        baslangic_tarihi     TEXT NOT NULL,
        bitis_tarihi         TEXT NOT NULL,
        tutar                REAL NOT NULL,
        komisyon             REAL NOT NULL DEFAULT 0,
        belge_seri_no        TEXT,
        durum                INTEGER NOT NULL DEFAULT 0,
        olusturma_tarihi     TEXT NOT NULL,
        arac_plaka           TEXT,
        arac_marka           TEXT,
        arac_model           TEXT,
        arac_yil             TEXT,
        ruhsat_seri_no       TEXT,
        adres                TEXT,
        uavt                 TEXT,
        hatirlatici_tarihi   TEXT,
        hatirlatici_notu     TEXT,
        takvim_notu_tarih    TEXT,
        takvim_notu_icerik   TEXT,
        notlar               TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_bitis ON policeler(bitis_tarihi)');
    await db.execute('CREATE INDEX idx_durum  ON policeler(durum)');
  }

  // Eski DB'ye komisyon kolonu ekle
  Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      try {
        await db.execute('ALTER TABLE policeler ADD COLUMN komisyon REAL NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        // pdf_dosya_yolu artık kullanılmıyor ama var olabilir, ignore
      } catch (_) {}
    }
  }

  // ── CRUD ─────────────────────────────────────────────────
  Future<int>  ekle(Police p)     async => (await database).insert('policeler', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<int>  guncelle(Police p) async => (await database).update('policeler', p.toMap(), where: 'id=?', whereArgs: [p.id]);
  Future<int>  sil(int id)        async => (await database).delete('policeler', where: 'id=?', whereArgs: [id]);
  Future<void> durumGuncelle(int id, PoliceStatus d) async =>
      (await database).update('policeler', {'durum': d.index}, where: 'id=?', whereArgs: [id]);

  Future<Police?> getir(int id) async {
    final r = await (await database).query('policeler', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Police.fromMap(r.first);
  }

  // ── Aylık liste ──────────────────────────────────────────
  Future<List<Police>> aylik(int y, int m, {PoliceStatus? filtre}) async {
    final bas = DateTime(y, m, 1).toIso8601String();
    final bit = DateTime(y, m + 1, 0, 23, 59, 59).toIso8601String();
    String w = 'olusturma_tarihi BETWEEN ? AND ?';
    List a = [bas, bit];
    if (filtre != null) { w += ' AND durum=?'; a.add(filtre.index); }
    final r = await (await database).query('policeler', where: w, whereArgs: a, orderBy: 'baslangic_tarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  // ── Yıllık tüm poliçeler (takvim not ekle için) ─────────
  Future<List<Police>> yillikTumPoliceler(int yil) async {
    final bas = DateTime(yil, 1, 1).toIso8601String();
    final bit = DateTime(yil, 12, 31, 23, 59, 59).toIso8601String();
    final r = await (await database).query(
      'policeler',
      where: 'olusturma_tarihi BETWEEN ? AND ?',
      whereArgs: [bas, bit],
      orderBy: 'musteri_adi ASC',
    );
    return r.map(Police.fromMap).toList();
  }

  // ── Analiz ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> aralikAnaliz(int yil, int basMay, int bitMay) async {
    final db = await database;
    final sonuc = <Map<String, dynamic>>[];
    for (int m = basMay; m <= bitMay; m++) {
      final bas = DateTime(yil, m, 1).toIso8601String();
      final bit = DateTime(yil, m + 1, 0, 23, 59, 59).toIso8601String();
      final rows = await db.rawQuery('''
        SELECT durum, SUM(tutar) as gelir, SUM(komisyon) as toplamKomisyon, COUNT(*) as adet
        FROM policeler WHERE olusturma_tarihi BETWEEN ? AND ?
        GROUP BY durum
      ''', [bas, bit]);
      int top = 0, yap = 0, yap2 = 0, bekl = 0, son = 0;
      double gelir = 0, topKom = 0;
      for (final r in rows) {
        final d = PoliceStatus.values[r['durum'] as int];
        final n = r['adet'] as int;
        final g = (r['gelir'] as num?)?.toDouble() ?? 0;
        final k = (r['toplamKomisyon'] as num?)?.toDouble() ?? 0;
        top += n;
        topKom += k;
        if (d == PoliceStatus.yapildi) { yap += n; gelir += g; }
        if (d == PoliceStatus.yapilamadi) yap2 += n;
        if (d == PoliceStatus.beklemede) bekl += n;
        if (d == PoliceStatus.dahaSonra) son += n;
      }
      sonuc.add({
        'ay': m, 'yil': yil, 'toplam': top,
        'yapildi': yap, 'yapilamadi': yap2,
        'beklemede': bekl, 'dahaSonra': son,
        'gelir': gelir, 'komisyon': topKom,
      });
    }
    return sonuc;
  }

  Future<List<Police>> yaklasan({int gun = 10}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final lim = DateTime.now().add(Duration(days: gun)).toIso8601String();
    final r = await db.query('policeler',
      where: 'bitis_tarihi BETWEEN ? AND ? AND durum=?',
      whereArgs: [now, lim, PoliceStatus.beklemede.index],
      orderBy: 'bitis_tarihi ASC');
    return r.map(Police.fromMap).toList();
  }

  Future<Map<int, int>> aylikSayilar(int yil) async {
    final db = await database;
    final res = <int, int>{};
    for (int m = 1; m <= 12; m++) {
      final b = DateTime(yil, m, 1).toIso8601String();
      final e = DateTime(yil, m + 1, 0, 23, 59, 59).toIso8601String();
      final r = await db.rawQuery('SELECT COUNT(*) as c FROM policeler WHERE olusturma_tarihi BETWEEN ? AND ?', [b, e]);
      res[m] = (r.first['c'] as int?) ?? 0;
    }
    return res;
  }

  Future<List<Police>> adSoyadAra(String query, int yil) async {
    final db = await database;
    if (query.trim().isEmpty) return [];
    final q = '%${query.trim().toLowerCase()}%';
    final bas = DateTime(yil, 1, 1).toIso8601String();
    final bit = DateTime(yil, 12, 31, 23, 59, 59).toIso8601String();
    final r = await db.rawQuery('''
      SELECT * FROM policeler
      WHERE (LOWER(musteri_adi) LIKE ? OR LOWER(soyadi) LIKE ?
             OR LOWER(musteri_adi || ' ' || soyadi) LIKE ?)
        AND olusturma_tarihi BETWEEN ? AND ?
      ORDER BY bitis_tarihi ASC
    ''', [q, q, q, bas, bit]);
    return r.map(Police.fromMap).toList();
  }
}
