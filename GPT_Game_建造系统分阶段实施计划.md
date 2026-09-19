# GPT Game：建造系统分阶段实施计划

## 0. 执行规则（非常重要）

本任务必须 **严格分阶段执行**。

桌面端每次只完成 **一个阶段**，完成后：

1.  检查 Parser Error / Warning-as-error。
2.  运行当前主场景。
3.  只验证本阶段要求的测试项目。
4.  汇报：
    -   修改了哪些文件；
    -   新建了哪些文件；
    -   本阶段实现了什么；
    -   测试结果；
    -   是否发现旧系统兼容问题；
    -   下一阶段准备做什么。
5.  **完成后立即停止，不得自动进入下一阶段。**
6.  等用户实际测试并明确回复"正常 / 继续 /
    下一步"后，才允许进入下一阶段。

如果本阶段测试失败，只修复当前阶段，不提前开发后面的内容。

------------------------------------------------------------------------

# 1. 当前工程已经确认的基础

当前已经跑通：

``` text
BuildingBase
└─ ResourceBuildingBase
   ├─ LumberCamp
   └─ Quarry
```

资源：

``` text
WOOD
STONE
```

居民：

``` text
LUMBERJACK → LumberCamp → WOOD
MINER      → Quarry     → STONE
```

资源采集职业已经通用化：

``` text
Villager
→ workplace is ResourceBuildingBase
→ workplace.production_resource_type
→ FIND_RESOURCE
```

不要重新引入：

``` text
LUMBERJACK -> WOOD
MINER -> STONE
```

这种硬编码映射。

当前还有：

``` text
ResourceStorage
ResourceManager
HUD
ResourceBuildingPanel
```

HUD 的定义：

``` text
全局资源总量
=
所有己方 ResourceStorage
+
所有己方居民 carried resource
```

运输过程中资源总量不得变化。

------------------------------------------------------------------------

# 2. 建造系统最终目标

最终玩家流程：

``` text
选择建筑蓝图
↓
鼠标选择地图位置
↓
吸附网格
↓
R：90°旋转
↓
M：镜像
↓
检查是否合法
↓
左键确认
↓
生成 ConstructionSite
↓
空闲居民自动领取搬运任务
↓
从 Base / Warehouse / 其他合法 ResourceStorage 搬材料
↓
居民携带途中资源仍计入 HUD
↓
材料送入工地时正式消费
↓
工地材料全部到齐
↓
空闲居民自动参与施工
↓
多人施工，但边际效益递减
↓
施工完成
↓
生成正式建筑
```

第一版禁止把建筑成本直接瞬间从全局资源中扣掉。

------------------------------------------------------------------------

# 3. 长期架构原则

## Job

长期职业：

``` text
NONE
LUMBERJACK
MINER
...
```

## Task

临时公共任务：

``` text
DELIVER_CONSTRUCTION_RESOURCE
BUILD
```

以后可扩展：

``` text
TRANSFER_RESOURCE
REPAIR
DEMOLISH
CLEAR_OBSTACLE
...
```

## Need（以后）

``` text
EAT
REST
...
```

三者不要混成一个系统。

当前已经工作的 Lumberjack / Miner 状态机不要为了 Task 系统重写。

------------------------------------------------------------------------

# 阶段 1：LevelConfig ------ 关卡初始数据

## 目标

建立通用关卡配置数据，不把第一关初始资源写死在 Base 或 Main 脚本。

建议：

``` gdscript
class_name LevelConfig
extends Resource
```

第一版至少支持：

``` text
initial_wood
initial_stone
initial_villagers
```

如果当前 ResourceType / ResourceStorage
的数据结构适合使用通用资源字典，可以采用现有架构更合适的方式，不要为了示例强行改变现有类型。

创建第一关配置，例如：

``` text
Level_01.tres
```

Main 或 LevelManager 引用该配置。

开局：

``` text
LevelConfig
↓
Base.ResourceStorage
↓
填入初始 WOOD / STONE
```

居民数量如果当前场景已经手工摆放，第一阶段可以先只保存
`initial_villagers`
配置但不强制动态生成，避免扩大修改范围；需在汇报中说明。

## 本阶段禁止

不要做：

``` text
BuildingData
BuildGrid
Ghost
ConstructionSite
TaskManager
施工
```

## 用户测试

用户需要确认：

-   游戏正常启动；
-   Base 获得 Level_01 配置的初始资源；
-   HUD 正确显示初始全局 WOOD / STONE；
-   修改 Level_01.tres 数值后重新运行，初始资源随配置变化；
-   LumberCamp / Quarry / Villager 原有流程仍正常。

**通过后停止，等待用户确认。**

------------------------------------------------------------------------

# 阶段 2：BuildingData ------ 建筑蓝图数据

## 目标

建筑的建造信息不能散落写死在 LumberCamp / Quarry 脚本中。

建立：

``` gdscript
class_name BuildingData
extends Resource
```

第一版至少支持：

``` text
id / display_name
building_scene
grid_size
construction_cost
construction_time
max_construction_workers
allow_rotation
allow_mirror
```

建议第一批：

``` text
LumberCampData.tres
QuarryData.tres
```

示例概念：

``` text
LumberCamp
占地：3 × 2
WOOD：20
STONE：0
施工时间：20
最大施工人数：3
允许旋转：true
允许镜像：true
```

具体数值以方便测试为主，后期再平衡。

## 注意

`BuildingData` 是"蓝图数据"。

`LumberCamp.gd / Quarry.gd` 是"建筑运行逻辑"。

两者职责必须分开。

## 本阶段禁止

不要开始地图放置。

## 用户测试

至少确认：

-   两个 `.tres` 可以在 Inspector 正常编辑；
-   Scene 引用正确；
-   成本、占地、施工时间能读取；
-   原 LumberCamp / Quarry 场景仍正常运行。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 3：BuildGrid ------ 三维网格建造基础

## 目标

建立世界坐标与建造格子的转换系统。

第一版需要：

``` text
world_to_grid()
grid_to_world()
is_area_free()
occupy_area()
release_area()
```

建筑按二维地面网格占地，Y 轴为高度。

需要支持：

``` text
3×2
旋转90° → 2×3
```

当前地图可先使用统一平地测试。

## 第一版合法性

至少判断：

``` text
格子是否已经被建筑/工地占用
是否处于允许建造范围
```

复杂地形坡度、悬崖、海水以后做。

## 用户测试

提供临时调试方式验证：

-   鼠标/指定世界位置能正确转换格子；
-   3×2 占地正确；
-   旋转后 2×3 占地正确；
-   已占用区域不能再次通过检测；
-   释放后重新可用。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 4：BuildingGhost ------ 蓝图预览、旋转、镜像

## 目标

玩家可以选择一个 `BuildingData`，看到半透明预览。

第一版操作：

``` text
鼠标移动 → Ghost 跟随
网格吸附
R → 每次旋转90°
M → 镜像
左键 → 尝试确认
右键 / Esc → 取消
```

必须记录逻辑状态：

``` text
rotation_step = 0 / 1 / 2 / 3
mirrored = false / true
```

不要只依赖当前 Transform 推算状态。

合法：

``` text
绿色/明显合法视觉反馈
```

非法：

``` text
红色/明显非法视觉反馈
```

如果当前材质架构不适合直接变色，可以使用简单可辨识的替代方案，但不要为了
Ghost 重构正式建筑材质系统。

## 镜像

第一版只做一个水平镜像即可。

镜像必须和最终建筑实例保持一致。

## 本阶段确认放置时

可以暂时只输出：

``` text
BuildingData
grid position
rotation_step
mirrored
```

或者生成一个临时占位节点。

**不要开始真实施工物流。**

## 用户测试

-   Ghost 正确吸附；
-   R 四次回到原方向；
-   3×2 / 2×3 占地随旋转变化；
-   M 镜像正常；
-   非法位置不能确认；
-   取消正常；
-   不影响镜头、HUD、现有建筑点击。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 5：ConstructionSite ------ 工地数据与状态

## 目标

确认 Ghost 后不直接生成正式建筑，而生成 ConstructionSite。

状态第一版：

``` text
WAITING_RESOURCES
READY_TO_BUILD
BUILDING
COMPLETED
CANCELLED
```

ConstructionSite 保存：

``` text
BuildingData
rotation_step
mirrored
required_resources
delivered_resources
reserved/in_transit resources
construction_progress
builders
```

工地需要知道：

``` text
required
delivered
reserved/in_transit
still_needed
```

核心公式：

``` text
still_needed
=
required
- delivered
- reserved/in_transit
```

避免多个居民重复搬运超额资源。

## 资源定义

材料：

``` text
Storage → Villager
```

仍属于玩家资源，HUD 不变。

材料：

``` text
Villager → ConstructionSite
```

正式消费。

因此 ConstructionSite 已投入材料 **不要加入 ResourceManager
的全局库存统计**。

## 本阶段先不让居民搬

可以通过调试按钮/方法手工给工地投入材料，验证状态转换。

## 用户测试

-   放下蓝图生成 ConstructionSite；
-   正式建筑尚未出现；
-   工地显示/打印正确资源需求；
-   手工投入部分资源仍 WAITING_RESOURCES；
-   全部材料齐后进入 READY_TO_BUILD；
-   旋转/镜像信息被工地保留。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 6：通用 GameTask + TaskManager 第一版

## 目标

建立可复用的公共任务系统。

第一版只实现：

``` text
DELIVER_CONSTRUCTION_RESOURCE
BUILD
```

### GameTask

至少：

``` text
id
type
state
priority
requester
target
assigned_worker
```

状态：

``` text
AVAILABLE
CLAIMED
IN_PROGRESS
COMPLETED
CANCELLED
```

### TaskManager

职责只包括：

``` text
create/register task
find task
claim task
release task
complete task
cancel task
```

TaskManager **不负责**：

``` text
控制居民移动
计算施工速度
识别 Trait
直接修改资源
```

### Villager 资格接口

预留：

``` gdscript
can_take_task(task)
```

第一版规则：

``` text
Job.NONE
current_task == null
→ 可以领取公共任务
```

伐木工/矿工继续做长期职业，不参与普通施工公共任务。

以后 Trait、饥饿、疲劳统一从资格层扩展。

## Trait 兼容原则

TaskManager 不允许写：

``` text
if villager has "讨厌石头"
```

未来必须：

``` text
villager.can_take_task(task)
```

职业招募未来同理：

``` text
villager.can_take_job(...)
```

## 用户测试

用调试任务验证：

-   创建 AVAILABLE Task；
-   空闲居民可以领取；
-   有正式职业居民不领取；
-   一个 Task 不会被两个居民同时 claim；
-   release 后重新 AVAILABLE；
-   complete 后不再被领取；
-   requester 删除时可取消相关任务或至少安全失效。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 7：施工材料自动搬运

## 目标

ConstructionSite 根据缺少资源发布：

``` text
DELIVER_CONSTRUCTION_RESOURCE
```

空闲居民自动领取。

流程：

``` text
领取任务
↓
寻找可提供资源的 ResourceStorage
↓
预约资源
↓
走到 Source
↓
取货
↓
HUD总量不变
↓
走到 ConstructionSite
↓
投入材料
↓
HUD总量减少
↓
完成 Task
```

## 非常重要

不要写死：

``` text
去 Base 拿材料
```

必须从合法 `ResourceStorage` 中寻找来源。

这样以后：

``` text
Warehouse
第二个 Base（如果未来有）
其他储存建筑
```

可以自然成为来源。

第一版来源选择可以简单：

``` text
最近且有足够/部分资源的 Storage
```

不要现在实现复杂物流最优算法。

## 预约

必须避免：

``` text
工地缺10
居民A预约10
居民B又预约10
```

需要最小预约机制。

## 用户测试

-   空闲居民自动领取材料运输；
-   伐木工/矿工不被抢去；
-   资源从 Storage 到居民时 HUD 不变；
-   到 ConstructionSite 时 HUD 扣除；
-   不超额运送；
-   多个空闲居民不会重复预约同一份资源；
-   材料齐后停止发布搬运任务。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 8：施工任务

## 目标

材料齐全后：

``` text
ConstructionSite
WAITING_RESOURCES
↓
READY_TO_BUILD
↓
发布 BUILD 名额
```

空闲居民领取 BUILD Task 后：

``` text
走到工地
↓
加入 builders
↓
施工
```

ConstructionSite 定义：

``` text
max_construction_workers
```

TaskManager 只提供施工任务/名额，不计算施工速度。

## 用户测试

-   材料不齐时无人施工；
-   材料齐后自动产生施工需求；
-   空闲居民自动来施工；
-   超过最大人数后不再分配；
-   离开/任务取消后施工名额正确释放。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 9：多人施工边际效益递减

## 目标

多人可以加速施工，但不能线性叠加。

禁止：

``` text
1人 = 100%
2人 = 200%
3人 = 300%
```

第一版可以使用简单可配置规则，例如：

``` text
1人 = 1.00x
2人 = 1.60x
3人 = 1.95x
4人 = 2.15x
5人 = 2.25x
```

具体数值以后调整。

施工效率计算属于：

``` text
ConstructionSite
```

不属于 TaskManager，也不要散落在 Villager 中。

未来 Trait 可以修正个人施工贡献，但本阶段不要实现 Trait 数值效果。

## 用户测试

分别测试：

``` text
1人
2人
3人
```

确认：

-   人多确实更快；
-   增益逐渐降低；
-   不超过 max_construction_workers；
-   工人数量变化时效率正确更新。

**通过后停止。**

------------------------------------------------------------------------

# 阶段 10：施工完成并替换正式建筑

## 目标

进度达到 100%：

``` text
ConstructionSite
↓
COMPLETED
↓
生成 BuildingData.building_scene
↓
应用 grid position
↓
应用 rotation_step
↓
应用 mirrored
↓
正式占用 BuildGrid
↓
清理工地任务
↓
释放 builders
↓
删除 ConstructionSite
```

正式生成：

``` text
LumberCamp
或
Quarry
```

必须继续兼容现有：

``` text
BuildingBase
ResourceBuildingBase
ResourceBuildingPanel
招募
解雇
采集
ResourceStorage
ResourceManager
HUD
```

## 用户测试

完整测试：

``` text
选择 LumberCamp 蓝图
→ 放置
→ 居民搬 WOOD
→ 材料消费
→ 居民施工
→ 完工
→ LumberCamp 出现
→ 点击建筑
→ 招募伐木工
→ 正常采树
```

然后：

``` text
Quarry
→ 同样完整跑通
→ 招募矿工
→ 正常采石
```

**通过后停止。**

------------------------------------------------------------------------

# 后续阶段（本计划暂不实施）

以下内容记录下来，但不要在上述 10 个阶段中提前实现：

## 建造物流增强

``` text
Warehouse
多仓库智能供货
资源拆单
物流优先级
专职搬运工
道路影响运输
取消施工后材料回运
```

## 居民需求

``` text
工作时长
疲劳
回据点吃饭
休息
食物消费
饥饿
死亡
```

## 人口/幸福感

``` text
House
居住地
人口上限
幸福感
工作效率
```

## Trait

``` text
讨厌石头 → can_take_job(MINER) = false
讨厌砍树 → can_take_job(LUMBERJACK) = false
强壮 → 搬运能力
勤劳 → 工作效率
高大/矮小 → 模型Scale + CollisionShape同步
```

Trait 不应直接耦合 TaskManager。

## 地图

``` text
程序化小岛
Seed
资源分布
战争迷雾
不可建造地形
```

## 建筑深度

``` text
HP
护甲类型
维修
升级
拆除
入口方向
邻接加成
美观度
```

------------------------------------------------------------------------

# 最终要求

桌面端必须把这份文件当作"阶段计划"，不是"一次性任务清单"。

**第一次读取本文件时，只允许执行阶段 1。**

阶段 1 完成后必须停止，并等待用户测试。

用户确认后再执行阶段 2。

以此类推。

不要因为后面的设计已经明确，就提前创建后续系统或大规模重构当前工程。
