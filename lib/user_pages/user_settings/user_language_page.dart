import 'package:flutter/material.dart';

class UserLanguagePage extends StatelessWidget {
  const UserLanguagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Idioma'),
      ),
      body: const Center(
        child: Text(
          'Página de Idioma',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
