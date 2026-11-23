import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

/// 跨平台 SQLite 数据库管理器
///
/// - Android / iOS：使用原生 `sqflite`
/// - Windows / Linux / macOS：自动初始化 `sqflite_common_ffi` 并持久化到应用支持目录
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String _dbFileName = 'planflow_local.db';
  static const int _dbVersion = 1;

  Database? _database;
  bool _ffiInitialized = false;

  /// 确保桌面平台 FFI 驱动已初始化
  void ensureFfiInitialized() {
    if (_ffiInitialized || kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    ensureFfiInitialized();

    final String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final supportDir = await getApplicationSupportDirectory();
      if (!await supportDir.exists()) {
        await supportDir.create(recursive: true);
      }
      dbPath = p.join(supportDir.path, _dbFileName);
    } else {
      final dbDir = await getDatabasesPath();
      dbPath = p.join(dbDir, _dbFileName);
    }

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE semesters (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        color_value INTEGER NOT NULL DEFAULT 4282339765,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        dimension TEXT NOT NULL,
        due_date TEXT,
        week_start_date TEXT,
        month_key TEXT,
        semester_id TEXT,
        parent_task_id TEXT,
        priority INTEGER NOT NULL DEFAULT 1,
        tags_json TEXT NOT NULL DEFAULT '[]',
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE milestones (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        semester_id TEXT NOT NULL,
        title TEXT NOT NULL,
        due_date TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tasks_due_date ON tasks(due_date)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_dimension ON tasks(dimension)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_semester_id ON tasks(semester_id)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_parent_task_id ON tasks(parent_task_id)',
    );
    await db.execute(
      'CREATE INDEX idx_milestones_task_id ON milestones(task_id)',
    );
    await db.execute(
      'CREATE INDEX idx_milestones_semester_id ON milestones(semester_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 预留未来 Schema 迁移扩展点
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
