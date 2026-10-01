# 原项目光束独立演示

打开 `res://addons/lens_effects/demo/demo.tscn`，按 F6 运行，无需启用编辑器插件。演示直接实例化作者的场景，增加中文参数面板和镜头操作。右键拖动环绕，滚轮缩放；“作者视角”恢复原始镜头，“俯视角度”用于比较观察方向的影响。

`upstream_demo.tscn` 来自上游 `lens-effects-demo/lens-effects-1.tscn`，仅移除无法跨项目解析的脚本 UID 和类型元数据，保留原始场景、光源、镜头、天空和效果参数。也可直接打开该场景按 F6 查看没有面板的原始演示。

四个核心文件 `base_compositor_effect.gd`、`lens_flare_compositor_effect.gd`、`lens_flares.glsl`、`world_environment.gd` 与固定提交的上游文件一致。此效果在透明物体渲染后执行（`effect_callback_type = 4`），通过屏幕深度径向采样形成光束遮挡和光晕。本演示没有预先摆放透明光束面片。

效果依赖观察角度和屏幕内的遮挡；采样数越高，GPU 开销越大。已在 Godot 4.7.2 / Forward+ / D3D12 的独立临时工程及当前主工程路径下验证原场景实际渲染、效果开关、采样和视角切换。主工程曾保留无窗口导入产生的空着色器缓存，现已恢复同一着色器的有效图形设备编译结果，并直接在主工程验证成功。当前仍是独立演示，未接入主场景、StylizedDayNight 或战争迷雾。

计算着色器需要通过带图形设备的编辑器导入。如果用 `--headless` 导入后遇到 `get_spirv` 或无效着色器错误，在正常编辑器中选择 `lens_flares.glsl`，在“导入”面板点击“重新导入”。

上游：https://github.com/ARez2/compositor-effect-lens-effects

固定提交：`0ce061271f672f05fbb9aed08a61e019a875c1ad`。上游采用 MIT 许可，原文见本目录 `LICENSE`。中文面板、镜头控制和本说明为项目新增。
