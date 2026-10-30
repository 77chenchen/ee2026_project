# OLED 最小亮屏测试

这个独立工程只用 `OLED_Test_Top.v` 和仓库已有的课程 `Oled_Display.v`。
上板后无需按键或拨码，连接在 **JB** 的 OLED 应在初始化后显示**整屏白色**。

在 Windows Vivado 的 Tcl Console 执行（替换成实际路径）：

```tcl
source {C:/path/to/ee2026_project/OLED_Test/build.tcl}
```

脚本生成独立工程并运行综合、布线和 bitstream；烧录：

```text
OLED_Test/vivado_project/OLED_Test.runs/impl_1/OLED_Test_Top.bit
```

接线前先给开发板断电，将 OLED 对准完整的双排 **JB** 插好，核对 GND/VCC，避免反插或错位。
这个测试不使用原计算器顶层。若仍黑屏，先确认烧录的是上述 `.bit`、JB 插接方向和供电；黑屏本身不能证明 OLED 已损坏。
