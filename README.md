# PlanFlow 四维计划清单（Windows & Android）

基于 **Flutter + Material Design 3 + Local-First SQLite + WebDAV** 打造的跨平台计划清单软件，围绕「日、周、月、学期」四个时间维度进行任务与目标管理，支持 Windows 桌面端与 Android 移动端双端自动增量同步。

---

## 核心特性

- **Local-First 本地优先**：Windows 使用 `sqflite_common_ffi` + `sqlite3_flutter_libs`，Android 使用原生 `sqflite`，离线可用、零操作延迟。
- **软删除与 LWW 同步规范**：`TaskItem`、`SemesterPlan`、`Milestone` 均配备全局唯一 UUID、UTC 毫秒级 `updatedAt` 与 `isDeleted` 软删除标记，防止多端同步时已删除记录复活。
- **四维计划联动**：
  - **日计划**：优先级排序、实时完成率进度条、快速添加、「一键顺延」未完成任务至次日。
  - **周计划**：本周核心目标、周一至周日分布概览，支持将周目标**直接分配到某一天**或**拆解为日计划子任务**。
  - **月计划**：自适应月历网格（圆点与数量角标展示每日完成情况）、点击日期查看/新增任务、月度重点任务清单。
  - **学期计划**：多学期创建/编辑/切换、长期目标管理、子里程碑勾选自动计算并更新总体完成百分比。
- **WebDAV 双端自动同步 + 本地 JSON 备份**：
  - 原生兼容坚果云（默认地址 `https://dav.jianguoyun.com/dav/`，自动建子目录 `PlanFlow/plan_sync.json`）。
  - 账号与应用密码经 `flutter_secure_storage` 加密存储；支持测试连接、立即同步、启动静默同步与 2 秒防抖自动同步。
  - 支持全量 JSON 备份本地导出与增量合并/覆盖导入。
- **双端自适应体验**：
  - Windows 宽屏：左侧 `NavigationRail` + 多栏布局 + 鼠标悬停快捷操作 + 快捷键（`Ctrl+N` / `Ctrl+F` / `Ctrl+S` / `Ctrl+1~5`）。
  - Android 窄屏：底部 `NavigationBar` + 单列卡片 + 右滑完成 / 左滑删除（带撤销）。

---

## 初始化平台文件与打包构建指南

### 1. 生成 Windows 与 Android 平台壳文件并拉取依赖

在已安装 Flutter SDK 的终端中进入本项目目录：

```bash
cd C:\Users\Leon\.gemini\antigravity\scratch\planflow
flutter create --platforms=windows,android --org com.planflow .
flutter pub get
```

> **重要提示（Android 发布版网络权限）**：
> 执行 `flutter create` 后，请打开 `android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 标签内（`<application>` 之前）确认已添加以下权限，否则 Android Release `.apk` 无法访问 WebDAV 网络：
>
> ```xml
> <uses-permission android:name="android.permission.INTERNET" />
> ```
>
> 同时建议在 `<application>` 标签上设置 `android:allowBackup="false"`，以避免 Android 系统自动备份恢复后导致 `EncryptedSharedPreferences` 密钥不一致。

### 2. 静态分析与单元测试

```bash
flutter analyze
flutter test
```

### 3. 打包 Windows 桌面端（`.exe`）

> 前置要求：Windows 本机已安装 Visual Studio（勾选「使用 C++ 的桌面开发」工作负载）。

```bash
flutter build windows --release
```

编译产物位于：`build\windows\x64\runner\Release\planflow.exe`（分发时需保留同目录下的 `.dll` 文件及 `data\` 文件夹）。

### 4. 打包 Android 移动端（`.apk`）

> 前置要求：已配置 Android SDK 与 Java 17+（可通过 `flutter doctor` 检查）。

- **构建通用 Release APK**：

```bash
flutter build apk --release
```

产物位于：`build\app\outputs\flutter-apk\app-release.apk`。

- **或按 CPU 架构分包以大幅减小 APK 体积**：

```bash
flutter build apk --release --split-per-abi
```

产物位于：`build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`（主流 64 位安卓手机首选）。
