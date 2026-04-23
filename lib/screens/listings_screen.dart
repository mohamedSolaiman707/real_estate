import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/property.dart';
import '../widgets/property_card.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _supabase = Supabase.instance.client;
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  bool _isLoading = true;
  
  String _searchQuery = '';
  RangeValues _priceRange = const RangeValues(100000, 10000000);
  final List<String> _selectedLocations = [];

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  // جلب العقارات الحقيقية من سوبابيز
  Future<void> _fetchProperties() async {
    try {
      final response = await _supabase
          .from('properties')
          .select()
          .order('created_at', ascending: false);
      
      final properties = (response as List).map((json) => Property(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        price: (json['price'] as num).toDouble(),
        location: json['location'],
        images: (json['images'] as List).map((e) => e.toString()).toList(),
        bedrooms: json['bedrooms'] ?? 0,
        bathrooms: json['bathrooms'] ?? 0,
        area: (json['area'] as num).toDouble(),
        type: json['type'],
        isForInvestment: json['purpose'] == 'استثمار',
      )).toList();

      setState(() {
        _allProperties = properties;
        _filteredProperties = properties;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching properties: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterProperties() {
    setState(() {
      _filteredProperties = _allProperties.where((p) {
        final matchesSearch = p.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                             p.location.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesPrice = p.price >= _priceRange.start && p.price <= _priceRange.end;
        final matchesLocation = _selectedLocations.isEmpty || _selectedLocations.contains(p.location);
        return matchesSearch && matchesPrice && matchesLocation;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استعرض العقارات في طنطا'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        drawer: _buildFilterDrawer(),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildSearchSection(),
                  _buildResultsInfo(),
                  _buildPropertiesGrid(),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: AppColors.primary,
      child: TextField(
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: 'ابحث عن شقة، محل، أو منطقة...',
          fillColor: Colors.white,
          filled: true,
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (val) {
          _searchQuery = val;
          _filterProperties();
        },
      ),
    );
  }

  Widget _buildResultsInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('تم العثور على ${_filteredProperties.length} عقار', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Builder(
            builder: (context) => ElevatedButton.icon(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.filter_alt_outlined),
              label: const Text('تصفية النتائج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesGrid() {
    if (_filteredProperties.isEmpty) {
      return const Expanded(child: Center(child: Text('لا توجد عقارات تطابق بحثك حالياً')));
    }
    return Expanded(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.75,
        ),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          return PropertyCard(
            property: _filteredProperties[index],
            onTap: () {
              Navigator.pushNamed(
                context,
                '/property_details',
                arguments: _filteredProperties[index],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.primary),
            child: Center(child: Text('تصفية البحث 🔍', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('نطاق السعر (ج.م)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                RangeSlider(
                  values: _priceRange,
                  min: 100000,
                  max: 10000000,
                  divisions: 100,
                  activeColor: AppColors.primary,
                  labels: RangeLabels('${(_priceRange.start/1000).toInt()}k', '${(_priceRange.end/1000).toInt()}k'),
                  onChanged: (val) {
                    setState(() => _priceRange = val);
                    _filterProperties();
                  },
                ),
                const Divider(height: 40),
                const Text('المناطق المتاحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ...AppStrings.locations.map((loc) => CheckboxListTile(
                  title: Text(loc),
                  value: _selectedLocations.contains(loc),
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val!) {
                        _selectedLocations.add(loc);
                      } else {
                        _selectedLocations.remove(loc);
                      }
                    });
                    _filterProperties();
                  },
                )),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _priceRange = const RangeValues(100000, 10000000);
                    _selectedLocations.clear();
                    _searchQuery = '';
                  });
                  _filterProperties();
                  Navigator.pop(context);
                },
                child: const Text('مسح كل الفلاتر'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
