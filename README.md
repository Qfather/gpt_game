# 时间裂缝

> Godot 4.7 工程。当前目标是用简化角色、建筑和 UI 跑通第一关完整闭环。
> 开发顺序与未来玩法见 `ROADMAP.md`。

## 当前状态

已经完成：

- 木材与石材采集、生产建筑、本地仓储和据点运输；
- 网格建造、Ghost 预览、工地物流、多人施工和正式建筑生成；
- 居民、建筑、据点和资源节点的统一选择、描边与详情面板；
- 基础食物来源 V1：Farm、三块 Field、Farmer 动态派工、GRAIN 生产、Farm 本地库存、据点运输和居民消费闭环；
- `UnitBase`、Trait 数据、属性 Modifier 和 Trait Editor；
- 资源系统 V2 阶段 1、阶段 2、阶段 2.5 Resource Editor、阶段 3 ResourceStorage ID 迁移；
- 多工地调度由“全局顺序锁”改为“顺序优先级”。

当前开发节点：

```text
基础食物来源 V1：Farm / GRAIN（已完成并通过实际回归）
下一步：根据试玩优先进入 House / 人口 V1 或 MEAT / FISH 食物来源
```

### 基础食物来源 V1

- Farm 4×4，最多 3 名 Farmer，内部 3 块 2×2 Field 和 FarmHouse；
- Field 状态循环：耕地、播种、生长、成熟、收割；
- Farmer 按田地优先级动态派工，支持认领、中断释放和休息后恢复；
- GRAIN 先进入 Farm 本地库存，再由居民真实运输到据点；
- 据点粮食可被居民实际消费，Needs、Task 和建筑 UI 回归通过。

## 2026-09-19 更新交接

- README 已精简为当前状态、测试、迁移进度和下一步，换电脑后以本文件为准；
- 完成 Resource Editor 阶段 2.5：资源扫描、筛选、新建、编辑、保存、安全删除和数据库引用保护；
- Resource Editor 资料头部与 Trait Editor 统一，资源图标为左侧 1:1 方形区域，ID 与显示名称在右侧；
- Resource Editor 独占新建窗口改为按需创建，解决启用插件时与“项目设置”窗口冲突的问题；
- 完成 ResourceStorage 阶段 3：内部库存统一使用 `StringName` 资源 ID，旧枚举调用继续兼容；
- `Base`、`ResourceManager`、`TaskManager` 已同步资源变化信号参数；
- 新增并通过 `resource_v2_stage3_storage_test.gd`，验证新旧接口共用同一份库存；
- 完成 ResourceManager 阶段 4：总量查询统一使用 Resource ID，同时保留旧枚举兼容入口；
- 新增阶段 4 自动测试，覆盖储存、居民携带和全局总量查询；
- 修复已释放对象仍在清除选择描边时触发的类型转换错误；
- 修复建造材料耗尽后居民滞留在工地的问题，并保留有材料时的后续运输；
- 阶段 5 首步完成：资源建筑生产类型和居民携带资源改用 Resource ID，旧接口继续兼容；
- 修复居民返回据点待命期间领取运输任务却不启动的问题；
- 资源建筑居民离职后主动触发任务调度，让等待中的建造任务由新空闲居民接手；
- 修复施工中的伐木场/采石场取消居民后无法重新增加施工居民的问题；
- 施工材料全部送达或已被运输任务预留后，提前派空闲居民到工地等待最后一批材料；
- 区分运输任务“已预留但未取货”和“材料已在居民身上”，新增库存后可立即生成后续运输任务；
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

Farm / GRAIN 已提供基础食物生产来源；其他食物与加工品目前只证明数据结构能够表达多分类、多层级和食物属性。工程暂无对应资源图标，因此图标暂为空。

### 阶段 3、阶段 4 已完成，阶段 5、阶段 6、阶段 7、阶段 8 等待实际运行确认

- `ResourceStorage` 内部库存和容量统一使用 `StringName` 资源 ID；
- `WOOD / STONE / FOOD` 旧枚举、`String` 和 `StringName` 调用共用同一份库存；
- 资源变化信号传递资源 ID，`Base`、`ResourceManager`、`TaskManager` 已同步兼容；
- 阶段 3 自动测试和主场景已由用户实际运行确认通过；
- 阶段 5 已迁移资源建筑生产 ID、居民携带 ID 和相关面板显示；
- 阶段 6 已迁移建筑成本、ConstructionSite 施工材料和 TaskManager 运输任务，等待用户回归确认。
- 阶段 7 已迁移 HUD、Base 库存面板和资源节点面板，等待用户回归确认。
- 阶段 8 已清理主要运行路径中的旧 `ResourceType` 调用，等待用户回归确认。
- 建筑交互点已按居民分配稳定环形站位，取货、交货和待机不再共用建筑中心点；
- 建造按钮已接入 `BuildingData` tooltip，悬停可查看介绍、功能和所需材料。
- 建造按钮悬停说明改为按钮上方的自定义“标签页 + 详情页”卡片，不再使用会遮住其他按钮的系统 tooltip。

### 尚未迁移

- 旧 `ResourceType` 的全面移除，目前只保留兼容映射；
- 更复杂的建筑解锁、分类和分页菜单。

因此，V2 的 grain、meat、plank、flour、bread 暂时不会出现在游戏运行画面中。

### 当前迁移进度

阶段 4 已将 `ResourceManager` 的总量查询迁移到稳定 Resource ID：

- `get_total()`、`get_storage_total()` 和 `get_carried_total()` 接受 Resource ID；
- `ResourceType.Type`、`String` 和 `StringName` 继续兼容并统一转换到 Resource ID；
- 储存与居民携带仍统计同一份运行数据，不建立平行库存；

阶段 5 再将居民携带和资源建筑的运行参数迁移到稳定 Resource ID：

- `WOOD → &"wood"`；
- `STONE → &"stone"`；
- `FOOD → &"food"`；
- 新旧接口共用同一份库存，不建立平行库存。

阶段 5 已完成首步迁移：

- `ResourceBuildingBase.production_resource_id` 作为生产资源身份；
- `Villager.carried_resource_id` 作为携带资源身份；
- 居民面板和资源建筑面板通过 Resource ID 查询资源资料；
- 旧枚举接口暂时保留，供阶段 6 迁移前的施工系统兼容。

阶段 2.5 不迁移运行逻辑，也未开发 Recipe Editor 或生产建筑。

阶段 6 首步已完成：

- `BuildingData.construction_cost` 使用 Resource ID 字典；
- `ConstructionSite` 的需求、已送达、已预约和材料显示使用 Resource ID；
- `TaskManager` 创建的施工运输任务使用 `resource_id`；
- 多个同类工地按创建先后分配库存，运输任务的预留材料会从全局可用库存中扣除；
- 施工居民使用稳定分散的工地边缘站位，居民之间不再用实体碰撞互相阻挡；
- 旧的 `ResourceType` 接口和旧任务字段仍保留读取兼容。

阶段 7 首步已完成：

- HUD 通过 `&"wood"` 和 `&"stone"` 查询全局总量；
- Base 库存面板通过 Resource ID 查询木材、石头和食物；
- 资源节点面板通过 Resource ID 查询资源资料和显示名称；
- `ResourceBase` 保留旧 `resource_type`，新增 `get_resource_id()` 兼容入口。

阶段 7 回归确认后，再继续清理剩余运行逻辑中的旧枚举入口。

阶段 8 首步已完成：

- 开局资源、调试快捷键、Base 和伐木场正式接口使用 Resource ID；
- 居民采集筛选使用 Resource ID；
- 资源节点正式字段改为 `resource_id`；
- 旧枚举属性、转换函数和旧测试保留兼容。

建筑 UI 继续复用现有 `BuildingPanelBase`，没有新增重复的建筑面板基类；建造按钮的悬停说明由 HUD 统一生成。

阶段 9 首步已完成：

- 建造按钮由 `BUILDING_OPTIONS` 数据列表统一配置；
- 按钮名称、点击事件和 tooltip 均来自 `BuildingData`；
- 保留当前两个按钮的布局，后续新增建筑可复用同一套菜单逻辑。

## 居民生活循环 V1 ✅

居民生活循环 V1 已完成并通过当前回归测试：

- Hunger、Fatigue、ActivityLevel 按实际行为持续更新；
- 工作时需求增长更快，休息时 Fatigue 恢复；
- 通过通用 `find_available_food()` / `choose_food()` 查询 FOOD；
- 进食按 `FoodProperties.nutrition` 降低 Hunger，低于或达到 10% 后停止；
- 又饿又累时一次回据点，休息期间同时进食；
- 携带材料时先完成安全运输，没有携带材料时才安全释放公共任务；
- 休息结束后恢复原 Job / Workplace / Idle 状态；
- 建筑完工时会继承施工、等待和运输居民的正式岗位；
- VillagerPanel 显示中文职业、任务、生活状态和 Hunger / Fatigue 颜色进度条；
- 左侧调试面板可调整资源、选中居民的 Hunger 与 Fatigue。

当前 Hunger、Fatigue、Eating、Resting 数值仍主要用于开发测试，正式时间尺度将在第一关闭环（经营 → 守城 → Boss）跑通后统一平衡。

暂不实现：FoodPreference、Starvation、HealthComponent 饥饿伤害、House 正式休息地点。

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
- `J`：给 Base 增加测试石头；
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
res://Tests/resource_v2_stage4_manager_test.gd
res://Tests/construction_site_priority_test.gd
```

当前验证状态：

- 资源 V2 阶段 1、阶段 2、阶段 2.5 测试通过；
- 资源 V2 阶段 3 `ResourceStorage` 新旧 ID 兼容测试通过；
- 资源 V2 阶段 4 `ResourceManager` 测试已新增，等待用户在 Godot 中运行确认；
- 资源 V2 阶段 5、阶段 6、阶段 7、阶段 8 已完成代码迁移，等待用户在 Godot 主场景中回归确认；
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
- 资源系统 V2 阶段 4 ResourceManager 迁移：完成并已实际运行确认；
- 资源系统 V2 阶段 5 居民携带与资源建筑迁移：代码完成，待用户运行确认；
- 资源系统 V2 阶段 6 建筑成本、ConstructionSite 与施工运输任务迁移：代码完成，待用户运行确认；
- 资源系统 V2 阶段 7 HUD、Base 面板与资源节点面板迁移：代码完成，待用户运行确认；
- 资源系统 V2 阶段 8 运行路径旧枚举清理：代码完成，待用户运行确认；
- README 精简为当前状态文档：完成。
