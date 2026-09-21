# 时间裂缝 — ROADMAP

> 当前目标：优先跑通一整局“经营 → 军事 → 战斗 → 防御 → 时间裂缝 → Boss →
> 结算”的主循环。  
> 原则：先做可玩的最小闭环，再逐步增加深度；玩家负责战略决策，居民与战斗单位尽量自主运行。

------------------------------------------------------------------------

# 0. 当前工程状态

``` text
基础经营循环                         ✅
├─ 居民自主任务
├─ 砍树 / 木材
├─ 采石 / 石料
├─ 农田 / 食物
├─ 资源运输与库存
├─ 建筑施工
└─ Hunger / Fatigue 生活需求

资源系统 V2                         ✅
├─ ResourceData
├─ Resource ID
├─ ResourceStorage
├─ ResourceManager
└─ Resource Editor

人口系统 V1                         ✅
├─ House / 住房
├─ PopulationManager
├─ 移民条件
├─ Migrant 到达
├─ 转化为 Villager
└─ 人口 UI

Military Daily Loop V1             ✅
├─ CombatRole / SWORDSMAN
├─ 剑士营
├─ 2 Training Slots
├─ 自动训练任务
└─ Villager → Swordsman

Barracks / Patrol V0               ✅
├─ Barracks Capacity = 6
├─ Swordsman 自动驻扎
├─ 无军营 → Base 附近待命
├─ 驻军进入军营后隐藏
├─ ceil(Garrison / 2) 自动出巡
├─ 门口集合
├─ 简单巡逻路线
├─ 返回军营隐藏
└─ 自动轮班循环

Barracks Logistics V1              ✅
├─ Barracks FOOD Storage
├─ 驻军军营内部进食
├─ 驻军军营内部休息
├─ 待命期间主动维持状态
├─ 军粮不足自动补给
├─ 待命驻军真实搬运 FOOD
├─ 补给属于 WORKING
├─ 出巡状态检查
├─ 巡逻返回后恢复
└─ 长时间轮班闭环

RTS Camera V1                      ✅
├─ WASD 平移
├─ 鼠标滚轮缩放
├─ 中键旋转
├─ Shift + 中键平移
└─ F 聚焦选中对象
```

## 当前开发节点

``` text
【CURRENT】
Combat V1
↓
数据驱动 Enemy 系统
↓
基础生命 / 伤害
↓
自动索敌
↓
Swordsman ↔ Enemy 战斗
↓
战斗结束恢复原任务
```

------------------------------------------------------------------------

# 1. Combat V1 — 当前主线

## 目标

第一次真正把经营系统与守城战斗系统连接起来。

最终最小闭环：

``` text
军营
↓
剑士出巡
↓
巡逻途中发现 Enemy
↓
自动接敌
↓
攻击 / 受伤
↓
Enemy 死亡
↓
剑士恢复巡逻
↓
返回军营
↓
吃饭 / 休息 / 再次出勤
```

第一版不要做复杂战斗数值。

先证明：

> 三名巡逻剑士能够发现一只敌人，自主过去战斗，消灭敌人后继续原来的巡逻任务。

------------------------------------------------------------------------

# 2. 数据驱动 Enemy 架构

这是 Combat V1 的第一阶段。

## 核心目标

后期增加普通敌人时：

``` text
创建 EnemyData
↓
设置模型和数值
↓
直接生成新敌人
```

绝大多数敌人**不需要单独写脚本**。

禁止长期形成：

``` text
slime.gd
wolf.gd
bandit.gd
big_slime.gd
enemy_01.gd
enemy_02.gd
...
```

------------------------------------------------------------------------

## 2.1 EnemyBase

所有敌人共享统一运行实体：

``` text
EnemyBase
├─ EnemyData
├─ Health
├─ Movement
├─ Targeting
├─ Combat
└─ Abilities[]
```

`EnemyBase` 只负责通用行为。

禁止在其中不断增加：

``` text
if enemy_type == SLIME
if enemy_type == WOLF
if enemy_type == BOSS
```

敌人差异应尽量来自数据与可复用能力组合。

------------------------------------------------------------------------

## 2.2 EnemyData

建议使用 Godot `Resource`。

概念字段：

``` text
Identity
├─ id
├─ display_name
├─ category
├─ is_boss
└─ visual_scene

Stats
├─ max_health
├─ damage
├─ move_speed
├─ attack_range
├─ attack_interval
└─ detection_range

AI
├─ target_policy
├─ can_attack_units
├─ can_attack_buildings
└─ behavior_profile

Rewards
├─ drops
└─ reward_value

Abilities
└─ Array[EnemyAbility]
```

具体字段随 Combat V1 实际需求逐步增加。

不要为了未来一次性塞入几十个暂时不用的参数。

------------------------------------------------------------------------

## 2.3 第一批 EnemyData

第一只测试敌人：

``` text
SlimeData.tres

HP             30
Damage          5
MoveSpeed       2.5
AttackRange     1.2
Abilities       []
```

它不需要：

``` text
slime.gd
```

第二只测试敌人可直接复制：

``` text
WolfData.tres
```

修改：

``` text
模型
HP
Damage
Speed
Detection Range
```

如果两种敌人都能依靠同一个 `EnemyBase`
正常运行，就证明数据驱动架构成立。

------------------------------------------------------------------------

# 3. Enemy Ability 系统

EnemyData 解决数值差异。

EnemyAbility 解决特殊机制差异。

结构：

``` text
EnemyAbility
├─ MeleeAttack
├─ RangedAttack
├─ Charge
├─ Pounce
├─ Heal
├─ Poison
├─ Summon
├─ Aura
└─ ...
```

普通敌人可以：

``` text
Slime
└─ 普通近战
```

狼人：

``` text
Wolf
├─ 普通近战
└─ Pounce
```

远程敌人：

``` text
Archer
└─ RangedAttack
```

特殊敌人：

``` text
Shaman
├─ RangedAttack
├─ Heal
└─ Summon
```

只有出现真正的新机制时才增加新的 Ability 脚本。

**不是每出现一种敌人就增加一个脚本。**

------------------------------------------------------------------------

# 4. Boss 与普通敌人共用底层

Boss 不重新建立第二套：

``` text
BossBase
BossHealth
BossCombat
BossTargeting
```

Boss 仍然属于：

``` text
EnemyBase
```

只是拥有：

``` text
is_boss = true
更高 Stats
更多 Abilities
PhaseController
Boss UI
特殊事件
全局 Debuff
```

示例：

``` text
Time Rift Boss
├─ EnemyBase
├─ EnemyData
├─ GroundSmash
├─ SummonEnemies
├─ GlobalDebuff
├─ RiftStorm
└─ PhaseController
```

以后 Boss 阶段可以增加：

``` text
Phase 1
↓ HP < 60%
Phase 2
↓ HP < 25%
Phase 3
```

但底层生命、受伤、目标、移动和基础战斗仍然与普通 Enemy 共用。

------------------------------------------------------------------------

# 5. Enemy Editor

## V1 暂时不做独立编辑器插件

当前先使用：

``` text
EnemyData Resource
+
Godot Inspector
```

作为第一版 Enemy Editor。

这样现在就能：

``` text
创建 EnemyData
↓
选择模型
↓
填写 HP / Damage / Speed
↓
选择 Ability
↓
保存 .tres
```

## 后期再制作 Enemy Database Editor

当敌人数量明显增加后，再做正式编辑器。

目标功能：

``` text
Enemy Database
├─ 搜索 / 分类
├─ 新建 Enemy
├─ Duplicate Enemy
├─ 编辑基础属性
├─ 模型预览
├─ Ability 列表
├─ 掉落配置
├─ Boss 标记
└─ 数据验证
```

最重要的是：

``` text
Wolf
↓ Duplicate
Dire Wolf
↓
只改 HP / Damage / Scale / Ability
```

不写新敌人脚本。

------------------------------------------------------------------------

# 6. Combat V1 开发顺序

``` text
阶段 1
EnemyData + EnemyBase
↓
只靠数据生成 Slime

阶段 2
Health / Damage
↓
Enemy 可以受伤和死亡
Swordsman 可以受伤

阶段 3
基础 Targeting
↓
Swordsman 能发现 Hostile
Enemy 能发现合法目标

阶段 4
基础近战 Combat
↓
接近目标
攻击
伤害
死亡

阶段 5
Patrol → Combat
↓
巡逻剑士发现 Enemy
中断巡逻
战斗

阶段 6
Combat → Patrol
↓
敌人死亡
剑士重新集合 / 恢复原任务
继续巡逻

阶段 7
第二种 EnemyData
↓
复制 SlimeData → WolfData
↓
不写 wolf.gd
验证数据驱动架构
```

Combat V1 暂不实现：

``` text
护甲
暴击
闪避
元素
复杂武器系统
技能树
复杂仇恨
复杂阵型
受伤动画系统
Boss Phase
```

------------------------------------------------------------------------

# 7. 第三方袭扰 V1

Combat V1 跑通后，再让敌人真正影响经营。

第一批可以选择：

``` text
Slime
Wolf
Bandit
```

不需要一开始全部做。

## 行为目标

第三方敌人不是大型时间裂缝 Wave。

它们属于地图日常威胁：

``` text
地图外围 / 野外生成
↓
靠近势力范围
↓
攻击居民 / 资源点 / 外围建筑
↓
巡逻队提前发现
↓
自动响应
↓
减少经济损失
```

这一步让巡逻真正产生玩法价值。

------------------------------------------------------------------------

# 8. Settlement Patrol Ring / Threat Detection

在 Combat 已经可玩之后，再正式完善巡逻区域。

## Settlement Patrol Ring

根据当前势力范围 / 建筑分布：

``` text
Settlement Bounds
↓
向外扩一定距离
↓
生成 Patrol Ring
```

军营自动负责对应区域。

V1 玩家不需要手动画路线。

长期可以允许：

``` text
选择 Barracks
↓
设置战略防区
```

但仍然不微操单个士兵。

## Threat Detection

巡逻的意义：

``` text
发现敌人
发现第三方袭扰
发现异常
提前预警
```

未来大型时间裂缝也可以与：

``` text
巡逻
预言塔
侦察建筑
```

共同决定玩家能够提前获得多少情报。

------------------------------------------------------------------------

# 9. 城墙与据点防御

完成基础战斗和日常威胁后：

``` text
Wall
Gate
Defensive Position
```

目标：

``` text
敌人不再直接冲进经济区
↓
城墙改变敌人路径
↓
士兵承担缺口 / 城门防御
↓
玩家开始规划真正的防线
```

后续可扩展：

``` text
箭塔
防御工事
陷阱
城墙升级
```

但第一版保持简单。

------------------------------------------------------------------------

# 10. 时间裂缝

大型时间裂缝不固定出生点。

建议：

``` text
当前 Settlement Bounds
↓
向外扩安全距离
↓
在外围随机选择合法位置
↓
生成大型 Rift
```

玩家不能永远背同一张地图的固定进攻方向。

裂缝出现后：

``` text
情报不足
→ 只知道异常出现

侦察 / 巡逻较好
→ 较早知道方向

未来预言塔
→ 更早获得位置 / 强度 / 敌人信息
```

玩家据此决定：

``` text
加固城墙
调整军营防区
建立前沿防御
准备资源
```

------------------------------------------------------------------------

# 11. Wave

时间裂缝进入正式进攻：

``` text
Rift
↓
Wave 1
↓
恢复 / 经营
↓
Wave 2
↓
更强敌人
↓
Elite
↓
最终 Boss
```

Wave 不应该让经营停止。

核心仍然是：

``` text
生产
↓
人口
↓
后勤
↓
军事
↓
守城
```

同时运行。

------------------------------------------------------------------------

# 12. Boss

Boss 使用统一 Enemy 架构。

Boss 的区别来自：

``` text
EnemyData
+
Abilities
+
PhaseController
+
Global Effects
```

Boss 可以对经营系统施加全局 Debuff，例如：

``` text
移民粮食要求增加
住房要求变化
作物成长降低
居民 Hunger 消耗增加
军营补给压力增加
资源生产降低
```

Boss 因此不只是“大血条怪物”，而会改变这一局的经营条件。

------------------------------------------------------------------------

# 13. Victory / Defeat

第一关最终需要明确结束。

## Victory

例如：

``` text
击败最终 Rift Boss
↓
关闭 / 稳定时间裂缝
↓
Victory
```

## Defeat

以后根据实际试玩确定，例如：

``` text
Base 被摧毁
```

或其他核心失败条件。

目标是让一局真正具备：

``` text
开始
↓
发展
↓
压力升级
↓
高潮
↓
结算
```

------------------------------------------------------------------------

# 14. 后续系统池

以下内容保留，但不阻塞第一关：

``` text
道路加速
手推车 / 驮兽物流
钓鱼
狩猎
肉 / 鱼
二级食品
三级食品
高级材料
更多职业
更多兵种
装备
Trait 深化
食物喜好 / 讨厌
探险小屋
远征
救援人口
热气球 / 船
程序化有限小岛
战争迷雾
预言塔
随机事件
更多第三方势力
更多 Boss
Roguelite Meta Progression
```

------------------------------------------------------------------------

# 15. 当前推荐主线

从现在开始，不再继续横向深化已经能运行的经营和军营系统。

``` text
【现在】
数据驱动 Enemy 架构
↓
Combat V1
↓
第一种第三方袭扰
↓
Patrol Ring / Threat Detection
↓
城墙 / 防御
↓
时间裂缝
↓
Wave
↓
Boss
↓
Victory / Defeat
```

做到这里：

> **第一关主循环完成。**

之后再回头增加：

``` text
更多资源
更多食物
更多兵种
更多敌人
远征
随机事件
程序化地图
Roguelite 深度
```

------------------------------------------------------------------------

# 16. 开发纪律

继续保持当前开发方式：

1.  每次只实现一个明确的小阶段。
2.  每阶段完成后停止。
3.  用户在 Godot 中实际运行测试。
4.  客户端说明修改文件、实现内容、测试步骤和已知限制。
5.  用户确认后才进入下一阶段。
6.  不因为“以后可能需要”而提前实现复杂系统。
7.  但底层数据结构应避免明显的一敌一脚本、一资源一硬编码等不可扩展设计。
