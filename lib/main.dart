// main.dart
// MeshDrop app entry point.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_screen.dart';
import 'ui/device_list_screen.dart';
import 'ui/transfer_screen.dart';
import 'ui/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MeshDropApp(),
    ),
  );
}

class MeshDropApp extends StatelessWidget {
  const MeshDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshDrop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF238636),
          surface: Color(0xFF161B22),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/devices': (_) => const DeviceListScreen(),
        '/transfers': (_) => const TransferScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
