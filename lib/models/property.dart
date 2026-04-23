class Property {
  final String id;
  final String title;
  final String description;
  final double price;
  final String location;
  final String imageUrl;
  final int bedrooms;
  final int bathrooms;
  final double area;
  final String type;
  final bool isForInvestment;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.imageUrl,
    required this.bedrooms,
    required this.bathrooms,
    required this.area,
    required this.type,
    this.isForInvestment = false,
  });
}
