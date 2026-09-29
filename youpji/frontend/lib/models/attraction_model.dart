import '../services/location_service.dart';

class AttractionItem {
  final String id;
  final String name;
  final String? level; // 5A, 4A, 3A...
  final String? city;
  final String? district;
  final String? address;
  final int? suggestedDurationMin;
  final List<String> tags;
  final String verificationStatus; // verified, pending, unverified
  final double? distanceMeters;
  final double? price;

  AttractionItem({
    required this.id,
    required this.name,
    this.level,
    this.city,
    this.district,
    this.address,
    this.suggestedDurationMin,
    this.tags = const [],
    this.verificationStatus = 'verified',
    this.distanceMeters,
    this.price,
  });

  String get formattedDistance => LocationService.formatDistance(distanceMeters);

  factory AttractionItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    return AttractionItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      level: json['level']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      address: json['address']?.toString(),
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
        'level': level,
        'city': city,
        'district': district,
        'address': address,
        'suggested_duration_min': suggestedDurationMin,
        'tags': tags,
        'verification_status': verificationStatus,
        'distance_meters': distanceMeters,
        'price': price,
      };
}
