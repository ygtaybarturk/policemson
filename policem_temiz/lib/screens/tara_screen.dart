// lib/screens/tara_screen.dart – v3.1
// Belge Tarayici: Kamera / Galeri → Manuel kırpma → PDF → Kaydet/Paylaş
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;

enum _Boyut { buyuk, orta, kucuk }
enum _Adim { kaynak, kirp, kaydet }

class TaraScreen extends StatefulWidget {
  const TaraScreen({super.key});
  @override State<TaraScreen> createState() => _TaraScreenState();
}

class _TaraScreenState extends State<TaraScreen> with TickerProviderStateMixin {
  final _picker = ImagePicker();
  _Adim _adim = _Adim.kaynak;
  XFile? _gorsel;
  Uint8List? _gorselBytes;
  Uint8List? _islenmisBytes;
  bool _islem = false;

  // Kırpma noktaları (normalleştirilmiş 0-1 arasında)
  // Sol-üst, Sağ-üst, Sağ-alt, Sol-alt (saat yönünde)
  List<Offset> _noktalar = [];
  Size _imageSize = Size.zero;

  _Boyut _boyut = _Boyut.orta;
  String? _kaydedilenYol;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  // ── Görsel Al ───────────────────────────────────────────
  Future<void> _kameraAc() async {
    final f = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear);
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
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    setState(() {
      _gorsel = f;
      _gorselBytes = bytes;
      _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
      // Varsayılan köşeler: tüm görsel
      _noktalar = [
        const Offset(.05, .05),
        const Offset(.95, .05),
        const Offset(.95, .95),
        const Offset(.05, .95),
      ];
      _adim = _Adim.kirp;
      _islenmisBytes = null;
      _kaydedilenYol = null;
    });
  }

  // ── Kırpma ve Perspektif Düzeltme ───────────────────────
  Future<void> _islemeBasla() async {
    if (_gorselBytes == null) return;
    setState(() => _islem = true);

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final imgObj = img.decodeImage(_gorselBytes!)!;
      final w = imgObj.width.toDouble();
      final h = imgObj.height.toDouble();

      // Piksel koordinatlarına çevir
      final tl = Offset(_noktalar[0].dx * w, _noktalar[0].dy * h);
      final tr = Offset(_noktalar[1].dx * w, _noktalar[1].dy * h);
      final br = Offset(_noktalar[2].dx * w, _noktalar[2].dy * h);
      final bl = Offset(_noktalar[3].dx * w, _noktalar[3].dy * h);

      // Hedef boyut hesapla
      final outW = ((tr - tl).distance + (br - bl).distance) ~/ 2;
      final outH = ((bl - tl).distance + (br - tr).distance) ~/ 2;

      // Basit dörtgen kırpma (tam perspektif için native gerekir, burada bbox)
      final minX = [tl.dx, tr.dx, br.dx, bl.dx].reduce(math.min).clamp(0, w - 1).toInt();
      final minY = [tl.dy, tr.dy, br.dy, bl.dy].reduce(math.min).clamp(0, h - 1).toInt();
      final maxX = [tl.dx, tr.dx, br.dx, bl.dx].reduce(math.max).clamp(0, w - 1).toInt();
      final maxY = [tl.dy, tr.dy, br.dy, bl.dy].reduce(math.max).clamp(0, h - 1).toInt();

      final kirpilmis = img.copyCrop(imgObj,
        x: minX, y: minY,
        width: (maxX - minX).clamp(1, 99999),
        height: (maxY - minY).clamp(1, 99999));

      // Boyut seçimine göre yeniden boyutlandır
      final hedefW = switch (_boyut) {
        _Boyut.buyuk => 2480,
        _Boyut.orta  => 1654,
        _Boyut.kucuk => 827,
      };

      img.Image sonuc;
      if (kirpilmis.width > hedefW) {
        sonuc = img.copyResize(kirpilmis, width: hedefW);
      } else {
        sonuc = kirpilmis;
      }

      // Kontrast artır (belge için)
      img.adjustColor(sonuc, contrast: 1.15, brightness: 1.05);

      final jpegBytes = img.encodeJpg(sonuc, quality: switch (_boyut) {
        _Boyut.buyuk => 95,
        _Boyut.orta  => 80,
        _Boyut.kucuk => 65,
      });

      setState(() {
        _islenmisBytes = Uint8List.fromList(jpegBytes);
        _adim = _Adim.kaydet;
        _islem = false;
      });
    } catch (e) {
      setState(() => _islem = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  // ── PDF Oluştur ve Kaydet ────────────────────────────────
  Future<String> _pdfOlustur() async {
    final pdfDoc = pw.Document();
    final pdfImage = pw.MemoryImage(_islenmisBytes!);

    // Boyuta göre sayfa formatı
    final format = switch (_boyut) {
      _Boyut.buyuk => PdfPageFormat.a4,
      _Boyut.orta  => PdfPageFormat.a4,
      _Boyut.kucuk => PdfPageFormat.a5,
    };

    pdfDoc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context ctx) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
    ));

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dosyaAdi = 'scan_$ts.pdf';
    final dosya = File('${dir.path}/$dosyaAdi');
    await dosya.writeAsBytes(await pdfDoc.save());
    return dosya.path;
  }

  Future<void> _cihazaKaydet() async {
    setState(() => _islem = true);
    try {
      final yol = await _pdfOlustur();
      setState(() { _kaydedilenYol = yol; _islem = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Kaydedildi: ${yol.split('/').last}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(label: 'Paylaş', onPressed: () => _paylasYol(yol)),
        ));
      }
    } catch (e) {
      setState(() => _islem = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt hatası: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _paylasYol(String yol) async {
    await Share.shareXFiles([XFile(yol)],
      subject: 'Taranmış Belge', text: 'Poliçem uygulamasından taranmış belge');
  }

  Future<void> _paylasVeYa() async {
    setState(() => _islem = true);
    try {
      final yol = _kaydedilenYol ?? await _pdfOlustur();
      setState(() { _kaydedilenYol = yol; _islem = false; });
      await _paylasYol(yol);
    } catch (e) {
      setState(() => _islem = false);
    }
  }

  void _sifirla() {
    setState(() {
      _gorsel = null; _gorselBytes = null; _islenmisBytes = null;
      _adim = _Adim.kaynak; _kaydedilenYol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          switch (_adim) {
            _Adim.kaynak => '📷 Belge Tara',
            _Adim.kirp   => '✂️ Çerçeve Ayarla',
            _Adim.kaydet => '💾 Kaydet',
          },
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          if (_adim != _Adim.kaynak)
            TextButton(onPressed: _sifirla,
              child: const Text('Yeniden Tara', style: TextStyle(color: Colors.white70))),
        ],
      ),
      body: switch (_adim) {
        _Adim.kaynak => _kaynakEkrani(sc),
        _Adim.kirp   => _kirpEkrani(sc),
        _Adim.kaydet => _kaydetEkrani(sc),
      },
    );
  }

  // ── Ekran 1: Kaynak Seç ─────────────────────────────────
  Widget _kaynakEkrani(ColorScheme sc) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Kamera butonu (büyük)
      GestureDetector(
        onTap: _kameraAc,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sc.primary.withOpacity(.15),
                border: Border.all(color: sc.primary, width: 3)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.camera_alt, size: 60, color: sc.primary),
                const SizedBox(height: 8),
                Text('Kamera Aç', style: TextStyle(color: sc.primary, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 40),
      // Galeri butonu
      OutlinedButton.icon(
        onPressed: _galeriAc,
        icon: const Icon(Icons.photo_library, color: Colors.white70),
        label: const Text('Galeriden Seç', style: TextStyle(color: Colors.white70, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
      const SizedBox(height: 30),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Belgeyi düz bir zemine koyun.\nUygulama köşeleri otomatik algılar.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
        ),
      ),
    ]);
  }

  // ── Ekran 2: Kırp / Çerçeve ─────────────────────────────
  Widget _kirpEkrani(ColorScheme sc) {
    return Column(children: [
      Expanded(
        child: _gorselBytes == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (ctx, constraints) {
            return Stack(fit: StackFit.expand, children: [
              // Görsel
              Image.memory(_gorselBytes!, fit: BoxFit.contain),
              // Köşe noktaları ve çizgiler
              CustomPaint(
                painter: _KirpPainter(
                  noktalar: _noktalar,
                  renk: sc.primary),
              ),
              // Dokunuş alanları
              ..._noktalar.asMap().entries.map((e) {
                final i = e.key;
                final n = e.value;
                return Positioned(
                  left: n.dx * constraints.maxWidth - 22,
                  top:  n.dy * constraints.maxHeight - 22,
                  child: GestureDetector(
                    onPanUpdate: (d) {
                      setState(() {
                        final nx = (n.dx + d.delta.dx / constraints.maxWidth).clamp(.0, 1.0);
                        final ny = (n.dy + d.delta.dy / constraints.maxHeight).clamp(.0, 1.0);
                        _noktalar[i] = Offset(nx, ny);
                      });
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: sc.primary.withOpacity(.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: sc.primary, width: 3)),
                      child: const Icon(Icons.open_with, size: 18, color: Colors.white),
                    ),
                  ),
                );
              }),
            ]);
          }),
      ),
      // Boyut seçici + buton
      Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Boyut seçenekleri
          Row(mainAxisAlignment: MainAxisAlignment.center, children: _Boyut.values.map((b) {
            final on = _boyut == b;
            final label = switch (b) {
              _Boyut.buyuk => '📄 Büyük\nA4 yüksek res',
              _Boyut.orta  => '📋 Orta\nA4 standart',
              _Boyut.kucuk => '🗒️ Küçük\nA5 kompakt',
            };
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _boyut = b),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? sc.primary : Colors.white10,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(label, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: on ? Colors.white : Colors.white60,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal, height: 1.4)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: FilledButton.icon(
              onPressed: _islem ? null : _islemeBasla,
              icon: _islem
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.crop),
              label: Text(_islem ? 'İşleniyor…' : 'Tara ve Devam Et',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            )),
        ]),
      ),
    ]);
  }

  // ── Ekran 3: Önizleme + Kaydet ──────────────────────────
  Widget _kaydetEkrani(ColorScheme sc) {
    return Column(children: [
      // Önizleme
      Expanded(
        child: _islenmisBytes == null
          ? const Center(child: CircularProgressIndicator())
          : InteractiveViewer(
            child: Image.memory(_islenmisBytes!, fit: BoxFit.contain)),
      ),
      // Bilgi + Boyut etiketi
      Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Icon(Icons.check_circle, color: Colors.green.shade400, size: 18),
          const SizedBox(width: 8),
          Text('Tarama hazır  •  ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.primary.withOpacity(.2), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sc.primary.withOpacity(.4))),
            child: Text(
              switch (_boyut) { _Boyut.buyuk=>'Büyük', _Boyut.orta=>'Orta', _Boyut.kucuk=>'Küçük' },
              style: TextStyle(color: sc.primary, fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 8),
          Text('${(_islenmisBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ),
      // Aksiyon butonları
      Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            // Cihaza Kaydet
            Expanded(child: OutlinedButton.icon(
              onPressed: _islem ? null : _cihazaKaydet,
              icon: const Icon(Icons.save_alt, color: Colors.white70),
              label: const Text('Cihaza Kaydet', style: TextStyle(color: Colors.white70)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 10),
            // Paylaş
            Expanded(child: FilledButton.icon(
              onPressed: _islem ? null : _paylasVeYa,
              icon: _islem
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.share),
              label: Text(_islem ? 'Hazırlanıyor…' : 'Paylaş',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
          if (_kaydedilenYol != null) ...[
            const SizedBox(height: 8),
            Text('📁 ${_kaydedilenYol!.split('/').last}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _sifirla,
            icon: const Icon(Icons.add_a_photo, size: 15, color: Colors.white54),
            label: const Text('Yeni Tarama', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ]),
      ),
    ]);
  }
}

// ── Çizim: perspektif çerçeve + köşe noktaları ──────────
class _KirpPainter extends CustomPainter {
  final List<Offset> noktalar;
  final Color renk;
  const _KirpPainter({required this.noktalar, required this.renk});

  @override
  void paint(Canvas canvas, Size size) {
    if (noktalar.length != 4) return;
    final pts = noktalar.map((n) => Offset(n.dx * size.width, n.dy * size.height)).toList();

    // Koyu overlay
    final overlayPaint = Paint()..color = Colors.black.withOpacity(.45);
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addPolygon(pts, true);
    canvas.drawPath(Path.combine(PathOperation.difference, path, cutout), overlayPaint);

    // Çerçeve çizgisi
    final linePaint = Paint()
      ..color = renk ..strokeWidth = 2 ..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..addPolygon(pts, true), linePaint);

    // Köşe vurguları
    final cornerPaint = Paint()..color = renk ..strokeWidth = 4 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 20.0;
    for (int i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final c = pts[(i + 3) % 4];
      final ab = (b - a) / (b - a).distance * len;
      final ac = (c - a) / (c - a).distance * len;
      canvas.drawLine(a, a + ab, cornerPaint);
      canvas.drawLine(a, a + ac, cornerPaint);
    }
  }

  @override bool shouldRepaint(_KirpPainter old) => old.noktalar != noktalar;
}
