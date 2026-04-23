import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
      if (file.bytes == null) continue;
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
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final priceController = TextEditingController();
    final areaController = TextEditingController();
    final descController = TextEditingController();
    final roomsController = TextEditingController(text: '0');
    final bathsController = TextEditingController(text: '0');
    final floorController = TextEditingController(text: '0');
    final yearController = TextEditingController(text: DateTime.now().year.toString());
    final roiController = TextEditingController(text: '0');

    bool isSaving = false;
    List<PlatformFile> selectedFiles = [];
    String purpose = 'بيع';
    String type = 'شقة';
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
                          const Text('الغرض:'),
                          const SizedBox(width: 20),
                          ChoiceChip(
                            label: const Text('بيع'),
                            selected: purpose == 'بيع',
                            onSelected: (val) => setDialogState(() => purpose = 'بيع'),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            label: const Text('إيجار'),
                            selected: purpose == 'إيجار',
                            onSelected: (val) => setDialogState(() => purpose = 'إيجار'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'عنوان الإعلان (مطلوب)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: locationController,
                            decoration: const InputDecoration(labelText: 'المنطقة / العنوان بالتفصيل 📍', border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'يرجى إدخال الموقع' : null,
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
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: priceController, decoration: InputDecoration(labelText: purpose == 'بيع' ? 'سعر البيع' : 'الإيجار الشهري'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: TextFormField(controller: areaController, decoration: const InputDecoration(labelText: 'المساحة (م²)'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (type != 'أرض')
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: roomsController, decoration: const InputDecoration(labelText: 'الغرف'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: bathsController, decoration: const InputDecoration(labelText: 'الحمامات'), keyboardType: TextInputType.number)),
                          if (type == 'شقة') 
                            Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: TextFormField(controller: floorController, decoration: const InputDecoration(labelText: 'الدور'), keyboardType: TextInputType.number))),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (purpose == 'بيع')
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: roiController, decoration: const InputDecoration(labelText: 'العائد ROI %'), keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(child: TextFormField(controller: yearController, decoration: const InputDecoration(labelText: 'سنة البناء'), keyboardType: TextInputType.number)),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'وصف إضافي', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('صور العقار 📸'),
                          const SizedBox(height: 12),
                          if (selectedFiles.isNotEmpty)
                            Wrap(spacing: 8, children: selectedFiles.map((f) => Chip(label: Text(f.name), onDeleted: () => setDialogState(() => selectedFiles.remove(f)))).toList()),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(type: FileType.image, allowMultiple: true);
                              if (result != null) setDialogState(() => selectedFiles.addAll(result.files));
                            },
                            icon: const Icon(Icons.add_a_photo),
                            label: const Text('اختيار صور من الجهاز'),
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(title: const Text('تمييز العقار'), value: isFeatured, onChanged: (v) => setDialogState(() => isFeatured = v!)),
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
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'price': int.tryParse(priceController.text) ?? 0,
                        'area': int.tryParse(areaController.text) ?? 0,
                        'location': locationController.text.trim(),
                        'type': type,
                        'bedrooms': int.tryParse(roomsController.text) ?? 0,
                        'bathrooms': int.tryParse(bathsController.text) ?? 0,
                        'floor': int.tryParse(floorController.text) ?? 0,
                        'build_year': int.tryParse(yearController.text) ?? 0,
                        'roi': double.tryParse(roiController.text) ?? 0.0,
                        'purpose': purpose,
                        'images': imageUrls,
                        'is_featured': isFeatured,
                        'created_at': DateTime.now().toIso8601String(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح! ✅'), backgroundColor: AppColors.success));
                      }
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.danger));
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('من فضلك املأ الحقول المطلوبة (باللون الأحمر)'), backgroundColor: Colors.orange));
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
        appBar: AppBar(title: const Text('لوحة التحكم الاحترافية 💼')),
        body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddPropertyDialog,
          backgroundColor: AppColors.secondary,
          icon: const Icon(Icons.add),
          label: const Text('إضافة عقار جديد'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        return Card(
          child: ListTile(
            title: Text(lead['name'] ?? 'عميل'),
            subtitle: Text(lead['phone']),
            trailing: IconButton(icon: const Icon(Icons.chat, color: Colors.green), onPressed: () => launchUrl(Uri.parse("https://wa.me/20${lead['phone']}"))),
          ),
        );
      },
    );
  }
}
