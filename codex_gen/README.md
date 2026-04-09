# codex_gen 使用说明

## 文件位置
- 主脚本: `codex_gen/ChannelFixedPointTools.m`
- 输出目录: `codex_gen/output/`
- 验证样例目录: `codex_gen/validation_mats/`（运行时可选择生成）
- 验证样例文件:
  - `validation_basic.mat`
  - `validation_delay_delta.mat`
  - `validation_padding.mat`
  - `validation_channel_coverage.mat`
  - `validation_quant_boundary.mat`

## 运行步骤
1. 在 MATLAB 中切换目录到 `codex_gen`：
   `.../channelGen/codex_gen`
2. 运行：
   ```matlab
   results = ChannelFixedPointTools();
   ```
3. 按提示：
   - 可先生成一组验证样例
   - 选择要处理的 `.mat`
   - 选择归一化、自动/手动 IQ_max
   - 输入 FPGA 时钟频率（默认 `245.76e6`，调试模式可输入 `1e9`）

## 验证样例说明
- `validation_basic.mat`: 基础可读性样例，用于人工核对 `sample / in / out / tap` 编码与落盘顺序
- `validation_delay_delta.mat`: 时延变化量样例，覆盖相邻时刻时延增大、减小、不变三种情况
- `validation_padding.mat`: 补零对齐样例，`T_num=22`，用于检查 `TZ_num` 补零与每4个32-bit字换行
- `validation_channel_coverage.mat`: 子信道完整性样例，用于检查偶数/奇数 `out_num` 是否都完整写出
- `validation_quant_boundary.mat`: 定点边界样例，用于检查舍入、饱和和 `int16` 边界行为

## 生成结果
脚本会在 `codex_gen/output/` 下生成：
- `xxx_fixedpoint.mat`
- `xxx.irc`
- `xxx.ird`
- `xxx_irc_decimal.txt`
- `xxx_ird_decimal.txt`

## 说明
- `.irc` 打包：`BIT[15:0]=实部`, `BIT[31:16]=虚部`
- `.ird` 写法：对所有 `OUT` 子信道都写出时延系数，避免遗漏偶数/奇数通道
- `delay` 输入单位固定按 `ns` 解释（与最新 `codex.md` 一致）
- `T_num` 自动补齐到 `T1_num=ceil(T_num/4)*4`，补齐部分写 0
- 文本文件编码为 UTF-8
- `xxx_fixedpoint.mat` 同时保留原始浮点变量 `H`，并保存量化结果 `Hq`
- `Hq` 与 `H` 结构保持一致，但其中 delay 列改为 `delay_clks` 对应的整数时钟计数，real/imag 为量化后的整数
- `xxx_fixedpoint.mat` 还保存 `qRealFi`、`qImagFi`，以及兼容字段 `delay_clks`、`IQ_max`、`CIR_update_rate`
- `.irc/.ird` 行格式：连续写 tap 字流，但每 4 个 32-bit 字换行
  - 每行固定 `4 x 8 = 32` 个 hex 字符
  - 行内不加空格或分隔符
- `xxx_irc_decimal.txt` 用于手工检查：每个 32-bit 字按 `.irc` 显示顺序拆成 2 个 `int16` 十进制数（先虚部、后实部），每行共 8 个数
- `xxx_ird_decimal.txt` 用于手工检查：每个 32-bit 字转成 1 个十进制数，每行共 4 个数

## 验证脚本
- 使用 `verify_ird_file`（保持原文件名）进行交互式校验：
  - 可选择原始 `.mat`，也可直接选择生成后的 `*_fixedpoint.mat`
  - 自动匹配或弹窗选择 `.irc/.ird`
  - 同时校验 `.irc` 和 `.ird` 的内容与行格式（每行必须为 `32` 个 hex 字符）
