# Flow Graph（流程节点编辑器）

适用于 Godot 4.7 的程序化内容图编辑插件，设计思路参考 Unreal Engine 5 的 PCG。通过可视化流程图生成点集、变换点集，并在场景中生成网格或场景实例。

## 简介

Flow Graph 是仅在编辑器中运行的工具，可使用节点搭建程序化生成流程。主要功能包括点集生成与变换、采样、点集布尔运算、分区、表达式计算等。插件提供实时 3D 调试视图和数据检查器，可逐步查看流程结果。

流程图以 Godot 资源保存，也可以公开带类型的输入参数，供其他图表或场景节点复用。

## 安装

1. 将以下目录复制到 Godot 项目中：
   - `demo/addons/flow_nodes_editor`
   - `demo/bin`
2. 在 Godot 中打开「项目 → 项目设置 → 插件」，启用「Flow Nodes Editor」。

本仓库内已放置插件文件和 Windows 编辑器/调试版扩展，可直接在当前项目的插件设置中启用。

## 快速开始

在 3D 场景中：

1. 添加一个 `FlowGraphNode3D` 节点。
2. 打开右侧的「数据流」面板。
3. 在流程图区域点击鼠标右键，打开「添加节点」菜单。
4. 添加一个节点，例如「生成网格」。
5. 选中节点并按 `D`，开启该节点的 3D 调试；点会以白色方块显示在视口中。
6. 在节点检查器中调整参数，例如网格数量和尺寸。
7. 按 `E` 打开「数据检查器」，查看每个点的实际数据。点击表格中的行，可在 3D 场景中用洋红色标记对应点。

## 快捷键

| 按键 | 功能 |
| --- | --- |
| 鼠标右键 | 添加节点 |
| `D` | 切换当前节点的 3D 点调试显示 |
| `Shift+D` | 关闭其他节点的 3D 点调试，只保留当前节点 |
| `A` | 切换数据检查器 |
| `E` | 启用或停用当前节点 |
| `C` | 为选中的节点创建注释框 |
| `X` | 删除选中的节点 |
| `R` | 强制重新计算选中的节点 |

## 功能

- 提供 75 种以上节点，包含样条轮廓与内部采样、网格表面采样、环体体积采样、点集并集/交集/差集、网格和场景实例生成、表达式计算、分区/归并/合并/排序、射线检测、自定义资源匹配、场景扫描、子图循环、样条语法生成、节点重定向、聚类、吸引点，以及 Watabou 地牢和民居数据导入。
- 网格形式的数据检查器，并支持选择高亮。
- 使用颜色区分状态的 3D 调试覆盖层。
- 流程图以资源保存，并支持可选的带类型输入。
- 支持复制和粘贴节点，剪贴板数据采用 JSON 格式。

### 环体体积散布实例

添加「环体采样」节点，并连接一个提供位置、旋转和尺寸数据的中心点。设置「环半径」「管道半径」和「采样数量」，节点会在每个中心点周围的圆环管状体积内均匀生成点。默认启用「切向旋转」，使实例局部 Z 轴沿圆环切线；「切向旋转偏移」可在此朝向上追加 XYZ 角度。关闭切向旋转后，实例沿用中心点旋转，偏移仍会叠加。随后连接「生成网格实例」或「生成场景实例」。输入点的位置和旋转分别决定圆环中心和朝向。需要实例缩放随机变化时，可在中间加入「随机变换点」。环半径小于管道半径时，会自动将环半径调整到管道半径，以保持标准圆环形状。

## 示例

上游仓库的 `demo` 目录提供可运行的 Godot 示例项目，流程图位于 `demo/demos`。以下图片链接保留自上游仓库；若示例资源未随当前项目复制，图片可能无法显示。

### 网格顶面采样
![网格顶面采样](demo/addons/flow_nodes_editor/doc/demo_sample_mesh.png)

### 程序化桥梁
![程序化桥梁](demo/addons/flow_nodes_editor/doc/demo_bridge.gif)

对应的流程图：

![桥梁示例流程图](demo/addons/flow_nodes_editor/doc/demo_bridge_graph.png)

### 森林中的村庄
![森林村庄示例](demo/addons/flow_nodes_editor/doc/demo_forest.gif)

### 语法生成
![语法生成示例](demo/addons/flow_nodes_editor/doc/demo_grammar.png)

### 非均匀采样
![非均匀采样示例](demo/addons/flow_nodes_editor/doc/demo_non_uniform_sampling.png)

### 使用循环生成塔楼
![循环生成塔楼](demo/addons/flow_nodes_editor/doc/demo_loop.png)

### 点位松弛
![点位松弛示例](demo/addons/flow_nodes_editor/doc/demo_relax.png)

### 旋转
![旋转示例](demo/addons/flow_nodes_editor/doc/demo_rotation.png)

### 使用曲线重映射
![曲线重映射示例](demo/addons/flow_nodes_editor/doc/demo_remap.png)

### 从样条生成简易围栏
![样条围栏示例](demo/addons/flow_nodes_editor/doc/demo_sample_spline.png)

## 参与贡献

参与项目的人员名单见上游仓库的 `CONTRIBUTORS.md`。

## 支持平台

插件提供 Windows 和 macOS 的预编译版本，Linux 环境也应可以正常编译。

这是一个 Godot 编辑器工具，原则上可在 Godot 编辑器支持的平台运行。大部分代码使用 GDScript；KDTree 和 RTree 的包装类使用了 [nanoflann](https://github.com/jlblancoc/nanoflann) 与 [RTree](https://github.com/nushoin/RTree)。

## 上游路线图与问题反馈

上游开发清单及其原始状态见本目录的 `UPSTREAM_TODO.md`。插件具备可用功能，但上游作者尚未在大型 Godot 项目中充分验证。如遇到问题或有改进建议，可在上游仓库提交 issue。

## 从源码编译

```sh
git submodule update --init
scons target=editor
```
