# GPT Game：居民生活循环 V1（流程优先版）

## 0. 本章目标

当前阶段只做一件事：

> **先把居民"活着 → 饥饿/疲劳 → 吃饭/休息 →
> 恢复原行为"的完整流程稳定跑通。**

不要在这一章把饮食、幸福感、饿死、住宅、复杂 Trait 等全部做完。

当前项目核心仍然是：

``` text
真实居民与物流
→ 据点经营
→ 备战
→ 守城
→ BOSS
```

居民生活系统是这个大循环的基础，不是游戏最终目的。

------------------------------------------------------------------------

# 1. V1 最终要跑通的流程

## 有工作的居民

``` text
正常工作
↓
根据实际 Activity 持续增加 Hunger / Fatigue
↓
Hunger 达到阈值？
├─ 是 → 前往 Base → 吃饭约 5 秒
└─ 否

Fatigue 达到阈值？
├─ 是 → 前往 Base → 休息
└─ 否

↓
重新检查 Needs
↓
需求满足
↓
恢复原 Job / Workplace
↓
继续工作
```

## 无业居民

``` text
Idle
↓
仍然持续消耗食物
↓
Hunger 缓慢上涨
↓
饿了
↓
Base 吃饭
↓
继续 Idle
```

无业居民不能因为"没有工作"而不需要吃饭。

------------------------------------------------------------------------

# 2. Hunger / Fatigue 基本规则

统一采用：

``` text
0   = 状态最好
100 = 状态最差
```

因此：

``` text
Hunger
0   = 吃饱
100 = 极度饥饿

Fatigue
0   = 精力充足
100 = 极度疲劳
```

UI 统一：

``` text
绿色 → 黄色 → 红色
```

数值越高越危险。

------------------------------------------------------------------------

# 3. ActivityLevel

不能根据 Job 判断消耗。

应该根据居民**当前实际行为**判断。

V1：

``` text
RESTING
NORMAL
WORKING
COMBAT
```

建议初始 Hunger 倍率：

``` text
RESTING   ×0.7
NORMAL    ×1.0
WORKING   ×1.5
COMBAT    ×1.8
```

COMBAT 目前只预留。

例如：

``` text
Idle / 普通移动
→ NORMAL

砍树 / 采石 / 搬运 / 施工
→ WORKING

正式休息
→ RESTING

未来战斗
→ COMBAT
```

直接随时间累计：

``` gdscript
hunger += delta * base_hunger_rate * activity_multiplier
```

不需要额外统计过去多少百分比时间在工作。

Fatigue 同样根据 Activity 更新：

``` text
NORMAL
→ 极慢增长或基本不增长

WORKING
→ 正常增长

RESTING
→ 持续恢复

COMBAT
→ 以后快速增长
```

所有倍率、阈值、恢复速度集中配置，避免散落魔法数字。

------------------------------------------------------------------------

# 4. 吃饭与休息必须独立

禁止：

``` text
饿了
→ 吃饭
→ 强制睡觉
```

应该：

``` text
Hunger → NeedEat
Fatigue → NeedRest
```

居民可能：

``` text
只饿
只累
又饿又累
什么需求都没有
```

每完成一个需求行为：

``` text
evaluate_needs()
```

重新判断下一步。

例如：

``` text
又饿又累
↓
回 Base
↓
吃饭
↓
仍然很累
↓
直接休息
↓
恢复工作
```

不要吃完走出 Base 后又立刻转身回来休息。

------------------------------------------------------------------------

# 5. Job / Workplace 必须保留

例如：

``` text
Job = MINER
Workplace = Quarry
```

矿工去吃饭/休息期间仍然保持这些信息。

生活行为只是暂时打断：

``` text
GO_TO_EAT
EATING
GO_TO_REST
RESTING
```

结束：

``` text
resume_normal_behavior()
```

然后继续原来的工作。

禁止为了吃饭：

``` gdscript
assign_job(Job.NONE)
```

------------------------------------------------------------------------

# 6. V1 食物规则：先通用，但不做复杂饮食模拟

## 6.1 不允许写死 GRAIN

居民需要的是：

``` text
FOOD
```

而不是：

``` text
GRAIN
```

寻找食物时必须通过现有：

``` text
ResourceData
FoodProperties
ResourceDatabase
```

判断：

``` text
resource.is_food()
```

因此以后增加：

``` text
GRAIN
MEAT
BREAD
高级料理
```

不需要重写居民吃饭流程。

------------------------------------------------------------------------

# 7. 食物偏好：本章记录设计，V1 只保留扩展入口

未来居民支持：

``` text
喜欢的食物
普通食物
讨厌的食物
禁止食用的食物（可选扩展）
```

未来选择优先级：

``` text
可用食物
↓
① 喜欢
↓ 没有
② 普通
↓ 没有
③ 讨厌
↓ 都没有
挨饿
```

"讨厌"不等于"不吃"。

真正没有其他选择时仍然会吃讨厌的食物。

未来效果可以类似：

``` text
喜欢      nutrition × 1.2
普通      nutrition × 1.0
讨厌      nutrition × 0.6
```

具体数值以后平衡。

偏好优先考虑通过：

``` text
Trait
+
ResourceData.tags
```

表达。

例如：

``` text
Trait：喜欢肉类
preferred_food_tags = [&"meat"]

Trait：讨厌谷物
disliked_food_tags = [&"grain"]
```

### V1 要求

本章**不要完整开发食物偏好系统**。

但进食代码必须提供通用入口，例如概念上的：

``` text
find_available_food()
choose_food()
consume_food()
```

禁止直接：

``` text
take_resource(&"grain", 1)
```

这样以后加入偏好时只扩展 `choose_food()`，不用重写整个进食状态机。

------------------------------------------------------------------------

# 8. 饥饿死亡：本章只记录，不正式实现

未来规则：

``` text
Hunger 达到红色阈值
↓
主动寻找食物
↓
Hunger = 100
↓
进入 Starvation
↓
持续没有食物
↓
Starvation Time 增长
↓
未来通过 HealthComponent 造成伤害
↓
HP = 0
↓
饿死
```

不要：

``` text
Hunger = 100
→ 瞬间死亡
```

V1 暂时：

``` text
Hunger clamp 到 100
```

允许预留：

``` text
is_starving()
starvation_time
```

但不要建立一套 Villager 专用死亡系统。

等后续战斗章节建立：

``` text
HealthComponent
```

以后再把 Starvation 接到统一生命/伤害/死亡系统。

------------------------------------------------------------------------

# 9. VillagerPanel 正式加入 Needs UI

本章从第一阶段开始就加入 UI，方便每一步实际测试。

建议：

``` text
职业：矿工
状态：正在采石

饥饿
[██████████░░░░░░] 62%

疲劳
[██████░░░░░░░░░░] 38%
```

ProgressBar：

``` text
低值 → 绿色
中值 → 黄色
高值 → 红色
```

优先连续：

``` text
绿 → 黄 → 红
```

如果实现不方便，V1 可以：

``` text
0~49    绿色
50~74   黄色
75~100  红色
```

但更新逻辑集中封装，不要 Hunger/Fatigue 各复制大量 UI 代码。

必须实时刷新，不需要重新点击居民才能看到变化。

------------------------------------------------------------------------

# 10. 分阶段开发规则

**每阶段必须由用户实际运行测试。**

客户端必须：

1.  一次只执行一个阶段。
2.  完成后进行静态检查。
3.  汇报新增/修改文件。
4.  说明测试方法。
5.  **立即停止。**
6.  等用户回复"正常 / 继续"。
7.  才能进入下一阶段。
8.  测试失败时只修当前阶段。
9.  禁止提前开发后续阶段。

------------------------------------------------------------------------

# 阶段 1：Needs 数据 + UI

## 开发

建立：

``` text
Hunger
Fatigue
ActivityLevel
```

优先考虑：

``` text
VillagerNeeds
```

独立组件。

但应结合当前工程架构，不为了组件化破坏已经稳定的 Villager。

实现：

``` text
update_needs(delta)
is_hungry()
is_tired()
```

以及集中配置的：

``` text
BASE_HUNGER_RATE
HUNGRY_THRESHOLD
TIRED_THRESHOLD
RESTED_THRESHOLD
Activity 倍率
```

本阶段只累计数值。

**不自动吃饭。** **不自动休息。**

## UI

VillagerPanel 新增：

``` text
Hunger ProgressBar
Fatigue ProgressBar
```

实时刷新，绿→黄→红。

## 用户测试

分别观察：

``` text
无业居民
伐木工
矿工
```

预期：

``` text
无业居民：
Hunger 缓慢上涨
Fatigue 基本不涨/极慢

工作居民：
实际工作时 Hunger 更快
Fatigue 正常上涨
```

完成后停止。

------------------------------------------------------------------------

# 阶段 2：GRAIN 初始库存 + 通用 FOOD 查询

## 开发

通过现有 LevelConfig / Base 初始化系统加入一定测试用：

``` text
GRAIN
```

不要开发农场。

确认：

``` text
ResourceDatabase
ResourceStorage
ResourceManager
HUD / BasePanel
```

可以正常处理 GRAIN。

建立通用：

``` text
find_available_food()
```

查询所有：

``` text
ResourceData.is_food() == true
```

的库存。

不要写死 GRAIN。

可以建立：

``` text
choose_food()
```

V1 暂时使用最简单策略：

``` text
从可用食物中选择一种
```

复杂"喜欢/普通/讨厌"只留扩展点。

## 用户测试

确认：

``` text
Base 有 GRAIN
HUD/资源面板数量正确
系统能识别 GRAIN 是 FOOD
WOOD / STONE 不受影响
```

完成后停止。

------------------------------------------------------------------------

# 阶段 3：进食流程

## 流程

``` text
Hunger 达到 HUNGRY_THRESHOLD
↓
NeedEat
↓
find_food_location()
↓
Base
↓
重新确认存在 FOOD
↓
EATING
↓
停留约 5 秒
↓
消费选中的 FOOD ×1
↓
根据 FoodProperties.nutrition 降低 Hunger
↓
evaluate_needs()
↓
恢复行为 / 继续处理 Fatigue
```

建议：

``` text
EATING_TIME = 5.0
```

集中配置。

## 注意

进入 EATING 前重新检查库存。

多人同时吃最后一份食物时：

``` text
库存不能负数
不能报错
不能卡状态机
```

V1 可以暂时不做完整 Reservation。

## FOOD = 0

居民：

``` text
继续保持 Hunger
不会卡死
不会无限状态切换
不会报错
```

暂时不掉 HP。

## 用户测试

观察：

``` text
Hunger 绿→黄→红
↓
居民主动去 Base
↓
停留约5秒
↓
GRAIN减少
↓
Hunger明显下降
↓
返回原工作/Idle
```

测试：

``` text
Lumberjack
Miner
Job.NONE
多人同时吃饭
没有食物
```

完成后停止。

------------------------------------------------------------------------

# 阶段 4：休息流程

## 流程

``` text
Fatigue >= TIRED_THRESHOLD
↓
NeedRest
↓
find_rest_location()
↓
Base
↓
RESTING
↓
fatigue -= recovery_rate * delta
↓
Fatigue <= RESTED_THRESHOLD
或达到 MAX_REST_TIME
↓
结束
```

建议：

``` text
MAX_REST_TIME ≈ 20 秒
```

但不是所有居民固定休息 20 秒。

轻度疲劳可能更早恢复。

## 休息期间

``` text
Activity = RESTING
Hunger multiplier ≈ 0.7
```

居民休息时仍然会缓慢变饿。

## 用户测试

观察：

``` text
Fatigue 上涨
↓
变红
↓
回 Base
↓
RESTING
↓
Fatigue ProgressBar 持续下降
↓
颜色逐渐回绿
↓
返回原工作
```

无业居民通常不应该频繁需要正式休息。

完成后停止。

------------------------------------------------------------------------

# 阶段 5：Hunger + Fatigue 联合处理

处理四种情况：

``` text
只饿
只累
又饿又累
都不需要
```

如果居民已经在 Base：

``` text
吃完
↓
发现仍然很累
↓
直接休息
```

或者：

``` text
休息结束
↓
已经很饿
↓
直接吃饭
```

不要：

``` text
离开 Base
→ 马上掉头回来
```

V1 可以让严重 Hunger 优先。

但建议统一通过：

``` text
evaluate_needs()
```

管理，方便以后增加：

``` text
战斗
逃跑
生命危险
```

等更高优先级行为。

## 用户测试

重点让 Hunger / Fatigue 同时处于高值，确认：

``` text
一次回 Base
→ 正确处理两个需求
→ 返回工作
```

完成后停止。

------------------------------------------------------------------------

# 阶段 6：Job / Task 中断安全

专门测试生活需求与现有系统冲突。

场景：

``` text
砍树时饿
采石时累
施工时饿
搬施工材料时饿
建筑完工时触发 Needs
工作建筑失效
解雇前后触发 Needs
```

## 运输原则

如果居民：

``` text
carried_amount > 0
```

特别是施工材料：

``` text
先完成当前安全运输步骤
↓
再处理 Needs
```

避免资源丢失。

公共 Task 如果允许安全中断：

``` text
release / unclaim
```

不能：

``` text
居民去吃饭
但 Task 永远被占用
```

## 用户测试

完整回归：

``` text
Lumberjack
Miner
Idle Villager
施工运输
多人施工
招募/解雇
```

完成后停止。

------------------------------------------------------------------------

# 阶段 7：生活循环 UI / 状态文本整理

VillagerPanel 正式显示：

``` text
职业
当前状态
工作地点

Hunger ProgressBar
Fatigue ProgressBar

携带资源
Task
```

状态文本能够显示：

``` text
前往吃饭
正在吃饭
前往休息
正在休息
```

### 食物偏好 UI

本章不要求正式实现。

但 README/ROADMAP 记录未来 VillagerPanel 可以加入：

``` text
喜欢食物
讨厌食物
```

等 FoodPreference 正式开发后再显示。

## 用户测试

连续选中居民观察完整生命周期，不依赖 Console。

同时确认：

``` text
切换居民
关闭面板
点击空地关闭
其他对象 Panel
```

原功能正常。

完成后停止。

------------------------------------------------------------------------

# 阶段 8：完整回归 + 文档更新

完整测试：

``` text
无业居民
→ 待机
→ 饥饿
→ 吃饭
→ 待机

伐木工
→ 工作
→ 饥饿/疲劳
→ 吃饭/休息
→ 返回伐木

矿工
→ 工作
→ 饥饿/疲劳
→ 吃饭/休息
→ 返回采石
```

多人：

``` text
同时吃饭
同时休息
FOOD不足
```

施工：

``` text
Needs
+
TaskManager
+
ConstructionSite
```

不得互相破坏。

------------------------------------------------------------------------

# 11. README 更新要求

全部完成后记录：

``` text
Villager Needs V1                 ✅
Hunger                           ✅
Fatigue                          ✅
ActivityLevel                    ✅
Idle 也消耗食物                   ✅
工作 Hunger 消耗更快              ✅
EATING_TIME                      ✅
FoodProperties.nutrition         ✅
通用 FOOD 查询                   ✅
choose_food() 扩展入口            ✅
RESTING 持续恢复                  ✅
吃饭/休息独立                     ✅
Job/Workplace 保持                ✅
Task 中断安全                     ✅
VillagerPanel Needs UI           ✅
绿→黄→红                         ✅
```

同时记录"已设计但未开发"：

``` text
FoodPreference
├─ Preferred
├─ Neutral
├─ Disliked
└─ Forbidden（可选）

Starvation
↓
未来 HealthComponent
↓
饿死
```

------------------------------------------------------------------------

# 12. ROADMAP 更新要求

当前：

``` text
居民生活循环 V1
```

完成后：

``` text
基础食物来源 V1
↓
House / 人口最小版
↓
训练建筑
↓
第一个战斗职业
↓
城墙
↓
Enemy
↓
Wave
↓
Boss
```

后期生活系统扩展：

``` text
FoodPreference
Trait 食物喜好
不同 Food nutrition
Food quality
饮食多样性
Starvation
HealthComponent 饥饿伤害
House 正式休息地点
高级料理
战前伙食 Buff
```

这些都不能阻塞第一版守城流程。

------------------------------------------------------------------------

# 13. 明确暂缓

本章不要顺手开发：

``` text
完整 FoodPreference
复杂 Trait 饮食
饮食多样性
幸福感
农场完整产业
肉类产业
面粉/面包生产
高级料理
House床位
食堂容量
排队
饿死
HealthComponent
敌人
士兵
城墙
Wave
Boss
```

**先跑通流程。**

------------------------------------------------------------------------

# 14. 第一次执行指令

客户端第一次读取本文档：

## 只执行阶段 1

``` text
Villager Needs 数据
+
Hunger
+
Fatigue
+
ActivityLevel
+
VillagerPanel Hunger/Fatigue 实时进度条
```

不要自动吃饭。

不要自动休息。

不要改食物库存。

完成后汇报并停止，等待用户实际测试。
