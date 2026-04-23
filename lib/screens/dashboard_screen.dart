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

    // متغيرات الحالة للفورم الديناميكي
    String purpose = 'بيع';
    String type = 'شقة';
    String location = ''; // أصبحت نص حر
    String title = '', description = '', status = 'available';
    int price = 0, area = 0, bedrooms = 0, bathrooms = 0, floor = 0, buildYear = DateTime.now().year, avgRent = 0;
    double roi = 0.0;
    bool isFeatured = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عقار جديد'),
          content: SizedBox(
            width: 800,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // الغرض (بيع / إيجار)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Text('الغرض:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 20),
                          ChoiceChip(
                            label: const Text('بيع 💰'),
                            selected: purpose == 'بيع',
                            onSelected: (val) => setDialogState(() => purpose = 'بيع'),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('إيجار 🔑'),
                            selected: purpose == 'إيجار',
                            onSelected: (val) => setDialogState(() => purpose = 'إيجار'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      decoration: const InputDecoration(labelText: 'عنوان العقار (مثلاً: شقة تمليك بالاستاد)', border: OutlineInputBorder()),
                      onChanged: (v) => title = v,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // المنطقة ونوع العقار (المنطقة الآن نص حر)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'المنطقة / العنوان بالتفصيل 📍',
                              hintText: 'مثلاً: طنطا - شارع البحر',
                              border: OutlineInputBorder()
                            ),
                            onChanged: (v) => location = v,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: type,
                            items: ['شقة', 'عمارة كاملة', 'فيلا', 'محل تجاري', 'أرض'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setDialogState(() => type = v!),
                            decoration: const InputDecoration(labelText: 'نوع العقار', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // السعر والمساحة
                    Row(
                      children: [
                        if (purpose == 'بيع')
                          Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'سعر البيع (ج.م)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => price = int.tryParse(v) ?? 0))
                        else
                          Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'الإيجار الشهري (ج.م)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => avgRent = int.tryParse(v) ?? 0)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'المساحة (م²)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => area = int.tryParse(v) ?? 0)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // حقول المباني (تختفي لو أرض)
                    if (type != 'أرض')
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'غرف النوم', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => bedrooms = int.tryParse(v) ?? 0)),
                              const SizedBox(width: 12),
                              Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'الحمامات', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => bathrooms = int.tryParse(v) ?? 0)),
                              
                              // إظهار "الدور" فقط لو شقة أو محل
                              if (type == 'شقة' || type == 'محل تجاري')
                                ...[
                                  const SizedBox(width: 12),
                                  Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => floor = int.tryParse(v) ?? 0)),
                                ],
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // الاستثمار (ROI) - يظهر فقط في البيع
                    if (purpose == 'بيع')
                      Row(
                        children: [
                          Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'العائد المتوقع ROI %', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => roi = double.tryParse(v) ?? 0.0)),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'سنة البناء', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => buildYear = int.tryParse(v) ?? DateTime.now().year)),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'وصف إضافي', border: OutlineInputBorder()),
                      maxLines: 2,
                      onChanged: (v) => description = v,
                    ),
                    const SizedBox(height: 24),

                    // رفع الصور
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('صور العقار 📸', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          if (selectedFiles.isNotEmpty)
                            Wrap(spacing: 8, children: selectedFiles.map((f) => Chip(label: Text(f.name), onDeleted: () => setDialogState(() => selectedFiles.remove(f)))).toList()),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(type: FileType.image, allowMultiple: true);
                              if (result != null) setDialogState(() => selectedFiles.addAll(result.files));
                            },
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('اختيار صور من الجهاز'),
                          ),
                        ],
                      ),
                    ),
                    
                    CheckboxListTile(
                      title: const Text('تمييز العقار في الموقع'),
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
                      if (selectedFiles.isNotEmpty) imageUrls = await _uploadImages(selectedFiles);

                      await _supabase.from('properties').insert({
                        'title': title, 'description': description, 'price': purpose == 'بيع' ? price : 0,
                        'area': area, 'location': location, 'type': type, 'bedrooms': bedrooms, 'bathrooms': bathrooms,
                        'floor': (type == 'شقة' || type == 'محل تجاري') ? floor : 0,
                        'build_year': buildYear, 'avg_rent': purpose == 'إيجار' ? avgRent : 0, 'roi': roi,
                        'purpose': purpose, 'status': status, 'images': imageUrls, 'is_featured': isFeatured,
                        'created_at': DateTime.now().toIso8601String(), 'admin_id': _supabase.auth.currentUser?.id,
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح! ✅'), backgroundColor: AppColors.success));
                        _fetchLeads();
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                    }
                  }
                },
                child: const Text('حفظ ونشر العقار'),
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
        final formData = lead['form_data'] as Map<String, dynamic>? ?? {};

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const Text('تفاصيل الطلب 📄:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    if (isChatbot)
                      Text('💬 ملخص المحادثة: ${formData['chat_summary'] ?? "استفسار عام"}')
                    else
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(label: Text('🏠 ${formData['property_type'] ?? ""}')),
                          Chip(label: Text('📍 ${formData['location'] ?? ""}')),
                          Chip(label: Text('💰 ${formData['budget'] ?? ""} ج.م')),
                          Chip(label: Text('🚪 ${formData['rooms'] ?? ""} غرف')),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(onPressed: () => _launchWhatsApp(lead['phone']), icon: const Icon(Icons.chat), label: const Text('واتساب'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(onPressed: () => _makePhoneCall(lead['phone']), icon: const Icon(Icons.phone), label: const Text('اتصال'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white))),
                      ],
                    )
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
