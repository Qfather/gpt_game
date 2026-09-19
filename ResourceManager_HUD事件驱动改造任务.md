# ResourceManager + HUD 改为事件驱动刷新

## 任务目标

当前 Godot 工程已经完成并验证：

-   `BuildingBase -> ResourceBuildingBase -> LumberCamp / Quarry`
-   LumberCamp 可以招募/解雇伐木工并采集 WOOD
-   Quarry 可以招募/解雇矿工并采集 STONE
-   Villager 的资源工作逻辑已经通用化，通过
    `workplace.production_resource_type` 判断采集资源
-   `ResourceManager` 已经能够统计：
    -   所有己方 `ResourceStorage`
    -   所有居民 `carried_amount`
-   HUD 已显示全局 WOOD + STONE 总量
-   已实际验证：资源从 Quarry/LumberCamp 搬到居民身上，再运到 Base
    时，HUD 总量不会变化

当前临时实现是 HUD 在 `_process()` 中每帧调用
`ResourceManager.get_total()`。

本次任务：

> 将资源 HUD 从"每帧遍历统计"改为"资源发生变化时才刷新"的 Signal
> 事件驱动方案，同时保持现有全局资源总量定义完全不变。

------------------------------------------------------------------------

## 一、必须先读取当前工程

不要直接用本文示例覆盖现有文件。

先检查当前实际代码和节点结构，重点包括：

``` text
ResourceManager.gd
resource_storage.gd
villager.gd
hud.gd
base.gd
ResourceBuildingBase.gd
lumber_camp.gd
quarry.gd
Main.tscn
HUD.tscn
```

搜索：

``` text
resource_changed
carried_amount
carried_resource_type
get_carried_amount
get_carried_resource_type
get_total
get_storage_total
get_carried_total
resource_storages
resource_manager
_process
update_resource_display
```

以当前工程实际接口为准。

------------------------------------------------------------------------

# 二、全局资源总量定义禁止改变

HUD 当前显示的是"玩家拥有的全局资源总量"，不是 Base 自己的库存。

必须继续满足：

``` text
全局资源总量
=
所有己方 ResourceStorage 中的资源
+
所有己方居民当前携带的资源
```

例如：

``` text
Base        STONE 10
Quarry      STONE 5
Miner       STONE 3

HUD STONE = 18
```

资源运输只是改变位置：

``` text
Quarry -5
Miner +5
```

HUD 总量不能减少。

随后：

``` text
Miner -5
Base +5
```

HUD 总量也不能增加。

只有真正新增/消费资源时，总量才变化：

``` text
采集 Stone       → HUD +N
采集 Tree        → HUD +N
以后建造消耗     → HUD -N
以后吃饭消耗     → HUD -N
```

地图上尚未采集的 Tree/Stone `resource_amount` 不计入 HUD。

------------------------------------------------------------------------

# 三、ResourceManager 增加统一变化信号

在当前 `ResourceManager` 中增加：

``` gdscript
signal resources_changed
```

增加同一帧合并刷新机制，例如：

``` gdscript
var refresh_queued: bool = false
```

任意资源来源变化后，不要立刻重复让 HUD 刷新多次，而是请求一次 deferred
刷新。

目标逻辑：

``` text
Quarry Storage -5 ─┐
                   ├─ request_refresh()
Miner carried +5 ──┘
                         ↓
                  同一帧只排队一次
                         ↓
                 deferred / 帧末
                         ↓
               resources_changed
                         ↓
                      HUD
```

可以采用类似：

``` gdscript
func request_refresh() -> void:
    if refresh_queued:
        return

    refresh_queued = true
    call_deferred("_emit_resources_changed")


func _emit_resources_changed() -> void:
    refresh_queued = false
    resources_changed.emit()
```

具体实现请结合当前工程。

------------------------------------------------------------------------

# 四、ResourceManager 监听 ResourceStorage

当前 `ResourceStorage` 已经有资源变化相关 Signal
时，应优先复用，不要重复设计另一套库存事件。

例如当前存在：

``` gdscript
signal resource_changed(...)
```

则 ResourceManager 在初始化后连接所有：

``` text
resource_storages
```

中的 Storage。

目标：

``` text
ResourceStorage.add()
ResourceStorage.take()
        ↓
resource_changed
        ↓
ResourceManager.request_refresh()
```

不要让 HUD 自己监听 Base/LumberCamp/Quarry。

HUD 只监听 ResourceManager。

------------------------------------------------------------------------

# 五、Villager 增加携带资源变化通知

因为全局总量还包括：

``` text
Villager.carried_amount
```

所以居民携带资源变化也必须通知 ResourceManager。

如果当前 Villager 尚无此 Signal，增加：

``` gdscript
signal carried_resource_changed
```

然后检查所有真正修改以下变量的位置：

``` gdscript
carried_amount
carried_resource_type
```

包括但不限于：

``` text
采集资源
从工作建筑取资源
向工作建筑卸货
向 Base 卸货
清空/重置携带资源
离职相关流程（如果会改变携带量）
```

修改完成后发出：

``` gdscript
carried_resource_changed.emit()
```

注意：

-   不要遗漏 `+=`
-   不要遗漏 `-=`
-   不要遗漏直接 `=`
-   不要因为一次函数内部连续修改 type + amount
    而产生不必要的重复通知；可以在该次完整修改结束后 emit 一次

现有查询接口：

``` gdscript
get_carried_amount()
get_carried_resource_type()
```

如果已经存在，保持。

------------------------------------------------------------------------

# 六、ResourceManager 连接 Villager

ResourceManager 初始化时还要连接当前所有：

``` text
villagers
```

中的：

``` gdscript
carried_resource_changed
```

然后统一调用：

``` gdscript
request_refresh()
```

不要让 HUD 直接连接 Villager。

------------------------------------------------------------------------

# 七、HUD 删除每帧资源统计

当前 HUD 如果存在：

``` gdscript
func _process(_delta: float) -> void:
    update_resource_display()
```

删除这套每帧资源刷新逻辑。

注意：

> 如果 HUD `_process()`
> 未来还有其他非资源用途，不要粗暴删除整个函数，只删除资源统计部分。

HUD 应：

``` text
_ready()
↓
找到 ResourceManager
↓
连接 ResourceManager.resources_changed
↓
主动 update_resource_display() 一次
```

之后：

``` text
resources_changed
↓
update_resource_display()
```

HUD 继续使用当前已经设置好的唯一名称节点：

``` gdscript
@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
```

不要重新改回写死的节点路径。

------------------------------------------------------------------------

# 八、保持当前 HUD 含义

HUD：

``` text
WOOD = 全局木材
STONE = 全局石头
```

不是：

``` text
Base 木材
Base 石头
```

不要恢复旧的：

``` text
HUD -> Base.resource_changed
HUD -> base.wood
```

旧的 Base 专用 HUD 逻辑如果已经废弃，可以清理。

------------------------------------------------------------------------

# 九、Base 自身库存与 HUD 必须区分

当前设计已经确定：

``` text
HUD
= 全局资源总量

未来 BasePanel
= Base 自己的 ResourceStorage

ResourceBuildingPanel
= 当前 LumberCamp / Quarry 自己的 ResourceStorage

未来 ResourceDetailPanel
= 显示资源分别存在哪里
```

本次不要创建 BasePanel 或 ResourceDetailPanel。

------------------------------------------------------------------------

# 十、当前 ResourceManager 查询接口应保留

类似以下接口继续保留：

``` gdscript
get_total(resource_type)
get_storage_total(resource_type)
get_carried_total(resource_type)
get_storages()
```

以后详细资源面板会使用。

不要为了事件驱动把 ResourceManager 改成只缓存两个 HUD 数字。

未来还需要支持：

``` text
WOOD
STONE
FOOD
更多资源
```

------------------------------------------------------------------------

# 十一、动态建筑暂时不扩大实现

当前 ResourceManager 可以先连接场景启动时已经存在的：

``` text
Base ResourceStorage
LumberCamp ResourceStorage
Quarry ResourceStorage
Villagers
```

以后进入正式建造系统后，运行时可能新增：

``` text
Warehouse
LumberCamp
Quarry
Villager
```

那时再实现动态注册/注销机制。

本次不要顺带实现完整运行时注册系统，除非当前工程已经自然具备相关机制且修改非常小。

可以留下清晰 TODO。

------------------------------------------------------------------------

# 十二、不要破坏现有系统

本次禁止顺带重构：

``` text
ResourceBuildingBase
LumberCamp
Quarry
Villager 工作状态机
Job
ResourceType
Trait
UnitBase
Navigation
建筑 UI
采集逻辑
运输逻辑
```

尤其不要重新引入：

``` text
LUMBERJACK -> WOOD
MINER -> STONE
```

Villager 当前已经通过：

``` text
workplace is ResourceBuildingBase
workplace.production_resource_type
```

实现通用资源采集，这一架构必须保留。

------------------------------------------------------------------------

# 十三、必须实际运行测试

修改后实际运行当前主场景。

至少验证：

### 1. 启动

-   无新增 Parser Error
-   无 Warning-as-error
-   ResourceManager 正常找到
-   WoodLabel 正常
-   StoneLabel 正常

### 2. 伐木

``` text
LumberCamp
→ 招募
→ LUMBERJACK
→ 找 Tree
→ 采集
```

采到新的 WOOD 时：

``` text
HUD WOOD 增加
```

### 3. 采石

``` text
Quarry
→ 招募
→ MINER
→ 找 Stone
→ 采集
```

采到新的 STONE 时：

``` text
HUD STONE 增加
```

### 4. 搬运

例如 Quarry：

``` text
Quarry STONE -5
Miner carried STONE +5
```

HUD STONE 必须保持不变。

### 5. 运到 Base

``` text
Miner carried STONE -5
Base STONE +5
```

HUD STONE 必须保持不变。

WOOD 同样验证。

### 6. 招募/解雇

LumberCamp 和 Quarry：

``` text
招募正常
解雇正常
```

不得因为 Signal 改造破坏原工作状态机。

------------------------------------------------------------------------

# 十四、建议临时诊断

如果 HUD 不刷新，可以临时输出：

``` text
ResourceStorage resource_changed
Villager carried_resource_changed
ResourceManager request_refresh
ResourceManager resources_changed
HUD update_resource_display
```

定位后删除过量日志。

------------------------------------------------------------------------

# 十五、完成后的目标结构

``` text
ResourceStorage
      │
      └─ resource_changed ─────────┐
                                   │
Villager                           │
      │                            ▼
      └─ carried_resource_changed → ResourceManager
                                         │
                                         │ 同帧合并
                                         ▼
                                 resources_changed
                                         │
                                         ▼
                                        HUD
                                  WOOD / STONE
```

查询关系：

``` text
ResourceManager.get_total(type)
=
ResourceStorage totals
+
Villager carried totals
```

------------------------------------------------------------------------

# 十六、本次完成后停止

不要继续开发：

-   BasePanel
-   ResourceDetailPanel
-   建造系统
-   Warehouse
-   Food
-   居民休息/吃饭
-   人口
-   幸福感
-   战斗
-   程序化地图

完成事件驱动改造并测试后停止。

请汇报：

``` text
1. 修改了哪些文件
2. ResourceManager 如何监听 ResourceStorage
3. ResourceManager 如何监听 Villager
4. Villager 哪些携带资源变化位置增加了通知
5. HUD 是否已经彻底取消每帧资源扫描
6. 搬运过程中 HUD 总量是否保持不变
7. 新采集资源时 HUD 是否实时增加
8. 是否存在以后做动态建筑时需要补的 TODO
```

最终验收标准：

> HUD 不再每帧遍历资源系统；只有资源实际发生变化时才刷新，同时保持"所有
> Storage + 居民携带量 = 全局总量"的现有正确逻辑。
