import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic> _stats = {};
  String _selectedPeriod = 'هذا الشهر'; // 'هذا الشهر', 'الربع الحالي', 'السنة', 'الكل'

  late TabController _periodTabController;

  @override
  void initState() {
    super.initState();
    _periodTabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _periodTabController.dispose();
    super.dispose();
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

  String _formatCurrency(num amount) {
    if (amount >= 1000000) {
      final millions = amount / 1000000;
      return '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)} مليون ج.م';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)} ألف ج.م';
    }
    return '$amount ج.م';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _hasError
                  ? _buildErrorWidget()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        slivers: [
                          _buildExecutiveHeaderBar(),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildKpiRibbonGrid(),
                                const SizedBox(height: 28),
                                _buildConversionFunnel(),
                                const SizedBox(height: 28),
                                _buildGeographicBreakdownSection(),
                                const SizedBox(height: 28),
                                _buildTargetProgressCard(),
                                const SizedBox(height: 28),
                                _buildInteractiveChartsGrid(),
                                const SizedBox(height: 28),
                                _buildMarketInsightsTable(),
                                const SizedBox(height: 40),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ─── Executive Header Bar ───────────────────────────────────────────────────
  Widget _buildExecutiveHeaderBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.slateDark, Color(0xFF1E293B)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 24),
                  tooltip: 'رجوع للوحة التحكم',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.analytics_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة التحليلات والأداء القيادي 📊',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'متابعة المحفظة العقارية والمبيعات • طنطا والقاهرة',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                    tooltip: 'تحديث البيانات',
                    onPressed: _loadData,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Timeframe Selector Tabs
            Center(
              child: Container(
                height: 42,
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    _buildPeriodTab('هذا الشهر'),
                    _buildPeriodTab('الربع الحالي'),
                    _buildPeriodTab('السنة'),
                    _buildPeriodTab('الكل'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String label) {
    bool isSelected = _selectedPeriod == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = label;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ─── KPI Ribbon Grid ────────────────────────────────────────────────────────
  Widget _buildKpiRibbonGrid() {
    final double portfolioValue = (_stats['total_portfolio_value'] ?? 0).toDouble();
    final int commission = _stats['commission'] ?? 0;
    final int expectedDeals = _stats['expected_deals'] ?? 0;
    final int toursToday = _stats['tours_today'] ?? 0;
    final int newCustomers = _stats['new_customers'] ?? 0;
    final String convRate = _stats['conversion_rate']?.toString() ?? '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final crossCount = isDesktop ? 4 : 2;
        final aspectRatio = isDesktop ? 1.45 : 1.35;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: aspectRatio,
          children: [
            _buildExecutiveKpiCard(
              title: 'عمولة المحفظة التقديرية',
              value: _formatCurrency(commission),
              subtitle: 'من إجمالي محفظة ${_formatCurrency(portfolioValue)}',
              icon: Icons.payments_rounded,
              accentColor: const Color(0xFF10B981),
              bgAccent: const Color(0xFFECFDF5),
              trendTag: '+14.2% نمو',
              isPositiveTrend: true,
              onTap: () => Navigator.pushNamed(context, '/dashboard', arguments: {'initialTabIndex': 3}),
            ),
            _buildExecutiveKpiCard(
              title: 'الصفقات المتوقعة',
              value: '$expectedDeals صفقات',
              subtitle: 'معدل إغلاق متوقع 35%',
              icon: Icons.handshake_rounded,
              accentColor: const Color(0xFF6366F1),
              bgAccent: const Color(0xFFEEF2FF),
              trendTag: 'معدل مرتفع 🔥',
              isPositiveTrend: true,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم عرض تفاصيل الصفقات المتوقعة قريباً'))
              ),
            ),
            _buildExecutiveKpiCard(
              title: 'معاينات اليوم المجدولة',
              value: '$toursToday معاينة',
              subtitle: 'تنسيق مباشر مع العملاء',
              icon: Icons.calendar_month_rounded,
              accentColor: const Color(0xFF0EA5E9),
              bgAccent: const Color(0xFFE0F2FE),
              trendTag: 'جاهزة الآن ⏱️',
              isPositiveTrend: true,
              onTap: () => Navigator.pushNamed(context, '/dashboard', arguments: {'initialTabIndex': 2}),
            ),
            _buildExecutiveKpiCard(
              title: 'إجمالي العملاء والطلبات',
              value: '$newCustomers عميل',
              subtitle: 'نسبة التحويل $convRate%',
              icon: Icons.people_alt_rounded,
              accentColor: const Color(0xFFF59E0B),
              bgAccent: const Color(0xFFFFFBEB),
              trendTag: 'نشط 🎯',
              isPositiveTrend: true,
              onTap: () => Navigator.pushNamed(context, '/dashboard', arguments: {'initialTabIndex': 0}),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExecutiveKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgAccent,
    required String trendTag,
    required bool isPositiveTrend,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: bgAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        trendTag,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.1,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Conversion Funnel ──────────────────────────────────────────────────────
  Widget _buildConversionFunnel() {
    final int leads = (_stats['new_customers'] ?? 45) as int;
    final int customers = (_stats['converted_customers'] ?? 12) as int;
    final int tours = (_stats['tours_today'] ?? 5) as int;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'مسار تحويل المبيعات (Funnel) ⚡',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFunnelStep(
            label: 'إجمالي الطلبات (Leads)',
            value: '$leads طلب',
            percentage: 1.0,
            color: const Color(0xFF6366F1),
          ),
          _buildFunnelStep(
            label: 'العملاء المهتمين (Customers)',
            value: '$customers عميل',
            percentage: leads > 0 ? (customers / leads).clamp(0.1, 1.0) : 0.4,
            color: const Color(0xFF0EA5E9),
          ),
          _buildFunnelStep(
            label: 'المعاينات المنفذة (Tours)',
            value: '$tours معاينة',
            percentage: customers > 0 ? (tours / customers).clamp(0.1, 1.0) : 0.2,
            color: const Color(0xFF10B981),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep({
    required String label,
    required String value,
    required double percentage,
    required Color color,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 6,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Icon(Icons.arrow_drop_down, color: AppColors.textMuted.withOpacity(0.3), size: 20),
          ),
      ],
    );
  }

  // ─── Geographic Breakdown (طنطا vs القاهرة) ─────────────────────────────────
  Widget _buildGeographicBreakdownSection() {
    final int tantaCount = _stats['tanta_properties'] ?? 0;
    final int cairoCount = _stats['cairo_properties'] ?? 0;
    final double tantaVal = (_stats['tanta_value'] ?? 0).toDouble();
    final double cairoVal = (_stats['cairo_value'] ?? 0).toDouble();
    final int totalProps = _stats['total_properties'] ?? 1;

    final double tantaRatio = totalProps > 0 ? (tantaCount / totalProps) : 0;
    final double cairoRatio = totalProps > 0 ? (cairoCount / totalProps) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.map_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'التوزيع والتغطية الجغرافية للمحفظة (طنطا والقاهرة) 📍',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            return isMobile
                ? Column(
                    children: [
                      _buildCityCard(
                        cityName: 'فرع طنطا 🌾',
                        subtitle: 'شارع الاستاد والبحر والحي الغربي',
                        propCount: tantaCount,
                        portfolioVal: tantaVal,
                        ratio: tantaRatio,
                        gradientColors: [
                          const Color(0xFF0EA5E9),
                          const Color(0xFF0284C7)
                        ],
                        icon: Icons.location_city_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildCityCard(
                        cityName: 'فرع القاهرة 🏙️',
                        subtitle: 'التجمع الخامس والشيخ زايد والتسعين',
                        propCount: cairoCount,
                        portfolioVal: cairoVal,
                        ratio: cairoRatio,
                        gradientColors: [
                          const Color(0xFF6366F1),
                          const Color(0xFF4F46E5)
                        ],
                        icon: Icons.apartment_rounded,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildCityCard(
                          cityName: 'فرع طنطا 🌾',
                          subtitle: 'شارع الاستاد والبحر والحي الغربي',
                          propCount: tantaCount,
                          portfolioVal: tantaVal,
                          ratio: tantaRatio,
                          gradientColors: [
                            const Color(0xFF0EA5E9),
                            const Color(0xFF0284C7)
                          ],
                          icon: Icons.location_city_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildCityCard(
                          cityName: 'فرع القاهرة 🏙️',
                          subtitle: 'التجمع الخامس والشيخ زايد والتسعين',
                          propCount: cairoCount,
                          portfolioVal: cairoVal,
                          ratio: cairoRatio,
                          gradientColors: [
                            const Color(0xFF6366F1),
                            const Color(0xFF4F46E5)
                          ],
                          icon: Icons.apartment_rounded,
                        ),
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildCityCard({
    required String cityName,
    required String subtitle,
    required int propCount,
    required double portfolioVal,
    required double ratio,
    required List<Color> gradientColors,
    required IconData icon,
  }) {
    final percentStr = (ratio * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: gradientColors[0].withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percentStr% من المحفظة',
                  style: TextStyle(
                    color: gradientColors[0],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('العقارات المتاحة',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    '$propCount عقارات',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('قيمة المعروضات',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(portfolioVal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: gradientColors[0],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(gradientColors[0]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Target Progress Card ──────────────────────────────────────────────────
  Widget _buildTargetProgressCard() {
    final int totalProps = _stats['total_properties'] ?? 0;
    const int targetGoal = 10;
    final double progress = (totalProps / targetGoal).clamp(0.0, 1.0);
    final int remaining = (targetGoal - totalProps).clamp(0, targetGoal);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.flag_rounded,
                    color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم نحو الهدف الشهري 🎯',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'مستهدف إضافة 10 عقارات حديثة شهرياً في طنطا والقاهرة',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 14,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تم إضافة $totalProps من 10 عقارات',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              Text(
                progress >= 1.0
                    ? '🏆 مبروك! حققت الهدف بالكامل'
                    : 'متبقي $remaining عقارات لتحقيق التارقت 🚀',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Interactive Charts Grid ────────────────────────────────────────────────
  Widget _buildInteractiveChartsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildDistributionDonutChart()),
                  const SizedBox(width: 16),
                  Expanded(flex: 7, child: _buildPerformanceLineChart()),
                ],
              )
            : Column(
                children: [
                  _buildDistributionDonutChart(),
                  const SizedBox(height: 16),
                  _buildPerformanceLineChart(),
                ],
              );
      },
    );
  }

  Widget _buildDistributionDonutChart() {
    final Map<String, int> dist =
        Map<String, int>.from(_stats['distribution'] ?? {});
    final int totalCount = _stats['total_properties'] ?? 0;

    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'توزيع أنواع العقارات 🏠',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dist.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(
                child: Text('لا توجد بيانات عقارات كافية حالياً',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 55,
                      sections: dist.entries.map((e) {
                        final index = dist.keys.toList().indexOf(e.key);
                        final color = colors[index % colors.length];
                        final double percentage = totalCount > 0
                            ? (e.value / totalCount) * 100
                            : 0;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: '${percentage.toStringAsFixed(0)}%',
                          color: color,
                          radius: 35,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'إجمالي العقارات',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Custom Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: dist.entries.map((e) {
                final index = dist.keys.toList().indexOf(e.key);
                final color = colors[index % colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: color),
                    const SizedBox(width: 6),
                    Text(
                      '${e.key} (${e.value})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceLineChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart_rounded,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'مسار نمو المبيعات والعمولات 📈',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                  SizedBox(width: 5),
                  Text('المبيعات',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  SizedBox(width: 10),
                  CircleAvatar(radius: 4, backgroundColor: AppColors.secondary),
                  SizedBox(width: 5),
                  Text('المعاينات',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 225,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF1F5F9),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        const months = [
                          'يناير',
                          'فبراير',
                          'مارس',
                          'أبريل',
                          'مايو',
                          'يونيو'
                        ];
                        if (val.toInt() >= 0 && val.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[val.toInt()],
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3),
                      FlSpot(1, 5),
                      FlSpot(2, 4),
                      FlSpot(3, 8),
                      FlSpot(4, 7),
                      FlSpot(5, 11),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.12),
                    ),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 1),
                      FlSpot(1, 3),
                      FlSpot(2, 2),
                      FlSpot(3, 5),
                      FlSpot(4, 6),
                      FlSpot(5, 8),
                    ],
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.secondary.withOpacity(0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Market Insights Data Table ─────────────────────────────────────────────
  Widget _buildMarketInsightsTable() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'تحليلات طلب السوق والعملاء 🎯',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          
          _buildInsightRow(
            title: 'المناطق الأكثر طلباً',
            items: [
              {'label': 'طنطا - الاستاد', 'value': '42%', 'trend': '↑'},
              {'label': 'القاهرة - التجمع', 'value': '35%', 'trend': '↑'},
              {'label': 'طنطا - البحر', 'value': '15%', 'trend': '↓'},
              {'label': 'الشيخ زايد', 'value': '8%', 'trend': '→'},
            ],
          ),
          
          const Divider(height: 1, color: AppColors.border),
          
          _buildInsightRow(
            title: 'ميزانية العملاء الشائعة',
            items: [
              {'label': '1M - 2M ج.م', 'value': '55%', 'trend': '↑'},
              {'label': '2M - 4M ج.م', 'value': '28%', 'trend': '→'},
              {'label': 'فوق 5M ج.م', 'value': '12%', 'trend': '↑'},
              {'label': 'أقل من 1M', 'value': '5%', 'trend': '↓'},
            ],
          ),
          
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInsightRow({required String title, required List<Map<String, String>> items}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              children: [
                Text(item['label']!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Text(item['value']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Text(item['trend']!, style: TextStyle(
                  color: item['trend'] == '↑' ? AppColors.success : (item['trend'] == '↓' ? AppColors.danger : AppColors.warning),
                  fontWeight: FontWeight.bold,
                )),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // ─── Error State Widget ─────────────────────────────────────────────────────
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 56, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'عذراً، تعذر تحميل بيانات التحليلات',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'تأكد من الاتصال بالإنترنت ثم حاول مجدداً',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            label: const Text('إعادة المحاولة',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
