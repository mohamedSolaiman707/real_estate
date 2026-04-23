import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/property.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Properties
  Future<List<Property>> getProperties() async {
    final response = await _supabase
        .from('properties')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List).map((json) => Property(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? '',
      isForInvestment: json['purpose'] == 'استثمار',
    )).toList();
  }

  // Auth
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Leads/Customers
  Future<Map<String, dynamic>> createLeadOrCustomer({
    required String name,
    required String phone,
    String? email,
  }) async {
    // Check if customer exists by phone
    final existing = await _supabase
        .from('customers')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (existing != null) return existing;

    // Create new customer
    final response = await _supabase.from('customers').insert({
      'name': name,
      'phone': phone,
      'email': email,
    }).select().single();

    return response;
  }

  // Tours
  Future<void> requestTour({
    required String propertyId,
    required String customerId,
    required DateTime date,
    String? notes,
  }) async {
    await _supabase.from('tours').insert({
      'property_id': propertyId,
      'customer_id': customerId,
      'scheduled_date': date.toIso8601String().split('T')[0],
      'status': 'pending',
      'notes': notes,
    });
  }

  // Chat
  Future<void> saveMessage(Map<String, dynamic> messageData) async {
    await _supabase.from('messages').insert(messageData);
  }

  // Dashboard Stats (Updated based on your exact schema)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // 1. Get Leads (Real data from leads table)
      final leadsData = await _supabase.from('leads').select('id');
      final totalLeads = (leadsData as List).length;

      // 2. Get Today's Tours (Using scheduled_date column from your image)
      final today = DateTime.now().toIso8601String().split('T')[0];
      final toursData = await _supabase
          .from('tours')
          .select('id')
          .eq('scheduled_date', today); // Matching your column 'scheduled_date'
      final toursToday = (toursData as List).length;

      // 3. Expected Deals estimation
      final expectedDeals = (totalLeads * 0.3).floor();

      // 4. Get Properties Data (Using price and type from your image)
      final propsData = await _supabase.from('properties').select('type, price');
      final List<dynamic> allProps = propsData as List;
      
      Map<String, int> distribution = {};
      double totalPortfolioValue = 0;

      for (var p in allProps) {
        String type = p['type'] ?? 'أخرى';
        distribution[type] = (distribution[type] ?? 0) + 1;
        totalPortfolioValue += (p['price'] as num?)?.toDouble() ?? 0.0;
      }

      // Calculate a metric for "Commission" or Portfolio Impact
      final estimatedCommission = (totalPortfolioValue * 0.01).floor(); // 1% for visualization

      return {
        'new_customers': totalLeads,
        'tours_today': toursToday,
        'expected_deals': expectedDeals,
        'commission': estimatedCommission,
        'distribution': distribution,
        'total_properties': allProps.length,
      };
    } catch (e) {
      print('Supabase Stats Error: $e');
      return {
        'new_customers': 0,
        'tours_today': 0,
        'expected_deals': 0,
        'commission': 0,
        'distribution': {},
        'total_properties': 0,
      };
    }
  }
}
