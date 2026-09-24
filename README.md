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
- 多工地调度由“全局顺序锁”改为“顺序优先级”；
- Military Daily Loop V1、Barracks / Patrol V0、Barracks Logistics V1 和 RTS Camera V1；
- Combat V1，以及数据驱动的 Slime / Wolf 敌人。
- Settlement Patrol Ring V0：WorldBounds、SettlementBounds 和领地级 0→1→2→3 巡逻点；
- Combat / Feature 接口预留 / Ability & Effect 最小框架已完成：保留 FeatureData、独立技能冷却和通用伤害/击退 Effect；当前 Ground Slam 通过配置组合伤害与击退，不扩展为完整技能编辑器。
- Building Durability + Base Defeat V0、Threat Detection V0、城墙/城门基础耐久、Time Rift V0、3 波 Rift Wave 和 Elite V0 已实现；Boss 组配置、裂缝关底 Boss 自动识别与胜利触发框架已接入，恶魔/蜘蛛裂缝 Boss 单位已配置，第一局完整主线流程已由用户实测跑通。
- 「关卡」插件统一管理怪物组和袭扰/裂缝时间线。时间线按基础出现时间排序（随机偏移不参与排序），列出事件名、怪物组、组模式、时间与 BOSS 定位，并用整行文字颜色区分袭扰/裂缝；固定模式按组内单位个数生成，随机模式按单位概率权重组成事件指定的总数。袭扰 BOSS 不参与裂缝主线通关判定；裂缝时间线最后一个 BOSS 事件为关底目标，击败后触发胜利。裂缝事件另可配置波数、波间隔与倒计时。
- 三方势力可互相战斗；Raid 可配置击杀单位、破坏建筑或偷取资源。击杀型目标优先攻击范围内单位；没有单位时攻击最近的非据点建筑，建筑耗尽后攻击据点。破坏建筑型史莱姆按配置优先建筑，否则随机选择；哥布林每次默认偷 3、间隔 1 秒、总额度 15，并掉落单个资源包。
- 袭扰配置检查器按行为显示目标选项；切换行为已改为通知 Inspector 重建属性列表，仍需在编辑器中做交互回归确认。杀伤、破坏和偷窃的目标优先级及其回退逻辑已接入运行时。
- 可受伤建筑由 BuildingBase 自动添加屏幕空间 2D 头顶血条；已存在血条的据点不重复添加。敌人追击攻击距离与占地相关建筑时会保留接近余量。

Population V1 已完成：

```text
PopulationManager / Population HUD       ✅
Base Housing Capacity / House V1         ✅
ImmigrationRules / Food Requirement     ✅
Immigration Countdown / ArrivalPoint     ✅
Migrant → Villager                       ✅
Population / Farm / FOOD 闭环            ✅
```

## 2026-09-20 本轮更新

- 从 Git 快进到 `1da5333 人口HUD显示`，包含 PopulationManager、House 和人口 HUD 基础代码；
- 开始 House / Population V1 阶段 3：新增可配置 ImmigrationRules；
- 移民规则已独立到 `res://data/population/immigration_rules.tres`，`LevelConfig` 只负责引用；
- PopulationManager 现在可以统计数据库中所有 FOOD 资源，判断住房、粮食和预计移民人数；
- 新增 `can_start_immigration()` 和 `get_immigration_status()`；
- 阶段 4 新增移民倒计时和 `immigration_ready` 信号；
- 倒计时期间条件失效会取消并重置，条件恢复后可以重新开始；
- 当前仍不生成 Migrant、不直接增加人口；
- 新增并通过 `house_population_stage3_test.gd`；
- 新增并通过 `house_population_stage4_test.gd`，确认只触发一次且不会每帧重复；
- 当前本轮修改尚未提交 Git，换电脑继续前先保留这些工作区改动。
- 阶段 5 新增 4 个地图外围 ArrivalPoint 和独立 Migrant 场景；
- 倒计时完成后按预计人数生成 Migrant，Migrant 不加入 `villagers` 组，也不计入正式人口；
- Migrant 使用 NavigationAgent3D 前往 Base；
- 阶段 6 新增抵达转换：Migrant 变为普通 Villager，接入资源管理、点击选择和 PopulationManager；
- 新 Villager 初始职业为 `NONE`，会进入正常待命、Needs 和 Task 流程。
- HUD 右上角新增移民状态面板，倒计时显示蓝色 0%～100% 进度条；
- HUD 同时显示本轮移民所需住房、当前空房、所需 FOOD 和当前 FOOD；
- 倒计时中途条件失效时进度归零，并恢复等待状态。
- 建筑基类新增通用拆除接口；正式建筑详情面板提供“拆除（返还 30%）”；
- 拆除按 `BuildingData.construction_cost` 的每种资源返还 30% 到 Base，Base 和施工中的工地不可拆除；
- 拆除前会释放资源建筑工人并取消相关任务。
- 阶段 8 修复移民批次状态：移民出发后不因住房或 FOOD 变化被取消，全部抵达后才允许下一批；正式人口超过住房容量时停止新批次。
- 阶段 8 新增回归测试，覆盖倒计时取消、在途移民保护、下一批移民和人口超住房容量。
- 移民 HUD 的“需要住房”改为显示本批预计人数，保证预计来 2 人时必须准备 2 个空房。
- 修复 Trait Editor 插件因引用不存在的 `StatModifier.StatType.FOOD_CONSUMPTION` 导致无法加载的问题，编辑器选项已与当前属性枚举同步。

当前经营闭环：

```text
初始居民
→ WOOD / STONE 采集、运输与储存
→ 建筑施工
→ Farm 生产 GRAIN
→ 居民 Hunger / Fatigue、吃饭与休息
→ House 提供住房容量
→ FOOD + Housing 满足移民条件
→ Migrant 前往 Base 并转为 Villager
→ 新居民加入生产、物流和施工
```

下一阶段方向：人口与经济转化为军事力量。详细设计只维护在 `ROADMAP.md`。

阶段 7 回归流程：

```text
初始居民工作
→ 建 Farm 并生产 GRAIN
→ 建 House，住房容量增加
→ 右上角确认移民条件和倒计时
→ Migrant 从地图外围前往 Base
→ 抵达后人口增加
→ 新居民进入待命并可分配职业
→ Hunger / Fatigue 正常增长
→ FOOD 消耗随人口增加
```

阶段 7 只做试玩验证，不调整最终平衡，也不实现 FoodPreference、饥饿伤害或正式住房休息点。

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

## House / Population V1

阶段 1～8 已完成并通过实际回归：

- `PopulationManager` 统计真实 Villager 和全局住房容量；
- Base 提供初始住房容量，House 建成后提供 `+3` 住房容量；
- HUD 显示“人口：当前 / 住房容量”；
- House 复用现有 BuildingData、Ghost、Grid、ConstructionSite 和建筑面板流程；
- 阶段 3 新增集中配置的移民规则：最低粮食储备、每名移民粮食需求、最低空房、到达间隔和人数范围；
- 移民规则配置文件位于 `res://data/population/immigration_rules.tres`，可直接在 Godot Inspector 或文本中调整；
- `can_start_immigration()` 只判断条件，FOOD 使用数据库中所有带 `FoodProperties` 的资源；
- 当前移民流程已包含倒计时、生成 Migrant 和抵达后增加正式人口。
- 已完成阶段 4～7：移民倒计时、外围生成、抵达转为 Villager、人口 HUD 和完整经济闭环。
- 阶段 8：已出发的 Migrant 独立于后续条件变化继续前往 Base；本批次未结束前不重复开新批次，结束后才重新检查住房与 FOOD；预计移民人数与所需住房数量一致。

长期人口入口：

```text
Population
├─ Immigration ✅ V1
└─ Expedition  ⏳ 后续
```

阶段 3 的规则测试覆盖：无空房、有房无粮、有房有粮，以及移民人数上限。

阶段 5 的基础测试确认 Migrant 查询和正式人口统计互不混淆；实际生成与移动需要在主场景中观察。

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
res://Tests/house_population_stage3_test.gd
res://Tests/house_population_stage4_test.gd
res://Tests/house_population_stage5_test.gd
res://Tests/house_population_stage6_test.gd
res://Tests/house_population_stage8_test.gd
res://Tests/building_demolition_test.gd
res://Tests/military_stage5_test.gd
```

当前验证状态：

- 资源 V2 阶段 1、阶段 2、阶段 2.5 测试通过；
- 资源 V2 阶段 3 `ResourceStorage` 新旧 ID 兼容测试通过；
- 资源 V2 阶段 4 `ResourceManager` 测试已新增，等待用户在 Godot 中运行确认；
- 资源 V2 阶段 5、阶段 6、阶段 7、阶段 8 已完成代码迁移，等待用户在 Godot 主场景中回归确认；
- House / Population V1 阶段 3～8 已完成代码检查、自动测试和主场景回归；
- 移民 HUD 已确认显示需求住房、当前空房、需求 FOOD、当前 FOOD 和倒计时进度；
- 建筑拆除返还功能已确认可用。
- 施工工地已加入通用取消建造：按当前进度计算取消时间与未消耗材料返还。
- 建筑网格占用已接入通用建筑生命周期，取消施工或拆除完成后会释放原占用格子。
- 暂停期间 UI 操作会进入游戏命令队列，恢复后按顺序执行，游戏世界仍保持暂停。
- 施工取消改为居民执行取消进度，完成后由居民将返还材料搬回据点，材料搬运结束才释放工地。
- 施工面板现在显示正常建造进度条与取消居民数量。
- 取消施工居民在取消完成前会保持取消任务，不会立即回据点接收其他任务。
- 取消施工使用居民专用占用标记，任务管理器不会再把取消居民误判为空闲并重新分配。
- 工地到达判定改为实际距离；导航尚未生成路径时会重新提交目标，避免取消居民原地停住。
- 暂停期间拍下建筑会立即显示并占用网格，但工地任务要到恢复游戏后才激活。
- 施工运输被取消时，居民会携带手中材料实际返回据点入库，再参与取消工地的后续工作。
- 取消工地返料按居民携带量往返运输，每次必须回到工地重新取料，最后一批取出后才删除工地。
- 取消工地会按建筑最大施工人数并行派出返料居民，UI 的尚未搬运材料会在每次取货后递减。
- Military Daily Loop V1 阶段 1～5 已完成，阶段 5 回归测试已新增，等待在 Godot 中运行确认；
- Combat V1 阶段 1 已完成：新增数据驱动 `EnemyData`、统一 `EnemyBase`、`SlimeData.tres` 和占位敌人场景；当前只验证数据读取和初始化，不包含索敌、攻击或死亡；
- 新增 `res://Tests/combat_stage1_test.gd`，覆盖敌人身份、模型占位和基础战斗参数初始化；
- 主场景不再预置静态 Slime，改由左侧调试面板按需放置。
- EnemyBase 已接入统一对象选择系统，点击敌人会从右侧打开 EnemyPanel，显示 ID、生命、伤害、移动速度、攻击范围、攻击间隔和检测范围；
- Combat V1 阶段 2 已完成：新增通用 `HealthComponent`，Enemy 和 Villager/Swordsman 共用 `take_damage()`、生命变化、受伤和死亡接口；
- 阶段 2 的死亡处理会停止实体交互并隐藏对象，暂不加入死亡动画、掉落或战斗 AI；
- 新增 `res://Tests/combat_stage2_test.gd`，覆盖 Slime 和居民的扣血、死亡与伤害上限；
- Combat V1 阶段 3 已完成：Enemy 现在按 Hostile/Settlement 阵营和 CombatRole 筛选检测范围内最近的 Swordsman 目标；目标死亡或离开范围后会清除；本阶段不追击、不攻击；
- 新增 `res://Tests/combat_stage3_test.gd`，覆盖普通居民过滤、剑士索敌、范围清除和死亡目标清除；
- Combat V1 阶段 4 已完成：Slime 会自动追踪检测到的剑士，进入攻击范围后按 Attack Interval 调用目标的 `take_damage()`；当前使用直接追踪，不包含复杂导航、动画或仇恨；
- 新增 `res://Tests/combat_stage4_test.gd`，覆盖自动追踪、进入攻击范围造成伤害和攻击间隔；
- 新增可复用 3D 世界血条：Slime 显示红色血条，剑士显示绿色血条，血量变化即时更新；普通居民默认隐藏血条；
- 修复 3D 血条黑色背景覆盖填充层的问题，填充层现在位于前景并独立渲染；
- 血条显示规则统一为“非满血显示、满血隐藏、死亡隐藏”，HealthBar3D 只依赖父节点生命接口，可复用于单位、敌人、建筑、城墙和 Boss；
- 详情面板切换时立即关闭旧面板，保证敌人、建筑、资源和居民面板不会同时重叠；剑士血条不再依赖职业状态，只按实际生命值显示；
- 修复剑士进军营隐藏、再次出营后血条不刷新的问题；HealthBar3D 现在会监听单位显示状态变化，并按当前生命值恢复显示。
- 血条前景与黑色背景统一使用同一层渲染，避免缩放填充后出现错位；剑士出营时会主动刷新血条。
- 精简居民返回据点待命日志，战斗输出改为记录敌人锁定目标、失去目标和死亡。
- 世界血条改为屏幕空间 2D 控件，通过摄像机投影跟随目标，旋转视角时不会再出现双层血条或背景错位。
- 战斗日志新增每次攻击的实际伤害与剑士剩余生命；剑士生命归零后短暂显示空血条再隐藏模型，便于确认死亡原因。
- 修复剑士死亡后仍计入人口、并在军营建成后被重新调出的异常；死亡单位会立即移出居民组、刷新人口 HUD，从军营驻军、巡逻、补给名单中清理，并在短暂显示死亡状态后释放节点。
- Combat V1 阶段 5 开始：巡逻状态中的剑士会自动检测附近敌人，进入战斗状态追击并按战斗参数攻击；多个剑士可同时攻击同一目标，目标结束后暂时回到待命，巡逻路线恢复留到阶段 6。
- 新增 `res://Tests/combat_stage5_test.gd`，验证两个巡逻剑士可以同时锁定并攻击同一敌人；阶段 5 代码测试已通过，等待 Godot 场景实测。
- Combat V1 阶段 6 开始：目标死亡、隐藏或失效时会重新选择最近的合法敌方单位；附近没有敌人时，剑士恢复被打断前的巡逻状态，敌人筛选支持所有有战斗身份的单位。
- 新增 `res://Tests/combat_stage6_test.gd`，验证最近目标优先、目标失效后的第二目标切换、清场和原巡逻任务恢复；阶段 6 自动测试已通过。
- Combat V1 阶段 7 开始：新增数据驱动的 `WolfData.tres` 和狼视觉场景，狼与史莱姆共用 EnemyBase；调试面板新增“放置狼”，用于验证第二种 EnemyData 的索敌、追击、攻击、受伤和死亡。
- 新增 `res://Tests/combat_stage7_test.gd`，验证狼无需专属脚本即可加载自身视觉场景、读取战斗参数、锁定剑士并造成伤害；阶段 7 自动测试通过，等待 Godot 场景实测。
- 修复剑士战斗入口：剑士不再要求处于巡逻状态，待命、运输、施工等可行动状态也会主动扫描并攻击仇恨范围内的敌人；战斗结束后恢复被打断的原任务。阶段 5、阶段 6 和阶段 7 自动测试通过。
- Combat V1 阶段 10：新增 `EnemyAbility` 能力资源接口，并挂载到 `EnemyData`；`EnemyBase` 可读取能力列表，暂不执行具体技能。新增阶段 8 自动测试，验证敌人可加载空能力列表。
- 左侧调试面板新增“放置史莱姆”按钮：点击后进入地面预览，第二次点击即可在鼠标位置生成真实史莱姆，右键或 Esc 可取消。
- 新增通用仇恨范围圆环：剑士显示绿色检测范围，史莱姆显示红色检测范围；剑士半径读取战斗参数，史莱姆半径读取 EnemyData，普通居民不显示。
- Barracks / Patrol V0 阶段 1 已完成：新增军营建筑、6 人驻军容量和军营 UI，等待用户测试；
- Barracks / Patrol V0 阶段 2 已完成代码，剑士自动驻扎流程等待主场景测试；
- Barracks / Patrol V0 阶段 3 已完成代码：按驻军人数自动选出约一半剑士，出营前往军营门口集合，等待主场景测试；
- Barracks / Patrol V0 阶段 4 已完成首版代码：军营 UI 手动开始巡逻，剑士同步经过 4 个测试巡逻点后返回军营；
- Barracks Logistics V1 阶段 1 已完成代码：军营增加独立 FOOD 库存，容量 60，军营面板显示军粮并提供调试加粮按钮，等待用户测试；
- Barracks Logistics V1 阶段 2 已完成代码：驻军在军营内部按现有 Hunger / Nutrition 逻辑进食，真实消耗军粮并恢复 Hunger，进食中的驻军不会被派去巡逻，等待用户测试；
- Barracks Logistics V1 阶段 5 已完成首版代码：驻军在军营内主动维持最佳状态，饥饿值高于 30 或疲劳值高于 30 时先在军营内恢复，达标后等待自动出巡，等待用户测试；
- Barracks Logistics V1 阶段 6 已完成代码：巡逻返回军营后自动恢复饥饿与疲劳，恢复完成后重新进入待命并参与下一轮巡逻；
- Barracks Logistics V1 阶段 7 已完成回归测试：覆盖不同驻军人数、军粮不足、据点无粮、巡逻轮换和人口统计稳定性；
- 阶段 7 回归修正：据点待机单位使用独立错峰换位计时；无粮且没有实际巡逻队时 UI 不再显示“巡逻进行中”；军粮不足时优先派待命驻军补给，补给完成后自动恢复巡逻；驻军统计按唯一单位去重，巡逻离营时从在营列表移除；
- Resource Editor 已通过 Godot 编辑器插件加载测试并扫描到 7 个资源；
- 多工地任务生成与顺序优先级测试通过；
- Godot 主场景无界面启动通过；
- 用户实际运行暂未发现问题。
- HUD 速度快捷键新增：数字键 `4` 为 5 倍速，数字键 `5` 为 10 倍速；HUD 同时新增 5X / 10X 按钮。
- 新增活动游戏相机：滚轮缩放，中键旋转，Shift+中键平移，WASD 平移；开局聚焦 Base，选中对象后按 `F` 聚焦对象。
- 技能框架新增 `AbilityEntry` 角色覆盖层：技能 `.tres` 保存基础数值，单位可独立覆盖伤害、击退力度和范围倍率；旧技能数组仍兼容。

## 开发约定

1. 每次实际修改都同步更新本 README，但只保留简洁结论。
2. UI 不直接承担游戏规则。
3. 新资源优先通过数据配置扩展，不复制整套代码。
4. Godot 使用严格类型检查，避免 Variant 推断警告。
5. 分阶段迁移；用户运行确认后再进入下一阶段。
6. 不提前开发当前阶段以外的 FOOD 循环、生产建筑、仓库或程序化地图。
7. README 只记录当前真实完成状态；ROADMAP 记录后续方向、系统连接和暂缓功能。

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
- House / Population V1 阶段 1～6：完成；
- House / Population V1 阶段 7 完整人口经济闭环：完成；
- House / Population V1 阶段 8 异常情况回归：完成；
- README 精简为当前状态文档：完成。
