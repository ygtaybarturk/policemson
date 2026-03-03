// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'screens/policeler_screen.dart';
import 'screens/takvim_screen.dart';
import 'screens/analizler_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/police_detay_screen.dart';
import 'theme/app_colors.dart';

// Global navigator key — bildirim tap'inde navigation için
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _i = ThemeNotifier._();
  factory ThemeNotifier() => _i;
  ThemeNotifier._();
  bool get dark => false;
  Future<void> load() async {}
  Future<void> toggle() async {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  await NotificationService().baslat(
    onTikla: (payload) => _bildirimNavigasyonu(payload),
  );

  runApp(const PolicemApp());
}

/// Bildirim payload'ına göre ilgili ekrana yönlendir
Future<void> _bildirimNavigasyonu(String payload) async {
  if (payload.startsWith('police:')) {
    final idStr = payload.replaceFirst('police:', '');
    final policeId = int.tryParse(idStr);
    if (policeId == null) return;

    // Police var mı kontrol et
    final db = DatabaseService();
    final police = await db.getById(policeId);
    if (police == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Zaten detay ekranındaysa tekrar açma
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => PoliceDetayScreen(policeId: policeId),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, child) {
          final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: a.drive(tween), child: child);
        },
      ),
    );
  }
}

class PolicemApp extends StatelessWidget {
  const PolicemApp({super.key});
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: kBgCard,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    return MaterialApp(
      title: 'Poliçem',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: _buildTheme(),
      home: const _Nav(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary, primary: kPrimary,
        brightness: Brightness.light,
        surface: kBg, surfaceContainerHighest: kBgCard2,
      ),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(
        centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: kBgCard, foregroundColor: kText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: kText),
      ),
      cardTheme: CardThemeData(
        color: kBgCard, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: kBgCard2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 2)),
        labelStyle: const TextStyle(color: kTextSub),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: kDivider, thickness: 1),
    );
  }
}

class _Nav extends StatefulWidget {
  const _Nav();
  @override State<_Nav> createState() => _NavState();
}

class _NavState extends State<_Nav> {
  int _i = 0;
  final _ctrl = PageController();
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  void _go(int i) { if (_i == i) return; setState(() => _i = i); _ctrl.jumpToPage(i); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: PageView(
        controller: _ctrl,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _Keep(child: PolicelerScreen()),
          _Keep(child: TakvimScreen()),
          _Keep(child: AnalizlerScreen()),
          _Keep(child: ProfilScreen()),
        ],
      ),
      bottomNavigationBar: _BottomBar(selected: _i, onTap: _go),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;
  const _BottomBar({required this.selected, required this.onTap});

  static const _data = [
    (Icons.shield_outlined,         Icons.shield,         'Poliçeler'),
    (Icons.calendar_today_outlined,  Icons.calendar_today, 'Takvim'),
    (Icons.bar_chart_outlined,       Icons.bar_chart,      'Analizler'),
    (Icons.person_outline,           Icons.person,         'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kGlass,
        border: const Border(top: BorderSide(color: kBorder, width: 0.8)),
        boxShadow: [
          BoxShadow(color: kPrimary.withOpacity(0.07), blurRadius: 28, offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(top: false,
        child: SizedBox(height: 62,
          child: Row(
            children: List.generate(_data.length, (i) {
              final sel = i == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); onTap(i); },
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? kPrimary.withOpacity(0.11) : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(sel ? _data[i].$2 : _data[i].$1, size: 22,
                          color: sel ? kPrimary : kTextHint),
                    ),
                    const SizedBox(height: 3),
                    Text(_data[i].$3, style: TextStyle(
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? kPrimary : kTextHint,
                    )),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Keep extends StatefulWidget {
  final Widget child;
  const _Keep({required this.child});
  @override State<_Keep> createState() => _KeepState();
}
class _KeepState extends State<_Keep> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  @override Widget build(BuildContext ctx) { super.build(ctx); return widget.child; }
}
