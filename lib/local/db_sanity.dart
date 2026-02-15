import 'package:sqflite/sqflite.dart';
import 'app_db.dart';

Future<void> runDbSanityCheck() async {
  final Database db = await AppDb.instance.db;

  // Insert one row
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = await db.insert('vehicles', {
    'vin': 'TESTVIN00000000000', // 17 chars? doesn't matter yet
    'year': 2018,
    'make': 'Ford',
    'model': 'F-150',
    'created_at': now,
  });

  // Read it back
  final rows = await db.query(
    'vehicles',
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  assert(rows.isNotEmpty, 'Vehicle record not found');

}
