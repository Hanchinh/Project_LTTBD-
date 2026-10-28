import 'package:delivery_marker_mobile/models/customer_photo_model.dart';

abstract class PhotoRepository {
  Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId);

  Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64);

  Future<void> deleteCustomerPhoto(String customerId, String photoId);

  Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  });
}
