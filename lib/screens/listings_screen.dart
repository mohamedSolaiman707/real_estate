import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/property.dart';
import '../widgets/property_card.dart';
import '../services/supabase_service.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _supabaseService = SupabaseService();
  List<Property> _allProperties = [];
  List<Property> _filteredProperties = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedCity = 'الكل';
  String _selectedType = 'الكل';
  String _selectedPurpose = 'الكل';
  String _selectedFinishing = 'الكل';

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    try {
      final properties = await _supabaseService.getProperties();

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
        final matchesSearch = _searchQuery.isEmpty ||
            p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.location.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCity =
            _selectedCity == 'الكل' || p.city == _selectedCity || p.location.contains(_selectedCity);
        final matchesType = _selectedType == 'الكل' || p.type == _selectedType;
        final matchesPurpose = _selectedPurpose == 'الكل' ||
            (_selectedPurpose == 'بيع' && !p.isForInvestment) ||
            (_selectedPurpose == 'استثمار' && p.isForInvestment);
        final matchesFinishing = _selectedFinishing == 'الكل' || p.finishing.contains(_selectedFinishing);

        return matchesSearch && matchesCity && matchesType && matchesPurpose && matchesFinishing;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCity = 'الكل';
      _selectedType = 'الكل';
      _selectedPurpose = 'الكل';
      _selectedFinishing = 'الكل';
      _filteredProperties = List.from(_allProperties);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('دليل العقارات في طنطا والقاهرة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            tooltip: 'رجوع للرئيسية',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  _buildSearchAndFiltersHeader(isDesktop),
                  _buildResultsBar(),
                  _buildPropertiesGrid(isDesktop),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchAndFiltersHeader(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isDesktop ? 20 : 14),
      child: Column(
        children: [
          // Search box
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _filterProperties();
            },
            decoration: InputDecoration(
              hintText: 'ابحث عن شقة، فيلا، محل تجاري، التجمع، شارع البحر...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              filled: true,
              fillColor: const Color(0xFFF0F4F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Row / Wrap
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // City Filter
                _buildFilterDropdown(
                  label: 'المحافظة',
                  icon: Icons.location_city_rounded,
                  value: _selectedCity,
                  items: ['الكل', 'طنطا', 'القاهرة'],
                  onChanged: (val) {
                    setState(() => _selectedCity = val!);
                    _filterProperties();
                  },
                ),
                const SizedBox(width: 8),

                // Type Filter
                _buildFilterDropdown(
                  label: 'النوع',
                  icon: Icons.home_work_rounded,
                  value: _selectedType,
                  items: ['الكل', ...AppStrings.propertyTypes],
                  onChanged: (val) {
                    setState(() => _selectedType = val!);
                    _filterProperties();
                  },
                ),
                const SizedBox(width: 8),

                // Purpose Filter
                _buildFilterDropdown(
                  label: 'الغرض',
                  icon: Icons.sell_rounded,
                  value: _selectedPurpose,
                  items: ['الكل', 'بيع', 'إيجار', 'استثمار'],
                  onChanged: (val) {
                    setState(() => _selectedPurpose = val!);
                    _filterProperties();
                  },
                ),
                const SizedBox(width: 8),

                // Finishing Filter
                _buildFilterDropdown(
                  label: 'التشطيب',
                  icon: Icons.home_repair_service_rounded,
                  value: _selectedFinishing,
                  items: ['الكل', ...AppStrings.finishingTypes],
                  onChanged: (val) {
                    setState(() => _selectedFinishing = val!);
                    _filterProperties();
                  },
                ),
                const SizedBox(width: 12),

                // Reset Button
                if (_selectedCity != 'الكل' || _selectedType != 'الكل' || _selectedPurpose != 'الكل' || _selectedFinishing != 'الكل' || _searchQuery.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.refresh_rounded, size: 16, color: Colors.red),
                    label: const Text('إعادة ضبط', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                    backgroundColor: Colors.red.withOpacity(0.08),
                    onPressed: _resetFilters,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
            items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFEFEFF4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'تم العثور على ${_filteredProperties.length} عقارات متاحة',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          if (_filteredProperties.isNotEmpty)
            const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                SizedBox(width: 4),
                Text('تحديث فوري', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPropertiesGrid(bool isDesktop) {
    if (_filteredProperties.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('لا توجد عقارات تطابق بحثك حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('جرب البحث بمحافظة أو نوع آخر أو امسح الفلاتر', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('عرض كل العقارات المتاحة'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 1100
              ? 4
              : (constraints.maxWidth > 700 ? 2 : 1);
          return GridView.builder(
            padding: EdgeInsets.all(isDesktop ? 20 : 14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.78,
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
          );
        },
      ),
    );
  }
}
