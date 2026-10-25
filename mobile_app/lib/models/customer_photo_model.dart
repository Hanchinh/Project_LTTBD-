class CustomerPhotoModel {
  final String id;
  final String customerId;
  final String imageUrl;
  final String? createdBy;
  final DateTime? createdAt;

  CustomerPhotoModel({
    required this.id,
    required this.customerId,
    required this.imageUrl,
    this.createdBy,
    this.createdAt,
  });

  factory CustomerPhotoModel.fromJson(Map<String, dynamic> json, {String? defaultCustomerId}) {
    return CustomerPhotoModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? json['customer_id']?.toString() ?? defaultCustomerId ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
