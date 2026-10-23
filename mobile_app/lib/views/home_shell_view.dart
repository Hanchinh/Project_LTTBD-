import 'package:flutter/material.dart';
import '../models/shift_model.dart';
import 'main_map_view.dart';
import 'customer_directory_view.dart';
import 'shift_list_view.dart';

/// Màn hình Khung chứa Điều hướng Chính (Home Shell View)
/// Cung cấp 3 tab chính: [Bản đồ] (mặc định), [Danh bạ], [Ca làm việc]
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

class _HomeShellViewState extends State<HomeShellView> {
  late int _currentIndex;
  ShiftModel? _activeShift;

  // Key để tương tác với MainMapView khi chuyển tab hoặc cập nhật ca
  final GlobalKey<MainMapViewState> _mainMapKey = GlobalKey<MainMapViewState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _activeShift = widget.initialShift;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
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
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE0E7FF),
          elevation: 0,
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: Color(0xFF64748B), size: 24),
              selectedIcon: Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Bản đồ',
            ),
            NavigationDestination(
              icon: Icon(Icons.contacts_outlined, color: Color(0xFF64748B), size: 24),
              selectedIcon: Icon(Icons.contacts_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Danh bạ',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined, color: Color(0xFF64748B), size: 24),
              selectedIcon: Icon(Icons.assignment_rounded, color: Color(0xFF2563EB), size: 24),
              label: 'Ca làm việc',
            ),
          ],
        ),
      ),
    );
  }
}
