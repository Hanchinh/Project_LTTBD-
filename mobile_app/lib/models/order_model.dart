import 'location_model.dart';

class OrderModel {
  final String orderId;
  final String orderCode;
  final String orderStatus;
  final String areaName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final bool hasSavedLocation;
  final SavedLocationModel? savedLocation;

  OrderModel({
    required this.orderId,
    required this.orderCode,
    required this.orderStatus,
    required this.areaName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.hasSavedLocation,
    this.savedLocation,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final cust = json['customer'];
    final area = json['area'];

    return OrderModel(
      orderId: json['orderId'],
      orderCode: json['orderCode'],
      orderStatus: json['orderStatus'],
      areaName: area['name'] ?? '',
      customerId: cust['id'],
      customerName: cust['fullName'],
      customerPhone: cust['phoneNumber'],
      customerAddress: cust['addressText'],
      hasSavedLocation: cust['hasSavedLocation'] ?? false,
      savedLocation: cust['savedLocation'] != null
          ? SavedLocationModel.fromJson(cust['savedLocation'], cust['id'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'orderStatus': orderStatus,
      'areaName': areaName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'hasSavedLocation': hasSavedLocation,
      'savedLocation': savedLocation?.toJson(),
    };
  }
}
