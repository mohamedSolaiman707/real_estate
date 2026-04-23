import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../widgets/chatbot_widget.dart';
import '../widgets/footer.dart';
import '../widgets/property_card.dart';
import '../models/property.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _phone = '';
  String _selectedType = AppStrings.propertyTypes[0];
  String _selectedLocation = AppStrings.locations[0];
  double _budget = 500000;
  String _rooms = '3';
  String _purpose = AppStrings.purposes[0];
  
  List<Property> _featuredProperties = [];
  bool _isLoadingProperties = true;

  @override
  void initState() {
    super.initState();
    _fetchFeaturedProperties();
  }

  // وظيفة لتنسيق العملة بشكل احترافي
  String _formatBudget(double value) {
    if (value >= 1000000) {
      double millions = value / 1000000;
      // لو الرقم صحيح (زي 1.0) يظهر "1" بس، لو فيه كسر (زي 1.5) يظهر "1.5"
      String formatted = millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1);
      return '$formatted مليون';
    } else {
      return '${(value / 1000).toInt()} ألف';
    }
  }

  Future<void> _fetchFeaturedProperties() async {
    try {
      final response = await _supabase
          .from('properties')
          .select()
          .eq('is_featured', true)
          .limit(4);
      
      setState(() {
        _featuredProperties = (response as List).map((json) => Property(
          id: json['id'],
          title: json['title'],
          description: json['description'],
          price: (json['price'] as num).toDouble(),
          location: json['location'],
          imageUrl: (json['images'] as List).isNotEmpty ? json['images'][0] : '',
          bedrooms: json['bedrooms'] ?? 0,
          bathrooms: json['bathrooms'] ?? 0,
          area: (json['area'] as num).toDouble(),
          type: json['type'],
          isForInvestment: json['purpose'] == 'استثمار',
        )).toList();
        _isLoadingProperties = false;
      });
    } catch (e) {
      setState(() => _isLoadingProperties = false);
    }
  }

  Future<void> _submitLead() async {
    if (_formKey.currentState!.validate()) {
      try {
        debugPrint('Submitting lead: $_name, $_phone');
        
        await _supabase.from('leads').insert({
          'name': _name.trim(),
          'phone': _phone.trim(),
          'source': 'home_form',
          'form_data': {
            'property_type': _selectedType,
            'location': _selectedLocation,
            'budget': _budget,
            'rooms': _rooms,
            'purpose': _purpose,
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('شكرًا يا $_name! هاتصل بيك الفريق قريبًا ☎️'),
              backgroundColor: AppColors.success,
            ),
          );
          _formKey.currentState!.reset();
        }
      } catch (e) {
        debugPrint('Supabase Insert Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.appName, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppColors.primary,
          actions: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/listings'),
              child: const Text('العقارات', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              child: const Text('دخول الموظفين', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(),
              _buildLeadForm(),
              _buildFeaturedPropertiesSection(),
              const Footer(),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'whatsapp',
              onPressed: () {}, 
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.chat, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const ChatBotWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 450,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const NetworkImage('https://images.unsplash.com/photo-1582407947304-fd86f028f716?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            AppStrings.homeTitle,
            style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            AppStrings.homeSubtitle,
            style: TextStyle(color: Colors.white, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/listings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('تصفح العقارات الآن', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('سجل اهتمامك وهنكلمك فوراً 📞', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: AppStrings.nameLabel, border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    onChanged: (value) => _name = value,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: AppStrings.phoneLabel, border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 11) ? 'رقم غير صحيح' : null,
                    onChanged: (value) => _phone = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: AppStrings.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                    decoration: const InputDecoration(labelText: AppStrings.propertyTypeLabel, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    items: AppStrings.locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (val) => setState(() => _selectedLocation = val!),
                    decoration: const InputDecoration(labelText: AppStrings.locationLabel, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('${AppStrings.budgetLabel}: ${_formatBudget(_budget)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _budget,
              min: 100000,
              max: 5000000,
              divisions: 49,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _budget = val),
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _rooms,
                    items: ['1', '2', '3', '4', '5+'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _rooms = val!),
                    decoration: const InputDecoration(labelText: AppStrings.roomsLabel, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 32),
                const Text('الغرض:'),
                ...AppStrings.purposes.map((p) => Expanded(
                  child: RadioListTile<String>(
                    title: Text(p),
                    value: p,
                    groupValue: _purpose,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _purpose = val!),
                  ),
                )).toList(),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _submitLead,
                child: const Text(AppStrings.sendButton, style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPropertiesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      color: Colors.grey[100],
      child: Column(
        children: [
          const Text('عقارات مميزة في طنطا', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 8),
          const Text('اخترنا لك أفضل الفرص المتاحة حالياً', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 32),
          _isLoadingProperties 
            ? const Center(child: CircularProgressIndicator())
            : _featuredProperties.isEmpty 
              ? const Text('لا توجد عقارات مميزة حالياً')
              : LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
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
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/listings'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('مشاهدة كل العقارات', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
