// ignore_for_file: library_private_types_in_public_api, no_leading_underscores_for_local_identifiers, prefer_const_declarations

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  void _navigateToAuth() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color _mainOrange = const Color(0xFFFF8902);

    return Scaffold(
      backgroundColor: _mainOrange,
      body: Stack(
        children: [
          // Fondo con patrón
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg_pattern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Logo y texto centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo_white.png',
                  height: 70,
                ),
                const SizedBox(height: 20),
                Text(
                  'B&R Consulting'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Versión en la esquina inferior derecha
          Positioned(
            bottom: 20,
            right: 20,
            child: Text(
              'Version 1.0'.tr(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
