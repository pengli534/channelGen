# channelGen

`channelGen` 是一个面向 FPGA 信道模拟器调试流程的 MATLAB 工具仓库，用于把浮点信道系数 `.mat` 文件转换为定点结果，并导出 FPGA 可用的 `.irc` / `.ird` 文本文件。

当前仓库主要包含：

- 信道系数定点化主工具
- `.irc` / `.ird` 文件导出
- 面向人工检查的十进制展开辅助文件
- 验证样例生成与文件一致性校验脚本

## 适用场景

本仓库适用于以下工作流：

- 已有外部工具生成的浮点信道系数 `H`
- 需要将信道系数量化为 `int16` 定点格式
- 需要生成 FPGA 调试或联调用的 `.irc` / `.ird` 文件
- 需要人工检查导出文件是否符合接口约定和打包格式

## 仓库结构

```text
channelGen/
├─ README.md
├─ codex.md
├─ 衰落模块交互接口.docx
└─ codex_gen/
   ├─ ChannelFixedPointTools.m
   ├─ verify_ird_file.m
   └─ README.md
```

## 核心脚本

### `codex_gen/ChannelFixedPointTools.m`

主入口脚本，用于：

- 交互式选择输入 `.mat`
- 解析信道系数 `H`
- 可选生成一组验证样例 `.mat`
- 执行信道系数量化
- 将 `delay` 转换为 FPGA 时钟计数
- 导出以下文件到 `codex_gen/output/`

输出文件包括：

- `xxx_fixedpoint.mat`
- `xxx.irc`
- `xxx.ird`
- `xxx_irc_decimal.txt`
- `xxx_ird_decimal.txt`

### `codex_gen/verify_ird_file.m`

交互式校验工具，用于：

- 选择原始 `.mat` 或生成后的 `*_fixedpoint.mat`
- 自动匹配或手动选择 `.irc` / `.ird`
- 同时校验文件内容与行格式

## 输入数据约定

输入 `.mat` 文件中应包含变量 `H`。

`H` 的典型组织形式为：

```text
Nsamples x (T_num * 3) x (IN_num * OUT_num)
```

其中每个 tap 由三元组组成：

```text
[delay, real, imag]
```

说明：

- `delay` 单位按 `ns` 解释
- `T_num` 为每个子信道的 tap 数量
- 若 `H` 只有二维，则按单通道 `IN_num = OUT_num = 1` 处理
- 若 `.mat` 中存在 `IN_num`、`OUT_num`、`CIR_update_rate` 等元数据，脚本会优先读取

## 导出格式

### `.irc`

- 每个 32-bit 字打包一个复数系数
- `BIT[15:0] = real`
- `BIT[31:16] = imag`

### `.ird`

- 保存时延相关系数
- `BIT[30:0]` 为时延变化量对应的 FPGA 时钟计数
- `BIT[31]` 表示方向位

### 对齐规则

- `T_num` 会自动补齐到 `T1_num = ceil(T_num / 4) * 4`
- 不足部分补零
- `.irc` / `.ird` 每行固定写 4 个 32-bit 字
- 每行固定 32 个十六进制字符，不加空格

## 快速开始

1. 在 MATLAB 中切换到 `codex_gen/`
2. 运行主脚本：

```matlab
results = ChannelFixedPointTools();
```

运行过程中会交互式提示：

- 是否生成验证样例
- 选择输入 `.mat`
- 是否归一化
- 自动或手动指定 `IQ_max`
- 输入 FPGA 时钟频率

默认 FPGA 时钟频率为：

```text
245.76e6 Hz
```

调试模式下也可输入：

```text
1e9 Hz
```

## 验证样例

主脚本可生成一组用于人工检查的验证样例，典型包括：

- `validation_basic.mat`
- `validation_delay_delta.mat`
- `validation_padding.mat`
- `validation_channel_coverage.mat`
- `validation_quant_boundary.mat`

这些样例分别用于覆盖：

- 基础维度与编码可读性
- 时延增减变化
- 非 4 对齐 tap 的补零行为
- 子信道完整写出
- 定点边界、舍入与饱和

## 校验方式

运行：

```matlab
report = verify_ird_file();
```

该工具会：

- 检查 `.irc` / `.ird` 内容是否与 `.mat` 一致
- 检查每行是否满足 4 个 32-bit 字对齐格式
- 返回结构化校验结果 `report`

## 依赖环境

- MATLAB
- Fixed-Point Designer / Fixed-Point Toolbox

## 相关文档

- `codex.md`：需求、格式说明和开发记录
- `衰落模块交互接口.docx`：外部接口说明文档
- `codex_gen/README.md`：脚本级使用说明

## 说明

本仓库当前重点是生成适用于 FPGA 调试与验证的信道系数文件，而不是完整的信道建模平台。若后续需要批处理、自动化测试或非交互式接口，可以在现有脚本基础上继续扩展。
