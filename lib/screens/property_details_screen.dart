import 'package:flutter/material.dart';
import '../models/property.dart';
import '../constants/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({super.key});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  int _selectedImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final property = ModalRoute.of(context)!.settings.arguments as Property;
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(property.title, style: const TextStyle(fontSize: 18)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 32 : 16,
                vertical: 24,
              ),
              child: isWeb 
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildMainContent(property)),
                      const SizedBox(width: 32),
                      Expanded(flex: 1, child: _buildSidebar(context, property)),
                    ],
                  )
                : Column(
                    children: [
                      _buildImageGallery(property),
                      _buildMainContent(property, showGalleryInContent: false),
                      const SizedBox(height: 24),
                      _buildSidebar(context, property),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(Property property, {bool showGalleryInContent = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGalleryInContent && MediaQuery.of(context).size.width > 900)
          _buildImageGallery(property),
        
        const SizedBox(height: 24),
        Text(property.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.secondary, size: 20),
            const SizedBox(width: 4),
            Text(property.location, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
        const Divider(height: 40),
        
        const Text('المواصفات الأساسية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildDetailsGrid(property),
        
        const Divider(height: 40),
        const Text('وصف العقار', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(property.description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
        
        if (property.isForInvestment) ...[
          const SizedBox(height: 32),
          _buildInvestmentCard(property),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, Property property) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السعر المطلوب', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('${intl.NumberFormat.decimalPattern().format(property.price)} ج.م',
              style: const TextStyle(fontSize: 26, color: AppColors.primary, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _launchWhatsApp(property),
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text('تواصل عبر واتساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () => _selectTourTime(context),
                icon: const Icon(Icons.calendar_month),
                label: const Text('طلب معاينة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(Property property) {
    if (property.images.isEmpty) return const SizedBox();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: property.images[_selectedImageIndex],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        ),
        if (property.images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: property.images.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedImageIndex = index;
                    });
                  },
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedImageIndex == index ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
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

  Widget _buildDetailsGrid(Property property) {
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _buildDetailBox(Icons.square_foot, '${property.area} م²', 'المساحة'),
        _buildDetailBox(Icons.king_bed, '${property.bedrooms}', 'غرف النوم'),
        _buildDetailBox(Icons.bathtub, '${property.bathrooms}', 'الحمامات'),
        _buildDetailBox(Icons.apartment, property.type, 'نوع العقار'),
      ],
    );
  }

  Widget _buildDetailBox(IconData icon, String value, String label) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(Property property) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: AppColors.primary),
              SizedBox(width: 8),
              Text('تحليل الاستثمار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInvestmentRow('العائد السنوي المتوقع (ROI):', '12% - 15%'),
          const SizedBox(height: 8),
          _buildInvestmentRow('متوسط الإيجار في المنطقة:', '6,000 ج.م'),
        ],
      ),
    );
  }

  Widget _buildInvestmentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  void _launchWhatsApp(Property p) async {
    final msg = Uri.encodeComponent('أهلاً، أنا مهتم بعقار: ${p.title} في ${p.location}');
    final url = Uri.parse("https://wa.me/201014250577?text=$msg");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _selectTourTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل طلبك، سنتواصل معك للتأكيد ✅')));
    }
  }
}
