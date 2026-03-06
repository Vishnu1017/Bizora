import 'package:flutter/material.dart';

class OwnerProducts extends StatelessWidget {
  const OwnerProducts({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Manage Products",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
