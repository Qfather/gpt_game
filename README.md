# 时间裂缝 --- 工程 README

> 更新日期：2026-09-18\
> 用途：记录当前工程**已经实际完成的系统、稳定约定和当前开发节点**。\
> 未来计划、支线想法和开发顺序请查看 `ROADMAP_时间裂缝.md`。

# 1. 当前核心目标

当前阶段仍以"胶囊角色 + 方块建筑 + 最简单 UI"完成第一关闭环为最高目标：

``` text
据点 + 初始居民
→ 资源生产
→ 自动采集 / 搬运
→ 木材 / 石材 / 食物
→ 建造
→ 训练战斗职业
→ 敌人
→ 自动战斗
→ Boss
→ 胜利 / 失败
```

当前不追求完整模拟深度和正式美术。

# 2. 当前工程核心架构

## 2.1 单位

当前已有统一单位基类 `UnitBase`。

基础属性包含：

-   最大生命
-   生命恢复
-   移动速度
-   食物消耗
-   工作速度
-   采集速度
-   攻击力
-   攻击速度

最终属性通过统一接口读取：

``` text
基础属性
+ Trait Modifier
= 当前最终属性
```

常用接口包括：

``` gdscript
get_max_health()
get_health_regen()
get_move_speed()
get_food_consumption()
get_work_speed()
get_gather_speed()
get_attack_damage()
get_attack_speed()
```

## 2.2 Trait 系统

当前 Trait 底层已经跑通：

``` text
TraitData
→ TraitLevelData
→ StatModifier
→ UnitTrait
→ UnitBase.get_stat()
→ 单位实际行为
```

已验证示例：

``` text
基础移动速度 3.0
+ 飞毛腿 10%
= 最终移动速度 3.3
```

`TraitData` 已包含稳定 `trait_id`，用于程序、数据库和存档；中文
`trait_name` 只负责显示。

Trait 当前支持：

-   唯一 ID
-   中文名称
-   描述
-   ICON
-   品级
-   正面 / 负面 / 混合
-   分类
-   抽取权重
-   多等级
-   每等级多个 `StatModifier`

显示约定：

``` text
只有一个等级 → 飞毛腿
多个等级     → 飞毛腿 Lv.2
```

同一个 Trait 的所有等级共用 ICON。

## 2.3 Trait Editor

已建立 Godot 编辑器插件：

``` text
res://addons/trait_editor/
```

当前已经能够：

-   扫描 Trait 数据目录
-   新建 / 删除 / 刷新 Trait
-   新建 Trait 时输入稳定 ID
-   编辑中文名称、描述、ICON
-   编辑性质、品级、分类、权重
-   添加等级
-   编辑等级 Modifier
-   保存修改
-   点击 Trait 与 Inspector 联动
-   左侧按品级 / 分类筛选

当前编辑器布局已经稳定，不再作为主线开发重点。

# 3. 通用资源框架

这是近期完成的重要重构。

## 3.1 ResourceType

全工程资源类型统一使用：

``` gdscript
ResourceType.Type.WOOD
ResourceType.Type.STONE
ResourceType.Type.FOOD
```

不再在 `ResourceBase` 或其他脚本中重复定义资源枚举。

## 3.2 ResourceStorage

已经建立通用仓储组件 `ResourceStorage`。

支持：

``` gdscript
get_amount(resource_type)
get_capacity(resource_type)
get_free_space(resource_type)

add(resource_type, amount)
take(resource_type, amount)
consume(resource_type, amount)

has(resource_type, amount)
is_empty(resource_type)
is_full(resource_type)
```

关键语义：

``` text
add()     → 返回实际成功存入数量
take()    → 返回实际成功取出数量
consume() → 资源完全足够才扣除
```

容量不足时不允许资源凭空消失。

任何未来需要存储资源的建筑原则上都应优先复用：

``` text
Building
└── ResourceStorage
```

## 3.3 Base

据点已经接入 `ResourceStorage`。

据点不再只保存一个独立 `wood` 变量，而是通过统一资源接口管理：

``` text
WOOD
STONE
FOOD
```

HUD 已经通过通用 `resource_changed(resource_type, new_amount)`
信号读取据点资源。

## 3.4 ResourceBase

资源节点统一拥有：

``` gdscript
resource_type: ResourceType.Type
```

当前：

``` text
Tree  → WOOD
Stone → STONE
```

资源节点继续负责：

-   随机资源数量
-   预约 / 释放
-   gather()
-   资源耗尽后删除

# 4. LumberCamp 与通用物流

伐木场目前是第一个完整资源生产建筑模板。

## 4.1 工作系统

已支持：

-   最大岗位
-   当前工人列表
-   招募
-   解雇
-   工作范围
-   无业居民分配
-   点击建筑打开 UI

## 4.2 本地仓储

LumberCamp 已经接入：

``` text
LumberCamp
└── ResourceStorage
```

并拥有：

``` gdscript
production_resource_type = ResourceType.Type.WOOD
```

正式资源接口已经通用化：

``` gdscript
deposit_resource()
take_resource()
has_resource()
get_resource_amount()
get_resource_capacity()
```

旧的木材专用接口如果仍存在，只作为兼容层，不再作为未来架构方向。

## 4.3 Villager 通用携带

居民正式携带数据已经改为：

``` gdscript
carried_resource_type
carried_amount
```

不再把"背包"定义成只能携带木材。

空背包判断以：

``` text
carried_amount <= 0
```

为准。

不要在卸货后强制把 `carried_resource_type` 重置为
`WOOD`；资源类型由实际采集 / 取货行为覆盖。

## 4.4 当前完整物流链

``` text
Tree / ResourceBase
resource_type = WOOD
        ↓
Villager 采集
        ↓
carried_resource_type = WOOD
carried_amount = X
        ↓
LumberCamp
production_resource_type = WOOD
        ↓
ResourceStorage
WOOD = X / Capacity
        ↓
Villager 运输
        ↓
Base
        ↓
ResourceStorage
WOOD += X
        ↓
resource_changed
        ↓
HUD
```

当前伐木闭环已经实际运行正常。

部分入库也已经考虑：

``` text
居民携带 10
目标只能存 5
→ 实际存 5
→ 居民仍保留 5
```

# 5. 建筑 UI

已有 `BuildingPanelBase` 作为建筑面板基类。

资源建筑面板 `ResourceBuildingPanel` 已支持：

-   建筑名称
-   当前库存 / 容量
-   当前工人 / 最大工人
-   招募
-   解雇
-   关闭
-   打开期间刷新

资源建筑 UI 已开始按照 `production_resource_type` +
通用仓储接口读取数据。

目标是让 LumberCamp、Quarry 等资源建筑共用同一套
Panel，而不是每种资源复制一套 UI。

# 6. 已确定但暂未进入主线的居民需求

未来居民基础循环：

``` text
工作 X 秒
→ 回据点
→ 消耗食物
→ 休息 Y 秒
→ 继续工作
```

已经考虑：

-   `FOOD_CONSUMPTION`
-   工作持续时间
-   休息时间

第一版没有食物时先等待，不立即实现饿死。

更复杂的挨饿、住房、幸福感、人口上限等放在 ROADMAP 支线。

# 7. Trait 后续表现扩展

除了数值 Modifier，未来 Trait 还可以影响单位视觉表现。

已记录支线方向：

``` text
Trait
→ UnitVisualModifier（未来）
→ 模型 / Visual Scale
→ 碰撞体尺寸同步
```

例如：

``` text
高大 → 模型更高大 + 碰撞体同步
矮小 → 模型更小 + 碰撞体同步
```

设计原则：

-   Trait 不直接散落修改 `Villager.scale`
-   视觉节点和物理碰撞应区分处理
-   体型变化后碰撞体必须同步，避免模型与碰撞范围不一致
-   后续还可扩展颜色、附件、特效等表现

当前不实现。

# 8. 当前开发节点

已经完成：

``` text
伐木生产闭环
→ 建筑 UI
→ UnitBase
→ TraitData / TraitLevelData / StatModifier
→ Trait Editor
→ Trait 实际属性计算
→ ResourceType
→ ResourceStorage
→ Base 通用仓储
→ LumberCamp 通用仓储
→ Villager 通用资源携带
→ 通用资源运输
```

## 当前下一章节

``` text
STONE + Quarry
```

目的不是增加复杂玩法，而是用第二种真实资源验证通用资源框架：

``` text
Stone
→ Miner
→ Quarry
→ Quarry ResourceStorage
→ Villager 运输
→ Base ResourceStorage
→ HUD Stone
```

如果这一流程可以基本不复制 Villager
主状态机就跑通，说明通用资源架构验证成功。

# 9. 开发原则

1.  先闭环，再深度。
2.  先胶囊方块，再正式美术。
3.  通用底层可以提前做好，但不提前实现大量未来玩法。
4.  UI 不直接承担游戏规则。
5.  Trait、职业、资源类型保持职责分离。
6.  新资源优先通过配置扩展，而不是复制整套代码。
7.  Godot 当前严格类型检查，避免 Variant 推断 Warning-as-error。
8.  多文件联动重构优先让客户端 GPT 直接读取完整工程修改。
9.  开发一段时间后重新上传完整工程复查 README / ROADMAP。

# 10. 阶段实施与修改记录

## 10.1 ResourceManager + HUD 事件驱动改造

修改文件：

~~~ text
Script/resource/ResourceManager.gd
Script/unit/game/villager.gd
Script/ui/hud.gd
~~~

## 10.11 建造系统阶段 10：施工完成生成正式建筑

修改文件：

~~~ text
Script/construction_site.gd
Script/task_manager.gd
UI/building_panel/resource_building_panel.gd
~~~

完成内容：

-   施工进度达到当前 BuildingData.construction_time 后，工地进入完成状态；
-   按原网格位置、旋转和镜像生成 BuildingData.building_scene；
-   完工时取消并清理工地相关任务；
-   释放施工居民并清理 ConstructionSite；
-   正式建筑自动注册到 Main 的建筑点击和面板系统；
-   工地面板在工地被替换后自动隐藏；
-   非资源型建筑完工清理施工任务时，施工居民返回据点公共待命区；资源型建筑按下一条规则直接接管施工居民；
-   资源型建筑完工时，施工居民直接转入正式建筑的工人列表，自动成为伐木工或矿工并开始工作；
-   曾将居民到达工地的中心距离放宽到 3 米用于排查；后续已由按居民分配外围站位的方案取代；
-   工地导航目标会投影到导航网格最近可行走点，避免目标落在不可行走区域；
-   修正手动取消运输居民后自动补位的问题：取消会释放预约并暂停自动补任务，只有点击增加居民才恢复补位；
-   修正最后一名已完成运输居民无法取消的问题：无活动运输任务时也会从运输/施工候选列表移除，并返回据点待命；
-   工地按居民分配外围站位，搬运和施工不再共同争抢建筑中心点，避免先到居民阻挡最后一名携带木材的居民；
-   修正建筑落地高度：移除 Ghost 放置时额外的 0.5 米抬高，使工地、Ghost 和正式建筑都以地面为根节点基准；
-   将居民外围站位距离从占地最大边长一半加 1 米调整为加 0.5 米，保持分散并缩短与建筑的距离；
-   居民站位改为读取建筑场景 MeshInstance3D 的水平包围盒，在模型边缘外扩 0.35 米后随机生成并缓存站位；
-   居民站位改为将模型外围分成多个区段，每名居民在不同区段内随机取点，避免居民集中在同一条边；
-   资源不足时不再让居民长期停在工地等待：搬运任务释放预约后，居民返回据点公共待命区，可被其他建筑运输任务领取；
-   资源补充时由 TaskManager 通知缺料工地重新创建运输任务；
-   当工地只剩一趟材料运输且据点有资源时，仅派对应数量居民去据点，其余已分配居民直接前往工地等待；据点完全无资源时则全部返回公共待命区；
-   增加所有工地的施工队优先级：伐木场、采石场等按放置顺序占用居民，前一个工地完成材料阶段后才轮到后一个，避免同一批居民被不同建筑同时抢走；
-   据点没有对应材料时不再创建空运输任务；工地完成材料阶段后由 TaskManager 持续唤醒后续工地，确保施工队顺序能够正确切换；
-   兼容当前 Godot 版本：改用手动变换包围盒 8 个顶点，避免调用不存在的 AABB.transformed()；
-   建造入口改为屏幕下方建造菜单：进入游戏不再默认开启伐木场 Ghost，点击“伐木场”或“采石场”后才进入预览，再点击地面确认放置；
-   修正 Ghost 初始化可见性：即使创建了预览模型，未选择建筑时也保持隐藏，避免启动场景中心出现伐木场 Ghost；

测试状态：

~~~ text
代码与场景引用静态检查通过。
已完成并验证材料运输、多人施工、正式建筑生成、建筑点击面板，
以及 LumberCamp / Quarry 原有资源建筑逻辑。
~~~

完成内容：

-   ResourceManager 新增 resources_changed 信号；
-   ResourceStorage 和 Villager 携带资源变化统一触发 deferred 刷新；
-   Villager 新增 carried_resource_changed；
-   HUD 删除资源相关 _process() 每帧扫描；
-   全局资源总量保持为所有 Storage + 居民携带资源；
-   动态生成居民通过 register_villager() 接入 ResourceManager。

状态：

~~~ text
静态检查通过。
HUD 事件驱动逻辑已完成。
~~~

## 10.2 建造系统阶段 1：LevelConfig

新建文件：

~~~ text
Script/level_config.gd
data/levels/Level_01.tres
~~~

修改文件：

~~~ text
Script/main.gd
Scene/main.tscn
Script/building/game/lumber_camp.gd
Script/resource/ResourceManager.gd
~~~

完成内容：

-   LevelConfig 支持初始木材、石头和居民数量；
-   Main 根据 Level_01.tres 给 Base 注入初始资源；
-   根据 initial_villagers 在 Base 附近动态生成居民；
-   移除 Main.tscn 中手工摆放的 5 个居民；
-   移除 LumberCamp 启动时自动把空闲居民设置为伐木工的临时逻辑；
-   动态居民保持 Job.NONE，并注册到 ResourceManager。

测试结果：

~~~ text
已通过。
居民数量、初始资源和原有采集流程验证正常。
~~~

## 10.3 建造系统阶段 2：BuildingData

新建文件：

~~~ text
Script/building_data.gd
data/buildings/LumberCampData.tres
data/buildings/QuarryData.tres
~~~

完成内容：

-   建立通用 BuildingData Resource；
-   支持建筑 ID、显示名称、建筑场景、占地、成本、施工时间、最大施工人数；
-   支持旋转和镜像配置；
-   LumberCamp 与 Quarry 蓝图数据已建立，场景引用正确。

测试结果：

~~~ text
已通过。
两个 .tres 可在 Inspector 编辑，原有建筑运行正常。
~~~

## 10.4 建造系统阶段 3：BuildGrid

新建文件：

~~~ text
Script/build_grid.gd
~~~

修改文件：

~~~ text
Scene/main.tscn
~~~

完成内容：

-   主场景新增 Systems/BuildGrid；
-   实现世界坐标与网格坐标互转；
-   实现网格边界检查；
-   实现区域占用、释放和重复占用检测；
-   支持 3×2 旋转为 2×3；
-   当前使用 1 米单元、30×30 平地网格；
-   保留 Inspector 可开启的临时调试测试。

测试结果：

~~~ text
已通过。
坐标转换、3×2 旋转、占用、冲突检测和释放均正常。
~~~

当前阶段：

~~~ text
阶段 3 已完成。
下一阶段：BuildingGhost。
等待用户确认后开始。
~~~
## 10.5 建造系统阶段 4：BuildingGhost

新建文件：

~~~ text
Script/building_ghost.gd
~~~

修改文件：

~~~ text
Scene/main.tscn
~~~

完成内容：

-   主场景新增 Systems/BuildingGhost；
-   默认加载 LumberCampData 作为当前蓝图；从 building_scene 提取静态 MeshInstance3D，使用半透明材质作为 Ghost 预览。
-   鼠标位置投射到地面并吸附 BuildGrid；
-   R 键按 90 度旋转；
-   M 键切换镜像；
-   合法位置显示绿色半透明预览；
-   非法位置显示红色半透明预览；
-   左键确认时只打印 BuildingData、网格坐标、旋转和镜像状态；
-   右键或 Esc 取消预览；
-   本阶段未生成正式建筑、未创建 ConstructionSite、未接入施工物流；主场景测试时暂时只保留 Base，移除 LumberCamp 和 Quarry 实例，相关场景与蓝图数据保留。

测试结果：

~~~ text
已通过。
Ghost 模型变换、半透明显示、网格吸附、旋转、镜像、合法性反馈、确认和取消均正常。
点击确认只打印参数并隐藏 Ghost，未生成正式建筑。
~~~
修复记录：

-   修复 Main.tscn 中 BuildingGhost 与 LumberCampData 的 ExtResource 声明缺失问题。
-   修复 BuildingGhost 鼠标世界坐标从 Variant 推断导致的 Warning-as-error。
-   Ghost 改为递归保留建筑场景各级 Node3D Transform，只复制静态模型并叠加透明材质。
## 10.6 建造系统阶段 5：ConstructionSite

新建文件：

~~~ text
Script/construction_site.gd
Scene/building/construction_site.tscn
~~~

修改文件：

~~~ text
Script/building_ghost.gd
~~~

完成内容：

-   Ghost 合法确认后生成 ConstructionSite，不生成正式建筑；
-   工地保存 BuildingData、网格坐标、rotation_step 和 mirrored；
-   工地状态支持 WAITING_RESOURCES、READY_TO_BUILD、BUILDING、COMPLETED、CANCELLED；
-   保存 required_resources、delivered_resources、reserved_resources、construction_progress 和 builders；
-   still_needed 按 required - delivered - reserved 计算；
-   工地使用临时橙色标记；
-   D 键按 debug_delivery_amount 投入材料，用于验证部分材料和全部材料；
-   工地投入材料暂不进入 ResourceManager 全局库存；
-   工地占用 BuildGrid，暂不接入居民搬运和施工任务。

测试结果：

~~~ text
已通过。
工地生成、required_resources、delivered_resources、reserved_resources、
still_needed，以及 WAITING_RESOURCES → READY_TO_BUILD 状态转换均正常。
~~~
## 10.7 建造系统阶段 6：GameTask + TaskManager

新建文件：

~~~ text
Script/game_task.gd
Script/task_manager.gd
~~~

修改文件：

~~~ text
Script/unit/game/villager.gd
Scene/main.tscn
~~~

完成内容：

-   建立 GameTask 数据对象；
-   支持 DELIVER_CONSTRUCTION_RESOURCE 和 BUILD 两类任务；
-   支持 AVAILABLE、CLAIMED、IN_PROGRESS、COMPLETED、CANCELLED 状态；
-   TaskManager 支持创建、注册、查找、领取、释放、完成和取消；
-   Villager 新增 can_take_task()；
-   Job.NONE 且 current_task 为空的居民才具备公共任务资格；
-   TaskManager 不控制移动、不计算施工速度、不修改资源；
-   主场景加入 TaskManager；
-   临时调试按键：T 创建、C 领取、R 释放、F 完成。

测试状态：

~~~ text
任务对象、TaskManager 的创建/领取/释放/完成接口已接入阶段 7 的真实搬运流程。
阶段 6 的独立调试按键仍保留；最终领取、释放、完成行为随阶段 7 一并验证。
~~~

## 10.8 建造系统阶段 7：施工材料自动搬运

修改文件：

~~~ text
Script/construction_site.gd
Script/unit/game/villager.gd
Script/task_manager.gd
~~~

完成内容：

-   ConstructionSite 进入 WAITING_RESOURCES 后自动创建施工材料搬运任务；
-   按建筑的 max_construction_workers 并行预约搬运任务；每个任务最多预约 5 个单位，避免多个居民重复领取同一批材料；
-   LumberCamp 的 max_construction_workers 为 3：20 木材先分配给 3 名居民各搬 5 个，完成一趟后只补足剩余的第 4 趟；
-   修正工地状态判断：预约中的材料不计入已交付，必须实际 delivered_resources 达到需求后才进入 READY_TO_BUILD；
-   空闲居民自动领取任务，寻找拥有对应资源的 ResourceStorage；
-   居民从 Base 取出材料后，先保留在自身携带量中，交付工地时才扣除据点库存并增加工地 delivered_resources；
-   交付完成后 TaskManager 标记任务完成，工地自动请求下一批材料；
-   搬运任务找不到资源或目标失效时释放任务和预约；
-   阶段 6 的任务状态测试与阶段 7 的真实搬运流程合并验证；
-   保留 D 键临时投入材料功能，但阶段 7 测试不使用该调试入口。

测试状态：

~~~ text
已通过。
放置 LumberCamp Ghost 后，工地自动创建搬运任务，最多 3 名居民并行领取；
总需求 20 木材按每次 5 个单位分批搬运，TaskManager 的创建、领取和完成流程正常。
工地材料状态与 READY_TO_BUILD 状态转换正常。
~~~

## 10.9 建造系统阶段 8：施工任务

修改文件：

~~~ text
Script/construction_site.gd
Script/task_manager.gd
Script/unit/game/villager.gd
Script/main.gd
UI/building_panel/resource_building_panel.gd
Scene/ui/resource_building_panel.tscn
~~~

完成内容：

-   材料全部交付后，ConstructionSite 自动发布 BUILD 任务；
-   运输阶段实际参与搬运的居民会被记录为施工候选人；
-   没有玩家取消任务时，施工仍优先由原运输居民承担，不从其他空闲居民中重新抢人；
-   建筑施工人数不超过 BuildingData.max_construction_workers；
-   居民领取 BUILD 任务后前往工地并加入 builders；
-   施工任务释放或取消时，工地移除对应施工人员并释放名额；
-   本阶段暂不计算施工速度，不生成正式建筑。
-   ConstructionSite 继承 BuildingBase，生成后拥有点击区域并动态注册到建筑面板；
-   建筑面板对工地显示材料已交付量/需求量，并提供增加居民、取消居民按钮；
-   增加或取消施工居民只调整施工名额，不改变材料运输人员连续性；
-   修正工地面板人数统计：运输任务中已领取/执行任务的居民也计入工地分配人数；
-   材料运输阶段同样可以取消居民或恢复居民名额，取消后不会自动补回；
-   修正取消/释放任务后的居民状态：居民会离开工地并返回据点附近待命；
-   修正任务执行失败后的重复领取循环：失败任务直接结束并释放居民，不再每帧重新领取同一任务；
-   修正搬运任务取消/释放时的资源回收：居民身上的材料会退回 Base，避免取消后材料滞留导致后续任务失败；
-   修正工地和待命点的到达判断：居民接近目标距离时即可触发交货、加入施工或结束返回移动，避免导航代理停在目标附近不触发状态切换；
-   资源不足时保留居民的搬运任务：居民前往工地等待，不再因暂时没有资源而失败退出，资源补充后继续搬运；
-   将工地分配居民与单个搬运任务分离：资源不足时居民仍可登记在工地等待，增加居民后可恢复到最大名额；
-   接入 ResourceStorage 资源变化唤醒：Base 增加木材后，等待中的搬运居民立即重新寻找资源，不需要重新任命；
-   增加阶段 8 测试快捷键：运行时按 `H` 给 Base 增加 10 木材，用于验证等待居民自动恢复搬运；

测试状态：

~~~ text
代码与场景引用静态检查通过。
已通过。
点击已放置工地可以查看材料已交付量/需求量和施工居民数量；
增加/取消居民可以调整施工名额；资源不足时居民在工地等待，按 H 增加木材后会自动恢复搬运。
~~~

## 10.10 建造系统阶段 9：线性多人施工

修改文件：

~~~ text
Script/construction_site.gd
UI/building_panel/resource_building_panel.gd
~~~

完成内容：

-   ConstructionSite 开始记录施工进度；
-   施工效率按实际施工人数线性计算：1 人 1 倍、2 人 2 倍、3 人 3 倍；
-   施工人数仍受建筑最大施工人数限制；
-   建筑面板显示施工进度；
-   本阶段不生成正式建筑，不处理完工替换。

测试状态：

~~~ text
代码与场景引用静态检查通过。
已通过。
已验证 1、2、3 名施工居民分别按 1 倍、2 倍、3 倍效率施工。
~~~

## 10.12 建造系统分阶段计划总体验收

计划文件：

~~~ text
GPT_Game_建造系统分阶段实施计划.md
~~~

完成状态：

~~~ text
阶段 1 至阶段 10：全部完成
~~~

阶段总结：

-   阶段 1：LevelConfig、初始资源和居民数量配置化，居民根据配置在 Base 附近动态生成；
-   阶段 2：BuildingData、伐木场数据和采石场数据建立，建筑参数从场景脚本中分离；
-   阶段 3：BuildGrid 完成世界坐标、网格坐标、旋转占地、占用和释放；
-   阶段 4：BuildingGhost 支持实际建筑模型预览、网格吸附、旋转、镜像和非法位置检查；
-   阶段 5：ConstructionSite 保存建筑成本、已交付材料、运输预约、施工状态和施工进度；
-   阶段 6：GameTask 和 TaskManager 支持运输、施工、领取、释放、完成、取消和失败；
-   阶段 7：居民自动从合法 ResourceStorage 搬运材料，支持预约、分批运输、资源回收和资源变化唤醒；
-   阶段 8：工地支持施工居民 UI、增加/取消居民、施工名额和运输居民连续分配；
-   阶段 9：施工效率按人数线性计算，1 人、2 人、3 人分别为 1 倍、2 倍、3 倍；
-   阶段 10：施工完成后生成正式建筑，保留位置、旋转和镜像，并完成正式建筑注册；资源型建筑会直接接管施工居民，自动成为伐木工或矿工；

最终建造流程：

~~~ text
点击下方伐木场/采石场按钮
→ 显示对应建筑 Ghost
→ 网格吸附并点击地面
→ 生成 ConstructionSite
→ 按建筑放置顺序分配施工队
→ 有材料时运输居民取货，其他已分配居民前往工地等待
→ 无材料时释放任务，居民返回公共待命区
→ 材料全部交付
→ 居民施工
→ 生成正式建筑
→ 伐木场施工居民转为伐木工，采石场施工居民转为矿工
~~~

已验证内容：

-   建筑 Ghost 不再在游戏启动时默认显示；
-   伐木场和采石场通过屏幕下方建造菜单选择；
-   多居民分批运输不会重复预约或超额运输；
-   资源不足时居民不会永久停在工地；
-   多个建筑按放置顺序分配施工队，不会互相抢同一批居民；
-   取消居民会释放任务和预约，并优先让居民继续领取其他任务；
-   建筑模型会自动计算外围站位，居民站位随机且分散；
-   正式建筑落地高度正确，支持替换为自定义建筑模型；
-   伐木场和采石场完工后会直接进入对应资源采集工作；
-   README 已持续记录各阶段修改和测试结果；
-   Godot 严格解析检查通过。

计划结论：

~~~ text
GPT_Game 建造系统分阶段实施计划已全部完成。
后续功能属于计划外扩展，建议从 Warehouse 和建造物流增强开始。
~~~
