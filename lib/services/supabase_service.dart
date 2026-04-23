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
  }

  // Auth
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Leads/Customers
  Future<void> insertLead(Map<String, dynamic> leadData) async {
    await _supabase.from('leads').insert(leadData);
  }

  // Chat
  Future<void> saveMessage(Map<String, dynamic> messageData) async {
    await _supabase.from('messages').insert(messageData);
  }

  // Dashboard Stats (Real Data from Supabase)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // 1. Get New Customers Count
      final customersResponse = await _supabase
          .from('customers')
          .select('id')
          .count(CountOption.exact);
      final customersCount = customersResponse.count;

      // 2. Get Today's Tours
      final today = DateTime.now().toIso8601String().split('T')[0];
      final toursResponse = await _supabase
          .from('tours')
          .select('id')
          .gte('tour_date', '$today 00:00:00')
          .lte('tour_date', '$today 23:59:59')
          .count(CountOption.exact);
      final toursToday = toursResponse.count;

      // 3. Get Expected Deals (from Leads)
      final leadsResponse = await _supabase
          .from('leads')
          .select('id')
          .count(CountOption.exact);
      final totalLeads = leadsResponse.count;
      final expectedDeals = ((totalLeads ?? 0) * 0.2).floor(); 

      // 4. Get Property Distribution for Chart
      final propsResponse = await _supabase.from('properties').select('type');
      final List<dynamic> props = propsResponse as List;
      Map<String, int> distribution = {};
      for (var p in props) {
        String type = p['type'] ?? 'أخرى';
        distribution[type] = (distribution[type] ?? 0) + 1;
      }

      // 5. Calculate Portfolio Value / Commission
      final pricesResponse = await _supabase.from('properties').select('price');
      double totalValue = 0;
      for (var p in pricesResponse as List) {
        totalValue += (p['price'] as num).toDouble();
      }
      final commission = (totalValue * 0.01).floor(); 

      return {
        'new_customers': customersCount ?? 0,
        'tours_today': toursToday ?? 0,
        'expected_deals': expectedDeals,
        'commission': commission,
        'distribution': distribution,
        'total_properties': props.length,
      };
    } catch (e) {
      print('Error fetching stats: $e');
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
