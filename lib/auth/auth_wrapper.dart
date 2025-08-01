import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/admin_pages/admin_home/admin_home_page.dart';
import 'package:namer_app/pages/auth_page.dart';
import 'package:namer_app/user_pages/user_home/user_home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getInitialScreen(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data == null || !data.containsKey('rol')) {
        return const AuthPage();
      }

      final rol = data['rol'];

      if (rol == 'admin') {
        return const AdminHomePage();
      } else {
        return const UserHomePage();
      }
    } catch (e) {
      print('Error al obtener rol: {$e}'.tr());
      return const AuthPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const AuthPage(); // usuario no logueado
        }

        return FutureBuilder<Widget>(
          future: _getInitialScreen(snapshot.data!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return const AuthPage();
            }

            return snapshot.data!;
          },
        );
      },
    );
  }
}
