import 'package:delivery_marker_mobile/models/customer_photo_model.dart';
import 'package:delivery_marker_mobile/data/remote/photo_api.dart';
import 'package:delivery_marker_mobile/data/repositories/photo_repository.dart';

class RemotePhotoRepository implements PhotoRepository {
  @override
  Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) {
    return PhotoApi.getCustomerPhotos(customerId);
  }

  @override
  Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) {
    return PhotoApi.addCustomerPhoto(customerId, imageBase64);
  }

  @override
  Future<void> deleteCustomerPhoto(String customerId, String photoId) {
    return PhotoApi.deleteCustomerPhoto(customerId, photoId);
  }

  @override
  Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  }) {
    return PhotoApi.getPhotoAuthInfo(
      photoPath,
      cacheVersion: cacheVersion,
      bustCache: bustCache,
    );
  }
}
