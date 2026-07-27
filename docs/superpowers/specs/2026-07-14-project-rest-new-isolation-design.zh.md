# project-rest-new 独立项目隔离设计

## 1. 目标

从 `feature/showcase-backpack-autosettle` 执行时的当前 HEAD 创建本地目录
`D:\Project\ProjectRest\project-rest-new`，保留该分支的完整祖先历史，同时让新项目在以下方面与原项目完全独立：

- 独立 Git 对象库、分支与远端配置；
- 独立 Godot 项目标识与 `user://` 数据目录；
- 独立存档文件名；
- 独立 UI 静态资源副本；
- 独立 Godot 导入缓存与运行产物。

运行时代码基线 `1a85e37` 是对 `main` 提交 `2c14ed5` 的适配集成：保留无限店铺等级、设备/养殖路线、166 道配方及相关资产和聚焦测试，但不恢复与橱窗独立自动结算冲突的旧营业日、营业手册和集中经营路径。新项目必须包含该适配提交，可额外包含本设计与实施计划文档，但不再直接 cherry-pick `2c14ed5`。

源项目 `project-rest-showcase-backpack` 只继续承载本设计文档和实施计划，不修改 Git 远端。当前源工作树中的 `resources/ui` 是为验证准备的未跟踪静态资产，创建新项目时只将其作为复制源，不在功能分支提交。

## 2. Git 隔离

使用本地 `git clone --no-hardlinks --single-branch` 从
`feature/showcase-backpack-autosettle` 创建新目录，不使用 Git worktree，也不直接复制 `.git`。

创建后执行以下整理：

- 删除新仓库的 `origin`；
- 将当前分支重命名为 `main`；
- 保留从当前功能分支向前可达的完整提交历史；
- 在新仓库中提交项目身份、存档隔离和 UI 资源自包含改动。

这样两个目录拥有互不依赖的 `.git` 对象库。新项目以后可以单独绑定新的远端仓库。

## 3. Godot 与运行数据隔离

新项目修改 `project.godot`：

```ini
config/name="project-rest-new"
```

Godot 会据此使用不同的 `user://` 项目数据目录。为避免未来项目名调整导致存档重合，`scripts/save_system.gd` 同时改用独立文件名：

```gdscript
const SAVE_PATH := "user://project_rest_new_save.json"
const BROKEN_SAVE_PATH := "user://project_rest_new_save.broken.json"
```

新项目不复制以下运行数据：

- `.godot/` 导入缓存；
- 原项目 `user://` 存档；
- 日志、临时测试存档和编辑器状态。

首次启动时由 Godot 在新目录重新生成 `.godot/`。

## 4. UI 静态资源自包含

当前主题依赖 `resources/ui`，但该目录未被当前分支跟踪。目录当前包含 341 个文件，约 46.6 MiB，其中既有原始皮肤资源，也有生成后的运行资源。仅运行
`tools/build_neighborhood_dessert_skin.py` 无法从空目录恢复原始资源。

`resources/recipe_icons` 则已在 `1a85e37` 中纳入 Git，共 332 个被跟踪文件；本地克隆会自然获得这些配方源图和导入描述，不需要额外复制。

新项目采用以下策略：

1. 从 `D:\Project\ProjectRest\project-rest-showcase-backpack\resources\ui` 复制一份静态资源到新项目；若执行时该目录缺失，则停止并报告，不回退到不明确的其他资产源；
2. 只复制 `resources/ui`，不复制原项目其他未跟踪文件；
3. 确认新项目 `.gitignore` 没有忽略 `resources/ui`；当前基线无需修改 `.gitignore`，若执行时规则发生漂移则先停止复核；
4. 将 `resources/ui` 纳入新项目自己的首次隔离提交；
5. 运行 `tools/build_neighborhood_dessert_skin.py --check` 验证运行资源与原始资源一致。

资源复制完成后，两个项目各自持有独立文件副本，后续修改不会相互影响。

## 5. 创建失败处理

- 若目标目录在开始时已存在，则立即停止，不覆盖、不合并。
- 若克隆、资源复制、生成器检查或 Godot 验证失败，则保留现场并报告失败步骤，不自动删除目标目录。
- 不修改源项目的分支、远端、运行代码或未跟踪资源。
- 不为新项目自动创建或绑定外部远端。

## 6. 验证

创建完成后必须验证：

1. `project-rest-new\.git` 是实际目录，不是 worktree 指针文件；
2. 新项目 `git remote -v` 无输出；
3. 新项目当前分支为 `main`；
4. 新项目基线包含 `1a85e37`，从而同时包含 `67b6fcd` 的橱窗自动结算实现和对 `2c14ed5` 的适配集成；
5. 新旧项目的 Git 目录解析结果不同；
6. `project.godot` 的项目名为 `project-rest-new`；
7. 存档和损坏存档路径均使用 `project_rest_new` 前缀；
8. `resources/ui` 与 `resources/recipe_icons` 均已被新仓库跟踪，皮肤生成器 `--check` 通过；
9. 使用显式 `--log-file` 运行 Godot 无窗口启动检查；
10. `infinite_shop_level_self_check.gd`、`progression_catalog_self_check.gd`、`task_mainline_self_check.gd` 以及三项橱窗自动结算聚焦自检通过；
11. 配方数据审计和橱窗配方图生成器 Python 测试通过；
12. 本轮文档已独立提交，源功能工作树只保留原有未跟踪 `resources/ui`，不误提交静态资源。

当前 `tests/mvp_self_check.gd` 仍包含旧 149 道配方、有限等级和旧任务路线断言，会在新基线上产生与隔离创建无关的级联失败，因此不作为本次新项目创建的阻断门。该测试的现代化应另开任务处理；本次不得为让广域旧测试变绿而恢复旧业务语义。

## 7. 不在本次范围内

- 不推送 GitHub；
- 不创建新的远端仓库；
- 不迁移旧存档；
- 不修改玩法、UI 布局或经济数值；
- 不合并回原项目的 `main`。
