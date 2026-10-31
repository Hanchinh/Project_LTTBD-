abstract class SharingRepository {
  Future<Map<String, dynamic>> getSharedLocations();

  Future<Map<String, dynamic>> importSharedLocations(
    String shareId, {
    List<String>? customerIds,
    bool all = true,
    bool replaceExisting = false,
  });
}
