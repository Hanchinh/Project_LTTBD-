import 'package:delivery_marker_mobile/models/data_share_model.dart';
import 'package:delivery_marker_mobile/data/remote/sharing_api.dart';
import 'package:delivery_marker_mobile/data/repositories/sharing_repository.dart';

class RemoteSharingRepository implements SharingRepository {
  @override
  Future<List<DataShareModel>> getOutgoingShares() {
    return SharingApi.getOutgoingShares();
  }

  @override
  Future<List<DataShareModel>> getIncomingShares() {
    return SharingApi.getIncomingShares();
  }

  @override
  Future<Map<String, dynamic>> getSharedLocations() {
    return SharingApi.getSharedLocations();
  }

  @override
  Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  }) {
    return SharingApi.createShare(
      recipientPhone: recipientPhone,
      scope: scope,
      shiftId: shiftId,
      includePhotos: includePhotos,
      expiresInDays: expiresInDays,
    );
  }

  @override
  Future<void> acceptShare(String shareId) {
    return SharingApi.acceptShare(shareId);
  }

  @override
  Future<void> declineShare(String shareId) {
    return SharingApi.declineShare(shareId);
  }

  @override
  Future<void> revokeShare(String shareId) {
    return SharingApi.revokeShare(shareId);
  }

  @override
  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  }) {
    return SharingApi.importSharedLocations(
      shareId,
      customerIds: customerIds,
      all: all,
      replaceExisting: replaceExisting,
    );
  }
}
