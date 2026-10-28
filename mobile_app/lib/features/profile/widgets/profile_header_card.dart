import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/user_model.dart';

class ProfileHeaderCard extends StatelessWidget {
  final UserModel? user;
  final bool isLocal;
  final VoidCallback onEditName;

  const ProfileHeaderCard({
    super.key,
    required this.user,
    required this.isLocal,
    required this.onEditName,
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bgCard = colorScheme.surface;
    final borderColor = theme.dividerTheme.color ?? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Container(
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
            backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            child: Text(
              _getInitials(user?.fullName ?? 'U'),
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
                        user?.fullName ?? 'Người dùng',
                        key: const Key('user_full_name'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isLocal)
                      IconButton(
                        key: const Key('btn_edit_display_name'),
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF2563EB)),
                        onPressed: onEditName,
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
                    _formatPhoneNumber(user?.phoneNumber ?? ''),
                    key: const Key('user_phone_number'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('user_role_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      _getRoleLabel(user?.role),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
