import 'package:flutter/material.dart';

class UserContactPage extends StatelessWidget {
  const UserContactPage({Key? key}) : super(key: key);

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
