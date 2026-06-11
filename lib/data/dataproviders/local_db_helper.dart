import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/parking_spot_model.dart';
import '../models/transaction_model.dart';

/// A zone as the user configures it (id is null for a not-yet-created zone).
typedef ZoneConfigRow = ({String? zoneId, String name, int capacity});

/// A zone with derived capacity + live occupancy.
typedef ZoneStatRow = ({String zoneId, String name, int capacity, int occupied});

class LocalDbHelper {
  static final LocalDbHelper instance = LocalDbHelper._init();
  static Database? _database;

  LocalDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('garage.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE zones (
        zone_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parking_spots (
        spot_id TEXT PRIMARY KEY,
        zone_id TEXT NOT NULL,
        spot_number INTEGER NOT NULL,
        is_occupied INTEGER DEFAULT 0,
        FOREIGN KEY (zone_id) REFERENCES zones (zone_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        plate_number TEXT NOT NULL,
        check_in_time TEXT NOT NULL,
        check_out_time TEXT,
        spot_assigned TEXT,
        total_fee REAL,
        is_synced INTEGER DEFAULT 0,
        status TEXT DEFAULT 'Active',
        FOREIGN KEY (spot_assigned) REFERENCES parking_spots (spot_id)
      )
    ''');

    // No seeding — the user builds their own garage on first launch.
  }

  /// v1 → v2: the garage went from a hard-coded layout to user-defined zones.
  /// Pre-release, so drop the old data and recreate empty.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS transactions');
    await db.execute('DROP TABLE IF EXISTS parking_spots');
    await db.execute('DROP TABLE IF EXISTS zones');
    await _createDB(db, newVersion);
  }

  // ── Garage configuration ────────────────────────────────────────────────

  Future<bool> isGarageConfigured() async {
    final db = await database;
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM zones'));
    return (count ?? 0) > 0;
  }

  /// Zones with derived capacity (spot count) + live occupancy, ordered.
  Future<List<ZoneStatRow>> getZoneStats() async {
    final db = await database;
    final zones = await db.query('zones', orderBy: 'sort_order ASC');
    final rows = <ZoneStatRow>[];
    for (final z in zones) {
      final zoneId = z['zone_id'] as String;
      final capacity = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM parking_spots WHERE zone_id = ?',
              [zoneId])) ??
          0;
      final occupied = Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM parking_spots WHERE zone_id = ? AND is_occupied = 1',
              [zoneId])) ??
          0;
      rows.add((
        zoneId: zoneId,
        name: z['name'] as String,
        capacity: capacity,
        occupied: occupied,
      ));
    }
    return rows;
  }

  /// Current editable config: zoneId, name, capacity.
  Future<List<ZoneConfigRow>> getGarageConfig() async {
    final stats = await getZoneStats();
    return stats
        .map<ZoneConfigRow>(
            (r) => (zoneId: r.zoneId, name: r.name, capacity: r.capacity))
        .toList();
  }

  /// Total spots across every zone.
  Future<int> totalCapacity() async {
    final db = await database;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM parking_spots')) ??
        0;
  }

  /// spot_id → zone name, for showing the zone label on sessions.
  Future<Map<String, String>> spotZoneNames() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT ps.spot_id AS spot_id, z.name AS name
      FROM parking_spots ps JOIN zones z ON ps.zone_id = z.zone_id
    ''');
    return {
      for (final r in rows) r['spot_id'] as String: r['name'] as String,
    };
  }

  /// Applies the desired layout. Entries with a null [zoneId] are new zones.
  /// The caller MUST validate occupancy first (only free spots are removed).
  Future<void> applyGarageConfig(List<ZoneConfigRow> desired) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query('zones', columns: ['zone_id']);
      final existingIds = existing.map((z) => z['zone_id'] as String).toSet();
      final keepIds =
          desired.where((d) => d.zoneId != null).map((d) => d.zoneId!).toSet();

      // 1. Removed zones → delete their (free) spots, then the zone.
      for (final id in existingIds.difference(keepIds)) {
        await txn.delete('parking_spots',
            where: 'zone_id = ? AND is_occupied = 0', whereArgs: [id]);
        await txn.delete('zones', where: 'zone_id = ?', whereArgs: [id]);
      }

      // 2. Upsert each desired zone and reconcile its spot count.
      for (int i = 0; i < desired.length; i++) {
        final d = desired[i];
        final zoneId = d.zoneId ?? _genZoneId();
        if (d.zoneId == null) {
          await txn.insert(
              'zones', {'zone_id': zoneId, 'name': d.name, 'sort_order': i});
        } else {
          await txn.update('zones', {'name': d.name, 'sort_order': i},
              where: 'zone_id = ?', whereArgs: [zoneId]);
        }

        final current = Sqflite.firstIntValue(await txn.rawQuery(
                'SELECT COUNT(*) FROM parking_spots WHERE zone_id = ?',
                [zoneId])) ??
            0;

        if (d.capacity > current) {
          final maxNum = Sqflite.firstIntValue(await txn.rawQuery(
                  'SELECT MAX(spot_number) FROM parking_spots WHERE zone_id = ?',
                  [zoneId])) ??
              0;
          final batch = txn.batch();
          for (int n = 1; n <= d.capacity - current; n++) {
            final number = maxNum + n;
            batch.insert('parking_spots', {
              'spot_id': '$zoneId-$number',
              'zone_id': zoneId,
              'spot_number': number,
              'is_occupied': 0,
            });
          }
          await batch.commit(noResult: true);
        } else if (d.capacity < current) {
          // Remove only free spots (highest numbers first).
          final free = await txn.query('parking_spots',
              where: 'zone_id = ? AND is_occupied = 0',
              whereArgs: [zoneId],
              orderBy: 'spot_number DESC',
              limit: current - d.capacity);
          for (final s in free) {
            await txn.delete('parking_spots',
                where: 'spot_id = ?', whereArgs: [s['spot_id']]);
          }
        }
      }
    });
  }

  static int _zoneSeq = 0;
  String _genZoneId() =>
      'z${DateTime.now().millisecondsSinceEpoch}_${_zoneSeq++}';

  // ── Spots ─────────────────────────────────────────────────────────────────

  Future<List<ParkingSpot>> getAllParkingSpots() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT ps.* FROM parking_spots ps
      JOIN zones z ON ps.zone_id = z.zone_id
      ORDER BY z.sort_order ASC, ps.spot_number ASC
    ''');
    return results.map(ParkingSpot.fromMap).toList();
  }

  Future<ParkingSpot?> getFirstAvailableSpotInZone(String zoneId) async {
    final db = await database;
    final results = await db.query(
      'parking_spots',
      where: 'zone_id = ? AND is_occupied = 0',
      whereArgs: [zoneId],
      orderBy: 'spot_number ASC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ParkingSpot.fromMap(results.first);
  }

  Future<void> updateSpotStatus(String spotId, bool isOccupied) async {
    final db = await database;
    await db.update(
      'parking_spots',
      {'is_occupied': isOccupied ? 1 : 0},
      where: 'spot_id = ?',
      whereArgs: [spotId],
    );
  }

  // ── Transactions ────────────────────────────────────────────────────────

  Future<void> insertTransaction(Transaction transaction) async {
    final db = await database;
    await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getActiveTransactions() async {
    final db = await database;
    final results = await db.query(
      'transactions',
      where: 'status = ?',
      whereArgs: ['Active'],
      orderBy: 'check_in_time DESC',
    );
    return results.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getCompletedTransactions() async {
    final db = await database;
    final results = await db.query(
      'transactions',
      where: 'status = ?',
      whereArgs: ['Completed'],
      orderBy: 'check_out_time DESC',
    );
    return results.map(Transaction.fromMap).toList();
  }

  Future<Transaction?> getActiveTransactionByPlate(String plateNumber) async {
    final db = await database;
    final results = await db.query(
      'transactions',
      where: 'plate_number = ? AND status = ?',
      whereArgs: [plateNumber, 'Active'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Transaction.fromMap(results.first);
  }

  Future<void> completeTransaction({
    required String transactionId,
    required DateTime checkOutTime,
    required double totalFee,
  }) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'check_out_time': checkOutTime.toIso8601String(),
        'total_fee': totalFee,
        'status': 'Completed',
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Deletes completed transactions older than [days] days.
  Future<int> deleteOldCompletedTransactions(int days) async {
    final db = await database;
    final cutoff =
        DateTime.now().subtract(Duration(days: days)).toIso8601String();
    return db.delete(
      'transactions',
      where: 'status = ? AND check_out_time < ?',
      whereArgs: ['Completed', cutoff],
    );
  }

  /// Resets all spots to free and deletes all active transactions.
  /// Used to clear stuck state from testing.
  Future<void> resetAll() async {
    final db = await database;
    await db.update('parking_spots', {'is_occupied': 0});
    await db.delete('transactions', where: 'status = ?', whereArgs: ['Active']);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
