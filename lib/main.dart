// lib/main.dart – M3 Redesign
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/notification_service.dart';
import 'screens/policeler_screen.dart';
import 'screens/takvim_screen.dart';
import 'screens/analizler_screen.dart';
import 'screens/tara_screen.dart';
import 'screens/profil_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await NotificationService().baslat();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const PolicemApp());
}

class PolicemApp extends StatelessWidget {
  const PolicemApp({super.key});

  static const _primary = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poliçem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
          brightness: Brightness.light,
          surface: const Color(0xFFF0F5FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F5FF),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x201565C0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0DCEE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0DCEE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFFE3F0FF),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            final sel = s.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: sel ? _primary : const Color(0xFF7A8AAA),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((s) {
            final sel = s.contains(WidgetState.selected);
            return IconThemeData(color: sel ? _primary : const Color(0xFF9AAAC0), size: 22);
          }),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE8EEFF), thickness: 1),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEEF3FF),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const _Nav(),
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

  void _go(int i) {
    if (_i == i) return;
    setState(() => _i = i);
    _ctrl.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _ctrl,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _Keep(child: PolicelerScreen()),
          _Keep(child: TakvimScreen()),
          _Keep(child: TaraScreen()),
          _Keep(child: AnalizlerScreen()),
          _Keep(child: ProfilScreen()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8EEFF))),
          boxShadow: [BoxShadow(color: Color(0x0F1565C0), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: _go,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Poliçeler'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
            NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner), label: 'Tara'),
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
