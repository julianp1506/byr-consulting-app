import 'package:flutter/material.dart';

class AdminContactPage extends StatelessWidget {
  const AdminContactPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contáctenos'),
      ),
      body: const Center(
        child: Text(
          'Página de Contáctenos',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
