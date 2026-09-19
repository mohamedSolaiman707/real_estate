import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/property.dart';
import '../services/supabase_service.dart';
import '../widgets/property_card.dart';
import '../widgets/embedded_video_player.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _selectedImageIndex = 0;
  bool _isFavorite = false;
  final SupabaseService _supabaseService = SupabaseService();
  List<Property> _similarProperties = [];
  bool _isLoadingSimilar = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSimilarProperties();
  }

  Future<void> _loadSimilarProperties() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Property) return;
    final Property currentProp = args;

    try {
      final allProps = await _supabaseService.getProperties();
      if (mounted) {
        setState(() {
          _similarProperties = allProps
              .where((p) => p.id != currentProp.id && (p.city == currentProp.city || p.type == currentProp.type))
              .take(3)
              .toList();
          _isLoadingSimilar = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading similar properties: $e');
      if (mounted) setState(() => _isLoadingSimilar = false);
    }
  }

  String _formatPrice(double price) {
    return intl.NumberFormat.decimalPattern().format(price);
  }

  double _calculatePricePerSqm(double price, double area) {
    if (area <= 0) return 0;
    return price / area;
  }

  void _launchPhoneCall(String phone) async {
    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _launchWhatsApp(Property p) async {
    final msg = Uri.encodeComponent(
        'مرحباً، أريد الاستفسار عن تفاصيل العقار: ${p.title} في ${p.location} (كود العقار: #${p.id.substring(0, p.id.length > 5 ? 5 : p.id.length)})');
    final url = Uri.parse("https://wa.me/201014250577?text=$msg");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openLightboxGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        int currentIndex = initialIndex;
        final PageController pageController = PageController(initialPage: initialIndex);
        return StatefulBuilder(
          builder: (context, setLightboxState) {
            return Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setLightboxState(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3.0,
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator(color: Colors.white)),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image_rounded, color: Colors.white, size: 60),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'الصورة ${currentIndex + 1} من ${images.length}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = ModalRoute.of(context)!.settings.arguments as Property;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final pricePerSqm = _calculatePricePerSqm(property.price, property.area);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.slateDark, Color(0xFF1E293B)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'كود العقار: #${property.id.substring(0, property.id.length > 5 ? 5 : property.id.length)} • ${property.city}',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _isFavorite ? Colors.redAccent : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isFavorite ? 'تم إضافة العقار للمفضلة ❤️' : 'تم الإزالة من المفضلة'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'مشاركة العقار',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رابط العقار لمشاركته 🔗')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1240),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 24,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _buildMainContent(property, isDesktop)),
                        const SizedBox(width: 28),
                        Expanded(flex: 5, child: _buildStickySidebar(property, pricePerSqm)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroImageGallery(property),
                        const SizedBox(height: 20),
                        _buildMobileStickyPriceCard(property, pricePerSqm),
                        const SizedBox(height: 24),
                        _buildMainContent(property, isDesktop, showGallery: false),
                        const SizedBox(height: 28),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Hero Image Gallery Widget ──────────────────────────────────────────────
  Widget _buildHeroImageGallery(Property property) {
    if (property.images.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Icon(Icons.apartment_rounded, size: 60, color: AppColors.textMuted),
        ),
      );
    }

    final safeIndex = _selectedImageIndex.clamp(0, property.images.length - 1);

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _openLightboxGallery(property.images, safeIndex),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: property.images[safeIndex],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),

            // Top Status Badges
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: property.status == 'تم البيع'
                            ? [Colors.red[600]!, Colors.red[800]!]
                            : [AppColors.success, const Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      property.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          property.folderName.isNotEmpty ? property.folderName : property.city,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Image Counter & Fullscreen Hint
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => _openLightboxGallery(property.images, safeIndex),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${safeIndex + 1} / ${property.images.length} صورة (اضغط التكبير)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Thumbnails Strip
        if (property.images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: property.images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final isSelected = safeIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 105,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: property.images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ─── Main Content Column ───────────────────────────────────────────────────
  Widget _buildMainContent(Property property, bool isDesktop, {bool showGallery = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGallery && isDesktop) _buildHeroImageGallery(property),
        const SizedBox(height: 24),

        // Title & Location Header Card
        Container(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      property.type,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      property.folderName.isNotEmpty ? property.folderName : 'فرع ${property.city}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                property.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      property.location,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // المواصفات دايماً بتاخد العرض الكامل — الفيديو انتقل للـ Sidebar
        const SizedBox(height: 24),
        const Text(
          'المواصفات والتفاصيل الأساسية 📐',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),
        _buildSpecificationsGrid(property, forcedCrossAxisCount: isDesktop ? 3 : 2),

        // الفيديو على الموبايل بيظهر هنا تحت المواصفات
        if (property.hasVideo && !isDesktop) ...[
          const SizedBox(height: 28),
          _buildVideoSection(property),
        ],

        const SizedBox(height: 28),

        // Detailed Description Card
        Container(
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
                  Icon(Icons.description_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'وصف العقار التفصيلي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 14),
              Text(
                property.description.isEmpty
                    ? 'عقار مميز بموقع راقٍ في ${property.location}، يتميز بالتشطيب الفاخر ${property.finishing} وقربه من كافة الخدمات والمحاور الرئيسية.'
                    : property.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Investment Analytics Card (if investment)
        if (property.isForInvestment || property.roi > 0) ...[
          const SizedBox(height: 28),
          _buildInvestmentAnalyticsCard(property),
        ],

        // Amenities & Facilities Section
        if (property.amenities.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildAmenitiesSection(property),
        ],

        const SizedBox(height: 28),

        // Property Consultant & Agent Card
        _buildAgentConsultantCard(property),

        const SizedBox(height: 32),

        // Similar Properties Section
        _buildSimilarPropertiesSection(),
      ],
    );
  }

  // ─── Key Specifications Grid ──────────────────────────────────────────────
  Widget _buildSpecificationsGrid(Property property, {int? forcedCrossAxisCount}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossCount = forcedCrossAxisCount ?? (isMobile ? 2 : 3);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: (forcedCrossAxisCount == 2) ? 1.85 : (isMobile ? 1.6 : 1.7),
          children: [
            _buildSpecTile(Icons.straighten_rounded, '${property.area.toInt()} م²', 'المساحة الكلية', AppColors.primary),
            _buildSpecTile(Icons.king_bed_rounded, '${property.bedrooms} غرف', 'غرف النوم', const Color(0xFF0EA5E9)),
            _buildSpecTile(Icons.bathtub_rounded, '${property.bathrooms} حمام', 'عدد الحمامات', const Color(0xFF10B981)),
            _buildSpecTile(Icons.layers_rounded, property.floor == 0 ? 'أرضي' : 'الدور ${property.floor}', 'رقم الدور', const Color(0xFFF59E0B)),
            _buildSpecTile(Icons.auto_awesome_rounded, property.finishing, 'مستوى التشطيب', const Color(0xFF6366F1)),
            _buildSpecTile(Icons.calendar_today_rounded, '${property.buildYear}', 'سنة البناء', const Color(0xFF8B5CF6)),
          ],
        );
      },
    );
  }

  Widget _buildSpecTile(IconData icon, String value, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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

  // ─── Investment & ROI Analytics Card ──────────────────────────────────────
  Widget _buildInvestmentAnalyticsCard(Property property) {
    final double roiValue = property.roi > 0 ? property.roi : 12.5;
    final double avgRentVal = property.avgRent > 0 ? property.avgRent : property.price * 0.005;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.04), const Color(0xFFEEF2FF)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تحليل العائد والتأجير الاستثماري 📈',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'تقديرات العائد السنوي المتوقع بناءً على حركة أسعار المنطقة',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      const Text('العائد السنوي المتوقع (ROI)',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '${roiValue.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      const Text('متوسط الإيجار المتوقع',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatPrice(avgRentVal)} ج.م/شهر',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Video Preview & Tour Section ────────────────────────────────────────
  Widget _buildVideoSection(Property property, {bool isCompact = false}) {
    if (!property.hasVideo) return const SizedBox();

    return EmbeddedVideoPlayer(
      videoUrl: property.videoUrl,
      coverImageUrl: property.mainImage,
      height: isCompact ? 210 : 250,
    );
  }

  // ─── Amenities Section ─────────────────────────────────────────────────────
  Widget _buildAmenitiesSection(Property property) {
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
              Icon(Icons.stars_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text(
                'الخدمات والمرافق المتاحة 🌟',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: property.amenities.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      a,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Agent Consultant Card ────────────────────────────────────────────────
  Widget _buildAgentConsultantCard(Property property) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slateDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.slateDark.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6366F1)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.person_pin_rounded, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مستشار المعاينات والتسويق العقاري 👨‍💼',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'جاهز للرد على كافة الاستفسارات وترتيب المعاينة في الموقع',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _launchPhoneCall('01014250577'),
            icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            label: const Text(
              'اتصال',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Similar Properties Carousel ─────────────────────────────────────────
  Widget _buildSimilarPropertiesSection() {
    if (_isLoadingSimilar) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_similarProperties.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.holiday_village_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'عقارات مشابهة قد تهمك 🏢',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            int count = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.8,
              ),
              itemCount: _similarProperties.length,
              itemBuilder: (context, index) {
                return PropertyCard(
                  property: _similarProperties[index],
                  onTap: () {
                    Navigator.pushReplacementNamed(
                      context,
                      '/property_details',
                      arguments: _similarProperties[index],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ─── Sticky Sidebar Widget (Desktop) ──────────────────────────────────────
  Widget _buildStickySidebar(Property property, double pricePerSqm) {
    final double downPayment = property.price * 0.10;
    final double estimatedMonthlyInstallment = (property.price * 0.90) / 72; // 6 Years

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppColors.hoverShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('السعر الإجمالي المطلوب',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('كاش / تقسيط',
                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatPrice(property.price)} ج.م',
                style: const TextStyle(
                  fontSize: 28,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (pricePerSqm > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'متوسط سعر المتر: ${_formatPrice(pricePerSqm.roundToDouble())} ج.م/م²',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 20),

              // Payment Plan Preview Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calculate_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'خطة التسهيلات التقديرية 🧮',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المقدم 10%:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${_formatPrice(downPayment)} ج.م',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('القسط الشهري (6 سنوات):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${_formatPrice(estimatedMonthlyInstallment.roundToDouble())} ج.م',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsApp(property),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'تواصل مباشر عبر واتساب 💬',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _showTourBookingDialog(context, property),
                  icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                  label: const Text(
                    'طلب حجز معاينة في الموقع 📅',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton.icon(
                  onPressed: () => _launchPhoneCall('01014250577'),
                  icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.textSecondary, size: 18),
                  label: const Text(
                    'اتصال مباشر بـ 01014250577',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded, size: 14, color: AppColors.success),
                  SizedBox(width: 5),
                  Text(
                    'معاينة وتصوير مجاني • ضمان شركة الحمد',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),

        // فيديو المعاينة ككارد منفصل مع مسافة 20px
        if (property.hasVideo) ...[
          const SizedBox(height: 20),
          _buildVideoSection(property, isCompact: true),
        ],
      ],
    );
  }

  // ─── Mobile Sticky Price Card Widget ──────────────────────────────────────
  Widget _buildMobileStickyPriceCard(Property property, double pricePerSqm) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('السعر المطلوب', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text(
                '${_formatPrice(property.price)} ج.م',
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (pricePerSqm > 0) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'متوسط المتر: ${_formatPrice(pricePerSqm.roundToDouble())} ج.م/م²',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchWhatsApp(property),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('واتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showTourBookingDialog(context, property),
                  icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 16),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('حجز معاينة', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Tour Booking Dialog Widget ────────────────────────────────────────────
  void _showTourBookingDialog(BuildContext context, Property property) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حجز معاينة مباشرة بالموقع',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              property.title,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب إدخال الاسم' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف (11 رقم)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 11) ? 'أدخل رقم تليفون صحيح مكون من 11 رقم' : null,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تاريخ المعاينة المقترح:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() => isSaving = true);
                                    try {
                                      await _supabaseService.requestTour(
                                        propertyId: property.id,
                                        name: nameController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        date: selectedDate,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('تم تسجيل طلب المعاينة بنجاح! وسيتواصل معك الفريق للتأكيد ✅'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setModalState(() => isSaving = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
                                        );
                                      }
                                    }
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('تأكيد طلب المعاينة 📅', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
