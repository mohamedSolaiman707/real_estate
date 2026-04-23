import '../models/property.dart';

class DataService {
  static List<Property> getMockProperties() {
    return [
      Property(
        id: '1',
        title: 'شقة فاخرة في الحي الغربي',
        description: 'شقة واسعة بتشطيب سوبر لوكس، قريبة من الخدمات.',
        price: 1200000,
        location: 'الحي الغربي',
        images: [
          'https://images.unsplash.com/photo-1570129477492-45c003edd2be?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
          'https://images.unsplash.com/photo-1484154218962-a197022b5858?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
        ],
        bedrooms: 3,
        bathrooms: 2,
        area: 150,
        type: 'شقة',
      ),
      Property(
        id: '2',
        title: 'فيلا مودرن في الضواحي',
        description: 'فيلا مستقلة بحديقة خاصة وحمام سباحة.',
        price: 4500000,
        location: 'الضواحي',
        images: [
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
          'https://images.unsplash.com/photo-1613977257363-707ba9348227?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
        ],
        bedrooms: 5,
        bathrooms: 4,
        area: 400,
        type: 'فيلا',
        isForInvestment: true,
      ),
      Property(
        id: '3',
        title: 'محل تجاري وسط المدينة',
        description: 'موقع حيوي جداً يصلح لكافة الأنشطة التجارية.',
        price: 850000,
        location: 'وسط المدينة',
        images: [
          'https://images.unsplash.com/photo-1555636222-cae831e670b3?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
        ],
        bedrooms: 0,
        bathrooms: 1,
        area: 60,
        type: 'محل تجاري',
        isForInvestment: true,
      ),
      Property(
        id: '4',
        title: 'شقة لقطة في الحي الشرقي',
        description: 'شقة دور ثالث، بحري، سعر ممتاز لسرعة البيع.',
        price: 650000,
        location: 'الحي الشرقي',
        images: [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=60',
        ],
        bedrooms: 2,
        bathrooms: 1,
        area: 100,
        type: 'شقة',
      ),
    ];
  }
}
