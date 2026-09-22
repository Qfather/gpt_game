# 下一阶段开发计划 — 最新工程收口、Feature 接口预留与第三方袭扰 V0

> **基准工程：当前上传的 `gpt-时间裂缝(7).zip` / GitHub 工程。**
>
> 已确认当前工程中 **Slime 与 Wolf 已经完成**，Combat V1 的“第二种
> EnemyData 验证”也已经完成。  
> 本计划**禁止重新制作 Slime / Wolf，禁止重写已经跑通的 Combat V1**。
>
> 本轮目的：
>
> 1.  让 README / ROADMAP 与当前真实工程同步；
> 2.  收口少量会影响后续扩展的 Combat 技术债；
> 3.  为 Trait / Ability / Visual / Effect 预留统一 Feature 扩展接口；
> 4.  不提前制作完整技能编辑器；
> 5.  直接让**现有 Slime / Wolf**进入第一版真实第三方袭扰玩法。
>
> 开发纪律：**每完成一个阶段立即停止 → 用户测试 →
> 用户确认后再进入下一阶段。**

------------------------------------------------------------------------

# 0. 当前真实进度（README / ROADMAP 必须以此为准）

``` text
基础经营循环                         ✅
├─ 木材 / 石料采集
├─ 资源运输 / 本地库存 / Base 库存
├─ 建造 / 工地物流 / 多人施工
├─ Farm / GRAIN
├─ Hunger / Fatigue
└─ 居民自主任务

资源系统 V2                         ✅
├─ ResourceData
├─ Resource ID
├─ ResourceStorage
├─ ResourceManager
└─ Resource Editor

Trait 基础系统                      ✅
├─ UnitBase
├─ TraitData
├─ Stat Modifier
└─ Trait Editor

Population V1                       ✅
├─ House
├─ Housing Capacity
├─ ImmigrationRules
├─ Immigration Countdown
├─ ArrivalPoint
├─ Migrant
└─ Migrant → Villager

Military Daily Loop                ✅
├─ CombatRole / SWORDSMAN
├─ 剑士训练
└─ Villager → Swordsman

Barracks / Patrol V0               ✅
├─ Capacity = 6
├─ 自动驻扎
├─ 驻军隐藏
├─ ceil(Garrison / 2) 轮班
├─ 门口集合
├─ 自动巡逻
├─ 返回军营
└─ 循环换班

Barracks Logistics V1              ✅
├─ 军粮库存
├─ 军营内部进食
├─ 军营内部休息
├─ 战备状态维护
├─ 军粮不足自动补给
├─ 驻军真实搬粮
└─ Patrol 前状态检查

RTS Camera V1                      ✅

Combat V1                          ✅
├─ EnemyData
├─ EnemyBase
├─ Health / Damage
├─ Faction 基础判断
├─ Enemy Targeting
├─ Enemy 追击 / 近战
├─ Swordsman 自动索敌 / 战斗
├─ Combat → Patrol 恢复
├─ SlimeData                       ✅
├─ WolfData                        ✅
└─ 第二种数据驱动 Enemy 验证       ✅
```

------------------------------------------------------------------------

# 1. 阶段 1 — 先修 README / ROADMAP

## README

当前 README 顶部仍写：

``` text
当前：Military Daily Loop V1（规划中）
```

这已经明显落后。

改为：

``` text
当前开发节点：
Combat V1 已完成
→ 地图边界 / 据点领地范围 / Settlement Patrol Ring V0
→ Combat 收口 / Feature 接口预留
→ Third-party Raid V0
```

README 顶部“已经完成”增加：

``` text
Military Daily Loop               ✅
Barracks / Patrol V0              ✅
Barracks Logistics V1             ✅
RTS Camera V1                     ✅
Combat V1                         ✅
Slime / Wolf                      ✅
```

旧的 Population
阶段流水账可以继续保留作为开发记录，但不要再让它表现成“当前开发节点”。

------------------------------------------------------------------------

## ROADMAP

当前 ROADMAP 仍写：

``` text
【CURRENT】
Combat V1
```

必须改成：

``` text
Combat V1                         ✅

【CURRENT】
地图边界 + Settlement Patrol Ring V0
↓
Combat 收口 + Feature 接口预留
↓
Third-party Raid V0
↓
Threat Detection
↓
第三方敌人攻击经济目标
↓
城墙 / 防御
↓
时间裂缝
↓
Wave
↓
Elite / Ability
↓
Boss
↓
Victory / Defeat
```

ROADMAP 中：

``` text
SlimeData
WolfData
```

全部标记为已完成。

**不得把 Slime / Wolf 再列为待开发敌人。**

------------------------------------------------------------------------

# 2. ROADMAP 新增：Feature System 长期架构

将以下内容加入长期 ROADMAP，但本轮只实现最小接口。

``` text
Feature System
│
├─ Trait
│  ├─ 被动标签
│  └─ 基础属性 Modifier
│
├─ Ability
│  ├─ Trigger
│  ├─ Cooldown
│  ├─ Animation
│  ├─ Audio
│  ├─ VFX
│  └─ Effects
│
└─ Visual Modifier
   ├─ Shader 参数
   ├─ 材质表现
   └─ 特殊视觉状态
```

未来可用于：

``` text
Villager
Swordsman
Enemy
Elite
Boss
Player / King
```

------------------------------------------------------------------------

# 3. Feature 概率配置

Enemy 配置未来支持：

``` text
FeatureEntry
├─ Feature
├─ Chance
└─ Enabled
```

例如：

``` text
WolfData

Melee Attack       100%
Fast                20%
Large               10%
Ground Slam          5%
Self Destruct        2%
```

注意：

> **概率属于 EnemyData 中的 FeatureEntry，不属于 Feature 本身。**

所以同一个：

``` text
Ground Slam
```

可以：

``` text
普通敌人       5%
Elite         40%
Boss         100%
```

------------------------------------------------------------------------

# 4. 当前工程需要收口的技术点

这里只处理会影响下一阶段的内容。

## 4.1 Enemy 死亡生命周期

检查 Enemy 死亡后是否最终：

``` text
停止 AI
↓
关闭碰撞
↓
死亡表现
↓
从注册列表 / Group 注销
↓
queue_free()
```

如果目前只是：

``` text
hide()
```

则补齐最终释放。

原因：

> Third-party Raid 开始以后会持续产生 Enemy，死亡节点不能永久留在
> SceneTree。

### 测试

连续生成并击杀多批现有：

``` text
Slime
Wolf
```

确认死亡实体不会持续累积。

------------------------------------------------------------------------

## 4.2 Faction 独立化

如果当前全局阵营定义仍依赖：

``` text
EnemyData.Faction
```

则抽成独立统一定义：

``` text
Faction

SETTLEMENT
HOSTILE
NEUTRAL
```

Enemy / Unit 都引用同一个 Faction。

本轮不做复杂外交矩阵。

------------------------------------------------------------------------

## 4.3 Combat Resume 再检查

重点验证：

``` text
PATROL
→ COMBAT
→ PATROL
```

已经正常。

同时检查普通居民/单位任务如果允许进入 Combat：

``` text
运输
施工
移动
↓
Combat Interrupt
↓
战斗结束
↓
原 Task 仍有效？
├─ YES → 恢复
└─ NO  → 正常重新调度
```

不要为了这个写大量：

``` text
if state == ...
```

优先保留/完善统一的：

``` text
CombatContext
```

如果当前只有 Swordsman 会参与
Combat，则至少保证军事任务恢复正确，并把普通任务恢复接口预留好。

------------------------------------------------------------------------

## 4.4 Enemy Navigation

现有 Slime / Wolf 已经能战斗，因此**不重新做 Enemy AI**。

但 Third-party Raid 会要求 Enemy 从外围走向 Settlement。

检查现有 Enemy 追踪是否真正通过：

``` text
NavigationAgent3D
```

如果仍然主要是：

``` text
direction_to()
→ move_and_slide()
```

则在 Raid V0 接入 NavigationAgent。

目标只是：

``` text
能绕过普通建筑 / 障碍
```

本轮不做：

``` text
城墙破坏
攻城寻路
门优先级
复杂 Path Cost
```

------------------------------------------------------------------------

# 5. 阶段 2 — FeatureData / FeatureEntry 最小接口

> 不制作 Ground Slam，不制作技能编辑器。

建议新增：

``` text
FeatureData
```

只保存 Feature 的通用身份：

``` text
feature_id
display_name
description
feature_kind
```

`feature_kind` 可以先有：

``` text
TRAIT
ABILITY
VISUAL
```

------------------------------------------------------------------------

## FeatureEntry

``` text
FeatureEntry

feature
chance = 1.0
enabled = true
```

EnemyData 增加：

``` text
features[]
```

Enemy 生成时：

``` text
EnemyData
↓
Roll FeatureEntry
↓
Runtime Features
↓
Apply
```

### 第一版测试

测试 EnemyData：

``` text
Feature A = 100%
Feature B = 0%
```

生成 10 次：

``` text
A 每次都有
B 每次都没有
```

确认现有：

``` text
Slime
Wolf
Combat
```

完全不受影响。

**完成后停止。**

------------------------------------------------------------------------

# 6. 阶段 3 — 与现有 Trait / EnemyAbility 接口兼容

不要删除或重写：

``` text
TraitData
Trait Editor
EnemyAbility
```

长期关系定义为：

``` text
Feature
├─ TraitData
├─ AbilityData / EnemyAbility
└─ Visual Feature
```

本轮可以通过：

``` text
基类
接口
适配器
```

中的最简单方案兼容。

目标：

> 后期 Trait、敌人技能、Boss 技能可以在同一“Feature
> 列表”中配置，但内部仍各自负责自己的逻辑。

不要为了统一架构重写现有 Trait Editor。

------------------------------------------------------------------------

# 7. 阶段 4 — Ability Runtime 接口预留

当前已有 EnemyAbility 基础接口。

本阶段只确保未来能够安全支持：

``` text
Trigger
Cooldown
Animation
Audio
VFX
Effect
```

## 最重要的规则

共享 Resource：

``` text
GroundSlam.tres
```

只能保存配置。

每个 Enemy 必须拥有自己的：

``` text
AbilityRuntime
```

例如：

``` text
Wolf A
GroundSlam CD = 8s

Wolf B
GroundSlam CD = 0s
```

绝不能因为共用一个 `.tres` 导致所有单位共享 CD。

### 本阶段测试

两个单位引用同一个 Ability Resource。

确认：

``` text
Runtime 状态互相独立
```

暂时不需要真的释放技能。

------------------------------------------------------------------------

# 8. 阶段 5 — Effect 接口预留

未来 Ability 不应该各自重复实现伤害。

预留：

``` text
Effect
├─ DamageEffect
├─ AreaEffect
├─ KnockbackEffect
├─ StatusEffect
└─ VisualEffect
```

本轮可以只建立基础接口。

未来：

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

Enemy Ability 与 Player Ability 最终复用同一 Effect 层。

------------------------------------------------------------------------

# 9. Shader / Animation / Audio / VFX 接口方向

只写进 ROADMAP，本轮不实现完整系统。

## Ground Slam

``` text
Trigger:
周围 Hostile >= 3

Cooldown:
12s

Presentation:
Animation
Audio
VFX

Effects:
AOE Damage
Knockback
```

------------------------------------------------------------------------

## Self Destruct

``` text
Trigger
↓
开始蓄力
↓
Animation
Audio
↓
Shader Modifier
crack_amount ↑
emission ↑
↓
VFX
↓
Explosion
```

不要为“自爆史莱姆”复制整套永久材质。

未来统一材质尽量支持：

``` text
hit_flash
emission
crack_amount
dissolve
frozen_amount
poison_amount
```

Feature / Ability 驱动这些参数。

------------------------------------------------------------------------

# 10. Player / King Ability 长期接口

玩家未来拥有：

``` text
2 个主动技能槽
```

例如：

``` text
Fireball
↓
玩家点击地面
↓
Projectile / Impact
↓
AreaEffect
├─ Damage
└─ Knockback
```

以后增加 Ragdoll：

``` text
Enemy AI Context
↓
Ragdoll Interrupt
↓
炸飞
↓
落地
↓
Recover
↓
恢复之前 AI Context
```

这与现有：

``` text
PATROL
→ COMBAT
→ PATROL
```

采用同样的“中断 → 恢复 Context”思想。

本轮不做 Player Ability 和 Ragdoll。

------------------------------------------------------------------------

# 11. 阶段 6 — Debug / 工程清理

保留现有 Combat 调试工具，但增加统一开关。

例如：

``` text
DEBUG_COMBAT_VISUALS
```

控制：

``` text
Aggro Range
调试圆环
Combat Debug Print
测试 Spawn UI
```

正式试玩时可以关闭。

------------------------------------------------------------------------

## `.tmp` 文件

检查工程中的 Godot 临时 Scene 文件。

确认未被正式场景引用后：

``` text
删除残留
```

并根据实际情况加入 `.gitignore`。

不要误删正式 `.tscn`。

------------------------------------------------------------------------

# 12. 阶段 7 — Settlement Patrol Ring V0

> 先建立领地级巡逻范围，再进入 Third-party Raid V0。当前军营巡逻点仍然是以军营为中心的固定局部坐标，不能直接承担整个领地的防卫。

## 目标

让巡逻范围从“军营周边”升级为“据点领地”。

第一版继续使用当前正方形固定地图，不制作程序化地形。

需要建立两个明确范围：

``` text
WorldBounds
└─ 整张地图的可玩边界

SettlementBounds
└─ Base 当前领地范围
```

巡逻环：

``` text
SettlementBounds
↓
生成 4 个有顺序的巡逻点
↓
投射到 NavigationMesh
↓
避开树木、建筑和地图边缘
↓
所有军营共享领地巡逻环
```

基本要求：

- 巡逻点不再使用 Barracks 周围的固定局部偏移；
- 巡逻顺序固定为 `0 → 1 → 2 → 3`；
- 多个剑士可以使用同一组领地点，但保留路线起点或轻微偏移差异；
- 地图边界、领地范围和巡逻点都使用相对场景数据，不写死电脑绝对路径；
- 第一版不做地形程序化生成、不做动态势力扩张。

## 阶段测试

确认：

- 巡逻点覆盖 Base 周边领地，而不是只在军营附近；
- 剑士可以按 `0 → 1 → 2 → 3` 完整巡逻并返回军营；
- 巡逻点不会落在建筑、树木或 NavigationMesh 外；
- 建造更多建筑后，巡逻环仍然可用；
- 军粮、轮班、战斗恢复逻辑不受影响。

**完成后停止。**

------------------------------------------------------------------------

# 13. 阶段 8 — Third-party Raid V0

> **直接使用已经完成的 Slime / Wolf。**
>
> 不创建新的 `SlimeData`、`WolfData`，不创建 `slime.gd`、`wolf.gd`。

## 目标

让现有测试敌人第一次成为真实地图威胁。

``` text
地图外围
↓
Raid Spawn
↓
生成现有 Slime / Wolf
↓
向 Settlement 方向活动
↓
巡逻队发现
↓
自动 Combat
↓
Enemy 死亡
↓
Swordsman 恢复 Patrol
```

------------------------------------------------------------------------

## Raid V0 暂时非常简单

第一版：

``` text
Raid
├─ 2～4 个 Enemy
├─ 从地图外围合法位置出现
├─ Slime / Wolf 随机组合
└─ 一次只测试一批
```

暂时不做复杂 Wave Director。

------------------------------------------------------------------------

# 14. Raid Spawn

建立简单：

``` text
RaidSpawnManager
```

职责：

``` text
寻找地图外围合法 Spawn Point
↓
选择 EnemyData
↓
实例化 EnemyBase
↓
赋予已有 SlimeData / WolfData
```

Spawn Point 必须：

``` text
在 Navigation 可达区域
不在建筑内部
不在 Base 正中心
不直接出生在巡逻队脸上
```

第一版可以使用预设外围 SpawnPoint 节点。

以后再程序化。

------------------------------------------------------------------------

# 15. Raid Enemy 的初始战略目标

当前 Enemy 已经能战斗，但 Raid Enemy 在没有 Swordsman
时也需要知道往哪里走。

V0 先定义：

``` text
Raid Destination = Settlement / Base 周边
```

敌人：

``` text
外围生成
↓
向 Settlement 移动
↓
途中发现 Settlement 战斗单位
↓
进入 Combat
```

第一版还不攻击：

``` text
Villager
Farm
LumberCamp
Storage
Base
```

这些放下一阶段。

这样可以先证明 Raid + Patrol 的关系。

------------------------------------------------------------------------

# 16. Raid V0 与巡逻的第一次玩法连接

最终测试画面：

``` text
玩家正常经营
↓
军营自动派出 3 名剑士
↓
剑士正常 Patrol

地图外围
↓
生成 2 Slime + 1 Wolf
↓
敌人向 Settlement 移动

巡逻队提前遇到敌人
↓
Combat
↓
Slime / Wolf 被消灭
↓
剑士继续原来的 Patrol
↓
返回 Barracks
```

这才是本轮真正的新玩法成果。

------------------------------------------------------------------------

# 17. Raid V0 暂时不做

``` text
重新制作 Slime
重新制作 Wolf
新的 EnemyBase
新的 Combat 系统

敌人抢资源
敌人攻击 Farm
敌人攻击 Villager
敌人攻击 Base
建筑 HP
建筑 Damage

正式 Spawn Director
难度曲线
Wave
Elite
Boss

完整 Feature Editor
Ground Slam
Self Destruct
Fireball
Ragdoll
Shader Skill System
```

------------------------------------------------------------------------

# 18. Raid V0 完成后的下一步

``` text
Settlement Patrol Ring V0        ✅
↓
Third-party Raid V0              ✅
↓
Threat Detection
↓
Third-party Raid V1
```

Raid V1 才开始：

``` text
Enemy
├─ 攻击外围居民
├─ 攻击生产建筑
├─ 抢夺 / 破坏资源
└─ 迫使玩家真正重视巡逻覆盖
```

随后：

``` text
城墙
↓
城门
↓
防御工事
↓
时间裂缝
↓
Wave
↓
Elite + 第一批正式 Ability
↓
Boss
```

------------------------------------------------------------------------

# 19. 更新后的 ROADMAP 主线

客户端同步 ROADMAP 为：

``` text
基础经营                         ✅
资源系统                         ✅
Trait 基础                       ✅
Population                       ✅
Swordsman Training               ✅
Barracks / Patrol                ✅
Barracks Logistics               ✅
RTS Camera                       ✅
Combat V1                        ✅
Slime                            ✅
Wolf                             ✅

【CURRENT】
地图边界 / Settlement Patrol Ring V0
↓
Combat 收口 / Feature接口预留
↓
Third-party Raid V0
↓
Threat Detection
↓
Raid V1：攻击经济目标
↓
城墙 / 城门 / 防御
↓
时间裂缝随机位置
↓
Wave
↓
Elite + Ability
↓
Boss + Phase + Global Debuff
↓
Victory / Defeat
```

长期系统池继续保留：

``` text
道路
手推车 / 驮兽
钓鱼
狩猎
肉 / 鱼
二级食品
更多职业
更多兵种
装备
食物喜好
探险小屋
远征
救援人口
程序化有限小岛
战争迷雾
预言塔
随机事件
Roguelite Meta
完整 Feature / Skill Editor
Ragdoll
Player / King Ability
```

------------------------------------------------------------------------

# 20. 客户端执行顺序

严格分阶段：

``` text
阶段 1
README / ROADMAP 同步
↓
停止，汇报

阶段 2
地图边界 / Settlement Patrol Ring V0
↓
用户测试

阶段 3
Combat 技术点收口
↓
用户测试

阶段 4
FeatureData / FeatureEntry
↓
用户测试

阶段 5
Ability Runtime
↓
用户测试

阶段 6
Effect 接口
↓
用户测试

阶段 7
Debug / 工程清理
↓
用户测试

阶段 8
Third-party Raid V0
↓
用户测试
```

每阶段必须汇报：

1.  修改文件；
2.  新增文件；
3.  删除文件；
4.  核心逻辑；
5.  自动测试；
6.  用户手动测试步骤；
7.  已知限制；
8.  是否修改了阶段范围之外的系统。

------------------------------------------------------------------------

# 21. 本轮最终验收

本轮结束时：

``` text
README / ROADMAP 与真实工程一致
+
Combat V1 正式标记完成
+
现有 Slime / Wolf 保持不重做
+
Feature / Ability / Effect 有未来扩展入口
+
100% / 5% Feature 概率架构已预留
+
没有提前陷入完整技能编辑器
+
现有 Slime / Wolf 从测试敌人变成真实 Raid 敌人
+
巡逻系统第一次承担真正的外围防卫任务
```

达到这里后，再进入：

``` text
Patrol Ring
→ Threat Detection
→ Raid V1
→ 城墙
→ 时间裂缝
```
