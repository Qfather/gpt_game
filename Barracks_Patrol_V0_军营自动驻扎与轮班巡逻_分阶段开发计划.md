# Barracks / Patrol V0 — 军营自动驻扎与轮班巡逻开发计划

> 当前前置：`CombatRole / SWORDSMAN`、剑士营、2 个 Training
> Slots、自动训练流程已经完成。  
> 本轮目标：先得到一个**肉眼可见、能够循环运行**的军营巡逻结果。  
> **不要在本轮实现完整军粮、军营吃饭休息、30% 补给和战备维护。**

# 1. 最终验收画面

本轮完成后，用户应该能看到：

``` text
训练 6 个 Swordsman
↓
没有军营时
6 人在 Base 附近待命
↓
建成 Barracks
↓
6 人自动真实走向军营
↓
进入军营后隐藏
↓
Barracks = 6 / 6

过一段时间
↓
3 人从军营出现
↓
在门口集合
↓
3 人一起沿简单路线巡逻
↓
巡逻完成
↓
3 人返回军营并隐藏

随后
↓
另外 3 人从军营出现
↓
集合
↓
巡逻
↓
返回
↓
持续轮班循环
```

玩家不需要逐个选择士兵，不需要手动指定驻军，也不需要手动画巡逻路线。

# 2. V0 设计原则

## 2.1 剑士营与军营职责分开

``` text
Swordsman Training Camp
= 训练

Barracks
= 驻军 + 组织巡逻
```

军营不生成 Swordsman。

## 2.2 自动化优先

玩家：

``` text
训练剑士
+
建造军营
```

系统负责：

``` text
寻找军营
驻扎
分班
出营
集合
巡逻
返回
换班
```

## 2.3 Swordsman 仍是原居民

不得创建第二套 Soldier 实体。

继续保留现有：

``` text
CombatRole
Hunger
Fatigue
Trait
Population Identity
Navigation
```

## 2.4 本轮 Needs 只保证兼容

V0：

``` text
PATROL
→ 按 WORKING 消耗

军营内部
→ 暂按 IDLE 消耗
```

本轮不解决军营内部正式 Eating / Resting。

完整 Needs / Military Logistics 放到下一轮。

------------------------------------------------------------------------

# 3. 阶段 1 — Barracks 建筑与驻军容量

## 目标

增加：

``` text
Barracks
Capacity = 6
```

继续复用现有建筑管线：

``` text
BuildingData
↓
BuildingGhost
↓
ConstructionSite
↓
材料运输
↓
施工
↓
正式 Barracks
```

允许占位模型。

## 数据

军营至少需要能查询：

``` text
garrison_capacity = 6
garrison_count
has_free_garrison_slot()
register_garrison(unit)
unregister_garrison(unit)
```

具体命名服从现有代码风格。

军营 UI V0 至少显示：

``` text
军营
驻军：0 / 6
```

## 阶段 1 测试

只测试建筑：

``` text
Ghost
旋转
放置
施工
完成
0 / 6
```

**完成后停止，等待用户确认。**

------------------------------------------------------------------------

# 4. 阶段 2 — Swordsman 自动寻找军营

## 无军营

训练完成的 Swordsman：

``` text
没有可用 Barracks
↓
前往 Base 附近
↓
保持显示
↓
BASE_GUARD_IDLE
```

V0 不巡逻。

## 有军营

``` text
Swordsman
↓
自动寻找有空位的 Barracks
↓
预留/注册驻军位
↓
真实走向 Barracks Entrance
↓
抵达
↓
进入 Garrison
↓
隐藏单位
```

禁止瞬移。

## 军营满员

``` text
Barracks = 6 / 6
↓
第 7 名 Swordsman
↓
寻找其他军营
↓
没有其他军营
↓
回 Base 待命
```

以后新建第二座军营：

``` text
无驻地 Swordsman
↓
自动发现新空位
↓
前往并驻扎
```

## 隐藏要求

只有真正抵达 Barracks Entrance 后才能隐藏。

进入军营后：

``` text
Visual / Mesh 隐藏
外部 Navigation 停止
逻辑实体继续存在
Needs 继续更新
```

不要因为隐藏而删除节点或停止居民核心数据。

## 阶段 2 测试

测试：

``` text
A. 先训练剑士，不建军营
→ 全部回 Base 待命

B. 建一座军营
→ 最多 6 人自动走过去
→ 到达后逐个消失
→ UI 变为 6 / 6

C. 第 7 人
→ 不进入满员军营
→ Base 待命

D. 再建第二座
→ 第 7 人自动前往第二座
```

**完成后停止。**

------------------------------------------------------------------------

# 5. 阶段 3 — 自动分班与出营

## 巡逻人数

使用：

``` text
PatrolCount = ceil(GarrisonCount / 2)
```

第一版：

| 驻军 | 出巡 | 留营 |
|-----:|-----:|-----:|
|    1 |    1 |    0 |
|    2 |    1 |    1 |
|    3 |    2 |    1 |
|    4 |    2 |    2 |
|    5 |    3 |    2 |
|    6 |    3 |    3 |

## 分班

不需要复杂 Squad 系统。

V0 只需要军营能够确定：

``` text
当前 Patrol Group
下一 Patrol Group
```

6 人时：

``` text
A B C = Group A
D E F = Group B
```

## 出营

轮到 Group A：

``` text
军营内部隐藏
↓
Group A 获得 Patrol Duty
↓
从 Barracks Entrance 恢复显示
↓
移动到 Assemble Point
```

Group B：

``` text
继续隐藏
继续留营
```

## Assemble Point

军营门口设置：

``` text
AssemblePoint
```

最好提供 3 个简单偏移位置，避免三人完全重叠。

例如：

``` text
     A

 B       C

  [Barracks]
```

## 阶段 3 测试

6 人驻军：

``` text
3 人从军营出现
3 人继续隐藏
出现的 3 人走到门口集合点
```

此阶段**先不要求开始巡逻**。

测试 1～6 人都不能报错。

**完成后停止。**

------------------------------------------------------------------------

# 6. 阶段 4 — 简单 Patrol V0

## 目标

让集合完成的小队真正一起巡逻。

本轮不做正式 Settlement Patrol Ring。

先使用简单可靠方案：

``` text
Base / Barracks 周围
P1
P2
P3
P4
```

可以是场景节点，也可以根据 Base 位置生成简单矩形/环形测试点。

优先选择最容易稳定测试的实现。

## 集合条件

``` text
所有本轮 Patrol Group 成员
↓
抵达各自 Assemble Position
↓
Group Ready
↓
开始 Patrol
```

不要一个人到了就先跑。

## 巡逻

``` text
ASSEMBLE
↓
P1
↓
P2
↓
P3
↓
P4
↓
RETURN_TO_BARRACKS
```

成员可以各自 NavigationAgent 寻路，不要求严格队形系统。

本轮只要求视觉上是同一批一起行动。

## 消耗

进入 PATROL 后：

``` text
activity = WORKING
```

让现有 Hunger / Fatigue 按工作状态继续变化。

## 阶段 4 测试

确认：

``` text
3 人门口集合
↓
全部到齐
↓
一起离开
↓
经过所有 Patrol Points
↓
不会随机散开到完全无关区域
↓
最终返回军营
```

**完成后停止。**

------------------------------------------------------------------------

# 7. 阶段 5 — 返回、隐藏与轮班循环

## 返回

巡逻路线完成：

``` text
PATROL
↓
RETURN_TO_BARRACKS
↓
真实走向 Barracks Entrance
↓
抵达
↓
隐藏
↓
恢复内部 IDLE
```

## 换班

第一组完全返回后：

``` text
Group A
→ 留营

Group B
→ 出营
→ Assemble
→ Patrol
→ Return
```

然后循环。

V0 可以使用简单：

``` text
Patrol → Return → Next Group
```

不需要现在实现复杂提前准备时间。

## 重要

不要出现：

``` text
A 组还没回来
B 组已经开始巡逻
```

除非后续设计明确需要。

V0 先保证轮班清晰稳定。

## 阶段 5 测试

重点：

``` text
6 人
→ 3 人巡逻
→ 返回并隐藏
→ 另外 3 人出现
→ 巡逻
→ 返回
→ 第一组再次出发
```

至少连续运行多个周期。

同时测试：

``` text
1 人
2 人
3 人
4 人
5 人
6 人
```

确认不会：

``` text
重复出勤
单位丢失
单位永久隐藏
一个单位同时属于两组
Garrison Count 错误
Navigation 卡死
```

**完成后停止。**

------------------------------------------------------------------------

# 8. 阶段 6 — V0 回归与异常处理

本阶段不加新玩法，只收口。

至少检查：

## 军营被删除/摧毁（若当前已有删除机制）

``` text
驻军解除
↓
重新显示
↓
寻找其他 Barracks
↓
没有则回 Base
```

如果当前工程还没有正式建筑摧毁流程，只保证删除测试不会造成永久锁死即可。

## 新军营建成

Base 待命的 Swordsman 应重新寻找空位。

## Needs

确认：

``` text
军营内部 Hunger / Fatigue 仍在更新
PATROL 使用 WORKING
返回后恢复 V0 的 IDLE
```

本轮不要求解决“饿了去哪里吃”。

## Population

驻军、隐藏、巡逻都不能改变 Population。

------------------------------------------------------------------------

# 9. 本轮明确不做

客户端不要顺手加入：

``` text
军营 FOOD Storage
军营内部 Eating
军营内部 Resting
军粮 < 30% 自动补给
驻军搬粮
战备 Hunger 维护线
战备 Fatigue 维护线
PREPARE_FOR_PATROL
正式 READY 检查
吃饱再出巡
门口等待正在吃饭的成员
严重疲劳替补
受伤替补

正式 Settlement Territory
正式 Settlement Patrol Ring
玩家设置巡逻区域 / 防区

Threat Detection
Slime
Wolf
Bandit
Faction
Health
Damage
Attack
Death

Wall
Rift
Wave
Boss
```

以上是已经确定的后续方向，不属于当前 V0。

------------------------------------------------------------------------

# 10. 下一轮：Barracks Logistics V1

V0 跑稳后，再加入我们已经确定的完整军事后勤：

``` text
Barracks FOOD Storage
↓
驻军进入军营后隐藏
↓
在内部吃饭 / 休息
↓
待命人员主动维持战备状态
↓
Hunger 低于维护线 → 主动吃饭
Fatigue 高于维护线 → 主动休息
↓
FOOD < 30%
↓
选择状态合适的非巡逻驻军
↓
去 Base / Storage 搬 FOOD
↓
RESUPPLY = WORKING
↓
返回军营补充军粮
↓
恢复自身状态
↓
READY
```

正常情况下：

``` text
轮到巡逻
↓
士兵已经处于 READY
↓
直接出营集合
```

出勤前检查只作为兜底。

以后允许出现有表现力的情况：

``` text
A READY → 先出门等待
B READY → 先出门等待
C 因异常状态正在吃饭
↓
C 吃完出门
↓
三人集合完成
↓
一起巡逻
```

但这属于下一轮，不阻塞当前 V0。

------------------------------------------------------------------------

# 11. 客户端执行规则

必须逐阶段执行：

``` text
阶段 1
→ 实现
→ 汇报
→ 用户测试
→ 用户确认

阶段 2
→ 实现
→ 汇报
→ 用户测试
→ 用户确认

...
```

每阶段汇报：

``` text
1. 修改文件
2. 新增文件
3. 核心实现
4. 测试步骤
5. 已知限制
```

未经用户确认，不进入下一阶段。

# 12. 本轮唯一核心验收

> **训练完成的 Swordsman
> 能在没有玩家微操的情况下自动进入军营；军营能够自动派出约一半驻军，在门口集合后一起完成一轮简单巡逻，返回隐藏，再由另一班接替，并持续稳定循环。**

做到这里，`Barracks / Patrol V0` 完成。
