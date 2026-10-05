# 时间裂缝：Blender → Godot 模块化建筑生产管线

> 目标：**在 Blender 中高效搭建完整建筑，但导入 Godot
> 后自动替换为真正可复用的模块化 Scene。**  
> 原则：Blender 负责“建筑设计与装配”，Godot
> 负责“最终实例化、施工表现和游戏逻辑”。

------------------------------------------------------------------------

# 1. 为什么采用这套方案

三种方案对比：

``` text
方案 A
Blender 拼完整建筑
→ 整体 GLB
→ Godot

优点：搭建方便
缺点：模块复用不够明确
```

``` text
方案 B
Blender 只制作零件
→ Godot 手工拼建筑

优点：真正模块化
缺点：大量建筑在 Godot 中手工摆放效率较低
```

最终采用：

``` text
方案 C

Blender
→ 使用模块搭完整建筑
→ 导出 GLB
→ Godot 读取模块标识和 Transform
→ 自动删除/替换导入 Mesh
→ 实例化正式 PackedScene
→ 保存为建筑 Scene
```

得到：

``` text
Blender 的搭建效率
+
Godot 的真正模块复用
+
自动施工顺序
+
以后可扩展损坏 / 维修 / 升级
```

------------------------------------------------------------------------

# 2. 总体资产结构

核心思想：

``` text
Village Module Library
        │
        ├──────── Blender
        │          预览 / 搭建模块
        │
        └──────── Godot
                   正式模块 Scene
```

两边通过统一的：

``` text
Module ID
```

对应。

例如：

``` text
Module ID:
BEAM_2M_A
```

Blender：

``` text
Beam_2m_A
```

Godot：

``` text
res://art/building_modules/structure/beam_2m_a.tscn
```

它们代表同一个建筑模块。

------------------------------------------------------------------------

# 3. Blender 的职责

Blender 负责：

``` text
制作基础模块
↓
测试模块尺寸
↓
利用模块快速搭建筑
↓
调整位置 / 旋转 / 缩放
↓
设置施工阶段
↓
导出建筑 GLB
```

Blender 中可以看到完整建筑效果。

例如：

``` text
FarmHouse
├─ Beam_2m_A
├─ Beam_2m_A.001
├─ Beam_2m_A.002
├─ Beam_Diagonal_A
├─ Wall_Plaster_A
├─ Wall_Plaster_A.001
├─ Roof_Thatch_A
├─ Roof_Thatch_A.001
├─ Window_Round_A
├─ Barrel_A
└─ Sack_A
```

但是这些 Blender Mesh 最终只是：

> **Godot 自动转换时的模块占位与 Transform 来源。**

------------------------------------------------------------------------

# 4. Godot 的职责

Godot 中维护真正的模块 Scene：

``` text
res://art/building_modules/

structure/
    beam_1m_a.tscn
    beam_2m_a.tscn
    beam_diagonal_a.tscn

walls/
    wall_plaster_a.tscn
    wall_stone_a.tscn
    wall_window_a.tscn

roofs/
    roof_thatch_a.tscn
    roof_ridge_a.tscn
    roof_end_a.tscn

openings/
    door_wood_a.tscn
    window_round_a.tscn

props/
    barrel_a.tscn
    crate_a.tscn
    sack_a.tscn
```

建筑导入后，Blender 原节点被转换为这些 Scene 的实例。

------------------------------------------------------------------------

# 5. 最简单的 V1：先通过名称匹配

第一版不要马上开发复杂插件。

例如 Blender：

``` text
Beam_2m_A
Beam_2m_A.001
Beam_2m_A.002
```

Godot 转换器统一识别为：

``` text
Beam_2m_A
```

然后查询：

``` text
Beam_2m_A
→ beam_2m_a.tscn
```

转换后：

``` text
FarmHouse
├─ Beam_2m_A.tscn Instance
├─ Beam_2m_A.tscn Instance
├─ Beam_2m_A.tscn Instance
├─ Beam_Diagonal_A.tscn Instance
├─ Wall_Plaster_A.tscn Instance
├─ Roof_Thatch_A.tscn Instance
├─ Barrel_A.tscn Instance
└─ Sack_A.tscn Instance
```

每个实例继承 Blender 原对象：

``` text
Position
Rotation
Scale
```

------------------------------------------------------------------------

# 6. 正式版：Module ID

V1 验证成功后，不再长期依赖：

``` text
.001
.002
.003
```

而是为 Blender Object 设置明确：

``` text
module_id = "BEAM_2M_A"
```

以后对象叫什么并不重要。

例如：

``` text
Blender Object:
LeftRoofSupport.003

Custom Property:
module_id = "BEAM_2M_A"
```

Godot 只读取：

``` text
BEAM_2M_A
```

然后查询 ModuleDatabase。

------------------------------------------------------------------------

# 7. ModuleDatabase

禁止在转换脚本中写大量：

``` text
if Beam
elif Wall
elif Roof
...
```

建立统一模块数据库。

概念：

``` text
ModuleDatabase
│
├─ BEAM_1M_A
│   → beam_1m_a.tscn
│
├─ BEAM_2M_A
│   → beam_2m_a.tscn
│
├─ WALL_PLASTER_A
│   → wall_plaster_a.tscn
│
├─ ROOF_THATCH_A
│   → roof_thatch_a.tscn
│
└─ BARREL_A
    → barrel_a.tscn
```

以后新增模块：

``` text
制作模块
↓
建立 Godot Scene
↓
注册 ModuleDatabase
```

即可供所有建筑使用。

------------------------------------------------------------------------

# 8. Godot 自动转换流程

输入：

``` text
FarmHouse.glb
```

转换器遍历所有模块节点：

``` text
读取 Node
↓
读取 module_id
↓
保存 Global/Local Transform
↓
ModuleDatabase 查找 PackedScene
↓
实例化 PackedScene
↓
赋予原 Transform
↓
复制必要 metadata
↓
删除原 GLB Mesh 节点
```

最终：

``` text
FarmHouse.tscn
```

内部只保留真正的模块实例。

------------------------------------------------------------------------

# 9. 建筑逻辑与视觉必须分离

正式建筑建议：

``` text
FarmHouse
│
├─ Logic
│   ├─ Interaction
│   ├─ Collision
│   ├─ Workplace
│   ├─ Storage
│   └─ Construction
│
└─ Visual
    ├─ Module Instance
    ├─ Module Instance
    ├─ Module Instance
    └─ ...
```

好处：

以后重新设计 FarmHouse 外观：

``` text
替换 Visual
```

不会影响：

``` text
Farmer
Field
Storage
Transport
UI
Task
```

等游戏逻辑。

------------------------------------------------------------------------

# 10. 施工信息一起从 Blender 带入

正式版模块建议具有：

``` text
module_id
build_stage
build_order
```

例如：

``` text
木柱 A

module_id   = BEAM_2M_A
build_stage = 2
build_order = 1
```

``` text
木柱 B

module_id   = BEAM_2M_A
build_stage = 2
build_order = 2
```

``` text
屋顶 A

module_id   = ROOF_THATCH_A
build_stage = 5
build_order = 1
```

------------------------------------------------------------------------

# 11. 推荐施工阶段

统一使用大致阶段：

``` text
Stage 0
材料 / 施工现场

Stage 1
地基

Stage 2
立柱 / 主结构

Stage 3
横梁 / 斜撑

Stage 4
墙体

Stage 5
屋顶结构

Stage 6
正式屋顶

Stage 7
门窗 / 烟囱

Stage 8
主要功能 Props

Stage 9
装饰 Props / 完成
```

不是所有建筑必须使用全部阶段。

------------------------------------------------------------------------

# 12. ConstructionProgress 映射

例如：

``` text
0%
只有施工材料

10%
Stage 1
地基出现

25%
Stage 2
木柱出现

40%
Stage 3
房梁出现

55%
Stage 4
墙体出现

70%
Stage 5
屋顶骨架

85%
Stage 6
屋顶

95%
Stage 7 / 8
门窗 / 功能物件

100%
Stage 9
装饰出现
建筑完成
```

------------------------------------------------------------------------

# 13. 同阶段逐个出现

通过：

``` text
build_order
```

控制同一阶段的顺序。

例如：

``` text
Stage 2

Order 1
木柱 A
↓
💨

Order 2
木柱 B
↓
💨

Order 3
木柱 C
↓
💨

Order 4
横向支撑
```

因此施工不会表现成：

``` text
30%
↓
十根木头同时突然出现
```

而是逐渐搭起来。

------------------------------------------------------------------------

# 14. 模块出现表现

第一版不需要真正的复杂施工动画。

模块出现时：

``` text
Scale 0.8
↓
1.05
↓
1.0
```

持续：

``` text
0.1 ~ 0.2 秒
```

同时：

``` text
Dust Puff
+
Hammer Sound
+
Wood / Stone Sound
```

形成简单但明显的搭建反馈。

------------------------------------------------------------------------

# 15. 真实物流与施工表现结合

当前游戏已经采用：

``` text
居民搬运真实资源
→ ConstructionSite
```

因此视觉可以表现：

``` text
WOOD 到达
→ 工地木料堆增加

STONE 到达
→ 石料堆增加

材料满足
→ 工人开始施工
```

然后：

``` text
ConstructionProgress
↓
模块按 Stage / Order 出现
```

最终：

``` text
100%
↓
最后一次 Dust Puff
↓
临时施工材料 / 脚手架消失
↓
建筑投入使用
```

------------------------------------------------------------------------

# 16. 通用施工 Props

以后可以制作少量所有建筑共享的：

``` text
Scaffold_Small
Scaffold_Medium

WoodPile
StonePile

ToolBox
ConstructionSign
```

不需要每栋建筑单独制作施工模型。

------------------------------------------------------------------------

# 17. 模块也可服务建筑损坏

长期可以利用相同结构：

``` text
HP 100%
完整建筑

HP < 70%
部分装饰损坏

HP < 40%
部分屋顶消失 / 损坏

HP < 20%
部分墙体损坏

HP = 0
建筑成为废墟
```

因此模块未来不仅用于：

``` text
建筑组装
```

还可以用于：

``` text
施工
损坏
维修
升级
废墟
```

------------------------------------------------------------------------

# 18. 模块也可服务维修

例如：

``` text
Enemy 攻击
↓
Roof Module 损坏
↓
维修 Task
↓
居民搬 WOOD
↓
施工动画
↓
Roof Module 恢复
```

本功能属于以后，不在第一版实现。

------------------------------------------------------------------------

# 19. 模块也可服务建筑升级

例如：

``` text
House Lv1
基础模块
```

升级：

``` text
House Lv2
+
Dormer
+
Chimney
+
Porch
+
更高级 Roof
```

因此升级不一定需要重新制作整栋建筑。

------------------------------------------------------------------------

# 20. Blender 插件长期方向

V1 管线验证成功以后，可以制作 Blender 小插件。

选择模块后：

``` text
Village Building Module
──────────────────────

Module ID
[ BEAM_2M_A ▼ ]

Build Stage
[ 2 ]

Build Order
[ 4 ]

[ 根据名称自动识别 ]
[ 自动排序 ]
```

以后还可以增加：

``` text
导出建筑 GLB
检查未知 Module ID
检查重复 ID
检查未设置 Stage
```

但第一版不要先开发 Blender 插件。

------------------------------------------------------------------------

# 21. 模块库不需要一次做完

不要先制作完整：

``` text
64 / 100 / 200 个模块
```

再开始做建筑。

正确方式：

``` text
需要 Farm
↓
制作当前需要的模块
↓
搭 Farm
↓
发现缺模块
↓
新增模块
↓
Module Library 增长
```

然后：

``` text
需要 House
↓
大量复用 Farm 模块
↓
只新增少量 House 专属模块
```

最终模块库自然形成。

------------------------------------------------------------------------

# 22. 第一轮最小实验

在正式采用该管线前，只做一次很小的验证。

## Blender

只准备约 5 种模块：

``` text
Beam_A
Wall_A
Roof_A
Window_A
Barrel_A
```

使用这些模块拼一个：

``` text
TestHouse
```

允许重复使用。

例如：

``` text
Beam_A × 8
Wall_A × 4
Roof_A × 4
Window_A × 2
Barrel_A × 2
```

导出：

``` text
TestHouse.glb
```

------------------------------------------------------------------------

# 23. Godot 最小转换器

Godot 建立对应：

``` text
Beam_A.tscn
Wall_A.tscn
Roof_A.tscn
Window_A.tscn
Barrel_A.tscn
```

转换脚本：

``` text
读取 TestHouse.glb
↓
通过名称识别模块
↓
查找对应 PackedScene
↓
继承 Transform
↓
替换原 Mesh
↓
生成 TestHouse.tscn
```

------------------------------------------------------------------------

# 24. 第一轮验证内容

必须检查：

``` text
位置正确
旋转正确
缩放正确
```

尤其验证：

``` text
Blender → Godot 坐标系转换
```

以及：

``` text
重复 Beam
```

是否真的引用同一 Godot 模块资源。

例如：

``` text
Beam_A × 8
```

最终不是八套独立 Mesh 数据，而是：

``` text
同一个 Beam_A 模块资源
×
8 个实例
```

------------------------------------------------------------------------

# 25. 第二轮再验证施工顺序

最小模块替换成功以后，再加入：

``` text
build_stage
build_order
```

测试：

``` text
Progress 20%
→ Beam A

Progress 30%
→ Beam B

Progress 50%
→ Wall

Progress 70%
→ Roof

Progress 90%
→ Window

Progress 100%
→ Barrel
```

并加入简单：

``` text
Dust Puff
```

------------------------------------------------------------------------

# 26. 性能策略

第一版保持模块实例独立。

不要提前：

``` text
合并 Mesh
MultiMesh
复杂 LOD
自动 Batch
```

原因：

当前建筑数量还不足以证明存在性能问题。

模块独立更方便：

``` text
施工
损坏
维修
升级
替换
```

等以后真实场景达到：

``` text
几十 / 上百栋建筑
```

再使用 Godot Profiler 检查：

``` text
Node 数量
Draw Calls
Rendering
CPU
GPU
```

有实际瓶颈再优化。

------------------------------------------------------------------------

# 27. 模块 Scene 本身保持轻量

模块 Scene 不要包含建筑业务逻辑。

例如：

``` text
Beam_A.tscn
```

主要负责：

``` text
Mesh
Material
必要的视觉设置
```

建筑的：

``` text
Workplace
Storage
Interaction
Construction
Health
```

属于完整 Building Scene，而不是 Beam。

------------------------------------------------------------------------

# 28. 材质继续共享

模块化 Mesh 之外，材质也尽量共享：

``` text
Village Material Library

Wood
Stone
Plaster
Thatch
RoofTile
Metal
Cloth
```

不要：

``` text
Farm_Wood
House_Wood
Barracks_Wood
```

分别制作重复材质。

以后可考虑：

``` text
共享 Color Atlas
+
少量特殊材质
```

但现在以视觉效果和制作效率优先。

------------------------------------------------------------------------

# 29. 推荐最终目录概念

``` text
art/
│
├─ building_modules/
│   ├─ structure/
│   ├─ walls/
│   ├─ roofs/
│   ├─ openings/
│   ├─ props/
│   └─ construction/
│
├─ buildings/
│   ├─ farm/
│   ├─ house/
│   ├─ lumber_camp/
│   └─ quarry/
│
└─ materials/
    └─ village/
```

具体目录应根据现有 Godot
工程结构调整，不要为了本方案破坏已经稳定的资源组织。

------------------------------------------------------------------------

# 30. 正式生产流程

以后制作一个新建筑：

``` text
① 确定建筑效果
        ↓
② 检查现有 Module Library
        ↓
③ Blender 使用已有模块搭建筑
        ↓
④ 缺什么才制作什么新模块
        ↓
⑤ 给新模块注册 Module ID
        ↓
⑥ Godot 建立对应 Module Scene
        ↓
⑦ Blender 设置 Stage / Order
        ↓
⑧ 导出完整建筑 GLB
        ↓
⑨ Godot 自动转换
        ↓
⑩ 原 GLB Mesh → PackedScene Instance
        ↓
⑪ 保存建筑 Visual Scene
        ↓
⑫ 接入现有 Building Logic
```

------------------------------------------------------------------------

# 31. 最终目标

这套管线最终希望做到：

``` text
制作一个新建筑
≠
重新制作一栋完整独立模型
```

而是：

``` text
打开 Blender
↓
从 Village Module Library 取模块
↓
快速组合
↓
只制作少量专属零件
↓
导出
↓
Godot 一键转换
↓
自动获得真正模块化建筑
↓
自动拥有施工出现顺序
```

最终形成：

``` text
Blender
= 建筑视觉编辑器

Godot
= 模块实例化 + 游戏逻辑 + 施工表现

ModuleDatabase
= 两者之间的统一语言
```

------------------------------------------------------------------------

# 32. 当前开发优先级

这套管线值得保留，但不能阻碍当前 Population 主线。

当前：

``` text
Population V1
```

继续按原计划开发。

美术管线可以并行做：

``` text
5 个模块
+
1 个 TestHouse
+
1 个 Godot 最小替换脚本
```

验证成功即可暂停。

等第一场 Wave / 战斗闭环形成后，再逐步扩大正式 Village Module Library。

原则：

> **先证明管线能工作，再扩充资产；不要为了制作完整模块系统而暂停游戏主线。**
