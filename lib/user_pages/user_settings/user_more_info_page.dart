import 'package:flutter/material.dart';

class UserMoreInfoPage extends StatelessWidget {
  const UserMoreInfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Más información'),
      ),
      body: const Center(
        child: Text(
          'Página de Más información',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
