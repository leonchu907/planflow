import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'app.dart';
import 'data/local/app_database.dart';
import 'data/local/plan_repository.dart';
import 'providers/plan_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';
import 'services/backup_service.dart';
import 'services/secure_config_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化桌面端（Windows）SQLite FFI 引擎与中文日期格式化符号
  AppDatabase.instance.ensureFfiInitialized();
  await initializeDateFormatting('zh_CN', null);

  final repository = PlanRepository(database: AppDatabase.instance);
  final configService = SecureConfigService();
  final syncService = SyncService(
    repository: repository,
    configService: configService,
  );
  final backupService = BackupService(
    repository: repository,
    configService: configService,
  );

  final themeProvider = ThemeProvider(configService: configService);
  final planProvider = PlanProvider(
    repository: repository,
    configService: configService,
  );
  final syncProvider = SyncProvider(
    syncService: syncService,
    configService: configService,
    backupService: backupService,
  );

  // 双向接线：本地数据变更 -> 2 秒防抖自动云同步；云端/备份写入本地 -> 立即刷新内存状态
  planProvider.onDataMutated = syncProvider.scheduleDebouncedSync;
  syncProvider.onDatabaseRefreshed = planProvider.reloadFromDatabase;

  await Future.wait<void>(<Future<void>>[
    themeProvider.initialize(),
    planProvider.initialize(),
    syncProvider.initialize(),
  ]);

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<PlanProvider>.value(value: planProvider),
        ChangeNotifierProvider<SyncProvider>.value(value: syncProvider),
      ],
      child: const PlanFlowApp(),
    ),
  );
}
