# Godot 地图生成器：World Surface Mask 地表混合系统开发计划

> 目标：把“草地 / 泥土 / 道路 / 建筑占地 / 特殊区域”的地表控制，正式集成进现有 Godot 地图生成器插件中。  
> 当前地图为方格地图，典型尺寸如 40×40；主要为俯视 RTS，没有洞穴和上下重叠地表，因此可以直接使用 **XZ 世界坐标映射一张二维 World Mask**。

---

## 1. 最终目标

地图生成完成后，插件自动生成一张与整张地图对应的二维遮罩纹理：

```text
R = 自然泥土 / 裸土地表
G = 道路
B = 建筑占地 / 建筑周围影响区
A = 特殊区域（裂隙、腐化区等，暂时预留）
```

地面 Shader 根据世界坐标读取这张 Mask，并完成：

```text
草地
↓
自然泥土簇
↓
道路
↓
建筑周围裸土
↓
特殊地表
```

要求：

- 不依赖每个 Plane 自己的 UV。
- 不按格子重复贴图。
- 整张地图视为一张连续地表。
- 同一张 Mask 后续可被道路、建筑、裂隙系统继续修改。
- 地图重新生成时，可同步重新生成地表分布。
- 可以单独重新生成地表，不必重新生成整个地图。

---

# 2. 核心设计原则

## 2.1 使用世界空间 XZ 坐标

因为当前地图：

- 主要为俯视；
- 没有洞穴；
- 不存在同一 XZ 上下叠层的地形；

所以所有地表遮罩统一按：

```text
World XZ
    ↓
Map UV 0~1
    ↓
WorldMask
```

映射。

Shader 不应使用每个 Plane 自己重复的 UV 来决定地表类型。

---

## 2.2 地图尺寸由生成器直接提供

假设：

```text
grid_width  = 40
grid_height = 40
cell_size   = 4.0
```

则：

```text
world_width  = grid_width  × cell_size
world_height = grid_height × cell_size
```

无需运行后再统计 Plane 数量。

插件应直接从地图生成参数得到：

```gdscript
grid_size
cell_size
map_origin
world_size
```

---

# 3. World Mask 数据定义

建议使用一张 RGBA Image / ImageTexture。

例如：

```text
512 × 512
RGBA8
```

默认：

```text
R = 0
G = 0
B = 0
A = 0
```

---

## 3.1 通道定义

### R：Natural Dirt

表示程序生成的自然泥土地。

```text
0.0 = 纯草地
1.0 = 纯泥土
0~1 = 草 / 泥过渡
```

---

### G：Road

表示玩家道路或程序道路。

```text
0.0 = 无道路
1.0 = 道路中心
0~1 = 道路边缘过渡
```

---

### B：Building

表示建筑占地区域及周围视觉影响区域。

用途：

- 地面变为裸土；
- 花草生成时避让；
- 后续可以做建筑施工痕迹。

---

### A：Special

暂时预留。

未来可用于：

- 裂隙腐化地表；
- 火烧区域；
- 沼泽；
- 魔法区域；
- Boss 地表影响。

---

# 4. 插件结构建议

建议不要把所有逻辑塞进一个脚本。

推荐拆分：

```text
addons/MapGenerate/
│
├─ surface/
│   ├─ surface_mask_generator.gd
│   ├─ surface_mask_resource.gd
│   ├─ surface_mask_runtime.gd
│   └─ shaders/
│       └─ terrain_surface.gdshader
│
├─ editor/
│   └─ surface_panel.gd
│
└─ ...
```

---

# 5. SurfaceMaskGenerator

负责编辑器阶段的 World Mask 生成。

主要职责：

```gdscript
generate_mask()
generate_natural_dirt()
clear_channel()
regenerate_surface()
save_mask()
```

建议提供统一入口：

```gdscript
func generate_surface_mask(map_data) -> Image:
```

---

# 6. SurfaceMaskResource

建议保存地表生成参数，方便插件复用。

例如：

```gdscript
class_name SurfaceMaskSettings
extends Resource

@export var enabled := true

@export var mask_resolution := 512

@export_range(0.0, 1.0)
var dirt_coverage := 0.20

@export var dirt_cluster_count := 12

@export var dirt_cluster_min_radius := 3.0
@export var dirt_cluster_max_radius := 10.0

@export_range(0.0, 1.0)
var edge_noise_strength := 0.35

@export var edge_softness := 0.15

@export var exclude_core_area := true

@export var seed := 0
```

---

# 7. 插件面板

地图生成器 Inspector / Dock 中增加：

```text
Terrain Surface
├─ Enable Surface Mask
│
├─ Mask Resolution
│   ├─ 256
│   ├─ 512
│   └─ 1024
│
├─ Dirt Coverage
├─ Dirt Cluster Count
├─ Dirt Cluster Min Size
├─ Dirt Cluster Max Size
├─ Edge Noise
├─ Edge Softness
├─ Seed
│
├─ Exclude Core Area
│
├─ [ Regenerate Surface ]
├─ [ Clear Surface ]
└─ [ Preview Mask ]
```

要求：

**Regenerate Surface 只重新生成 Surface Mask，不重新跑 WFC / 地形生成。**

---

# 8. 自然泥土生成算法

不要每格独立随机。

错误：

```text
草 泥 草 草 泥
泥 草 泥 草 草
```

这种会产生碎点。

目标：

```text
草 草 草 草 草
草 草 泥 泥 草
草 泥 泥 泥 草
草 草 泥 泥 草
草 草 草 草 草
```

即“簇状分布”。

---

# 9. 推荐算法：随机簇 + Noise 扰动

第一版不必上复杂算法。

推荐：

### Step 1

随机生成 N 个泥土簇中心。

```gdscript
cluster_center = random_map_position()
```

---

### Step 2

每个簇随机半径：

```text
min_radius ~ max_radius
```

---

### Step 3

对 Mask 像素计算到簇中心距离。

可以使用：

```text
圆形
椭圆
轻微方向拉伸
```

避免全部为完美圆形。

---

### Step 4

加入 FastNoiseLite。

逻辑类似：

```text
distance_mask
+
large_scale_noise
=
final_cluster
```

Noise 必须是大尺度。

不要生成密集砂点。

推荐：

```text
frequency 较低
fractal_octaves 2~4
```

---

### Step 5

边缘平滑

最终值：

```text
0 → 1
```

不要直接二值化。

推荐使用类似：

```text
smoothstep()
```

思路。

最终：

```text
草地 0.0
过渡 0.2~0.8
泥土 1.0
```

---

# 10. 核心区域排除

当前地图开局据点核心区需要保持稳定。

如果地图生成器已有：

```text
Core Area 5×5
```

则 Surface 系统需要支持：

```text
exclude_core_area = true
```

第一阶段建议：

```text
核心区内 R 通道限制在 0 ~ 0.15
```

不要完全随机生成大片泥土。

后续建筑正式放置后，再由 B 通道控制据点周围的裸土地。

---

# 11. 世界坐标 → Mask UV

必须做成统一公共函数。

CPU：

```gdscript
func world_to_mask_uv(world_pos: Vector3) -> Vector2:
    var local_x := world_pos.x - map_origin.x
    var local_z := world_pos.z - map_origin.z

    return Vector2(
        local_x / world_size.x,
        local_z / world_size.y
    )
```

像素坐标：

```gdscript
func world_to_mask_pixel(world_pos: Vector3) -> Vector2i:
    var uv := world_to_mask_uv(world_pos)

    return Vector2i(
        int(uv.x * mask_width),
        int(uv.y * mask_height)
    )
```

必须 Clamp。

---

# 12. 地面 Shader

建议地面统一使用一个 Terrain Surface Shader。

核心参数：

```glsl
uniform sampler2D grass_texture;
uniform sampler2D dirt_texture;
uniform sampler2D road_texture;

uniform sampler2D world_mask;

uniform vec2 map_origin;
uniform vec2 map_world_size;
```

---

## 12.1 世界空间坐标

```glsl
varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
```

---

## 12.2 Mask UV

```glsl
vec2 map_uv = (
    world_pos.xz - map_origin
) / map_world_size;
```

---

## 12.3 读取 Mask

```glsl
vec4 mask = texture(world_mask, map_uv);

float natural_dirt = mask.r;
float road         = mask.g;
float building     = mask.b;
float special      = mask.a;
```

---

# 13. 草 / 泥混合

第一阶段：

```glsl
vec3 grass = texture(grass_texture, terrain_uv).rgb;
vec3 dirt  = texture(dirt_texture, terrain_uv).rgb;

float dirt_mask = max(
    natural_dirt,
    building
);

vec3 color = mix(
    grass,
    dirt,
    dirt_mask
);
```

---

# 14. 道路优先级

建议：

```text
Special
  >
Road
  >
Building Dirt
  >
Natural Dirt
  >
Grass
```

或者后续根据实际视觉调整。

例如：

```glsl
color = mix(color, dirt_color, building);
color = mix(color, road_color, road);
color = mix(color, special_color, special);
```

---

# 15. 打破地面贴图重复

World Mask 只解决“大面积地表重复”。

贴图本身还需要进一步避免重复。

推荐使用：

```text
大尺度 Surface Mask
+
世界空间 UV
+
Noise UV Offset
+
多尺度 Texture
```

---

## 15.1 不使用每格 Plane UV

不要：

```glsl
texture(grass_texture, UV)
```

如果每个 Plane 的 UV 都是：

```text
0~1
```

则会明显看到重复格子。

---

## 15.2 使用世界空间 UV

例如：

```glsl
vec2 terrain_uv = world_pos.xz * texture_scale;
```

这样所有 Plane 连续。

---

## 15.3 后续可增加双尺度贴图

例如：

```text
Grass Detail Texture
+
Large Color Variation Texture
```

小尺度负责草纹。

大尺度负责颜色变化。

这样可以进一步消除重复。

---

# 16. 建筑系统写入 B 通道

以后玩家建造建筑：

```text
放置建筑
↓
得到建筑占格
↓
写入 WorldMask.B
↓
Ground Shader 自动变为泥土
```

例如建筑占：

```text
3 × 3
```

不要只写准确 3×3。

建议视觉影响区域略微扩大：

```text
3×3 Occupancy
+
0.25~0.5 格软边
```

形成：

```text
草草草草草
草░░░░草
草░建筑░草
草░░░░草
草草草草草
```

其中：

```text
░ = 0~1 渐变
```

---

# 17. 建筑拆除

必须支持：

```text
拆建筑
↓
重新计算对应区域 B 通道
```

注意：

**不能简单把 B 设置成 0。**

因为同一区域可能有：

- 相邻建筑；
- 道路；
- 其他影响源。

推荐长期方案：

```text
Mask 数据来源分层
```

例如 CPU 内部保存：

```text
natural_layer
road_layer
building_layer
special_layer
```

最后合成为 RGBA Texture。

这样删除建筑时只重算 Building Layer。

---

# 18. 草 / 花生成系统

以后树下会增加：

- 草；
- 花；
- 小石块；
- 装饰物。

生成时应读取 Building Mask。

例如：

```gdscript
if get_building_mask(world_pos) > 0.4:
    skip_spawn()
```

建筑正下方不要生成花草。

墙角附近可以保留少量：

```text
0.1 ~ 0.4 Mask
```

区域的植被。

---

# 19. 道路系统

道路建造时：

```text
道路路径
↓
写入 G 通道
↓
地面立即显示道路材质
```

道路宽度建议不是一条硬线。

需要：

```text
中心 = 1
边缘 = 0
```

软过渡。

---

# 20. 裂隙系统

未来裂隙可以写 A 通道：

```text
裂隙中心 = 1
周围逐渐衰减
```

Shader 中：

```text
草地
→ 枯黄
→ 腐化
→ 裂隙中心
```

这样无需再修改整个地面材质架构。

---

# 21. 编辑器预览

建议插件支持 Preview Mode：

```text
Normal
R Channel
G Channel
B Channel
A Channel
```

例如：

```text
R Preview
黑 = 草
白 = 泥
```

这样调参数非常方便。

---

# 22. 保存方式

地图保存时需要保存：

```text
Surface Settings
Seed
World Mask
```

建议保存：

```text
res://generated/
    map_surface_mask.png
```

或者：

```text
ImageTexture Resource
```

开发阶段优先 PNG，方便直接打开检查。

---

# 23. 随机种子

Surface Mask 必须绑定地图 Seed。

例如：

```gdscript
surface_seed = map_seed + 10001
```

这样：

同一个 Map Seed：

```text
地形一致
Surface 一致
```

避免每次加载地图泥土位置都变化。

---

# 24. 性能目标

地图典型：

```text
40×40
```

推荐：

```text
Mask = 512×512
```

第一阶段完全足够。

不建议一开始就：

```text
2048×2048
```

因为当前是俯视 RTS。

---

# 25. Mask 更新优化

编辑器生成：

```text
整张 Image 更新
```

可以接受。

运行时建造：

不要每放一个建筑都重新生成整张自然地表。

只修改：

```text
Building Layer
```

并更新 Texture。

以后如果地图变大，再优化 Dirty Rect。

第一版不用提前复杂化。

---

# 26. 与高度地图的关系

Surface Mask 不保存高度。

只负责：

```text
XZ
```

地表类型。

因此：

- 平地可用；
- 高地可用；
- 坡道可用；
- 悬崖顶部可用。

目前游戏没有洞穴，因此不会出现映射冲突。

---

# 27. 悬崖侧面

第一版建议：

**World Surface Mask 只影响地面顶部材质。**

悬崖侧面继续使用现有岩石材质。

不要让草 / 泥 Mask 直接覆盖悬崖侧壁。

如果当前 Mesh 共用一个材质，需要通过：

```text
Normal Y
```

或顶点属性区分：

```text
顶部
侧面
```

---

# 28. 第一阶段开发范围

先只实现：

### M1

```text
✔ 创建 RGBA World Mask
✔ 自然 Dirt Cluster
✔ 世界坐标映射
✔ Grass / Dirt Shader 混合
✔ Inspector 参数
✔ Regenerate Surface
✔ Mask PNG 导出
```

完成后确认：

```text
40×40 地图看不到每格贴图重复
```

---

# 29. 第二阶段

### M2

加入：

```text
✔ 建筑 B Channel
✔ Building Mask API
✔ 建筑拆除恢复
✔ 花草生成避让建筑
```

---

# 30. 第三阶段

### M3

加入：

```text
✔ 道路 G Channel
✔ 道路软边
✔ 道路材质
```

---

# 31. 第四阶段

### M4

加入：

```text
✔ 裂隙 A Channel
✔ 腐化 Shader
✔ 特殊区域扩展
```

---

# 32. 建议 API

Surface 系统至少暴露：

```gdscript
regenerate_surface()
```

```gdscript
world_to_mask_uv(world_pos)
```

```gdscript
world_to_mask_pixel(world_pos)
```

```gdscript
get_mask_value(
    world_pos,
    channel
)
```

```gdscript
paint_building_area(
    world_pos,
    size,
    softness
)
```

```gdscript
paint_road(
    points,
    width,
    softness
)
```

```gdscript
clear_building_area(...)
```

---

# 33. 不要这样实现

## 不要让 Shader 遍历所有建筑

不要：

```glsl
for building in buildings
```

理由：

- 建筑越多越慢；
- Shader 参数难维护；
- 建筑数量受到 uniform 限制；
- 道路和裂隙以后更难扩展。

---

## 不要每个 Plane 随机 UV

虽然可以缓解重复，但无法形成：

```text
大尺度泥土地簇
```

也无法统一：

```text
道路
建筑
裂隙
```

---

## 不要把 Dirt 完全二值化

不要：

```text
0 / 1
```

需要保留灰度过渡。

---

# 34. 验收标准

M1 完成时必须满足：

1. 40×40 地图生成后自动生成 Surface Mask。
2. 草 / 泥分布形成连续簇，而不是随机碎点。
3. 泥土边缘不规则。
4. 地面跨 Plane 无明显格子接缝。
5. 地面纹理不再每格重复。
6. 可以只点击一次按钮重新随机地表。
7. 不改变 WFC 结果。
8. 不改变高度数据。
9. 同 Seed 结果一致。
10. 修改 Dirt Coverage 能明显控制泥土面积。
11. 修改 Cluster Size 能明显改变大块区域尺寸。
12. Mask 可以导出 PNG 检查。
13. 地图尺寸变化后仍能正确映射。

---

# 35. 最终架构

```text
Map Generator
│
├─ Grid Data
├─ Height Data
├─ Region Data
├─ WFC / Module Data
│
└─ Surface System
    │
    ├─ Natural Dirt Layer
    ├─ Road Layer
    ├─ Building Layer
    └─ Special Layer
           ↓
       World Mask RGBA
           ↓
     Ground Shader
           ↓
 ┌──────────────────────┐
 │ Grass / Dirt / Road  │
 │ Building / Corruption│
 └──────────────────────┘
```

---

# 36. 本项目最终推荐方向

当前阶段优先实现：

```text
自然草地
+
自然泥土簇
```

先解决目前地图：

```text
大片纯绿色
+
重复感明显
```

的问题。

等这个系统稳定后，再让：

```text
建筑
道路
裂隙
花草生成
```

逐步接入同一张 World Mask。

不要一次性全部实现。

**先完成 M1，再扩展 M2。**
