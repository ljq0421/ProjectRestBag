# 原料图标 `ingredient_v1` 全量替换设计

## 目标

`project-rest-new` 中所有运行时原料图标统一从
`res://resources/ui/ingredient_v1/<ingredient_id>.png` 加载。

## 已确认范围

- `resources/ui/ingredient_v1` 与旧目录 `resources/ingredient_icons` 各有 71 个
  PNG，文件主名集合完全一致。
- 当前运行时通过 `scripts/main_view.gd` 中的统一目录常量及
  `_ingredient_icon_texture()` 加载原料图标。
- 库存、购买、研发/加工结果、配方材料和按钮图标等调用方继续使用现有
  统一加载函数，不分别维护资源路径。

## 实施方案

1. 将 `INGREDIENT_ICON_DIRECTORY` 改为
   `res://resources/ui/ingredient_v1`。
2. 更新硬编码旧资源路径的聚焦测试断言。
3. 保留 `resources/ingredient_icons` 目录，但不把它作为运行时回退源。
4. 不改动历史设计与实施文档中对旧实现的记录。

## 不在范围内

- 不删除旧原料图标。
- 不改动原料 ID、名称、库存数据或业务逻辑。
- 不改动配方图标、设备图标及其他 UI 资源。
- 不改动当前工作区内已有的配方图片变更。

## 验证

- 比较新旧目录的 PNG 文件主名，确认 71 个原料 ID 一一覆盖。
- 扫描脚本、场景、资源和测试，确认没有运行时旧目录引用。
- 运行原料/配方库存图标聚焦自检。
- 使用可写 `--log-file` 执行 Godot 基础加载检查，确认新 PNG 能正常导入和加载。

