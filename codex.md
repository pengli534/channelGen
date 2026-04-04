
# 任务：信道系数定点化工具

# 要求

编辑MATALB代码，支持fixed point toolbox

## 预期输入
* 能够询问.mat文件的位置，load 信道系数（浮点）数据到matlab 的 workspace；
* 输入是load一个*.mat文件，文件主要数据是信道系数H（例子见附件文件）；首先检查信道系数H的几个维度 Nsamples × （T_num×3） × （IN_num × OUT_num）
* IN_num是输入数据通道的数量，OUT_num是输出数据通道的数量，当IN_num = OUT_num = 时，2×2=4 共四个信道(channel)；如果只有Nsamples × （T_num×3）两个维度，说明IN_num=OUT_num=1；
* T_num 是每个信道的多径数量，对应TDL模型滤波器的抽头个数，每个tap包括了 相对时延（delay）；信道系数实数部分；信道系数虚数部分；相对时延的单位是：ns
* 除此以外，CIR update rate等相关参数也需要load到workspace备用。

## 处理过程要求
* 代码需要能够分析TDL多径信道系数的数据，包括但不限于 tap点的数量、tap之间的相对时延、以及实数部分和虚数部分的值，评估包括但不限于信道平均功率参数，model gain等（如果写的不准确可补充或更正），并打印分析结果；
* 能够根据 CIR update rate（信道刷新率）分析与信道仿真相关的参数：包括但不限于Nsamples对应的仿真时长，多普勒扩展等指标（如果写的不准确可补充或更正）；
* 使用matlab的fi实现定点化，完成信道系数的定点化操作，信道系数位宽为16bit有符号整数，需要打印显示定点方式；
* 能够选择是否需要进行信道归一化操作；
* 定点化需符合“信道系数定点化”要求；
* irc 和 ird 文件保存格式需要满足“irc 和 ird 文件保存格式”要求。

## 预期输出要求
* 能够计算并展示量化误差，误差容忍度：< $10^{-4}$；
* 并把信道系数存储为：新的*.mat文件（定点化后的fi）以及FPGA调试时可用的*.irc文件和*.ird文件；
* 信道模型滤波器系数（coeff）文件保存为*.irc；信道模型时延系数（delay）文件保存为*.ird；
* *.irc 和 *.ird 两个Plain text UTF-8文件。

# 处理方法
## 信道系数定点化
* 信道系数的实部和虚部均为有符号16位整数，其中符号占1位，因此有符号16位整数的取值范围为：-32768 ~ 32768，归一化公式为：Q = round（x/{IQ_max}*(2^15-1)）
* 例如，{IQ_max}=54.7时，当x=-54.7时，Q=-32768；当x=0时，Q=0；当x=54.7时，Q=54.7时，Q=32767。
* 再例如，{IQ_max}=3.5时，当x=3.0时，Q=28086；当x=-1.5时，Q=-14043

## irc 和 ird 文件保存格式
* 满足“衰落模块交互接口.docx”中“二、信道模型文件格式说明”的要求。
* 时延系数ird和滤波器系数irc在文件中，任何情况下必须满足4个32比特对齐模式，当不满足要求时，需要补齐TZnum个32比特的0。
* 滤波器系数：BIT[15:0]：信道系数实部；BIT[31:16]：信道系数虚部；
* 时延系数：BIT[30:0]：相对时延对应的FPGA系统时钟个数，即当前时刻的时延相对于前一刻时延的变化量。BIT[31]为0时，表示滑动时延增大；BIT[31]为1时，表示滑动时延减小；“FPGA系统时钟个数”需要通过相对时延和采样周期计算获得。
* irc 和 ird 的格式是 tap0[31:0]tap1 [31:0] ... tap23[31:0]，应连续写，不要每个tap换1行。但是每一行写满4个tap以后就要换行，来保证4个32比特对齐的要求。


# 背景
* 用于信道仿真器的FPGA逻辑设计测试，以及后期的应用软件开发；
* 工程背景：（1）信道仿真器研制；（2）信道仿真器中的FPGA逻辑正确性验证；（3）FPGA用于完成信道系数（定点化后的）与信号（定点化后的）的卷积计算，需要验证计算过程中的逻辑正确性以及定点化选择；
* 本代码仅用于生成定点化后的信道系数,并存为.mat文件提供后续仿真工作；

* 输入：信道的浮点系数CIR系数列表，已经用其他软件生成并保存为.mat格式（请分析附件.mat），随着taps数量增加，数据量增加，每条路径都含 delay image real 三组浮点数；
* Xilinx Ultrascale+ VU13P 系列FPGA 时钟频率 245.76e6Hz
* 信道刷新率 CIR update rate 最高不超过6e6Hz 对应的多普勒扩展为±1.5e6Hz
* 需要load的.mat 所在的位置 C:\Users\pengl\Documents\CloudStation\捷希科技\信道模拟器\fixedpoints\channelGen\tap_to_asc_matlab\cir_mat_file，可以多检查几组.mat中的H作为软件通用性的测试。

* irc 和 ird 文件保存格式伪代码
fopen(filter_coff_file)；
fopen(delay_coff_file)；
filter_coff_file_offset_=0;
delay_coff_file_offset_=0;
for(m=0; m++; m<INnum)
for(n=0; n++; n<OUTnum)
for(x=0; x++; x<T1num)
fwrite(filter_coff_file ,filter_coff_file_offset ,CF[m,n,x]);//CF是滤波器系数
filter_coff_file_offset = filter_coff_file_offset +4;	 //+4，一个系数占用4字节 
if(mod(n,2)==0)
fwrite (delay_coff_file ,delay_coff_file_offset ,CD[m,n,x]);//CD是时延系数
delay_coff_file_offset= delay_coff_file_offset+4; //+4，一个系数占用4字节
end
end
end
end
fclose(filter_coff_file);
fclose(delay_coff_file);

# 正确性验证
* “衰落模块交互接口.docx”中“二、信道模型文件格式说明”中的伪代码可用于参考并生成测试用例。
* 程序应能够生成一个验证性的*.mat文件供第一步骤时的手动选择， 信道系数H（T_num = 24） × （IN_num = 4  × OUT_num =4），方便人工验证程序的正确性。这个验证性的H中包含的delay image real 应该是很容易人工分辨的递增数，应该容易分辨是哪个IN_num OUT_num 组合中的 第几个 T_num。
* 在设计人工验证使用的H时，需要考虑方便人工查看，定点化前后的数据都比较容易人工分辨。

# 特殊情况
* 如果无法分析或理解，“衰落模块交互接口.docx” 以及 .mat文件，请说明并停止生成代码。

# 人工检查
* 人工检查时，发现落盘的*.ird 文件中 只包含了子信道 （in_num，out_num）为 out_num 为奇数时的子信道的时延系数，缺少out_num为偶数时的信道时延系数。请检查并更正。
* 怀疑 *.irc 是否也只包含了out_num 为奇数时的子信道的信道系数，请检查并更正。
* 手工调试时：*.irc每4个16进制数一组转换成10进制，生成的10进制数每行8个方便手工检查; *.ird 每8个16进制数一组转换成10进制，生成的10进制数每行4个。


# 更新
* 增加询问用户FPGA时钟频率的步骤，默认 245.76e6Hz，fpgaClock = 245.76e6，调试模式时 fpgaClock = 1e9;
* 输出的*.mat中Hq中所有关于时延的列，不应该保留以时间ns为单位的值（原始的 *.mat），应该用delay_clks中对应的整数，这样才是一个完备且一致的输出。
* 20260404 输出的*.mat 中保留原有的 变量H（浮点信道系数时延数据）格式不变，方便后期用户或程序调用，也方便查看H和Hq。
* 在README.md 中增加对于生成的 - `xxx_fixedpoint.mat`，`xxx.irc`，`xxx.ird` 说明。



