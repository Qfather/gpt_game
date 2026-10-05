# Ability Editor V1 — 技能编辑器与通用效果框架

> **当前用途：先搭框架，再在框架上实现正在制作的“击飞”。**
>
> 不再把击飞写成某个敌人、Boss 或技能的专属逻辑。  
> 本轮优先建立 `Ability → Effects[] → 通用 Effect Runtime`
> 的骨架，然后把击飞作为第一个 `ForceEffect` 实例接进去。
>
> 目标不是现在完成全部技能编辑器，而是确保后续伤害、治疗、BUFF/DEBUFF、击退、击飞、布娃娃、法术都可以继续沿用同一套框架。

------------------------------------------------------------------------

# 1. 核心原则

``` text
Ability
= 技能配置

Effect
= 技能实际产生的通用效果

Runtime
= 每个单位自己的运行状态

Presentation
= 动画 / VFX / Audio
```

禁止以后出现：

``` text
GroundSlam.gd
Fireball.gd
BossKnockup.gd
WolfSpecialSkill.gd
```

来分别重复实现相同机制。

正确结构：

``` text
AbilityData
↓
AbilityRuntime
↓
Target / Area / Filter
↓
Effects[]
├─ DamageEffect
├─ HealEffect
├─ StatusEffect
└─ ForceEffect
↓
目标单位已有的通用组件
```

------------------------------------------------------------------------

# 2. Ability V1 总树状结构

``` text
技能 Ability
│
├─ 基础信息
│   ├─ ID
│   ├─ 名称
│   └─ 冷却时间
│
├─ 触发条件 Trigger
│   ├─ 触发类型
│   ├─ 检测范围
│   ├─ 比较条件
│   └─ 条件数值
│
├─ 释放目标 Target
│   └─ 自身 / 单位 / 地面位置
│
├─ 作用范围 Area
│   ├─ 单体 / 圆形
│   └─ 半径
│
├─ 目标过滤 Filter
│   ├─ 阵营关系
│   ├─ 指定阵营
│   ├─ 必须标签
│   └─ 排除标签
│
├─ 施法 Cast
│   ├─ 瞬发
│   ├─ 延迟释放 / 吟唱
│   └─ 持续施法
│
├─ 效果 Effects[]
│   ├─ DamageEffect
│   ├─ HealEffect
│   ├─ StatusEffect
│   └─ ForceEffect
│
└─ 表现 Presentation
    ├─ Animation
    ├─ VFX
    └─ Audio
```

------------------------------------------------------------------------

# 3. V1 枚举

## 3.1 释放目标

``` gdscript
enum CastTargetType {
    SELF,
    UNIT,
    POINT
}
```

中文：

``` text
SELF   → 自身
UNIT   → 单位
POINT  → 地面位置
```

------------------------------------------------------------------------

## 3.2 范围类型

``` gdscript
enum AreaShape {
    SINGLE,
    CIRCLE
}
```

组合关系：

``` text
SELF + CIRCLE
→ 自身为圆心

UNIT + CIRCLE
→ 目标单位为圆心

POINT + CIRCLE
→ 指定地点为圆心
```

V1 不做：

``` text
CONE
LINE
BOX
RING
```

以后需要再增加。

------------------------------------------------------------------------

# 4. 阵营过滤

复用工程现有三阵营：

``` text
我方
袭扰方
裂隙方
```

技能增加关系过滤：

``` gdscript
enum TargetRelation {
    SELF,
    FRIENDLY,
    HOSTILE,
    ANY
}
```

推荐：

``` text
TargetFilter
├─ Relation
├─ AllowedFactions[]
├─ RequiredTags[]
└─ ExcludedTags[]
```

规则：

``` text
AllowedFactions 为空
→ 不限制具体阵营
→ 只按照 Relation 判断

AllowedFactions 有值
→ Relation 判断后
→ 再限制到指定阵营
```

例如普通我方攻击：

``` text
Relation = HOSTILE
Faction = ANY
```

可以攻击：

``` text
袭扰方
裂隙方
```

特殊“裂隙净化”：

``` text
Relation = HOSTILE
AllowedFaction = 裂隙方
```

只影响裂隙阵营。

------------------------------------------------------------------------

# 5. Tag 过滤

Tag 不建立新的固定枚举。

继续复用现有 Tag 系统 / Tag Editor。

例如：

``` text
UNIT
BUILDING
MILITARY
CIVILIAN
BOSS
LARGE
...
```

技能可以配置：

``` text
RequiredTags:
UNIT

ExcludedTags:
BOSS
```

不要写：

``` text
VILLAGER
SWORDSMAN
SLIME
WOLF
```

这种具体单位枚举。

------------------------------------------------------------------------

# 6. 施法方式

只保留三种。

``` gdscript
enum CastMode {
    INSTANT,
    DELAYED,
    CHANNEL
}
```

## INSTANT — 瞬发

``` text
条件满足
↓
立即执行 Effects[]
↓
进入 Cooldown
```

配置：

``` text
Cooldown
```

------------------------------------------------------------------------

## DELAYED — 延迟释放 / 吟唱

``` text
开始施法
↓
等待 CastDuration
↓
执行 Effects[]
↓
进入 Cooldown
```

配置：

``` text
CastDuration
Cooldown
```

主要服务法术特色：

``` text
陨石
大型治疗术
召唤
蓄力魔法
```

------------------------------------------------------------------------

## CHANNEL — 持续施法

``` text
开始持续施法
↓
每 TickInterval
执行 Effects[]
↓
达到 ChannelDuration
↓
结束
↓
进入 Cooldown
```

配置：

``` text
ChannelDuration
TickInterval
Cooldown
```

主要用于：

``` text
持续治疗
暴风雪
火焰雨
毒雾
吸取生命
持续范围 Buff
```

本游戏不加入前摇、后摇、转身、锁方向等复杂战斗参数。

------------------------------------------------------------------------

# 7. Trigger V1

``` gdscript
enum TriggerType {
    ALWAYS,
    TARGET_IN_RANGE,
    ENEMY_COUNT,
    HP_BELOW
}
```

例如：

``` text
普通攻击
→ TARGET_IN_RANGE

踩地
→ ENEMY_COUNT >= 3

残血技能
→ HP_BELOW 30%
```

Trigger 属于“AI 为什么决定释放”。

Behavior 仍然负责：

``` text
这个 Enemy 为什么追这个目标
```

两者不要混合。

------------------------------------------------------------------------

# 8. 数值模式

``` gdscript
enum ValueMode {
    FLAT,
    MAX_HP_PERCENT,
    CURRENT_HP_PERCENT
}
```

例如：

``` text
Damage 30
→ FLAT

造成最大生命 20% 伤害
→ MAX_HP_PERCENT

造成当前生命 10% 伤害
→ CURRENT_HP_PERCENT
```

------------------------------------------------------------------------

# 9. Effects\[\] 是技能系统核心

一个 Ability 可以包含多个 Effect。

``` text
Ability
└─ Effects[]
   ├─ Effect 1
   ├─ Effect 2
   ├─ Effect 3
   └─ ...
```

V1 核心 Effect：

``` text
DamageEffect
HealEffect
StatusEffect
ForceEffect
```

不要把：

``` text
AOE_DAMAGE
AOE_KNOCKUP
FIREBALL
GROUND_SLAM
```

做成 Effect 类型。

AOE 是 Target/Area，效果是 Effect。

------------------------------------------------------------------------

# 10. DamageEffect

配置：

``` text
ValueMode
Value
```

执行：

``` text
Effect Runtime
↓
找到合法目标
↓
目标 Health / Damage 接口
↓
take_damage(value)
```

DamageEffect 不关心：

``` text
技能叫什么
谁释放
是火球还是踩地
```

------------------------------------------------------------------------

# 11. HealEffect

结构与 DamageEffect 类似：

``` text
ValueMode
Value
```

执行：

``` text
目标
↓
Health / Durability
↓
heal(value)
```

后续建筑是否允许某些治疗/维修技能，由 Tag/Faction/目标接口决定。

------------------------------------------------------------------------

# 12. StatusEffect

BUFF 与 DEBUFF 不分成两套底层系统。

统一：

``` text
StatusEffect
└─ StatusData
```

StatusData 长期结构：

``` text
StatusData
├─ ID
├─ Name
├─ Duration
├─ Stack
├─ MaxStacks
├─ TickInterval
├─ Modifiers[]
└─ PeriodicEffects[]
```

例如狂暴：

``` text
Duration = 10

Modifiers:
Damage × 1.5
AttackSpeed × 1.3
MoveSpeed × 1.15
```

例如减速：

``` text
Duration = 5

Modifiers:
MoveSpeed × 0.5
```

例如中毒：

``` text
Duration = 10
TickInterval = 1

PeriodicEffects:
Damage 5
```

本阶段可以只定义接口，不需要马上完整实现 Status。

------------------------------------------------------------------------

# 13. ForceEffect — 当前击飞必须从这里实现

这是客户端当前工作的重点。

**不要继续把击飞写成独立技能逻辑。**

先建立：

``` text
EffectBase
↓
ForceEffect
```

ForceEffect V1 建议参数：

``` text
HorizontalForce
VerticalForce
UseRagdoll
```

可选预留：

``` text
ForceOrigin
```

V1 可以默认：

``` text
从技能作用中心向目标施力
```

------------------------------------------------------------------------

# 14. ForceEffect 组合结果

## 击退

``` text
HorizontalForce = 8
VerticalForce = 0
UseRagdoll = false
```

结果：

``` text
目标水平向外移动
```

------------------------------------------------------------------------

## 击飞

``` text
HorizontalForce = 2
VerticalForce = 10
UseRagdoll = false
```

结果：

``` text
目标主要向上飞起
```

**当前正在制作的击飞，应迁移/实现为这个配置。**

------------------------------------------------------------------------

## 爆炸炸飞

``` text
HorizontalForce = 10
VerticalForce = 7
UseRagdoll = true
```

结果：

``` text
目标受到冲量
↓
进入 Ragdoll
↓
飞出
↓
落地
↓
恢复
```

Ragdoll 当前未完成时：

``` text
UseRagdoll = false
```

先让 ForceEffect 本身正确工作。

------------------------------------------------------------------------

# 15. Ragdoll 不属于 Ability

边界必须固定：

``` text
Ability
↓
ForceEffect
↓
请求目标受到力
↓
如果 UseRagdoll
↓
RagdollComponent
```

RagdollComponent 长期负责：

``` text
正常动画
↓
切换物理骨骼
↓
飞行 / 翻滚
↓
落地
↓
检测稳定
↓
保存最终 Pose
↓
匹配 GetUp 起始姿势
↓
起身动画
↓
恢复 Navigation / AI
↓
恢复之前任务
```

Ability 不实现这些内容。

这样以后：

``` text
火球
爆炸桶
建筑坍塌
陷阱
Boss技能
```

都可以调用同一个 Ragdoll 系统。

------------------------------------------------------------------------

# 16. Presentation

AbilityData 预留：

``` text
Animation
VFX
Audio
```

建议至少区分：

``` text
Cast Animation
Cast VFX
Impact VFX
Audio
```

但 V1 可以先保持简单。

表现层不负责 Damage / Force 等 Gameplay 结果。

------------------------------------------------------------------------

# 17. 推荐 Resource 结构

可按当前工程命名习惯调整，不要求完全照搬文件名。

``` text
AbilityData
│
├─ basic
├─ trigger
├─ target
├─ area
├─ filter
├─ cast
├─ effects[]
└─ presentation
```

Effect：

``` text
EffectData
├─ DamageEffectData
├─ HealEffectData
├─ StatusEffectData
└─ ForceEffectData
```

运行时：

``` text
AbilityRuntime
├─ owner
├─ source_data
├─ cooldown_remaining
└─ cast/channel runtime state
```

非常重要：

> `.tres` Resource 只保存配置，不保存某个单位自己的 CD。

例如：

``` text
Wolf A
GroundSlam CD = 8

Wolf B
GroundSlam CD = 0
```

必须互不影响。

------------------------------------------------------------------------

# 18. 推荐运行流程

``` text
单位拥有 AbilityData
↓
AbilityRuntime
↓
Cooldown Ready?
↓
Trigger 是否满足？
↓
确定 Cast Target
↓
CastMode
│
├─ INSTANT
│   └─ 立即继续
│
├─ DELAYED
│   └─ 等待 CastDuration
│
└─ CHANNEL
    └─ 按 TickInterval 周期执行
↓
根据 Area 找候选目标
↓
TargetFilter
├─ Relation
├─ Faction
└─ Tags
↓
得到最终 Targets[]
↓
逐个执行 Effects[]
↓
Cooldown
```

------------------------------------------------------------------------

# 19. 当前先实现的最小框架

客户端现在正在做击飞，因此本轮建议按以下顺序：

``` text
1. AbilityData 基础 Resource
↓
2. EffectData / EffectBase
↓
3. ForceEffectData
↓
4. AbilityRuntime 最小执行入口
↓
5. Target = SELF / UNIT
↓
6. Area = SINGLE / CIRCLE
↓
7. TargetFilter 接入现有 Faction
↓
8. ForceEffect Runtime
↓
9. 把当前击飞迁移到 ForceEffect
↓
10. 用测试 AbilityData 配出击飞
```

这轮**不需要为了搭框架把所有 Effect 全部实现**。

------------------------------------------------------------------------

# 20. 当前第一个测试技能：击飞测试

建立测试配置：

``` text
Ability: Test_KnockUp

CastMode:
INSTANT

Target:
SELF

Area:
CIRCLE

Radius:
4

Relation:
HOSTILE

Faction:
ANY

RequiredTags:
UNIT

Effects:
└─ ForceEffect
   ├─ HorizontalForce = 2
   ├─ VerticalForce = 10
   └─ UseRagdoll = false
```

测试：

``` text
释放技能
↓
搜索自身 4m
↓
过滤敌对单位
↓
找到合法目标
↓
ForceEffect
↓
目标被击飞
```

如果当前阵营关系尚未完全支持
`HOSTILE`，可以先直接用现有三阵营过滤完成测试，但不要把具体阵营写死进
ForceEffect。

------------------------------------------------------------------------

# 21. 第二个测试：伤害 + 击飞组合

ForceEffect 成功后，再实现最简单 DamageEffect。

配置：

``` text
Ability: Test_GroundSlam

CastMode:
INSTANT

Target:
SELF

Area:
CIRCLE
Radius:
4

Relation:
HOSTILE

Effects:
├─ DamageEffect
│  └─ Damage = 30
│
└─ ForceEffect
   ├─ Horizontal = 5
   ├─ Vertical = 8
   └─ Ragdoll = false
```

验收：

``` text
同一次 Ability
↓
同一批合法目标
↓
Damage
+
KnockUp
```

如果这一点成立，就证明：

> `Effects[]` 多效果组合框架已经成立。

------------------------------------------------------------------------

# 22. 第三个测试：三阵营过滤

至少测试：

``` text
场上：
我方 A
袭扰方 B
裂隙方 C
```

我方释放：

``` text
Relation = HOSTILE
```

应能影响：

``` text
B
C
```

不能影响：

``` text
A
```

然后配置：

``` text
AllowedFaction = RIFT
```

应只影响：

``` text
C
```

这一测试能确认 Ability 没有把“敌人”写死成某个阵营。

------------------------------------------------------------------------

# 23. Ability Editor UI — 先搭配置页骨架

如果本轮顺手建立 Editor，先做最低版本：

``` text
┌─────────────────────────────────┐
│ 技能编辑器 Ability Editor       │
├─────────────────────────────────┤
│ 基础                            │
│ 名称                            │
│ 冷却                            │
│                                 │
│ 触发                            │
│ [Trigger Type ▼]                │
│                                 │
│ 目标                            │
│ [Target Type ▼]                 │
│ [Area Shape ▼]                  │
│ Radius                          │
│                                 │
│ 过滤                            │
│ [Relation ▼]                    │
│ Factions                        │
│ Required Tags                   │
│ Excluded Tags                   │
│                                 │
│ 施法                            │
│ [INSTANT / DELAYED / CHANNEL ▼] │
│                                 │
│ Effects                         │
│ ├─ ForceEffect                  │
│ │  Horizontal                   │
│ │  Vertical                     │
│ │  Ragdoll                      │
│ │                               │
│ └─ [+ Add Effect]               │
│                                 │
│ 表现                            │
│ Animation                       │
│ VFX                             │
│ Audio                           │
└─────────────────────────────────┘
```

编辑器只负责创建/修改 Ability Resource。

Gameplay Runtime 不依赖 Editor。

------------------------------------------------------------------------

# 24. Editor 动态字段

根据选择显示对应字段。

例如：

``` text
CastMode = INSTANT
→ 不显示时间参数

CastMode = DELAYED
→ 显示 CastDuration

CastMode = CHANNEL
→ 显示 ChannelDuration
→ 显示 TickInterval
```

Area：

``` text
SINGLE
→ 隐藏 Radius

CIRCLE
→ 显示 Radius
```

Effect：

``` text
ForceEffect
→ HorizontalForce
→ VerticalForce
→ UseRagdoll

DamageEffect
→ ValueMode
→ Value
```

避免一个页面同时显示大量无关参数。

------------------------------------------------------------------------

# 25. 后续扩展方式

以后如果需要：

``` text
扇形攻击
```

不是新增技能脚本，而是：

``` text
AreaShape += CONE
```

需要：

``` text
召唤
```

增加：

``` text
SpawnEffect
```

需要：

``` text
传送
```

增加：

``` text
TeleportEffect
```

需要：

``` text
眩晕
```

优先：

``` text
StatusData = Stun
```

需要：

``` text
布娃娃
```

扩展独立：

``` text
RagdollComponent
```

Ability 框架本身不需要推翻。

------------------------------------------------------------------------

# 26. 当前不要实现

``` text
❌ 完整 Status 系统
❌ 全部 BUFF / DEBUFF
❌ Ragdoll Recovery
❌ 起身动画系统
❌ CONE / LINE / BOX / RING
❌ Projectile 通用系统
❌ SpawnEffect
❌ TeleportEffect
❌ 复杂 Trigger 条件树
❌ 技能连招
❌ 转身 / 锁方向
❌ 前摇 / 后摇
❌ 技能树
❌ 技能升级系统
```

先确保：

``` text
Ability
↓
Area / Filter
↓
Effects[]
↓
ForceEffect
↓
击飞
```

这条链成立。

------------------------------------------------------------------------

# 27. 当前客户端执行顺序

``` text
【STEP 1】
检查当前击飞代码
不要继续写成专属逻辑

↓

【STEP 2】
建立 AbilityData

↓

【STEP 3】
建立 Effect 基类 / 数据接口

↓

【STEP 4】
建立 ForceEffect

↓

【STEP 5】
把现有击飞逻辑迁入 ForceEffect Runtime

↓

【STEP 6】
建立 Test_KnockUp Ability Resource

↓

【STEP 7】
用 AbilityRuntime 执行它

↓

【STEP 8】
接入现有 Faction / Tag 过滤

↓

【STEP 9】
验证圆形 AOE 击飞

↓

【STEP 10】
再补 DamageEffect

↓

【STEP 11】
验证 GroundSlam =
DamageEffect + ForceEffect
```

------------------------------------------------------------------------

# 28. 本阶段验收标准

必须做到：

``` text
同一个 ForceEffect 代码
```

可以仅通过参数配出：

``` text
普通击退
水平高 / 垂直低

击飞
水平低 / 垂直高

爆炸冲击
水平高 / 垂直高
```

并且：

``` text
Ability A
Effects:
Force

Ability B
Effects:
Damage + Force
```

不需要修改 ForceEffect 源码。

同时三阵营与 Tag Filter 正常工作。

达到这里，技能框架第一阶段成立。

------------------------------------------------------------------------

# 29. 与当前主线的关系

这次之所以允许提前搭 Ability
框架，是因为客户端**当前已经正在制作击飞**。

既然击飞未来必然属于通用技能 Effect：

> 与其现在写一套临时代码，之后 Elite / Boss 阶段再重构，不如现在只搭最小
> Ability/Effect 骨架，让当前击飞直接成为第一个通用 ForceEffect。

但仍然禁止借此提前展开完整技能系统。

完成：

``` text
AbilityData
EffectBase
ForceEffect
基础 Area / Filter
测试击飞
```

后，应继续回到当前主线：

``` text
Building Durability
↓
Base Defeat
↓
Threat Detection
↓
Wall / Gate
↓
Time Rift
↓
Wave
↓
Elite + Ability 正式扩展
```

------------------------------------------------------------------------

# 30. 最终原则

``` text
技能负责：
何时释放
↓
在哪里释放
↓
影响哪些目标
↓
调用哪些效果

Effect负责：
实际发生什么

组件负责：
目标如何完成具体行为
```

例如：

``` text
Ground Slam
↓
DamageEffect
+
ForceEffect
↓
HealthComponent.take_damage()
+
Unit Force / Ragdoll 接口
```

因此：

> **击飞不是一个“技能系统特例”，而应该成为 Ability Editor
> 框架中的第一个通用 ForceEffect。**
