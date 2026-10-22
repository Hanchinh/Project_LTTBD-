import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/order_model.dart';
import '../models/location_model.dart';

class OfflineStorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'delivery_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_orders (
            orderId TEXT PRIMARY KEY,
            jsonData TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customerId TEXT,
            latitude REAL,
            longitude REAL,
            gpsAccuracy REAL,
            identificationNotes TEXT,
            createdAt TEXT
          )
        ''');
      },
    );
  }

  static Future<void> cacheOrders(List<OrderModel> orders) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_orders');

    for (var order in orders) {
      batch.insert('cached_orders', {
        'orderId': order.orderId,
        'jsonData': jsonEncode(order.toJson()),
      });
    }

    await batch.commit(noResult: true);
  }

  static Future<List<OrderModel>> getCachedOrders() async {
    final db = await database;
    final maps = await db.query('cached_orders');
    return maps.map((m) {
      final json = jsonDecode(m['jsonData'] as String);
      return OrderModel.fromJson(json);
    }).toList();
  }

  static Future<void> addToSyncQueue(SavedLocationModel location) async {
    final db = await database;
    await db.insert('offline_sync_queue', {
      'customerId': location.customerId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'gpsAccuracy': location.gpsAccuracy,
      'identificationNotes': location.identificationNotes,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('offline_sync_queue');
  }

  static Future<void> clearSyncQueueItem(int id) async {
    final db = await database;
    await db.delete('offline_sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
