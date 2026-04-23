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
  bool _hasError = false;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final stats = await _supabaseService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
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
            : _hasError
                ? _buildErrorWidget()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('نظرة عامة على الأداء الحقيقي'),
                          _buildStatsCards(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('التقدم نحو الهدف الشهري'),
                          _buildProgressSection(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('توزيع العقارات المتاحة بالسوق'),
                          _buildPieChartSection(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('رؤى السوق'),
                          _buildMarketInsightsTable(),
                          const SizedBox(height: 24),
                          _buildMotivationCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text('عذراً، حدث خطأ أثناء تحميل البيانات', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
        ],
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
        _buildStatCard('عملاء بالداتابيز', '${_stats['new_customers'] ?? 0}', Colors.blue),
        _buildStatCard('معاينات اليوم', '${_stats['tours_today'] ?? 0}', Colors.orange),
        _buildStatCard('تقدير الفرص', '${_stats['expected_deals'] ?? 0}', Colors.purple),
        _buildStatCard('قيمة المحفظة (تقديري)', '${_stats['commission'] ?? 0}', Colors.green),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    double progress = 0.0;
    int totalProps = _stats['total_properties'] ?? 0;
    progress = (totalProps / 10).clamp(0.0, 1.0); 
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الهدف الشهري: 10 عقارات جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: AppColors.success,
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            Text(
              progress >= 1.0 
                ? 'مبروك! حققت هدف الشهر بالكامل 🏆' 
                : 'فاضلك ${(10 - totalProps).clamp(0, 10)} عقارات عشان توصل للهدف الشهري 💪', 
              style: const TextStyle(color: Colors.grey)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    final Map<String, int> dist = Map<String, int>.from(_stats['distribution'] ?? {});
    if (dist.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(child: Text('لا توجد بيانات عقارات كافية للرسم البياني')),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: dist.entries.map((e) {
            final List<Color> colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple];
            final color = colors[dist.keys.toList().indexOf(e.key) % colors.length];
            return PieChartSectionData(
              value: e.value.toDouble(),
              title: '${e.key}\n(${e.value})',
              color: color,
              radius: 60,
              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMarketInsightsTable() {
    final Map<String, int> dist = Map<String, int>.from(_stats['distribution'] ?? {});
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: dist.isEmpty 
          ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد بيانات حالياً')))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(AppColors.primary.withOpacity(0.05)),
                columns: const [
                  DataColumn(label: Text('نوع العقار', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('العدد المتاح', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: dist.entries.map((e) => DataRow(cells: [
                  DataCell(Text(e.key)),
                  DataCell(Text(e.value.toString())),
                  const DataCell(Text('نشط', style: TextStyle(color: Colors.green))),
                ])).toList(),
              ),
            ),
    );
  }

  Widget _buildMotivationCard() {
    int totalProps = _stats['total_properties'] ?? 0;
    return Card(
      color: AppColors.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, size: 48, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                totalProps > 5 
                  ? 'أداء رائع! عندك $totalProps عقار نشط في السوق حالياً 🚀'
                  : 'البداية قوية! استمر في إضافة العقارات لزيادة فرص البيع 📈',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
