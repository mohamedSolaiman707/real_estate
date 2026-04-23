import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('أدائك')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(context),
              const SizedBox(height: 24),
              _buildProgressSection(),
              const SizedBox(height: 24),
              const Text('نمو مبيعاتك الشهري', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildLineChart(),
              const SizedBox(height: 24),
              _buildMotivationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('الصفقات (الشهر)', '8', Colors.blue),
        _buildStatCard('الأرباح (الشهر)', '120k', Colors.green),
        _buildStatCard('الترتيب', '#3', Colors.orange),
        _buildStatCard('أفضل منطقة', 'الضواحي', Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الهدف الشهري: 10 صفقات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.8,
              backgroundColor: Colors.grey[200],
              color: AppColors.success,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            const Text('أنت حققت 80% من هدفك!'),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(1, 2), FlSpot(2, 5), FlSpot(3, 3), FlSpot(4, 8)],
              isCurved: true,
              color: AppColors.primary,
            )
          ],
          titlesData: FlTitlesData(show: false),
        ),
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Card(
      color: AppColors.secondary,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'أنت قريب من الهدف! شد الحيل 💪 باقي لك صفقتين بس وتوصل للتوب!',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
