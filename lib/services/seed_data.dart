import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SeedDataService {
  static Future<void> seedInitialProperties() async {
    final supabase = Supabase.instance.client;

    final sampleProperties = [
      // عقارات القاهرة
      {
        'title': 'شقة فاخرة للبيع في التجمع الخامس - النرجس',
        'type': 'شقة',
        'location': 'التجمع الخامس (القاهرة)',
        'price': 4200000,
        'area': 195,
        'bedrooms': 3,
        'bathrooms': 2,
        'floor': 2,
        'build_year': 2023,
        'description': 'شقة بتشطيب ألترا سوبر لوكس، مطلة على حديقة كبيرة، قريب من التسعين الجنوبي والخدمات. فيلا في النرجس عمارات.',
        'amenities': ['مصعد', 'أمن 24/7', 'جراج خاص', 'تشطيب سوبر لوكس', 'تكييف مركزي'],
        'images': [
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
        ],
        'roi': 14.5,
        'avg_rent': 22000,
        'purpose': 'بيع',
        'status': 'متاح',
        'is_featured': true,
        'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      },
      {
        'title': 'فيلا مودرن للبيع في الشيخ زايد - كمبوند درة',
        'type': 'فيلا',
        'location': 'الشيخ زايد (القاهرة)',
        'price': 12500000,
        'area': 380,
        'bedrooms': 5,
        'bathrooms': 4,
        'floor': 0,
        'build_year': 2024,
        'description': 'فيلا مستقلة بحمام سباحة وحديقة خاصة، موقع مميز داخل كمبوند راقي بالشيخ زايد بالتقسيط على 5 سنوات.',
        'amenities': ['حمام سباحة', 'حديقة خاصة', 'أمن 24/7', 'جراج خاص', 'تكييف مركزي'],
        'images': [
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
        ],
        'roi': 12.0,
        'avg_rent': 60000,
        'purpose': 'بيع',
        'status': 'متاح',
        'is_featured': true,
      },
      {
        'title': 'محل تجاري للاستثمار في العاصمة الإدارية',
        'type': 'محل تجاري',
        'location': 'العاصمة الإدارية (القاهرة)',
        'price': 3100000,
        'area': 45,
        'bedrooms': 0,
        'bathrooms': 1,
        'floor': 1,
        'build_year': 2024,
        'description': 'محل تجاري بمنطقة الـ Downtown بأعلى عائد استثماري مؤجر لإحدى البراندات الشهيرة.',
        'amenities': ['أمن 24/7', 'مصعد', 'تكييف مركزي'],
        'roi': 16.0,
        'avg_rent': 28000,
        'purpose': 'استثمار',
        'status': 'متاح',
        'is_featured': true,
      },
      // عقارات طنطا
      {
        'title': 'شقة لقطة للبيع في طنطا - شارع البحر',
        'type': 'شقة',
        'location': 'شارع البحر (طنطا)',
        'price': 1850000,
        'area': 140,
        'bedrooms': 3,
        'bathrooms': 2,
        'floor': 4,
        'build_year': 2022,
        'description': 'شقة واجهة بحرية بالكامل على شارع البحر الرئيسي بطنطا، تشطيب هاي لوكس، برج حديث بـ 2 أسانسير.',
        'amenities': ['مصعد', 'أمن 24/7', 'تشطيب سوبر لوكس'],
        'images': [
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
        ],
        'roi': 11.5,
        'avg_rent': 8500,
        'purpose': 'بيع',
        'status': 'متاح',
        'is_featured': true,
      },
      {
        'title': 'شقة ممتازة للإيجار في طنطا - منطقة الاستاد',
        'type': 'شقة',
        'location': 'منطقة الاستاد (طنطا)',
        'price': 6500,
        'area': 120,
        'bedrooms': 2,
        'bathrooms': 1,
        'floor': 3,
        'build_year': 2023,
        'description': 'شقة مفروشة بالكامل تكييفات وأجهزة كهربائية حديثة في أرقى مناطق طنطا قريب من الاستاد والخدمات.',
        'amenities': ['مصعد', 'تكييف مركزي', 'تشطيب سوبر لوكس'],
        'images': [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'
        ],
        'roi': 0.0,
        'avg_rent': 6500,
        'purpose': 'إيجار',
        'status': 'متاح',
        'is_featured': false,
      },
      {
        'title': 'محل تجاري للبيع في الحي الغربي - طنطا',
        'type': 'محل تجاري',
        'location': 'الحي الغربي (طنطا)',
        'price': 1200000,
        'area': 55,
        'bedrooms': 0,
        'bathrooms': 1,
        'floor': 0,
        'build_year': 2021,
        'description': 'محل تجاري واجهة عريضة على شارع تجاري حيوى جداً يصلح لكافة الأنشطة الصيدليات والمطاعم.',
        'amenities': ['أمن 24/7'],
        'roi': 13.0,
        'avg_rent': 9000,
        'purpose': 'بيع',
        'status': 'متاح',
        'is_featured': false,
      }
    ];

    try {
      for (var prop in sampleProperties) {
        await supabase.from('properties').insert(prop);
      }
      debugPrint('Seed Properties Completed Successfully!');
    } catch (e) {
      debugPrint('Seed Properties Error: $e');
      rethrow;
    }
  }
}
