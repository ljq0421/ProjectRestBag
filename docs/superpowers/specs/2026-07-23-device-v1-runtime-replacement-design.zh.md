# Device V1 设备图标运行时替换设计

## 目标

`project-rest-new` 中所有现有设备图标显示统一从
`res://resources/ui/device_v1` 加载，不再从
`res://resources/device_icons` 加载。

设备 ID 与新资源文件保持一一对应：

- `round_pot.png`
- `grinder.png`
- `oven.png`
- `chiller.png`
- `griddle.png`
- `mixer.png`

## 已确认的现状

设备图标由 `scripts/main_view.gd` 的
`DEVICE_ICON_DIRECTORY` 和 `_device_icon_texture()` 集中加载。
当前运行时使用处包括研发工具槽和研发工具选择弹窗，二者都调用同一个
加载函数。`tests/research_input_strip_self_check.gd` 还直接检查旧目录。

`resources/ui/device_v1` 已包含与六个设备 ID 同名的 PNG。旧目录
`resources/device_icons` 继续保留，但退出运行时和测试引用链。

## 设计

采用集中路径切换：

1. 将 `DEVICE_ICON_DIRECTORY` 改为
   `res://resources/ui/device_v1`。
2. 保留 `_device_icon_texture()` 当前的资源加载及 PNG 缓冲回退逻辑。
3. 更新设备图标测试，使其检查新目录下六张图标，并验证主界面的集中
   加载函数返回新目录资源。

这样无需分别修改研发工具槽和选择弹窗；当前及后续复用
`_device_icon_texture()` 的界面都会自动使用同一套资源。

## 失败与回退行为

保持现有行为：资源不存在、文件无法打开或 PNG 解码失败时返回
`null`，界面继续显示设备名称，不引入新的崩溃路径或占位资源。

## 验证

1. 静态扫描运行时代码和测试，确认不再引用
   `res://resources/device_icons`。
2. 运行 `research_input_strip_self_check.gd`，验证六个设备图标存在、
   集中加载路径正确，并覆盖研发工具槽与选择弹窗的真实界面构建。
3. 使用带可写 `--log-file` 的 Godot 4.6.1 headless 命令验证项目解析。
4. 运行 `git diff --check`。

旧目录自身的 `.import` 元数据和历史设计文档可继续提及旧路径；它们不属于
当前运行时或测试引用。

## 非目标

- 不删除或覆盖 `resources/device_icons`。
- 不修改设备解锁、研发、成长或配方逻辑。
- 不调整图标槽、弹窗布局、纹理缩放或设备名称。
- 不改动 `project-rest` 等其他 checkout。
