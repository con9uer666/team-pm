# team_pm_mobile

RoboMaster 战队管理 App — Flutter 客户端，同源同后端，跑 iOS + Android。

后端：`http://49.233.180.22:8080/api`（[server runbook](../CLAUDE.md)）。

---

## 环境

- macOS + Xcode 26+ + CocoaPods 1.16+
- Flutter 3.41.x stable
- 装过 Apple ID（Xcode → Settings → Accounts）

iPhone 端要求：

- iOS 14+
- 设置 → 隐私与安全性 → **开发者模式** 打开（iOS 16+ 强制）
- 第一次插 Mac 时点「信任此电脑」

---

## 每次改完代码

```bash
cd mobile
flutter pub get
flutter run -d <device-id>        # 默认拉远端 49.233.180.22:8080
```

设备 id 用 `flutter devices` 查。

如果要指向别的后端（例如本地起 backend）：

```bash
flutter run -d <device-id> --dart-define=API_BASE=http://192.168.x.x:3000/api
```

注意：HTTP 后端必须在 [ios/Runner/Info.plist](ios/Runner/Info.plist) 的 `NSAppTransportSecurity` 白名单里，否则 iOS 静默挡掉所有请求。

---

## 第一次跑（一次性）

### 1. 装 Flutter 依赖 + iOS pods

```bash
cd mobile
flutter pub get
cd ios && pod install && cd ..
```

### 2. Xcode 里配签名（GUI 必须）

```bash
open ios/Runner.xcworkspace
```

注意：**用 `.xcworkspace`，不是 `.xcodeproj`**（CocoaPods 整合后必须用 workspace）。

- Xcode → Settings → Accounts → 加 Apple ID（免费的也能用）
- 左侧选 Runner project → TARGETS → **Runner** → **Signing & Capabilities** 标签
- 勾 ☑ **Automatically manage signing**
- Team 下拉选 `XXX (Personal Team)`
- Bundle Identifier 已经预设为 `com.teampm.app`，如果你之前用同一个 Apple ID 给别的项目（比如 `frontend/ios/` 那个 Capacitor 工程）签过同一个 id，会冲突。处理方式：
  - 推荐：把那个老工程的 bundle id 改掉（[frontend/capacitor.config.ts](../frontend/capacitor.config.ts) 的 `appId`），从手机上卸载老 app
  - 应急：把这里的 bundle id 加后缀，比如 `com.teampm.app.<你名字>`

### 3. iPhone 端

- 数据线插 Mac
- 设置 → 隐私与安全性 → 开发者模式 → 开（要求重启）
- 重启后 Xcode `flutter devices` 才能看到设备

### 4. 跑

```bash
flutter run -d <device-id>
```

首次安装后启动会卡「不受信任的开发者」。手机上：

- 设置 → 通用 → VPN 与设备管理 → 选你的 Apple ID → **信任**

回桌面点「战队管理」图标。

> 免费 Apple ID 签名的有效期是 **7 天**。过期后再跑一次 `flutter run` 就会重签，App 自动覆盖更新。

---

## 调试技巧

- **Flutter DevTools**：`flutter run` 后终端会打印一个 `http://127.0.0.1:xxxxx/?uri=...` 链接，浏览器打开就是 DevTools（widget tree、network、perf）。
- **WebView 风格的 console**：直接在 Dart 代码里 `print()` 或者 `debugPrint()`，输出在 `flutter run` 的终端。
- **hot reload**：`r`（热加载，秒级）；`R`（热重启，秒级，会丢状态）；`q`（退出）。
- **网络抓包**：用 Mac 上的 Charles / Proxyman 当代理，iPhone 设置 → Wi-Fi → HTTP 代理填 Mac 内网 IP + 端口，记得装 Charles 证书。

---

## 已知坑

- `flutter create --platforms=ios .` 默认 Podfile 不指定 iOS 平台，导致拉到 13.0；本仓库已改成 14.0（[ios/Podfile](ios/Podfile)）+ 同步 `IPHONEOS_DEPLOYMENT_TARGET = 14.0`。如果以后升 geolocator 等插件再次报 deployment target 太低，把 Podfile 的 `platform :ios, 'XX.0'` 一起调高，跑 `pod install` 重装。
- 后端是 HTTP，[ios/Runner/Info.plist](ios/Runner/Info.plist) 加了 `NSAppTransportSecurity → NSExceptionDomains → 49.233.180.22` 例外。后端上 HTTPS 后请删掉这一块。
- pubspec 里有 `retrofit / retrofit_generator / freezed / json_serializable / riverpod_generator` 一堆 codegen 包，但**当前代码完全没用 codegen 注解**（所有 API client 手写 dio）。`dart run build_runner build` 会跑过但产物为 0，正常。要不要清掉这些依赖等以后再看。
- `flutter create` 生成的 Xcode project 缺 `Flutter/Profile.xcconfig`，本仓库已补上。`flutter run --profile` 才用得到。
- 高德 Web 服务 Key 目前还没接到 mobile 端（web 端用的是 `VITE_AMAP_KEY`），打卡反向地理编码现在没地址显示，只显示经纬度。后续要补。

---

## 项目结构

```
lib/
├── core/              # 跨页面基建
│   ├── auth/          # auth controller + api + models
│   ├── network/       # dio client + provider
│   ├── router/        # go_router 配置
│   ├── storage/       # secure storage (token) + shared prefs
│   ├── geo/           # 定位封装
│   ├── theme/         # Material theme
│   └── config.dart    # API base URL, 全局常量
├── features/          # 按业务分目录
│   ├── auth/          # 登录、注册
│   ├── home/          # 仪表盘
│   ├── tasks/         # 任务中心
│   ├── attendance/    # 打卡
│   ├── meetings/      # 会议（api 已就绪，screen 待补）
│   ├── pending/       # 待审批用户落地页
│   └── profile/       # 个人信息
├── shared/widgets/    # 跨页复用组件
└── main.dart
```

Web 端 ([../frontend/](../frontend/)) 还有 `notifications / collaborate / space / team-structure / admin/*` 这些页面 mobile 还没有，按计划增量补齐（见 [.claude/plans/web-ios-prancy-canyon.md](../.claude/plans/web-ios-prancy-canyon.md)）。
