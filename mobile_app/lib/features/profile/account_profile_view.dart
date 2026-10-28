import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';
import 'package:delivery_marker_mobile/data/repositories/repository_provider.dart';
import 'package:delivery_marker_mobile/data/remote/api_service.dart';
import 'package:delivery_marker_mobile/data/local/backup_service.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/backup_restore_bottom_sheet.dart';
import 'package:delivery_marker_mobile/features/server_mode/change_password_view.dart';
import 'package:delivery_marker_mobile/features/server_mode/data_sharing_view.dart';
import 'package:delivery_marker_mobile/features/server_mode/login_view.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_dialogs.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_server_config_dialog.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_stats_section.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_local_actions_section.dart';
import 'package:delivery_marker_mobile/features/profile/widgets/profile_header_card.dart';

/// Màn hình Cá nhân (Local-First) & Hồ sơ tài khoản (Remote)
class AccountProfileView extends StatefulWidget {
  const AccountProfileView({super.key});

  @override
  State<AccountProfileView> createState() => _AccountProfileViewState();
}

class _AccountProfileViewState extends State<AccountProfileView> {
  UserModel? _user;
  List<Map<String, dynamic>> _areas = [];
  Map<String, int> _stats = {
    'savedLocationsCount': 0,
    'createdShiftsCount': 0,
    'uploadedPhotosCount': 0,
  };
  String _currentBaseUrl = '';
  bool _isLoading = true;
  bool _shouldShowBackupReminder = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = await RepositoryProvider.profile.getCurrentUser();
      final stats = await RepositoryProvider.profile.getMyStats();

      if (RepositoryProvider.useLocalData) {
        final reminder = await BackupService(appDb: RepositoryProvider.localProfile.appDb).shouldShowBackupReminder();
        if (mounted) {
          setState(() {
            _user = user;
            _stats = stats;
            _shouldShowBackupReminder = reminder;
            _isLoading = false;
          });
        }
      } else {
        final areas = await RepositoryProvider.profile.getMyAreas();
        final baseUrl = await ApiService.getBaseUrl();
        if (mounted) {
          setState(() {
            _user = user;
            _areas = areas;
            _stats = stats;
            _currentBaseUrl = baseUrl;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  Future<void> _showEditDisplayNameDialog() async {
    final result = await ProfileEditNameDialog.show(
      context: context,
      currentName: _user?.fullName ?? '',
    );

    if (result != null && mounted) {
      await RepositoryProvider.localProfile.updateDisplayName(result);
      await _loadProfileData();
    }
  }

  Future<void> _showServerConfigDialog() async {
    await ProfileServerConfigDialog.show(
      context: context,
      currentBaseUrl: _currentBaseUrl,
      onUrlUpdated: (newUrl) {
        if (mounted) setState(() => _currentBaseUrl = newUrl);
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Text(
                'Xác nhận đăng xuất',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không? Phiên làm việc hiện tại sẽ kết thúc.',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              key: const Key('cancel_logout_btn'),
              style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              key: const Key('confirm_logout_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await RepositoryProvider.profile.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginView()),
        (route) => false,
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    const bgCard = Colors.white;
    const borderColor = Color(0xFFE2E8F0);
    final isLocal = RepositoryProvider.useLocalData;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isLocal ? 'Cá nhân' : 'Tài khoản',
          key: const Key('profile_app_bar_title'),
          style: const TextStyle(
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
                  // THÔNG BÁO NHẮC SAO LƯU (> 14 ngày chưa sao lưu)
                  if (isLocal && _shouldShowBackupReminder) ...[
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

                  // 1. ĐẦU TRANG: Avatar, Tên
                  ProfileHeaderCard(
                    user: _user,
                    isLocal: isLocal,
                    onEditName: _showEditDisplayNameDialog,
                  ),

                  const SizedBox(height: 20),

                  // 2. KHU VỰC PHỤ TRÁCH (CHỈ HIỂN THỊ KHI REMOTE)
                  if (!isLocal) ...[
                    Container(
                      key: const Key('profile_areas_card'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.map_rounded, color: Color(0xFF0F172A), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Khu vực phụ trách',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_areas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Chưa được phân công khu vực nào',
                                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _areas.map((area) {
                                final name = area['name'] ?? 'Khu vực';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.place_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 4),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. THỐNG KÊ CỦA TÔI
                  ProfileStatsSection(stats: _stats),

                  const SizedBox(height: 20),

                  // 4. MỤC BẢO MẬT & SAO LƯU (LOCAL-FIRST)
                  if (isLocal) ...[
                    ProfileLocalActionsSection(
                      onDataReload: _loadProfileData,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. CÀI ĐẶT TÀI KHOẢN KHI REMOTE
                  if (!isLocal) ...[
                    Material(
                      color: bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ListTile(
                            key: const Key('profile_change_password_item'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF0F172A), size: 22),
                            ),
                            title: const Text(
                              'Đổi mật khẩu',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            subtitle: const Text(
                              'Cập nhật mật khẩu đăng nhập tài khoản',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordView())),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
                          ListTile(
                            key: const Key('profile_data_sharing_item'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 22),
                            ),
                            title: const Text(
                              'Chia sẻ dữ liệu',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            subtitle: const Text(
                              'Chia sẻ vị trí & ca làm việc với shipper khác',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataSharingView())),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6. THÔNG TIN HỆ THỐNG / PHIÊN BẢN
                  Material(
                    color: bgCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: borderColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (!isLocal) ...[
                          ListTile(
                            key: const Key('profile_server_config_item'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.dns_rounded, color: Color(0xFF0F172A), size: 22),
                            ),
                            title: const Text(
                              'Địa chỉ máy chủ',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            subtitle: Text(
                              _currentBaseUrl.isEmpty ? 'Đang tải...' : _currentBaseUrl,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: _showServerConfigDialog,
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
                        ],
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0F172A), size: 22),
                          ),
                          title: const Text(
                            'Phiên bản ứng dụng',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          trailing: Text(
                            isLocal ? 'v1.0.0 (Local-First)' : 'v1.0.0 (Build 1)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 7. NÚT ĐĂNG XUẤT (CHỈ HIỂN THỊ KHI REMOTE)
                  if (!isLocal) ...[
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        key: const Key('profile_logout_btn'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                          minimumSize: const Size(48, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _handleLogout,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('ĐĂNG XUẤT'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
    );
  }
}
