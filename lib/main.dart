import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'providers/trip_provider.dart';
import 'screens/map_screen.dart';
import 'screens/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: const TripPinApp(),
    ),
  );
}

class TripPinApp extends StatelessWidget {
  const TripPinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapMap - 自訂常駐標籤地圖',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.light,
      home: const _AppGate(),
    );
  }
}

/// 開啟 App 時的全螢幕 Loading 畫面守門員：等 `TripProvider` 的實際初始化
/// 真的完成，且至少顯示過一個最短時間（避免瞬間載入畫面一閃而過）才切換到主畫面。
class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  static const _minSplashDuration = Duration(milliseconds: 600);
  bool _minDurationElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _minDurationElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInitializing = context.watch<TripProvider>().isInitializing;
    final ready = _minDurationElapsed && !isInitializing;
    return ready ? const MapScreen() : const SplashView();
  }
}
