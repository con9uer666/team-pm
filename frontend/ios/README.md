# iOS build runbook（云 Mac 端操作）

这份是在远程 Mac 上构建并导出 `.ipa` 的步骤。目标：**用免费 Apple ID 签名，产出 `.ipa`**，然后下载回 Windows 用 Sideloadly 灌手机。

## 一次性环境准备（只做一次）

### 1. 装 Xcode

- App Store 搜 "Xcode" 装（Command Line Tools 自带）
- 启动一次 Xcode，同意 license
- 终端跑：
  ```bash
  xcode-select --install
  sudo xcodebuild -license accept
  ```

### 2. 装 Node + Git

腾讯云 Mac 默认一般有。没有就：
```bash
# Homebrew（没装过先装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install node git
```

### 3. 登录 Apple ID（免费的也行）

`Xcode → Settings → Accounts → +` 输免费 Apple ID 密码。

后面会用这个 ID 的 **Personal Team** 签名（7 天有效期）。

---

## 每次改代码后要做的事

### 4. 拉代码

```bash
git clone https://github.com/con9uer666/team-pm.git  # 第一次
cd team-pm
# 或者已经 clone 过：
cd team-pm && git pull
```

### 5. 构建 Web 资源并同步到 iOS 工程

```bash
cd frontend
npm install                # 第一次或 lockfile 变化
npm run cap:sync:ios       # build:native 打包 + 灌进 ios/App/App/public/
```

这一步完成后 `ios/App/App/public/` 里就是 Windows 端跑过的同一份产物。

### 6. 打开 Xcode 工程

```bash
open ios/App/App.xcworkspace
```

> ⚠ 用 `.xcworkspace`，不是 `.xcodeproj`。Capacitor 8 默认 SPM，工程文件名是 `App.xcodeproj`，但 `.xcworkspace` 会自动拉入 SPM 包。

### 7. Xcode 里配置签名（只做一次）

- 左侧导航栏选顶部的 **App** 项目
- 中间选 TARGET **App**
- **Signing & Capabilities** 标签：
  - 勾 ☑ **Automatically manage signing**
  - **Team** 下拉选你的 `XXX (Personal Team)`
  - **Bundle Identifier** 如果冲突，把 `com.teampm.app` 改成 `com.teampm.<你的随机后缀>`（比如 `com.teampm.app.zhangsan`）。免费 ID 一天只能注册 10 个 bundle id，所以别乱改。

### 8. 构建 + 导出 IPA

**方案 A：命令行（推荐，脚本化）**

```bash
cd ios/App

# 编译 archive
xcodebuild \
  -workspace App.xcworkspace \
  -scheme App \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath $PWD/build/App.xcarchive \
  archive

# 导出 ipa
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
EOF

xcodebuild \
  -exportArchive \
  -archivePath $PWD/build/App.xcarchive \
  -exportPath $PWD/build/ipa \
  -exportOptionsPlist $PWD/build/ExportOptions.plist
```

产物：`ios/App/build/ipa/App.ipa`

**方案 B：GUI（第一次用 GUI 排错比较好）**

- Xcode 顶部 scheme 右边切 **Any iOS Device (arm64)**（不是 simulator）
- `Product → Archive`
- 等几分钟，Organizer 自动弹出
- 选刚 archive 的这个 → **Distribute App** → **Debugging** → Next 一路点 → 导出到某个文件夹，里面就有 `App.ipa`

### 9. 下载 IPA 回 Windows

用 `scp`（你 ssh 上来时用的账号/密码）：

```bash
# Windows 这边
scp <mac-user>@<mac-ip>:/path/to/App.ipa E:\PROJECTS\app\frontend\ios\App\build\ipa\App.ipa
```

或者云 Mac 服务商一般有文件传输页面（拖拽上传下载）。

### 10. Windows 侧 Sideloadly 装机

- 下 https://sideloadly.io
- 打开，手机插 Windows
- 拖 `App.ipa` 进去
- 填 Apple ID（同一个免费账号）+ 专用密码（账号启用了两步验证就要去 appleid.apple.com 生成 app-specific password）
- Start → 等几分钟装完
- iPhone **设置 → 通用 → VPN 与设备管理 → 信任这个开发者证书**
- 桌面图标点开，应该能用

---

## 免费 ID 的硬约束

- **7 天过期**：每 7 天要重复步骤 8-10。麻烦。
- **3 个 App 上限**：一个免费 ID 最多装 3 个签名 App 在同一台手机上。
- **不能 TestFlight / Ad Hoc**：只能自己用，发不了给队友。
- **Push Notifications / CloudKit 不能用**：我们 app 没用这些，不影响。

扩队员要用，只有两条路：掏 $99 开发者账号（支持 TestFlight），或者每个队员自己用自己的免费 ID 跟 Sideloadly 重签。

---

## 调试技巧

- iPhone 连 Mac（或连 Windows 都行），**Safari（Mac） / 手机对面的 Chrome** 可以远程 inspect WebView
- Mac 上：`Safari → Develop → <iPhone 名> → App Web View` 看 DevTools，console.log 全可见
- Windows Chrome：地址栏 `chrome://inspect/#devices`，手机上先打开 app 进入 WebView，Windows 这边就能看到
