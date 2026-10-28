import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

class DirectoryEmptyView extends StatelessWidget {
  const DirectoryEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_outlined, size: 44, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có khách nào',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bác tài có thể bấm "+ Thêm số" ở trên để lưu khách mới.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class DirectoryErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const DirectoryErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Lỗi: $errorMessage',
              style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: AppButtons.secondary(minHeight: 48, borderRadius: 10),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: onRetry,
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

