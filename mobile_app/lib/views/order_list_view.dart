import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';
import 'delivery_map_view.dart';
import 'order_detail_view.dart';
import 'login_view.dart';

class OrderListView extends StatefulWidget {
  const OrderListView({super.key});

  @override
  State<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends State<OrderListView> {
  late Future<List<OrderModel>> _ordersFuture;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ApiService.getMyShiftOrders();
    });
    _checkPendingSync();
  }

  Future<void> _checkPendingSync() async {
    final count = await ApiService.getPendingSyncCount();
    if (mounted) {
      setState(() {
        _pendingSyncCount = count;
      });
    }
    if (count > 0) {
      await ApiService.syncOfflineQueue();
      final afterCount = await ApiService.getPendingSyncCount();
      if (mounted) {
        setState(() {
          _pendingSyncCount = afterCount;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Đơn Hàng Trong Ca', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          if (_pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: 'Có $_pendingSyncCount vị trí đang chờ đồng bộ',
                child: Chip(
                  avatar: const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.amber),
                  label: Text('$_pendingSyncCount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.amber.shade100,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Xem bản đồ giao hàng',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DeliveryMapView()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refreshOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Đang tải danh sách đơn hàng...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Lỗi kết nối hoặc tải đơn hàng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}'.replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshOrders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Không có đơn hàng nào trong ca hôm nay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn đã hoàn thành tất cả đơn được giao hoặc chưa có đơn mới.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _refreshOrders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Kiểm tra lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshOrders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailView(order: order),
                        ),
                      );
                      _refreshOrders();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order.orderCode,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1565C0)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: order.hasSavedLocation ? Colors.green.shade50 : Colors.amber.shade50,
                                  border: Border.all(
                                    color: order.hasSavedLocation ? Colors.green.shade300 : Colors.amber.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      order.hasSavedLocation ? Icons.check_circle : Icons.help_outline,
                                      size: 14,
                                      color: order.hasSavedLocation ? Colors.green.shade700 : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.hasSavedLocation ? 'Đã có vị trí' : 'Chưa có vị trí',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: order.hasSavedLocation ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 18, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${order.customerName} (${order.customerPhone})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.home_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  order.customerAddress,
                                  style: const TextStyle(color: Colors.black87, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.map_outlined, size: 16, color: Colors.blueAccent),
                              const SizedBox(width: 6),
                              Text(
                                order.areaName,
                                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              const Text('Chi tiết', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
