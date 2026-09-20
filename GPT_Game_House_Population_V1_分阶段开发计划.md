# 时间裂缝：House / Population V1 分阶段开发计划

> 当前前置：居民生活循环 V1 ✅、Farm / GRAIN V1 ✅\
> 本阶段目标：完成"住房 → 移民 → 新居民 → 新劳动力 →
> 更多食物消耗"的人口闭环。\
> 原则：**人口不能通过支付资源直接购买并凭空生成。**

------------------------------------------------------------------------

# 0. 最终要跑通的闭环

``` text
初始居民
↓
砍树 / 采石 / 种田
↓
建造 House
↓
Housing Capacity 增加
↓
据点满足基本 FOOD 条件
↓
等待移民
↓
Migrant 从地图外围真实出现
↓
走向 Base
↓
正式加入 Villager
↓
Population 增加
↓
新居民可以工作
↓
同时产生 Hunger / Fatigue
↓
FOOD 消耗增加
↓
玩家继续扩张生产与住房
```

House 的作用是提供居住容量，不是"生产人口"。

------------------------------------------------------------------------

# 1. V1 范围

本阶段只实现普通 Immigration。

人口来源：

``` text
Population
├─ Immigration     ← 本次实现
└─ Expedition      ← 以后
```

本次不实现：

``` text
探险小屋
救援人口
随机事件人口
生育
儿童
家庭
幸福度
特殊职业移民
复杂安全度
BossModifier
```

------------------------------------------------------------------------

# 2. House V1

建议第一版：

``` text
House
占地：2×2
Housing Capacity：+3
```

如果当前美术/网格尺寸更适合其他大小，可以保持项目现有比例，但容量必须数据化。

House 继续使用当前统一建筑流程：

``` text
BuildingData
↓
Blueprint
↓
Ghost
↓
Grid
↓
旋转 / 镜像
↓
ConstructionSite
↓
真实材料运输
↓
施工
↓
House
```

不要建立 House 专用建造系统。

House 建成：

``` text
housing_capacity += house.capacity
```

House 被拆除/摧毁：

``` text
housing_capacity -= house.capacity
```

注意：

> 房屋被摧毁后可以出现 Population \> Housing Capacity。

不要因为超员直接删除居民。

例如：

``` text
Population = 8
Capacity = 8

House 被毁：
Capacity = 5

结果：
Population = 8 / 5
```

此时只是"住房不足"，禁止继续普通移民。

以后再考虑住房不足的长期惩罚。

------------------------------------------------------------------------

# 3. PopulationManager

建立统一 PopulationManager，负责：

``` text
current_population
housing_capacity
free_housing
immigration 状态
arrival timer
```

推荐人口数量根据真实居民注册/注销维护，而不是 UI 自己统计场景节点。

需要明确接口，例如概念：

``` text
register_villager()
unregister_villager()

register_housing()
unregister_housing()

get_population()
get_housing_capacity()
get_free_housing()
```

具体命名遵循当前工程风格。

以后：

``` text
Villager 死亡
Migrant 加入
Expedition 带回居民
特殊事件加入居民
```

都应通过统一人口入口更新 Population。

------------------------------------------------------------------------

# 4. ImmigrationRules

移民规则不要散落硬编码。

V1 建立一个简单、可配置的数据入口：

``` text
ImmigrationRules
├─ minimum_food_reserve
├─ food_per_migrant
├─ required_free_housing
├─ arrival_interval
├─ min_group_size
└─ max_group_size
```

不一定必须新建
Resource；如果当前项目已有统一关卡配置/规则数据结构，应优先接入现有体系。

关键要求：

> PopulationManager 不要到处出现固定的 `food >= 30`、`capacity >= 2`。

以后 Boss、Difficulty、Event 可以修改这些规则。

本次不实现 Modifier，只把基础参数集中起来。

------------------------------------------------------------------------

# 5. FOOD 条件不是人口购买价格

禁止：

``` text
30 GRAIN
↓
点击招募
↓
-30 GRAIN
↓
+1 Villager
```

FOOD 是"据点能否承载新人口"的条件。

例如概念：

``` text
当前 Population = 5
准备到来 Migrants = 2

需要：
Free Housing >= 2

以及：
Available FOOD >=
minimum_food_reserve
+
food_per_migrant × 2
```

满足后才允许移民等待/到来。

**移民到来时不直接扣除这部分 FOOD。**

新居民加入后会通过正常 Hunger 系统持续消耗 FOOD。

这样 FOOD 的代价来自真实人口长期消费，而不是一次性购买。

------------------------------------------------------------------------

# 6. FOOD 统计

移民条件使用当前 ResourceManager 的"总可用 FOOD"概念。

不能只检查：

``` text
GRAIN
```

因为以后还有：

``` text
MEAT
FISH
二级食品
```

建议通过：

``` text
ResourceData.is_food()
```

统计所有 FOOD。

因此以后：

``` text
GRAIN = 10
MEAT = 5
FISH = 5
```

应该可以被人口系统视为：

``` text
Total FOOD = 20
```

具体是否按 nutrition 加权属于后期平衡，本次 V1 可以先按资源数量统计。

------------------------------------------------------------------------

# 7. Immigration 状态

建议 PopulationManager 有清晰状态：

``` text
WAITING_FOR_REQUIREMENTS
↓
条件满足
COUNTDOWN
↓
计时完成
SPAWNING
↓
生成 Migrants
↓
WAITING_FOR_REQUIREMENTS
```

如果 COUNTDOWN 期间条件失效，例如：

``` text
粮食被吃掉
House 被毁
Population 已达到 Capacity
```

V1 建议：

``` text
暂停 / 取消本轮 Countdown
```

并在条件重新满足后重新开始。

不要让已经不具备住房条件的据点继续凭空刷人口。

------------------------------------------------------------------------

# 8. Migrant

Migrant 第一版不要重新做完整角色系统。

优先复用 Villager 场景/移动能力。

概念上增加一个短暂状态：

``` text
MIGRATING
```

或建立轻量 MigrantController。

流程：

``` text
ArrivalPoint
↓
生成 Migrant
↓
目标 = Base Arrival / Join Point
↓
正常 NavAgent 移动
↓
抵达 Base
↓
register_villager()
↓
切换为普通 Villager
↓
Job = NONE
↓
进入正常生活循环
```

重点：

> 人口只有在 Migrant 真正抵达据点后才增加。

不能生成在地图边缘的一瞬间就算正式 Population。

------------------------------------------------------------------------

# 9. ArrivalPoint

Level 中增加：

``` text
ArrivalPoints
├─ ArrivalPoint_A
├─ ArrivalPoint_B
└─ ...
```

V1 可以只有 1\~2 个。

PopulationManager 每次随机选择可用 ArrivalPoint。

要求：

``` text
ArrivalPoint
→ Base
```

必须存在可导航路径。

以后程序化地图可以自动生成 ArrivalPoint。

当前不要开发程序化生成。

------------------------------------------------------------------------

# 10. Migrant 到达表现

第一版不用复杂事件 UI。

最低表现：

``` text
“新的移民正在前往据点”
```

地图上可以实际看到居民从外围走来。

抵达：

``` text
“2 名移民加入了据点”
```

HUD：

``` text
Population
5 / 8
↓
7 / 8
```

以后再增加：

``` text
姓名
Trait
来历
特殊职业
事件文本
```

------------------------------------------------------------------------

# 11. 新居民初始化

Migrant 成为 Villager 后必须走统一初始化流程。

至少保证：

``` text
Job = NONE
Workplace = null

Hunger = 合理初始值
Fatigue = 合理初始值

Trait
使用当前普通居民生成规则

Task
无残留

Population
已注册
```

新居民之后：

``` text
可以被 LumberCamp 招募
可以被 Quarry 招募
可以被 Farm 招募
可以承担公共 Task
会 Hunger
会 Fatigue
会 Eating
会 Resting
```

禁止为了 Migrant 复制第二套 Villager 逻辑。

------------------------------------------------------------------------

# 12. HUD

HUD 增加人口总览：

``` text
人口：5 / 8
```

含义：

``` text
5 = 当前正式 Villager
8 = Housing Capacity
```

如果住房被毁：

``` text
人口：8 / 5
```

必须允许显示超员。

后期详细人口面板再显示：

``` text
Idle
Farmer
Lumberjack
Miner
Soldier
Housing
Food
```

V1 不需要。

------------------------------------------------------------------------

# 13. House UI

House 点击后使用当前建筑详情体系。

最低显示：

``` text
住宅

住房容量：+3
当前总人口：5 / 8
```

以后再加入：

``` text
实际入住居民
休息床位
幸福度
升级
```

V1 不做居民绑定房屋。

也就是说：

> Housing Capacity 第一版是全局容量，不需要指定"这个居民住哪栋 House"。

这样可以避免提前进入家庭/床位管理。

------------------------------------------------------------------------

# 14. Base 初始住房

关卡必须明确初始居民为什么有住房。

建议 Base 自带：

``` text
base_housing_capacity
```

例如开局：

``` text
Villager = 5
Base Capacity = 5
```

因此：

``` text
Population = 5 / 5
```

玩家想继续增加人口必须建 House。

不要让第一关开局直接处于：

``` text
5 / 0
```

------------------------------------------------------------------------

# 15. 与 LevelConfig 的关系

不同关卡未来可能有：

``` text
initial_population
base_housing_capacity
initial_resources
immigration_rules
```

这些应该由关卡配置控制，而不是写死在 PopulationManager。

例如：

``` text
Level 01
initial_population = 5
base_housing_capacity = 5
```

未来挑战关：

``` text
initial_population = 3
base_housing_capacity = 3
```

本次如果已有 LevelConfig，请优先扩展。

不要重新建立重复的关卡配置系统。

------------------------------------------------------------------------

# 16. 与 Needs 的关系

新增人口以后，当前 Hunger / Fatigue 系统必须自然承担人口成本。

例如：

``` text
5 Villagers
↓
新增 2 Migrants
↓
7 Villagers
↓
FOOD 消耗自然提高
```

不要 PopulationManager 自己按人口：

``` text
每分钟 -FOOD
```

否则会和居民 Eating 产生双重消耗。

人口系统只决定：

``` text
谁能加入
```

FOOD 实际消耗仍然由：

``` text
Villager Hunger
→ Eating
```

产生。

------------------------------------------------------------------------

# 17. 与 Farm 的关系

Population V1 完成后要重点验证：

``` text
Farm 产粮
↓
FOOD 储备满足移民条件
↓
House 有空位
↓
Migrant 到来
↓
人口增加
↓
Eating 人数增加
↓
粮食下降更快
```

这将形成目前第一个完整经营反馈循环。

------------------------------------------------------------------------

# 18. 为 BossModifier 留接口，但本次不实现

未来：

``` text
BossModifier
↓
minimum_food_reserve
food_per_migrant
required_free_housing
arrival_interval
group_size
```

例如：

``` text
饥荒 Boss
→ FOOD Requirement +100%

恐惧 Boss
→ Arrival Interval +50%
```

本次只要求 ImmigrationRules 集中配置。

禁止现在开发 BossModifier。

------------------------------------------------------------------------

# 19. 为 Expedition 留统一人口入口

未来 Expedition 可能：

``` text
3人出发
↓
遇到流浪剑客
↓
4人归来
↓
新成员成为 Villager
```

因此 PopulationManager 应提供统一：

``` text
add / register villager
```

入口。

不要让 Immigration 成为唯一能增加人口的私有逻辑。

但本次禁止开发 Expedition。

------------------------------------------------------------------------

# 20. 分阶段执行规则

继续使用当前开发方式：

> **每阶段完成后必须让用户实际测试。**

客户端执行要求：

1.  第一次只执行阶段 1。
2.  完成后做静态检查。
3.  汇报修改文件和实现内容。
4.  给出用户测试方法。
5.  立即停止。
6.  等用户回复"正常 / 继续"。
7.  再执行下一阶段。
8.  测试失败只修当前阶段。
9.  禁止提前开发后续阶段。

------------------------------------------------------------------------

# 阶段 1：PopulationManager + HUD

## 实现

建立：

``` text
PopulationManager
```

先只统计现有居民和住房容量。

Base 提供初始 Housing Capacity。

HUD 增加：

``` text
人口：X / Y
```

本阶段不建 House，不生成 Migrant。

## 测试

开局例如：

``` text
5 / 5
```

确认人口数量与场景真实居民一致。

调试增删 Villager 时人口数字正确更新。

确认 Resource / Farm / Needs 无回归。

**完成后停止。**

------------------------------------------------------------------------

# 阶段 2：House + Housing Capacity

## 实现

新增 House：

``` text
2×2
Housing Capacity +3
```

接入现有：

``` text
BuildingData
Ghost
Grid
ConstructionSite
施工
Building UI
```

建成后：

``` text
5 / 5
→
5 / 8
```

拆除/销毁时容量减少。

## 测试

建 1 栋：

``` text
5 / 8
```

再建 1 栋：

``` text
5 / 11
```

测试旋转/镜像/施工。

测试 House 被删除/摧毁后容量正确回退。

**完成后停止。**

------------------------------------------------------------------------

# 阶段 3：ImmigrationRules + 条件判断

## 实现

集中建立 V1 参数：

``` text
minimum_food_reserve
food_per_migrant
required_free_housing
arrival_interval
min_group_size
max_group_size
```

实现：

``` text
can_start_immigration()
```

或项目风格下的等价接口。

FOOD 使用所有 `is_food()` Resource 统计。

本阶段先不生成 Migrant。

## 调试 UI / Console

能够明确看到：

``` text
住房满足：YES
FOOD 满足：YES
预计移民人数：2
移民等待：可以开始
```

## 测试

分别验证：

``` text
无空房 → FALSE
有房无粮 → FALSE
有房有粮 → TRUE
```

**完成后停止。**

------------------------------------------------------------------------

# 阶段 4：Immigration Countdown

## 实现

条件满足：

``` text
WAITING
→ COUNTDOWN
```

倒计时结束触发：

``` text
immigration_ready
```

本阶段可以先只打印：

``` text
“移民准备到来：2人”
```

不生成实际角色。

条件中途失效则取消/重置倒计时。

## 测试

验证：

``` text
有房有粮
→ 倒计时开始

中途粮食不足
→ 取消

恢复粮食
→ 重新开始

倒计时完成
→ 正确触发一次
```

不能连续每帧触发。

**完成后停止。**

------------------------------------------------------------------------

# 阶段 5：ArrivalPoint + Migrant 实体

## 实现

Level 增加 ArrivalPoint。

倒计时完成：

``` text
随机 ArrivalPoint
↓
生成 Migrant
↓
走向 Base
```

Migrant 此时：

``` text
不计入正式 Population
```

## 测试

实际看到 1\~N 个居民从地图外围出现并走向 Base。

确认：

``` text
生成时 Population 不增加
```

**完成后停止。**

------------------------------------------------------------------------

# 阶段 6：Migrant → Villager

## 实现

Migrant 抵达 Base：

``` text
加入据点
↓
注册 Population
↓
变成普通 Villager
↓
Job = NONE
↓
进入正常 Needs / Task 系统
```

HUD：

``` text
5 / 8
→
7 / 8
```

## 测试

新居民可以：

``` text
点击查看
招募为 Farmer
招募为 Lumberjack
招募为 Miner
参加施工 / 搬运
吃饭
休息
```

**完成后停止。**

------------------------------------------------------------------------

# 阶段 7：完整人口经济闭环

## 测试流程

从开局：

``` text
5 / 5
```

开始。

玩家：

``` text
砍树 / 采石
↓
建 Farm
↓
生产 GRAIN
↓
建 House
↓
5 / 8
↓
满足 FOOD
↓
等待
↓
移民从外围走来
↓
7 / 8
↓
粮食消耗提高
↓
安排新居民工作
```

重点观察：

``` text
人口增长是否有价值
新增人口是否带来明显 FOOD 压力
Farm 是否能支撑当前人口
空闲居民是否能正常施工/物流
```

不要现在调最终平衡。

**完成后停止并由用户试玩。**

------------------------------------------------------------------------

# 阶段 8：异常情况回归

测试：

### House 在 Migrant 路上被毁

``` text
Migrant 尚未加入
↓
Capacity 不足
```

V1 建议：

-   已经实际出发的 Migrant 可以继续抵达；
-   抵达后允许形成临时超员；
-   后续 Immigration 停止。

这样比走到一半凭空消失自然。

### FOOD 在 Migrant 路上不足

已经出发的 Migrant 继续到达。

FOOD 条件只决定：

``` text
是否发起下一批 Immigration
```

不要把正在路上的人删除。

### Population \> Capacity

允许存在。

禁止新 Immigration。

### 多 House

容量正确累计。

### 多批 Migrant

不能超出本轮计算的合理数量。

### 场景重载

PopulationManager 不重复注册居民/住房。

**完成后停止。**

------------------------------------------------------------------------

# 阶段 9：README / ROADMAP

README 按实际完成结果更新：

``` text
PopulationManager             ✅
Population HUD                ✅
Base Housing Capacity         ✅
House V1                      ✅
Housing Capacity              ✅
ImmigrationRules              ✅
Food Requirement              ✅
Immigration Countdown         ✅
ArrivalPoint                  ✅
Migrant                       ✅
Migrant → Villager            ✅
Population / Farm Loop        ✅
```

ROADMAP：

``` text
House / Population V1         ✅
```

当前主线切换：

``` text
Training Building
↓
第一个战斗职业
↓
Health / Combat
```

同时继续保留：

``` text
Expedition                    ⏳
Hunting / MEAT                ⏳
Fishing / FISH                ⏳
FoodPreference                ⏳
Boss Immigration Modifier     ⏳
```

不要完成 Population 后自动开发这些横向系统。

------------------------------------------------------------------------

# 21. 本阶段明确不做

``` text
Expedition Lodge
热气球
探险事件
救援人口
特殊移民
生育
家庭
儿童
居民绑定具体 House
幸福度
房屋舒适度
租金
FoodPreference
MEAT
FISH
BossModifier
复杂 Difficulty Modifier
疾病
人口老化
```

------------------------------------------------------------------------

# 22. Population V1 完成标准

只有下面整条链实际可玩，才算完成：

``` text
初始 5 人
↓
真实生产资源
↓
Farm 生产 FOOD
↓
玩家建 House
↓
Housing Capacity 增加
↓
FOOD + Housing 满足移民条件
↓
等待
↓
Migrant 从外围真实走来
↓
抵达 Base
↓
正式成为 Villager
↓
人口 HUD 增加
↓
新居民参加生产 / 施工 / 物流
↓
新居民正常吃饭 / 休息
↓
人口增加导致 FOOD 消耗自然提高
```

完成这个节点以后：

> **经营 V1 可以视为形成了一个可独立运转的模拟经营骨架。**

随后主线应立即转入：

``` text
训练
→ 战斗职业
→ Health / Combat
→ 城墙
→ Enemy
→ Wave
→ Boss
```

而不是继续横向扩张经营系统。
