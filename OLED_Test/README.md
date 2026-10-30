# 独立 OLED 亮屏测试

这里的 Verilog **只有一个文件**：`OLED_Test_Top.v`。不引用计算器、Graph 或原工程的 OLED 驱动。
适用硬件是 Basys3 + Digilent PmodOLEDrgb（96×64，SSD1331），OLED 接在完整的双排 **JB**。

先给板子断电再插 OLED，核对 GND/VCC，避免插反或错位。

在 Windows 上把 `OLED_Test_Standalone.zip` 解压到短路径，例如 `C:\OLED_Test`，
然后用 Vivado **Open Project** 打开 `OLED_Test.xpr`，点击 **Generate Bitstream**。
生成后在 Hardware Manager 中烧录 `OLED_Test.runs/impl_1/OLED_Test_Top.bit`。

如果 Vivado 版本不能直接打开这份 2025.2 工程，可在 Vivado Tcl Console 运行：

```tcl
source {C:/OLED_Test/build.tcl}
```

脚本会新建等价工程并生成 bitstream：`vivado_project/OLED_Test.runs/impl_1/OLED_Test_Top.bit`。
无须按任何按钮；正常情况下约 0.13 秒后屏幕会整屏点亮。
这个测试用 SSD1331 的 `A5` 全屏点亮命令，**不绘制图像或文字**。
确认亮屏后重新烧录正常程序，避免长时间保持全屏最高亮度。

如果仍黑屏，观察板载 LED：`LED0` 应持续闪烁；`LED1`、`LED2`、`LED3`、`LED4`
应在初始化后亮起。它们只反映 FPGA 输出信号，不测量 OLED 实际电压。
Vivado 的 `no supported debug core` 信息是正常的；本工程没有 ILA 调试核。

工程只有一个 Verilog 源文件和一份引脚约束 `oled_test.xdc`，可以把整个 `OLED_Test` 文件夹单独复制到另一台电脑。
若仍黑屏，先检查烧录文件、JB 接线方向和供电；黑屏本身不能单独证明 OLED 损坏。

依据：[Digilent PmodOLEDrgb 手册](https://digilent.com/reference/_media/reference/pmod/pmodoledrgb/pmodoledrgb_rm.pdf)、[SSD1331 数据手册](https://support.newhavendisplay.com/hc/en-us/article_attachments/4414853585815)。
