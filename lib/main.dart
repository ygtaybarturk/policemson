// lib/main.dart – v5 (gece modu + ThemeNotifier)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'screens/policeler_screen.dart';
import 'screens/takvim_screen.dart';
import 'screens/analizler_screen.dart';
import 'screens/profil_screen.dart';

// ── Global tema notiifer ─────────────────────────────────────
class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _i = ThemeNotifier._();
  factory ThemeNotifier() => _i;
  ThemeNotifier._();

  bool _dark = false;
  bool get dark => _dark;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _dark = p.getBool('dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _dark = !_dark;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark_mode', _dark);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await NotificationService().baslat();
  await ThemeNotifier().load();
  runApp(const PolicemApp());
}

class PolicemApp extends StatefulWidget {
  const PolicemApp({super.key});
  @override State<PolicemApp> createState() => _PolicemAppState();
}

class _PolicemAppState extends State<PolicemApp> {
  final _theme = ThemeNotifier();

  @override
  void initState() {
    super.initState();
    _theme.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _theme.removeListener(() => setState(() {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = _theme.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: dark ? const Color(0xFF161B27) : Colors.white,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'Poliçem',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: const _Nav(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const primary = Color(0xFF1565C0);
    const primaryDark = Color(0xFF4A9EF5);
    final col = dark ? primaryDark : primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: col,
        brightness: brightness,
        surface: dark ? const Color(0xFF161B27) : const Color(0xFFF0F5FF),
        surfaceContainerHighest: dark ? const Color(0xFF1E2535) : const Color(0xFFE8EEFF),
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF0D1117) : const Color(0xFFF0F5FF),
      appBarTheme: AppBarTheme(
        centerTitle: false, elevation: 0, scrolledUnderElevation: 0,
        backgroundColor: dark ? const Color(0xFF161B27) : Colors.white,
        foregroundColor: dark ? const Color(0xFFE8EDF5) : const Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3,
          color: dark ? const Color(0xFFE8EDF5) : const Color(0xFF1A1A2E),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF161B27) : Colors.white,
        elevation: 0,
        shadowColor: dark ? Colors.black45 : const Color(0x201565C0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1E2535) : const Color(0xFFF5F8FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? const Color(0xFF2A3450) : const Color(0xFFD0DCEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? const Color(0xFF2A3450) : const Color(0xFFD0DCEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: col, width: 2),
        ),
        labelStyle: TextStyle(color: dark ? const Color(0xFF8B97B0) : const Color(0xFF6B7A99)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: col, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF161B27) : Colors.white,
        elevation: 0, shadowColor: Colors.transparent, surfaceTintColor: Colors.transparent,
        indicatorColor: dark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F0FF),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: sel ? col : (dark ? const Color(0xFF5A6580) : const Color(0xFF9AAAC0)));
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return IconThemeData(color: sel ? col : (dark ? const Color(0xFF5A6580) : const Color(0xFF9AAAC0)), size: 22);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xFF262E42) : const Color(0xFFE8EEFF),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        selectedColor: col.withOpacity(0.15),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).navigationBarTheme.backgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          boxShadow: [BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : const Color(0x0F1565C0),
            blurRadius: 16, offset: const Offset(0, -4),
          )],
        ),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: _go,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Poliçeler'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analizler'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
          ],
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
