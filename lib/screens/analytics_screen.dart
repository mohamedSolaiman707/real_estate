import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تحليل السوق')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('أداء المناطق'),
              _buildMarketInsightsTable(),
              const SizedBox(height: 24),
              _buildSectionTitle('توزيع المبيعات'),
              SizedBox(height: 300, child: _buildPieChart()),
              const SizedBox(height: 24),
              _buildSectionTitle('توقعات الأسبوع القادم'),
              _buildPredictionCard(),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {}, // Download PDF report
          label: const Text('تحميل التقرير PDF'),
          icon: const Icon(Icons.picture_as_pdf),
          backgroundColor: AppColors.danger,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMarketInsightsTable() {
    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('المنطقة')),
          DataColumn(label: Text('عدد الصفقات')),
          DataColumn(label: Text('متوسط العائد')),
        ],
        rows: const [
          DataRow(cells: [DataCell(Text('الحي الغربي')), DataCell(Text('45')), DataCell(Text('12%'))]),
          DataRow(cells: [DataCell(Text('وسط المدينة')), DataCell(Text('30')), DataCell(Text('15%'))]),
          DataRow(cells: [DataCell(Text('الضواحي')), DataCell(Text('25')), DataCell(Text('8%'))]),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(value: 40, title: 'شقق', color: Colors.blue, radius: 50),
          PieChartSectionData(value: 30, title: 'فيلات', color: Colors.green, radius: 50),
          PieChartSectionData(value: 20, title: 'تجاري', color: Colors.orange, radius: 50),
          PieChartSectionData(value: 10, title: 'أراضي', color: Colors.red, radius: 50),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    return Card(
      color: AppColors.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: const [
            ListTile(
              leading: Icon(Icons.trending_up, color: AppColors.success),
              title: Text('نمو متوقع بنسبة 5% في الحي الغربي'),
            ),
            ListTile(
              leading: Icon(Icons.event, color: AppColors.primary),
              title: Text('أفضل يوم للبيع المتوقع: الثلاثاء القادم'),
            ),
          ],
        ),
      ),
    );
  }
}
