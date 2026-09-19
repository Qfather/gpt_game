# ResourceBuildingBase 抽取后伐木工停止工作的修复任务

## 任务背景

当前 Godot 工程原本的 LumberCamp + Villager 伐木闭环已经正常运行：

``` text
LumberCamp 招募居民
→ Villager 成为 LUMBERJACK
→ 找 Tree
→ 移动
→ 采集 WOOD
→ 返回 LumberCamp
→ 存入 ResourceStorage
→ 从 LumberCamp 取货
→ 运回 Base
→ 继续工作
```

最近为了建立建筑继承体系，新增了：

``` text
BuildingBase
    ↓
ResourceBuildingBase
    ↓
LumberCamp / Quarry
```

把 LumberCamp 中的工人、岗位、工作范围、ResourceStorage 等通用逻辑抽到了
`ResourceBuildingBase`。

抽取之后出现新问题：

> 游戏可以运行，但 LumberCamp 的工人不再正常干活。

本任务的目标是：**找到抽基类造成的回归并修复，恢复原有伐木闭环，同时保留
ResourceBuildingBase 架构。**

------------------------------------------------------------------------

# 1. 必须先读取整个工程

请直接读取当前工程的实际文件，不要根据本文中的示例代码覆盖现有实现。

重点检查但不限于：

``` text
BuildingBase.gd
ResourceBuildingBase.gd
lumber_camp.gd
villager.gd
resource_storage.gd
resource_base.gd
tree.gd
base.gd
ResourceBuildingPanel
LumberCamp.tscn
Villager.tscn
Main / 当前测试场景
```

同时搜索：

``` text
add_worker
remove_worker
assign_worker_job
assign_job
quit_job
is_idle
workplace
job
State.FIND_RESOURCE
production_resource_type
ResourceStorage
deposit_resource
take_resource
has_resource
get_worker_job
LUMBERJACK
```

先理解当前代码，再修改。

------------------------------------------------------------------------

# 2. 当前目标继承结构必须保留

最终必须保持：

``` text
BuildingBase
    │
    └── ResourceBuildingBase
            │
            ├── LumberCamp
            └── Quarry（后续）
```

不要为了恢复伐木功能把 LumberCamp 改回：

``` gdscript
extends BuildingBase
```

`ResourceBuildingBase` 是正式架构的一部分。

------------------------------------------------------------------------

# 3. BuildingBase 职责

当前 `BuildingBase` 应保持轻量。

目前主要负责：

``` text
ClickArea
→ 鼠标左键
→ building_clicked
```

不要把：

``` text
workers
ResourceStorage
production_resource_type
职业
采集逻辑
```

重新塞入 BuildingBase。

未来建筑生命、护甲、建造状态等也不属于本次任务。

------------------------------------------------------------------------

# 4. ResourceBuildingBase 应负责的内容

资源生产建筑共有逻辑应该放在这里，包括：

``` text
production_resource_type

max_workers
workers

work_radius
idle_radius

ResourceStorage

get_worker_count()
get_max_worker_count()
has_free_slot()

add_worker()
remove_worker()

is_position_in_work_range()

deposit_resource()
take_resource()
has_resource()
get_resource_amount()
get_resource_capacity()

get_storage_amount()
get_storage_capacity()
```

如果当前工程实际接口名称略有不同，请基于现有实现处理，不要为了匹配本文强制重命名。

------------------------------------------------------------------------

# 5. 当前最重要的排查链路

重点确认以下调用链是否仍然完整：

``` text
LumberCamp
↓
add_worker(villager)
↓
ResourceBuildingBase.add_worker()
↓
给 worker 分配正确职业
↓
Villager.assign_job(...)
↓
job = LUMBERJACK
workplace = LumberCamp
↓
Villager 进入原本正常的工作状态
↓
State.FIND_RESOURCE
↓
寻找 WOOD ResourceBase
```

需要确认：

### A. `workers.append(worker)` 是否执行

成功招募后，LumberCamp 的 `workers` 必须包含该居民。

### B. `worker.assign_job(...)` 是否仍然执行

不能出现只：

``` gdscript
workers.append(worker)
```

但没有真正调用 Villager `assign_job()` 的情况。

### C. 职业是否正确

LumberCamp 必须最终分配：

``` text
LUMBERJACK
```

不能因为抽象层导致：

``` text
NONE
-1
MINER
```

或没有职业。

### D. workplace 是否正确

成功分配后：

``` text
villager.workplace == LumberCamp 实例
```

必须成立。

### E. Villager 状态是否进入原有工作流程

重点检查原本正常工作的 `Villager.assign_job()`。

如果原逻辑在 LUMBERJACK 分支中设置：

``` gdscript
state = State.FIND_RESOURCE
```

则应该继续使用。

**不要为了适配 ResourceBuildingBase 重写整个 Villager 状态机。**

------------------------------------------------------------------------

# 6. 关于 Job 枚举的重要限制

当前工程的 Job 枚举如果仍然定义在 `villager.gd`
内部，本次不要顺带建立新的 `JobType.gd`。

尤其不要假定存在：

``` gdscript
Villager.Job.LUMBERJACK
```

除非当前 `villager.gd` 实际声明了：

``` gdscript
class_name Villager
```

如果没有 `class_name Villager`，上述写法会报：

``` text
Identifier "Villager" not declared in the current scope
```

请根据当前工程实际结构解决职业分配。

如果当前正常旧逻辑使用：

``` gdscript
worker.Job.LUMBERJACK
```

可以继续沿用这种方式。

例如 ResourceBuildingBase 可以把"具体职业选择"交给子类，而不依赖
Villager 类名：

``` text
ResourceBuildingBase
→ 通用 add_worker()

LumberCamp
→ 告诉基类/worker：职业是 LUMBERJACK

Quarry（以后）
→ 职业是 MINER
```

具体实现方式请结合当前工程选择最简单、最稳定的方案。

本次禁止为了这个问题扩大为 Job 系统重构。

------------------------------------------------------------------------

# 7. LumberCamp 最终应该只保留自己的差异

抽取完成后，LumberCamp 不应该重新复制 ResourceBuildingBase 已有的：

``` text
workers
max_workers
work_radius
idle_radius
storage

add_worker()
remove_worker()
has_free_slot()

deposit_resource()
take_resource()
has_resource()

get_storage_amount()
get_storage_capacity()
```

LumberCamp 应主要保留：

``` text
它生产 WOOD
它使用 LUMBERJACK
当前仍需要的 LumberCamp 专属逻辑
临时测试逻辑（如工程仍在使用）
旧兼容接口（如果还有引用）
```

不要为了修 Bug 又把基类代码复制回来。

------------------------------------------------------------------------

# 8. `_ready()` 继承链必须检查

如果 LumberCamp 有自己的：

``` gdscript
func _ready():
```

必须确保基类初始化没有被跳过。

预期调用：

``` text
LumberCamp._ready()
↓
ResourceBuildingBase._ready()
↓
BuildingBase._ready()
```

因此通常需要：

``` gdscript
func _ready() -> void:
    super._ready()
    ...
```

请检查：

-   `BuildingBase` 的 ClickArea 是否仍然成功连接；
-   `ResourceBuildingBase` 的 ResourceStorage 是否成功获取；
-   LumberCamp 自己的启动/测试逻辑是否仍然执行。

不要重复连接同一个 `input_event`。

------------------------------------------------------------------------

# 9. ResourceStorage 节点路径必须验证

检查 `LumberCamp.tscn` 的实际节点结构。

如果基类使用：

``` gdscript
get_node_or_null("ResourceStorage")
```

则场景必须确实存在对应节点。

例如：

``` text
LumberCamp
├── ResourceStorage
└── ClickArea
```

如果实际路径不同，应以当前场景为准修复。

不能出现：

``` text
storage == null
```

导致居民虽然采集，但无法入库。

------------------------------------------------------------------------

# 10. 不要破坏已经完成的通用资源重构

当前正式资源流程应继续使用：

``` text
ResourceType.Type.WOOD
ResourceType.Type.STONE
ResourceType.Type.FOOD

carried_resource_type
carried_amount

deposit_resource()
take_resource()
has_resource()
```

不要退回：

``` text
carried_wood
stored_wood
```

作为正式架构。

旧：

``` text
deposit_wood()
take_wood()
has_stored_wood()
```

如果还有调用，可以暂时作为兼容层保留。

------------------------------------------------------------------------

# 11. 不要修改已经正常工作的 Villager 核心状态机

这是本次任务的重要约束。

抽 `ResourceBuildingBase` 之前：

``` text
Villager
→ 找 Tree
→ 走过去
→ gather()
→ 回 LumberCamp
→ 入库
→ 运输
→ Base
```

已经正常。

因此首先假设：

> 回归来自建筑基类抽取，而不是 Villager 原有状态机突然需要重新设计。

允许修改 Villager 的情况：

-   基类重构后某个接口名称确实变化；
-   当前调用明显已经失效；
-   只需要极小兼容调整。

禁止：

-   重写整个 State enum；
-   重写寻路；
-   重写资源搜索；
-   重写运输系统；
-   顺带重构 Job；
-   顺带重构 Trait。

------------------------------------------------------------------------

# 12. Trait / UnitBase 不要动

现有：

``` text
TraitData
→ TraitLevelData
→ StatModifier
→ UnitTrait
→ UnitBase.get_stat()
```

必须保持。

居民仍应通过现有最终属性接口获取：

``` gdscript
get_move_speed()
get_work_speed()
get_gather_speed()
```

不要写死速度。

------------------------------------------------------------------------

# 13. Quarry 暂停

虽然工程里可能已经存在：

``` text
quarry.gd
quarry.tscn
stone.gd
stone.tscn
```

本次不要继续实现 Quarry。

先保证：

``` text
BuildingBase
↓
ResourceBuildingBase
↓
LumberCamp
```

完全稳定。

只有伐木闭环恢复以后，下一阶段才进入：

``` text
ResourceBuildingBase
├── LumberCamp → WOOD + LUMBERJACK
└── Quarry     → STONE + MINER
```

------------------------------------------------------------------------

# 14. 运行时增加必要诊断信息

如果原因不明显，可以临时打印以下信息：

``` text
LumberCamp add_worker 收到谁
workers.size()
worker 当前 job
worker workplace
worker state
production_resource_type
storage 是否为 null
```

例如最终至少应能确认：

``` text
居民：Villager
职业：LUMBERJACK
工作地点：LumberCamp
状态：FIND_RESOURCE
目标资源：WOOD
```

定位后可以删除过度诊断日志，只保留有价值的日志。

------------------------------------------------------------------------

# 15. 必须实际运行验收

不要只看脚本无红线。

请实际运行当前测试场景，完整验证：

1.  Godot 项目启动无新增错误。
2.  LumberCamp 正常初始化。
3.  BuildingBase 点击仍然有效。
4.  点击 LumberCamp 能打开原来的建筑 UI。
5.  能找到 villagers group。
6.  空闲居民可以被 LumberCamp 招募。
7.  `workers` 数量正确。
8.  居民成功变成 LUMBERJACK。
9.  `workplace` 正确指向 LumberCamp。
10. 居民开始寻找 Tree。
11. 不会错误寻找 Stone。
12. 能移动到 Tree。
13. 能正常 gather WOOD。
14. `carried_resource_type == WOOD`。
15. 能返回 LumberCamp。
16. 能存入 LumberCamp 的 ResourceStorage。
17. LumberCamp UI 库存正确刷新。
18. 能从 LumberCamp 取 WOOD。
19. 能运到 Base。
20. Base ResourceStorage 的 WOOD 增加。
21. HUD 木材显示正常。
22. 居民能继续下一轮工作。
23. 解雇功能仍然正常。
24. Trait 对移动/工作等已有修正没有失效。
25. 没有新的 Warning-as-error。

------------------------------------------------------------------------

# 16. 修复后的架构目标

最终应该是：

``` text
BuildingBase
│
│  点击建筑
│
└── ResourceBuildingBase
    │
    ├─ 工人管理
    ├─ 工作范围
    ├─ production_resource_type
    ├─ ResourceStorage
    ├─ 通用库存接口
    │
    └── LumberCamp
        ├─ WOOD
        └─ LUMBERJACK
```

未来才扩展：

``` text
ResourceBuildingBase
├── LumberCamp
│   ├─ WOOD
│   └─ LUMBERJACK
│
└── Quarry
    ├─ STONE
    └─ MINER
```

其他未来建筑：

``` text
BuildingBase
├── ResourceBuildingBase
├── TrainingBuildingBase（以后）
├── Warehouse（以后）
├── House（以后）
└── ...
```

Warehouse 虽然有 ResourceStorage，但不属于
ResourceBuildingBase，因为它不是资源生产建筑。

------------------------------------------------------------------------

# 17. 本次禁止顺带实现

不要新增或扩展：

-   Quarry 正式生产逻辑
-   Stone 新玩法
-   JobType 重构
-   TrainingBuildingBase
-   Warehouse
-   建筑 HP
-   建筑 ArmorType
-   建造系统
-   Food
-   工作/吃饭/休息
-   幸福感
-   人口
-   程序化地图
-   战争迷雾
-   Trait 体型缩放

这些都不是本次回归修复任务。

------------------------------------------------------------------------

# 18. 完成后停止并汇报

修复并实际运行成功后停止，不要继续开发下一功能。

请汇报：

``` text
1. 根本原因是什么
2. 修改了哪些文件
3. ResourceBuildingBase 最终负责什么
4. LumberCamp 最终还保留什么
5. 是否修改 Villager；如果修改，为什么
6. 是否保留旧木材兼容接口
7. 完整伐木闭环实际运行结果
8. 是否还有建议以后清理但本次没有动的代码
```

最终验收标准只有一句：

> **在保留 ResourceBuildingBase 架构的前提下，让抽取前已经正常工作的
> LumberCamp + Villager 完整伐木循环恢复正常。**
