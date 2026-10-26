import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../theme/app_buttons.dart';
import 'change_password_view.dart';
import 'data_sharing_view.dart';
import 'login_view.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.getCurrentUser();
      final areas = await ApiService.getMyAreas();
      final stats = await ApiService.getMyStats();
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
      await ApiService.logout();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tài khoản',
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
                  // 1. ĐẦU TRANG: Avatar, Tên, SĐT, Vai trò
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
                        // Avatar với chữ cái đầu
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
                              Text(
                                _user?.fullName ?? 'Người dùng',
                                key: const Key('user_full_name'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. KHU VỰC PHỤ TRÁCH
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Vị trí đã lưu
                            Expanded(
                              child: _buildStatTile(
                                label: 'Vị trí đã lưu',
                                count: _stats['savedLocationsCount'] ?? 0,
                                icon: Icons.location_on_rounded,
                                color: const Color(0xFF2563EB),
                                bgColor: const Color(0xFFEFF6FF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Ca đã tạo
                            Expanded(
                              child: _buildStatTile(
                                label: 'Ca đã tạo',
                                count: _stats['createdShiftsCount'] ?? 0,
                                icon: Icons.work_history_rounded,
                                color: const Color(0xFF059669),
                                bgColor: const Color(0xFFECFDF5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Ảnh đã tải
                            Expanded(
                              child: _buildStatTile(
                                label: 'Ảnh đã tải',
                                count: _stats['uploadedPhotosCount'] ?? 0,
                                icon: Icons.photo_camera_rounded,
                                color: const Color(0xFF7C3AED),
                                bgColor: const Color(0xFFF5F3FF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. CHIA SẺ DỮ LIỆU (TASK 023)
                  Container(
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        key: const Key('profile_data_sharing_item'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        minVerticalPadding: 14,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_location_rounded, color: Color(0xFF0F172A), size: 22),
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
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DataSharingView()),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. BẢO MẬT & ĐỔI MẬT KHẨU
                  Container(
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        key: const Key('profile_change_password_item'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        minVerticalPadding: 14,
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
                          'Cập nhật mật khẩu tài khoản cá nhân',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChangePasswordView()),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. CÀI ĐẶT & THÔNG TIN HỆ THỐNG
                  Container(
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          ListTile(
                            key: const Key('profile_server_config_item'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                            minVerticalPadding: 14,
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
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                            minVerticalPadding: 14,
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
                            trailing: const Text(
                              'v1.0.0 (Build 1)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 6. NÚT ĐĂNG XUẤT
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
