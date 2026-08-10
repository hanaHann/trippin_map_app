import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'providers/trip_provider.dart';
import 'screens/map_screen.dart';

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
      themeMode: ThemeMode.system,
      home: const MapScreen(),
    );
  }
}
