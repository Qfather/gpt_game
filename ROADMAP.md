# ROADMAP 更新补丁 — 剑士训练完成 → Barracks / Patrol V0

> 用途：交给客户端合并进当前精简版 `ROADMAP.md`。  
> 原则：ROADMAP
> 保留最终方向，但当前开发只做**可运行的最小版本**，不要提前实现完整军事后勤。

## 当前状态更新

将 Military Daily Loop V1 更新为：

``` text
Military Daily Loop V1
├─ CombatRole / SWORDSMAN                 ✅
├─ 剑士营 2 Training Slots               ✅
├─ 自动领取训练任务                       ✅
├─ Villager → Swordsman                  ✅
│
├─ Barracks / Patrol V0                  ← 当前
│  ├─ 军营 Capacity = 6
│  ├─ Swordsman 自动驻扎
│  ├─ 无军营 → Base 附近待命
│  ├─ 驻军进入军营后隐藏
│  ├─ ceil(Garrison / 2) 自动出巡
│  ├─ 门口集合
│  ├─ 简单自动巡逻路线
│  ├─ 返回军营后隐藏
│  └─ 两班循环换班
│
├─ Barracks Logistics V1                 ⏳ 后续
│  ├─ 军营 FOOD Storage
│  ├─ 驻军在军营内部吃饭 / 休息
│  ├─ 待命期间主动维持战备状态
│  ├─ FOOD < 30% 自动补给
│  ├─ 非巡逻驻军负责搬运
│  ├─ 搬运 = WORKING
│  ├─ 出巡前 Hunger / Fatigue 检查
│  └─ READY 后再出勤
│
├─ Settlement Patrol Ring                ⏳
├─ Threat Detection                      ⏳
└─ Combat V1                             ⏳
```

## 当前 V0 与最终设计的边界

本轮只证明：

``` text
训练出的剑士
↓
自动找到军营
↓
进入军营
↓
自动分班
↓
一半出门集合
↓
一起巡逻
↓
返回军营
↓
另一班接替
```

本轮暂不实现：

``` text
军粮库存
军营内部正式吃饭
军营内部正式休息
30% 军粮补给
战备状态主动维护
READY 出勤检查
替补机制
玩家指定巡逻区域
Settlement Territory 精确外轮廓
第三方敌人
战斗
```

这些规则已经作为最终方向保留，但不能阻塞当前可运行闭环。

## 军营最终定位（保留到 ROADMAP）

军营不是生产士兵的建筑。剑士营负责训练，军营负责组织军事人口。

最终职责：

``` text
Barracks
├─ 驻军
├─ 隐藏式内部待命
├─ 吃饭 / 休息
├─ 军粮储备
├─ 自动补给
├─ 战备维护
├─ 自动轮班
├─ 巡逻
└─ 警戒响应
```

长期规则：

- Capacity = 6。
- 无军营的 Swordsman 在 Base 附近待命，不进行正式常规巡逻。
- 有空位时 Swordsman 自动前往军营，不要求玩家逐个分配。
- 驻军进入建筑后隐藏；执行外部任务时重新显示。
- 和平时期目标巡逻人数 `ceil(GarrisonCount / 2)`。
- 玩家未来只进行战略级设置（例如军营防区），不微操单个士兵巡逻路线。
- 巡逻的最终用途是保护外围生产、发现史莱姆/狼人/盗匪等第三方袭扰、降低损失并提供敌情预警。

## Military Daily Loop 后续顺序

``` text
Barracks / Patrol V0
↓
Barracks Logistics V1
↓
Settlement Patrol Ring
↓
Threat Detection
↓
Combat V1
↓
第一种第三方袭扰
↓
城墙 / 防御
↓
大型时间裂缝随机方向
↓
情报 / 基础侦察
↓
正式 Wave
↓
Boss
↓
Victory / Defeat
```

## 开发纪律

继续沿用：

1.  每个阶段完成后停止。
2.  用户实际运行测试。
3.  客户端说明修改文件、实现内容、测试步骤、已知限制。
4.  用户确认后才进入下一阶段。
5.  当前 V0 不为最终军粮/战备系统做过度实现。
