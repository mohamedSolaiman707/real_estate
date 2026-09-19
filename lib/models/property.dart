class Property {
  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String city;
  final List<String> images;
  final int bedrooms;
  final int bathrooms;
  final int floor;
  final int buildYear;
  final double area;
  final String type;
  final String status;
  final String finishing;
  final String folderName;
  final List<String> amenities;
  final double roi;
  final double avgRent;
  final bool isForInvestment;
  final bool isFeatured;
  final String videoUrl;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    this.city = 'طنطا',
    required this.images,
    required this.bedrooms,
    required this.bathrooms,
    this.floor = 0,
    this.buildYear = 2024,
    required this.area,
    required this.type,
    this.status = 'متاح',
    this.finishing = 'سوبر لوكس',
    this.folderName = 'عام',
    this.amenities = const [],
    this.roi = 0.0,
    this.avgRent = 0.0,
    this.isForInvestment = false,
    this.isFeatured = false,
    this.videoUrl = '',
  });

  String get mainImage => images.isNotEmpty ? images[0] : 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?ixlib=rb-4.0.3&auto=format&fit=crop&w=600&q=80';

  bool get hasVideo => videoUrl.trim().isNotEmpty;

  String get formattedPrice {
    if (price >= 1000000) {
      double millions = price / 1000000;
      String formatted = millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1);
      return '$formatted مليون ج.م';
    } else {
      return '${(price / 1000).toInt()} ألف ج.م';
    }
  }

  String get formattedArea => '${area.toInt()} م²';
}

