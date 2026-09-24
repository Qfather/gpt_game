# gpt_game — 综合开发 ROADMAP

> **版本定位：第一局完整闭环优先**
>
> 本 ROADMAP 基于当前工程已有规划与最近讨论重新整理。
> 当前工程原规划已经明确：Combat V1、Slime/Wolf 已完成；Settlement
> Patrol Ring 与 Raid 已进入实际玩法连接；Feature / Ability / Effect
> 作为扩展接口存在。
>
> 本次新增重点：
>
> 1.  敌人 AI 的最终数据驱动方向；
> 2.  Enemy Behavior / 目标 / 逃跑 / 掠夺 / Base Fallback；
> 3.  编辑器化与 Game Database 的长期方向；
> 4.  布娃娃、技能、事件等长期接口；
> 5.  再次明确：**这些最终构想不能阻塞当前主线。**
>
> ------------------------------------------------------------------------
>
> ## 总原则
>
> **先纵向打穿一局游戏，再横向扩充内容。**
>
> 判断某个新系统现在是否要做：
>
> > 没有这个系统，第一局是否仍然可以从开局一直玩到胜利 / 失败？
>
> 如果答案是“可以”，则先进入长期系统池，不立即展开。

------------------------------------------------------------------------

# 1. 当前已完成框架

``` text
经营
├─ 木材 / 石料采集
├─ 运输 / 仓储
├─ 建造
├─ Farm / Grain
├─ Hunger / Fatigue
└─ 居民自主工作

资源系统
├─ ResourceData
├─ Resource ID
├─ ResourceStorage
├─ ResourceManager
└─ Resource Editor                     ✅

标签 / Trait 基础
├─ UnitBase
├─ TraitData
├─ Stat Modifier
└─ Trait / Tag Editor                  ✅

人口
├─ House
├─ Housing Capacity
├─ Immigration Rules
├─ Immigration Countdown
├─ Arrival Point
└─ Migrant → Villager

军事
├─ Swordsman Training
├─ Barracks
├─ 驻军
├─ 军粮
├─ 休息 / 进食
├─ 自动轮班
└─ Patrol

RTS Camera                             ✅

Combat V1                              ✅
├─ EnemyData / EnemyBase
├─ Health / Damage
├─ Targeting
├─ Enemy Navigation 基础
├─ Swordsman 自动战斗
├─ Patrol → Combat → Patrol
├─ Enemy Death Cleanup
├─ Slime
└─ Wolf

Settlement Patrol Ring V0              ✅
├─ WorldBounds
├─ SettlementBounds
├─ 领地级巡逻路线
└─ Barracks 使用 Settlement 巡逻范围

Feature 扩展接口
├─ FeatureData
├─ FeatureEntry + Chance
├─ AbilityRuntime
└─ Effect 接口
```

原规划已经明确 Slime / Wolf 不应重新制作，Raid 直接使用现有
EnemyData；同时 Feature/Ability/Effect
只作为未来扩展入口。


------------------------------------------------------------------------

# 2. 当前主线：先完成第一局

``` text
已实现
├─ Building Durability / Base Defeat V0
├─ Threat Detection V0
├─ Wall / Gate 基础耐久
├─ Time Rift V0 + 3 波 Wave V0
└─ Elite V0 / Ground Slam
↓
【DONE】关卡事件编辑器与 LevelFlow 收口
├─ 在同一时间线配置 Rift 与支线 Raid
├─ 事件分别保留专属参数与运行机制
└─ 裂缝波数及每波固定单位数量可配置
↓
【DONE】Boss V0：恶魔/蜘蛛裂缝 Boss 与关底事件接入
↓
【DONE】Victory / 第一局完整主线回归验证
↓
第一局完整可玩原型
```

原 ROADMAP 后续主线本身就是 Raid → Threat Detection → 防御 → 时间裂缝 →
Wave → Elite/Ability → Boss →
Victory/Defeat。

------------------------------------------------------------------------

# 3. Raid 当前最低要求

现有剑士已经能够：

``` text
Barracks
↓
自动出营
↓
Settlement Patrol
↓
发现 Enemy
↓
Combat
↓
Enemy 死亡
↓
恢复 Patrol
↓
继续巡逻 / 返回军营
```

因此当前不再重做：

``` text
EnemyBase
Combat
Slime
Wolf
Swordsman Combat
Patrol Combat Resume
```

Raid 只需要继续保证：

``` text
外围生成 Enemy
↓
向 Settlement 推进
↓
被巡逻队截获 → Combat
↓
没被截获 → 继续向 Base 推进
```

------------------------------------------------------------------------

# 4. Enemy AI 最低主线规则

虽然完整 Enemy Behavior System 留到后期，但现在应固定一条底层规则：

> **没有撤退意图的 Hostile
> Enemy，如果没有任何更高优先级的有效目标，最终目标必须是 Base。**

禁止：

``` text
找不到目标
↓
原地站着不动
```

应该：

``` text
寻找当前目标
↓
没有目标
↓
是否应该撤退？
├─ YES → Exit / Retreat
└─ NO
    ↓
   Base
    ↓
   攻击据点
    ↓
   Base 被摧毁
    ↓
   Defeat
```

当前阶段只需要最简单的 Base Fallback。

**不要因此提前制作完整 Behavior Editor。**

------------------------------------------------------------------------

# 5. Enemy Behavior System — 长期正式设计

这是未来所有：

``` text
第三方敌人
时间裂缝敌人
Elite
Boss
召唤物
特殊中立敌对单位
```

共享的行为框架。

## 5.1 主线与支线敌人分层

三方势力的玩法职责固定为：

``` text
Settlement
├─ 发展与防守
├─ 防御 Rift 主线
└─ 处理 Raid 支线压力

Rift
├─ 时间裂缝进入
├─ 推进关卡主线波次
├─ Elite / Boss
└─ 最终 Boss 被击败后才允许 Victory

Raid
├─ 少量单位随机出现
├─ 选择资源建筑或仓储目标
├─ 偷取 / 破坏
├─ 携带战利品撤退
└─ 撤退途中可能被 Rift 拦截
```

Rift 与 Raid 都使用统一的 EnemyData、阵营过滤、索敌和战斗系统，但事件调度彼此独立：Raid 不推进主线，Rift 也不会因为 Raid 事件结束而提前结束主线。

## 5.2 统一敌人事件调度

后续新增 `EncounterDirector` / `LevelFlow`，负责把发展、裂缝、普通波次、袭扰和 Boss 连接成一条可配置流程：

``` text
LevelFlow
├─ Primary Encounters
│  ├─ Rift
│  ├─ Wave
│  ├─ Elite
│  └─ Boss
└─ Secondary Raids
   ├─ RaidGroupData
   ├─ LevelEventEntry（Raid / Rift）
   ├─ 首次时间
   ├─ 随机时间偏移
   ├─ 重复间隔
   └─ 是否允许并发
```

怪物组数据定义袭扰/裂缝阵营来源、固定/随机生成模式、普通/BOSS身份与单位成员；BOSS组的成员必须属于对应阵营且在 EnemyData 中标记为 BOSS。固定模式为每种单位分别配置数量，随机模式用成员概率权重组成事件指定的固定总数。`LevelEventEntry` 引用怪物组并定义出场时间、随机偏移和重复规则；裂缝事件还可配置总波数、波间隔与开启倒计时。运行时仍由 RaidSpawnManager 与 RiftManager 分别执行，编辑器统一呈现与排序。裂缝来源中基础出现时间最晚的 BOSS 事件自动成为关底目标；袭扰 BOSS 不参与该选择。该事件完成后触发胜利；恶魔与蜘蛛裂缝 Boss 基础内容已加入，第一局完整主线流程已由用户实测跑通。

袭扰行为必须是真实状态流转：

``` text
进入领地 → 选择目标 → 偷取 / 破坏 → 携带战利品撤退
                                  ↓
                         遭遇敌对单位 → 战斗 / 改变路线
```

本设计是后续实现目标，当前不视为已完成。

核心定义：

``` text
EnemyData
= 我是谁 / 我的基础数值是什么

BehaviorProfile
= 我来这里想干什么 / 遇到阻拦怎么办 / 什么时候离开

Feature / Ability
= 我有什么特殊能力

Trait
= 我的被动特征是什么
```

------------------------------------------------------------------------

# 6. BehaviorProfile

长期结构：

``` text
BehaviorProfile
│
├─ TargetRules[]
│   ├─ TargetTag
│   ├─ Priority
│   ├─ Action
│   └─ DistanceWeight
│
├─ EncounterRules[]
│   ├─ TargetTag
│   └─ Response
│
├─ ExitRules
│   ├─ ExitType
│   ├─ LootThreshold
│   ├─ HPThreshold
│   └─ Conditions
│
└─ Fallback
    ├─ Target = BASE
    └─ Action = ATTACK
```

------------------------------------------------------------------------

# 7. Enemy Target Rules

目标偏好不能硬编码成：

``` text
if enemy is wolf
if enemy is slime
if enemy is goblin
```

应该数据化。

例如：

## 掠夺者

``` text
RESOURCE_PRODUCER     Priority 100
STORAGE               Priority 90
VILLAGER              Priority 40
MILITARY              Priority 30
BASE                   Fallback
```

目的：

``` text
Farm
LumberCamp
Quarry
Storage
```

以后主要执行：

``` text
STEAL
```

------------------------------------------------------------------------

## 杀戮型

``` text
VILLAGER              Priority 100
MILITARY              Priority 80
BASE                   Fallback
```

例如狼人。

目标是：

``` text
寻找居民
↓
攻击居民
↓
重新寻找
↓
无有效目标
↓
Base
```

------------------------------------------------------------------------

## 破坏者

``` text
DEFENSE_BUILDING      Priority 100
PRODUCTION_BUILDING   Priority 90
OTHER_BUILDING        Priority 80
BASE                   Fallback
```

目的主要是破坏 Settlement。

------------------------------------------------------------------------

# 8. Target Action

“想找谁”与“找到以后做什么”必须分开。

``` text
Target Preference
= 我想找谁

Target Action
= 找到以后我要干什么
```

长期 Action：

``` text
ATTACK
DESTROY
STEAL
IGNORE
SPECIAL
```

例如：

``` text
强盗
Storage → STEAL

破坏者
Storage → DESTROY

狼人
Villager → ATTACK
```

因此相同目标可以产生完全不同的敌人行为。

------------------------------------------------------------------------

# 9. Target Tags

未来建筑与单位逐渐统一目标标签。

例如：

``` text
Farm
├─ BUILDING
├─ PRODUCTION
├─ RESOURCE_PRODUCER
└─ FOOD

LumberCamp
├─ BUILDING
├─ PRODUCTION
├─ RESOURCE_PRODUCER
└─ WOOD

Quarry
├─ BUILDING
├─ PRODUCTION
├─ RESOURCE_PRODUCER
└─ STONE

Barracks
├─ BUILDING
├─ MILITARY
└─ STORAGE

Base
├─ BUILDING
├─ BASE
└─ STORAGE

Villager
├─ UNIT
├─ SETTLEMENT
└─ CIVILIAN

Swordsman
├─ UNIT
├─ SETTLEMENT
└─ MILITARY
```

这样以后新增：

``` text
Fishery
Mine
Bakery
Warehouse
Magic Workshop
```

Enemy AI 不需要新增对应脚本判断。

------------------------------------------------------------------------

# 10. Encounter Response

敌人发现军事单位后不一定全部迎战。

长期支持：

``` text
FIGHT
FLEE
IGNORE
CONDITIONAL
```

例如：

## 狼人

``` text
MILITARY → FIGHT
```

## 小偷

``` text
MILITARY → FLEE
```

## 胆小敌人

``` text
HP > 30% → FIGHT
HP < 30% → FLEE
```

## 群体判断（后期）

``` text
附近敌方军事单位 >= 3
→ FLEE

附近友军 >= 4
→ FIGHT
```

条件编辑器属于后期，不在当前主线实现。

------------------------------------------------------------------------

# 11. Retreat / Exit

逃跑不是 Combat 的特殊补丁，而应该是 Enemy Strategic AI 的正式状态。

``` text
ENTERING
↓
SEEKING
↓
EXECUTING_GOAL
│
├─ Encounter
│    ├─ FIGHT → COMBAT
│    └─ FLEE  → RETREAT
│
└─ Goal Complete
     ↓
   Exit Rule
     ├─ Continue
     └─ RETREAT
```

长期 ExitRule：

``` text
NEVER
LOOT_REACHED
LOW_HP
GOAL_COMPLETED
CONDITION
```

例如盗贼：

``` text
进入 Settlement
↓
偷资源
↓
Loot >= 10
↓
RETREAT
↓
地图边缘
↓
离场
```

或者：

``` text
正在偷资源
↓
发现剑士
↓
FLEE
↓
带着已经偷到的资源逃走
```

------------------------------------------------------------------------

# 12. Strategic Target 与 Combat Target 分离

非常重要。

例如：

``` text
Strategic Target = Farm
```

途中剑士拦截：

``` text
保存 Strategic Context
↓
Combat Target = Swordsman
↓
Combat
↓
战斗结束
↓
原 Farm 仍有效？
├─ YES → 恢复原战略任务
└─ NO  → 重新 Targeting
```

这与现有：

``` text
PATROL
→ COMBAT
→ PATROL
```

采用同样的 Context Interrupt / Resume 思想。

------------------------------------------------------------------------

# 13. Enemy Behavior 当前不做什么

当前只记录，不展开：

``` text
Behavior Editor
复杂 Target Score
复杂距离权重
掠夺资源
偷窃容量
敌人带资源逃跑
复杂 Flee Conditions
群体勇气判断
攻击居民
建筑破坏
多阵营关系
复杂仇恨
```

等第一局需要“敌人之间产生真正行为差异”时再实现 BehaviorProfile V1。

------------------------------------------------------------------------

# 14. Feature System — 长期设计

现有规划已经定义 Feature 方向为 Trait / Ability / Visual，并明确 Ability
可拥有
Trigger、Cooldown、Animation、Audio、VFX、Effects。


长期：

``` text
Feature System
│
├─ Trait
│   ├─ 被动标签
│   └─ Stat Modifier
│
├─ Ability
│   ├─ Trigger
│   ├─ Cooldown
│   ├─ Animation
│   ├─ Audio
│   ├─ VFX
│   └─ Effects
│
└─ Visual Modifier
    ├─ Shader 参数
    ├─ 材质表现
    └─ 特殊视觉状态
```

------------------------------------------------------------------------

# 15. Feature 概率

继续采用：

``` text
FeatureEntry
├─ Feature
├─ Chance
└─ Enabled
```

概率属于配置 Entry，而不是 Feature 自身。

例如：

``` text
Wolf

Melee Attack        100%
Fast                 20%
Large                10%
Ground Slam           5%
Self Destruct         2%
```

同一个技能：

``` text
Ground Slam

普通怪      5%
Elite       40%
Boss       100%
```

现有规划已经采用这一原则。

------------------------------------------------------------------------

# 16. Ability / Effect

长期保持：

``` text
Ability
= 什么时候释放 + 表现 + 调用哪些 Effect

Effect
= 实际发生什么
```

Effect：

``` text
DamageEffect
AreaEffect
KnockbackEffect
StatusEffect
VisualEffect
SpawnEffect
HealEffect
```

例如：

``` text
Ground Slam
↓
AreaEffect
├─ Damage
└─ Knockback
```

``` text
Self Destruct
↓
Visual Modifier
+
AreaEffect
├─ Damage
└─ Knockback
```

``` text
Player Fireball
↓
AreaEffect
├─ Damage
└─ Knockback / Ragdoll
```

Enemy 与 Player 最终复用 Effect
层；这一方向也已经存在于原规划。

------------------------------------------------------------------------

# 17. Ability Runtime

Resource 只保存配置。

``` text
GroundSlam.tres
```

不能保存所有 Enemy 共用的 CD。

每个单位拥有自己的：

``` text
AbilityRuntime
├─ owner
├─ source_data
└─ cooldown_remaining
```

因此：

``` text
Wolf A → CD 8s
Wolf B → CD 0s
```

互不影响。

------------------------------------------------------------------------

# 18. Shader / Animation / Audio / VFX

以后技能配置可以携带：

``` text
Animation
Audio
VFX
Visual Modifier
```

例如自爆：

``` text
Self Destruct
↓
蓄力
↓
Animation
↓
Audio
↓
Shader
├─ crack_amount ↑
└─ emission ↑
↓
Explosion VFX
↓
Area Damage
```

统一材质逐渐支持：

``` text
hit_flash
emission
crack_amount
dissolve
frozen_amount
poison_amount
```

避免为了“自爆版敌人”复制一整套永久材质。原规划已记录这一表现层方向。

------------------------------------------------------------------------

# 19. Ragdoll — 长期系统

用于：

``` text
爆炸
火球
强击退
Boss 技能
```

流程：

``` text
正常 AI / Animation
↓
保存 AI Context
↓
Ragdoll
↓
飞行 / 翻滚 / 落地
↓
检测静止
↓
判断 Front / Back
↓
保存最终 Ragdoll Pose
↓
Root 对齐 Pelvis
↓
Ragdoll Pose → GetUp Start Pose Blend
↓
GetUp_Front / GetUp_Back
↓
恢复 Navigation
↓
恢复之前 AI Context
```

V1 只需要：

``` text
GetUp_Front
GetUp_Back
```

以及约 0.2～0.5 秒的 Pose Blend。

不要求运行时自动生成完整起身动画。

当前不实现 Ragdoll；原规划也把它明确放在 Player Ability
的长期接口之后。

------------------------------------------------------------------------

# 20. Player / King Ability — 长期

“国王”本质上是玩家主动能力载体。

第一版长期目标：

``` text
2 个主动技能槽
```

例如：

``` text
Fireball
↓
点击地面
↓
Projectile / Impact
↓
AreaEffect
├─ Damage
└─ Knockback / Ragdoll
```

与 Enemy Ability 共用 Effect。

------------------------------------------------------------------------

# 21. 数据驱动内容生产

项目最终目标：

``` text
底层代码
= 规则

Resource / Data
= 内容

Editor
= 内容生产工具
```

理想状态：

> 已有规则的不同组合不再修改代码；只有第一次出现全新机制时才扩展代码框架。

流程：

``` text
第一次出现新机制
↓
写一次通用代码
↓
注册为 Data / Effect / Behavior / Feature
↓
Editor 可配置
↓
后续大量内容不再写专属脚本
```

------------------------------------------------------------------------

# 22. 已有编辑器

当前已有：

``` text
Tag / Trait Editor                   ✅
Resource Editor                      ✅
```

这说明项目已经开始从“纯代码开发”向“框架 + 内容生产工具”过渡。

但现在**不因为这个方向正确就停下主线开发一整套后台**。

------------------------------------------------------------------------

# 23. Game Database — 长期编辑器体系

未来可以逐步收敛成统一后台：

``` text
GAME DATABASE
│
├─ Tags
├─ Resources
├─ Buildings
├─ Units / Enemies
├─ Traits
├─ Abilities
├─ Behaviors
├─ Events
└─ Bosses
```

界面概念：

``` text
┌──────────────────────────────────────────┐
│              GAME DATABASE               │
├──────────────┬───────────────────────────┤
│ Tags         │                           │
│ Resources    │  当前数据                 │
│ Buildings    │                           │
│ Units        │  Name: Wolf               │
│ Enemies      │  HP: 100                  │
│ Traits       │  Behavior: Hunter         │
│ Abilities    │  Features: ...            │
│ Behaviors    │                           │
│ Events       │                           │
└──────────────┴───────────────────────────┘
```

------------------------------------------------------------------------

# 24. Enemy / Unit Editor — 后期

当敌人数量开始快速增加时制作。

配置：

``` text
Name
Scene / Model
HP
Damage
Speed
Faction

BehaviorProfile

Features
├─ Trait
├─ Ability
└─ Chance

Animation
Audio
VFX
Loot
```

目标：

``` text
创建新敌人
↓
选择模型
↓
填写数据
↓
选择 Behavior
↓
选择 Feature / Ability
↓
保存 EnemyData
↓
游戏可直接使用
```

避免：

``` text
wolf.gd
slime.gd
goblin.gd
bandit.gd
...
```

------------------------------------------------------------------------

# 25. Building Editor — 后期

当建筑数量增加时制作。

配置：

``` text
Name
Scene
Footprint
Build Time

Durability
├─ Max Health
├─ Damage Profile
└─ Destruction Profile

Build Cost

Workers
├─ Job
└─ Max Workers

Storage

Production

Target Tags
├─ BUILDING
├─ PRODUCTION
├─ RESOURCE_PRODUCER
└─ ...
```

目标是新增：

``` text
Fishery
Mine
Bakery
Warehouse
Blacksmith
Hospital
```

主要通过数据与 Scene，而不是复制大量建筑专属脚本。

------------------------------------------------------------------------

# 26. Feature / Ability Editor — 后期

当 Elite / Boss / Player Ability 真正开始生产时制作。

例如：

``` text
Ground Slam

Trigger:
Nearby Hostiles >= 3

Cooldown:
12

Animation:
A_GroundSlam

Audio:
SFX_GroundSlam

VFX:
Shockwave

Effects:
├─ Area
├─ Damage
└─ Knockback
```

保存后可以赋予多个不同 Enemy。

------------------------------------------------------------------------

# 27. Behavior Editor — 后期

当敌人真正开始出现：

``` text
掠夺者
杀戮型
破坏者
胆小型
不死战型
Boss
```

再制作。

配置：

``` text
Target Rules
Encounter Rules
Exit Rules
Fallback
```

第一版不做复杂条件图编辑器。

------------------------------------------------------------------------

# 28. Adventure / Event Editor — 后期重点

探险小屋 / 远征系统最终高度数据驱动。

事件配置：

``` text
Event
├─ Title
├─ Description
├─ Conditions
├─ Progress Trigger
├─ Choices[]
│   ├─ Cost
│   ├─ Requirements
│   └─ Outcomes[]
│       ├─ Chance
│       ├─ Resource
│       ├─ Injury
│       ├─ Death
│       ├─ New Member
│       └─ Special Effect
└─ Presentation
```

例如：

``` text
森林中的陌生人

选择：救助
Food -5

结果：
70% 新居民 / 剑客加入
20% 无事发生
10% 队员受伤
```

这类系统必须依靠 Editor 才能后期快速生产大量事件内容。

------------------------------------------------------------------------

# 29. 编辑器开发时机

不一次做完所有 Editor。

规则：

> **当某一类内容开始出现大量重复手工配置时，再把它工具化。**

建议时机：

``` text
现在
Tag Editor                         ✅
Resource Editor                    ✅

第一局完整闭环
↓
需要大量 Enemy
→ Enemy Editor

建筑数量明显增加
→ Building Editor

Elite / Boss 技能开始大量制作
→ Ability / Feature Editor

Behavior 类型开始增加
→ Behavior Editor

探险 / 随机事件进入内容生产期
→ Event Editor
```

------------------------------------------------------------------------

# 30. Building Durability / Damage / Repair — 通用建筑基础

本阶段第一次正式引入建筑生命值。不要把生命值、受损与摧毁逻辑只写在 Base 中，而应建立所有可破坏建筑未来都能复用的通用基础。

核心原则：

``` text
Building Gameplay
= 建筑做什么

Durability / Health
= 建筑还能承受多少伤害

Damage Visual
= 建筑受损后看起来怎样

Destruction Visual
= 生命归零后怎样坍塌 / 炸开 / 消失
```

## V0 当前实现

``` text
Building Durability V0
├─ max_health
├─ current_health
├─ take_damage(amount)
├─ repair(amount)
├─ get_health_ratio()
├─ is_destroyed()
├─ health_changed
├─ damage_state_changed
└─ destroyed
```

通用 DamageState 现在就固定接口：

``` text
HEALTHY
DAMAGED
HEAVY_DAMAGED
DESTROYED
```

默认可以先按：

``` text
100% ~ 70%   HEALTHY
< 70%        DAMAGED
< 30%        HEAVY_DAMAGED
0%           DESTROYED
```

阈值未来允许由 BuildingData / DamageProfile 配置。

V0 表现只要求：

``` text
HP > 0
→ 建筑正常存在

HP <= 0
→ destroyed
→ 停止建筑 Gameplay
→ 建筑直接隐藏 / 删除
```

当前不制作模块破损、坍塌、烟火等复杂表现，但必须让表现层以后可以监听 DamageState 与 destroyed，而不用修改耐久底层。

## Base 首个接入

``` text
Enemy 未被巡逻队拦截
↓
没有更高优先级目标
↓
Base Fallback
↓
进入攻击距离
↓
Enemy Attack
↓
Base.take_damage()
↓
Base HP <= 0
↓
DESTROYED
↓
GameState = DEFEAT
```

第一版 Base 需要最简单 HP UI 与失败提示。

## 模块化 Damage Visual — 后期

项目建筑由可复用模块拼装，因此受损表现不需要为整栋建筑重新制作一套完整模型。

未来 DamageProfile 可以根据 DamageState：

``` text
DAMAGED
├─ 隐藏少量正常模块
├─ 替换少量 Damaged 模块
└─ 添加轻微 Smoke / Dust

HEAVY_DAMAGED
├─ 隐藏更多模块
├─ Roof / Wall / Beam 替换为 Broken Variant
├─ 添加 Debris
├─ Smoke
└─ Fire（按建筑类型）

DESTROYED
├─ Gameplay Disabled
├─ 模块小规模坍塌 / 炸开
├─ Dust / Debris VFX
└─ 留残骸或清除
```

模块库长期可以提供：

``` text
Wall_A
Wall_A_Damaged
Wall_A_Broken

Roof_A
Roof_A_Damaged
Roof_A_Broken

Beam_A
Beam_A_Broken
```

同一破损模块可以被 House、Farm、Barracks、Warehouse、LumberCamp 等多种建筑复用。

## Destruction Visual — 后期

耐久系统只发送 destroyed，不负责具体怎么碎。

长期可配置：

``` text
INSTANT
COLLAPSE
EXPLOSION
BURN
DISSOLVE
```

V0 只使用：

``` text
INSTANT
→ 直接消失
```

## Repair System — 已确定规则，当前只预留

**建筑只要不是满血，就存在维修需求。**

维修资源按照“损失生命比例 × 原始建造材料总需求”计算，而不是固定维修价格。

定义：

``` text
missing_ratio = 1.0 - current_health / max_health
```

每种原始建造资源：

``` text
repair_cost(resource)
= build_cost(resource) × missing_ratio
```

例如建筑：

``` text
Build Cost
Wood  = 40
Stone = 20

当前 HP = 60%
缺失 HP = 40%
```

则从 60% 修到满血的理论维修需求：

``` text
Wood  = 40 × 40% = 16
Stone = 20 × 40% = 8
```

实际实现时需要统一整数取整规则，避免免费维修小数资源；该规则在 Repair V1 实现时确定。

维修时间同样按损失比例计算：

``` text
repair_time
= base_build_time × missing_ratio
```

因此损坏越严重，维修资源与维修时间越高。

长期也可以支持“只修一部分”，资源消耗与恢复 HP 按相同比例结算。

## 谁负责维修

维修属于 Settlement 的劳动任务，而不是建筑自动回血。

### 有在职工人的建筑

例如：

``` text
Farm
LumberCamp
Quarry
Workshop
```

建筑受损后：

``` text
HP < Max HP
↓
产生 Repair Job
↓
优先由该建筑在职 Worker 执行维修
↓
需要时暂停 / 降低正常生产
↓
搬运维修材料
↓
前往建筑维修
↓
HP 恢复
↓
回到原 Job
```

具体是“一名工人维修还是多人协作”“生产是否完全暂停”留到 Repair V1 实测后决定。

### 没有生产职工的建筑

例如：

``` text
Base
Barracks
Swordsman Training Building
Wall / Gate
Tower
```

建筑受损后：

``` text
HP < Max HP
↓
产生公共 Repair Job
↓
Settlement 空闲居民领取
↓
搬运维修材料
↓
前往建筑维修
↓
完成后恢复 Idle / 原调度
```

剑士等军事单位不承担普通建筑维修；维修由居民劳动系统负责。

## 维修状态与破损表现联动

以后：

``` text
HEAVY_DAMAGED
↓ Repair
DAMAGED
↓ Repair
HEALTHY
```

DamageVisual 根据状态反向恢复正常模块，因此不需要独立的“修复动画系统”才能完成第一版视觉恢复。

## Repair 当前不实现

本阶段只要求：

``` text
repair(amount) 接口存在
DamageState 可逆
BuildingData 保留 Build Cost / Build Time
未来可从 Build Cost 推导 Repair Cost
```

暂不实现：

``` text
❌ Repair Job 调度
❌ 工人搬维修材料
❌ 在职工人暂停生产维修
❌ 空闲居民公共维修
❌ 模块破损替换
❌ 模块恢复
❌ 坍塌物理
❌ Smoke / Fire / Debris
❌ Repair UI
```

这些进入第一局闭环后的 Building / Repair 扩展阶段。

------------------------------------------------------------------------

# 31. Threat Detection

主线系统。

V0：

``` text
敌人出现
↓
玩家获得大致威胁方向
```

以后：

``` text
无侦察
→ 只知道存在威胁

基础侦察
→ 知道方向

预言塔
→ 知道裂缝位置 / 敌人类型 / 数量 / 时间
```

为玩家提供：

``` text
加固哪边？
把军营建哪里？
在哪修墙？
是否提前布防？
```

------------------------------------------------------------------------

# 32. 城墙 / 城门 / 防御

第一版只做：

``` text
Wall
Gate
Building HP
Enemy 基础攻击建筑
Navigation 处理
```

不要第一版就做复杂攻城器械。

目的：

> 第一次让 Settlement 的空间布局真正影响生存。

------------------------------------------------------------------------

# 33. 时间裂缝 V0

正式敌人主线。

裂缝位置：

``` text
SettlementBounds
↓
向外扩一定距离
↓
合法 Navigation / WorldBounds
↓
随机生成 Rift
```

避免固定出生点。

玩家根据侦察决定：

``` text
修墙
调整防御
加强巡逻
建立防御工事
```

------------------------------------------------------------------------

# 34. Wave V0

时间裂缝：

``` text
出现
↓
倒计时
↓
Wave 1
↓
间隔
↓
Wave 2
↓
...
↓
Boss
```

第一版重点是节奏闭环，不是敌人数量。

------------------------------------------------------------------------

# 35. Elite V0

到这里才第一次正式使用 Ability 系统做一个完整案例。

推荐：

``` text
Ground Slam
```

验证：

``` text
Trigger
Cooldown
Animation
Audio
VFX
AOE
Knockback
```

如果这一个技能能够通过数据赋给不同 Enemy，Ability 框架才算真正验证。

------------------------------------------------------------------------

# 36. Boss V0

Boss：

``` text
EnemyData
+
BehaviorProfile
+
Feature / Ability
+
Boss Phase
+
Global Debuff
```

第一版 Boss 不需要大量技能。

重点：

``` text
有明显威胁
有阶段变化
有全局 Debuff
能够成为一局结束前的高潮
```

------------------------------------------------------------------------

# 37. Victory / Defeat

必须尽早完成第一版。

## Defeat

最简单：

``` text
Base HP <= 0
→ Defeat
```

以后再增加：

``` text
人口全灭
特殊 Boss 条件
事件失败
```

## Victory

第一版：

``` text
最终 Boss 被击败
→ Rift Crisis 结束
→ Victory
```

------------------------------------------------------------------------

# 38. 第一局完整闭环

目标：

``` text
开局
↓
Base
↓
砍树 / 采石
↓
建造
↓
Farm
↓
人口增长
↓
训练 Swordsman
↓
Barracks
↓
自动 Patrol
↓
Raid
↓
Threat
↓
城墙 / 防御
↓
Time Rift
↓
Wave
↓
Elite
↓
Boss
↓
Victory
```

失败路线：

``` text
防御不足
↓
Enemy 突破 Patrol / Defense
↓
没有其他有效战略目标
↓
Base Fallback
↓
攻击 Base
↓
Base Destroyed
↓
Defeat
```

------------------------------------------------------------------------

# 39. 第一局闭环后再扩展的经营内容

``` text
狩猎
↓
Meat

钓鱼
↓
Fish

Farm
↓
Grain
```

然后：

``` text
Grain
Meat
Fish
↓
二级食品
```

居民食物系统：

``` text
Preferred Food
Disliked Food
Neutral Food
```

进食优先：

``` text
喜欢
↓ 没有
普通
↓ 没有
讨厌
```

讨厌食物：

``` text
会吃
但摄入更少 / 满足度更低
```

饥饿：

``` text
正常
↓
红色警告
↓
0
↓
负值
↓
临界值
↓
死亡
```

这些继续作为 Life Simulation 扩展，不阻塞第一局。

------------------------------------------------------------------------

# 40. 人口长期扩展

已有 Immigration 作为基础。

以后：

``` text
住房
粮食
Boss Debuff
Settlement 状态
↓
影响移民条件
```

其他人口渠道：

``` text
救援
随机事件
探险
远征归来
特殊 NPC 加入
```

------------------------------------------------------------------------

# 41. 探险 / 远征长期系统

建筑：

``` text
Adventure Hut
```

流程：

``` text
组建队伍
↓
携带 Food / Equipment
↓
热气球 / 船只离开
↓
Progress
↓
节点事件
↓
资源 / 受伤 / 死亡 / 新成员
↓
任务完成
↓
队伍归来
```

此系统进入开发时优先配套 Event Editor。

------------------------------------------------------------------------

# 42. 长期地图 / 防御扩展

``` text
程序化有限小岛
战争迷雾
预言塔
哨塔
动态 SettlementBounds
多个 Patrol Zone
道路
手推车 / 驮兽
防御工事
更多 Rift 类型
```

V0 当前仍允许固定地图与简单 SettlementBounds。

------------------------------------------------------------------------

# 43. 长期兵种 / 职业

``` text
Swordsman                    ✅

后期：
Archer
Knight
Mage
Guard
Hunter
Fisher
...
```

职业数据化后再考虑：

``` text
CombatRoleData
UnitCombatProfile
```

不要现在重构已经工作的 Swordsman。

------------------------------------------------------------------------

# 44. 内容生产阶段的最终目标

框架稳定后：

``` text
代码开发比例逐渐下降
↓
Data / Resource 配置比例上升
↓
Editor 内容生产比例上升
```

最终开发体验：

``` text
选择模型
↓
填写属性
↓
勾选 Tags
↓
选择 Behavior
↓
选择 Traits
↓
选择 Abilities
↓
设置概率
↓
指定动画 / 音效 / VFX
↓
保存
↓
游戏中出现新内容
```

只有遇到“框架从未支持过的新规则”时才写新代码。

------------------------------------------------------------------------

# 45. 当前明确不要做

``` text
❌ 为每个 Enemy 写独立脚本
❌ 完整 Behavior Editor
❌ 完整 Skill Editor
❌ 完整 Game Database
❌ 复杂掠夺系统
❌ 复杂 Flee AI
❌ Ragdoll
❌ Player Fireball
❌ Self Destruct
❌ Ground Slam（直到 Elite 阶段）
❌ 大量 Boss 技能
❌ 动态领地多边形
❌ 多 Patrol Zone
❌ 完整程序化岛屿
❌ Repair Job / 自动维修调度（当前仅预留）
❌ 模块化破损替换 / 坍塌表现（当前仅预留）
❌ 大量食物
❌ 二级食品
❌ 探险事件内容生产
```

这些不是删除，而是**延后到真正需要它们的阶段**。

------------------------------------------------------------------------

# 46. 当前执行顺序

``` text
1. 【DONE】关卡事件编辑器：完成 Rift / Raid 同时间线编辑及固定数量配置
   ↓
2. 【DONE】Boss V0：接入最终主线事件，击败后结束裂缝危机
   ↓
3. 【DONE】Victory V0：最终 Boss 被击败后胜利
   ↓
4. 【DONE】第一局完整试玩并修复闭环问题
   ↓
5. 根据试玩结果决定 Repair / Editor / 内容扩展优先级
```

------------------------------------------------------------------------

# 47. 第一局完成后的优先判断

第一局完成后不要立刻把所有长期系统全部做出来。

先试玩并回答：

``` text
经营是否太单薄？
→ 食物 / 二级生产

敌人是否太相似？
→ BehaviorProfile

敌人内容生产是否太慢？
→ Enemy Editor

技能制作是否重复？
→ Ability Editor

建筑增加是否麻烦？
→ Building Editor

建筑受损后的恢复是否已经影响经营节奏？
→ Repair V1 / Repair Job / Damage Visual

地图防御是否太简单？
→ Patrol Zone / Tower / Wall 扩展

人口是否太机械？
→ 食物喜好 / Trait / Event

局外内容不足？
→ Adventure / Event Editor

战斗表现不足？
→ Ragdoll / VFX / Shader
```

让实际游戏问题决定工具和系统的开发顺序。

------------------------------------------------------------------------

# 48. 总体架构目标

``` text
                        GAME
                         │
        ┌────────────────┼────────────────┐
        │                │                │
      Runtime          Data            Editor
        │                │                │
  ┌─────┼─────┐    ┌─────┼─────┐    ┌─────┼─────┐
  │     │     │    │     │     │    │     │     │
Economy AI  Combat Enemy Building  Tag  Resource ...
                  │
             Feature
                  │
       ┌──────────┼──────────┐
       │          │          │
     Trait      Ability    Behavior
```

最终原则：

> **Runtime 负责规则。**
> **Data 负责内容。**
> **Editor 负责生产和维护内容。**

但当前阶段仍然只有一个最高优先级：

# **先把第一局完整跑通。**
