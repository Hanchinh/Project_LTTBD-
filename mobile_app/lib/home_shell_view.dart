import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/models/shift_model.dart';
import 'package:delivery_marker_mobile/data/repository_provider.dart';
import 'package:delivery_marker_mobile/features/profile/account_profile_view.dart';
import 'package:delivery_marker_mobile/features/directory/customer_directory_view.dart';
import 'package:delivery_marker_mobile/features/map/main_map_view.dart';
import 'package:delivery_marker_mobile/features/onboarding_lock/pin_lock_screen.dart';
import 'package:delivery_marker_mobile/features/shifts/shift_list_view.dart';

/// Màn hình Khung chứa Điều hướng Chính (Home Shell View)
/// Cung cấp 4 tab chính: [Bản đồ] (mặc định), [Danh bạ], [Ca làm việc], [Cá nhân] / [Tài khoản]
/// Hỗ trợ thích ứng màn hình rộng (Tablet >= 600dp dùng NavigationRail, Mobile dùng NavigationBar).
class HomeShellView extends StatefulWidget {
  final int initialTab;
  final ShiftModel? initialShift;

  const HomeShellView({
    super.key,
    this.initialTab = 0,
    this.initialShift,
  });

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> with WidgetsBindingObserver {
  late int _currentIndex;
  ShiftModel? _activeShift;
  bool _isLockShowing = false;

  // Key để tương tác với MainMapView khi chuyển tab hoặc cập nhật ca
  final GlobalKey<MainMapViewState> _mainMapKey = GlobalKey<MainMapViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialTab;
    _activeShift = widget.initialShift;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!RepositoryProvider.useLocalData) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      RepositoryProvider.localProfile.recordActiveNow();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
    }
  }

  Future<void> _checkLockOnResume() async {
    if (_isLockShowing) return;
    final needLock = await RepositoryProvider.localProfile.shouldLockApp();
    if (needLock && mounted) {
      _isLockShowing = true;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PinLockScreen(
            onSuccess: () => Navigator.of(context).pop(),
          ),
        ),
      );
      _isLockShowing = false;
      await RepositoryProvider.localProfile.recordActiveNow();
    }
  }

  void _onTabSelected(int index) {
    final previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });

    if (index == 0 && previousIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mainMapKey.currentState?.reloadActiveShift(preserveSelected: true);
      });
    }
  }

  void _handleActiveShiftChanged(ShiftModel shift) {
    setState(() {
      _activeShift = shift;
    });
  }

  void _handleSelectShiftFromListView(ShiftModel shift) {
    setState(() {
      _activeShift = shift;
      _currentIndex = 0; // Chuyển về tab Bản đồ
    });

    // Báo cho bản đồ chuyển sang ca được chọn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainMapKey.currentState?.reloadActiveShift(preserveSelected: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final profileLabel = RepositoryProvider.useLocalData ? 'Cá nhân' : 'Tài khoản';

    final stackContent = IndexedStack(
      index: _currentIndex,
      children: [
        // Tab 0: Bản đồ chính làm trung tâm (Mặc định mở đầu tiên)
        MainMapView(
          key: _mainMapKey,
          initialShift: _activeShift,
          onActiveShiftChanged: _handleActiveShiftChanged,
          onOpenDirectory: () => _onTabSelected(1),
          onOpenShifts: () => _onTabSelected(2),
        ),

        // Tab 1: Danh bạ vị trí độc lập (Full CRUD)
        CustomerDirectoryView(
          activeShift: _activeShift,
          onShiftUpdated: (updatedShift) {
            setState(() => _activeShift = updatedShift);
            _mainMapKey.currentState?.reloadActiveShift(preserveSelected: true);
          },
          onSwitchToMapTab: () {
            _onTabSelected(0);
            _mainMapKey.currentState?.reloadActiveShift(preserveSelected: true);
          },
        ),

        // Tab 2: Quản lý các ca làm việc
        ShiftListView(
          onSelectShiftForMap: _handleSelectShiftFromListView,
          showAppBarLogout: true,
        ),

        // Tab 3: Hồ sơ tài khoản cá nhân & Cài đặt
        const AccountProfileView(),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onTabSelected,
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.map_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                      selectedIcon: const Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 24),
                      label: const Text('Bản đồ'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.contacts_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                      selectedIcon: const Icon(Icons.contacts_rounded, color: Color(0xFF2563EB), size: 24),
                      label: const Text('Danh bạ'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                      selectedIcon: const Icon(Icons.assignment_rounded, color: Color(0xFF2563EB), size: 24),
                      label: const Text('Ca làm việc'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                      selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 24),
                      label: Text(profileLabel),
                    ),
                  ],
                ),
                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0),
                ),
                Expanded(child: stackContent),
              ],
            )
          : stackContent,
      bottomNavigationBar: isWide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerTheme.color ?? const Color(0xFFE2E8F0), width: 1.0),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabSelected,
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
                elevation: 0,
                height: 72,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.map_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                    selectedIcon: const Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 24),
                    label: 'Bản đồ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.contacts_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                    selectedIcon: const Icon(Icons.contacts_rounded, color: Color(0xFF2563EB), size: 24),
                    label: 'Danh bạ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.assignment_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                    selectedIcon: const Icon(Icons.assignment_rounded, color: Color(0xFF2563EB), size: 24),
                    label: 'Ca làm việc',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 24),
                    selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 24),
                    label: profileLabel,
                  ),
                ],
              ),
            ),
    );
  }
}
