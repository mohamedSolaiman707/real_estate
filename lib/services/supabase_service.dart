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

  // Dashboard Stats (Updated to use Leads and Properties)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // 1. Get Leads Count (Since customers table is empty)
      final leadsData = await _supabase.from('leads').select('id');
      final totalLeads = (leadsData as List).length;

      // 2. Get Today's Tours (Empty for now, but keeping the logic)
      final today = DateTime.now().toIso8601String().split('T')[0];
      final toursData = await _supabase
          .from('tours')
          .select('id')
          .gte('tour_date', '$today 00:00:00')
          .lte('tour_date', '$today 23:59:59');
      final toursToday = (toursData as List).length;

      // 3. Expected Deals (Based on Leads)
      final expectedDeals = (totalLeads * 0.3).floor(); // 30% conversion estimation

      // 4. Get All Properties for Analytics
      final propsData = await _supabase.from('properties').select('type, price');
      final List<dynamic> allProps = propsData as List;
      
      Map<String, int> distribution = {};
      double totalPortfolioValue = 0;

      for (var p in allProps) {
        // Distribution
        String type = p['type'] ?? 'أخرى';
        distribution[type] = (distribution[type] ?? 0) + 1;
        
        // Portfolio Value
        totalPortfolioValue += (p['price'] as num).toDouble();
      }

      // Calculate a "Projected Commission" (e.g., 2.5% of total portfolio)
      final estimatedCommission = (totalPortfolioValue * 0.025).floor();

      return {
        'new_customers': totalLeads, // Using leads as customers
        'tours_today': toursToday,
        'expected_deals': expectedDeals,
        'commission': estimatedCommission, // This will be the Portfolio Value metric
        'distribution': distribution,
        'total_properties': allProps.length,
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
