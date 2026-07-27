# project-rest-new 独立项目创建实施计划

**目标：** 从 `feature/showcase-backpack-autosettle` 当前 HEAD 创建 `D:\Project\ProjectRest\project-rest-new`，保留 `1a85e37` 运行时代码基线，并让 Git、Godot 项目标识、存档、导入缓存和 UI 静态资源完全独立。

**依据：** `docs/superpowers/specs/2026-07-14-project-rest-new-isolation-design.zh.md`

**架构：** 使用本地 `git clone --no-hardlinks --single-branch` 创建真实独立仓库，随后移除源远端并把分支重命名为 `main`。用一个先失败后通过的项目身份自检约束 Godot 项目名和存档路径；把源功能工作树中未跟踪的 `resources/ui` 复制到新仓库并在新仓库首次提交中跟踪。新项目不迁移任何旧存档，也不复制 `.godot` 和日志。

**技术栈：** Git、PowerShell、Godot 4.6.1、GDScript、Python 3、Pillow、仓库内 SceneTree headless self-check。

## 全局约束

- 源仓库：`D:\Project\ProjectRest\project-rest-showcase-backpack`。
- 目标仓库：`D:\Project\ProjectRest\project-rest-new`。
- 源分支必须为 `feature/showcase-backpack-autosettle`，且 `1a85e370aafbc4986d00043177f404c1ae462667` 必须是其 HEAD 的祖先。
- 目标目录若已存在，立即停止；不覆盖、不合并、不自动清理现场。
- 不修改源仓库的运行代码、远端或未跟踪 `resources/ui`。
- 不复制 `.godot/`、日志、临时测试文件、编辑器状态或任何 `user://` 数据。
- 新项目不保留旧存档兼容、迁移或回退逻辑。
- 所有 Godot 无头命令必须从包含 `project.godot` 的目标目录运行，并显式传入可写 `--log-file`。
- `tests/mvp_self_check.gd` 的旧 149 配方、有限等级和旧任务路线断言不属于本次验收门；不得为了让它通过而恢复已废弃业务语义。
- 源仓库与新仓库分别提交；不推送、不创建远端、不创建 PR。

---

## Task 1：冻结源边界并执行创建前检查

**检查对象：**

- `D:\Project\ProjectRest\project-rest-showcase-backpack\.git`
- `D:\Project\ProjectRest\project-rest-showcase-backpack\resources\ui`
- `D:\Project\ProjectRest\project-rest-new`

- [ ] **Step 1：确认源分支和适配提交**

```powershell
$source = 'D:\Project\ProjectRest\project-rest-showcase-backpack'
$target = 'D:\Project\ProjectRest\project-rest-new'
$required = '1a85e370aafbc4986d00043177f404c1ae462667'

git -C $source status --short
git -C $source branch --show-current
git -C $source rev-parse HEAD
git -C $source merge-base --is-ancestor $required HEAD
if ($LASTEXITCODE -ne 0) { throw 'Required adapted commit is not an ancestor of source HEAD.' }
```

Expected: 当前分支为 `feature/showcase-backpack-autosettle`；状态只包含已知的未跟踪 `resources/ui`，没有未提交运行代码。

- [ ] **Step 2：确认目标不存在**

```powershell
if (Test-Path -LiteralPath $target) {
    throw "Target already exists: $target"
}
```

- [ ] **Step 3：确认 UI 复制源完整且当前未被 Git 跟踪**

```powershell
$sourceUi = Join-Path $source 'resources\ui'
if (-not (Test-Path -LiteralPath $sourceUi -PathType Container)) {
    throw "UI source is missing: $sourceUi"
}
$uiFiles = Get-ChildItem -LiteralPath $sourceUi -Recurse -File
if ($uiFiles.Count -ne 341) {
    throw "Unexpected UI file count: $($uiFiles.Count)"
}
if ((git -C $source ls-files resources/ui | Measure-Object).Count -ne 0) {
    throw 'resources/ui unexpectedly became tracked in the source branch.'
}
```

- [ ] **Step 4：确认配方源图已由 Git 自包含**

```powershell
$recipeIconFiles = git -C $source ls-files resources/recipe_icons
if (($recipeIconFiles | Measure-Object).Count -ne 332) {
    throw 'Tracked resources/recipe_icons count drifted from the approved baseline.'
}
```

Expected: 332 个配方源图相关文件已跟踪，无需在创建新项目时额外复制。

---

## Task 2：创建物理独立的本地 Git 仓库

**产生：**

- Create directory: `D:\Project\ProjectRest\project-rest-new`
- Create repository: `D:\Project\ProjectRest\project-rest-new\.git`

- [ ] **Step 1：从批准分支执行无硬链接克隆**

```powershell
git clone --no-hardlinks --single-branch --branch feature/showcase-backpack-autosettle $source $target
if ($LASTEXITCODE -ne 0) { throw 'Local clone failed.' }
```

失败时保留目标现场并停止，不自动删除半成品目录。

- [ ] **Step 2：移除源远端并重命名默认分支**

```powershell
git -C $target remote remove origin
git -C $target branch -m main
```

- [ ] **Step 3：验证仓库不是 worktree 或共享对象仓库**

```powershell
if (-not (Test-Path -LiteralPath (Join-Path $target '.git') -PathType Container)) {
    throw 'Target .git is not a real directory.'
}
if (Test-Path -LiteralPath (Join-Path $target '.git\objects\info\alternates')) {
    throw 'Target repository still uses an alternate object store.'
}

$sourceGit = (git -C $source rev-parse --path-format=absolute --git-common-dir).Trim()
$targetGit = (git -C $target rev-parse --path-format=absolute --git-common-dir).Trim()
if ($sourceGit -eq $targetGit) { throw 'Source and target share the same Git directory.' }
if ((git -C $target remote) -ne $null) { throw 'Target repository still has a remote.' }
if ((git -C $target branch --show-current).Trim() -ne 'main') { throw 'Target branch is not main.' }
git -C $target merge-base --is-ancestor $required HEAD
if ($LASTEXITCODE -ne 0) { throw 'Target does not contain the adapted runtime baseline.' }
```

---

## Task 3：用 RED → GREEN 固定新项目身份和存档隔离

**文件：**

- Create: `tests/project_identity_self_check.gd`
- Modify: `project.godot`
- Modify: `scripts/save_system.gd`

- [ ] **Step 1：先写项目身份失败自检**

在新仓库创建 `tests/project_identity_self_check.gd`，断言：

- `ProjectSettings.get_setting("application/config/name") == "project-rest-new"`；
- `SaveSystem.SAVE_PATH == "user://project_rest_new_save.json"`；
- `SaveSystem.BROKEN_SAVE_PATH == "user://project_rest_new_save.broken.json"`；
- 两个存档路径均以 `user://` 开头，且不再包含 `neighbor_dessert`。

自检使用仓库现有 `SceneTree` 退出码模式，并以 `PROJECT_IDENTITY_SELF_CHECK_PASS` 作为成功标记。

- [ ] **Step 2：运行 RED 并确认失败原因准确**

```powershell
Set-Location -LiteralPath $target
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-rest-new-identity-red.log" -s res://tests/project_identity_self_check.gd
if ($LASTEXITCODE -eq 0) { throw 'Identity test should fail before isolation edits.' }
```

Expected: 只因项目名仍为 `project-rest`、存档名仍为 `neighbor_dessert_*` 而失败，不得出现脚本解析错误。

- [ ] **Step 3：完成最小身份修改**

在 `project.godot` 修改：

```ini
config/name="project-rest-new"
```

在 `scripts/save_system.gd` 修改：

```gdscript
const SAVE_PATH := "user://project_rest_new_save.json"
const BROKEN_SAVE_PATH := "user://project_rest_new_save.broken.json"
```

不修改 `scripts/main_view.gd`；它已经通过 `SaveSystem.SAVE_PATH` 和 `SaveSystem.BROKEN_SAVE_PATH` 读取默认值。不得添加旧文件探测、复制、迁移或兼容分支。

- [ ] **Step 4：运行 GREEN**

```powershell
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-rest-new-identity-green.log" -s res://tests/project_identity_self_check.gd
if ($LASTEXITCODE -ne 0) { throw 'Project identity isolation failed.' }
```

Expected: `PROJECT_IDENTITY_SELF_CHECK_PASS`。

---

## Task 4：复制并跟踪独立 UI 静态资源

**文件：**

- Create: `resources/ui/**`（从源功能工作树机械复制）
- Verify unchanged: `.gitignore`

- [ ] **Step 1：确认规则没有忽略目标资源**

```powershell
Set-Location -LiteralPath $target
$ignoreProbe = git check-ignore -q resources/ui/skin/neighborhood_dessert/neighborhood_dessert_theme.tres
if ($LASTEXITCODE -eq 0) { throw 'resources/ui is ignored; stop and review rule drift.' }
```

当前 `.gitignore` 只有 `.godot/`、`/android/` 和 `/.superpowers`，所以本任务不应修改它。

- [ ] **Step 2：复制目录并比较文件集合和哈希**

```powershell
$targetResources = Join-Path $target 'resources'
Copy-Item -LiteralPath $sourceUi -Destination $targetResources -Recurse

$targetUi = Join-Path $target 'resources\ui'
$sourceFiles = Get-ChildItem -LiteralPath $sourceUi -Recurse -File
$targetFiles = Get-ChildItem -LiteralPath $targetUi -Recurse -File
if ($sourceFiles.Count -ne $targetFiles.Count) { throw 'UI file count mismatch after copy.' }

$sourceHashes = $sourceFiles | ForEach-Object {
    $relative = $_.FullName.Substring($sourceUi.Length).TrimStart('\')
    "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
} | Sort-Object
$targetHashes = $targetFiles | ForEach-Object {
    $relative = $_.FullName.Substring($targetUi.Length).TrimStart('\')
    "$relative|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
} | Sort-Object
if (Compare-Object $sourceHashes $targetHashes) { throw 'UI asset hashes differ after copy.' }
```

- [ ] **Step 3：运行皮肤确定性检查**

```powershell
$python = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python tools\build_neighborhood_dessert_skin.py --check
if ($LASTEXITCODE -ne 0) { throw 'Neighborhood dessert skin check failed.' }
```

Expected: `NEIGHBORHOOD_DESSERT_RUNTIME_SKIN_CHECK_PASS`。

---

## Task 5：运行新仓库聚焦回归

**验证范围：** 项目加载、无限等级/配方适配、任务路线、橱窗独立结算与反馈、Python 配方资产。

- [ ] **Step 1：运行 Godot 项目加载检查**

```powershell
Set-Location -LiteralPath $target
& 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP\project-rest-new-load.log" --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot project load failed.' }
```

检查输出和日志中无 `SCRIPT ERROR`、无缺失 `res://resources/ui` 或配方图标。

- [ ] **Step 2：运行六项聚焦 GDScript 自检**

```powershell
$tests = @(
    'infinite_shop_level_self_check.gd',
    'progression_catalog_self_check.gd',
    'task_mainline_self_check.gd',
    'showcase_auto_sale_service_self_check.gd',
    'showcase_backpack_feedback_self_check.gd',
    'showcase_backpack_scene_self_check.gd'
)
foreach ($test in $tests) {
    $log = Join-Path $env:TEMP ("project-rest-new-" + $test + '.log')
    & 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --log-file $log -s "res://tests/$test"
    if ($LASTEXITCODE -ne 0) { throw "Focused self-check failed: $test" }
}
```

- [ ] **Step 3：运行配方 Python 测试**

```powershell
$python = 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python -m unittest tests.test_recipe_data_audit tests.test_generate_showcase_recipe_icons
if ($LASTEXITCODE -ne 0) { throw 'Recipe Python tests failed.' }
```

Expected: 12 项 Python 测试通过。

- [ ] **Step 4：记录广域旧测试的已知边界**

本次不把 `tests/mvp_self_check.gd` 作为阻断门。若为留档而运行，必须原样记录其旧配方总数、旧有限等级和旧任务路线失败；不得在本计划内改写运行逻辑迎合陈旧断言。

---

## Task 6：提交新项目初始化并做最终隔离审计

**新仓库提交范围：**

- `project.godot`
- `scripts/save_system.gd`
- `tests/project_identity_self_check.gd`
- `resources/ui/**`

- [ ] **Step 1：审查精确变更边界**

```powershell
Set-Location -LiteralPath $target
git status --short
git diff --check
git diff -- project.godot scripts/save_system.gd tests/project_identity_self_check.gd
```

Expected: 除四类文件外无其他变更；`.godot/` 不出现；`resources/recipe_icons` 已在克隆基线中而不是本次未跟踪变更。

- [ ] **Step 2：创建新项目自己的首次隔离提交**

```powershell
git add -- project.godot scripts/save_system.gd tests/project_identity_self_check.gd resources/ui
git diff --cached --check
git commit -m '初始化 project-rest-new 独立项目'
```

- [ ] **Step 3：执行最终 Git 和身份审计**

```powershell
if (git status --porcelain) { throw 'Target worktree is not clean.' }
if ((git remote) -ne $null) { throw 'Target unexpectedly has a remote.' }
if ((git branch --show-current).Trim() -ne 'main') { throw 'Target branch changed from main.' }
if (Test-Path -LiteralPath '.git\objects\info\alternates') { throw 'Target uses shared Git objects.' }
git merge-base --is-ancestor $required HEAD
if ($LASTEXITCODE -ne 0) { throw 'Final target lost the adapted baseline.' }
git ls-files resources/ui resources/recipe_icons | Measure-Object
rg -n 'config/name|SAVE_PATH|BROKEN_SAVE_PATH|neighbor_dessert_save' project.godot scripts/save_system.gd
```

Expected:

- 工作区干净，分支 `main`，无远端；
- `.git` 为独立目录且无 alternates；
- `1a85e37` 是新项目 HEAD 的祖先；
- 项目名和两个默认存档名只使用 `project-rest-new` / `project_rest_new`；
- UI 和配方源图都由新仓库自身跟踪。

- [ ] **Step 4：复核源仓库未被执行过程污染**

```powershell
git -C $source status --short
git -C $source branch --show-current
git -C $source remote -v
```

Expected: 源分支和远端不变；源工作树仍只保留执行前已有的未跟踪 `resources/ui`，没有目标项目的存档、`.godot` 或初始化提交泄漏回来。

## 完成定义

仅当 Task 1–6 全部满足时，才可报告 `project-rest-new` 创建完成。任何一步失败都保留现场、说明具体失败命令和当前目录状态，不自动删除目标目录，也不把部分成功描述为完成。
