import 'package:flutter/material.dart';

class OwnerOrders extends StatelessWidget {
  const OwnerOrders({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Customer Orders",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}
