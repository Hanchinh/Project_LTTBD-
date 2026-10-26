import '../../models/customer_photo_model.dart';
import '../../services/api_service.dart';
import '../photo_repository.dart';

class RemotePhotoRepository implements PhotoRepository {
  @override
  Future<List<CustomerPhotoModel>> getCustomerPhotos(String customerId) {
    return ApiService.getCustomerPhotos(customerId);
  }

  @override
  Future<CustomerPhotoModel> addCustomerPhoto(String customerId, String imageBase64) {
    return ApiService.addCustomerPhoto(customerId, imageBase64);
  }

  @override
  Future<void> deleteCustomerPhoto(String customerId, String photoId) {
    return ApiService.deleteCustomerPhoto(customerId, photoId);
  }

  @override
  Future<Map<String, String>> getPhotoAuthInfo(
    String photoPath, {
    int? cacheVersion,
    bool bustCache = false,
  }) {
    return ApiService.getPhotoAuthInfo(
      photoPath,
      cacheVersion: cacheVersion,
      bustCache: bustCache,
    );
  }
}
