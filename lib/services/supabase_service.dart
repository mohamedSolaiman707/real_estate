import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/property.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  bool isOffline = false;

  Future<void> _saveCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json.encode(data));
    } catch (e) {
      debugPrint('Error saving cache for $key: $e');
    }
  }

  Future<dynamic> _getCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString(key);
      if (cached != null) {
        return json.decode(cached);
      }
    } catch (e) {
      debugPrint('Error getting cache for $key: $e');
    }
    return null;
  }

  Property _mapJsonToProperty(dynamic json) {
    final loc = json['location']?.toString() ?? '';
    final fld = (json['folder_name'] ?? json['folder_id'] ?? '').toString();
    final combinedSearch = '$loc $fld';

    String city = 'طنطا';
    if (combinedSearch.contains('القاهرة') || 
        combinedSearch.contains('التجمع') || 
        combinedSearch.contains('زايد') || 
        combinedSearch.contains('المعادي') || 
        combinedSearch.contains('مدينة نصر') || 
        combinedSearch.contains('الشروق') || 
        combinedSearch.contains('أكتوبر')) {
      city = 'القاهرة';
    }

    return Property(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      location: loc,
      city: city,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      floor: json['floor'] ?? 0,
      buildYear: json['build_year'] ?? 2024,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? 'شقة',
      status: json['status'] ?? 'متاح',
      finishing: json['finishing'] ?? 'سوبر لوكس',
      folderName: json['folder_name'] ?? json['folder_id'] ?? 'عام',
      amenities: (json['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      roi: (json['roi'] as num?)?.toDouble() ?? 0.0,
      avgRent: (json['avg_rent'] as num?)?.toDouble() ?? 0.0,
      isForInvestment: json['purpose'] == 'استثمار' || (json['roi'] != null && (json['roi'] as num) > 0),
      isFeatured: json['is_featured'] ?? false,
      videoUrl: json['video_url']?.toString() ?? '',
    );
  }

  // Leads Caching Function
  Future<List<Map<String, dynamic>>> getLeads({bool useCacheOnly = false}) async {
    final cacheKey = 'leads_list';
    if (useCacheOnly) {
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final response = await _supabase
          .from('leads')
          .select()
          .order('created_at', ascending: false);
      isOffline = false;
      await _saveCache(cacheKey, response);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting leads: $e');
      isOffline = true;
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }
  }

  // Properties
  // [staffView] = true  → يجيب كل العقارات بما فيها المباعة (للوحة تحكم الموظف)
  // [staffView] = false → يستثني العقارات المباعة (للعملاء والشات والموقع)
  Future<List<Property>> getProperties({bool staffView = false, bool useCacheOnly = false}) async {
    final cacheKey = 'properties_staffView_$staffView';
    if (useCacheOnly) {
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return (cachedData as List).map((json) => _mapJsonToProperty(json)).toList();
      }
      return [];
    }

    try {
      // ── العقارات المباعة لا تظهر للعملاء أبداً ──
      final response = staffView
          ? await _supabase.from('properties').select().order('created_at', ascending: false)
          : await _supabase.from('properties').select().neq('status', 'مباع').order('created_at', ascending: false);

      isOffline = false;
      await _saveCache(cacheKey, response);
      return (response as List).map((json) => _mapJsonToProperty(json)).toList();
    } catch (e) {
      debugPrint('Error getting properties: $e');
      isOffline = true;
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return (cachedData as List).map((json) => _mapJsonToProperty(json)).toList();
      }
      return [];
    }
  }

  Future<bool> updateProperty(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('properties').update(data).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating property: $e');
      return false;
    }
  }

  Future<bool> updatePropertyStatus(String id, String status) async {
    try {
      await _supabase.from('properties').update({'status': status}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating property status: $e');
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {
    try {
      await _supabase.from('properties').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting property: $e');
      return false;
    }
  }

  // ─── Folders / Areas (ديناميك من قاعدة البيانات) ──────────────────────────
  Future<List<String>> getFolders() async {
    try {
      final response = await _supabase
          .from('folders')
          .select('name')
          .order('created_at', ascending: true);
      final names = (response as List).map((r) => r['name'].toString()).toList();
      return ['الكل', ...names];
    } catch (e) {
      debugPrint('Error fetching folders: $e');
      // fallback للفولدرات الافتراضية لو فيه مشكلة في الاتصال
      return ['الكل', 'طنطا - شارع الاستاد', 'طنطا - شارع البحر', 'القاهرة - التجمع الخامس'];
    }
  }

  Future<bool> addFolder(String name) async {
    try {
      await _supabase.from('folders').insert({'name': name.trim()});
      return true;
    } catch (e) {
      debugPrint('Error adding folder: $e');
      return false;
    }
  }

  Future<bool> deleteFolder(String name) async {
    try {
      await _supabase.from('folders').delete().eq('name', name);
      return true;
    } catch (e) {
      debugPrint('Error deleting folder: $e');
      return false;
    }
  }

  Future<bool> updateCustomerNotes(String customerId, String newNotes) async {
    try {
      await _supabase.from('customers').update({'notes': newNotes}).eq('id', customerId);
      return true;
    } catch (e) {
      debugPrint('Error updating customer notes: $e');
      return false;
    }
  }

  // Auth
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Leads & Customers Pipeline
  Future<Map<String, dynamic>> convertLeadToCustomer({
    required String leadId,
    required String name,
    required String phone,
    String? email,
    String status = 'Hot',
    String? notes,
    Map<String, dynamic>? formData,
  }) async {
    try {
      int? parsedBudget;
      if (formData?['budget'] != null) {
        final b = formData!['budget'];
        if (b is num) {
          parsedBudget = b.toInt();
        } else if (b is String) {
          final n = num.tryParse(b.replaceAll(RegExp(r'[^\d.]'), ''));
          if (n != null) {
            parsedBudget = n.toInt();
          }
        }
      }

      // 1. Insert into customers table
      final customerResponse = await _supabase.from('customers').insert({
        'name': name,
        'phone': phone,
        'email': email,
        'status': status,
        'notes': notes ?? formData?['chat_summary'] ?? 'عميل محول من طلبات الموقع',
        'property_type': formData?['property_type'] ?? formData?['preference'],
        'location': formData?['location'] ?? formData?['region'],
        'budget': parsedBudget,
        'purpose': formData?['purpose'] ?? formData?['intent'],
        'source': 'leads_conversion',
        'converted': true,
        'conversion_date': DateTime.now().toIso8601String(),
      }).select().single();

      final customerId = customerResponse['id'];

      // 2. Update lead status to converted
      await _supabase.from('leads').update({
        'converted': true,
        'customer_id': customerId,
        'is_qualified': true,
      }).eq('id', leadId);

      // 3. Log initial interaction
      await logCustomerInteraction(
        customerId: customerId,
        type: 'conversion',
        notes: 'تم تحويل الطلب إلى عميل مؤهل بنجاح ($status)',
      );

      return customerResponse;
    } catch (e) {
      debugPrint('Error converting lead: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers({bool useCacheOnly = false}) async {
    final cacheKey = 'customers_list';
    if (useCacheOnly) {
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final response = await _supabase.from('customers').select().order('created_at', ascending: false);
      isOffline = false;
      await _saveCache(cacheKey, response);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      isOffline = true;
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }
  }

  // Log Interactions
  Future<void> logCustomerInteraction({
    required String customerId,
    required String type,
    required String notes,
    String outcome = 'متابعة مستمرة',
  }) async {
    try {
      await _supabase.from('customer_interactions').insert({
        'customer_id': customerId,
        'type': type,
        'notes': notes,
        'outcome': outcome,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error logging interaction: $e');
    }
  }

  // Tours Management
  Future<void> requestTour({
    required String propertyId,
    required String name,
    required String phone,
    required DateTime date,
    String? notes,
  }) async {
    try {
      // 1. Create or get customer
      final customer = await _supabase.from('customers').select('id').eq('phone', phone).maybeSingle();
      String customerId;
      if (customer != null) {
        customerId = customer['id'];
      } else {
        final newCust = await _supabase.from('customers').insert({
          'name': name,
          'phone': phone,
          'status': 'Warm',
          'source': 'tour_request'
        }).select('id').single();
        customerId = newCust['id'];
      }

      // 2. Insert tour
      await _supabase.from('tours').insert({
        'property_id': propertyId,
        'customer_id': customerId,
        'scheduled_date': date.toIso8601String().split('T')[0],
        'status': 'scheduled',
        'notes': notes ?? 'طلب معاينة عبر التطبيق',
      });
    } catch (e) {
      debugPrint('Error requesting tour: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTours({bool useCacheOnly = false}) async {
    final cacheKey = 'tours_list';
    if (useCacheOnly) {
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }

    try {
      final response = await _supabase
          .from('tours')
          .select('*, properties(title, location), customers(name, phone)')
          .order('scheduled_date', ascending: false);
      isOffline = false;
      await _saveCache(cacheKey, response);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching tours: $e');
      isOffline = true;
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }
      return [];
    }
  }

  Future<void> updateTourStatus(String tourId, String status, {String? feedback}) async {
    try {
      Map<String, dynamic> updateData = {'status': status};
      if (status == 'completed') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }
      if (feedback != null) {
        updateData['next_steps'] = feedback;
      }
      await _supabase.from('tours').update(updateData).eq('id', tourId);
    } catch (e) {
      debugPrint('Error updating tour: $e');
    }
  }

  Future<void> updateTourDetails({
    required String tourId,
    String? status,
    String? scheduledDate,
    String? notes,
    String? nextSteps,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (status != null) updateData['status'] = status;
      if (scheduledDate != null) updateData['scheduled_date'] = scheduledDate;
      if (notes != null) updateData['notes'] = notes;
      if (nextSteps != null) updateData['next_steps'] = nextSteps;
      if (status == 'completed') {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }
      await _supabase.from('tours').update(updateData).eq('id', tourId);
    } catch (e) {
      debugPrint('Error updating tour details: $e');
      rethrow;
    }
  }

  // Dashboard Stats
  Future<Map<String, dynamic>> getDashboardStats({bool useCacheOnly = false}) async {
    final cacheKey = 'dashboard_stats';
    if (useCacheOnly) {
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
      return {
        'new_customers': 0,
        'converted_customers': 0,
        'conversion_rate': '0.0',
        'tours_today': 0,
        'expected_deals': 0,
        'commission': 0,
        'distribution': {},
        'total_properties': 0,
        'total_portfolio_value': 0.0,
        'cairo_properties': 0,
        'cairo_value': 0.0,
        'tanta_properties': 0,
        'tanta_value': 0.0,
      };
    }

    try {
      final leadsData = await _supabase.from('leads').select('id');
      final totalLeads = (leadsData as List).length;

      final customersData = await _supabase.from('customers').select('id, status, converted');
      final totalCustomers = (customersData as List).length;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final toursData = await _supabase
          .from('tours')
          .select('id')
          .eq('scheduled_date', today);
      final toursToday = (toursData as List).length;

      final propsData = await _supabase.from('properties').select('type, price, location');
      final List<dynamic> allProps = propsData as List;
      
      Map<String, int> distribution = {};
      int cairoCount = 0;
      int tantaCount = 0;
      double cairoValue = 0;
      double tantaValue = 0;
      double totalPortfolioValue = 0;

      for (var p in allProps) {
        String type = p['type'] ?? 'أخرى';
        String loc = p['location']?.toString() ?? '';
        double price = (p['price'] as num?)?.toDouble() ?? 0.0;
        
        distribution[type] = (distribution[type] ?? 0) + 1;
        totalPortfolioValue += price;

        if (loc.contains('القاهرة') || loc.contains('التجمع') || loc.contains('زايد') || loc.contains('المعادي')) {
          cairoCount++;
          cairoValue += price;
        } else {
          tantaCount++;
          tantaValue += price;
        }
      }

      final estimatedCommission = (totalPortfolioValue * 0.015).floor();
      final convertedCount = (customersData as List).where((c) => c['converted'] == true).length;
      final totalPipeline = totalLeads + totalCustomers;
      final conversionRate = totalPipeline > 0 ? ((convertedCount / totalPipeline) * 100).toStringAsFixed(1) : '0.0';

      final result = {
        'new_customers': totalPipeline,
        'converted_customers': convertedCount,
        'conversion_rate': conversionRate,
        'tours_today': toursToday,
        'expected_deals': ((totalLeads + totalCustomers) * 0.35).floor(),
        'commission': estimatedCommission,
        'distribution': distribution,
        'total_properties': allProps.length,
        'total_portfolio_value': totalPortfolioValue,
        'cairo_properties': cairoCount,
        'cairo_value': cairoValue,
        'tanta_properties': tantaCount,
        'tanta_value': tantaValue,
      };

      isOffline = false;
      await _saveCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('Supabase Stats Error: $e');
      isOffline = true;
      final cachedData = await _getCache(cacheKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
      return {
        'new_customers': 0,
        'converted_customers': 0,
        'conversion_rate': '0.0',
        'tours_today': 0,
        'expected_deals': 0,
        'commission': 0,
        'distribution': {},
        'total_properties': 0,
        'total_portfolio_value': 0.0,
        'cairo_properties': 0,
        'cairo_value': 0.0,
        'tanta_properties': 0,
        'tanta_value': 0.0,
      };
    }
  }
}
