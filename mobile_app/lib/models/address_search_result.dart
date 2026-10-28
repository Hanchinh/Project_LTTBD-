/// Mô hình kết quả tìm kiếm địa chỉ (Geocoding Result)
class AddressSearchResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? source;

  AddressSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.source,
  });

  factory AddressSearchResult.fromJson(Map<String, dynamic> json) {
    return AddressSearchResult(
      displayName: json['displayName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'latitude': latitude,
      'longitude': longitude,
      if (source != null) 'source': source,
    };
  }
}

