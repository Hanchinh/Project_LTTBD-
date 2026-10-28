import 'package:delivery_marker_mobile/models/data_share_model.dart';

abstract class SharingRepository {
  Future<List<DataShareModel>> getOutgoingShares();

  Future<List<DataShareModel>> getIncomingShares();

  Future<Map<String, dynamic>> getSharedLocations();

  Future<DataShareModel> createShare({
    required String recipientPhone,
    required String scope,
    String? shiftId,
    bool includePhotos = false,
    int? expiresInDays,
  });

  Future<void> acceptShare(String shareId);

  Future<void> declineShare(String shareId);

  Future<void> revokeShare(String shareId);

  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  });
}
