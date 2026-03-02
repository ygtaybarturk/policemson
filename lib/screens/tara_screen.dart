// lib/screens/tara_screen.dart – M3 Redesign
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

enum _Boyut { buyuk, orta, kucuk }
enum _Adim  { kaynak, kirp, onizleme }

class _Sayfa {
  final Uint8List orijinal;
  final Uint8List islenmis;
  _Sayfa({required this.orijinal, required this.islenmis});
}

class TaraScreen extends StatefulWidget {
  const TaraScreen({super.key});
  @override State<TaraScreen> createState() => _TaraScreenState();
}

class _TaraScreenState extends State<TaraScreen> with TickerProviderStateMixin {
  final _picker = ImagePicker();
  _Adim _adim = _Adim.kaynak;
  final List<_Sayfa> _sayfalar = [];
  int _aktifSayfa = 0;

  Uint8List? _gorselBytes;
  List<Offset> _noktalar = [];
  bool _islem = false;
  _Boyut _boyut = _Boyut.orta;
  String? _kaydedilenYol;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _kameraAc() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95, preferredCameraDevice: CameraDevice.rear);
    if (f == null) return;
    await _gorselYukle(f);
  }

  Future<void> _galeriAc() async {
    final f = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (f == null) return;
    await _gorselYukle(f);
  }

  Future<void> _gorselYukle(XFile f) async {
    final bytes = await f.readAsBytes();
    setState(() {
      _gorselBytes = bytes;
      _noktalar = [const Offset(.04,.04), const Offset(.96,.04), const Offset(.96,.96), const Offset(.04,.96)];
      _adim = _Adim.kirp;
      _kaydedilenYol = null;
    });
  }

  Future<void> _islemeBasla() async {
    if (_gorselBytes == null) return;
    setState(() => _islem = true);
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final imgObj = img.decodeImage(_gorselBytes!)!;
      final w = imgObj.width.toDouble();
      final h = imgObj.height.toDouble();

      final tl = Offset(_noktalar[0].dx*w, _noktalar[0].dy*h);
      final tr = Offset(_noktalar[1].dx*w, _noktalar[1].dy*h);
      final br = Offset(_noktalar[2].dx*w, _noktalar[2].dy*h);
      final bl = Offset(_noktalar[3].dx*w, _noktalar[3].dy*h);

      final minX = [tl.dx,tr.dx,br.dx,bl.dx].reduce(math.min).clamp(0,w-1).toInt();
      final minY = [tl.dy,tr.dy,br.dy,bl.dy].reduce(math.min).clamp(0,h-1).toInt();
      final maxX = [tl.dx,tr.dx,br.dx,bl.dx].reduce(math.max).clamp(0,w-1).toInt();
      final maxY = [tl.dy,tr.dy,br.dy,bl.dy].reduce(math.max).clamp(0,h-1).toInt();

      var kirpilmis = img.copyCrop(imgObj, x:minX, y:minY,
        width:(maxX-minX).clamp(1,99999), height:(maxY-minY).clamp(1,99999));

      final hedefW = switch (_boyut) { _Boyut.buyuk=>2480, _Boyut.orta=>1654, _Boyut.kucuk=>827 };
      if (kirpilmis.width > hedefW) kirpilmis = img.copyResize(kirpilmis, width: hedefW);

      img.adjustColor(kirpilmis, contrast: 1.25, brightness: 1.08, saturation: 0.85);
      final jpegBytes = img.encodeJpg(kirpilmis, quality: switch (_boyut) { _Boyut.buyuk=>95, _Boyut.orta=>82, _Boyut.kucuk=>68 });

      setState(() {
        _sayfalar.add(_Sayfa(orijinal: _gorselBytes!, islenmis: Uint8List.fromList(jpegBytes)));
        _aktifSayfa = _sayfalar.length - 1;
        _gorselBytes = null;
        _adim = _Adim.onizleme;
        _islem = false;
      });
    } catch (e) {
      setState(() => _islem = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  Future<String> _pdfOlustur() async {
    final pdfDoc = pw.Document();
    for (final s in _sayfalar) {
      pdfDoc.addPage(pw.Page(
        pageFormat: _boyut == _Boyut.kucuk ? PdfPageFormat.a5 : PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(s.islenmis), fit: pw.BoxFit.contain),
      ));
    }
    final dir = await getApplicationDocumentsDirectory();
    final dosya = File('${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await dosya.writeAsBytes(await pdfDoc.save());
    return dosya.path;
  }

  Future<void> _cihazaKaydet() async {
    setState(() => _islem = true);
    try {
      final yol = await _pdfOlustur();
      setState(() { _kaydedilenYol = yol; _islem = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ ${_sayfalar.length} sayfalı PDF kaydedildi'),
        backgroundColor: Colors.green,
        action: SnackBarAction(label: 'Paylaş', onPressed: () => _paylas(yol)),
      ));
    } catch (e) {
      setState(() => _islem = false);
    }
  }

  Future<void> _paylas(String yol) async =>
    Share.shareXFiles([XFile(yol)], subject: '${_sayfalar.length} Sayfalı Belge');

  Future<void> _paylasVeYa() async {
    setState(() => _islem = true);
    try {
      final yol = _kaydedilenYol ?? await _pdfOlustur();
      setState(() { _kaydedilenYol = yol; _islem = false; });
      await _paylas(yol);
    } catch (e) { setState(() => _islem = false); }
  }

  void _sifirla() => setState(() {
    _sayfalar.clear(); _gorselBytes = null;
    _adim = _Adim.kaynak; _kaydedilenYol = null; _aktifSayfa = 0;
  });

  @override
  Widget build(BuildContext context) {
    final dark = _adim != _Adim.kaynak ? true : false;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0C0C1A) : const Color(0xFFF0F5FF),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF0F0F22) : Colors.white,
        foregroundColor: dark ? Colors.white : const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        title: Text(
          switch (_adim) {
            _Adim.kaynak   => 'Belge Tara',
            _Adim.kirp     => 'Çerçeve Ayarla',
            _Adim.onizleme => '${_sayfalar.length} Sayfa – Önizleme',
          },
          style: TextStyle(fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF1A1A2E)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dark ? const Color(0xFF1E1E36) : const Color(0xFFE8EEFF)),
        ),
        actions: [
          if (_adim != _Adim.kaynak)
            TextButton(
              onPressed: _sifirla,
              child: Text('Sıfırla', style: TextStyle(color: dark ? Colors.white60 : const Color(0xFF1565C0))),
            ),
        ],
      ),
      body: switch (_adim) {
        _Adim.kaynak   => _kaynakEkrani(),
        _Adim.kirp     => _kirpEkrani(),
        _Adim.onizleme => _onizlemeEkrani(),
      },
    );
  }

  // ── Ekran 1: Kaynak ──────────────────────────────────────
  Widget _kaynakEkrani() {
    return SafeArea(
      child: Column(children: [
        const Spacer(),
        // Başlık
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F0FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.document_scanner_outlined, size: 36, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 16),
            const Text('Belge Tarayıcı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            const Text('Belgeyi düz zemine koyun\nkameranızla fotoğraflayın', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF7A8AAA), height: 1.6)),
          ]),
        ),
        const SizedBox(height: 48),
        // Büyük kamera butonu
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: GestureDetector(
                onTap: _kameraAc,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.4), blurRadius: 28, spreadRadius: 4),
                      BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.15), blurRadius: 56, spreadRadius: 12),
                    ],
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_rounded, size: 56, color: Colors.white),
                    SizedBox(height: 6),
                    Text('Kamera Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 36),
        // Galeri
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: OutlinedButton.icon(
            onPressed: _galeriAc,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeriden Seç'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              side: const BorderSide(color: Color(0xFFD0DCEE), width: 1.5),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const Spacer(),
        // Özellik chip'leri
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            _FeatureChip(icon: Icons.crop_free, label: 'Oto Kırpma'),
            _FeatureChip(icon: Icons.picture_as_pdf_outlined, label: 'PDF Çıktı'),
            _FeatureChip(icon: Icons.auto_fix_high_outlined, label: 'Netleştirme'),
            _FeatureChip(icon: Icons.add_to_photos_outlined, label: 'Çoklu Sayfa'),
          ]),
        ),
      ]),
    );
  }

  // ── Ekran 2: Kırp ────────────────────────────────────────
  Widget _kirpEkrani() {
    return Column(children: [
      Expanded(
        child: _gorselBytes == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(builder: (_, constraints) => Stack(fit: StackFit.expand, children: [
                Image.memory(_gorselBytes!, fit: BoxFit.contain),
                CustomPaint(painter: _KirpPainter(noktalar: _noktalar, renk: const Color(0xFF1565C0))),
                ..._noktalar.asMap().entries.map((e) {
                  final i = e.key; final n = e.value;
                  return Positioned(
                    left: n.dx * constraints.maxWidth - 24,
                    top:  n.dy * constraints.maxHeight - 24,
                    child: GestureDetector(
                      onPanUpdate: (d) => setState(() {
                        _noktalar[i] = Offset(
                          (n.dx + d.delta.dx / constraints.maxWidth).clamp(.0, 1.0),
                          (n.dy + d.delta.dy / constraints.maxHeight).clamp(.0, 1.0),
                        );
                      }),
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1565C0), width: 2.5),
                          boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: const Icon(Icons.open_with, size: 20, color: Colors.white),
                      ),
                    ),
                  );
                }),
              ])),
      ),
      Container(
        color: const Color(0xFF0F0F22),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(children: [
          // Boyut seçici
          Row(children: _Boyut.values.map((b) {
            final on = _boyut == b;
            final lbl = switch (b) { _Boyut.buyuk=>'Büyük\nA4 HD', _Boyut.orta=>'Orta\nA4', _Boyut.kucuk=>'Küçük\nA5' };
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _boyut = b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? const Color(0xFF1565C0) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(lbl, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: on ? Colors.white : Colors.white60,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w500, height: 1.4)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 12),
          Row(children: [
            if (_sayfalar.isNotEmpty) ...[
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() => _adim = _Adim.onizleme),
                icon: const Icon(Icons.preview, color: Colors.white60, size: 16),
                label: const Text('Önizleme', style: TextStyle(color: Colors.white60, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _islem ? null : _islemeBasla,
                icon: _islem
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(_islem ? 'İşleniyor…' : 'Tara & Ekle',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  // ── Ekran 3: Önizleme ────────────────────────────────────
  Widget _onizlemeEkrani() {
    if (_sayfalar.isEmpty) {
      return const Center(child: Text('Sayfa yok', style: TextStyle(color: Colors.white)));
    }
    return Column(children: [
      // Küçük sayfa listesi
      Container(
        height: 78,
        color: const Color(0xFF0A0A14),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          itemCount: _sayfalar.length + 1,
          itemBuilder: (_, i) {
            if (i == _sayfalar.length) {
              return GestureDetector(
                onTap: () => setState(() { _gorselBytes = null; _adim = _Adim.kaynak; }),
                child: Container(
                  width: 48, height: 60,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1565C0), width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add, color: Color(0xFF1565C0), size: 20),
                    Text('Ekle', style: TextStyle(color: Color(0xFF1565C0), fontSize: 9, fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            }
            final aktif = i == _aktifSayfa;
            return GestureDetector(
              onTap: () => setState(() => _aktifSayfa = i),
              child: Stack(children: [
                Container(
                  width: 48, height: 60, margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: aktif ? const Color(0xFF1565C0) : Colors.white30, width: aktif ? 2.5 : 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: Image.memory(_sayfalar[i].islenmis, fit: BoxFit.cover)),
                ),
                Positioned(right: 4, top: -2,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _sayfalar.removeAt(i);
                      if (_aktifSayfa >= _sayfalar.length) _aktifSayfa = _sayfalar.length - 1;
                      if (_sayfalar.isEmpty) _adim = _Adim.kaynak;
                    }),
                    child: Container(width: 16, height: 16,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 10, color: Colors.white)),
                  )),
                Positioned(left: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6), topRight: Radius.circular(6)),
                    ),
                    child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  )),
              ]),
            );
          },
        ),
      ),
      // Ana önizleme
      Expanded(child: InteractiveViewer(
        child: Image.memory(_sayfalar[_aktifSayfa].islenmis, fit: BoxFit.contain))),
      // Kaydet bar
      Container(
        color: const Color(0xFF0F0F22),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Text('${_sayfalar.length} sayfa hazır', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.4)),
              ),
              child: Text(
                switch (_boyut) { _Boyut.buyuk=>'Büyük', _Boyut.orta=>'Orta', _Boyut.kucuk=>'Küçük' },
                style: const TextStyle(color: Color(0xFF90CAF9), fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _islem ? null : _cihazaKaydet,
              icon: const Icon(Icons.save_alt, color: Colors.white70, size: 16),
              label: const Text('Kaydet', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: _islem ? null : _paylasVeYa,
              icon: _islem
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.share),
              label: Text(_islem ? 'Hazırlanıyor…' : 'Paylaş',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
          if (_kaydedilenYol != null) ...[
            const SizedBox(height: 8),
            Text('📁 ${_kaydedilenYol!.split('/').last}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _sifirla,
            icon: const Icon(Icons.add_a_photo, size: 14, color: Colors.white38),
            label: const Text('Yeni Tarama Başlat', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
        ]),
      ),
    ]);
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFE3F0FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF1565C0)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1565C0), fontWeight: FontWeight.w700)),
    ]),
  );
}

class _KirpPainter extends CustomPainter {
  final List<Offset> noktalar;
  final Color renk;
  const _KirpPainter({required this.noktalar, required this.renk});

  @override
  void paint(Canvas canvas, Size size) {
    if (noktalar.length != 4) return;
    final pts = noktalar.map((n) => Offset(n.dx * size.width, n.dy * size.height)).toList();
    final overlay = Paint()..color = Colors.black.withOpacity(0.5);
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cut = Path()..addPolygon(pts, true);
    canvas.drawPath(Path.combine(PathOperation.difference, path, cut), overlay);
    canvas.drawPath(Path()..addPolygon(pts, true),
      Paint()..color = renk..strokeWidth = 2.5..style = PaintingStyle.stroke);
    final cp = Paint()..color = renk..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final a = pts[i]; final b = pts[(i+1)%4]; final c = pts[(i+3)%4];
      final ab = (b-a)/(b-a).distance*22; final ac = (c-a)/(c-a).distance*22;
      canvas.drawLine(a, a+ab, cp); canvas.drawLine(a, a+ac, cp);
    }
  }

  @override bool shouldRepaint(_KirpPainter o) => o.noktalar != noktalar;
}
