# GPT Game：资源系统 V2 数据驱动化 + 编辑器工具------分阶段迁移计划

## 0. 本章目标

当前工程的
`WOOD / STONE`、采集、库存、HUD、施工物流和建造系统已经正常运行。

下一阶段原本准备开发居民：

``` text
工作 → 进食 → 休息 → 恢复工作
```

但后续游戏明确需要：

``` text
粮食 + 肉
粮食 → 面粉 → 面包
肉 → 加工食品 → 高级料理

木材 → 木板 → 更高级材料
石头 → 石砖 → 更高级材料
矿石 → 金属锭 → 工具
```

因此现在先进行一次 **资源系统 V2 数据驱动化**。

目标不是只增加
FOOD，而是建立以后一级、二级、三级乃至更多加工层级都能复用的统一资源底座。

------------------------------------------------------------------------

# 1. 最终设计原则

以后不要为每个新资源不断扩展大量硬编码：

``` gdscript
enum Type {
    WOOD,
    STONE,
    GRAIN,
    MEAT,
    FLOUR,
    BREAD,
    PLANK,
    ...
}
```

最终资源应由：

``` text
稳定 Resource ID
+
ResourceData (.tres)
```

共同定义。

例如：

``` text
&"wood"
&"stone"
&"grain"
&"meat"
&"plank"
&"flour"
&"bread"
```

其中：

``` text
ID
```

是游戏逻辑、存档和资源引用的稳定身份。

`.tres`：

``` text
ResourceData
```

负责名称、类别、层级、标签、图标、食物属性等数据。

资源、配方和生产建筑的职责必须分开：

``` text
ResourceData
→ 定义“资源是什么”

RecipeData
→ 定义“资源如何转换”

ProductionBuildingBase
→ 定义“在哪里、由谁、花多久加工”
```

禁止把 `WOOD → PLANK`、`GRAIN → FLOUR` 等加工关系直接写进
ResourceData。Tier 只表示产业层级，不自动代表升级规则。

------------------------------------------------------------------------

# 2. 非常重要：本次必须分阶段执行

本任务是底层迁移，禁止一次性把整个工程全部替换。

执行规则：

1.  每次只执行一个阶段。
2.  完成后运行工程。
3.  执行该阶段测试。
4.  汇报修改文件和结果。
5.  **立即停止。**
6.  等用户回复"正常 / 继续 / 下一阶段"后才能继续。
7.  如果本阶段失败，只修本阶段，不提前开发后面的阶段。

## 第一次读取本文档时

**只执行阶段 1。**

不要自动执行阶段 2。

调整后的阶段顺序：

``` text
阶段 1   ResourceData + FoodProperties + ResourceDatabase
阶段 2   第一批 ResourceData
阶段 2.5 Resource Editor 最小版
阶段 3   ResourceStorage 迁移
阶段 4   ResourceManager 迁移
阶段 5   Villager Carry + ResourceBuildingBase 迁移
阶段 6   BuildingData + ConstructionSite + Task 迁移
阶段 7   动态 ResourceHUD
阶段 8   RecipeData 配方底座
阶段 8.5 Recipe Editor 最小版
阶段 9   清理旧 ResourceType 兼容层
```

------------------------------------------------------------------------

# 3. 迁移期间必须保护的现有系统

当前已经工作的系统不能因为资源 V2 重构而失效：

``` text
Tree
Stone

LumberCamp
Quarry

ResourceBuildingBase
ResourceStorage
ResourceManager

Villager
LUMBERJACK
MINER

HUD
LevelConfig

BuildingData
BuildGrid
BuildingGhost
ConstructionSite

GameTask
TaskManager
施工材料运输
多人施工
正式建筑生成

ResourceBuildingPanel
VillagerPanel
ResourceNodePanel
Base 库存面板
对象选择 UI
统一对象描边
```

尤其必须持续保证：

``` text
砍树 → WOOD
采石 → STONE
运输
库存
HUD
施工消耗
建筑完工
```

完整闭环正常。

后续阶段必须显式检查当前工程中的这些旧资源引用，不能只搜索
ResourceStorage：

``` text
ResourceType.Type.FOOD
Base.resource_changed
ResourceNodePanel 的资源类型显示
ResourceBuildingPanel 的 Base WOOD / STONE / FOOD 显示
LevelConfig.initial_wood / initial_stone
ResourceBase.resource_type
TaskManager 的资源变化信号参数
BuildingData.construction_cost 的数字枚举 Key
```

------------------------------------------------------------------------

# 4. 新资源系统总体结构

最终目标：

``` text
                    ResourceData
                         │
       ┌─────────────────┼──────────────────┐
       ↓                 ↓                  ↓
    Category            Tier               Tags
                                             │
                                             ↓
                                      FoodProperties
                         │
                         ↓
                  ResourceDatabase
                         │
       ┌─────────────────┼─────────────────┐
       ↓                 ↓                 ↓
ResourceStorage    ResourceManager    BuildingData
       │                 │                 │
       ↓                 ↓                 ↓
 Villager Carry          HUD        ConstructionSite
       │
       │
       └──────────────┐
                      ↓
                  RecipeData
                      │
                      ↓
             ProductionBuildingBase
                      │
             Input → Process → Output
```

`ProductionBuildingBase` 属于后续章节，本次只建立它未来需要的数据基础。

------------------------------------------------------------------------

# 阶段 1：ResourceData + ResourceDatabase

## 目标

只建立新资源数据底座。

**不迁移当前 WOOD / STONE。**

当前旧系统继续照常运行。

------------------------------------------------------------------------

## 1.1 ResourceData

建议：

``` gdscript
class_name ResourceData
extends Resource
```

至少支持：

``` text
id
display_name
category
tier
tags
icon
stack_size
food_properties
```

可以根据当前工程风格调整具体字段类型。

### ID

推荐：

``` gdscript
@export var id: StringName
```

例如：

``` text
&"wood"
&"stone"
&"grain"
```

ID 必须稳定。

显示名称改变不能改变 ID。

例如：

``` text
ID = grain
显示名称 = 粮食
```

以后显示名称改成：

``` text
小麦
```

ID 仍然必须是：

``` text
grain
```

------------------------------------------------------------------------

## 1.2 ResourceCategory

建立稳定的大类别。

第一版可以包括：

``` text
RAW_MATERIAL
BUILDING_MATERIAL
FOOD
METAL
TOOL
GOODS
LUXURY
FUEL
```

如果当前阶段暂时用不到全部，可以保留合理精简版本。

不要把 Category 当作所有行为判断的唯一依据。

------------------------------------------------------------------------

## 1.3 Tier

``` text
tier = 1 / 2 / 3 ...
```

表示：

> 产业加工深度 / 资源层级。

例如：

``` text
WOOD      T1
PLANK     T2

GRAIN     T1
FLOUR     T2
BREAD     T3
```

但禁止写：

``` gdscript
if resource.tier == 2:
    # 某种特殊行为
```

Tier 主要用于：

``` text
UI
科技
产业链
分类
平衡
```

真正行为由数据、Tags、Recipe 等决定。

------------------------------------------------------------------------

## 1.4 Tags

ResourceData 支持 Tags，例如：

``` text
WOOD
RAW
CONSTRUCTION

FOOD
GRAIN
PLANT
RAW

FOOD
PROCESSED_FOOD
GRAIN_PRODUCT
```

建议使用：

``` text
Array[StringName]
```

或当前工程更适合的数据结构。

提供简单接口，例如：

``` gdscript
func has_tag(tag: StringName) -> bool
```

------------------------------------------------------------------------

## 1.5 FoodProperties

不要建立完全独立于资源系统之外的 Food 库存体系。

食物仍然是普通 ResourceData，只是额外拥有食物属性。

建议：

``` gdscript
class_name FoodProperties
extends Resource
```

第一版预留：

``` text
nutrition
food_quality
variety_group
```

例如：

``` text
WOOD
food_properties = null

GRAIN
food_properties != null

MEAT
food_properties != null

BREAD
food_properties != null
```

ResourceData 可以提供：

``` gdscript
func is_food() -> bool:
    return food_properties != null
```

本阶段只建立数据结构。

**不要开发居民进食。**

------------------------------------------------------------------------

## 1.6 ResourceDatabase

建立统一资源定义查询。

职责：

``` text
Resource ID
↓
ResourceData
```

例如：

``` gdscript
get_resource_data(&"wood")
```

返回 Wood 的 ResourceData。

至少考虑：

``` text
注册资源
按 ID 查询
检查 ID 是否存在
重复 ID 检测
无效 ID 警告
```

结合当前工程没有 Autoload、但大量数据使用 `.tres` 的现状，阶段 1
优先采用：

``` text
ResourceDatabase extends Resource
@export var resources: Array[ResourceData]
运行时建立 ID → ResourceData 索引
data/resources/resource_database.tres 作为 Inspector 可维护配置
```

阶段 1 不新增 Autoload。等运行逻辑开始迁移时，再决定由 Main、
ResourceManager 或统一游戏配置持有数据库引用。

不要为了数据库实现复杂文件系统自动扫描框架，除非当前工程已有成熟方式。

------------------------------------------------------------------------

## 阶段 1 禁止

不要修改：

``` text
ResourceStorage
ResourceManager
Villager Carry
LumberCamp
Quarry
BuildingData
ConstructionSite
HUD
LevelConfig
```

不要删除：

``` text
ResourceType
```

旧 enum 继续工作。

------------------------------------------------------------------------

## 阶段 1 测试

验证：

``` text
ResourceData 可以创建 .tres
ID 可以读取
Category 可以读取
Tier 可以读取
Tags 可以读取
FoodProperties 可以为空/存在
ResourceDatabase 可以通过 ID 找到 ResourceData
重复 ID 有清晰警告
无效 ID 不导致崩溃
```

阶段 1 可以通过内存对象以及 `user://` 临时保存/读取验证序列化，
不要为了测试提前在正式数据目录创建 wood、stone 等阶段 2 资源定义。

同时运行游戏确认：

``` text
WOOD / STONE
砍树
采石
HUD
建造
施工
```

完全不受影响。

完成后停止。

------------------------------------------------------------------------

# 阶段 2：建立第一批 ResourceData

## 目标

创建真实资源定义，但仍然不迁移旧运行逻辑。

建议目录：

``` text
resources/data/
```

具体遵循当前工程目录规范。

第一批：

``` text
T1
WOOD
STONE
GRAIN
MEAT

T2
PLANK
FLOUR

T3
BREAD
```

------------------------------------------------------------------------

## 示例关系

``` text
WOOD
ID = wood
Tier = 1
Tags = wood, raw, construction

STONE
ID = stone
Tier = 1
Tags = stone, raw, construction

GRAIN
ID = grain
Tier = 1
Category = FOOD
FoodProperties != null

MEAT
ID = meat
Tier = 1
Category = FOOD
FoodProperties != null

PLANK
ID = plank
Tier = 2
Tags = wood, processed, construction

FLOUR
ID = flour
Tier = 2
Category = FOOD
FoodProperties != null

BREAD
ID = bread
Tier = 3
Category = FOOD
FoodProperties != null
```

具体 nutrition / quality 数值只用于测试，后期再平衡。

------------------------------------------------------------------------

## 注意

本阶段：

``` text
GRAIN / MEAT
```

不需要生产来源。

``` text
PLANK / FLOUR / BREAD
```

也不需要生产建筑。

它们用于证明系统能表达：

``` text
多类别
多 Tier
食物
加工品
```

------------------------------------------------------------------------

## 阶段 2 测试

通过 ResourceDatabase 验证所有 ID：

``` text
wood
stone
grain
meat
plank
flour
bread
```

均可正确找到。

完成后停止。

------------------------------------------------------------------------

# 阶段 2.5：Resource Editor 最小版

## 目标

复用当前 Trait Editor 的工程经验，建立资源数据编辑工具，避免资源数量增加后
长期手工管理大量 `.tres`。

第一版只负责 ResourceData，不编辑 RecipeData。

## 最小功能

``` text
扫描 data/resources/
显示资源列表
按 Category / Tier / Tags 筛选
新建资源时要求输入稳定 ID
编辑显示名称、图标、Category、Tier、Tags、stack_size
编辑/清空 FoodProperties
保存、刷新
重复 ID 和非法 ID 提示
```

ID 创建后默认只读。显示名称可以修改，但不能把显示名称当成引用或存档 Key。

## 删除规则

``` text
没有引用
→ 允许删除

存在 ResourceDatabase、建筑成本、配方或其他数据引用
→ 阻止删除，并列出引用位置
```

阶段 2.5 时部分 V2 引用尚未迁移，第一版至少检查 ResourceDatabase；
后续阶段建立 BuildingData V2 和 RecipeData 后继续扩展引用检查。

不要在第一版开发节点图、产业链图或生产建筑编辑器。

## 阶段 2.5 测试

``` text
可以新建测试资源
可以编辑并保存后重新读取
不能创建空 ID 或重复 ID
ID 不会因修改显示名称而改变
有数据库引用的资源不能被误删
```

现有 WOOD / STONE 运行逻辑仍不迁移。

完成后停止。

------------------------------------------------------------------------

# 阶段 3：ResourceStorage 迁移到 Resource ID

## 目标

库存底层逐步从：

``` text
ResourceType.Type
```

迁移为：

``` text
StringName Resource ID
```

例如：

``` text
wood: 50
stone: 20
grain: 10
```

推荐库存核心身份使用：

``` text
StringName
```

而不是把 ResourceData 对象本身当作存档身份。

------------------------------------------------------------------------

## 兼容层

迁移期间必须保留旧接口兼容。

例如如果当前大量代码仍调用：

``` text
ResourceType.Type.WOOD
```

可以暂时提供转换：

``` text
旧 enum
↓
Resource ID
```

例如：

``` text
WOOD → &"wood"
STONE → &"stone"
FOOD → &"food"
```

当前 Base 已经保存 FOOD，兼容层不得只处理 WOOD / STONE。
不要第一天删除 ResourceType。

------------------------------------------------------------------------

## ResourceStorage 最终目标接口

概念上支持：

``` text
get_amount(resource_id)
add_resource(resource_id, amount)
take_resource(resource_id, amount)
has_resource(resource_id)
get_free_space(resource_id)
```

实际函数名优先兼容当前工程，避免无意义大改。

阶段 3 必须允许旧 enum 调用与新 StringName 调用并存；旧接口统一转换到
ID 核心实现，禁止维护两份彼此独立的库存。

------------------------------------------------------------------------

## 信号

资源变化信号也应能表达：

``` text
resource_id
old/new amount
```

以便：

``` text
ResourceManager
TaskManager
HUD
ConstructionSite
```

监听。

------------------------------------------------------------------------

## 阶段 3 测试

重点：

``` text
Base WOOD / STONE 正常
LumberCamp 库存正常
Quarry 库存正常
资源增加/取出正常
旧调用仍兼容
HUD 暂时仍能正常工作
施工物流正常
```

完成后停止。

------------------------------------------------------------------------

# 阶段 4：ResourceManager 迁移

## 目标

全局资源统计改为基于 Resource ID。

最终支持：

``` gdscript
get_total(&"wood")
get_total(&"stone")
get_total(&"grain")
```

ResourceManager 不需要为每种资源新增：

``` text
wood变量
stone变量
grain变量
meat变量
```

而应动态统计。

------------------------------------------------------------------------

## 总量定义继续保持

``` text
全局可支配资源
=
所有合法 ResourceStorage
+
居民正在携带的资源
```

ConstructionSite 已投入材料：

``` text
不计入可支配资源
```

此规则不得因为 V2 重构改变。

------------------------------------------------------------------------

## 阶段 4 测试

``` text
Storage → Villager
HUD/ResourceManager 总量不变

Villager → ConstructionSite
总量减少
```

WOOD / STONE 全部回归。

完成后停止。

------------------------------------------------------------------------

# 阶段 5：Villager Carry + ResourceBuildingBase 迁移

## 目标

居民携带资源和资源建筑生产类型改为 Resource ID。

例如：

``` text
LumberCamp.production_resource_id = &"wood"
Quarry.production_resource_id = &"stone"
```

Villager：

``` text
carried_resource_id
carried_amount
```

不要继续让 Villager 写死：

``` text
LUMBERJACK → WOOD
MINER → STONE
```

仍然保持现有通用原则：

``` text
Villager
↓
workplace.production_resource_id
↓
决定采集什么
```

本阶段同时迁移当前真实使用者：

``` text
ResourceBase.resource_type
ResourceNodePanel 的资源类型与剩余量显示
VillagerPanel 的携带资源显示
ResourceBuildingBase.production_resource_id
ResourceBuildingPanel 的资源建筑库存显示
```

这些节点和面板只能通过 Resource ID 查询 ResourceDatabase，取得显示名称、图标和分类。
不得在 UI 中重新建立一套 `WOOD / STONE / FOOD` 判断。

------------------------------------------------------------------------

## 阶段 5 测试

完整：

``` text
Lumberjack → Tree → WOOD
Miner → Stone → STONE
```

并验证：

``` text
采集
携带
存入 ResourceBuilding
运输
HUD
```

全部正常。

完成后停止。

------------------------------------------------------------------------

# 阶段 6：BuildingData + ConstructionSite + Task 迁移

## 目标

建筑成本不能继续限定 WOOD / STONE enum。

最终：

``` gdscript
@export var construction_cost: Dictionary[StringName, float]
```

支持任意：

``` text
Resource ID → Amount
```

例如以后：

``` text
高级建筑：

plank       30
stone_brick 20
iron_bar     5
```

ConstructionSite 只处理：

``` text
Resource ID
```

不知道什么叫 WOOD/STONE。

第一版 V2 统一使用：

``` gdscript
Dictionary[StringName, float]
```

表达“资源 ID → 数量”。BuildingData 成本、ConstructionSite
需求/已送达/已预约，以及后续 RecipeData 输入输出保持同一种表达方式。

本次迁移不要中途再引入 `ResourceAmount`，避免 BuildingData 和施工链发生第二次结构迁移。

LevelConfig 也必须在本阶段处理。优先迁移为：

``` gdscript
@export var initial_resources: Dictionary[StringName, float]
```

如果 Inspector 迁移风险暂时过高，可以短期保留 `initial_wood / initial_stone`，
但进入游戏时必须立即转换到 Resource ID 接口，并在阶段 9 前移除。

------------------------------------------------------------------------

## 施工运输任务

DeliverResourceTask 同样改为：

``` text
resource_id
amount
source
destination
```

不要写死资源枚举。

TaskManager 创建、领取、完成、取消任务时涉及资源类型的参数与信号，也全部改为
稳定 Resource ID。旧 enum 参数只能存在于明确标注的兼容入口中。

------------------------------------------------------------------------

## 阶段 6 测试

完整跑：

``` text
LumberCamp 蓝图
→ ConstructionSite
→ WOOD 搬运
→ 消费
→ 施工
→ 完工
```

以及：

``` text
Quarry
→ 对应成本
→ 搬运
→ 完工
```

多工地、缺料、补料恢复都必须回归。

完成后停止。

------------------------------------------------------------------------

# 阶段 7：HUD 动态资源显示

## 当前问题

当前可能是：

``` text
WoodLabel
StoneLabel
```

未来资源几十种后不能继续：

``` text
GrainLabel
MeatLabel
FlourLabel
BreadLabel
PlankLabel
...
```

------------------------------------------------------------------------

## 目标

建立：

``` text
ResourceHUD
↓
ResourceEntry
```

动态显示指定核心资源。

例如当前顶部先显示：

``` text
WOOD
STONE
GRAIN
MEAT
```

后续可以通过配置决定哪些资源固定显示。

ResourceEntry 的显示信息必须来自 ResourceDatabase：

``` text
resource_id
→ display_name
→ icon
→ ResourceManager 总量
```

新增 ResourceData 后，最多只需修改 HUD 的显示配置，不应修改 HUD 核心脚本。

当前 Base 的库存面板也必须改为动态条目，不再固定读取
`WOOD / STONE / FOOD` 三个字段；统一对象面板的打开、关闭动画与描边选择行为保持不变。

------------------------------------------------------------------------

## 详细资源面板

本阶段可以只预留，不必开发完整详细面板。

未来：

``` text
原材料
食物
加工品
金属
奢侈品
```

分类显示所有库存。

------------------------------------------------------------------------

## 阶段 7 测试

资源数量变化后 HUD 正确刷新。

不能因为添加一个新 ResourceData 就要求修改 HUD 脚本核心逻辑。

完成后停止。

------------------------------------------------------------------------

# 阶段 8：RecipeData 通用配方底座

## 目标

建立统一加工配方数据。

不要做：

``` text
FoodRecipe
WoodRecipe
MetalRecipe
```

三套系统。

统一：

``` gdscript
class_name RecipeData
extends Resource
```

------------------------------------------------------------------------

## 配方至少支持

``` text
id
display_name
inputs
outputs
processing_time
```

第一版 V2 直接使用：

``` gdscript
@export var inputs: Dictionary[StringName, float]
@export var outputs: Dictionary[StringName, float]
```

与 `BuildingData.construction_cost` 使用同一种“资源 ID → 数量”表达方式。

本轮不建立 `ResourceAmount`。只有实际使用后确认 Godot Inspector 编辑 Dictionary
明显影响维护，再单独立项评估是否迁移；不能在本计划中同时维护两套数量结构。

------------------------------------------------------------------------

## 第一批测试 Recipe

### 木板

``` text
WOOD ×2
↓
PLANK ×1
```

### 面粉

``` text
GRAIN ×2
↓
FLOUR ×1
```

### 面包

``` text
FLOUR ×2
↓
BREAD ×1
```

只建立 `.tres` 配方并验证读取。

**不要开发生产建筑。**

------------------------------------------------------------------------

## 阶段 8 测试

验证 RecipeData 能正确读取：

``` text
输入
输出
加工时间
资源 ID
```

ResourceDatabase 能解析配方引用资源。

完成后停止。

------------------------------------------------------------------------

# 阶段 8.5：Recipe Editor 最小版

## 目标

让配方能够在编辑器中安全创建、修改和删除，不要求开发生产建筑或节点图。

优先与 Resource Editor 放在同一个 EditorPlugin 中，用两个页签管理：

``` text
Resources
Recipes
```

避免建立两套重复的扫描、保存和校验逻辑。

## 最小功能

``` text
扫描 data/recipes 下的 RecipeData
按 ID / 显示名称筛选
创建稳定且唯一的 recipe id
编辑 display_name
编辑 inputs / outputs
编辑 processing_time
保存并刷新列表
```

资源选择必须来自 ResourceDatabase，不能依赖手写字符串。

## 校验与删除规则

保存前必须阻止：

``` text
重复 recipe id
不存在的 resource id
空 inputs
空 outputs
数量小于或等于 0
processing_time 小于或等于 0
```

recipe id 创建后默认只读。删除配方前检查已知引用；如果未来已有建筑引用该配方，
编辑器必须列出引用并阻止直接删除。

第一版明确不做：

``` text
节点图编辑器
产业链自动布局
产量模拟器
ProductionBuildingBase 运行逻辑
配方自动升级或合成规则
```

## 阶段 8.5 测试

``` text
创建测试配方
保存
重新扫描并读取
修改后再次读取
非法资源 ID 被阻止
重复 ID 被阻止
有引用的配方无法直接删除
```

完成后停止。

------------------------------------------------------------------------

# 阶段 9：清理旧 ResourceType 兼容层

只有前面阶段 1～8.5 全部测试通过，并确认所有真实运行引用完成迁移后才允许执行。

## 先全工程搜索

搜索：

``` text
ResourceType.Type
WOOD enum
STONE enum
get_amount(enum)
add_resource(enum)
take_resource(enum)
```

确认是否仍有真实运行代码依赖旧系统。

------------------------------------------------------------------------

## 原则

如果仍然存在重要旧引用：

``` text
不要强删。
```

先迁移引用。

只有整个运行链全部使用 Resource ID 后，才删除或废弃旧 ResourceType
enum。

------------------------------------------------------------------------

## 最终回归

必须完整测试：

``` text
开局 LevelConfig
↓
WOOD / STONE
↓
LumberCamp / Quarry
↓
采集
↓
携带
↓
本地库存
↓
ResourceManager
↓
HUD
↓
建造蓝图
↓
施工物流
↓
施工
↓
正式建筑
↓
继续生产
```

并测试：

``` text
ResourceDatabase
grain
meat
plank
flour
bread
```

即使暂时没有生产来源，也必须能被系统识别和存储。

------------------------------------------------------------------------

# 5. 未来居民食物系统如何接入（本次不开发）

资源 V2 完成后，下一章才做：

``` text
Villager Food Need
↓
寻找 ResourceStorage
↓
查询其中可用 ResourceData
↓
resource.is_food()
↓
villager.can_eat(resource)
↓
选择食物
↓
消费
↓
休息
↓
恢复工作
```

第一版：

``` text
有什么可吃的就吃什么
```

后期：

``` text
营养
食物品质
饮食丰富度
Trait 喜好/禁忌
幸福感
高级料理
```

------------------------------------------------------------------------

# 6. 未来产业链（本次不开发）

## 食品

``` text
T1
GRAIN
MEAT
VEGETABLE

↓ 加工

T2
FLOUR
COOKED_MEAT
PRESERVED_FOOD

↓ 加工

T3
BREAD
MEAT_DISH
ADVANCED_MEAL
```

## 木材

``` text
WOOD
↓
PLANK
↓
FURNITURE / ADVANCED_WOOD_PRODUCT
```

## 石材

``` text
STONE
↓
STONE_BRICK
↓
CARVED_STONE
```

## 金属

``` text
IRON_ORE
↓
IRON_BAR
↓
TOOLS / WEAPONS
```

所有产业统一使用：

``` text
ResourceData
+
RecipeData
+
未来 ProductionBuildingBase
```

------------------------------------------------------------------------

# 7. 未来 ProductionBuildingBase（本次不开发）

以后建立：

``` text
BuildingBase
├─ ResourceBuildingBase
│  ├─ LumberCamp
│  └─ Quarry
│
├─ ProductionBuildingBase
│  ├─ Sawmill
│  ├─ Mill
│  ├─ Bakery
│  ├─ Kitchen
│  └─ Smelter
│
├─ StorageBuildingBase
└─ TrainingBuildingBase
```

ProductionBuildingBase 只关心：

``` text
RecipeData
输入库存
工人
加工时间
输出库存
```

不关心：

``` text
“我是面包房”
“我是锯木厂”
```

具体差异由数据决定。

------------------------------------------------------------------------

# 8. 存档兼容原则

从 V2 开始资源身份必须优先使用稳定 ID：

``` text
wood
stone
grain
...
```

未来存档建议保存：

``` text
{
    "wood": 50,
    "stone": 30,
    "grain": 20
}
```

而不是保存：

``` text
enum 数字
Resource 对象内存身份
显示名称
```

禁止把：

``` text
"木材"
```

这样的显示名称作为稳定存档 Key。

------------------------------------------------------------------------

# 9. README 更新要求

每完成一个阶段再同步实际进度，不提前标记。

资源 V2 全部完成后，README 应说明：

``` text
ResourceData 数据驱动资源定义        ✅
ResourceDatabase                    ✅
Resource Editor                     ✅
稳定 StringName Resource ID         ✅
ResourceStorage V2                  ✅
ResourceManager V2                  ✅
Villager Carry V2                   ✅
BuildingData 任意资源成本            ✅
ConstructionSite 任意资源物流        ✅
动态 ResourceHUD                    ✅
RecipeData 配方底座                  ✅
Recipe Editor                       ✅
```

并说明：

``` text
旧 WOOD / STONE 功能保持完整。
```

------------------------------------------------------------------------

# 10. ROADMAP 更新要求

当前主线改为：

``` text
【当前】
资源系统 V2 数据驱动化
↓
ResourceData
↓
ResourceDatabase
↓
Resource Editor
↓
ResourceStorage / ResourceManager 迁移
↓
Villager / Building / Construction 迁移
↓
动态 HUD
↓
RecipeData
↓
Recipe Editor
↓
【下一章】
居民 FOOD + 工作/进食/休息循环
```

保留后续：

``` text
ProductionBuildingBase
粮食生产
肉类生产
二级/三级食品
二级/三级材料
Warehouse
House
幸福感
训练建筑
战斗
程序化地图
```

------------------------------------------------------------------------

# 11. 本章明确禁止顺手开发

资源 V2 迁移期间不要顺便做：

``` text
农场
牧场
狩猎
磨坊
面包房
锯木厂
冶炼厂
居民吃饭
疲劳
休息
幸福感
Warehouse
生产建筑运行逻辑
存档系统完整版
程序化地图
```

先把底层迁移稳定。

------------------------------------------------------------------------

# 12. 每阶段完成后的汇报格式

每个阶段完成后请汇报：

``` text
1. 当前完成的是第几阶段
2. 新增文件
3. 修改文件
4. 新增了哪些接口
5. 是否修改了旧 WOOD / STONE 运行逻辑
6. 回归测试结果
7. 是否发现旧系统硬编码
8. 是否存在兼容层
9. 当前 TODO / 风险
10. 编辑器校验与引用扫描结果（编辑器阶段填写）
11. 下一阶段准备做什么
```

然后停止等待用户测试。

------------------------------------------------------------------------

# 13. 第一次执行指令

第一次读取本文件：

``` text
只执行阶段 1：
ResourceData + FoodProperties + ResourceDatabase
```

必须保证：

``` text
现有游戏行为完全不变。
```

阶段 1 完成并汇报后立即停止。

等待用户实际运行测试并确认后，再进入阶段 2。
