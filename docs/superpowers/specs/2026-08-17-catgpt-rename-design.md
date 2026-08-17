# CatGPT 完整改名规格

## 目标

将当前 macOS 应用、SwiftPM 工程、磁盘项目目录及所有面向运行时的命名从 `CatGPT` 完整改为 `CatGPT`，并移除菜单栏中的“打开屏幕录制权限设置”和“重新注册快捷键”。

## 范围

- SwiftPM package、executable target、test target 和测试目录统一使用 `CatGPT` / `CatGPTTests`。
- 磁盘目录从 `/Users/apple/Developer/CatGPT` 移至 `/Users/apple/Developer/CatGPT`，已有 Git main worktree 与 settings-redesign worktree 的登记路径同步修复。
- 应用显示名、菜单、窗口标题、tooltip、accessibility label、Bundle ID、App Support 文件夹、Keychain service、UserDefaults key 前缀、队列/Touch Bar/历史存储标识全部使用 `CatGPT`。
- README、构建脚本、源码注释、测试、设计/计划文档中的项目名一并更新；历史命令的目录与产物名也更新。
- 不读取、不复制、不迁移任何旧的 `CatGPT` 或 `catGPT` 配置、历史、钥匙串凭证或窗口状态。升级后视为全新应用。
- 从状态栏菜单移除两项：屏幕录制权限设置、重新注册快捷键；保留设置页内的系统权限操作。

## 非目标

- 不创建 Release、DMG、签名或上传产物。
- 不删除用户现有 `~/Library/Application Support/CatGPT`、旧 Keychain 条目或旧 UserDefaults 值；新应用仅忽略它们。
- 不变更 OAuth 协议、截图逻辑或 UI 视觉设计。

## 验收

- `swift run CatGPT` 启动应用，菜单中不再出现两项被移除的操作。
- 新写入路径和标识均以 `CatGPT` 为前缀，旧配置不会被读取。
- 工作区根目录与 active worktree 均位于 `/Users/apple/Developer/CatGPT` 下，`git worktree list` 无过期路径。
- 运行 `swift test`、`swift build -Xswiftc -warnings-as-errors`、`git diff --check`，仅进行 Debug 验证。
