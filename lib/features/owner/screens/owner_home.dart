import 'package:flutter/material.dart';

class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Owner Dashboard",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
