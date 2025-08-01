import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:namer_app/pages/login_page.dart';
import 'package:namer_app/pages/register_page.dart';
import 'package:namer_app/user_pages/user_home/user_home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLoginPage = true;

  void toggleScreens() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        //
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        //Si está logueado, va al Home directamente
        if (snapshot.hasData) {
          return const UserHomePage();
        }

        // Si no está logueado, muestra Login/Registro
        if (showLoginPage) {
          return LoginPage(showRegisterPage: toggleScreens);
        } else {
          return RegisterPage(showLoginPage: toggleScreens);
        }
      },
    );
  }
}
