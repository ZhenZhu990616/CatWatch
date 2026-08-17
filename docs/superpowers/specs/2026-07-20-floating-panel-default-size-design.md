# CatGPT 首次悬浮窗默认尺寸设计

## 目标

将 CatGPT 首次启动时的悬浮窗默认尺寸设为 520×320 点，宽高比约为 16:10，使文本回答有足够的横向阅读空间，同时避免窗口过扁或占用过多屏幕。

## 行为范围

- 仅修改 `ConfigDraft.defaultPanelWidth` 与 `ConfigDraft.defaultPanelHeight` 的默认值。
- 当 `UserDefaults` 中不存在已保存的窗口尺寸时，使用 520×320。
- 当用户已经调整并保存过窗口尺寸时，继续读取已保存值，不进行迁移或覆盖。
- 环境变量 `SCREEN_LLM_PANEL_WIDTH` 与 `SCREEN_LLM_PANEL_HEIGHT` 仍可覆盖首次默认值。
- 现有窗口最小尺寸、最大尺寸、位置恢复和拖拽保存逻辑保持不变。

## 实现边界

尺寸默认值继续由 `ConfigDraft` 统一提供，`FloatingResultPresenter` 沿用现有配置加载路径，不增加新的状态或迁移版本。这样改动集中，且不会影响窗口生命周期与用户已有偏好。

## 验证

新增 Swift Package 测试目标，先用失败测试确认当前默认值不是 520×320，再修改常量使测试通过。测试同时确认默认宽高比处于正常横向窗口范围，并通过现有 Release 构建、Developer ID 验签和打包流程验证最终应用。

## 发布

源代码提交到新的私有 GitHub 仓库 `ZhenZhu990616/CatGPT`。签名后的应用打包为版本化 DMG，并作为 GitHub Release 资产上传；本地 `.build` 与临时发布产物不进入 Git 历史。
