import 'package:flutter/material.dart';

class UserHelpCenterPage extends StatelessWidget {
  const UserHelpCenterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de ayuda'),
      ),
      body: const Center(
        child: Text(
          'Página del Centro de ayuda',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
