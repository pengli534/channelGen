function report = verify_ird_file()
% verify_ird_file
% -------------------------------------------------------------------------
% 交互式校验工具：同时校验 .irc 和 .ird
%
% 设计目标：
%   1) 不要求手工在命令行填写路径字符串
%   2) 用户通过文件选择框选择 .mat
%   3) 自动尝试匹配对应 .irc/.ird；匹配不到则弹窗继续选择
%   4) 校验数据值与格式（每行固定4个32-bit字，即32个hex字符）
%
% 输出：
%   report.irc / report.ird 结构体，包含一致性与首个差异位置
% -------------------------------------------------------------------------

clc;

thisFile = mfilename('fullpath');
scriptDir = fileparts(thisFile);
projectRoot = fileparts(scriptDir);
defaultMatDir = fullfile(projectRoot, 'tap_to_asc_matlab', 'cir_mat_file');
defaultOutDir = fullfile(scriptDir, 'output');

if isfolder(defaultMatDir)
    matStartDir = defaultMatDir;
else
    matStartDir = projectRoot;
end

% 1) 选择 MAT
[matName, matPath] = uigetfile({'*.mat','MAT files (*.mat)'}, '选择用于校验的 .mat 文件', matStartDir);
if isequal(matName, 0)
    error('未选择 .mat 文件，校验终止。');
end
matFile = fullfile(matPath, matName);

src = load(matFile);
if isfield(src, 'H')
    H = src.H;
elseif isfield(src, 'Hq')
    H = src.Hq;
else
    H = [];
end
if isfield(src, 'H')
    H_float = src.H;
else
    H_float = [];
end
if isfield(src, 'Hq')
    H_quantized = src.Hq;
else
    H_quantized = [];
end

if ~isempty(H)
    if ~isnumeric(H) || ~(ismatrix(H) || ndims(H)==3)
        error('H/Hq 必须是2D或3D数值数组。');
    end

    Nsamples = size(H,1);
    packedCols = size(H,2);
    if mod(packedCols,3)~=0
        error('H/Hq 第二维不是3的倍数，无法按 delay/real/imag 解析。');
    end
    T_num = packedCols/3;
    T1_num = ceil(T_num/4)*4;

    if ismatrix(H)
        Nchannel = 1;
    else
        Nchannel = size(H,3);
    end
elseif isfield(src, 'delay_clks') || isfield(src, 'delayClocks')
    delayClocks = readDelayClocks(src);
    if ~isnumeric(delayClocks) || ndims(delayClocks) ~= 3
        error('delay_clks/delayClocks 必须是 3D 数值数组。');
    end
    Nsamples = size(delayClocks,1);
    T_num = size(delayClocks,2);
    T1_num = ceil(T_num/4)*4;
    Nchannel = size(delayClocks,3);
else
    error('所选 .mat 需要包含 H、Hq 或 delay_clks/delayClocks 之一。');
end

[IN_num, OUT_num] = inferInOut(src, Nchannel);

% 2) 自动推断 .irc/.ird 路径，不存在则弹窗选
[~, baseName, ~] = fileparts(matName);
fileStem = stripFixedpointSuffix(baseName);
autoIrc = fullfile(defaultOutDir, [fileStem, '.irc']);
autoIrd = fullfile(defaultOutDir, [fileStem, '.ird']);

if isfile(autoIrc)
    ircFile = autoIrc;
else
    if isfolder(defaultOutDir)
        irStartDir = defaultOutDir;
    else
        irStartDir = matPath;
    end
    [ircName, ircPath] = uigetfile({'*.irc','IRC files (*.irc)'}, '选择待校验的 .irc 文件', irStartDir);
    if isequal(ircName,0)
        error('未选择 .irc 文件，校验终止。');
    end
    ircFile = fullfile(ircPath, ircName);
end

if isfile(autoIrd)
    irdFile = autoIrd;
else
    if isfolder(defaultOutDir)
        irStartDir = defaultOutDir;
    else
        irStartDir = matPath;
    end
    [irdName, irdPath] = uigetfile({'*.ird','IRD files (*.ird)'}, '选择待校验的 .ird 文件', irStartDir);
    if isequal(irdName,0)
        error('未选择 .ird 文件，校验终止。');
    end
    irdFile = fullfile(irdPath, irdName);
end

fprintf('\n===== 校验输入 =====\n');
fprintf('MAT: %s\n', matFile);
fprintf('IRC: %s\n', ircFile);
fprintf('IRD: %s\n', irdFile);
fprintf('Nsamples=%d, T_num=%d, T1_num=%d, IN=%d, OUT=%d, channels=%d\n', ...
    Nsamples, T_num, T1_num, IN_num, OUT_num, Nchannel);
if isfield(src, 'meta') && isstruct(src.meta) && isfield(src.meta, 'mimo_bidi_enabled')
    fprintf('双向信道测试并置零: %d\n', double(src.meta.mimo_bidi_enabled));
end

% 3) 从 H 生成期望字流
if ~isempty(H)
    H_delay = extractTriplet(H,1);
    H_real  = extractTriplet(H,2);
    H_imag  = extractTriplet(H,3);
else
    H_delay = [];
    H_real = [];
    H_imag = [];
end

[qReal, qImag] = getQuantizedRI(H_real, H_imag, src);

expIrc = buildExpectedIrc(qReal, qImag, IN_num, OUT_num, T_num, T1_num);
expIrd = buildExpectedIrd(H_delay, src, IN_num, OUT_num, T_num, T1_num);

% 4) 读取文件字流（并检查每行格式）
gotIrc = readHexWordsAligned4(ircFile);
gotIrd = readHexWordsAligned4(irdFile);

% 5) 比较
[rIrcSame, rIrcDiff, rIrcIdx, rIrcGot, rIrcExp] = compareWords(gotIrc, expIrc);
[rIrdSame, rIrdDiff, rIrdIdx, rIrdGot, rIrdExp] = compareWords(gotIrd, expIrd);

fprintf('\n===== IRC 校验结果 =====\n');
printCmp(rIrcSame, rIrcDiff, rIrcIdx, rIrcGot, rIrcExp, numel(gotIrc), numel(expIrc));

fprintf('\n===== IRD 校验结果 =====\n');
printCmp(rIrdSame, rIrdDiff, rIrdIdx, rIrdGot, rIrdExp, numel(gotIrd), numel(expIrd));

mimoBidiReport = struct('enabled', false, 'supported', false, 'H_same', true, ...
    'Hq_same', true, 'H_nonzero_count', 0, 'Hq_nonzero_count', 0, ...
    'DL_num', 0, 'UL_num', 0);
if isfield(src, 'meta') && isstruct(src.meta) && isfield(src.meta, 'mimo_bidi_enabled') ...
        && double(src.meta.mimo_bidi_enabled) == 1
    mimoBidiReport.enabled = true;
    [DL_num, UL_num] = readBidiDlUl(src.meta, IN_num);
    mimoBidiReport.DL_num = DL_num;
    mimoBidiReport.UL_num = UL_num;
    mimoBidiReport.supported = (IN_num == OUT_num && IN_num >= 2 && ...
        DL_num > 0 && UL_num > 0 && DL_num + UL_num == IN_num);
    if ~isempty(H_float)
        [mimoBidiReport.H_same, mimoBidiReport.H_nonzero_count] = ...
            checkMimoBidiZeroed(H_float, IN_num, OUT_num, DL_num, UL_num);
    end
    if ~isempty(H_quantized)
        [mimoBidiReport.Hq_same, mimoBidiReport.Hq_nonzero_count] = ...
            checkMimoBidiZeroed(H_quantized, IN_num, OUT_num, DL_num, UL_num);
    end

    fprintf('\n===== 双向信道测试并置零校验 =====\n');
    fprintf('supported=%d, DL_num=%d, UL_num=%d, H_same=%d, H_nonzero_count=%d, Hq_same=%d, Hq_nonzero_count=%d\n', ...
        mimoBidiReport.supported, DL_num, UL_num, mimoBidiReport.H_same, mimoBidiReport.H_nonzero_count, ...
        mimoBidiReport.Hq_same, mimoBidiReport.Hq_nonzero_count);
end

report = struct();
report.input = struct('mat', matFile, 'irc', ircFile, 'ird', irdFile);
report.meta = struct('Nsamples', Nsamples, 'T_num', T_num, 'T1_num', T1_num, ...
    'IN_num', IN_num, 'OUT_num', OUT_num, 'Nchannel', Nchannel);
report.irc = struct('same', rIrcSame, 'diff_count', rIrcDiff, 'first_diff_idx', rIrcIdx, ...
    'got', rIrcGot, 'exp', rIrcExp, 'file_len', numel(gotIrc), 'exp_len', numel(expIrc));
report.ird = struct('same', rIrdSame, 'diff_count', rIrdDiff, 'first_diff_idx', rIrdIdx, ...
    'got', rIrdGot, 'exp', rIrdExp, 'file_len', numel(gotIrd), 'exp_len', numel(expIrd));
report.mimo_bidi = mimoBidiReport;
end

function [IN_num, OUT_num] = inferInOut(src, Nchannel)
IN_num = readScalar(src, {'IN_num','N_T','Ntx','N_mimo_input','MIMOInputCount'}, NaN);
OUT_num = readScalar(src, {'OUT_num','N_R','Nrx','N_mimo_output','MIMOOutputCount'}, NaN);
if ~isnan(IN_num) && ~isnan(OUT_num)
    IN_num = max(1, round(IN_num));
    OUT_num = max(1, round(OUT_num));
    return;
end
if Nchannel == 1
    IN_num = 1; OUT_num = 1; return;
end
s = round(sqrt(Nchannel));
if s*s == Nchannel
    IN_num = s; OUT_num = s;
else
    IN_num = 1; OUT_num = Nchannel;
end
end

function v = readScalar(src, names, defaultV)
v = defaultV;
for i=1:numel(names)
    n=names{i};
    if isfield(src,n)
        t=src.(n);
        if isnumeric(t) && isscalar(t)
            v=double(t);
            return;
        end
    end
end
if isfield(src, 'meta') && isstruct(src.meta)
    meta = src.meta;
    for i=1:numel(names)
        n=names{i};
        if isfield(meta,n)
            t=meta.(n);
            if isnumeric(t) && isscalar(t)
                v=double(t);
                return;
            end
        end
    end
end
end

function X = extractTriplet(H,pos)
if ismatrix(H)
    X = zeros(size(H,1), size(H,2)/3, 1);
    X(:,:,1)=H(:,pos:3:end);
else
    X = zeros(size(H,1), size(H,2)/3, size(H,3));
    for ch=1:size(H,3)
        X(:,:,ch)=H(:,pos:3:end,ch);
    end
end
end

function [qReal, qImag] = getQuantizedRI(H_real, H_imag, src)
% 优先路径：如果当前 MAT 已是 *_fixedpoint.mat，直接读取 qRealFi/qImagFi。
if isfield(src, 'qRealFi') && isfield(src, 'qImagFi')
    qReal = int16(src.qRealFi.int);
    qImag = int16(src.qImagFi.int);
    return;
end
% Backward compatibility for older MAT files that used fi_real/fi_imag.
if isfield(src, 'fi_real') && isfield(src, 'fi_imag')
    qReal = int16(src.fi_real.int);
    qImag = int16(src.fi_imag.int);
    return;
end

% 回退路径：按主程序默认策略从原始H重算量化值。
if isempty(H_real) || isempty(H_imag)
    error('当前 .mat 缺少可用于重算量化的 H/Hq，也没有保存 qRealFi/qImagFi（旧版兼容名为 fi_real/fi_imag）。');
end
normalizeFlag = readScalar(src, {'normalize','Normalize'}, NaN);
IQ_max = readScalar(src, {'IQ_max','IQMax'}, NaN);
if isnan(normalizeFlag)
    normalizeFlag = 1;
end
if isnan(IQ_max)
    IQ_max = max(abs([H_real(:); H_imag(:)]));
    if IQ_max == 0
        IQ_max = 1;
    end
end
if normalizeFlag == 1
    scale = (2^15 - 1) / IQ_max;
else
    scale = 1;
end
fm = fimath('RoundingMethod','Nearest', 'OverflowAction','Saturate');
qRealFi = fi(H_real * scale, 1, 16, 0, fm);
qImagFi = fi(H_imag * scale, 1, 16, 0, fm);
qReal = int16(qRealFi.int);
qImag = int16(qImagFi.int);
end

function words = readHexWordsAligned4(pathName)
% 每行必须恰好包含4个32-bit字，即32个hex字符。
raw = fileread(pathName);
lines = string(splitlines(raw));
lines = strtrim(lines);
lines(lines=="") = [];

if isempty(lines)
    words = zeros(0,1,'uint32');
    return;
end

expectedChars = 32; % 4 words * 8 hex chars
hexCells = strings(0,1);
for i=1:numel(lines)
    s = char(lines(i));
    if length(s) ~= expectedChars
        error('文件 %s 第%d行长度为%d，不等于期望%d(=4*8)。', pathName, i, length(s), expectedChars);
    end
    for k=1:4
        seg = s((k-1)*8 + (1:8));
        hexCells(end+1,1) = string(seg); %#ok<AGROW>
    end
end
words = uint32(hex2dec(hexCells));
end

function out = buildExpectedIrc(qReal, qImag, IN_num, OUT_num, T_num, T1_num)
Nsamples = size(qReal,1);
Nchannel = size(qReal,3);
out = zeros(Nsamples * IN_num * OUT_num * T1_num, 1, 'uint32');
idx = 1;

% 与主程序一致顺序: s -> m -> n -> t
for s = 1:Nsamples
    for m = 1:IN_num
        for n = 1:OUT_num
            ch = (m-1)*OUT_num + n;
            if ch > Nchannel
                error('channel overflow in IRC build');
            end
            for t = 1:T1_num
                if t <= T_num
                    re16 = typecast(qReal(s,t,ch), 'uint16');
                    im16 = typecast(qImag(s,t,ch), 'uint16');
                    out(idx) = bitor(uint32(re16), bitshift(uint32(im16), 16));
                else
                    out(idx) = uint32(0);
                end
                idx = idx + 1;
            end
        end
    end
end
end

function out = buildExpectedIrd(H_delay, src, IN_num, OUT_num, T_num, T1_num)
delayClocks = readDelayClocks(src);
if isempty(delayClocks)
    if isempty(H_delay)
        error('缺少 delay 数据，无法构造期望 .ird。');
    end
    % 最新 codex.md: delay 单位固定 ns
    fpgaClock = readScalar(src, {'fpga_clock_hz','FPGAClockHz'}, 245.76e6);
    delayClocks = round(H_delay * 1e-9 * fpgaClock);
end

Nsamples = size(delayClocks,1);
Nchannel = size(delayClocks,3);
out = zeros(Nsamples * IN_num * OUT_num * T1_num, 1, 'uint32');
idx = 1;

% 与主程序一致顺序: s -> m -> n -> t
for s = 1:Nsamples
    for m = 1:IN_num
        for n = 1:OUT_num
            ch = (m-1)*OUT_num + n;
            if ch > Nchannel
                error('channel overflow in IRD build');
            end
            for t = 1:T1_num
                if t <= T_num
                    if s == 1
                        prev = int64(0);
                    else
                        prev = int64(delayClocks(s-1,t,ch));
                    end
                    cur = int64(delayClocks(s,t,ch));
                    delta = cur - prev;
                    mag = uint32(min(abs(delta), int64(2^31-1)));
                    if delta < 0
                        out(idx) = bitor(bitshift(uint32(1),31), mag);
                    else
                        out(idx) = mag;
                    end
                else
                    out(idx) = uint32(0);
                end
                idx = idx + 1;
            end
        end
    end
end
end

function baseName = stripFixedpointSuffix(baseName)
suffix = '_fixedpoint';
if endsWith(baseName, suffix)
    baseName = baseName(1:end-length(suffix));
end
end

function delayClocks = readDelayClocks(src)
delayClocks = [];
if isfield(src, 'delay_clks')
    delayClocks = src.delay_clks;
elseif isfield(src, 'delayClocks')
    delayClocks = src.delayClocks;
end
end

function [same, diffCount, firstIdx, gotVal, expVal] = compareWords(got, exp)
if numel(got) ~= numel(exp)
    same = false;
    diffCount = abs(numel(got)-numel(exp)) + min(numel(got),numel(exp));
    firstIdx = 1;
    gotVal = uint32(0);
    expVal = uint32(0);
    if ~isempty(got), gotVal = got(1); end
    if ~isempty(exp), expVal = exp(1); end
    return;
end
m = (got ~= exp);
diffCount = nnz(m);
same = diffCount == 0;
if same
    firstIdx = 0; gotVal = uint32(0); expVal = uint32(0);
else
    firstIdx = find(m,1,'first');
    gotVal = got(firstIdx);
    expVal = exp(firstIdx);
end
end

function printCmp(same, diffCount, firstIdx, gotVal, expVal, gotLen, expLen)
fprintf('same=%d, diff=%d, len(file/exp)=%d/%d\n', same, diffCount, gotLen, expLen);
if ~same
    fprintf('first_diff_idx=%d, got=%08X, exp=%08X\n', firstIdx, gotVal, expVal);
end
end

function [DL_num, UL_num] = readBidiDlUl(meta, IN_num)
DL_num = readScalar(meta, {'mimo_bidi_dl_num','DL_num'}, NaN);
UL_num = readScalar(meta, {'mimo_bidi_ul_num','UL_num'}, NaN);
if isnan(DL_num) || isnan(UL_num)
    % 兼容旧输出：旧版本仅支持偶数维二等分。
    if mod(IN_num, 2) == 0
        DL_num = IN_num / 2;
        UL_num = IN_num / 2;
    else
        DL_num = 0;
        UL_num = 0;
    end
end
DL_num = round(DL_num);
UL_num = round(UL_num);
end

function [same, nonzeroCount] = checkMimoBidiZeroed(H, IN_num, OUT_num, DL_num, UL_num)
nonzeroCount = 0;
if isempty(H) || ~(IN_num == OUT_num && IN_num >= 2 && ...
        DL_num > 0 && UL_num > 0 && DL_num + UL_num == IN_num)
    same = false;
    return;
end

H_delay = extractTriplet(H, 1);
H_real = extractTriplet(H, 2);
H_imag = extractTriplet(H, 3);

for m = 1:IN_num
    for n = 1:OUT_num
        keepBlock1 = (m >= 1 && m <= DL_num && n >= 1 && n <= UL_num);
        keepBlock2 = (m >= DL_num + 1 && m <= DL_num + UL_num && ...
            n >= UL_num + 1 && n <= UL_num + DL_num);
        if ~(keepBlock1 || keepBlock2)
            ch = (m - 1) * OUT_num + n;
            nz = nnz(H_delay(:,:,ch) ~= 0) + nnz(H_real(:,:,ch) ~= 0) + nnz(H_imag(:,:,ch) ~= 0);
            nonzeroCount = nonzeroCount + nz;
        end
    end
end

same = nonzeroCount == 0;
end
