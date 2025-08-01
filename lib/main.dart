import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:namer_app/SplashScreen.dart';
import 'package:namer_app/admin_pages/admin_home/admin_home_page.dart';
import 'package:namer_app/auth/auth_wrapper.dart';
import 'package:namer_app/user_pages/user_home/user_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B&R Consulting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey[200],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8902),
          primary: const Color(0xFFFF8902),
          secondary: const Color(0xFFFF8902),
          brightness: Brightness.light,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8902),
            foregroundColor: Colors.black,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF8902),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF8902),
          foregroundColor: Colors.black,
        ),
        switchTheme: const SwitchThemeData(
          thumbColor: WidgetStatePropertyAll(Color(0xFFFF8902)),
          trackColor: WidgetStatePropertyAll(Color(0xFFFF8902)),
        ),
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/adminHome': (context) => const AdminHomePage(),
        '/userHome': (context) => const UserHomePage(),
      },
    );
  }
}
