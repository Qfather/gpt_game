# 时间裂缝 --- 项目开发 README

> **工程审查基准：2026-09-18**
>
> 本文档根据当前上传的 Godot
> 工程整理，用于记录**已经实际存在的系统、已经确定的设计规则、当前开发位置以及后续计划**。\
> 后续开发一段时间后，可以重新上传完整工程，再以实际代码为准更新本
> README，避免聊天记录与工程状态逐渐脱节。

------------------------------------------------------------------------

## 1. 项目核心方向

当前项目以"居民"为基础单位，围绕
**居民个体差异、自动工作、资源生产、职业发展、Trait 标签、全局效果与
Boss 影响** 展开。

目前确定的主要方向：

-   居民自动寻找工作、采集资源、运输资源。
-   建筑拥有岗位、本地库存以及对应 UI。
-   居民后续可以训练为剑士、弓手等职业单位。
-   所有单位共享统一的 `UnitBase` 基础属性体系。
-   单位通过 Trait 标签产生个体差异。
-   Trait 使用数据驱动方式配置，不把具体效果硬编码到居民脚本中。
-   居民出生时后续会随机获得通用 Trait。
-   转职后可以额外获得职业 Trait。
-   后续类似《杀戮尖塔》遗物的全局效果，也计划复用统一的 Modifier 思路。
-   Boss 的全局 Buff / Debuff 不直接硬编码在 Boss
    内，而是调用统一的全局效果数据。
-   居民存在工作周期：工作一段时间后返回据点，消耗食物并休息，然后继续原工作。

------------------------------------------------------------------------

# 2. 当前工程结构

当前核心目录大致如下：

``` text
res://
├─ Scene/
│  ├─ main.tscn
│  ├─ base.tscn
│  ├─ villager.tscn
│  ├─ lumber_camp.tscn
│  ├─ tree.tscn
│  ├─ stone.tscn
│  ├─ hud.tscn
│  └─ resource_building_panel.tscn
│
├─ Script/
│  ├─ main.gd
│  ├─ base.gd
│  ├─ villager.gd
│  ├─ lumber_camp.gd
│  ├─ resource_base.gd
│  ├─ tree.gd
│  ├─ stone.gd
│  ├─ hud.gd
│  ├─ stat_modifier.gd
│  │
│  ├─ trait/
│  │  ├─ trait_data.gd
│  │  └─ trait_level_data.gd
│  │
│  └─ unit/
│     ├─ unit_base.gd
│     └─ unit_trait.gd
│
├─ UI/
│  ├─ building_panel/
│  │  ├─ building_panel_base.gd
│  │  ├─ building_panel_base.tscn
│  │  └─ resource_building_panel.gd
│  │
│  └─ unit_panel/
│     ├─ unit_panel_base.gd
│     ├─ villager_panel.gd
│     └─ villager_panel.tscn
│
├─ addons/
│  └─ trait_editor/
│     ├─ plugin.cfg
│     └─ trait_editor_plugin.gd
│
└─ data/
   └─ traits/
      └─ swift_feet.tres
```

### 目录约定

``` text
Script/
```

放运行时代码。

``` text
UI/
```

放 UI 场景与 UI 脚本，并按系统分类。

``` text
data/
```

放实际游戏数据资源，例如 Trait `.tres`。

``` text
addons/
```

放 Godot 编辑器插件，例如 Trait Editor。

------------------------------------------------------------------------

# 3. 已完成：居民基础工作系统

当前 `villager.gd` 已经具有较完整的自动工作状态机。

居民可以执行的核心流程包括：

``` text
寻找资源
↓
移动到资源
↓
采集
↓
返回工作建筑
↓
存入建筑库存
↓
继续工作
```

同时已经存在与据点相关的移动 / 运输状态，因此后续"工作一段时间 →
回据点吃饭休息"应继续扩展现有状态机，而不是另写一套独立移动系统。

### 当前设计原则

`Villager` 负责：

-   工作行为。
-   导航。
-   资源采集。
-   资源运输。
-   职业 / 岗位行为。
-   什么时候需要回据点。
-   吃饭休息后恢复原任务。

`UnitBase` 不负责具体 AI 行为。

------------------------------------------------------------------------

# 4. 已完成：伐木场与资源建筑基础

伐木场已经拥有基本生产逻辑。

### 工人系统

已实现：

-   最大工人数。
-   当前工人列表。
-   判断岗位是否已满。
-   添加工人。
-   移除工人。
-   从居民中寻找空闲单位。
-   居民可以成为伐木工。
-   无业居民可以回据点附近待命。

### 工作范围

已实现工作范围判断，用于限制居民寻找资源的位置。

### 本地库存

伐木场拥有本地木材库存，包括：

-   当前库存。
-   最大容量。
-   剩余容量。
-   是否满仓。
-   存入木材。
-   取出木材。
-   判断是否有木材可运输。

### 当前资源运输设计

``` text
居民砍树
↓
木材送回伐木场
↓
伐木场累计库存
↓
达到需要运输的条件
↓
将木材搬往据点
↓
继续采集
```

目标是避免每砍少量木材就频繁执行：

``` text
树 → 伐木场 → 据点 → 树
```

------------------------------------------------------------------------

# 5. 已完成：建筑 UI 基础系统

当前建筑 UI 已拆分为：

``` text
BuildingPanelBase
└─ ResourceBuildingPanel
```

`BuildingPanelBase` 负责：

-   当前查看建筑。
-   面板打开。
-   面板关闭。
-   从屏幕右侧滑入 / 滑出。
-   关闭按钮。
-   基础刷新接口。

资源建筑面板负责：

-   建筑名称。
-   当前库存 / 最大库存。
-   当前工人数 / 最大工人数。
-   招募。
-   解雇。
-   面板打开期间实时刷新。

后续采石场等资源建筑应尽量复用这一套 UI 架构。

------------------------------------------------------------------------

# 6. 已完成：UnitBase 单位基类

居民当前已经继承：

``` gdscript
UnitBase
```

`UnitBase` 当前统一管理的基础属性包括：

``` text
MAX_HEALTH
HEALTH_REGEN
MOVE_SPEED
FOOD_CONSUMPTION
WORK_SPEED
GATHER_SPEED
ATTACK_DAMAGE
ATTACK_SPEED
```

对应基础值采用：

``` text
base_xxx
```

最终值通过：

``` text
get_stat()
```

统一计算。

例如：

``` text
base_move_speed = 3.0
```

不应该因为 Trait 而直接变成 `3.3`。

真正使用：

``` text
get_move_speed()
```

获得 Trait 修正后的最终值。

------------------------------------------------------------------------

# 7. 已完成：统一属性 Modifier

当前使用：

``` text
StatModifier
```

描述属性修改。

### 修改方式

目前包括：

``` text
ADD
PERCENT
```

例如：

``` text
最大生命 +20
```

使用：

``` text
MAX_HEALTH / ADD / 20
```

例如：

``` text
移动速度 +10%
```

使用：

``` text
MOVE_SPEED / PERCENT / 10
```

### 当前属性公式

当前确定：

``` text
最终值
=
(基础值 + 所有 ADD)
×
(1 + 所有 PERCENT 总和 / 100)
```

百分比先相加，再统一乘算。

------------------------------------------------------------------------

# 8. 已完成：Trait 数据结构

Trait 当前已经拆分为三层：

``` text
TraitData
↓
TraitLevelData
↓
StatModifier
```

## 8.1 TraitData

负责"这个标签是什么"。

当前包含：

-   永久 ID。
-   中文显示名称。
-   描述。
-   ICON。
-   品级。
-   性质。
-   分类。
-   随机权重。
-   等级列表。

### 稳定 ID 规则

例如：

``` text
trait_id   = swift_feet
trait_name = 飞毛腿
文件        = swift_feet.tres
```

设计原则：

-   `trait_id` 是程序、数据库、存档使用的永久身份。
-   创建后原则上不修改。
-   `.tres` 文件名使用 Trait ID。
-   中文名称只负责显示，可以修改。
-   后续存档优先保存 `trait_id + level`，而不是中文名称。

------------------------------------------------------------------------

## 8.2 TraitLevelData

负责某个 Trait 的具体等级。

结构：

``` text
level
modifiers[]
```

例如：

``` text
飞毛腿

Lv.1
└─ MOVE_SPEED / PERCENT / 10

Lv.2
└─ MOVE_SPEED / PERCENT / 20
```

------------------------------------------------------------------------

## 8.3 UnitTrait

负责表示：

> 某一个具体单位拥有哪个 Trait，以及当前是几级。

结构：

``` text
UnitTrait
├─ trait_data
└─ level
```

例如：

``` text
居民 A
└─ UnitTrait
   ├─ trait_data → swift_feet.tres
   └─ level → 1
```

多个单位共享同一个 TraitData，不复制 Trait 数据。

------------------------------------------------------------------------

# 9. 已完成：Trait 实际影响 UnitBase 属性

Trait 已经不只是数据库数据，而是已经接入 `UnitBase.get_stat()`。

当前已经实际测试：

``` text
居民基础移动速度：3.0
Trait：飞毛腿
等级：1
效果：MOVE_SPEED / PERCENT / +10%

最终移动速度：3.3
```

并且居民实际导航移动使用：

``` text
get_move_speed()
```

因此 Trait 的移动速度效果已经进入实际游戏行为。

这条数据链已经验证成功：

``` text
Trait Editor
↓
TraitData
↓
TraitLevelData
↓
StatModifier
↓
UnitTrait
↓
UnitBase.get_stat()
↓
Villager 实际行为
```

------------------------------------------------------------------------

# 10. Trait 分类、性质与品级

## 分类

当前：

``` text
GENERAL
SWORDSMAN
ARCHER
```

用途：

-   `GENERAL`：居民出生通用 Trait。
-   `SWORDSMAN`：剑士职业 Trait。
-   `ARCHER`：弓手职业 Trait。

后续新增职业继续扩展。

## 性质

当前：

``` text
POSITIVE
NEGATIVE
MIXED
```

用于区分：

-   正面 Trait。
-   负面 Trait。
-   同时有优点和缺点的 Trait。

## 品级

当前：

``` text
COMMON
UNCOMMON
RARE
EPIC
LEGENDARY
```

品级主要用于表现稀有程度与玩家获得时的价值感。

非常强力的 Trait 可以通过：

``` text
高品级
+
低 weight
```

控制出现概率。

------------------------------------------------------------------------

# 11. Trait 权重与未来随机生成

每个 Trait 拥有：

``` text
weight
```

用于同一 Trait 池中的加权随机。

例如：

``` text
普通 Trait     weight = 20
稀有 Trait     weight = 5
传奇 Trait     weight = 0.5
```

后续居民出生 Trait 计划：

``` text
第 1 个 Trait：100%
↓
第 2 个 Trait：50%
↓
第 3 个 Trait：10%
```

规则：

-   第一个必定获得。
-   第二个只有在第一个存在后才判定。
-   第三个只有在第二个存在后才判定。
-   至少 1 个。
-   最多 3 个。
-   从 `GENERAL` 池中按 `weight` 抽取。
-   同一居民原则上不重复获得同一个 Trait。

职业训练后，再从对应职业 Trait 池追加职业 Trait。

------------------------------------------------------------------------

# 12. Trait 等级与显示规则

Trait 支持单等级或多等级。

### 单等级 Trait

例如只有 Lv.1：

``` text
飞毛腿
```

UI 中只显示：

``` text
飞毛腿
```

不显示：

``` text
飞毛腿 Lv.1
```

### 多等级 Trait

例如：

``` text
剑术天才 Lv.1
剑术天才 Lv.2
剑术天才 Lv.3
```

UI 中显示实际等级：

``` text
剑术天才 Lv.2
```

### ICON

当前确定：

-   同一个 Trait 所有等级共用一张 ICON。
-   不为每一级重新制作 ICON。
-   后续通过边框、角标、光效等 UI 表现区分等级 / 品级。

这样可以明显减少美术资源数量。

------------------------------------------------------------------------

# 13. 已完成：Trait Editor 编辑器插件

插件目录：

``` text
res://addons/trait_editor/
```

当前已经完成：

-   Trait 数据扫描。
-   Trait 列表。
-   刷新。
-   删除。
-   编辑。
-   保存。
-   中文界面。
-   中文枚举。
-   ICON 选择。
-   Trait 等级编辑。
-   Modifier 编辑。
-   添加等级。
-   添加属性效果。
-   品级筛选。
-   职业 / 分类筛选。
-   Inspector 同步。
-   顶部固定保存按钮。
-   新建 Trait 弹窗。
-   Trait ID 输入。
-   中文名称输入。
-   ID 格式检查。
-   ID 重复检查。
-   自动使用 ID 创建 `.tres`。
-   创建成功自动关闭窗口。
-   右上角关闭按钮可正常关闭。
-   Trait ID 在编辑区域只读显示。
-   ICON 区域增加边缘显示。

当前正式 Trait 示例：

``` text
res://data/traits/swift_feet.tres
```

------------------------------------------------------------------------

# 14. 单位 UI：当前正在开发

UI 已经开始分类：

``` text
UI/
├─ building_panel/
└─ unit_panel/
```

单位 UI 当前已有：

``` text
unit_panel_base.gd
villager_panel.gd
villager_panel.tscn
```

设计目标：

``` text
点击居民
↓
选中单位
↓
右侧滑出 VillagerPanel
↓
查看单位状态
```

玩家**不能直接控制居民**。

点击居民仅用于：

-   查看状态。
-   查看职业。
-   查看生命。
-   查看最终属性。
-   查看 Trait。
-   后续查看工作 / 休息状态。

单位 UI 应与建筑 UI 保持相似的右侧滑入体验。

------------------------------------------------------------------------

# 15. 下一阶段重点：工作 → 吃饭 → 休息循环

这是当前准备开始实现的主要系统。

## 15.1 核心定义

这里暂时不做持续下降的"饥饿条"。

第一版采用：

``` text
工作一段时间
↓
需要休息
↓
返回据点
↓
一次性消耗食物
↓
吃饭
↓
休息一段时间
↓
恢复工作
```

因此：

``` text
FOOD_CONSUMPTION
```

当前定义为：

> **每次回据点吃饭 + 休息所消耗的食物数量。**

不是"每秒食物消耗"。

------------------------------------------------------------------------

## 15.2 准备增加的 UnitBase 属性

计划新增：

``` text
WORK_DURATION
REST_DURATION
```

对应：

``` text
base_work_duration
base_rest_duration
```

含义：

``` text
WORK_DURATION
= 连续工作多久后需要回据点

REST_DURATION
= 吃饭以后需要休息多久
```

这样 Trait 也可以直接修改作息。

例如：

``` text
精力充沛
WORK_DURATION +25%

大胃王
FOOD_CONSUMPTION +50%

浅眠
REST_DURATION -30%

嗜睡
WORK_DURATION -20%
REST_DURATION +40%
```

------------------------------------------------------------------------

## 15.3 职责划分

### UnitBase

只负责：

``` text
基础工作周期
基础食物消耗
基础休息时间
Trait 修正后的最终数值
```

### Villager

负责：

``` text
什么时候正在工作
工作时间累计
什么时候应该返回据点
导航回据点
吃饭
休息
休息结束
恢复原来的工作
```

也就是说：

> **数值属于 UnitBase，行为属于 Villager。**

不要把导航和 AI 状态机塞进 UnitBase。

------------------------------------------------------------------------

# 16. 下一阶段：据点食物库存

当前据点 `Base` 已经有资源逻辑，但食物系统还没有正式接入。

下一步计划让据点拥有：

``` text
wood
food
```

并增加类似：

``` text
has_food(amount)
consume_food(amount)
```

居民到达据点后：

``` text
需要食物 = get_food_consumption()
↓
Base.consume_food(需要食物)
↓
成功
↓
开始休息
```

------------------------------------------------------------------------

# 17. 食物不足时的暂定规则

第一版建议：

``` text
居民工作周期结束
↓
返回据点
↓
食物不足
↓
留在据点等待
↓
不完成本次休息
↓
据点重新有足够食物
↓
吃饭
↓
开始休息
↓
休息完成
↓
恢复工作
```

这样食物不足会真实影响生产：

``` text
粮食不足
↓
居民陆续回据点
↓
越来越多居民等待食物
↓
生产效率下降 / 停摆
```

从而形成：

``` text
人口
↔
食物
↔
生产
```

的基础经营压力。

------------------------------------------------------------------------

# 18. 未来：全局 Modifier / 遗物系统

后续计划加入类似《杀戮尖塔》遗物的全局效果。

原则：

> 遗物不直接遍历居民并硬改属性，而是向统一属性计算系统提供 Modifier。

例如：

``` text
丰收图腾
所有居民 FOOD_CONSUMPTION -10%

工匠工具
所有居民 WORK_SPEED +15%

远征号角
所有战斗单位 ATTACK_DAMAGE +20%
```

后续需要设计统一的：

``` text
GlobalModifier / GlobalEffect
```

数据层。

------------------------------------------------------------------------

# 19. 未来：Boss 全局 Buff / Debuff

Boss 的全局影响与遗物采用相同思想。

例如 Boss 不写：

``` text
找到所有居民
→ 每个人移动速度 -20%
```

而是激活一个数据化效果：

``` text
寒冬诅咒
MOVE_SPEED -20%
WORK_SPEED -15%
```

单位最终属性计算时统一读取。

目标结构：

``` text
基础属性
+
单位 Trait
+
装备
+
玩家遗物
+
Boss Buff / Debuff
+
其他全局效果
=
最终属性
```

这样 Boss 只负责：

``` text
激活 / 关闭某个全局效果
```

不负责具体属性实现。

------------------------------------------------------------------------

# 20. 推荐开发顺序

根据 2026-09-18 当前工程状态，接下来建议按以下顺序推进：

``` text
① StatModifier 增加 WORK_DURATION / REST_DURATION
↓
② UnitBase 增加对应基础属性与 get_xxx()
↓
③ Base 增加食物库存
↓
④ Villager 接入工作时间累计
↓
⑤ Villager 增加回据点吃饭 / 休息状态
↓
⑥ 测试食物不足时等待逻辑
↓
⑦ 完成 VillagerPanel 单位查看 UI
↓
⑧ UI 显示工作 / 休息 / Trait / 最终属性
↓
⑨ TraitManager
↓
⑩ 居民出生随机 GENERAL Trait
↓
⑪ 职业训练与职业 Trait
↓
⑫ 全局 Modifier / 遗物
↓
⑬ Boss 全局 Buff / Debuff
```

------------------------------------------------------------------------

# 21. 当前已经验证通过的关键链路

## 工作链

``` text
居民
→ 找资源
→ 导航
→ 采集
→ 工作建筑
→ 建筑库存
→ 运输 / 据点
```

## 建筑 UI 链

``` text
点击建筑
→ BuildingPanelBase
→ ResourceBuildingPanel
→ 显示库存 / 工人
```

## Trait 数据链

``` text
Trait Editor
→ TraitData
→ TraitLevelData
→ StatModifier
→ .tres
```

## Trait 运行时链

``` text
UnitTrait
→ UnitBase.get_stat()
→ get_move_speed()
→ Villager 实际移动
```

实际测试：

``` text
3.0 基础移动速度
+ 飞毛腿 10%
= 3.3 最终移动速度
```

------------------------------------------------------------------------

# 22. 开发约定

为了避免项目继续扩大后代码越来越难维护，后续尽量遵守以下原则。

### 数据与行为分开

``` text
TraitData
StatModifier
```

描述"是什么"。

``` text
Villager
UnitBase
```

负责运行时行为与计算。

### 基础值与最终值分开

不要让 Trait 直接永久修改：

``` text
base_move_speed
```

统一通过：

``` text
get_move_speed()
get_stat()
```

取得最终值。

### 通用功能放基类

所有单位都有的属性放：

``` text
UnitBase
```

职业专属行为不要全部塞入 `UnitBase`。

### AI 行为留在具体单位

例如：

``` text
砍树
搬运
回据点
吃饭
休息
```

属于居民状态机，而不是基础属性类。

### UI 不承载游戏逻辑

UI 负责：

``` text
读取
显示
发出玩家操作请求
```

实际数据变化由对应系统处理。

### 稳定 ID 不使用中文显示名代替

例如：

``` text
swift_feet
```

是永久身份。

``` text
飞毛腿
```

只是玩家看到的名称。

------------------------------------------------------------------------

# 23. 工程阶段性复查方式

随着系统增加，聊天记录不应该成为唯一的项目状态来源。

建议每完成一批较大的功能后：

``` text
继续开发一段时间
↓
上传当前完整 Godot 工程 ZIP
↓
重新分析实际脚本 / 场景 / 数据
↓
更新 README
↓
再决定下一阶段修改
```

重点复查：

-   是否出现重复系统。
-   某功能是否已经存在但准备重复实现。
-   基类职责是否越来越臃肿。
-   `Villager` 是否需要继续拆分。
-   UI 与游戏逻辑是否混在一起。
-   Trait / Modifier 是否仍保持数据驱动。
-   新职业能否复用现有系统。
-   存档所需稳定 ID 是否完整。
-   全局效果是否可以复用 Modifier。
-   README 与实际工程是否一致。

------------------------------------------------------------------------

# 24. 当前开发位置

截至本次工程审查：

``` text
建筑生产基础       ✅
居民工作基础       ✅
建筑库存           ✅
建筑 UI            ✅
UnitBase            ✅
StatModifier        ✅
TraitData           ✅
TraitLevelData      ✅
UnitTrait           ✅
Trait Editor        ✅
Trait ID            ✅
Trait 等级          ✅
Trait Modifier      ✅
Trait 实际属性生效   ✅

单位查看 UI         🟡 已开始
工作周期            ⏳ 下一步
食物库存            ⏳ 下一步
吃饭 / 休息         ⏳ 下一步
随机出生 Trait      ⏳ 后续
职业 Trait          ⏳ 后续
遗物全局效果         ⏳ 后续
Boss 全局效果       ⏳ 后续
```

------------------------------------------------------------------------

## 下一次继续开发时

优先从：

``` text
StatModifier
+
UnitBase
```

增加：

``` text
WORK_DURATION
REST_DURATION
```

开始。

然后再修改：

``` text
Base
→ food

Villager
→ 工作计时
→ 返回据点
→ 消耗食物
→ 休息
→ 恢复工作
```

这将成为下一阶段的主线。
