# codex_gen 使用说明

## 文件位置
- 主脚本: `codex_gen/ChannelFixedPointTools.m`
- 输出目录: `codex_gen/output/`
- 验证样例: `codex_gen/validation_H_4x4_t24.mat`（运行时可选择生成）

## 运行步骤
1. 在 MATLAB 中切换目录到 `codex_gen`：
   `.../channelGen/codex_gen`
2. 运行：
   ```matlab
   results = ChannelFixedPointTools();
   ```
3. 按提示：
   - 可先生成验证样例（4x4, T_num=24）
   - 选择要处理的 `.mat`
   - 选择归一化、自动/手动 IQ_max

## 生成结果
脚本会在 `codex_gen/output/` 下生成：
- `xxx_fixedpoint.mat`
- `xxx.irc`
- `xxx.ird`

## 说明
- `.irc` 打包：`BIT[15:0]=实部`, `BIT[31:16]=虚部`
- `.ird` 写法：按文档伪代码，仅写 `mod(n,2)==0`(0-based) 对应的 OUT 通道
- `delay` 输入单位固定按 `ns` 解释（与最新 `codex.md` 一致）
- `T_num` 自动补齐到 `T1_num=ceil(T_num/4)*4`，补齐部分写 0
- 文本文件编码为 UTF-8
- `xxx_fixedpoint.mat` 保存主量化字段 `qRealFi`、`qImagFi`，并额外保存兼容字段 `delay_clks`、`IQ_max`、`CIR_update_rate`
- `.irc/.ird` 行格式：连续写 tap 字流，但每 4 个 32-bit 字换行
  - 每行固定 `4 x 8 = 32` 个 hex 字符
  - 行内不加空格或分隔符

## 验证脚本
- 使用 `verify_ird_file`（保持原文件名）进行交互式校验：
  - 可选择原始 `.mat`，也可直接选择生成后的 `*_fixedpoint.mat`
  - 自动匹配或弹窗选择 `.irc/.ird`
  - 同时校验 `.irc` 和 `.ird` 的内容与行格式（每行必须为 `32` 个 hex 字符）
