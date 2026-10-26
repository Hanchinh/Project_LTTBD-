import '../../models/data_share_model.dart';
import '../../services/api_service.dart';
import '../sharing_repository.dart';

class RemoteSharingRepository implements SharingRepository {
  @override
  Future<List<DataShareModel>> getOutgoingShares() {
    return ApiService.getOutgoingShares();
  }

  @override
  Future<List<DataShareModel>> getIncomingShares() {
    return ApiService.getIncomingShares();
  }

  @override
  Future<Map<String, dynamic>> getSharedLocations() {
    return ApiService.getSharedLocations();
  }

  @override
  Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  }) {
    return ApiService.createShare(
      recipientPhone: recipientPhone,
      scope: scope,
      shiftId: shiftId,
      includePhotos: includePhotos,
      expiresInDays: expiresInDays,
    );
  }

  @override
  Future<void> acceptShare(String shareId) {
    return ApiService.acceptShare(shareId);
  }

  @override
  Future<void> declineShare(String shareId) {
    return ApiService.declineShare(shareId);
  }

  @override
  Future<void> revokeShare(String shareId) {
    return ApiService.revokeShare(shareId);
  }

  @override
  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) {
    return ApiService.importSharedLocations(
      shareId,
      customerIds: customerIds,
      all: all,
      replaceExisting: replaceExisting,
    );
  }
}
