import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/property.dart';
import '../services/supabase_service.dart';
import 'property_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;

  // ─── Memory Cache (Instant Loading / Stale-While-Revalidate) ────────────
  static List<Map<String, dynamic>>? _cachedLeads;
  static List<Map<String, dynamic>>? _cachedCustomers;
  static List<Map<String, dynamic>>? _cachedTours;
  static List<Property>? _cachedProperties;
  static List<String>? _cachedFolders;

  late TabController _tabController;
  List<Map<String, dynamic>> _leads = _cachedLeads ?? [];
  List<Map<String, dynamic>> _customers = _cachedCustomers ?? [];
  List<Map<String, dynamic>> _tours = _cachedTours ?? [];
  List<Property> _properties = _cachedProperties ?? [];
  String _propertySearchQuery = '';
  String _propertyStatusFilter = 'الكل';
  String _propertyFolderFilter = 'الكل';
  String _propertyFinishingFilter = 'الكل';
  List<String> _customFolders = _cachedFolders ?? ['الكل'];
  bool _isLoading = _cachedProperties == null;
  bool _isRefreshing = false;
  bool _showAdvancedFilters = false;
  bool _isOffline = false;

  List<String> get _allAvailableFolders {
    final set = <String>{'الكل'};
    set.addAll(_customFolders.where((f) => f != 'الكل'));
    for (var p in _properties) {
      final fName = p.folderName.trim();
      if (fName.isNotEmpty && fName != 'عام') {
        set.add(fName);
      }
    }
    return set.toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('initialTabIndex')) {
      final index = args['initialTabIndex'] as int;
      if (index >= 0 && index < 4) {
        _tabController.animateTo(index);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    // 1. Instant Load from Persistent Cache (Stale)
    try {
      final cachedLeads = await _supabaseService.getLeads(useCacheOnly: true);
      final cachedCustomers = await _supabaseService.getCustomers(useCacheOnly: true);
      final cachedTours = await _supabaseService.getTours(useCacheOnly: true);
      final cachedProps = await _supabaseService.getProperties(staffView: true, useCacheOnly: true);

      if (mounted && cachedProps.isNotEmpty) {
        setState(() {
          _leads = cachedLeads;
          _customers = cachedCustomers;
          _tours = cachedTours;
          _properties = cachedProps;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('SWR Cache Load Error: $e');
    }

    // 2. Revalidate from Network in Background
    setState(() {
      if (_properties.isEmpty) _isLoading = true;
      _isRefreshing = true;
    });

    try {
      final leadsRes = await _supabaseService.getLeads();
      final customersRes = await _supabaseService.getCustomers();
      final toursRes = await _supabaseService.getTours();
      final propsRes = await _supabaseService.getProperties(staffView: true);
      final foldersRes = await _supabaseService.getFolders();

      // Save to static memory cache
      _cachedLeads = leadsRes;
      _cachedCustomers = customersRes;
      _cachedTours = toursRes;
      _cachedProperties = propsRes;
      _cachedFolders = foldersRes;

      if (mounted) {
        setState(() {
          _leads = leadsRes;
          _customers = customersRes;
          _tours = toursRes;
          _properties = propsRes;
          _customFolders = foldersRes;
          _isLoading = false;
          _isRefreshing = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      debugPrint('SWR Network Revalidate Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _isOffline = true;
        });
      }
    }
  }

  Future<List<String>> _uploadImages(List<PlatformFile> files) async {
    List<String> imageUrls = [];
    for (var file in files) {
      if (file.bytes == null) continue;
      final extension = file.extension ?? 'jpg';
      final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
      final path = 'property_images/$fileName';
      try {
        await _supabase.storage.from('properties').uploadBinary(
              path,
              file.bytes!,
              fileOptions: FileOptions(contentType: 'image/$extension', upsert: true),
            );
        final url = _supabase.storage.from('properties').getPublicUrl(path);
        imageUrls.add(url);
      } catch (e) {
        debugPrint('Upload Error: $e');
        rethrow;
      }
    }
    return imageUrls;
  }

  Widget _buildConnectivityBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: _isOffline ? 45 : 0,
      width: double.infinity,
      curve: Curves.easeInOut,
      color: const Color(0xFFFEE2E2), // Light red background
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 18),
              SizedBox(width: 10),
              Text(
                'تعمل حالياً في وضع الأوفلاين - سيتم التحديث عند استقرار الاتصال 📡',
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Executive Header & KPI Ribbon ─────────────────────────────────────────
  Widget _buildTopBrandingAndKPIs() {
    final hotLeads = _leads.where((l) => l['converted'] != true).length;
    final convertedLeads = _leads.where((l) => l['converted'] == true).length;
    final pendingTours =
        _tours.where((t) => t['status'] == 'scheduled').length;

    return Container(
      color: AppColors.slateDark,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Slim Modern Navbar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  const Icon(Icons.business_center_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'شركة الحمد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'نظام الإدارة المتكامل',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildHeaderIconButton(
                    icon: Icons.home_rounded,
                    tooltip: 'الرئيسية',
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderIconButton(
                    icon: Icons.analytics_outlined,
                    tooltip: 'التقارير',
                    onTap: () => Navigator.pushNamed(context, '/analytics'),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'خروج',
                    color: AppColors.danger,
                    bgColor: AppColors.danger.withOpacity(0.1),
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 700;
                  if (isDesktop) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            icon: Icons.bolt_rounded,
                            label: 'طلبات جديدة',
                            value: '$hotLeads',
                            accentColor: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            icon: Icons.groups_rounded,
                            label: 'إجمالي العملاء',
                            value: '${_customers.length}',
                            accentColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            icon: Icons.event_available_rounded,
                            label: 'معاينات قادمة',
                            value: '$pendingTours',
                            accentColor: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            icon: Icons.verified_rounded,
                            label: 'تم التحويل',
                            value: '$convertedLeads',
                            accentColor: AppColors.secondary,
                          ),
                        ),
                      ],
                    );
                  }
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _buildKpiCard(
                        icon: Icons.bolt_rounded,
                        label: 'طلبات جديدة',
                        value: '$hotLeads',
                        accentColor: AppColors.warning,
                      ),
                      _buildKpiCard(
                        icon: Icons.groups_rounded,
                        label: 'إجمالي العملاء',
                        value: '${_customers.length}',
                        accentColor: AppColors.success,
                      ),
                      _buildKpiCard(
                        icon: Icons.event_available_rounded,
                        label: 'معاينات',
                        value: '$pendingTours',
                        accentColor: AppColors.info,
                      ),
                      _buildKpiCard(
                        icon: Icons.verified_rounded,
                        label: 'تحويلات',
                        value: '$convertedLeads',
                        accentColor: AppColors.secondary,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBarSection() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slateDark,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textMuted,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'الطلبات (${_leads.length})'),
            Tab(text: 'العملاء (${_customers.length})'),
            Tab(text: 'المعاينات (${_tours.length})'),
            Tab(text: 'العقارات (${_properties.length})'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color? bgColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.2)),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: _buildConnectivityBanner(),
              ),
              SliverToBoxAdapter(
                child: _buildTopBrandingAndKPIs(),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverHeaderDelegate(
                  child: _buildTabBarSection(),
                ),
              ),
            ];
          },
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeadsTab(),
                    _buildCustomersTab(),
                    _buildToursTab(),
                    _buildPropertiesTab(),
                  ],
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPropertyDialog,
          backgroundColor: AppColors.primary,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'إضافة عقار جديد',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ─── Leads Tab ───────────────────────────────────────────────────────────────
  Widget _buildLeadsTab() {
    if (_leads.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox_rounded,
        message: 'لا توجد طلبات جديدة حالياً',
        subtitle: 'ستظهر هنا طلبات العملاء من الموقع والشات',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width > 750) {
          final crossAxisCount = width > 1200 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 350,
            ),
            itemCount: _leads.length,
            itemBuilder: (context, index) => SingleChildScrollView(
              child: _buildLeadCard(_leads[index]),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: _leads.length,
          itemBuilder: (context, index) => _buildLeadCard(_leads[index]),
        );
      },
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    final formData = lead['form_data'] as Map<String, dynamic>? ?? {};
    final sourceStr = lead['source']?.toString().toLowerCase() ?? '';
    final intentStr = formData['intent']?.toString() ?? '';
    final purposeStr = formData['purpose']?.toString() ?? '';
    final rawName = (lead['name'] ?? 'عميل جديد') as String;

    final isSellIntent = sourceStr.contains('sell') ||
        intentStr.contains('بيع') ||
        purposeStr.contains('بيع') ||
        rawName.contains('بيع') ||
        rawName.contains('عرض');

    final isChatbot = sourceStr.contains('chatbot') ||
        sourceStr.contains('ai_') ||
        sourceStr.contains('chat');
    final isConverted = lead['converted'] == true;

    final displayName = (isSellIntent && (rawName == 'عميل محتمل (الشات الذكي)' || rawName.isEmpty))
        ? 'عرض عقار للبيع 💰 (مالك)'
        : rawName;

    // Premium CRM Visual Identity Theme Colors
    final Color themePrimary;
    final Color themeBg;
    final Color themeBorder;
    final Color themeText;
    final String sourceLabel;
    final IconData sourceIcon;

    if (isSellIntent) {
      themePrimary = const Color(0xFFD97706); // Amber
      themeBg = const Color(0xFFFFFBEB);
      themeBorder = const Color(0xFFFCD34D);
      themeText = const Color(0xFF92400E);
      sourceLabel = 'مالك/عرض للبيع';
      sourceIcon = Icons.sell_rounded;
    } else if (isChatbot) {
      themePrimary = const Color(0xFF4F46E5); // Indigo / AI Theme
      themeBg = const Color(0xFFEEF2FF);
      themeBorder = const Color(0xFFC7D2FE);
      themeText = const Color(0xFF3730A3);
      sourceLabel = 'شات ذكي AI';
      sourceIcon = Icons.smart_toy_rounded;
    } else {
      themePrimary = const Color(0xFF059669); // Emerald / Website Theme
      themeBg = const Color(0xFFECFDF5);
      themeBorder = const Color(0xFFA7F3D0);
      themeText = const Color(0xFF065F46);
      sourceLabel = 'الموقع الإلكتروني';
      sourceIcon = Icons.language_rounded;
    }

    final cleanType = (formData['property_type'] ?? '').toString().replaceAll('🏢', '').trim();
    final cleanLoc = (formData['location'] ?? formData['region'] ?? '').toString().replaceAll('📍', '').replaceAll('🌐', '').trim();

    String summaryStr = '';
    if (cleanType.isNotEmpty) summaryStr += cleanType;
    if (cleanLoc.isNotEmpty) {
      if (summaryStr.isNotEmpty) summaryStr += ' • ';
      summaryStr += cleanLoc;
    }
    if (summaryStr.isEmpty) {
      summaryStr = isSellIntent ? 'عقار للبيع' : 'طلب عقار جديد';
    }

    Widget statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isConverted ? const Color(0xFFE2E8F0) : themeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConverted ? const Color(0xFFCBD5E1) : themeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConverted ? Icons.check_circle_rounded : Icons.fiber_new_rounded,
            size: 13,
            color: isConverted ? const Color(0xFF64748B) : themePrimary,
          ),
          const SizedBox(width: 4),
          Text(
            isConverted ? 'تم التحويل' : 'جديد',
            style: TextStyle(
              color: isConverted ? const Color(0xFF475569) : themeText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    Widget sourceBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sourceIcon, size: 13, color: themePrimary),
          const SizedBox(width: 4),
          Text(
            sourceLabel,
            style: TextStyle(
              color: themeText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeBorder,
          width: isSellIntent ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConverted
                    ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                    : (isSellIntent
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : (isChatbot
                            ? [const Color(0xFF6366F1), const Color(0xFF4F46E5)]
                            : [const Color(0xFF10B981), const Color(0xFF059669)])),
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                isSellIntent ? '💰' : (displayName.isNotEmpty ? displayName[0] : 'ع'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  statusBadge,
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  sourceBadge,
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(Icons.phone_rounded, size: 12, color: AppColors.textMuted),
                  Text(
                    lead['phone']?.toString() ?? 'بدون رقم',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                summaryStr,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(lead['phone'], lead['name'] ?? 'عميلنا'),
                      icon: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                      label: const Text('واتساب', style: TextStyle(fontSize: 11, color: Color(0xFF128C7E), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Color(0xFF25D366), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: const Color(0xFF25D366).withOpacity(0.05),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(lead['phone']),
                      icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.secondary),
                      label: const Text('اتصال مباشر', style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: AppColors.secondary, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: AppColors.secondary.withOpacity(0.05),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16, color: AppColors.border),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formData.isNotEmpty || isSellIntent) ...[
                  Row(
                    children: [
                      Icon(
                        isSellIntent ? Icons.real_estate_agent_rounded : Icons.person_pin_rounded,
                        size: 15,
                        color: themePrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSellIntent ? 'تفاصيل طلب عرض العقار (مالك العقار):' : 'تفاصيل اهتمام العميل:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: themePrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: themeBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: themeBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSellIntent) ...[
                          Row(
                            children: [
                              Icon(Icons.home_work_rounded, size: 15, color: themePrimary),
                              const SizedBox(width: 6),
                              Text(
                                'نوع العقار: ${formData['property_type']?.toString().replaceAll('🏢', '').trim().isEmpty ?? true ? "شقة / عقار" : formData['property_type'].toString().replaceAll('🏢', '').trim()}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeText),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 15, color: themePrimary),
                              const SizedBox(width: 6),
                              Text(
                                'الموقع / المنطقة: ${(formData['location'] ?? formData['region'] ?? '').toString().replaceAll('📍', '').replaceAll('🌐', '').trim().isEmpty ? "طنطا/القاهرة" : (formData['location'] ?? formData['region']).toString().replaceAll('📍', '').replaceAll('🌐', '').trim()}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: themeText),
                              ),
                            ],
                          ),
                        ] else if (formData['selected_property_title'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.apartment_rounded, size: 15, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'العقار المطلوب: ${formData['selected_property_title']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (formData['chat_summary'] != null && !formData['chat_summary'].toString().contains('العميل مهتم بـ')) ...[
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            isSellIntent ? Icons.task_alt_rounded : Icons.chat_bubble_outline_rounded,
                            formData['chat_summary'].toString(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final cleanLoc = (formData['location'] ?? formData['region'] ?? '')
                          .toString()
                          .replaceAll('📍', '')
                          .replaceAll('🌐', '')
                          .trim();
                      final cleanType = (formData['property_type'] ?? '')
                          .toString()
                          .replaceAll('🏢', '')
                          .trim();
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (isSellIntent)
                            _buildDetailBadge('🏷️', 'عرض للبيع (مالك)')
                          else if (formData['purpose'] != null)
                            _buildDetailBadge('🎯', formData['purpose'].toString()),
                          if (cleanType.isNotEmpty)
                            _buildDetailBadge('🏠', cleanType),
                          if (cleanLoc.isNotEmpty)
                            _buildDetailBadge('📍', cleanLoc),
                          if (formData['budget'] != null && formData['budget'].toString().isNotEmpty && !isSellIntent)
                            _buildDetailBadge('💰', '${formData['budget']}'),
                          if (formData['rooms'] != null)
                            _buildDetailBadge('🚪', '${formData['rooms']} غرف'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                if (!isConverted)
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      icon: Icons.sync_alt_rounded,
                      label: 'إضافة للعملاء',
                      color: AppColors.primary,
                      onTap: () => _showConvertLeadDialog(lead),
                    ),
                  ),

                // ─── Smart Property Matching (AI Feature) ────────────────────
                if (!isSellIntent && !isConverted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF), // Light Blue for AI
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'العقارات المقترحة للعميل (ذكاء اصطناعي) 🤖',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final budgetStr = formData['budget']?.toString() ?? '';
                            final targetBudget = _parseArabicPrice(budgetStr).toDouble();
                            final targetRooms = int.tryParse(formData['rooms']?.toString() ?? '') ?? 0;
                            
                            final matchedProperties = _properties.where((p) {
                              if (p.status == 'مباع') return false;

                              // Type Match
                              bool typeMatch = true;
                              if (cleanType.isNotEmpty) {
                                typeMatch = p.type.contains(cleanType) || cleanType.contains(p.type);
                              }

                              // Location Match
                              bool locMatch = true;
                              if (cleanLoc.isNotEmpty) {
                                locMatch = p.location.contains(cleanLoc) || 
                                          p.city.contains(cleanLoc) || 
                                          cleanLoc.contains(p.location);
                              }

                              // Budget Match (+/- 30%)
                              bool budgetMatch = true;
                              if (targetBudget > 0) {
                                final minB = targetBudget * 0.7;
                                final maxB = targetBudget * 1.3;
                                budgetMatch = p.price >= minB && p.price <= maxB;
                              }

                              return typeMatch && locMatch && budgetMatch;
                            }).toList();

                            if (matchedProperties.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'لا توجد عقارات مطابقة تماماً حالياً',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: matchedProperties.map((p) {
                                  return GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                      context, 
                                      '/property_details', 
                                      arguments: p,
                                    ),
                                    child: Container(
                                      width: 140,
                                      margin: const EdgeInsets.only(left: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            child: Image.network(
                                              p.mainImage,
                                              height: 80,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Container(
                                                height: 80,
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.home_work, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.title,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  p.formattedPrice,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87))),
      ],
    );
  }

  Widget _buildDetailBadge(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text('$emoji $label', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Customers Tab ───────────────────────────────────────────────────────────
  Widget _buildCustomersTab() {
    if (_customers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        message: 'لا يوجد عملاء مسجلون حالياً',
        subtitle: 'قم بتحويل الطلبات لعملاء دائمين من تبويب الطلبات',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width > 750) {
          final crossAxisCount = width > 1200 ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 260,
            ),
            itemCount: _customers.length,
            itemBuilder: (context, index) => _buildCustomerCard(_customers[index]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: _customers.length,
          itemBuilder: (context, index) => _buildCustomerCard(_customers[index]),
        );
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> cust) {
    final status = cust['status'] ?? 'Cold';
    final name = (cust['name'] ?? 'عميل') as String;
    final initial = name.isNotEmpty ? name[0] : 'ع';

    final statusData = {
      'Hot': {
        'color': const Color(0xFFEF4444), // Coral Red
        'bg': const Color(0xFFFEF2F2),
        'border': const Color(0xFFFCA5A5),
        'emoji': '🔥',
        'label': 'متحمس جداً'
      },
      'Warm': {
        'color': const Color(0xFFF59E0B), // Amber Yellow
        'bg': const Color(0xFFFFFBEB),
        'border': const Color(0xFFFDE68A),
        'emoji': '☀️',
        'label': 'مهتم'
      },
      'Cold': {
        'color': const Color(0xFF64748B), // Slate Gray
        'bg': const Color(0xFFF8FAFC),
        'border': const Color(0xFFE2E8F0),
        'emoji': '❄️',
        'label': 'متابعة عادية'
      },
    };
    final sd = statusData[status] ?? statusData['Cold']!;
    final Color themeColor = sd['color'] as Color;
    final Color themeBg = sd['bg'] as Color;
    final Color themeBorder = sd['border'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          ...AppColors.cardShadow,
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Name + Interest Badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor.withOpacity(0.8), themeColor],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: themeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: themeBorder.withOpacity(0.5)),
                        ),
                        child: Text(
                          '${sd['emoji']} ${sd['label']}',
                          style: TextStyle(
                            color: themeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),
            
            // Contact Info
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  cust['phone']?.toString() ?? 'بدون رقم',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Latest Notes
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (cust['notes'] != null && cust['notes'].toString().isNotEmpty)
                          ? cust['notes'].toString()
                          : 'لا توجد ملاحظات مسجلة للعميل حتى الآن...',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Actions Bar
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(cust['phone'], cust['name']),
                      icon: const Icon(Icons.chat_rounded, size: 14, color: Color(0xFF25D366)),
                      label: const Text(
                        'واتساب',
                        style: TextStyle(fontSize: 11, color: Color(0xFF128C7E), fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Color(0xFF25D366), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: const Color(0xFF25D366).withOpacity(0.05),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _makePhoneCall(cust['phone']),
                      icon: const Icon(Icons.phone_rounded, size: 14, color: AppColors.secondary),
                      label: const Text(
                        'اتصال',
                        style: TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: AppColors.secondary, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: AppColors.secondary.withOpacity(0.05),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditCustomerNotesDialog(cust),
                      icon: const Icon(Icons.edit_note_rounded, size: 14, color: Colors.white),
                      label: const Text(
                        'ملاحظات',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ─── Tours Tab ───────────────────────────────────────────────────────────────
  Widget _buildToursTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 750;
        final isWide = constraints.maxWidth > 1200;
        final crossAxisCount = isWide ? 3 : (isDesktop ? 2 : 1);

        return Column(
          children: [
            // Professional CRM Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إدارة المعاينات الميدانية',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'تتبع وجدولة زيارات العملاء للعقارات المتاحة',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddTourDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('جدولة معاينة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: _tours.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.event_available_rounded,
                      message: 'لا توجد معاينات مجدولة حالياً',
                      subtitle: 'ابدأ بجدولة معاينة جديدة لربط العملاء بالعقارات',
                    )
                  : isDesktop
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            mainAxisExtent: 230,
                          ),
                          itemCount: _tours.length,
                          itemBuilder: (context, index) =>
                              _buildTourCard(_tours[index]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _tours.length,
                          itemBuilder: (context, index) =>
                              _buildTourCard(_tours[index]),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTourCard(Map<String, dynamic> tour) {
    final property = tour['properties'] as Map<String, dynamic>? ?? {};
    final customer = tour['customers'] as Map<String, dynamic>? ?? {};
    final status = tour['status']?.toString() ?? 'scheduled';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';
    final isScheduled = status == 'scheduled';

    Color themeColor;
    Color bgColor;
    String statusText;
    IconData statusIcon;

    if (isCompleted) {
      themeColor = AppColors.success;
      bgColor = AppColors.successBg;
      statusText = 'مكتملة';
      statusIcon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      themeColor = AppColors.danger;
      bgColor = AppColors.dangerBg;
      statusText = 'ملغاة';
      statusIcon = Icons.cancel_rounded;
    } else {
      themeColor = AppColors.primary;
      bgColor = AppColors.primaryLight;
      statusText = 'مجدولة';
      statusIcon = Icons.calendar_today_rounded;
    }

    final DateTime? scheduledDate =
        DateTime.tryParse(tour['scheduled_date']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.8)),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showTourDetailsDialog(tour),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Date Badge
                      _buildDateBadge(scheduledDate, themeColor),
                      const SizedBox(width: 16),
                      // Info Section
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'معاينة: ${property['title'] ?? 'عقار غير محدد'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: themeColor.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(statusIcon,
                                          size: 10, color: themeColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: themeColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    customer['name'] ?? 'عميل غير معروف',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone_iphone_rounded,
                                    size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  customer['phone'] ?? 'بدون هاتف',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (scheduledDate != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${scheduledDate.hour.toString().padLeft(2, '0')}:${scheduledDate.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Quick Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: AppColors.surfaceSubtle.withOpacity(0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (isScheduled)
                    _buildTourQuickAction(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'إتمام ✅',
                      color: AppColors.success,
                      onTap: () async {
                        await _supabaseService.updateTourDetails(
                          tourId: tour['id'].toString(),
                          status: 'completed',
                        );
                        _loadDashboardData();
                      },
                    ),
                  _buildTourQuickAction(
                    icon: Icons.chat_outlined,
                    label: 'واتساب 📱',
                    color: const Color(0xFF25D366),
                    onTap: () => _openWhatsApp(
                        customer['phone'] ?? '', customer['name'] ?? 'عميل'),
                  ),
                  _buildTourQuickAction(
                    icon: Icons.info_outline_rounded,
                    label: 'التفاصيل 📝',
                    color: AppColors.primary,
                    onTap: () => _showTourDetailsDialog(tour),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(DateTime? date, Color color) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    return Container(
      width: 65,
      height: 75,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date != null ? date.day.toString() : '--',
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          Text(
            date != null ? months[date.month - 1] : '----',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTourQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTourDetailsDialog(Map<String, dynamic> tour) {
    final property = tour['properties'] as Map<String, dynamic>? ?? {};
    final customer = tour['customers'] as Map<String, dynamic>? ?? {};
    final status = tour['status']?.toString() ?? 'scheduled';
    final notesController =
        TextEditingController(text: tour['notes']?.toString() ?? '');
    final feedbackController =
        TextEditingController(text: tour['next_steps']?.toString() ?? '');

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: MediaQuery.of(context).size.width > 700 ? 520 : MediaQuery.of(context).size.width * 0.95,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تفاصيل المعاينة المجدولة 📅',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              Text(
                                'معرف المعاينة: #${tour['id']}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status & Scheduled Date Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاريخ المعاينة:',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.event_rounded,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      tour['scheduled_date']?.toString() ??
                                          'غير محدد',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: status == 'completed'
                                  ? AppColors.successBg
                                  : (status == 'cancelled'
                                      ? AppColors.dangerBg
                                      : AppColors.warningBg),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: status == 'completed'
                                    ? AppColors.success.withOpacity(0.3)
                                    : (status == 'cancelled'
                                        ? AppColors.danger.withOpacity(0.3)
                                        : AppColors.warning.withOpacity(0.3)),
                              ),
                            ),
                            child: Text(
                              status == 'completed'
                                  ? '✅ مكتملة'
                                  : (status == 'cancelled'
                                      ? '❌ ملغاة'
                                      : '📅 مجدولة'),
                              style: TextStyle(
                                color: status == 'completed'
                                    ? AppColors.success
                                    : (status == 'cancelled'
                                        ? AppColors.danger
                                        : AppColors.warning),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Property Details Section
                    const Text('تفاصيل العقار المطلوب:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.home_rounded,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property['title'] ?? 'عقار غير مسمى',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '📍 ${property['location'] ?? ''}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Customer Details Section
                    const Text('بيانات العميل:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_rounded,
                                color: AppColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer['name'] ?? 'عميل غير مسجل',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '📞 ${customer['phone'] ?? ''}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_rounded,
                                    color: Color(0xFF25D366)),
                                tooltip: 'مراسلة واتساب',
                                onPressed: () => _openWhatsApp(
                                    customer['phone'], customer['name']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone_rounded,
                                    color: AppColors.primary),
                                tooltip: 'اتصال هاتفي',
                                onPressed: () =>
                                    _makePhoneCall(customer['phone']),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes & Outcome Input
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات المعاينة الأولية',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      decoration: const InputDecoration(
                        labelText: 'نتيجة المعاينة وتغذية العميل الراجعة 📝',
                        hintText: 'مثال: العميل أبدى رغبته بالشراء وطلب كراسة الشروط...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Actions Row
                    Row(
                      children: [
                        if (status == 'scheduled') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: const Text('إتمام المعاينة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      await _supabaseService.updateTourDetails(
                                        tourId: tour['id'].toString(),
                                        status: 'completed',
                                        notes: notesController.text.trim(),
                                        nextSteps: feedbackController.text.trim(),
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                        _loadDashboardData();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined,
                                  size: 18, color: AppColors.danger),
                              label: const Text('إلغاء المعاينة',
                                  style: TextStyle(color: AppColors.danger)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.danger),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      await _supabaseService.updateTourDetails(
                                        tourId: tour['id'].toString(),
                                        status: 'cancelled',
                                        notes: notesController.text.trim(),
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                        _loadDashboardData();
                                      }
                                    },
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      await _supabaseService.updateTourDetails(
                                        tourId: tour['id'].toString(),
                                        notes: notesController.text.trim(),
                                        nextSteps: feedbackController.text.trim(),
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                        _loadDashboardData();
                                      }
                                    },
                              child: const Text('حفظ التعديلات والملاحظات'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTourDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    Property? selectedProperty = _properties.isNotEmpty ? _properties.first : null;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.add_task_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('جدولة معاينة جديدة 📅',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 700 ? 480 : MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Property>(
                      value: selectedProperty,
                      items: _properties
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.title,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setModalState(() => selectedProperty = v),
                      decoration: const InputDecoration(labelText: 'اختر العقار المعني'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم العميل الكامل'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'رقم هاتف العميل'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text('تاريخ المعاينة:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات المعاينة (اختياري)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: (isSaving || selectedProperty == null)
                    ? null
                    : () async {
                        if (nameController.text.isEmpty ||
                            phoneController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('من فضلك ادخل اسم العميل ورقم الهاتف'),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                          return;
                        }
                        setModalState(() => isSaving = true);
                        try {
                          await _supabaseService.requestTour(
                            propertyId: selectedProperty!.id,
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            date: selectedDate,
                            notes: notesController.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم جدولة المعاينة بنجاح ✅'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            _loadDashboardData();
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('جدولة المعاينة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 52, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Convert Lead Dialog ─────────────────────────────────────────────────────
  void _showConvertLeadDialog(Map<String, dynamic> lead) {
    final formData = lead['form_data'] as Map<String, dynamic>? ?? {};
    final sourceStr = lead['source']?.toString().toLowerCase() ?? '';
    final intentStr = formData['intent']?.toString() ?? '';
    final purposeStr = formData['purpose']?.toString() ?? '';
    final rawName = (lead['name'] ?? 'عميل جديد') as String;

    final isSellIntent = sourceStr.contains('sell') ||
        intentStr.contains('بيع') ||
        purposeStr.contains('بيع') ||
        rawName.contains('بيع') ||
        rawName.contains('عرض');

    final displayName = (isSellIntent && (rawName == 'عميل محتمل (الشات الذكي)' || rawName.isEmpty))
        ? 'عرض عقار للبيع 💰 (مالك)'
        : rawName;

    String initialNotes = formData['chat_summary']?.toString() ?? 'عميل مهتم بعقارات طنطا والقاهرة';
    if (isSellIntent && (initialNotes.contains('العميل مهتم بـ') || initialNotes.isEmpty)) {
      initialNotes = 'يرغب العميل في عرض عقاره للبيع والتسويق عبر الشركة - يطلب التواصل للتنسيق للمعاينة والتصوير المجاني 📸';
    }

    final notesController = TextEditingController(text: initialNotes);
    String selectedStatus = 'Hot';
    bool isConverting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 700 ? 480 : MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sync_alt_rounded,
                          color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إضافة لقاعدة العملاء',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('سيتم إضافة العميل لقاعدة البيانات الدائمة',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogInfo(
                          Icons.person_rounded,
                          displayName),
                      const SizedBox(height: 6),
                      _buildDialogInfo(
                          Icons.phone_rounded, lead['phone']?.toString() ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('تصنيف العميل:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatusChoice(
                        '🔥 متحمس', 'Hot', Colors.red, selectedStatus,
                        () => setModalState(() => selectedStatus = 'Hot')),
                    const SizedBox(width: 8),
                    _buildStatusChoice(
                        '☀️ مهتم', 'Warm', Colors.orange, selectedStatus,
                        () => setModalState(() => selectedStatus = 'Warm')),
                    const SizedBox(width: 8),
                    _buildStatusChoice(
                        '❄️ بارد', 'Cold', Colors.blueGrey, selectedStatus,
                        () => setModalState(() => selectedStatus = 'Cold')),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات المتابعة',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isConverting
                            ? null
                            : () async {
                                setModalState(() => isConverting = true);
                                try {
                                  await _supabaseService.convertLeadToCustomer(
                                    leadId: lead['id'].toString(),
                                    name: displayName,
                                    phone: lead['phone'].toString(),
                                    status: selectedStatus,
                                    notes: notesController.text.trim(),
                                    formData: formData,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'تمت إضافة العميل لقائمة العملاء بنجاح ✅'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                    _loadDashboardData();
                                  }
                                } catch (e) {
                                  setModalState(() => isConverting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('خطأ: $e'),
                                            backgroundColor: AppColors.danger));
                                  }
                                }
                              },
                        child: isConverting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('حفظ وتحويل',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatusChoice(String label, String value, Color color,
      String selected, VoidCallback onTap) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFolderDialog() {
    final folderController = TextEditingController();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.create_new_folder_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('إضافة فولدر / منطقة جديدة 📁', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: TextField(
              controller: folderController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'اسم الفولدر (مثلاً: طنطا - شارع النحاس)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = folderController.text.trim();
                        if (name.isNotEmpty) {
                          setModalState(() => isSaving = true);
                          await _supabaseService.addFolder(name);
                          if (!_customFolders.contains(name)) {
                            _customFolders.add(name);
                          }
                          setState(() {
                            _propertyFolderFilter = name;
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم إنشاء فولدر "$name" بنجاح 📁'), backgroundColor: AppColors.success),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إنشاء الفولدر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add Property Dialog ─────────────────────────────────────────────────────
  void _showAddPropertyDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final priceController = TextEditingController();
    final areaController = TextEditingController();
    final descController = TextEditingController();
    final videoUrlController = TextEditingController();
    final roomsController = TextEditingController(text: '3');
    final bathroomsController = TextEditingController(text: '2');
    final floorController = TextEditingController(text: '2');
    final yearController =
        TextEditingController(text: DateTime.now().year.toString());
    final roiController = TextEditingController(text: '0');

    bool isSaving = false;
    List<PlatformFile> selectedFiles = [];
    String purpose = 'بيع';
    String status = 'متاح';
    String type = 'شقة';
    String finishing = AppStrings.finishingTypes.first;
    String folderName = _allAvailableFolders.firstWhere((f) => f != 'الكل', orElse: () => 'عام');
    bool isFeatured = true;
    List<String> selectedAmenities = ['مصعد', 'أمن 24/7'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDesktop = MediaQuery.of(context).size.width > 900;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_home_rounded,
                      color: AppColors.secondary, size: isDesktop ? 24 : 20),
                ),
                const SizedBox(width: 12),
                Text('إضافة عقار جديد 🏢',
                    style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: isDesktop ? 800 : MediaQuery.of(context).size.width * 0.95,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    const Text('الغرض:'),
                                    const SizedBox(width: 12),
                                    ChoiceChip(
                                      label: const Text('بيع'),
                                      selected: purpose == 'بيع',
                                      onSelected: (val) =>
                                          setDialogState(() => purpose = 'بيع'),
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: const Text('إيجار'),
                                      selected: purpose == 'إيجار',
                                      onSelected: (val) =>
                                          setDialogState(() => purpose = 'إيجار'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: status,
                                items: AppStrings.propertyStatuses
                                    .map((s) =>
                                        DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => status = v!),
                                decoration: InputDecoration(
                                    labelText: 'حالة العقار',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Text('الغرض:'),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Text('بيع'),
                                selected: purpose == 'بيع',
                                onSelected: (val) =>
                                    setDialogState(() => purpose = 'بيع'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text('إيجار'),
                                selected: purpose == 'إيجار',
                                onSelected: (val) =>
                                    setDialogState(() => purpose = 'إيجار'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: AppStrings.propertyStatuses
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => status = v!),
                          decoration: InputDecoration(
                              labelText: 'حالة العقار',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10))),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: finishing,
                                decoration: InputDecoration(
                                  labelText: 'مستوى التشطيب ✨',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: AppStrings.finishingTypes
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => finishing = val!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _allAvailableFolders.contains(folderName) ? folderName : (_allAvailableFolders.where((f) => f != 'الكل').firstOrNull ?? 'عام'),
                                decoration: InputDecoration(
                                  labelText: 'الفولدر / المنطقة 📁',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                items: _allAvailableFolders.where((f) => f != 'الكل')
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => folderName = val!),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          value: finishing,
                          decoration: InputDecoration(
                            labelText: 'مستوى التشطيب ✨',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: AppStrings.finishingTypes
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) => setDialogState(() => finishing = val!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _allAvailableFolders.contains(folderName) ? folderName : (_allAvailableFolders.where((f) => f != 'الكل').firstOrNull ?? 'عام'),
                          decoration: InputDecoration(
                            labelText: 'الفولدر / المنطقة 📁',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _allAvailableFolders.where((f) => f != 'الكل')
                              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                              .toList(),
                          onChanged: (val) => setDialogState(() => folderName = val!),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: titleController,
                        decoration: InputDecoration(
                            labelText: 'عنوان الإعلان (مطلوب)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                      ),
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: locationController,
                                decoration: InputDecoration(
                                    labelText: 'الموقع والحي 📍',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                validator: (v) =>
                                    v!.isEmpty ? 'يرجى إدخال الموقع' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: type,
                                items: AppStrings.propertyTypes
                                    .map((t) =>
                                        DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => type = v!),
                                decoration: InputDecoration(
                                    labelText: 'النوع',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        TextFormField(
                          controller: locationController,
                          decoration: InputDecoration(
                              labelText: 'الموقع والحي 📍',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          validator: (v) =>
                              v!.isEmpty ? 'يرجى إدخال الموقع' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: type,
                          items: AppStrings.propertyTypes
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => type = v!),
                          decoration: InputDecoration(
                              labelText: 'النوع',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10))),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                                child: TextFormField(
                                    controller: priceController,
                                    decoration: InputDecoration(
                                        labelText: purpose == 'بيع'
                                            ? 'سعر البيع (ج.م)'
                                            : 'الإيجار الشهري (ج.م)',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: TextFormField(
                                    controller: areaController,
                                    decoration: InputDecoration(
                                        labelText: 'المساحة (م²)',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    keyboardType: TextInputType.number)),
                          ],
                        )
                      else ...[
                        TextFormField(
                            controller: priceController,
                            decoration: InputDecoration(
                                labelText: purpose == 'بيع'
                                    ? 'سعر البيع (ج.م)'
                                    : 'الإيجار الشهري (ج.م)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: areaController,
                            decoration: InputDecoration(
                                labelText: 'المساحة (م²)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            keyboardType: TextInputType.number),
                      ],
                      const SizedBox(height: 16),
                      if (type != 'أرض')
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                  child: TextFormField(
                                      controller: roomsController,
                                      decoration: InputDecoration(
                                          labelText: 'الغرف',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      keyboardType: TextInputType.number)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TextFormField(
                                      controller: bathroomsController,
                                      decoration: InputDecoration(
                                          labelText: 'الحمامات',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      keyboardType: TextInputType.number)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TextFormField(
                                      controller: floorController,
                                      decoration: InputDecoration(
                                          labelText: 'الدور',
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      keyboardType: TextInputType.number)),
                            ],
                          )
                        else ...[
                          TextFormField(
                              controller: roomsController,
                              decoration: InputDecoration(
                                  labelText: 'الغرف',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: bathroomsController,
                              decoration: InputDecoration(
                                  labelText: 'الحمامات',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: floorController,
                              decoration: InputDecoration(
                                  labelText: 'الدور',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              keyboardType: TextInputType.number),
                        ],
                      const SizedBox(height: 16),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(
                                child: TextFormField(
                                    controller: roiController,
                                    decoration: InputDecoration(
                                        labelText: 'العائد ROI %',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: TextFormField(
                                    controller: yearController,
                                    decoration: InputDecoration(
                                        labelText: 'سنة البناء',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    keyboardType: TextInputType.number)),
                          ],
                        )
                      else ...[
                        TextFormField(
                            controller: roiController,
                            decoration: InputDecoration(
                                labelText: 'العائد ROI %',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: yearController,
                            decoration: InputDecoration(
                                labelText: 'سنة البناء',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            keyboardType: TextInputType.number),
                      ],
                    const SizedBox(height: 16),
                    const Align(
                        alignment: Alignment.centerRight,
                        child: Text('المرافق والخدمات:',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: AppStrings.availableAmenities.map((amenity) {
                        final isSelected = selectedAmenities.contains(amenity);
                        return FilterChip(
                          label: Text(amenity, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withOpacity(0.15),
                          checkmarkColor: AppColors.primary,
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                selectedAmenities.add(amenity);
                              } else {
                                selectedAmenities.remove(amenity);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: descController,
                        decoration: InputDecoration(
                            labelText: 'وصف إضافي للعقار',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                        maxLines: 2),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: videoUrlController,
                        decoration: InputDecoration(
                            labelText: 'رابط فيديو المعاينة (YouTube / Vimeo / رابط مباشر) 🎥',
                            hintText: 'https://www.youtube.com/watch?v=...',
                            prefixIcon: const Icon(Icons.video_library_rounded, color: AppColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('صور العقار 📸',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (selectedFiles.isNotEmpty)
                            Wrap(
                                spacing: 8,
                                children: selectedFiles
                                    .map((f) => Chip(
                                        label: Text(f.name),
                                        onDeleted: () => setDialogState(
                                            () => selectedFiles.remove(f))))
                                    .toList()),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: true,
                                  withData: true);
                              if (result != null) {
                                setDialogState(
                                    () => selectedFiles.addAll(result.files));
                              }
                            },
                            icon: const Icon(Icons.add_a_photo_rounded),
                            label: const Text('اختيار صور'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withOpacity(0.08),
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                        title: const Text('تمييز العقار في الصفحة الرئيسية'),
                        value: isFeatured,
                        activeColor: AppColors.primary,
                        onChanged: (v) =>
                            setDialogState(() => isFeatured = v!)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (isSaving)
              const CircularProgressIndicator()
            else ...[
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isSaving = true);
                    try {
                      List<String> imageUrls = [];
                      if (selectedFiles.isNotEmpty) {
                        imageUrls = await _uploadImages(selectedFiles);
                      }
                      await _supabase.from('properties').insert({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'price': _parseArabicPrice(priceController.text),
                        'area': _parseArabicArea(areaController.text),
                        'location': locationController.text.trim(),
                        'type': type,
                        'status': status,
                        'bedrooms': int.tryParse(roomsController.text) ?? 0,
                        'bathrooms':
                            int.tryParse(bathroomsController.text) ?? 0,
                        'floor': int.tryParse(floorController.text) ?? 0,
                        'build_year':
                            int.tryParse(yearController.text) ??
                                DateTime.now().year,
                        'roi': double.tryParse(roiController.text) ?? 0.0,
                        'purpose': purpose,
                        'amenities': selectedAmenities,
                        'images': imageUrls,
                        'finishing': finishing,
                        'folder_name': folderName,
                        'is_featured': isFeatured,
                        'video_url': videoUrlController.text.trim(),
                        'created_at': DateTime.now().toIso8601String(),
                      });
                      if (folderName.isNotEmpty && folderName != 'عام') {
                        await _supabaseService.addFolder(folderName);
                        if (!_customFolders.contains(folderName)) {
                          _customFolders.add(folderName);
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نشر العقار بنجاح ✅'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        _loadDashboardData();
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('خطأ: $e'),
                            backgroundColor: AppColors.danger,
                            duration: const Duration(seconds: 5)));
                      }
                    }
                  }
                },
                child: const Text('حفظ ونشر العقار',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      },
    ),
  );
}

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  int _parseArabicPrice(String input) {
    if (input.trim().isEmpty) return 0;

    String text = input.trim();
    // Convert Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩) to ASCII (0123456789)
    const easternDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(easternDigits[i], westernDigits[i]);
    }

    text = text.replaceAll('،', '.').toLowerCase();

    // Direct clean number check e.g. "3000000" or "3,000,000"
    String cleanDigitsOnly = text.replaceAll(',', '').replaceAll(' ', '');
    final directVal = int.tryParse(cleanDigitsOnly) ?? double.tryParse(cleanDigitsOnly)?.round();
    if (directVal != null) return directVal;

    double multiplier = 1;
    if (text.contains('مليون') || text.contains('ملايين') || text.contains('مليونين') || text.contains('مليونان')) {
      multiplier = 1000000;
    } else if (text.contains('ألف') || text.contains('الف') || text.contains('آلاف') || text.contains('الاف') || text.contains('ك') || text.contains('k')) {
      multiplier = 1000;
    }

    final regExp = RegExp(r'(\d+(?:\.\d+)?)');
    final match = regExp.firstMatch(text.replaceAll(',', '.'));

    double baseValue = 0;
    if (match != null) {
      baseValue = double.tryParse(match.group(1)!) ?? 0;
    } else {
      if (text.contains('مليونين') || text.contains('مليونان')) {
        baseValue = 2;
      } else if (text.contains('مليون')) {
        baseValue = 1;
      } else if (text.contains('نص') || text.contains('نصف')) {
        baseValue = 0.5;
      } else if (text.contains('ربع')) {
        baseValue = 0.25;
      }
    }

    if (text.contains('ونص') || text.contains('و نص') || text.contains('ونصف') || text.contains('و نصف')) {
      baseValue += 0.5;
    } else if (text.contains('وربع') || text.contains('و ربع')) {
      baseValue += 0.25;
    } else if (text.contains('وثلاث أرباع') || text.contains('و ثلاث ارباع')) {
      baseValue += 0.75;
    }

    if (multiplier == 1 && baseValue > 0 && !text.contains('الف') && !text.contains('ألف')) {
      if (text.contains('م') || text.contains('مليون')) {
        multiplier = 1000000;
      }
    }

    return (baseValue * multiplier).round();
  }

  int _parseArabicArea(String input) {
    if (input.trim().isEmpty) return 0;
    String text = input.trim();
    const easternDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < 10; i++) {
      text = text.replaceAll(easternDigits[i], westernDigits[i]);
    }
    final regExp = RegExp(r'(\d+(?:\.\d+)?)');
    final match = regExp.firstMatch(text.replaceAll(',', '.'));
    if (match != null) {
      return (double.tryParse(match.group(1)!) ?? 0).round();
    }
    return 0;
  }

  // ─── Properties Tab ─────────────────────────────────────────────────────────
  Widget _buildPropertiesTab() {
    List<Property> filteredProps = _properties.where((p) {
      final matchesQuery = _propertySearchQuery.isEmpty ||
          p.title.contains(_propertySearchQuery) ||
          p.location.contains(_propertySearchQuery) ||
          p.city.contains(_propertySearchQuery);

      final matchesStatus = _propertyStatusFilter == 'الكل' ||
          p.status == _propertyStatusFilter;

      final matchesFinishing = _propertyFinishingFilter == 'الكل' ||
          p.finishing.contains(_propertyFinishingFilter);

      final matchesFolder = _propertyFolderFilter == 'الكل' ||
          p.folderName.trim() == _propertyFolderFilter.trim() ||
          p.folderName.contains(_propertyFolderFilter) ||
          p.location.contains(_propertyFolderFilter) ||
          p.city.contains(_propertyFolderFilter);

      return matchesQuery && matchesStatus && matchesFinishing && matchesFolder;
    }).toList();

    return Column(
      children: [
        // Search and Multi-Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search input with Toggle Button Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _propertySearchQuery = val),
                        decoration: InputDecoration(
                          hintText: MediaQuery.of(context).size.width > 600 ? 'ابحث باسم العقار، المنطقة، المالك، أو الكود...' : 'بحث عن عقار...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          filled: true,
                          fillColor: AppColors.surfaceSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.border.withOpacity(0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
                      icon: Icon(
                        _showAdvancedFilters ? Icons.filter_list_off_rounded : Icons.filter_list_rounded,
                        size: 18,
                        color: _showAdvancedFilters ? Colors.white : AppColors.primary,
                      ),
                      label: MediaQuery.of(context).size.width > 700 
                          ? Text(
                              _showAdvancedFilters ? 'فلاتر متقدمة ▴' : 'فلاتر متقدمة ▾',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _showAdvancedFilters ? Colors.white : AppColors.primary,
                              ),
                            )
                          : const SizedBox.shrink(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showAdvancedFilters ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                        foregroundColor: _showAdvancedFilters ? Colors.white : AppColors.primary,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width > 700 ? 16 : 12,
                          vertical: 14
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_showAdvancedFilters) ...[
                  const SizedBox(height: 16),

                  // Filter Row 1: Folders & Areas
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.folder_special_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('الفولدرات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._allAvailableFolders.map((fld) {
                                final isSel = _propertyFolderFilter == fld;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    selected: isSel,
                                    label: Text(fld),
                                    selectedColor: AppColors.primary,
                                    backgroundColor: AppColors.surfaceSubtle,
                                    labelStyle: TextStyle(
                                      color: isSel ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    onSelected: (_) => setState(() => _propertyFolderFilter = fld),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: isSel ? AppColors.primary : AppColors.border,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: _showAddFolderDialog,
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.add_rounded, size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('+ فولدر جديد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Row 2: Finishing Categories
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.home_repair_service_rounded, size: 14, color: AppColors.secondary),
                            SizedBox(width: 4),
                            Text('التشطيب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.secondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['الكل', ...AppStrings.finishingTypes].map((fin) {
                              final isSel = _propertyFinishingFilter == fin;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  selected: isSel,
                                  label: Text(fin),
                                  selectedColor: AppColors.secondary,
                                  backgroundColor: AppColors.surfaceSubtle,
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : AppColors.textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => setState(() => _propertyFinishingFilter = fin),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: isSel ? AppColors.secondary : AppColors.border,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Row 3: Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.slateDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.sell_rounded, size: 14, color: AppColors.slateDark),
                            SizedBox(width: 4),
                            Text('المعاملة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slateDark)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['الكل', 'متاح', 'محجوز', 'مباع', 'مؤجر'].map((st) {
                              final isSel = _propertyStatusFilter == st;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  selected: isSel,
                                  label: Text(st),
                                  selectedColor: AppColors.slateDark,
                                  backgroundColor: AppColors.surfaceSubtle,
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : AppColors.textSecondary,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => setState(() => _propertyStatusFilter = st),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(
                                      color: isSel ? AppColors.slateDark : AppColors.border,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // Properties list or grid based on LayoutBuilder responsive view
        Expanded(
          child: filteredProps.isEmpty
              ? _buildEmptyState(
                  icon: Icons.home_work_outlined,
                  message: 'لا توجد عقارات تطابق البحث والفلترة',
                  subtitle: 'جرب تغيير الفولدر، فئة التشطيب، أو خيارات البحث',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 750;
                    if (isDesktop) {
                      final crossAxisCount = constraints.maxWidth > 1200 ? 3 : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        itemCount: filteredProps.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisExtent: 440, // Increased from 400 to 440 to prevent overflow with archive banner
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) =>
                            _buildAdminPropertyCard(filteredProps[index], isGrid: true),
                      );
                    } else {
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        itemCount: filteredProps.length,
                        itemBuilder: (context, index) =>
                            _buildAdminPropertyCard(filteredProps[index], isGrid: false),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAdminPropertyCard(Property prop, {bool isGrid = false}) {
    Color statusColor;
    Color statusBg;
    switch (prop.status) {
      case 'متاح':
        statusColor = AppColors.success;
        statusBg = AppColors.successBg;
        break;
      case 'محجوز':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningBg;
        break;
      case 'مباع':
        statusColor = AppColors.danger;
        statusBg = AppColors.dangerBg;
        break;
      case 'مؤجر':
        statusColor = AppColors.info;
        statusBg = AppColors.infoBg;
        break;
      default:
        statusColor = AppColors.textMuted;
        statusBg = AppColors.surfaceSubtle;
    }

    final isSold = prop.status == 'مباع';
    final cardBg = isSold ? const Color(0xFFF1F5F9) : AppColors.surface;
    final cardBorderColor = isSold ? const Color(0xFFCBD5E1) : AppColors.border;

    if (isGrid) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: isSold ? 1.5 : 1.0),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap the main clickable area in Material + InkWell
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/property_details',
                      arguments: prop),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image with stacked badges
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(15)),
                            child: Image.network(
                              prop.mainImage,
                              height: 210,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 210,
                                color: AppColors.surfaceSubtle,
                                child: const Center(
                                  child: Icon(Icons.business_rounded,
                                      color: AppColors.textMuted, size: 40),
                                ),
                              ),
                            ),
                          ),
                          // Status badge overlay top-right
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusBg.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: Text(
                                prop.status,
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                          // Folder / area badge overlay top-left
                          if (prop.folderName.isNotEmpty &&
                              prop.folderName != 'عام')
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.slateDark.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_rounded,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      prop.folderName,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prop.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      prop.location,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),

                              // Metrics & Price Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    prop.formattedPrice,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 15),
                                  ),
                                  Text(
                                    prop.formattedArea,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Specific Metrics row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildMetricBadge(
                                        Icons.king_bed_rounded,
                                        '${prop.bedrooms} غرف'),
                                    const SizedBox(width: 6),
                                    _buildMetricBadge(Icons.bathtub_rounded,
                                        '${prop.bathrooms} حمام'),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        prop.finishing,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isSold)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          color: const Color(0xFFE2E8F0),
                          child: const Row(
                            children: [
                              Icon(Icons.archive_rounded,
                                  size: 14, color: Color(0xFF64748B)),
                              SizedBox(width: 6),
                              Text(
                                'أرشيف داخلي مخفي تلقائياً عن العملاء',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.borderLight),
            _buildCardActionsBar(prop),
          ],
        ),
      );
    }

    // List view (mobile layout)
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: isSold ? 1.5 : 1.0),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/property_details',
                  arguments: prop),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            prop.mainImage,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 90,
                              height: 90,
                              color: AppColors.surfaceSubtle,
                              child: const Icon(Icons.business_rounded,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        if (isSold)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.archive_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  prop.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: statusColor.withOpacity(0.2)),
                                ),
                                child: Text(
                                  prop.status,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  prop.location,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (prop.folderName.isNotEmpty &&
                                  prop.folderName != 'عام') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.slateDark.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('📁 ${prop.folderName}',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.slateDark,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                prop.formattedPrice,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 14),
                              ),
                              Text('📐 ${prop.formattedArea}',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              _buildMetricBadge(
                                  Icons.king_bed_rounded, '${prop.bedrooms} غرف',
                                  compact: true),
                              _buildMetricBadge(
                                  Icons.bathtub_rounded, '${prop.bathrooms} حمام',
                                  compact: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSold)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFFE2E8F0),
              child: const Row(
                children: [
                  Icon(Icons.visibility_off_rounded,
                      size: 13, color: Color(0xFF475569)),
                  SizedBox(width: 6),
                  Text(
                    'مخفي عن العملاء والشات تلقائياً • أرشيف داخلي فقط',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.borderLight),
          _buildCardActionsBar(prop),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(IconData icon, String label, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: compact ? 10 : 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCardActionsBar(Property prop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'تغيير حالة العقار',
            onSelected: (newStatus) async {
              final ok = await _supabaseService.updatePropertyStatus(prop.id, newStatus);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم تغيير حالة العقار إلى $newStatus ✅'), backgroundColor: AppColors.success),
                );
                _loadDashboardData();
              }
            },
            itemBuilder: (context) => ['متاح', 'محجوز', 'مباع', 'مؤجر']
                .map((s) => PopupMenuItem(value: s, child: Text('حالة: $s')))
                .toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.label_outline_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('الحالة ▾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'تعديل العقار',
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            onPressed: () => _showEditPropertyDialog(prop),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'مشاركة على واتساب',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 20),
            onPressed: () => _sharePropertyWhatsApp(prop),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'حذف العقار',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            onPressed: () => _showDeletePropertyDialog(prop),
          ),
        ],
      ),
    );
  }

  void _showEditPropertyDialog(Property prop) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: prop.title);
    final locationController = TextEditingController(text: prop.location);
    final priceController = TextEditingController(text: prop.price.toInt().toString());
    final areaController = TextEditingController(text: prop.area.toInt().toString());
    final descController = TextEditingController(text: prop.description);
    final videoUrlController = TextEditingController(text: prop.videoUrl);
    final roomsController = TextEditingController(text: prop.bedrooms.toString());
    final bathroomsController = TextEditingController(text: prop.bathrooms.toString());
    final floorController = TextEditingController(text: prop.floor.toString());
    final yearController = TextEditingController(text: prop.buildYear.toString());
    final roiController = TextEditingController(text: prop.roi.toString());

    bool isSaving = false;
    String purpose = prop.isForInvestment ? 'استثمار' : 'بيع';
    String status = prop.status;
    String type = prop.type;
    String finishing = prop.finishing;
    String folderName = prop.folderName.isNotEmpty ? prop.folderName : (_customFolders.contains(prop.location) ? prop.location : 'عام');
    bool isFeatured = prop.isFeatured;
    List<String> selectedAmenities = List<String>.from(prop.amenities);
    List<String> currentImages = List<String>.from(prop.images);
    List<PlatformFile> newFiles = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDesktop = MediaQuery.of(context).size.width > 900;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_note_rounded, color: AppColors.primary, size: isDesktop ? 24 : 20),
                  ),
                  const SizedBox(width: 12),
                  Text('تعديل بيانات العقار ✏️', style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: isDesktop ? 800 : MediaQuery.of(context).size.width * 0.95,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Text('الغرض:'),
                                      const SizedBox(width: 12),
                                      ChoiceChip(
                                        label: const Text('بيع'),
                                        selected: purpose == 'بيع',
                                        onSelected: (_) => setDialogState(() => purpose = 'بيع'),
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('إيجار'),
                                        selected: purpose == 'إيجار',
                                        onSelected: (_) => setDialogState(() => purpose = 'إيجار'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: ['متاح', 'محجوز', 'مباع', 'مؤجر'].contains(status) ? status : 'متاح',
                                  decoration: const InputDecoration(labelText: 'حالة العقار', border: OutlineInputBorder()),
                                  items: ['متاح', 'محجوز', 'مباع', 'مؤجر']
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => status = val!),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Text('الغرض:'),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: const Text('بيع'),
                                  selected: purpose == 'بيع',
                                  onSelected: (_) => setDialogState(() => purpose = 'بيع'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('إيجار'),
                                  selected: purpose == 'إيجار',
                                  onSelected: (_) => setDialogState(() => purpose = 'إيجار'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: ['متاح', 'محجوز', 'مباع', 'مؤجر'].contains(status) ? status : 'متاح',
                            decoration: const InputDecoration(labelText: 'حالة العقار', border: OutlineInputBorder()),
                            items: ['متاح', 'محجوز', 'مباع', 'مؤجر']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (val) => setDialogState(() => status = val!),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: AppStrings.finishingTypes.contains(finishing) ? finishing : AppStrings.finishingTypes.first,
                                  decoration: const InputDecoration(labelText: 'مستوى التشطيب ✨', border: OutlineInputBorder()),
                                  items: AppStrings.finishingTypes
                                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => finishing = val!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _customFolders.contains(folderName) ? folderName : (_customFolders.where((f) => f != 'الكل').firstOrNull ?? 'عام'),
                                  decoration: const InputDecoration(labelText: 'الفولدر / المنطقة 📁', border: OutlineInputBorder()),
                                  items: _customFolders.where((f) => f != 'الكل')
                                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => folderName = val!),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          DropdownButtonFormField<String>(
                            value: AppStrings.finishingTypes.contains(finishing) ? finishing : AppStrings.finishingTypes.first,
                            decoration: const InputDecoration(labelText: 'مستوى التشطيب ✨', border: OutlineInputBorder()),
                            items: AppStrings.finishingTypes
                                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                .toList(),
                            onChanged: (val) => setDialogState(() => finishing = val!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _customFolders.contains(folderName) ? folderName : (_customFolders.where((f) => f != 'الكل').firstOrNull ?? 'عام'),
                            decoration: const InputDecoration(labelText: 'الفولدر / المنطقة 📁', border: OutlineInputBorder()),
                            items: _customFolders.where((f) => f != 'الكل')
                                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                .toList(),
                            onChanged: (val) => setDialogState(() => folderName = val!),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: 'عنوان الإعلان (مطلوب)', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: 12),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: locationController,
                                  decoration: const InputDecoration(labelText: 'الموقع والحي 📍', border: OutlineInputBorder()),
                                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: ['شقة', 'فيلا', 'محل تجاري', 'أرض', 'مكتب'].contains(type) ? type : 'شقة',
                                  decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                                  items: ['شقة', 'فيلا', 'محل تجاري', 'أرض', 'مكتب']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (val) => setDialogState(() => type = val!),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: locationController,
                            decoration: const InputDecoration(labelText: 'الموقع والحي 📍', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: ['شقة', 'فيلا', 'محل تجاري', 'أرض', 'مكتب'].contains(type) ? type : 'شقة',
                            decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
                            items: ['شقة', 'فيلا', 'محل تجاري', 'أرض', 'مكتب']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) => setDialogState(() => type = val!),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: priceController,
                                  decoration: const InputDecoration(labelText: 'سعر البيع/الإيجار (ج.م)', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: areaController,
                                  decoration: const InputDecoration(labelText: 'المساحة (م²)', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          TextFormField(
                            controller: priceController,
                            decoration: const InputDecoration(labelText: 'سعر البيع/الإيجار (ج.م)', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: areaController,
                            decoration: const InputDecoration(labelText: 'المساحة (م²)', border: OutlineInputBorder()),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: roomsController, decoration: const InputDecoration(labelText: 'الغرف', border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: bathroomsController, decoration: const InputDecoration(labelText: 'الحمامات', border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: floorController, decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()))),
                            ],
                          )
                        else ...[
                          TextFormField(controller: roomsController, decoration: const InputDecoration(labelText: 'الغرف', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          TextFormField(controller: bathroomsController, decoration: const InputDecoration(labelText: 'الحمامات', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          TextFormField(controller: floorController, decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder())),
                        ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'وصف إضافي للعقار', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: videoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'رابط فيديو المعاينة (YouTube / Vimeo / رابط مباشر) 🎥',
                          hintText: 'https://www.youtube.com/watch?v=...',
                          prefixIcon: Icon(Icons.video_library_rounded, color: AppColors.primary),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ─── Property Images Section ─────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.collections_rounded, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('إدارة صور العقار 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Existing Images Preview
                            if (currentImages.isNotEmpty) ...[
                              const Text('الصور الحالية (اضغط ✖ لإزالة الصورة):', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 85,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: currentImages.length,
                                  itemBuilder: (context, index) {
                                    final imgUrl = currentImages[index];
                                    return Stack(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          width: 85,
                                          height: 85,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            image: DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover),
                                          ),
                                        ),
                                        Positioned(
                                          top: 3,
                                          left: 3,
                                          child: InkWell(
                                            onTap: () => setDialogState(() => currentImages.removeAt(index)),
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // New Selected Files
                            if (newFiles.isNotEmpty) ...[
                              const Text('صور جديدة مختارة للإضافة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: newFiles
                                    .map((f) => Chip(
                                          label: Text(f.name, style: const TextStyle(fontSize: 11)),
                                          onDeleted: () => setDialogState(() => newFiles.remove(f)),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                            ],
                            // Pick Images Button
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await FilePicker.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: true,
                                  withData: true,
                                );
                                if (result != null) {
                                  setDialogState(() => newFiles.addAll(result.files));
                                }
                              },
                              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                              label: const Text('إضافة صور جديدة من الجهاز'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: isSaving ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isSaving = true);
                    List<String> newUploadedUrls = [];
                    if (newFiles.isNotEmpty) {
                      newUploadedUrls = await _uploadImages(newFiles);
                    }
                    final finalImages = [...currentImages, ...newUploadedUrls];

                    final data = {
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'price': _parseArabicPrice(priceController.text),
                      'area': _parseArabicArea(areaController.text),
                      'location': locationController.text.trim(),
                      'type': type,
                      'status': status,
                      'bedrooms': int.tryParse(roomsController.text) ?? 0,
                      'bathrooms': int.tryParse(bathroomsController.text) ?? 0,
                      'floor': int.tryParse(floorController.text) ?? 0,
                      'build_year': int.tryParse(yearController.text) ?? DateTime.now().year,
                      'roi': double.tryParse(roiController.text) ?? 0.0,
                      'purpose': purpose,
                      'amenities': selectedAmenities,
                      'finishing': finishing,
                      'folder_name': folderName,
                      'is_featured': isFeatured,
                      'video_url': videoUrlController.text.trim(),
                      'images': finalImages,
                    };
                    final ok = await _supabaseService.updateProperty(prop.id, data);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديث بيانات وصور العقار بنجاح ✅'), backgroundColor: AppColors.success),
                        );
                        _loadDashboardData();
                      }
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeletePropertyDialog(Property prop) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد الحذف 🗑️', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('هل أنت تأكد من حذف عقار "${prop.title}" نهائياً من السيستم؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final ok = await _supabaseService.deleteProperty(prop.id);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف العقار بنجاح 🗑️'), backgroundColor: AppColors.success),
                  );
                  _loadDashboardData();
                }
              },
              child: const Text('حذف العقار', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePropertyWhatsApp(Property prop) async {
    final text = '''
🏡 *${prop.title}* 🏡

📍 *الموقع:* ${prop.location}
💰 *السعر:* ${prop.price.toInt()} جنيه
📐 *المساحة:* ${prop.area.toInt()} متر²
🛏️ *الغرف:* ${prop.bedrooms} | 🛁 *الحمامات:* ${prop.bathrooms} | 🏢 *الدور:* ${prop.floor}
🎯 *الغرض:* ${prop.type} (${prop.status})

📝 *الوصف:*
${prop.description}

✨ *شركة الحمد للعقارات (طنطا والقاهرة)* ✨
للتواصل والاستفسار المباشر 📞
''';

    final uri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditCustomerNotesDialog(Map<String, dynamic> cust) {
    final notesController = TextEditingController(text: cust['notes']?.toString() ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('ملاحظات وتحديثات العميل 📝', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 600 ? 400 : MediaQuery.of(context).size.width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('العميل: ${cust['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب ملاحظات العميل، تفاصيل آخر مكالمة، أو الاتفاق...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  final success = await _supabaseService.updateCustomerNotes(
                    cust['id'].toString(),
                    notesController.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تحديث ملاحظات العميل بنجاح ✅'), backgroundColor: AppColors.success),
                      );
                      _loadDashboardData();
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ الملاحظات'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String p) async =>
      await launchUrl(Uri(scheme: 'tel', path: p));

  Future<void> _openWhatsApp(String phoneNumber, String name) async {
    String cleanPhone =
        phoneNumber.startsWith('0') ? '2$phoneNumber' : phoneNumber;
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/$cleanPhone?text=${Uri.encodeComponent('أهلاً يا $name، بخصوص طلبك في عقارات طنطا والقاهرة...')}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SliverHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 80.0;

  @override
  double get minExtent => 80.0;

  @override
  bool shouldRebuild(covariant _SliverHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
