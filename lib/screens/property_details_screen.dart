import 'package:flutter/material.dart';
import '../models/property.dart';
import '../constants/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' as intl;

class PropertyDetailsScreen extends StatelessWidget {
  const PropertyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final property = ModalRoute.of(context)!.settings.arguments as Property;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(property.title),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageGallery(property),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(property.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('${intl.NumberFormat.decimalPattern().format(property.price)} ج.م',
                          style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey),
                        Text(property.location, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text('التفاصيل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildDetailsGrid(property),
                    const SizedBox(height: 24),
                    const Text('الوصف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(property.description, style: const TextStyle(fontSize: 16)),
                    if (property.isForInvestment) ...[
                      const SizedBox(height: 24),
                      _buildInvestmentSection(),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _selectTourTime(context),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('اطلب جولة'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {}, // WhatsApp share
                            icon: const Icon(Icons.share),
                            label: const Text('شارك على WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100), // Spacing for bottom
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(Property property) {
    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: 3, // Mocking multiple images
        itemBuilder: (context, index) {
          return CachedNetworkImage(
            imageUrl: property.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[200]),
          );
        },
      ),
    );
  }

  Widget _buildDetailsGrid(Property property) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 4,
      children: [
        _buildDetailItem(Icons.square_foot, 'المساحة: ${property.area} م²'),
        _buildDetailItem(Icons.king_bed, 'الغرف: ${property.bedrooms}'),
        _buildDetailItem(Icons.bathtub, 'الحمامات: ${property.bathrooms}'),
        _buildDetailItem(Icons.apartment, 'النوع: ${property.type}'),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  Widget _buildInvestmentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('معلومات الاستثمار', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('العائد السنوي المتوقع:'),
              Text('8% - 10%', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('متوسط الإيجار الشهري:'),
              Text('5,000 ج.م', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectTourTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل طلب الجولة، سنتواصل معك للتأكيد')),
        );
      }
    }
  }
}
