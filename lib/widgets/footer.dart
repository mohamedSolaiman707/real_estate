import 'package:flutter/material.dart';
import '../constants/colors.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.text,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text(
            'مكتب عقارات طنطا',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'العنوان: طنطا، شارع البحر، برج السلام',
            style: TextStyle(color: Colors.white70),
          ),
          const Text(
            'تليفون: 01001234567',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            '© ${DateTime.now().year} جميع الحقوق محفوظة',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
