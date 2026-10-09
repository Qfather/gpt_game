# Godot 4.7.2 风格化白天天空制作计划

## 目标

在当前 Godot 4.7.2 项目中，为主游戏场景建立一套可调节的风格化白天天空系统。

使用：

```text
WorldEnvironment
→ Environment
→ Sky
→ ProceduralSkyMaterial
```

同时确保场景中存在一个 `DirectionalLight3D` 作为太阳。

不要改动现有地图生成、角色、建筑、导航等逻辑，只处理环境天空和主方向光。

---

## 1. 场景结构

如果主场景没有环境节点，则创建：

```text
Main
├─ WorldEnvironment
└─ DirectionalLight3D
```

如果已经存在这些节点，则复用，不要重复创建。

`WorldEnvironment.environment` 使用独立的 `.tres` Environment 资源，方便以后统一调整。

建议资源保存到类似：

```text
res://assets/environment/day_environment.tres
res://assets/environment/day_sky.tres
res://assets/environment/day_sky_material.tres
```

如果项目已有更合适的资源目录，则遵循项目原有目录结构。

---

## 2. Environment 设置

Background：

```text
Mode = Sky
```

创建 `Sky`，并把 `Sky Material` 设置为：

```text
ProceduralSkyMaterial
```

环境光优先从天空获得，让天空真正参与地图整体颜色，而不仅仅作为背景。

初期不要开启很重的后处理效果，不要主动加入强雾、DOF 等效果。

---

## 3. ProceduralSkyMaterial 初始风格

目标：

```text
风格化
晴朗白天
柔和蓝天
浅蓝偏白地平线
不要深蓝
不要写实 HDR 风格
不要让天空颜色压过草地和建筑
```

第一版参数建议从以下方向开始：

```text
Sky Top Color
中等偏浅、稍微低饱和的蓝色

Sky Horizon Color
非常浅的蓝白色

Sky Curve
让顶部蓝色到地平线的过渡比较柔和

Ground Horizon Color
与 Sky Horizon Color 接近

Ground Bottom Color
灰蓝或灰绿色，不要纯黑

Ground Curve
保持柔和

Energy Multiplier
约 1.0，后续根据模型曝光微调

Sky Energy Multiplier
约 1.0

Ground Energy Multiplier
略低于天空

Use Debanding
开启
```

---

## 4. 推荐第一版颜色

可以先尝试：

```text
Sky Top:
#6FA6D8

Sky Horizon:
#C7DCEA

Ground Horizon:
#C7DCEA

Ground Bottom:
#75858A
```

这些只作为第一版基准，不要求死用具体颜色。

实际效果以当前草地、岩石和建筑材质为准。

希望最终看到的是：

```text
天空顶部：柔和蓝
         ↓
        浅蓝
         ↓
地平线：接近蓝白
```

避免出现明显的深蓝—白色硬渐变。

---

## 5. 太阳 DirectionalLight3D

场景使用一个主要 `DirectionalLight3D`。

初始目标：

```text
太阳角度：
不要正午完全垂直向下
从斜上方照射

Light Color：
接近白色，可以带极轻微暖色

Energy：
中等，不要把草地晒成纯白

Shadows：
开启
```

建议光照方向让：

```text
建筑顶部明亮
建筑侧面有明显但柔和的明暗关系
悬崖石块能读出体积
树冠有足够层次
```

当前项目只需要一个主要太阳即可。

---

## 6. 环境光

设置 Environment 的 Ambient Light，让天空参与环境光。

目标不是靠环境光把所有阴影填平，而是：

```text
太阳 = 主要明暗塑形
天空环境光 = 填充阴影
```

最终阴影区域仍应能看清材质颜色，但比受光面明显暗。

不要把 Ambient Energy 调得太高，否则整个场景会变得扁平。

---

## 7. 重点检查 grass_cliff 材质

当前悬崖材质使用：

```text
World Normal Y
→
草地 / 岩石贴图混合
```

调节天空时重点确认：

```text
草地没有过曝
岩石没有被天空光染得过蓝
草地与 Blender 中原贴图颜色差异不要太大
石头阴影区域仍然有层次
```

不要为了让天空更漂亮而破坏地图材质的可读性。

---

## 8. 摄像机视角下调节

不要只站在地面第一人称角度调天空。

以游戏实际 RTS 摄像机高度和角度作为主要观察标准。

因为游戏画面主体优先级是：

```text
1. 地图地形
2. 树木和资源
3. 建筑
4. 单位
5. 天空
```

天空应该只是背景和整体光照来源，不能抢视觉注意力。

---

## 9. 第一阶段不要做

暂时不要加入：

```text
动态昼夜循环
动态天气
星星
自定义云 Shader
HDRI
PhysicalSkyMaterial
复杂体积云
强烈雾效
```

先把单一的“晴朗白天”做稳定。

---

## 10. 验收标准

修改完成后运行主场景检查：

```text
① 游戏运行时能看到真实天空，而不是编辑器预览天空
② 摄像机旋转时天空正常
③ 草地没有严重偏白或偏蓝
④ 岩石依旧清楚
⑤ 建筑和悬崖具有明显体积
⑥ 阴影区域不会黑死
⑦ 天空不会比地图本身更抢眼
⑧ 编辑器运行和实际游戏运行视觉基本一致
```

完成后告诉我：

```text
修改了哪些场景/资源
新建了哪些 .tres
ProceduralSkyMaterial 最终参数
DirectionalLight3D 最终参数
Environment 环境光参数
```

不要修改与天空、环境和主 `DirectionalLight3D` 无关的代码或资源。

---

## 当前阶段建议

先固定成一个标准晴朗白天环境。

等地图、树、建筑整体颜色基本确定之后，再做：

```text
第二套：阴天
第三套：黄昏
```

避免现阶段一边修改材质，一边又被天空颜色影响，导致反复调整。
