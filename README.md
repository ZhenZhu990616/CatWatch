# CatWatch

一个只使用 ChatGPT/Codex OAuth 的 macOS 菜单栏工具。设置界面是原生 macOS 窗口，不再启动 localhost Web 前端。

## 运行

```sh
cd /Users/apple/Developer/CatWatch
swift run CatWatch
```

启动后只显示菜单栏图标。菜单栏图标提供：

- 偏好设置
- 立即截图
- 框选截图（框内实时显示尺寸，Esc 取消）
- 批量截图（⇧ 连按两下缓存，立即截图快捷键发送）
- 中断当前任务
- 呼出/隐藏浮窗
- 历史记录（最近 50 条问答，点击可回看）
- 提示词预设（内置通用分析 / OCR 提取文字 / 翻译，可在设置中自定义）
- 登录 ChatGPT / 退出登录
- 请求屏幕权限
- 退出

回答以流式增量显示在浮窗中（行内 Markdown 会被渲染）。使用
ScreenCaptureKit 截屏（自动排除自家窗口、保留 Retina 分辨率）。设置的「服务」页可开启
开机自启（需以 .app 打包运行）。

## 配置

| 变量 | 默认值 |
| --- | --- |
| `SCREEN_LLM_MODEL` | `gpt-5.6-terra`（可选 `gpt-5.6-sol` 旗舰 / `gpt-5.6-luna` 最快） |
| `SCREEN_LLM_THINKING` | `true` |
| `SCREEN_LLM_REASONING_EFFORT` | `medium` |
| `SCREEN_LLM_REASONING_SUMMARY` | `none` |
| `SCREEN_LLM_TEXT_VERBOSITY` | `low` |
| `SCREEN_LLM_SERVICE_TIER` | 空，表示不传 |
| `SCREEN_LLM_MAX_OUTPUT_TOKENS` | `0`，表示不设置 |
| `SCREEN_LLM_OUTPUT_DISPLAY_MODE` | `floatingPanel` |
| `SCREEN_LLM_TOUCHBAR_FONT_SIZE` | `14` |
| `SCREEN_LLM_TOUCHBAR_TEXT_COLOR` | `system` |
| `SCREEN_LLM_TOUCHBAR_TEXT_INTENSITY` | `1.0` |
| `SCREEN_LLM_TOUCHBAR_TEXT_ALIGNMENT` | `center` |
| `SCREEN_LLM_PROMPT` | `请分析这张截图，并用中文简洁回答。` |
| `SCREEN_LLM_INSTRUCTIONS` | `你是一个简洁、准确的中文屏幕分析助手。` |
| `SCREEN_LLM_HOTKEY` | `cmd double tap`（⌘ 连按两下） |
| `SCREEN_LLM_SELECTION_HOTKEY` | `ctrl double tap`（⌃ 连按两下） |
| `SCREEN_LLM_PANEL_HOTKEY` | `opt double tap`（⌥ 连按两下） |
| `SCREEN_LLM_CAPTURE_REGION_HOTKEY` | `cmd+e`（⌘E） |
| `SCREEN_LLM_BATCH_CAPTURE_HOTKEY` | `shift double tap`（⇧ 连按两下） |
| `SCREEN_LLM_MAX_IMAGE_EDGE` | `1600` |

登录凭证保存在 macOS 钥匙串。首次截图需要给启动程序的终端或可执行文件授予屏幕录制权限。

### 批量截图

- `⇧` 连按两下（可在“快捷键”设置中修改）会缓存一张立即截图，最多 8 张；图片只保存在内存中。
- 缓存后按“立即截图”快捷键会一次发送全部缓存图片，不会额外截取当前屏幕。
- 缓存期间按 `Esc` 会先取消正在采集的一张；没有在途采集时删除最后一张缓存。
- 未登录或未授予屏幕录制权限时，发送前的失败不会清空缓存；请求已经开始后的网络/服务端失败不会恢复缓存。
- “从屏幕选择”的默认快捷键为 `⌘E`。

批量缓存不写入磁盘，退出、重启或退出登录后不会恢复。
