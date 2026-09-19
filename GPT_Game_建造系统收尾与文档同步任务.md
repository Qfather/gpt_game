# GPT Game：建造系统收尾 + 文档同步修改任务

## 0. 执行目标

当前 `STONE + Quarry`
与第一轮建造系统已经基本完成。本次不是开发新玩法，而是进行一次**建造章节收尾与工程文档同步**。

请先读取当前工程实际代码、`README.md`、`ROADMAP.md`，以当前实现为准，不要根据旧计划覆盖已经完成的功能。

本次只处理以下四类工作：

1.  TaskManager 调度事件驱动化；
2.  开发调试入口统一为 DEV_MODE；
3.  BuildGrid
    为未来程序化地图预留"可建造区域提供者/规则接口"，但不开发程序化地图；
4.  更新 `README.md` 与 `ROADMAP.md`，使文档与当前真实进度一致。

完成后停止，不进入 FOOD、UnitPanel、Warehouse、程序化地图等新章节。

------------------------------------------------------------------------

# 1. 修改项一：TaskManager 调度事件驱动化

## 当前问题

当前实现如果仍类似：

``` gdscript
func _process(_delta: float) -> void:
    _dispatch_available_tasks()

    for site in construction_sites:
        site.request_delivery_tasks()
```

意味着每帧持续扫描：

``` text
Tasks
× Villagers
× ConstructionSites
```

当前规模小可以运行，但未来居民、工地、仓库任务、维修任务增加后会产生大量无意义扫描。

## 目标

改成与 ResourceManager 类似的"事件触发 + 同帧合并"机制。

建议核心结构：

``` text
任务创建
居民重新空闲
工地状态变化
资源库存变化
任务释放/取消/完成
        ↓
TaskManager.request_dispatch()
        ↓
同一帧只排队一次
        ↓
call_deferred(...)
        ↓
统一调度
```

建议字段：

``` gdscript
var dispatch_queued: bool = false
```

概念实现：

``` gdscript
func request_dispatch() -> void:
    if dispatch_queued:
        return

    dispatch_queued = true
    call_deferred("_run_dispatch")


func _run_dispatch() -> void:
    dispatch_queued = false

    # 根据当前工程实际接口执行：
    # 1. 让需要材料的工地补充/发布运输任务
    # 2. 分配 AVAILABLE Tasks
```

## 必须触发重新调度的情况

至少检查当前工程并覆盖：

``` text
新 Task 创建
Task release
Task complete
Task cancel
Villager 完成任务重新空闲
Villager 放弃任务重新空闲
ConstructionSite 新建
ConstructionSite 状态改变
ConstructionSite 材料送达
ConstructionSite 完工/取消
ResourceStorage 资源发生变化
```

尤其要保证：

``` text
工地缺料
↓
当前库存不足
↓
居民被释放，不傻站
↓
后来 Base/LumberCamp/Quarry 库存增加
↓
ResourceStorage.resource_changed
↓
TaskManager.request_dispatch()
↓
工地重新产生可执行运输
```

不得因为取消 `_process()` 而破坏"后来补充资源后自动恢复施工物流"。

## 重要原则

不要用 Timer 每隔 X 秒扫描来冒充事件驱动。

允许 `call_deferred()` 合并同一帧多次变化。

如果当前某个特殊状态确实只能通过轮询才能正确工作，请先确认原因；优先补充对应
Signal，而不是保留全局每帧扫描。

## 测试

必须测试：

1.  单工地材料充足：正常搬运、施工、完工。
2.  工地材料不足：居民释放。
3.  后来增加资源：工地自动恢复物流。
4.  两个工地同时存在：任务仍能正常调度。
5.  Task release 后其他居民可以重新领取。
6.  Task complete/cancel 后不会留下幽灵任务。
7.  TaskManager 不再依赖每帧 `_process()` 做常规任务调度。

------------------------------------------------------------------------

# 2. 修改项二：统一 DEV_MODE / 调试入口

## 当前情况

工程目前存在多个开发调试入口，例如可能包括：

``` text
TaskManager.enable_debug_input
BuildGrid.run_debug_test
Main 中 KEY_H 增加 WOOD
ConstructionSite 调试投料
其他测试快捷键/测试打印
```

开发阶段这些功能仍然有用，因此**不要全部删除**。

## 目标

建立一个统一的开发模式开关。

可以根据当前工程结构选择：

``` gdscript
const DEV_MODE: bool = true
```

或一个简单的全局开发配置。

不要为了一个开关创建过度复杂的 Settings 系统。

所有仅用于开发测试的功能必须明确受 DEV_MODE 控制，例如：

``` gdscript
if not DEV_MODE:
    return
```

目标：

``` text
DEV_MODE = true
→ H 加资源
→ 调试投料
→ BuildGrid 测试
→ Task 调试输入
→ 必要调试日志

DEV_MODE = false
→ 玩家正常运行时无法触发这些开发作弊/测试功能
```

## 注意

普通错误日志、必要警告不属于 DEV_MODE，不要把真正的错误提示一起关闭。

只控制：

``` text
作弊快捷键
手工投料
测试任务
网格自检入口
高频调试打印
```

## 临时文件

检查工程 ZIP/目录中类似：

``` text
*.tmp
main.tscn....tmp
villager.tscn....tmp
```

如果确认是编辑器/工具产生且不被工程引用，可以清理。

不要误删 Godot
正式资源或用户正在使用的备份文件；不确定则只在汇报中列出。

------------------------------------------------------------------------

# 3. 修改项三：BuildGrid 为程序化地图预留接口

## 当前状态

当前 BuildGrid 使用固定测试范围，例如：

``` gdscript
grid_min = Vector2i(-15, -15)
grid_max = Vector2i(14, 14)
```

目前这对测试平地完全正确。

未来计划：

``` text
程序化小岛
↓
海水
悬崖
普通地面
资源节点
战争迷雾
↓
决定哪些格子可以建造
```

## 本次目标

**不要开发程序化地图。**

只需要检查 BuildGrid 架构，避免"可建造 =
只要在固定矩形范围内且没被占用"被写死到无法扩展。

建议将合法性概念分开：

``` text
是否在当前网格范围
+
是否被建筑/工地占用
+
地形规则是否允许建造
```

可以预留类似：

``` gdscript
func is_cell_buildable(cell: Vector2i) -> bool:
```

以及：

``` gdscript
func is_area_buildable(
    origin: Vector2i,
    size: Vector2i
) -> bool:
```

第一版地形规则仍然可以简单返回：

``` text
在测试范围内 = true
```

但调用方（Ghost/ConstructionSite）应通过 BuildGrid
的统一合法性接口判断，而不是自己直接依赖 `grid_min/grid_max`。

未来程序化地图只需要替换/注入：

``` text
TerrainBuildabilityProvider
或
BuildGrid 的 terrain rule
```

即可表达：

``` text
LAND     → 可建
WATER    → 不可建
CLIFF    → 不可建
特殊地形 → 按规则
```

## 不要现在做

禁止本次顺带开发：

``` text
噪声地图
岛屿生成
Seed
海水
悬崖
战争迷雾
资源随机分布
NavMesh 动态生成
```

本次只是**留下干净扩展点**。

## 测试

现有平地建造行为必须完全不变：

``` text
Ghost 吸附正常
合法位置正常
占用位置非法
旋转占地正常
镜像正常
施工完成后正式建筑占格正常
```

------------------------------------------------------------------------

# 4. README.md 更新要求

README 必须描述"当前工程真实状态"，不要继续显示旧的：

``` text
当前下一章节：STONE + Quarry
```

因为 `STONE + Quarry` 已完成，建造系统第一轮也已完成。

## 建议更新当前完成状态

至少记录：

``` text
WOOD + Tree + LumberCamp                    ✅
STONE + Stone + Quarry                      ✅
ResourceType 通用资源类型                   ✅
ResourceStorage 通用库存                    ✅
ResourceManager 全局资源统计                ✅
HUD WOOD / STONE 全局总量                   ✅

BuildingBase                                ✅
ResourceBuildingBase                        ✅
ResourceBuildingPanel                       ✅

LevelConfig                                 ✅
BuildingData                                ✅
BuildGrid                                   ✅
BuildingGhost                               ✅
网格吸附                                    ✅
90°旋转                                     ✅
镜像                                        ✅
ConstructionSite                            ✅

GameTask / TaskManager                      ✅
空闲居民公共任务                            ✅
施工材料自动运输                            ✅
资源不足时释放居民                          ✅
资源补充后恢复施工物流                      ✅
多工地任务调度                              ✅
多人施工                                    ✅
max_construction_workers 最大施工人数限制   ✅
施工完成生成正式建筑                        ✅
完工后居民衔接正式生产（如当前实现确实如此）✅
```

如果本次完成 TaskManager 事件驱动化，再加入：

``` text
TaskManager 事件驱动调度                    ✅
```

## 明确当前施工速度规则

之前计划中的"边际效益递减"已由用户主动取消。

当前正式规则：

``` text
施工效率按实际施工人数线性增加
+
BuildingData.max_construction_workers
限制最大同时施工人数
```

README 不要再写：

``` text
多人施工边际效益递减
```

示例：

``` text
1人 = 1×
2人 = 2×
3人 = 3×

如果 max_construction_workers = 3
则最多3人同时贡献施工效率。
```

## README 增加当前核心循环

建议加入：

``` text
初始 Base + Villagers
        ↓
LevelConfig 提供初始资源
        ↓
选择建筑蓝图
        ↓
网格放置 / 90°旋转 / 镜像
        ↓
ConstructionSite
        ↓
空闲居民自动搬运施工材料
        ↓
材料送入工地并正式消费
        ↓
材料齐全
        ↓
多人施工（受最大施工人数限制）
        ↓
正式建筑生成
        ↓
LumberCamp / Quarry 开始生产
        ↓
WOOD / STONE 增加
        ↓
继续建设
```

并明确：

``` text
Storage → Villager：
资源仍属于玩家，HUD 总量不变

Villager → ConstructionSite：
材料正式投入工程，从可支配全局资源中扣除
```

## 文档结构建议

README 主要保留：

``` text
项目当前状态
核心玩法循环
当前架构
主要系统说明
运行/开发说明
当前下一章节
```

详细历史修改记录如果当前已经很长，本次可以：

-   保留现状，不强制拆分；
-   或创建 `CHANGELOG.md` 并移动纯历史修复记录。

如果移动 CHANGELOG，必须确保 README 中保留简洁入口/说明。

不要因为整理文档删除有价值的技术记录。

------------------------------------------------------------------------

# 5. ROADMAP.md 更新要求

ROADMAP 不能继续写：

``` text
[当前] STONE + Quarry
↓
建造系统最小版
```

这些已经完成。

## 已完成里程碑

更新为：

``` text
第一阶段：基础居民 + WOOD              ✅
第二阶段：STONE + Quarry              ✅
第三阶段：通用资源建筑架构             ✅
第四阶段：全局资源统计                 ✅
第五阶段：建造系统第一轮               ✅
第六阶段：公共 Task / 施工物流         ✅
```

名称可以结合现有 ROADMAP 风格调整，但状态必须与真实代码一致。

## 当前建议主线

下一阶段建议写为：

``` text
[当前/下一步]
Villager UnitPanel 最小版
↓
FOOD
↓
工作时长 / 疲劳基础
↓
居民回据点吃饭
↓
休息
↓
恢复原工作
```

### UnitPanel 第一版目标（仅写进 ROADMAP，本次不要开发）

未来点击居民显示：

``` text
名称/编号
Job
State
CurrentTask
Workplace

HP
移动速度
工作/采集相关速度

携带资源
Trait
```

它既是玩家信息面板，也是后续 FOOD / 疲劳 / Trait 开发的可视化调试工具。

## 后续主线继续记录

``` text
FOOD
↓
工作 → 吃饭 → 休息循环
↓
House / 人口上限
↓
幸福感
↓
训练建筑
↓
剑士
↓
敌人 / 战斗
```

## 重要支线继续保留

### Trait

``` text
讨厌石头
→ 未来 can_take_job(MINER) = false

讨厌砍树
→ can_take_job(LUMBERJACK) = false

强壮
→ 搬运能力

勤劳
→ 工作效率

高大 / 矮小
→ 模型 Scale + CollisionShape 同步
```

TaskManager 不直接识别 Trait。

统一通过未来接口：

``` text
Villager.can_take_task(task)
Villager.can_take_job(job, workplace)
```

### Warehouse / 物流

保留：

``` text
附近 ResourceStorage 优先供给
Warehouse 本地库存
资源建筑 → Warehouse → Base
建造材料可以从任意合法 ResourceStorage 获取
```

当前施工运输代码不得退化成"只从 Base 取材料"。

### 程序化地图

继续记录：

``` text
程序化小岛
Seed
每局不同
资源分布
战争迷雾
海水边界
悬崖/不可建造地形
BuildGrid 与程序化地形规则结合
```

### 建筑后续

继续保留：

``` text
HP
护甲类型
维修
升级
拆除
道路
入口方向
邻接/美观度
```

------------------------------------------------------------------------

# 6. 本次禁止开发的新功能

本次只是收尾 + 架构优化 + 文档同步。

不要开始实现：

``` text
UnitPanel
FOOD
疲劳
吃饭
休息
House
Warehouse
人口
幸福感
战斗
程序化地图
战争迷雾
Trait 新效果
建筑 HP / 护甲
```

------------------------------------------------------------------------

# 7. 最终回归测试

修改完成后必须完整跑一次：

## 资源

``` text
WOOD / STONE 正常
HUD 正常
Storage → Villager 时总量不变
Villager → ConstructionSite 时总量减少
```

## 建造

``` text
选择 LumberCamp
→ Ghost
→ 网格吸附
→ R旋转
→ M镜像
→ 放置
→ ConstructionSite
→ 自动搬材料
→ 自动施工
→ 正式 LumberCamp
→ 正常招募/生产
```

Quarry 同样测试。

## 多工地

``` text
同时放两个工地
```

确认：

``` text
无重复预约
无超额运输
居民不会同时拥有两个任务
缺料会释放
补料会恢复
一个工地完成后居民可以继续参与其他任务
```

## DEV_MODE

``` text
true  → 调试入口可用
false → 调试作弊入口不可用
```

## TaskManager

确认正常游戏过程中不再依赖每帧全量扫描进行常规任务调度。

------------------------------------------------------------------------

# 8. 完成后汇报格式

完成后停止，并汇报：

``` text
1. 修改了哪些文件
2. TaskManager 原来的每帧扫描改成了什么
3. 哪些事件会触发 request_dispatch()
4. 缺料后补资源是否能自动恢复
5. DEV_MODE 控制了哪些入口
6. BuildGrid 为程序化地图预留了什么接口
7. README 更新了哪些“已完成”状态
8. ROADMAP 当前主线改成了什么
9. 是否创建/更新 CHANGELOG
10. 完整建造回归测试结果
11. 仍存在的 TODO / 风险
```

完成这些后不要自动进入 UnitPanel 或 FOOD。
