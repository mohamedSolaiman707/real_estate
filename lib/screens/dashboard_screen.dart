import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

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

  // جلب البيانات الحقيقية من سوبابيز
  Future<void> _fetchLeads() async {
    try {
      final response = await _supabase
          .from('leads')
          .select()
          .order('created_at', ascending: false);
      
      setState(() {
        _leads = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching leads: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('لوحة تحكم الموظفين'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLeads,
              tooltip: 'تحديث البيانات',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            ),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLeads,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('طلبات العملاء الجدد 👋', 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text)),
                    const SizedBox(height: 8),
                    Text('لديك ${_leads.length} طلبات تحتاج للمتابعة', 
                      style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    _buildLeadsList(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildLeadsList() {
    if (_leads.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('لا توجد طلبات حالياً'),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _leads.length,
      itemBuilder: (context, index) {
        final lead = _leads[index];
        final formData = lead['form_data'] as Map<String, dynamic>?;
        final isChatbot = lead['source'] == 'chatbot';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: isChatbot ? Colors.blue[50] : Colors.green[50],
              child: Icon(
                isChatbot ? Icons.smart_toy_outlined : Icons.person_outline,
                color: isChatbot ? Colors.blue : Colors.green,
              ),
            ),
            title: Text(lead['name'] ?? 'بدون اسم', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('رقم الهاتف: ${lead['phone']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isChatbot ? Colors.blue[100] : Colors.green[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isChatbot ? 'من الشات' : 'من الموقع',
                style: TextStyle(fontSize: 10, color: isChatbot ? Colors.blue[800] : Colors.green[800], fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const Text('تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (isChatbot) 
                      _buildChatbotDetails(formData)
                    else 
                      _buildFormDetails(formData),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {}, // إضافة أكشن للاتصال
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('اتصال'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {}, // إضافة أكشن للواتساب
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('واتساب'),
                          style: TextButton.styleFrom(foregroundColor: Colors.green),
                        ),
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

  Widget _buildChatbotDetails(Map<String, dynamic>? data) {
    if (data == null) return const Text('لا توجد تفاصيل إضافية');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ملخص المحادثة: ${data['chat_summary'] ?? 'غير متوفر'}'),
        Text('• الاهتمام: ${data['intent'] ?? 'غير محدد'}'),
        Text('• التفضيلات: ${data['preference'] ?? 'غير محدد'}'),
      ],
    );
  }

  Widget _buildFormDetails(Map<String, dynamic>? data) {
    if (data == null) return const Text('لا توجد تفاصيل إضافية');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• نوع العقار: ${data['property_type'] ?? 'غير محدد'}'),
        Text('• الموقع: ${data['location'] ?? 'غير محدد'}'),
        Text('• الميزانية: ${data['budget'] ?? 'غير محدد'}'),
        Text('• الغرض: ${data['purpose'] ?? 'غير محدد'}'),
      ],
    );
  }
}
