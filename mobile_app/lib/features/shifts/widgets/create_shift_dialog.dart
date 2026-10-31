// Hộp thoại tạo ca làm việc mới với tên ca và ngày thực hiện.
// Khởi tạo ca rỗng hoặc chuyển sang màn hình dán SĐT ngay lập tức.
import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/core/theme/app_buttons.dart';

/// Hộp thoại tạo ca làm việc nhanh từ bản đồ chính (TASK: SHIFT-FROM-MAP-AND-BULK-PASTE-015B)
/// - Thiết kế tối ưu cho shipper thao tác một tay ở vùng ngón cái
/// - Ô nhập duy nhất "Tên ca", tự focus, gợi ý sẵn ví dụ "Ca sáng dd/MM", có thể để trống
/// - Nút "TẠO CA" kích thước lớn >= 56px, tương phản cao
class CreateShiftBottomSheet extends StatefulWidget {
  const CreateShiftBottomSheet({super.key});

  static Future<ShiftModel?> show(BuildContext context) {
    return showModalBottomSheet<ShiftModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateShiftBottomSheet(),
    );
  }

  @override
  State<CreateShiftBottomSheet> createState() => _CreateShiftBottomSheetState();
}

class _CreateShiftBottomSheetState extends State<CreateShiftBottomSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;
  String? _errorMessage;
  String _suggestedName = '';

  @override
  void initState() {
    super.initState();
    _suggestedName = ShiftModel.suggestShiftName();
    _nameController.text = _suggestedName;
    _checkExistingShiftsForDeduplication();
  }

  Future<void> _checkExistingShiftsForDeduplication() async {
    try {
      final shifts = await RepositoryProvider.shift.getShifts();
      if (!mounted) return;
      final existingNames = shifts
          .map((s) => s.shiftName?.trim() ?? s.displayTitle.trim())
          .toList();
      final resolved = ShiftModel.suggestShiftName(existingNames: existingNames);
      if (mounted && (_nameController.text.trim() == _suggestedName || _nameController.text.trim().isEmpty)) {
        setState(() {
          _suggestedName = resolved;
          _nameController.text = resolved;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      var nameText = _nameController.text.trim();
      if (nameText.isEmpty) {
        nameText = _suggestedName.isNotEmpty ? _suggestedName : ShiftModel.suggestShiftName();
      }
      final newShift = await RepositoryProvider.shift.createShift(
        shiftName: nameText,
      );
      if (!mounted) return;
      Navigator.of(context).pop(newShift);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thanh gạt vuốt đóng
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Tiêu đề
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_task_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạo ca làm việc mới',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Đặt tên ca để quản lý hoặc để trống để tạo mã tự động',
                            style: TextStyle(fontSize: 12, color: subtextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Ô nhập tên ca duy nhất, tự động focus
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Tên ca làm việc (tùy chọn)',
                    hintText: 'Ví dụ: Ca sáng 25/10',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_note_rounded, color: subtextColor),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Thông báo lỗi nếu có
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),

                // Nút "TẠO CA" kích thước lớn >= 56px
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isCreating ? null : _handleCreate,
                    style: AppButtons.primaryLarge(minHeight: 56, borderRadius: 16),
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 22),
                    label: Text(
                      _isCreating ? 'ĐANG TẠO CA...' : 'TẠO CA VÀ MỞ BẢN ĐỒ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
