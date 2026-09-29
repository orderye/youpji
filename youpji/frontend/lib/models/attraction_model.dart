import '../services/location_service.dart';

class AttractionItem {
  final String id;
  final String name;
  final String? level; // 5A, 4A, 3A...
  final String? category;
  final String? city;
  final String? district;
  final String? address;
  final String? coverImageUrl;
  final int? suggestedDurationMin;
  final List<String> tags;
  final String verificationStatus; // verified, pending, unverified
  final double? distanceMeters;
  final double? price;

  AttractionItem({
    required this.id,
    required this.name,
    this.level,
    this.category,
    this.city,
    this.district,
    this.address,
    this.coverImageUrl,
    this.suggestedDurationMin,
    this.tags = const [],
    this.verificationStatus = 'verified',
    this.distanceMeters,
    this.price,
  });

  String get formattedDistance => LocationService.formatDistance(distanceMeters);

  bool get isMuseum =>
      (category != null && (category!.contains('博物馆') || category!.contains('文化场馆'))) ||
      name.contains('博物馆');

  factory AttractionItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    return AttractionItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      level: json['level']?.toString(),
      category: json['category']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      address: json['address']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      suggestedDurationMin: (json['suggested_duration_min'] as num?)?.toInt(),
      tags: parsedTags,
      verificationStatus: json['verification_status']?.toString() ?? 'verified',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (level != null) 'level': level,
        if (category != null) 'category': category,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (address != null) 'address': address,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        'suggested_duration_min': suggestedDurationMin,
        'tags': tags,
        'verification_status': verificationStatus,
        'distance_meters': distanceMeters,
        'price': price,
      };
}
