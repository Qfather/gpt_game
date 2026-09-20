# Military Daily Loop V1 — 阶段一开发计划

## 剑士营 + Swordsman 职业转换

> 当前目标：打通 **“经营人口 → 军事人口”** 的第一条转换链。  
> 本轮只实现剑士职业与剑士营训练流程，**暂不实现军营、巡逻、敌人、Health、攻击、城墙和
> Wave**。  
> 执行方式：**每个阶段完成后停止开发，由用户测试并反馈；确认正常后再进入下一阶段。**

------------------------------------------------------------------------

# 1. 本轮最终闭环

``` text
普通 Villager
↓
玩家建造剑士营
↓
点击“训练剑士”
↓
产生训练需求
↓
符合条件的空闲居民自动领取
↓
真实走到剑士营
↓
占用 Training Slot
↓
训练计时
↓
原 Villager 转为 Swordsman
↓
人口总数不变
↓
继续保留 Hunger / Fatigue / Trait / 个体数据
```

本轮完成以后，项目第一次拥有：

``` text
经济人口
↓
牺牲部分生产劳动力
↓
转化为军事人口
```

这将作为后续军营、巡逻和 Combat 的入口。

------------------------------------------------------------------------

# 2. 重要架构原则

## 2.1 Swordsman 不是新的居民

禁止：

``` text
删除 Villager
↓
生成 Soldier Scene
```

应该：

``` text
同一个 Villager
CombatRole:
NONE
↓
SWORDSMAN
```

因此训练前后的：

``` text
居民身份
Trait
Hunger
Fatigue
Population
Transform / 实体身份
```

都应继续保留。

------------------------------------------------------------------------

## 2.2 CombatRole 与 Civilian Job 分离

不要把：

``` text
SWORDSMAN
```

直接塞进现有：

``` text
Lumberjack
Miner
Farmer
```

生产 Job 枚举。

建议概念结构：

``` text
Villager
│
├─ Civilian Job
│  ├─ NONE
│  ├─ Lumberjack
│  ├─ Miner
│  └─ Farmer
│
└─ Combat Role
   ├─ NONE
   └─ SWORDSMAN
```

长期可扩展：

``` text
SWORDSMAN
ARCHER
SPEARMAN
KNIGHT
MAGE
...
```

本轮只实现：

``` text
NONE
SWORDSMAN
```

------------------------------------------------------------------------

## 2.3 不复制已有系统

训练居民时优先复用当前已有：

``` text
GameTask
TaskManager
Villager 移动
NavigationAgent3D
BuildingData
BuildingGhost
ConstructionSite
Resource / Needs
```

不要另外创建一套完全独立的：

``` text
MilitaryTaskManager
SoldierNavigation
SoldierNeeds
```

------------------------------------------------------------------------

# 3. 阶段 1 — CombatRole 数据层

## 目标

让现有 Villager 能稳定保存：

``` text
CombatRole.NONE
CombatRole.SWORDSMAN
```

暂时：

``` text
不训练
不攻击
不巡逻
不换模型
```

只建立数据层。

## 要求

建议增加统一 CombatRole 定义，例如：

``` text
NONE
SWORDSMAN
```

具体文件位置根据现有工程架构决定，不要为了本功能大规模重构已有代码。

Villager 应能：

``` text
读取 CombatRole
修改 CombatRole
判断是否为战斗单位
```

建议预留：

``` text
set_combat_role(...)
get_combat_role()
has_combat_role()
```

具体命名可按照工程现有风格调整。

## Civilian Job 关系

第一版规则：

``` text
CombatRole != NONE
```

意味着该居民不能继续占用普通生产岗位。

如果居民原本有生产 Job，在真正训练流程开始前应安全释放 Job / Workplace。

但阶段 1 只建立数据结构，不需要实际触发训练。

## UI

为了测试，可以在现有居民信息 UI 中增加简单字段：

``` text
军事职业：无
```

或：

``` text
军事职业：剑士
```

不要现在制作正式军事 UI。

------------------------------------------------------------------------

## 阶段 1 测试

客户端完成后停止。

用户测试：

1.  启动现有工程。
2.  居民原有 Job / Needs 正常。
3.  CombatRole 默认全部为 NONE。
4.  调试方式将一个居民改为 SWORDSMAN。
5.  UI/调试信息能正确读取。
6.  Hunger / Fatigue 不受影响。
7.  Population 数量不变化。
8.  不出现已有 Task / Job 报错。

### 阶段 1 通过条件

``` text
CombatRole 可以独立存在
+
不破坏现有居民系统
```

用户确认后才能进入阶段 2。

------------------------------------------------------------------------

# 4. 阶段 2 — 剑士营建筑

## 目标

增加第一座军事训练建筑：

``` text
Swordsman Training Camp
剑士营
```

它的职责只有：

> **普通居民 → Swordsman**

它不是军营，不负责：

``` text
驻扎
巡逻
休息
警戒
战斗
```

## 建筑流程

必须继续复用：

``` text
BuildingData
↓
BuildingGhost
↓
Grid Placement
↓
ConstructionSite
↓
真实材料运输
↓
施工
↓
正式剑士营
```

不要制作“点击按钮直接生成”的特殊建筑。

## 第一版参数

``` text
Training Slots = 2
```

也就是说：

``` text
最多同时训练 2 名居民
```

训练 Slot 应作为可复用概念实现，避免把：

``` text
slot_1
slot_2
```

大量硬编码到剑士营专属逻辑。

但本轮也不要为了未来做复杂通用框架。

## 临时美术

允许继续使用：

``` text
占位模型
Cube
现有临时建筑
```

本阶段不制作正式剑士营美术。

------------------------------------------------------------------------

## 阶段 2 测试

客户端完成后停止。

用户测试：

``` text
选择剑士营
↓
Ghost 正常
↓
旋转 / 放置正常
↓
扣除/运输真实建筑材料
↓
居民施工
↓
建筑完成
```

同时确认：

``` text
剑士营存在 2 个 Training Slots
```

但此时还不需要居民进入训练。

### 阶段 2 通过条件

``` text
剑士营完整接入现有建筑系统
+
Training Slots = 2
```

用户确认后进入阶段 3。

------------------------------------------------------------------------

# 5. 阶段 3 — 训练请求与自动领取

## 目标

玩家不手动指定：

> “居民 A 去训练。”

而是：

``` text
玩家点击剑士营
↓
点击“训练剑士”
↓
系统产生训练需求
↓
符合条件的居民自动领取
```

这与当前居民自主领取工作/任务的方向保持一致。

## 剑士营 UI V1

点击建筑显示最简单信息：

``` text
剑士营

训练位：0 / 2

[训练剑士]
```

如果已经有一个：

``` text
训练位：1 / 2
```

两个：

``` text
训练位：2 / 2
```

如果未来存在等待队列，可再显示 Queue；本阶段不强制做复杂队列 UI。

## 合格居民条件

第一版至少：

``` text
是正式 Villager
CombatRole == NONE
没有正在训练
没有被其他不可打断任务锁定
```

如果居民正在普通工作，训练系统应通过现有 Job / Task
规则安全处理，不允许造成 Workplace 残留占位。

具体优先级应尽量服从现有 TaskManager，而不是硬抢状态。

## 移动

领取训练任务后：

``` text
Villager
↓
前往剑士营 Training Point / Slot Point
```

必须真实移动。

禁止：

``` text
点击训练
↓
居民瞬移
```

两个 Training Slots 最好拥有两个实际站位，避免两名居民完全重叠。

------------------------------------------------------------------------

## 阶段 3 测试

客户端完成后停止。

用户测试：

``` text
点击一次训练
→ 1 个合格居民前往剑士营

连续点击两次
→ 2 个居民分别前往两个 Slot
```

重点测试：

``` text
不会超过2人同时占位
不会同一个居民领取两次
居民能正常寻路
原生产岗位正确释放
TaskManager 无残留
```

此时到达后可以保持“训练中”，不要求完成职业转换。

### 阶段 3 通过条件

``` text
训练需求
→ 自动选人
→ 真实移动
→ 正确占用 Training Slot
```

用户确认后进入阶段 4。

------------------------------------------------------------------------

# 6. 阶段 4 — 训练计时与 Swordsman 转换

## 目标

打通完整训练流程。

居民抵达 Training Slot：

``` text
ARRIVE
↓
TRAINING
↓
TrainingProgress
↓
COMPLETE
↓
CombatRole = SWORDSMAN
```

## 训练时间

开发测试阶段建议先设置较短，例如：

``` text
10～20 秒
```

方便频繁测试。

最终正式数值以后结合：

``` text
1× / 2× / 3×
```

整体单局节奏统一调整。

不要现在锁死正式平衡数值。

## 训练过程中

第一版可以：

``` text
居民站在训练点
+
简单训练状态
```

有现成动画可以播放；没有就先不阻塞功能。

## 完成后

必须：

``` text
CombatRole = SWORDSMAN
```

同时：

``` text
Population 不变
Training Slot 释放
Training Task 完成
居民仍然存在
Needs 继续运行
```

当前阶段完成后，Swordsman 暂时可以在据点待命。

**不要提前实现巡逻。**

因为正式巡逻必须由下一阶段的 Barracks 组织。

------------------------------------------------------------------------

## 阶段 4 测试

测试：

``` text
Population = 10
↓
训练 2 人
↓
Population 仍然 = 10
```

检查：

``` text
2 人 CombatRole = SWORDSMAN
Training Slots 回到空闲
Hunger 正常变化
Fatigue 正常变化
Trait 保留
居民 UI 正常
普通生产岗位没有幽灵占位
```

再继续训练下一批，确认 Slot 可以重复使用。

### 阶段 4 通过条件

完整链：

``` text
Villager
↓
Training Request
↓
自动领取
↓
走到剑士营
↓
Training
↓
Swordsman
```

稳定运行。

------------------------------------------------------------------------

# 7. 阶段 5 — 回归测试与收口

本阶段不增加新玩法。

专门检查现有系统有没有被军事职业破坏。

## 测试 A：Population

``` text
训练前人口 = N
训练后人口 = N
```

Migrant / Immigration 逻辑仍然正常。

## 测试 B：FOOD / Hunger

Swordsman：

``` text
仍然会饿
仍然会去吃饭
仍然消耗 FOOD
```

## 测试 C：Fatigue

Swordsman：

``` text
仍然产生 Fatigue
达到阈值仍然能进入已有休息流程
```

## 测试 D：生产劳动力

训练前：

``` text
10 Villagers
0 Swordsmen
```

训练后：

``` text
8 普通劳动力
2 Swordsmen
总人口仍然 10
```

确保剑士不会继续被普通生产建筑当成可招聘居民。

## 测试 E：建筑删除 / 异常

至少测试：

``` text
训练中删除剑士营
居民寻路失败
Slot 被取消
任务中断
```

不能：

``` text
居民永久锁死
Training Slot 永久占用
Task 永久残留
```

具体异常恢复策略遵循工程已有模式。

------------------------------------------------------------------------

# 8. 本轮明确不做

为了避免客户端顺手继续扩展，本轮禁止提前实现：

``` text
Barracks
驻军
巡逻
换班

Settlement Patrol Ring

Faction
Health
Damage
Attack
Enemy
Slime
Wolf
Bandit

Wall
Defensive Position

Rift
Wave
Boss

正式军事模型
正式武器装备系统
军事升级树
```

这些属于后续阶段。

------------------------------------------------------------------------

# 9. 本轮完成后的下一步

确认本轮稳定后：

``` text
Swordsman
↓
Barracks V1
```

下一轮目标：

``` text
军营 Capacity = 6
↓
Swordsman 自动驻扎
↓
和平时期
ceil(Garrison / 2) 巡逻
↓
其余 GARRISON_IDLE
↓
定期真实换班
↓
PATROL = WORKING 消耗
GARRISON_IDLE = IDLE 消耗
```

随后才进入：

``` text
Settlement Patrol Ring
↓
Threat Detection
↓
第一种第三方袭扰
↓
Combat V1
```

------------------------------------------------------------------------

# 10. 客户端执行要求

客户端必须严格按照以下方式推进：

``` text
阶段 1
→ 实现
→ 给出修改文件
→ 给出测试步骤
→ 停止

用户测试确认
↓

阶段 2
→ 实现
→ 测试
→ 停止
```

依次执行。

每阶段回复必须说明：

``` text
1. 修改了哪些文件
2. 新增了哪些文件
3. 核心逻辑是什么
4. 用户应该如何测试
5. 已知限制
```

不要在用户确认前自动进入下一阶段。

------------------------------------------------------------------------

# 11. 本轮验收目标

最终只需要证明这一件事：

> **一个真实存在于当前经营系统中的居民，可以通过玩家建设的剑士营和自主任务流程，真正走过去训练，并在不丢失个体与
> Needs 数据、不改变总人口的情况下成为 Swordsman。**

做到这里，本轮结束。

下一轮再让这些 Swordsman：

> **进入军营，并开始承担真正有目的的据点巡逻职责。**
