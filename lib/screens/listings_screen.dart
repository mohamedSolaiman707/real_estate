import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/property.dart';
import '../services/data_service.dart';
import '../widgets/property_card.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  String _searchQuery = '';
  RangeValues _priceRange = const RangeValues(100000, 5000000);
  final List<String> _selectedLocations = [];

  @override
  void initState() {
    super.initState();
    _allProperties = DataService.getMockProperties();
    _filteredProperties = _allProperties;
  }

  void _filterProperties() {
    setState(() {
      _filteredProperties = _allProperties.where((p) {
        final matchesSearch = p.title.contains(_searchQuery) || p.location.contains(_searchQuery);
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
          title: const Text('استعرض العقارات'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        drawer: _buildFilterDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'ابحث عن عقار أو منطقة...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _filterProperties();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تم العثور على ${_filteredProperties.length} عقار'),
                  Builder(
                    builder: (context) => TextButton.icon(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.filter_list),
                      label: const Text('تصفية'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredProperties.isEmpty
                  ? const Center(child: Text('لا توجد نتائج تطابق بحثك'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DrawerHeader(
            child: Text('تصفية النتائج', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const Text('نطاق السعر', style: TextStyle(fontWeight: FontWeight.bold)),
          RangeSlider(
            values: _priceRange,
            min: 100000,
            max: 5000000,
            divisions: 20,
            labels: RangeLabels('${_priceRange.start.toInt()}', '${_priceRange.end.toInt()}'),
            onChanged: (val) {
              setState(() => _priceRange = val);
              _filterProperties();
            },
          ),
          const Divider(),
          const Text('الموقع', style: TextStyle(fontWeight: FontWeight.bold)),
          ...AppStrings.locations.map((loc) => CheckboxListTile(
                title: Text(loc),
                value: _selectedLocations.contains(loc),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _priceRange = const RangeValues(100000, 5000000);
                _selectedLocations.clear();
                _searchQuery = '';
              });
              _filterProperties();
              Navigator.pop(context);
            },
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }
}
