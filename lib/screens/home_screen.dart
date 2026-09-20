import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../widgets/chatbot_widget.dart';
import '../widgets/footer.dart';
import '../widgets/property_card.dart';
import '../models/property.dart';
import '../services/supabase_service.dart';
import '../services/seed_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _heroImageUrl =
      'https://images.unsplash.com/photo-1582407947304-fd86f028f716?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80';

  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _phone = '';
  final String _selectedCity = 'الكل';
  String _selectedType = AppStrings.propertyTypes[0];
  String _selectedLocation = AppStrings.locations[0];
  double _budget = 1500000;
  String _rooms = '3';
  String _purpose = AppStrings.purposes[0];

  List<Property> _featuredProperties = [];
  bool _isLoadingProperties = true;
  bool _isSeeding = false;
  bool _isHeroImagePrecached = false;

  @override
  void initState() {
    super.initState();
    _fetchFeaturedProperties();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isHeroImagePrecached) {
      precacheImage(const CachedNetworkImageProvider(_heroImageUrl), context);
      _isHeroImagePrecached = true;
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/201014250577?text=${Uri.encodeComponent('مرحبًا، أريد الاستفسار عن العقارات المتاحة في طنطا والقاهرة')}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تعذر فتح واتساب، تأكد من تثبيت التطبيق')),
        );
      }
    }
  }

  String _formatBudget(double value) {
    if (value >= 1000000) {
      double millions = value / 1000000;
      String formatted = millions
          .toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1);
      return '$formatted مليون';
    } else {
      return '${(value / 1000).toInt()} ألف';
    }
  }

  Future<void> _fetchFeaturedProperties() async {
    setState(() => _isLoadingProperties = true);
    try {
      final properties = await _supabaseService.getProperties();
      final featured = properties
          .where((p) => p.isFeatured || properties.indexOf(p) < 4)
          .take(4)
          .toList();

      setState(() {
        _featuredProperties = featured;
        _isLoadingProperties = false;
      });
    } catch (e) {
      debugPrint('Error fetching featured: $e');
      setState(() => _isLoadingProperties = false);
    }
  }

  Future<void> _handleSeedData() async {
    setState(() => _isSeeding = true);
    try {
      await SeedDataService.seedInitialProperties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة عقارات مميزة في طنطا والقاهرة بنجاح! 🎉'),
              backgroundColor: AppColors.success),
        );
      }
      await _fetchFeaturedProperties();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ أثناء تعبئة البيانات: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _submitLead() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _supabase.from('leads').insert({
          'name': _name.trim(),
          'phone': _phone.trim(),
          'source': 'home_form',
          'form_data': {
            'city': _selectedCity,
            'property_type': _selectedType,
            'location': _selectedLocation,
            'budget': _budget,
            'rooms': _rooms,
            'purpose': _purpose,
          }
        });

        // Fetch properties for Smart Matching
        final properties = await _supabaseService.getProperties();
        
        final matched = properties.where((p) {
          final typeMatch = p.type == _selectedType;
          final locationMatch = p.location == _selectedLocation;
          final budgetMatch = p.price >= (_budget * 0.75) && p.price <= (_budget * 1.25);
          
          bool roomsMatch = false;
          if (_rooms == '5+') {
            roomsMatch = p.bedrooms >= 5;
          } else {
            roomsMatch = p.bedrooms == int.tryParse(_rooms);
          }
          
          return typeMatch && locationMatch && budgetMatch && roomsMatch;
        }).toList();

        bool isExactMatch = matched.isNotEmpty;
        List<Property> displayProperties = matched;
        
        if (!isExactMatch) {
          final featured = properties.where((p) => p.isFeatured).toList();
          if (featured.length >= 2) {
            displayProperties = featured.take(2).toList();
          } else {
            displayProperties = properties.take(2).toList();
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'شكرًا يا $_name! تواصل معك مستشار عقارات طنطا والقاهرة قريبًا ☎️'),
              backgroundColor: AppColors.success,
            ),
          );
          _formKey.currentState!.reset();
          
          // Show the premium Smart Matching Dialog
          _showSmartMatchingDialog(displayProperties, isExactMatch);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showSmartMatchingDialog(List<Property> displayProperties, bool isExactMatch) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isExactMatch ? AppColors.success.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExactMatch ? Icons.stars_rounded : Icons.lightbulb_rounded,
                    color: isExactMatch ? AppColors.success : AppColors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isExactMatch ? 'لقد وجدنا عقارات تطابق طلبك! ✨' : 'مقترحات بديلة تناسب اهتمامك ✨',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!isExactMatch) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'لم نجد عقارات تطابق نفس الاختيارات تماماً، إليك أفضل الخيارات المميزة:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 380,
              child: displayProperties.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد عقارات متاحة حالياً',
                        style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: displayProperties.length,
                      itemBuilder: (context, index) => SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: PropertyCard(
                            property: displayProperties[index],
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.pushNamed(
                                context,
                                '/property_details',
                                arguments: displayProperties[index],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.slateDark.withOpacity(0.5), size: 20),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500, fontFamily: 'Cairo'),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildFloatingNavbar(bool isDesktop) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // High-end Logo & Branding
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/hamd-logo1.png',
                    width: isDesktop ? 42 : 36,
                    height: isDesktop ? 42 : 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: isDesktop ? 20 : 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: isDesktop ? 15 : 13,
                      fontFamily: 'Cairo',
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(height: 2),
                    Text(
                      'طنطا والقاهرة • العقارات الفاخرة',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),

              // Browse All Properties Button
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/listings'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view_rounded,
                          color: Colors.white, size: isDesktop ? 16 : 14),
                      const SizedBox(width: 6),
                      Text(
                        isDesktop ? 'تصفح كل العقارات' : 'العقارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Staff Portal Login Button
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/login'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 18 : 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: isDesktop ? 16 : 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDesktop ? 'دخول الموظفين' : 'دخول',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 12 : 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final topPadding = MediaQuery.of(context).padding.top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeroSection(isDesktop),
                  _buildLeadForm(isDesktop),
                  _buildFeaturedPropertiesSection(isDesktop),
                  const Footer(),
                ],
              ),
            ),
            Positioned(
              top: topPadding + 14,
              left: isDesktop ? 40 : 20,
              right: isDesktop ? 40 : 20,
              child: _buildFloatingNavbar(isDesktop),
            ),
          ],
        ),
        floatingActionButton: isDesktop
            ? Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'whatsapp',
                    onPressed: _launchWhatsApp,
                    backgroundColor: const Color(0xFF25D366),
                    child: const Icon(Icons.chat_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const ChatBotWidget(),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const ChatBotWidget(),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: 'whatsapp',
                    onPressed: _launchWhatsApp,
                    backgroundColor: const Color(0xFF25D366),
                    child: const Icon(Icons.chat_rounded, color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.85;

    return Container(
      width: double.infinity,
      height: heroHeight < 580 ? 580 : heroHeight,
      decoration: BoxDecoration(
        color: AppColors.slateDark,
        image: DecorationImage(
          image: const CachedNetworkImageProvider(_heroImageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.75),
              Colors.black.withOpacity(0.3),
              const Color(0xFF0F172A),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('خدمات عقارية متميزة في طنطا والقاهرة 🏢',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: isDesktop ? 13 : 11, fontFamily: 'Cairo')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 48 : 28,
                  height: 1.35,
                  fontFamily: 'Cairo',
                ),
                children: const [
                  TextSpan(
                    text: 'أفضل عقارات ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: 'طنطا والقاهرة',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF59E0B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.homeSubtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: isDesktop ? 20 : 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/listings'),
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 28, vertical: isDesktop ? 20 : 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: AppColors.primary.withOpacity(0.5),
              ),
              label: Text(
                'استعرض عقارات طنطا والقاهرة الآن',
                style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo'),
              ),
            ),
            const Spacer(flex: 2),
            
            // Ultra-Premium Trust Badge Row with Glassmorphism Blur
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: isDesktop ? 24 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                  ),
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrustItem(Icons.history_toggle_off_rounded, isDesktop ? '10+ سنوات خبرة' : '10+ سنوات', isDesktop ? 'تميز وثقة عقارية' : 'خبرة عقارية', isDesktop),
                      Container(width: 1, height: 35, color: Colors.white24),
                      _buildTrustItem(Icons.handshake_rounded, isDesktop ? '500+ معاملة ناجحة' : '500+ معاملة', isDesktop ? 'في طنطا والقاهرة' : 'ناجحة', isDesktop),
                      Container(width: 1, height: 35, color: Colors.white24),
                      _buildTrustItem(Icons.support_agent_rounded, isDesktop ? 'دعم 24/7' : 'دعم فني', isDesktop ? 'مستشار متوفر دائماً' : 'متوفر دائماً', isDesktop),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle, bool isDesktop) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFF59E0B), size: isDesktop ? 24 : 20),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isDesktop ? 14 : 11, fontFamily: 'Cairo')),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: isDesktop ? 11 : 9, fontFamily: 'Cairo'), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLeadForm(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      padding: EdgeInsets.all(isDesktop ? 36 : 16),
      margin: EdgeInsets.symmetric(
          vertical: isDesktop ? 48 : 24, horizontal: isDesktop ? 24 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
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
                  child: Icon(Icons.real_estate_agent_rounded,
                      color: AppColors.primary, size: isDesktop ? 26 : 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سجل اهتمامك وهنكلمك فوراً 📞',
                          style: TextStyle(
                              fontSize: isDesktop ? 22 : 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo')),
                      const SizedBox(height: 4),
                      Text('ابحث عن عقارك المثالي بدعم كامل من مستشارينا',
                          style: TextStyle(fontSize: isDesktop ? 13 : 11, color: const Color(0xFF64748B), fontFamily: 'Cairo')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _buildInputDecoration(label: AppStrings.nameLabel, icon: Icons.person_outline_rounded),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب إدخال الاسم' : null,
                      onChanged: (value) => _name = value,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: TextFormField(
                      decoration: _buildInputDecoration(label: AppStrings.phoneLabel, icon: Icons.phone_android_rounded),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 11) ? 'أدخل رقم تليفون صحيح (11 رقم)' : null,
                      onChanged: (value) => _phone = value,
                    ),
                  ),
                ],
              )
            else ...[
              TextFormField(
                decoration: _buildInputDecoration(label: AppStrings.nameLabel, icon: Icons.person_outline_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب إدخال الاسم' : null,
                onChanged: (value) => _name = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _buildInputDecoration(label: AppStrings.phoneLabel, icon: Icons.phone_android_rounded),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 11) ? 'أدخل رقم تليفون صحيح (11 رقم)' : null,
                onChanged: (value) => _phone = value,
              ),
            ],
            const SizedBox(height: 20),
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: AppStrings.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                      decoration: _buildInputDecoration(label: AppStrings.propertyTypeLabel, icon: Icons.holiday_village_outlined),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedLocation,
                      items: AppStrings.locations.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setState(() => _selectedLocation = val!),
                      decoration: _buildInputDecoration(label: AppStrings.locationLabel, icon: Icons.location_on_outlined),
                    ),
                  ),
                ],
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                items: AppStrings.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
                decoration: _buildInputDecoration(label: AppStrings.propertyTypeLabel, icon: Icons.holiday_village_outlined),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocation,
                items: AppStrings.locations.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                onChanged: (val) => setState(() => _selectedLocation = val!),
                decoration: _buildInputDecoration(label: AppStrings.locationLabel, icon: Icons.location_on_outlined),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.budgetLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      Text('${_formatBudget(_budget)} ج.م', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary, fontFamily: 'Cairo')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      trackHeight: 8,
                      thumbColor: AppColors.primary,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, pressedElevation: 8),
                      overlayColor: AppColors.primary.withOpacity(0.15),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                    ),
                    child: Slider(
                      value: _budget,
                      min: 200000,
                      max: 15000000,
                      divisions: 74,
                      onChanged: (val) => setState(() => _budget = val),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('200 ألف', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                        Text('15 مليون', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _rooms,
                      items: ['1', '2', '3', '4', '5+'].map((r) => DropdownMenuItem(value: r, child: Text('$r غرف', style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setState(() => _rooms = val!),
                      decoration: _buildInputDecoration(label: AppStrings.roomsLabel, icon: Icons.bed_outlined),
                    ),
                  ),
                  const SizedBox(width: 32),
                  const Text('الغرض من العقار:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                  const SizedBox(width: 16),
                  ...AppStrings.purposes.map((p) => Row(
                    children: [
                      Radio<String>(
                        value: p,
                        groupValue: _purpose,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _purpose = val!),
                      ),
                      Text(p, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                      const SizedBox(width: 12),
                    ],
                  )).toList(),
                ],
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _rooms,
                items: ['1', '2', '3', '4', '5+'].map((r) => DropdownMenuItem(value: r, child: Text('$r غرف', style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                onChanged: (val) => setState(() => _rooms = val!),
                decoration: _buildInputDecoration(label: AppStrings.roomsLabel, icon: Icons.bed_outlined),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      const Text('الغرض: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Cairo')),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: AppStrings.purposes.map((p) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: p,
                              groupValue: _purpose,
                              activeColor: AppColors.primary,
                              onChanged: (val) => setState(() => _purpose = val!),
                            ),
                            Text(p, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                            const SizedBox(width: 4),
                          ],
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 36),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF4F46E5)],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _submitLead,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                label: Text(AppStrings.sendButton,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPropertiesSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 64 : 40, horizontal: isDesktop ? 32 : 16),
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          // Section Decorator / Premium Badge Design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_purple500_rounded, color: AppColors.secondary, size: 16),
                const SizedBox(width: 8),
                const Text('عروض حصرية مختارة بعناية', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Cairo')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('عقارات مميزة في طنطا والقاهرة 🏢',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                  height: 1.2)),
          const SizedBox(height: 12),
          const Text('اكتشف أفضل الفرص السكنية والاستثمارية بأسعار تنافسية ومواقع استراتيجية',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500, fontFamily: 'Cairo')),
          const SizedBox(height: 40),
          _isLoadingProperties
              ? const Center(child: CircularProgressIndicator())
              : _featuredProperties.isEmpty
                  ? Column(
                      children: [
                        const Text('لا توجد عقارات مضافة في الداتابيز حالياً',
                            style: TextStyle(fontSize: 15, color: Colors.grey, fontFamily: 'Cairo')),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isSeeding ? null : _handleSeedData,
                          icon: _isSeeding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_rounded),
                          label: const Text(
                              'تعبئة عقارات تجريبية في طنطا والقاهرة 🚀', style: TextStyle(fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 1100
                            ? 4
                            : (constraints.maxWidth > 700 ? 2 : 1);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: isDesktop ? 20 : 16,
                            mainAxisSpacing: isDesktop ? 20 : 16,
                            childAspectRatio: isDesktop ? 0.75 : 0.8,
                          ),
                          itemCount: _featuredProperties.length,
                          itemBuilder: (context, index) {
                            return PropertyCard(
                              property: _featuredProperties[index],
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/property_details',
                                arguments: _featuredProperties[index],
                              ),
                            );
                          },
                        );
                      },
                    ),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/listings'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
            ),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary, size: 20),
            label: const Text('مشاهدة كل العقارات المتاحة (طنطا والقاهرة)',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
