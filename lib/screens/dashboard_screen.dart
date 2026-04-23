import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // --- لوجيك إضافة عقار جديد ---
  void _showAddPropertyDialog() {
    final formKey = GlobalKey<FormState>();
    String title = '', description = '', location = AppStrings.locations[0], type = AppStrings.propertyTypes[0], imageUrl = '';
    double price = 0, area = 0;
    int bedrooms = 0, bathrooms = 0;
    bool isFeatured = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة عقار جديد 🏠'),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'عنوان العقار (مثلاً: شقة فاخرة بالاستاد)'),
                      onChanged: (v) => title = v,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'الوصف'),
                      maxLines: 3,
                      onChanged: (v) => description = v,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'السعر (ج.م)'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => price = double.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'المساحة (م²)'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => area = double.tryParse(v) ?? 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'رابط الصورة (URL)'),
                      onChanged: (v) => imageUrl = v,
                    ),
                    CheckboxListTile(
                      title: const Text('تمييز العقار (يظهر في الصفحة الرئيسية)'),
                      value: isFeatured,
                      onChanged: (v) => setDialogState(() => isFeatured = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _supabase.from('properties').insert({
                      'title': title,
                      'description': description,
                      'price': price,
                      'location': location,
                      'area': area,
                      'type': type,
                      'images': [imageUrl.isEmpty ? 'https://via.placeholder.com/400' : imageUrl],
                      'is_featured': isFeatured,
                      'bedrooms': bedrooms,
                      'bathrooms': bathrooms,
                      'purpose': 'بيع',
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة العقار بنجاح ✅'), backgroundColor: AppColors.success));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger));
                    }
                  }
                }
              },
              child: const Text('حفظ العقار'),
            ),
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('لوحة تحكم الموظفين'),
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
          const SizedBox(height: 24),
          _buildLeadsTable(),
        ],
      ),
    );
  }

  Widget _buildLeadsTable() {
    if (_leads.isEmpty) return const Center(child: Text('لا توجد طلبات حالياً'));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person, color: AppColors.primary),
            title: Text(lead['name'] ?? 'بدون اسم'),
            subtitle: Text('رقم: ${lead['phone']} | مصدر: ${lead['source']}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        );
      },
    );
  }
}
