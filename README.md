# 时间裂缝

> Godot 4.7 工程。当前目标是用简化角色、建筑和 UI 跑通第一关完整闭环。
> 开发顺序与未来玩法见 `ROADMAP.md`，资源迁移细节见 `GPT_Game_资源系统V2_分阶段迁移计划.md`。

## 当前状态

已经完成：

- 木材与石材采集、生产建筑、本地仓储和据点运输；
- 网格建造、Ghost 预览、工地物流、多人施工和正式建筑生成；
- 居民、建筑、据点和资源节点的统一选择、描边与详情面板；
- `UnitBase`、Trait 数据、属性 Modifier 和 Trait Editor；
- 资源系统 V2 阶段 1、阶段 2、阶段 2.5 Resource Editor、阶段 3 ResourceStorage ID 迁移；
- 多工地调度由“全局顺序锁”改为“顺序优先级”。

当前开发节点：

```text
资源系统 V2 阶段 3：ResourceStorage 迁移到 Resource ID（代码与自动测试完成，等待用户运行确认）
下一步：资源系统 V2 阶段 4 ResourceManager 迁移
```

## 2026-09-19 更新交接

- README 已精简为当前状态、测试、迁移进度和下一步，换电脑后以本文件为准；
- 完成 Resource Editor 阶段 2.5：资源扫描、筛选、新建、编辑、保存、安全删除和数据库引用保护；
- Resource Editor 资料头部与 Trait Editor 统一，资源图标为左侧 1:1 方形区域，ID 与显示名称在右侧；
- Resource Editor 独占新建窗口改为按需创建，解决启用插件时与“项目设置”窗口冲突的问题；
- 完成 ResourceStorage 阶段 3：内部库存统一使用 `StringName` 资源 ID，旧枚举调用继续兼容；
- `Base`、`ResourceManager`、`TaskManager` 已同步资源变化信号参数；
- 新增并通过 `resource_v2_stage3_storage_test.gd`，验证新旧接口共用同一份库存；
- 当前改动仍在工作区，尚未提交 Git，不要用重置或清理命令覆盖现有修改。

## 核心系统

### 单位与 Trait

```text
TraitData
→ TraitLevelData
→ StatModifier
→ UnitTrait
→ UnitBase.get_stat()
→ 单位实际属性
```

Trait 使用稳定 `trait_id`；中文名称只负责显示。编辑器插件位于：

```text
res://addons/trait_editor/
```

### 当前资源运行链

现有游戏仍使用旧兼容体系：

```text
Resource ID / ResourceType.Type 兼容入口
→ ResourceStorage（内部统一 Resource ID）
→ ResourceBase / ResourceBuildingBase
→ Villager 携带与运输
→ Base
→ HUD
```

当前可运行资源为 `WOOD / STONE / FOOD`。Tree 产出木材，Stone 产出石材。

### 建造系统

```text
底部建造菜单
→ BuildingGhost
→ BuildGrid
→ ConstructionSite
→ TaskManager 派发运输
→ 居民搬运材料
→ 多人施工
→ 生成正式建筑
```

工地按放置顺序获得任务优先级，但不会全局锁死后续工地。较早工地无法推进时，空闲居民可以处理后续工地。

资源型建筑完工后，施工居民会直接成为该建筑工人。

### 对象详情 UI

```text
居民        → VillagerPanel
资源建筑    → ResourceBuildingPanel
Base        → ResourceBuildingPanel
Tree/Stone  → ResourceNodePanel
```

对象选择互斥，统一使用黄色描边；面板统一播放滑入和收回动画。

## 资源系统 V2

### 已完成

- `ResourceData`：稳定 ID、显示名称、Category、Tier、Tags、图标、堆叠上限；
- `FoodProperties`：营养、品质、多样性分组；
- `ResourceDatabase`：注册、查询、索引、重复与无效 ID 检查；
- 正式数据库：`res://data/resources/resource_database.tres`；
- 首批 7 种资源定义；
- Resource Editor：扫描筛选、新建、编辑、保存和安全删除资源定义；
- Resource Editor 使用与 Trait Editor 一致的资料头部：1:1 方形图标位于资源 ID 和显示名称左侧；
- Resource Editor 的独占弹窗按需创建，启用插件时不会与“项目设置”窗口冲突。

| Tier | 资源 |
|---|---|
| T1 | wood、stone、grain、meat |
| T2 | plank、flour |
| T3 | bread |

食物与加工品目前只证明数据结构能够表达多分类、多层级和食物属性，尚无生产来源或生产建筑。工程暂无对应资源图标，因此图标暂为空。

### 阶段 3 已完成，等待实际运行确认

- `ResourceStorage` 内部库存和容量统一使用 `StringName` 资源 ID；
- `WOOD / STONE / FOOD` 旧枚举、`String` 和 `StringName` 调用共用同一份库存；
- 资源变化信号传递资源 ID，`Base`、`ResourceManager`、`TaskManager` 已同步兼容；
- 阶段 3 自动测试通过，未迁移居民、建筑和 HUD 的上层资源参数。

### 尚未迁移

- `ResourceManager` 的查询参数仍保留旧枚举入口；
- 居民携带与资源建筑；
- `BuildingData / ConstructionSite / TaskManager` 的资源参数；
- HUD、Base 面板和资源节点面板；
- 旧 `ResourceType` 的全面移除，目前只保留兼容映射。

因此，V2 的 grain、meat、plank、flour、bread 暂时不会出现在游戏运行画面中。

### 下一步

阶段 4 将 `ResourceManager`、居民携带和资源建筑的运行参数迁移到稳定 Resource ID：

- `WOOD → &"wood"`；
- `STONE → &"stone"`；
- `FOOD → &"food"`；
- 新旧接口共用同一份库存，不建立平行库存。

阶段 2.5 不迁移运行逻辑，也未开发 Recipe Editor 或生产建筑。

换电脑后开始阶段 4 前，先运行阶段 3 测试并检查主场景；确认没有解析错误后，再迁移
`ResourceManager` 的总量查询，保持 `ResourceType.Type` 兼容入口，不建立第二份库存。

## 操作

### 建造

- 点击底部“伐木场”或“采石场”进入放置模式；
- 鼠标左键确认；
- 鼠标右键或 `Esc` 取消；
- `R` 旋转；
- `M` 镜像。

### 对象选择

- 点击居民、建筑、Base、Tree 或 Stone 打开对应详情；
- 点击世界空地关闭面板并清除描边。

### 开发模式

`Script/dev_mode.gd` 当前为开启状态。调试键包括：

- `H`：给 Base 增加测试木材；
- `D`：向工地投入测试材料；
- `T / C / R / F`：任务创建、领取、释放、完成测试。

发布或正式试玩前应关闭 `DevMode.DEV_MODE`。

## 测试

现有自动测试：

```text
res://Tests/resource_v2_stage1_test.gd
res://Tests/resource_v2_stage2_test.gd
res://Tests/resource_editor_stage2_5_test.gd
res://Tests/resource_v2_stage3_storage_test.gd
res://Tests/construction_site_priority_test.gd
```

当前验证状态：

- 资源 V2 阶段 1、阶段 2、阶段 2.5 测试通过；
- 资源 V2 阶段 3 `ResourceStorage` 新旧 ID 兼容测试通过；
- Resource Editor 已通过 Godot 编辑器插件加载测试并扫描到 7 个资源；
- 多工地任务生成与顺序优先级测试通过；
- Godot 主场景无界面启动通过；
- 用户实际运行暂未发现问题。

## 开发约定

1. 每次实际修改都同步更新本 README，但只保留简洁结论。
2. UI 不直接承担游戏规则。
3. 新资源优先通过数据配置扩展，不复制整套代码。
4. Godot 使用严格类型检查，避免 Variant 推断警告。
5. 分阶段迁移；用户运行确认后再进入下一阶段。
6. 不提前开发当前阶段以外的 FOOD 循环、生产建筑、仓库或程序化地图。

## 关键里程碑

- 建造系统第一轮：完成；
- Villager UnitPanel 与统一对象详情 UI：完成；
- 资源系统 V2 计划修订：完成；
- 资源系统 V2 阶段 1：完成；
- 多工地顺序锁修正：完成；
- 资源系统 V2 阶段 2：完成；
- 资源系统 V2 阶段 2.5 Resource Editor：完成；
- 资源系统 V2 阶段 3 ResourceStorage ID 迁移：代码与自动测试完成，待用户运行确认；
- README 精简为当前状态文档：完成。
