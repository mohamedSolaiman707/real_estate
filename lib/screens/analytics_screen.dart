import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _supabaseService.getDashboardStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم والتحليلات'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('نظرة عامة على الأداء'),
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('التقدم نحو الهدف الشهري'),
                    _buildProgressSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('توزيع العقارات بالسوق'),
                    SizedBox(height: 300, child: _buildPieChart()),
                    const SizedBox(height: 24),
                    _buildSectionTitle('أداء المناطق'),
                    _buildMarketInsightsTable(),
                    const SizedBox(height: 24),
                    _buildMotivationCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {}, 
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

  Widget _buildStatsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('عملاء جدد', '${_stats['new_customers'] ?? 0}', Colors.blue),
        _buildStatCard('معاينات اليوم', '${_stats['tours_today'] ?? 0}', Colors.orange),
        _buildStatCard('صفقات متوقعة', '${_stats['expected_deals'] ?? 0}', Colors.purple),
        _buildStatCard('عمولة (ج.م)', '${_stats['commission'] ?? 0}', Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الهدف الشهري: 10 صفقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('80%', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.8,
              backgroundColor: Colors.grey[200],
              color: AppColors.success,
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            const Text('عاش يا بطل! باقي لك صفتين بس وتقفل التارجت 🎯', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketInsightsTable() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
          columns: const [
            DataColumn(label: Text('المنطقة', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('عدد الصفقات', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('متوسط العائد', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text('الحي الغربي')), DataCell(Text('45')), DataCell(Text('12%'))]),
            DataRow(cells: [DataCell(Text('وسط المدينة')), DataCell(Text('30')), DataCell(Text('15%'))]),
            DataRow(cells: [DataCell(Text('الضواحي')), DataCell(Text('25')), DataCell(Text('8%'))]),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(value: 40, title: 'شقق', color: Colors.blue, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: 30, title: 'فيلات', color: Colors.green, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: 20, title: 'تجاري', color: Colors.orange, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          PieChartSectionData(value: 10, title: 'أراضي', color: Colors.red, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Card(
      color: AppColors.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'أنت حالياً في المركز الثالث على مستوى الشركة! استمر 💪',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
