import 'package:flutter/material.dart';

class AdminLanguagePage extends StatelessWidget {
  const AdminLanguagePage({Key? key}) : super(key: key);

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
