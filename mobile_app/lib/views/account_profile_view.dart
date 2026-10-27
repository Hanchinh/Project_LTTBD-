import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../repositories/repository_provider.dart';
import '../services/api_service.dart';
import '../services/backup_service.dart';
import '../theme/app_buttons.dart';
import '../widgets/backup_restore_bottom_sheet.dart';
import '../widgets/data_share_import_preview_sheet.dart';
import '../widgets/data_share_qr_scanner_view.dart';
import '../widgets/data_share_send_sheet.dart';
import '../widgets/pin_settings_bottom_sheet.dart';
import 'change_password_view.dart';
import 'data_sharing_view.dart';
import 'login_view.dart';

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

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _getRoleLabel(String? role) {
    if (role == null) return 'Người dùng';
    final upper = role.toUpperCase();
    if (upper == 'ADMIN') return 'Quản trị viên';
    if (upper == 'SHIPPER') return 'Nhân viên giao hàng';
    return role;
  }

  String _formatPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '${clean.substring(0, 4)} ${clean.substring(4, 7)} ${clean.substring(7)}';
    }
    return phone;
  }

  Future<void> _showEditDisplayNameDialog() async {
    final controller = TextEditingController(text: _user?.fullName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi tên hiển thị', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          key: const Key('edit_display_name_input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Họ và tên của bạn',
            hintText: 'Nhập tên mới...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY')),
          ElevatedButton(
            key: const Key('edit_display_name_save_btn'),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await RepositoryProvider.localProfile.updateDisplayName(result);
      await _loadProfileData();
    }
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(text: _currentBaseUrl);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.dns_rounded, color: Color(0xFF0F172A), size: 24),
              SizedBox(width: 10),
              Text(
                'Cấu hình máy chủ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Địa chỉ API Backend (ví dụ: http://10.0.2.2:3000/api/v1):',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('account_server_url_input'),
                  controller: controller,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'http://...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập địa chỉ máy chủ';
                    }
                    if (!val.startsWith('http://') && !val.startsWith('https://')) {
                      return 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              style: AppButtons.text(minHeight: 48),
              onPressed: () async {
                await ApiService.resetCustomBaseUrl();
                final defUrl = await ApiService.getBaseUrl();
                if (mounted) {
                  setState(() => _currentBaseUrl = defUrl);
                }
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop('Đã khôi phục địa chỉ máy chủ mặc định');
                }
              },
              child: const Text('Mặc định', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              key: const Key('account_server_url_save_btn'),
              style: AppButtons.primary(minHeight: 48, borderRadius: 10),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newUrl = controller.text.trim();
                  await ApiService.setCustomBaseUrl(newUrl);
                  if (mounted) {
                    setState(() => _currentBaseUrl = newUrl);
                  }
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop('Đã cập nhật địa chỉ máy chủ');
                  }
                }
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
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

  Future<void> _openReceiveShareDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Chọn phương thức nhận dữ liệu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ListTile(
              key: const Key('btn_receive_scan_qr'),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              title: const Text('Quét mã QR từ máy khác', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Nhận dữ liệu nhanh trực tiếp bằng camera', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.pop(ctx);
                DataShareQrScannerView.show(context, onImportSuccess: _loadProfileData);
              },
            ),
            const Divider(height: 1, indent: 64),
            ListTile(
              key: const Key('btn_receive_open_file'),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_open_rounded, color: Color(0xFF16A34A), size: 24),
              ),
              title: const Text('Mở tệp chia sẻ (.dshare)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Chọn tệp đã lưu trong máy hoặc tải về từ Zalo/Drive', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final files = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['dshare', 'zip'],
                  );
                  if (files.isNotEmpty && files.first.path != null) {
                    final pickedFile = File(files.first.path!);
                    if (mounted) {
                      DataShareImportPreviewSheet.showFromFile(
                        context,
                        file: pickedFile,
                        onImportSuccess: _loadProfileData,
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi mở tệp: $e'), backgroundColor: const Color(0xFFDC2626)),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
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
                  Container(
                    key: const Key('profile_header_card'),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(
                            _getInitials(_user?.fullName ?? 'U'),
                            key: const Key('user_avatar_initials'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _user?.fullName ?? 'Người dùng',
                                      key: const Key('user_full_name'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (isLocal)
                                    IconButton(
                                      key: const Key('btn_edit_display_name'),
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
                                      onPressed: _showEditDisplayNameDialog,
                                      tooltip: 'Đổi tên hiển thị',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (isLocal)
                                const Text(
                                  'Chế độ Local-First (Dữ liệu trên máy)',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                )
                              else ...[
                                Text(
                                  _formatPhoneNumber(_user?.phoneNumber ?? ''),
                                  key: const Key('user_phone_number'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  key: const Key('user_role_badge'),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    _getRoleLabel(_user?.role),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  Container(
                    key: const Key('profile_stats_card'),
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
                            Icon(Icons.bar_chart_rounded, color: Color(0xFF0F172A), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Thống kê của tôi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatTile(
                                label: 'Vị trí đã lưu',
                                count: _stats['savedLocationsCount'] ?? 0,
                                icon: Icons.place_rounded,
                                color: const Color(0xFF2563EB),
                                bgColor: const Color(0xFFEFF6FF),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatTile(
                                label: 'Ca đã tạo',
                                count: _stats['createdShiftsCount'] ?? 0,
                                icon: Icons.assignment_rounded,
                                color: const Color(0xFF16A34A),
                                bgColor: const Color(0xFFF0FDF4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatTile(
                                label: 'Ảnh đã tải',
                                count: _stats['uploadedPhotosCount'] ?? 0,
                                icon: Icons.photo_library_rounded,
                                color: const Color(0xFFD97706),
                                bgColor: const Color(0xFFFFFBEB),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. MỤC BẢO MẬT & SAO LƯU (LOCAL-FIRST)
                  if (isLocal) ...[
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
                            key: const Key('profile_pin_item'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 22),
                            ),
                            title: const Text(
                              'Bảo mật & Mã PIN khóa app',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            subtitle: const Text(
                              'Đặt/đổi mã PIN hoặc cấu hình thời gian tự động khóa',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () => PinSettingsBottomSheet.show(context),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: borderColor),
                          ListTile(
                            key: const Key('profile_backup_item'),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.backup_outlined, color: Color(0xFF16A34A), size: 22),
                            ),
                            title: const Text(
                              'Sao lưu & Khôi phục dữ liệu',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            subtitle: const Text(
                              'Xuất file zip sao lưu hoặc phục hồi dữ liệu',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                            onTap: () => BackupRestoreBottomSheet.show(context, onRestored: _loadProfileData),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // MỤC CHIA SẺ DỮ LIỆU CỤC BỘ (LOCAL-FIRST)
                    Material(
                      color: bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: borderColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.share_location_rounded, color: Color(0xFF2563EB), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Chia sẻ dữ liệu',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gửi và nhận điểm trực tiếp giữa các shipper qua tệp .dshare hoặc quét mã QR',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      key: const Key('profile_btn_send_share'),
                                      style: AppButtons.primary(minHeight: 48, borderRadius: 12),
                                      onPressed: () => DataShareSendSheet.show(context),
                                      icon: const Icon(Icons.upload_rounded, size: 18),
                                      label: const Text('GỬI DỮ LIỆU'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      key: const Key('profile_btn_receive_share'),
                                      style: AppButtons.secondary(minHeight: 48, borderRadius: 12),
                                      onPressed: _openReceiveShareDialog,
                                      icon: const Icon(Icons.download_rounded, size: 18),
                                      label: const Text('NHẬN DỮ LIỆU'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildStatTile({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
