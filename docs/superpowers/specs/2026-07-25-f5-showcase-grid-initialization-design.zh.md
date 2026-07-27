# F5 默认橱窗格子初始化修复设计

## 问题

`Main.tscn` 中的 `ShowcaseGrid` 是空容器，168 个橱窗格子由
`main_view.gd::_refresh_storefront_showcase()` 在运行时创建。F5 默认进入制作页面后，
`PAGE_PRODUCTION` 分支只刷新制作队列，没有执行包含橱窗在内的当前页面刷新，因此
橱窗格子数保持为 0。

## 设计

- 将 `PAGE_PRODUCTION` 分支的局部制作队列刷新改为 `_refresh_current_page()`。
- 复用现有统一刷新链，不在 `_ready()` 添加第二条专用橱窗初始化路径。
- 不改橱窗场景结构、格子数量、解锁规则、存档结构或配方图片。

## 验证

- `Main.tscn` 完成默认 `_ready()` 后，`ShowcaseGrid` 必须有 168 个子节点。
- 现有橱窗布局、解锁格和拖放断言继续通过。
- Godot 自检使用可写的 `--log-file` 路径。
