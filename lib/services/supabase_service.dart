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

  // Dashboard Stats (Example)
  Future<Map<String, dynamic>> getDashboardStats() async {
    // This would ideally be a RPC or multiple queries
    final customersCount = await _supabase.from('customers').count();
    // Simplified for demo
    return {
      'new_customers': customersCount,
      'tours_today': 5,
      'expected_deals': 2,
      'commission': 15000,
    };
  }
}
