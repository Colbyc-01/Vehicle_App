import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'garage.db');

    final opened = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vin TEXT,
            year INTEGER,
            make TEXT,
            model TEXT,
            engine_label TEXT,
            engine_code TEXT,
            vehicle_id TEXT, -- your backend vehicle_id if you have it
            created_at INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE oil_changes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            vehicle_local_id INTEGER NOT NULL,
            performed_at INTEGER NOT NULL,
            odometer INTEGER,
            oil_spec TEXT,
            oil_capacity_qt REAL,
            oil_filter_brand TEXT,
            oil_filter_part TEXT,
            notes TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(vehicle_local_id) REFERENCES vehicles(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('CREATE INDEX idx_oil_vehicle ON oil_changes(vehicle_local_id);');
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );

    _db = opened;
    return opened;
  }
}
