// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/notification_service.dart';
import 'services/database_service.dart';
import 'screens/policeler_screen.dart';
import 'screens/takvim_screen.dart';
import 'screens/analizler_screen.dart';
import 'screens/police_detay_screen.dart';
import 'theme/app_colors.dart';
import 'providers/theme_notifier.dart';

// Global navigator key — bildirim tap'inde navigation için
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global navigation key — ana sekmelerde gezinmek için
final GlobalKey<_NavState> mainNavKey = GlobalKey<_NavState>();

/// Ana Poliçeler sekmesine dön
void goPoliceler() {
  mainNavKey.currentState?._go(0);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  await NotificationService().baslat(
    onTikla: (payload) => _bildirimNavigasyonu(payload),
  );

  // Tema tercihlerini yükle
  await ThemeNotifier().load();

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

class PolicemApp extends StatefulWidget {
  const PolicemApp({super.key});
  @override
  State<PolicemApp> createState() => _PolicemAppState();
}

class _PolicemAppState extends State<PolicemApp> {
  late ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ThemeNotifier();
    _themeNotifier.addListener(_themeChanged);
  }

  @override
  void dispose() {
    _themeNotifier.removeListener(_themeChanged);
    super.dispose();
  }

  void _themeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeNotifier.isDark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? kBgCardDark : kBgCard,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp(
      title: 'Poliçem',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeNotifier.themeMode,
      home: _Nav(
        key: mainNavKey,
        themeNotifier: _themeNotifier,
      ),
    );
  }
}

class _Nav extends StatefulWidget {
  final ThemeNotifier themeNotifier;
  const _Nav({Key? key, required this.themeNotifier}) : super(key: key);
  @override
  State<_Nav> createState() => _NavState();
}

class _NavState extends State<_Nav> {
  int _i = 0;
  final _ctrl = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (_i == i) return;
    setState(() => _i = i);
    _ctrl.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kBgDark : kBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: PageView(
        controller: _ctrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Keep(
            child: PolicelerScreen(themeNotifier: widget.themeNotifier),
          ),
          const _Keep(child: TakvimScreen()),
          const _Keep(child: AnalizlerScreen()),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        selected: _i,
        onTap: _go,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int selected;
  final void Function(int) onTap;
  const _BottomBar({required this.selected, required this.onTap});

  static const _data = [
    (Icons.shield_outlined, Icons.shield, 'Poliçeler'),
    (Icons.calendar_today_outlined, Icons.calendar_today, 'Takvim'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Analizler'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kGlassDark : kGlass;
    final borderColor = isDark ? kBorderDark : kBorder;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.07),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_data.length, (i) {
              final sel = i == selected;
              final textHintColor =
                  isDark ? kTextHintDark : const Color(0xFFB2BEDA);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sel ? kPrimary.withOpacity(0.11) : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          sel ? _data[i].$2 : _data[i].$1,
                          size: 22,
                          color: sel ? kPrimary : textHintColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _data[i].$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? kPrimary : textHintColor,
                        ),
                      ),
                    ],
                  ),
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
  @override
  State<_Keep> createState() => _KeepState();
}

class _KeepState extends State<_Keep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext ctx) {
    super.build(ctx);
    return widget.child;
  }
}
