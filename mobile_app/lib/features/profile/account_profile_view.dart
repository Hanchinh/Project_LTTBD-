import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/data/local/backup_service.dart';
import 'package:delivery_marker_mobile/data/local/app_storage_service.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/backup_restore_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_dialogs.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_stats_section.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_local_actions_section.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_header_card.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_storage_section.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_about_section.dart';

/// Màn hình quản lý thông tin Cá nhân & Thiết lập Local-First
class AccountProfileView extends StatefulWidget {
  const AccountProfileView({super.key});

  @override
  State<AccountProfileView> createState() => _AccountProfileViewState();
}

class _AccountProfileViewState extends State<AccountProfileView> {
  UserModel? _user;
  Map<String, int> _myStats = {'savedLocationsCount': 0, 'createdShiftsCount': 0, 'uploadedPhotosCount': 0};
  AppStorageStats? _storageStats;
  bool _isLoading = true;
  bool _isClearingCache = false;
  bool _shouldShowBackupReminder = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = await RepositoryProvider.localProfile.getCurrentUser();
      final stats = await RepositoryProvider.localProfile.getMyStats();
      final storage = await AppStorageService().getStorageStats();
      final backupReminder = await BackupService().shouldShowBackupReminder();

      if (mounted) {
        setState(() {
          _user = user;
          _myStats = stats;
          _storageStats = storage;
          _shouldShowBackupReminder = backupReminder;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClearCache() async {
    setState(() => _isClearingCache = true);
    try {
      final freed = await AppStorageService().clearCache();
      final updatedStorage = await AppStorageService().getStorageStats();
      if (mounted) {
        setState(() {
          _storageStats = updatedStorage;
          _isClearingCache = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã dọn dẹp ${AppStorageService.formatBytes(freed)} bộ nhớ đệm.'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _showEditDisplayNameDialog() async {
    final currentName = _user?.fullName ?? '';
    final newName = await ProfileEditNameDialog.show(context: context, currentName: currentName);
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await RepositoryProvider.localProfile.updateDisplayName(newName);
      _loadProfileData();
    }
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Cá nhân',
          key: Key('profile_app_bar_title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: const Color(0xFF0F172A),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // Nhắc nhở sao lưu nếu > 14 ngày
                  if (_shouldShowBackupReminder) ...[
                    Container(
                      key: const Key('backup_reminder_card'),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Bạn chưa sao lưu dữ liệu hơn 14 ngày. Hãy sao lưu định kỳ để bảo vệ ảnh và vị trí.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
                            ),
                          ),
                          TextButton(
                            key: const Key('btn_backup_now'),
                            onPressed: () => BackupRestoreBottomSheet.show(context, onRestored: _loadProfileData),
                            child: const Text('Sao lưu ngay', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Thông tin cá nhân & Đổi tên
                  ProfileHeaderCard(
                    user: _user,
                    isLocal: true,
                    onEditName: _showEditDisplayNameDialog,
                  ),

                  const SizedBox(height: 20),

                  // 2. Thống kê của tôi
                  ProfileStatsSection(stats: _myStats),

                  const SizedBox(height: 20),

                  // 3. Bảo mật PIN, Sao lưu & Chia sẻ dữ liệu
                  ProfileLocalActionsSection(onDataReload: _loadProfileData),

                  const SizedBox(height: 20),

                  // 4. Dung lượng lưu trữ & Dọn cache
                  ProfileStorageSection(
                    storageStats: _storageStats,
                    isClearingCache: _isClearingCache,
                    onClearCache: _handleClearCache,
                  ),

                  const SizedBox(height: 20),

                  // 5. Phiên bản & Bản quyền bản đồ
                  const ProfileAboutSection(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
