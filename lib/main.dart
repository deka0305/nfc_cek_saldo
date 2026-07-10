import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load(); // muat preferensi tema tersimpan
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const NfcCekSaldoApp());
}

class NfcCekSaldoApp extends StatelessWidget {
  const NfcCekSaldoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDark,
      builder: (context, dark, _) {
        // Sesuaikan warna status bar / navigasi dengan tema.
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: AppTheme.background,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'NFC Cek Saldo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: HomeScreen(),
        );
      },
    );
  }
}
