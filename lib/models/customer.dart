import 'package:flutter/material.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String needs;
  final String status; // Hot, Warm, Cold
  final String lastContact;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.needs,
    required this.status,
    required this.lastContact,
  });

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'hot':
        return Colors.red;
      case 'warm':
        return Colors.orange;
      case 'cold':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
