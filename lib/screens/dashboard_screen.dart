import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../constants/colors.dart';
import '../constants/strings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _leads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    try {
      final response = await _supabase.from('leads').select().order('created_at', ascending: false);
      setState(() {
        _leads = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- لوجيك رفع الصور لاحترافي ---
  Future<List<String>> _uploadImages(List<PlatformFile> files) async {
    List<String> imageUrls = [];
    for (var file in files) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = 'property_images/$fileName';
      
      await _supabase.storage.from('properties').uploadBinary(
        path,
        file.bytes!,
        fileOptions: FileOptions(contentType: 'image/${file.extension}'),
      );
      
      final url = _supabase.storage.from('properties').getPublicUrl(path);
      imageUrls.add(url);
    }
    return imageUrls;
  }

  void _showAddPropertyDialog() {
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    List<PlatformFile> selectedFiles = [];
    
    // متغيرات مطابقة للـ Schema في الصورة
    String title = '', description = '', location = AppStrings.locations[0], type = AppStrings.propertyTypes[0], purpose = 'بيع', status = 'available';
    int price = 0, area = 0, bedrooms = 0, bathrooms = 0, floor = 0, buildYear = DateTime.now().year, avgRent = 0;
    double roi = 0.0;
    bool isFeatured = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عقار جديد بالتفاصيل الكاملة 🏠'),
          content: SizedBox(
            width: 800,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1. البيانات الأساسية
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'عنوان العقار (مطلوب)', border: OutlineInputBorder()),
                      onChanged: (v) => title = v,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'وصف العقار بالتفصيل', border: OutlineInputBorder()),
                      maxLines: 3,
                      onChanged: (v) => description = v,
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. السعر والمساحة والدور
                    Row(
                      children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'السعر (ج.م)'), keyboardType: TextInputType.number, onChanged: (v) => price = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'المساحة (م²)'), keyboardType: TextInputType.number, onChanged: (v) => area = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'الدور'), keyboardType: TextInputType.number, onChanged: (v) => floor = int.tryParse(v) ?? 0)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. الغرف والحمامات وسنة البناء
                    Row(
                      children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'غرف النوم'), keyboardType: TextInputType.number, onChanged: (v) => bedrooms = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'الحمامات'), keyboardType: TextInputType.number, onChanged: (v) => bathrooms = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'سنة البناء'), keyboardType: TextInputType.number, onChanged: (v) => buildYear = int.tryParse(v) ?? DateTime.now().year)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. الاستثمار (ROI والعائد)
                    Row(
                      children: [
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'متوسط الإيجار الشهري'), keyboardType: TextInputType.number, onChanged: (v) => avgRent = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'نسبة العائد (ROI %)'), keyboardType: TextInputType.number, onChanged: (v) => roi = double.tryParse(v) ?? 0.0)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 5. الاختيارات (المنطقة، النوع، الغرض)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: location,
                            items: AppStrings.locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                            onChanged: (v) => location = v!,
                            decoration: const InputDecoration(labelText: 'المنطقة'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: type,
                            items: AppStrings.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => type = v!,
                            decoration: const InputDecoration(labelText: 'نوع العقار'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 6. رفع الصور
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Text('صور العقار 📸', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (selectedFiles.isNotEmpty)
                             Wrap(spacing: 8, children: selectedFiles.map((f) => Chip(label: Text(f.name), onDeleted: () => setDialogState(() => selectedFiles.remove(f)))).toList()),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
                              if (result != null) {
                                setDialogState(() => selectedFiles.addAll(result.files));
                              }
                            },
                            icon: const Icon(Icons.upload_file),
                            label: const Text('اختيار صور من الجهاز'),
                          ),
                        ],
                      ),
                    ),
                    
                    CheckboxListTile(
                      title: const Text('عقار مميز (يظهر في الهيرو)'),
                      value: isFeatured,
                      onChanged: (v) => setDialogState(() => isFeatured = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (isSaving) const CircularProgressIndicator() 
            else ...[
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isSaving = true);
                    try {
                      List<String> imageUrls = [];
                      if (selectedFiles.isNotEmpty) {
                        imageUrls = await _uploadImages(selectedFiles);
                      }

                      await _supabase.from('properties').insert({
                        'title': title,
                        'description': description,
                        'price': price,
                        'area': area,
                        'location': location,
                        'type': type,
                        'bedrooms': bedrooms,
                        'bathrooms': bathrooms,
                        'floor': floor,
                        'build_year': buildYear,
                        'avg_rent': avgRent,
                        'roi': roi,
                        'purpose': purpose,
                        'status': status,
                        'images': imageUrls,
                        'is_featured': isFeatured,
                        'created_at': DateTime.now().toIso8601String(),
                        'admin_id': _supabase.auth.currentUser?.id,
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العقار بنجاح! 🎉'), backgroundColor: AppColors.success));
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppColors.danger));
                      }
                    }
                  }
                },
                child: const Text('حفظ العقار في الداتابيز'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('لوحة التحكم الاحترافية 💼'),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLeads),
            IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacementNamed(context, '/')),
          ],
        ),
        body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPropertyDialog,
          backgroundColor: AppColors.secondary,
          icon: const Icon(Icons.add_business, color: Colors.white),
          label: const Text('إضافة عقار جديد', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إدارة الطلبات والعملاء 📋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildLeadsList(),
        ],
      ),
    );
  }

  Widget _buildLeadsList() {
    if (_leads.isEmpty) return const Center(child: Text('لا توجد طلبات حالياً'));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        final isChatbot = lead['source'] == 'chatbot';
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ExpansionTile(
            leading: Icon(isChatbot ? Icons.smart_toy_outlined : Icons.person, color: isChatbot ? Colors.blue : Colors.green),
            title: Text(lead['name'] ?? 'عميل'),
            subtitle: Text('رقم: ${lead['phone']}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    ElevatedButton(onPressed: () => _launchWhatsApp(lead['phone']), child: const Text('واتساب')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: () => _makePhoneCall(lead['phone']), child: const Text('اتصال')),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _makePhoneCall(String p) async => await launchUrl(Uri(scheme: 'tel', path: p));
  Future<void> _launchWhatsApp(String p) async => await launchUrl(Uri.parse("https://wa.me/20$p"));
}
