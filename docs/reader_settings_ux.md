# 阅读器配置界面（对标专业小说阅读器）优化方案

> 目标：让“正在阅读时”的设置面板更符合专业阅读器的使用习惯：
> - 高频项集中（不让用户在 6 个 Tab 里找字号）
> - 低频项归拢（页眉页脚/点击区域/按键等放“更多”）
> - 作用范围明确（全局默认 vs 本书独立）

## 推荐信息架构（阅读器内）

### 顶部固定：设置范围

- 显示当前编辑范围：`全局默认` / `本书设置`
- 开关：`本书独立设置`
- 快捷动作：
  - `保存为全局默认`
  - `全局覆盖本书`（仅当本书独立开启时可用）

### Tabs（建议 4 个）

1. `Aa`：排版（高频）
2. `主题`：主题与亮度
3. `翻页`：翻页模式与按键
4. `更多`：状态栏、点击区域、文本处理、其它

## 字段映射（ReadingSettings）

### Aa（排版，高频）

- 字号：`fontSize`
- 行距：`lineHeight`
- 段距：`paragraphSpacing`
- 缩进：`paragraphIndent`
- 对齐：`textFullJustify`
- 字体：`fontFamilyIndex`
- 字形/装饰：`textBold`、`underline`
- 边距预设：`paddingLeft/Right/Top/Bottom`
- 高级排版入口：打开 `TypographySettingsDialog` 做精调

### 主题

- 阅读主题：`themeIndex`
- 亮度：`brightness`、`useSystemBrightness`

### 翻页

- 翻页模式：`pageTurnMode`
- 方向：对用户隐藏，统一使用“垂直”
- 动画时长：`pageAnimDuration`
- 灵敏度：`pageTouchSlop`
- 音量键：`volumeKeyPage`

### 更多

- 状态栏：`showStatusBar`、`showTime/showBattery/showProgress/showChapterProgress`
- 页眉页脚：`hideHeader/hideFooter`、分割线、左右中内容字段
- 点击区域：`clickActions`
- 其它：`keepScreenOn`、`chineseTraditional`、`cleanChapterTitle`、自动阅读速度等
