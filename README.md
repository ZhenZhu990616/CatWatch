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
- 中断当前任务
- 呼出/隐藏浮窗
- 历史记录（最近 50 条问答，点击可回看）
- 提示词预设（内置通用分析 / OCR 提取文字 / 翻译，可在设置中自定义）
- 登录 ChatGPT / 退出登录
- 请求屏幕权限
- 退出

回答以流式增量显示在浮窗中（行内 Markdown 会被渲染）。macOS 14+ 使用
ScreenCaptureKit 截屏（自动排除自家窗口、保留 Retina 分辨率），旧系统回退
CGDisplayCreateImage。设置的「服务」页可开启开机自启（需以 .app 打包运行）。

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
| `SCREEN_LLM_HOTKEY` | `cmd+shift+l` |
| `SCREEN_LLM_SELECTION_HOTKEY` | `cmd+shift+k` |
| `SCREEN_LLM_PANEL_HOTKEY` | `cmd+shift+o` |
| `SCREEN_LLM_MAX_IMAGE_EDGE` | `1600` |

登录凭证保存在 macOS 钥匙串。首次截图需要给启动程序的终端或可执行文件授予屏幕录制权限。
