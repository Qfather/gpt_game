# Combat V1 — 数据驱动敌人与基础自动战斗开发计划

> 当前前置：经营、人口、剑士训练、军营自动驻扎与巡逻、军营后勤、RTS
> Camera 已经能够运行。
>
> 本轮目标不是制作很多怪物，而是建立一套**以后新增普通敌人主要靠数据配置，而不是一敌一脚本**的战斗底层，并让现有巡逻剑士第一次真正发生战斗。
>
> 开发方式继续保持：**每完成一个阶段立即停止 → 用户测试 →
> 确认后再进入下一阶段。**

------------------------------------------------------------------------

# 1. 本轮最终验收画面

``` text
军营
↓
3 名剑士自动出营
↓
集合
↓
正常巡逻
↓
附近出现 Slime
↓
剑士发现 Hostile
↓
中断当前巡逻
↓
接近 Slime
↓
自动攻击
↓
Slime HP 降低
↓
Slime 死亡
↓
剑士重新恢复巡逻
↓
巡逻结束
↓
返回军营
```

同时再复制一份 EnemyData：

``` text
SlimeData
↓ Duplicate
WolfData
↓
修改模型 / HP / Damage / Speed
```

**不创建 `wolf.gd`，也能正常参与同一套战斗。**

做到这里，Combat V1 完成。

------------------------------------------------------------------------

# 2. 架构原则

## 2.1 禁止一敌一脚本

不要形成：

``` text
slime.gd
wolf.gd
bandit.gd
big_slime.gd
elite_slime.gd
...
```

绝大多数敌人应该是：

``` text
EnemyBase
+
EnemyData
+
可选 Abilities
```

------------------------------------------------------------------------

## 2.2 Boss 以后也走 EnemyBase

当前不做 Boss，但底层必须允许未来：

``` text
普通 Enemy
Elite
Boss
```

共享：

``` text
Health
Damage
Movement
Targeting
Combat
```

Boss 的特殊性以后来自：

``` text
EnemyData
Abilities
PhaseController
Boss UI
Global Effect
```

不要现在建立第二套 Boss 战斗系统。

------------------------------------------------------------------------

## 2.3 只实现当前真正需要的数据

EnemyData 要可扩展，但不要一次塞几十个未来字段。

Combat V1 先围绕：

``` text
身份
模型
HP
Damage
Move Speed
Attack Range
Attack Interval
Detection Range
基础目标规则
```

实现。

------------------------------------------------------------------------

# 3. 阶段 1 — EnemyData + EnemyBase

## 目标

先建立数据驱动敌人的最小骨架。

建议：

``` text
EnemyData.gd
extends Resource
```

概念数据：

``` text
id
display_name
visual_scene

max_health
damage
move_speed
attack_range
attack_interval
detection_range

is_boss = false
```

字段名根据当前项目规范调整。

## EnemyBase

创建统一敌人 Scene / Script：

``` text
EnemyBase
├─ Visual Root
├─ NavigationAgent3D
├─ Collision
└─ EnemyBase.gd
```

EnemyBase 加载：

``` text
@export var enemy_data: EnemyData
```

运行时从 EnemyData 初始化：

``` text
模型
HP
Damage
Speed
Range
...
```

## 第一份数据

创建：

``` text
SlimeData.tres
```

测试参数可以简单：

``` text
HP               = 30
Damage           = 5
Move Speed       = 2.5
Attack Range     = 1.2
Attack Interval  = 1.0
Detection Range  = 8
```

模型可以先使用占位 Mesh。

## 本阶段不做

``` text
索敌
追击
攻击
死亡
掉落
Ability
```

只证明：

> 同一个 EnemyBase 能根据 EnemyData 正确生成一个具有不同数据的敌人实例。

## 测试

场景中放置：

``` text
EnemyBase
└─ EnemyData = SlimeData
```

运行后检查：

``` text
名称正确
HP正确
速度参数正确
模型/占位物正确
无报错
```

**完成后停止。**

------------------------------------------------------------------------

# 4. 阶段 2 — 通用 Health / Damage

## 目标

建立单位受伤与死亡的最小接口。

这里不要只为 Enemy 写死：

``` text
enemy.hp -= damage
```

因为：

``` text
Enemy
Swordsman
未来 Villager
未来建筑
未来 Boss
```

都会需要受伤。

优先建立可复用的生命接口/组件。

概念：

``` text
Health
├─ max_health
├─ current_health
├─ take_damage(amount, source)
├─ is_dead()
└─ died signal
```

具体采用
Component、独立脚本还是当前项目已有的实体接口，由客户端结合现有代码决定。

## Enemy 死亡

V1：

``` text
HP <= 0
↓
进入 DEAD
↓
停止移动
↓
停止攻击
↓
短暂延迟或立即移除
```

暂时不要做：

``` text
尸体
掉落动画
布娃娃
复杂死亡特效
```

## Swordsman

Swordsman 也接入同一生命接口。

开发阶段 UI/调试信息至少能观察：

``` text
HP 100 / 100
```

## 阶段测试

先用调试调用造成伤害：

``` text
Slime 30
↓ -10
20
↓ -10
10
↓ -10
死亡
```

再测试 Swordsman 同样可以受伤。

**完成后停止。**

------------------------------------------------------------------------

# 5. 阶段 3 — Enemy 基础 Targeting

## 目标

让 Enemy 能识别合法目标，但先不攻击。

V1 先保持规则简单。

例如：

``` text
Enemy
↓
Detection Range
↓
寻找最近合法目标
```

第一版合法目标优先只包括：

``` text
Swordsman
```

等战斗稳定后，再扩：

``` text
Villager
Building
Base
```

避免这一阶段同时牵动所有经济实体。

## Hostile 概念

不要让 Enemy 判断：

``` text
if target is Villager
if target is Swordsman
```

建议逐步建立统一的阵营/敌对判断概念。

V1 可以很小：

``` text
Faction / Team

SETTLEMENT
HOSTILE
```

至少做到：

``` text
同阵营不互打
敌对阵营才是合法目标
```

以后：

``` text
史莱姆
狼人
盗匪
时间裂缝怪物
```

才能继续扩展。

## 阶段测试

放置：

``` text
1 Swordsman
1 Slime
```

进入 Detection Range：

``` text
Slime 获取 Swordsman 为 target
```

离开范围/目标死亡：

``` text
target 清除或重新选择
```

本阶段仍然不攻击。

**完成后停止。**

------------------------------------------------------------------------

# 6. 阶段 4 — Enemy 追击与基础近战

## 目标

完成 Enemy 的第一条战斗行为：

``` text
发现目标
↓
追击
↓
进入 Attack Range
↓
停止移动
↓
按 Attack Interval 攻击
↓
造成 Damage
```

第一版不要求复杂攻击动画。

可以：

``` text
攻击计时完成
↓
take_damage()
```

以后再把伤害事件对齐动画帧。

## 目标失效

目标：

``` text
死亡
距离过远
不可达
```

Enemy 应退出当前 Combat，不得永久卡住。

## 阶段测试

``` text
Slime
↓
发现 Swordsman
↓
走过去
↓
进入攻击距离
↓
每 1 秒攻击
↓
Swordsman HP 正常下降
```

**完成后停止。**

------------------------------------------------------------------------

# 7. 阶段 5 — Swordsman 自动索敌与反击

## 目标

让现有剑士第一次拥有真正 Combat 行为。

Swordsman 在：

``` text
PATROL
ASSEMBLE
RETURN
```

等军事外部状态中，可以发现附近 Hostile。

V1 优先让：

``` text
PATROL
```

支持自动索敌。

流程：

``` text
PATROL
↓
检测到 Hostile
↓
保存原军事任务上下文
↓
COMBAT
↓
追击
↓
攻击
```

剑士攻击参数先使用简单开发值，例如：

``` text
HP              100
Damage           10
Attack Range      1.5
Attack Interval   1.0
Detection Range  10
```

后续再数据化兵种。

## 多名剑士

允许：

``` text
3 Swordsman
↓
发现同一 Slime
↓
一起攻击
```

第一版不做复杂仇恨和目标分配。

## 阶段测试

``` text
3名剑士正在巡逻
↓
Slime 位于附近
↓
剑士中断巡逻
↓
自动接近
↓
攻击
↓
Slime 死亡
```

此阶段先观察死亡后状态是否稳定，下一阶段再正式恢复巡逻。

**完成后停止。**

------------------------------------------------------------------------

# 8. 阶段 6 — Combat → 恢复原军事任务

## 目标

这是 Combat V1 最关键的闭环。

剑士不能打完以后：

``` text
站在原地发呆
```

也不能：

``` text
直接回 Base
```

应该恢复被 Combat 打断前的军事任务。

例如：

``` text
PATROL
↓
发现 Enemy
↓
保存 Patrol Context
↓
COMBAT
↓
Enemy 死亡
↓
检查附近是否还有立即威胁
↓
没有
↓
恢复 Patrol
```

如果原本属于巡逻小队：

``` text
重新靠近小队 / 当前巡逻路线
↓
继续后续 Patrol Point
```

不要求 V1 做严格阵型。

## 多敌人

如果战斗结束附近还有 Hostile：

``` text
重新选择合法目标
↓
继续 Combat
```

清场后再恢复 Patrol。

## 阶段测试

完整测试：

``` text
军营
↓
3人出营
↓
集合
↓
巡逻
↓
发现 Slime
↓
战斗
↓
Slime 死亡
↓
3人恢复巡逻
↓
走完路线
↓
返回军营
↓
隐藏
```

这条完整跑通后再进入下一阶段。

**完成后停止。**

------------------------------------------------------------------------

# 9. 阶段 7 — 第二种 EnemyData 验证

## 目标

验证我们的敌人架构确实不是“披着 Data 外皮的一敌一脚本”。

复制：

``` text
SlimeData.tres
↓
WolfData.tres
```

修改：

``` text
display_name
visual_scene
max_health
damage
move_speed
attack_range
detection_range
```

例如：

``` text
Wolf

HP              60
Damage          12
Move Speed       5
Attack Range     1.4
Detection Range 14
```

## 核心验收

禁止创建：

``` text
wolf.gd
```

Wolf 必须直接使用：

``` text
EnemyBase
+
WolfData
```

然后能够：

``` text
索敌
追击
攻击
受伤
死亡
```

如果需要为“狼”专门在 EnemyBase 写：

``` text
if id == "wolf"
```

说明当前数据驱动架构有问题，应先修架构而不是继续增加敌人。

**完成后停止。**

------------------------------------------------------------------------

# 10. Enemy Ability — 本轮只留接口，不扩玩法

Combat V1 可以建立最小 `EnemyAbility` 接口，但不要现在做一堆能力。

目标只是保证以后可以：

``` text
Wolf
└─ Pounce

Archer
└─ RangedAttack

Shaman
├─ Heal
└─ Summon
```

而不用修改 EnemyBase。

如果当前 Combat V1 完全不需要 Ability
才能跑通，可以只把接口设计记入代码结构/ROADMAP，不必为了架构漂亮强行实现空系统。

------------------------------------------------------------------------

# 11. Enemy Editor — 当前实现方式

本轮：

``` text
EnemyData Resource
+
Godot Inspector
```

就是 Enemy Editor V0。

现在不制作专门 EditorPlugin。

添加敌人的正常流程应达到：

``` text
New Resource
↓
EnemyData
↓
填写参数
↓
选择模型
↓
保存 .tres
↓
放入 EnemyBase
↓
运行
```

等真正有大量 EnemyData 后再制作：

``` text
Enemy Database Editor
```

------------------------------------------------------------------------

# 12. 本轮明确不做

``` text
正式 Boss
Boss Phase
Boss UI

护甲
暴击
闪避
格挡
元素克制
状态异常
技能树

复杂仇恨
复杂阵型
复杂 Squad Combat
远程战斗
弹道
武器装备
掉落系统

敌人攻击 Villager
敌人攻击 Building
敌人攻击 Base

敌人 Spawn Director
第三方袭扰生成
时间裂缝
Wave
城墙
Boss
```

这些都不能阻塞第一场最小战斗。

------------------------------------------------------------------------

# 13. Combat V1 完成后的下一步

完成本计划后：

``` text
经营系统
↓
人口
↓
剑士
↓
军营
↓
军粮
↓
巡逻
↓
Enemy
↓
Combat
```

已经第一次形成连接。

下一轮进入：

# Third-party Raid V1

目标：

``` text
地图外围出现少量敌人
↓
向 Settlement 活动
↓
威胁外围居民 / 生产
↓
巡逻队发现
↓
自动响应
↓
玩家第一次感受到“为什么需要巡逻”
```

然后再做：

``` text
Settlement Patrol Ring
↓
Threat Detection
↓
城墙
↓
时间裂缝
↓
Wave
↓
Boss
```

------------------------------------------------------------------------

# 14. 客户端执行纪律

必须逐阶段执行：

``` text
阶段 1
→ 实现
→ 汇报
→ 用户测试
→ 停止

用户确认
↓
阶段 2
```

每阶段必须汇报：

1.  修改文件。
2.  新增文件。
3.  核心实现。
4.  用户测试方法。
5.  已知限制。
6.  是否改动了本阶段范围以外的系统。

不要一次把 7 个阶段全部做完。

------------------------------------------------------------------------

# 15. 本轮唯一最终验收

> **使用同一个 EnemyBase 和不同
> EnemyData，可以生成至少两种不需要专属脚本的敌人；巡逻中的 Swordsman
> 能自动发现敌人、接近并战斗，敌人死亡后 Swordsman
> 能恢复原来的巡逻任务并最终返回军营。**

完成这一点后，Combat V1 收口。
