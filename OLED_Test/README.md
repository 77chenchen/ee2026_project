# 独立 OLED 硬件测试（Basys3，JB）

这个工程只使用测试顶层、简单图案生成器及课程 `Oled_Display.v` 驱动。
不使用计算器原顶层、graph、菜单、字体、鼠标或其新增流水线。
目标器件为 `xc7a35tcpg236-1`，输入时钟 100 MHz，OLED 时钟 6.25 MHz。

**所有拨码开关关闭，上电后约 0.2 秒应出现整屏红色，无须按按钮。**
本测试能够排除很多原工程问题，但不能仅凭黑屏断定 OLED 已损坏。

## 生成工程、bitstream

1. 下载/切换到 GitHub 的 **oled-hardware-test** 分支，解压完整仓库。
2. 保存并关闭 Vivado 当前工程。在 Tcl Console 执行下面命令，替换实际路径：

```tcl
source {C:/path/to/ee2026_project/OLED_Test/build.tcl}
```

这个脚本自动创建独立工程、综合、布局布线、导出报告，在时序检查通过后生成 bitstream。
它不会改动或运行原来的 `FDP2026.xpr`，也不会自动连接/烧录硬件。

生成文件：

```text
OLED_Test/vivado_project/OLED_Test.xpr
OLED_Test/vivado_project/OLED_Test.runs/impl_1/OLED_Test_Top.bit
OLED_Test/reports/timing.txt
OLED_Test/reports/utilization.txt
OLED_Test/reports/io.txt
OLED_Test/reports/coverage.txt
```

如果只需要先打开工程查看源码：

```tcl
source {C:/path/to/ee2026_project/OLED_Test/create_project.tcl}
```

然后在 Vivado 中运行 Generate Bitstream。不要打开仓库里的旧 Hanna 归档工程；
不要烧录名称相同但位于其他目录的旧 `.bit`。

## 上板步骤

1. **板子断电后**连接 OLED 到整个双排 **JB**，核对 GND/VCC 标签，避免反插、错位。
   不要热插拔，不要触碰或拉扯 OLED 排线。
2. 所有拨码开关关闭，板子上电。
3. Vivado → Open Hardware Manager → Open Target → Auto Connect → Program Device。
4. 选择上面的 **OLED_Test_Top.bit**，确认路径，再 Program。
5. 屏幕应在约 0.2 秒后为红色；继续观察至少 2 秒，确认 LED0 持续闪烁。

## 图案与操作

`SW3=0` 时用 `SW2 SW1 SW0` 手动选择：

| SW2 SW1 SW0 | 图案 | 检查内容 |
| --- | --- | --- |
| 000 | 整屏红 | 默认上电检查、红通道 |
| 001 | 整屏绿 | 绿通道 |
| 010 | 整屏蓝 | 蓝通道 |
| 011 | 整屏白 | 全屏及缺失行/列 |
| 100 | 8×8 黑白棋盘 | 像素寻址、图像完整性 |
| 101 | 边框＋四色角标 | 上下左右边缘、方向 |
| 110 | 白色中心十字 | 中心位置、行列 |
| 111 | RGB 色条＋移动白条 | 持续刷新、动态画面 |

`SW3=1`：每约 3 秒自动切换一个图案；再关闭可回到手动选择。
`SW15=1`：保持 OLED 关闭/复位；将其拨回 0 后重新初始化。
其他拨码和按钮不参与这个工程。

## LED 指示

| LED | 含义 |
| --- | --- |
| 0 | 约 1 Hz 心跳；用于检查主时钟和测试逻辑是否运行 |
| 1 | OLED PMODEN（初始化后应亮） |
| 2 | OLED VCCEN（初始化后应亮） |
| 3 | OLED RESN（复位结束后应亮） |
| 4 | 正在发送像素；正常刷新时通常看起来常亮 |
| 7..5 | 当前图案编号，二进制 000..111 |

LED 只表示 FPGA 内部信号，不是 OLED 电源电压或屏幕状态的测量结果。
JB[2] 为驱动未使用的信号，本测试固定输出 0。

## 仍然黑屏时

- LED0 不闪：先核对烧录的 bitstream、器件、板子时钟和供电；此时不能归因于 OLED。
- SW15 必须为 0；初始化后 LED1/2/3 应亮。否则先检查复位与工程实现报告。
- LED 正常但所有纯色均不显示：核对 JB、插接方向、接触与供电，提供接线照片、`.bit` 完整路径及 `reports/`。
- 同一块板、同一接法下，已知正常的 OLED 能显示而这块不能显示，才更有力地指向屏幕/排线故障。
  如果两块都黑，也可能是板子接口、电源或实现/烧录问题。

## 本地测试及限制

安装 Icarus Verilog 后，在仓库根目录运行：

```sh
bash OLED_Test/run_tests.sh
```

测试检查全部图案像素、实际分频、上电复位、LED 心跳、手动/自动切换，以及
真实顶层从上电到八个完整图案帧的串行像素（初始化等待没有跳过）。
开发 Mac 没有 Vivado，仓库不提供未经验证的预编译 `.bit`。
仿真通过不能证明屏幕完好，也不能代替 Windows 上的实现报告和上板测试。
