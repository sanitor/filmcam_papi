# 胶片相机智能辅助 App — 技术方案

## 1. 项目概述

跨平台（Android / iOS）App，为老胶片相机提供以下辅助功能：

| 功能 | 说明 | 精度目标 |
|------|------|----------|
| 测光 | 反射式测光（含点测光/中央重点/平均测光），支持入射测光（需外接柔光罩） | ±0.3 EV（校准后） |
| 测距 | 对焦距离测量，支持景深预览、超焦距计算 | ±1 cm @ ≤1 m；±5 cm @ 1–5 m |
| 测色温 | 光源色温（K）及色偏（Duv）测量 | ±200 K（校准后） |
| 取景辅助 | 根据画幅/焦距生成框线叠加，LiDAR 辅助对焦提示 | 视差 < 1° |

对标设备：Sony α1 / Nikon Z9 机内测光及白平衡。

---

## 2. 框架选择：Flutter

### 选型理由

| 维度 | Flutter | React Native |
|------|---------|--------------|
| GPU 管线 | Impeller 引擎，直接编译为原生机器码，无 JS Bridge | 新架构（Fabric + TurboModules）已大幅改善，但重计算场景仍有桥接损耗 |
| 相机帧处理 | `flutter_native_vision_camera` FFI 零拷贝纹理；`CameraImage` 可获取 RAW 像素 + 曝光元数据（aperture/exposureTime/ISO） | 需写自定义 Native Module，维护 Kotlin/Swift 两套胶水代码 |
| 跨平台一致性 | Skia/Impeller 渲染，像素级一致 | 依赖原生 UI 组件，各平台表现有差异 |
| 原生集成 | Platform Channel 足够成熟；复杂场景可写 Swift/Kotlin 插件 | 生态更成熟但重相机场景仍需自定义 Native Module |
| 社区活跃度 | 快速增长中，Camera + ML 插件日趋完善 | 更大但碎片化 |

**结论**：本 App 重度依赖相机传感器原始数据访问 + 实时帧处理 + 自定义 UI 叠加层，Flutter 的渲染管线一致性和 FFI 帧处理能力更适合，推荐 Flutter 3.29+（Impeller 引擎）。

---

## 3. 四大功能技术方案

### 3.1 测光 (Light Meter)

#### 原理

手机相机传感器本质就是一个数字测光表。通过读取 RAW 或 YUV 帧的像素亮度值，结合拍摄时的曝光参数（aperture、exposureTime、ISO），反推出场景的 EV（曝光值）。

#### 实现路径

```
┌─────────────────────┐
│ AVFoundation (iOS)   │  →  sensorSensitivity (ISO)
│ CameraX (Android)    │  →  sensorExposureTime (ns)
│                      │  →  lensAperture (f-stop)
│                      │  →  RAW pixel data
└────────┬────────────┘
         ↓
┌─────────────────────┐
│ Flutter CameraImage  │  → lensAperture / sensorExposureTime / sensorSensitivity
│ (CameraController)   │  → planes (YUV/Raw pixel buffers)
└────────┬────────────┘
         ↓
┌─────────────────────┐
│ 亮度 → EV 转换引擎    │  → EV = log₂(L * S / K)
│                      │  → L 由像素均值经校准曲线得出
│                      │  → 支持三种测光模式：
│                      │     - 平均 (整个画面)
│                      │     - 中央重点 (中心权重)
│                      │     - 点测 (5° 取景框)
└────────┬────────────┘
         ↓
┌─────────────────────┐
│ 用户可调校准偏移       │  → 针对特定手机型号预置 Profile
│ (Calibration Offset) │  → 用户可手动微调 (-5 ~ +5 EV)
└─────────────────────┘
```

#### 关键技术点

- **曝光锁定**：先调用 `setExposureMode(ExposureMode.locked)` 固定曝光，再读帧，确保测光值稳定
- **入射测光**：提示用户用前摄 + 手机背面贴柔光罩（135 胶卷盒），算法上做扩散补偿
- **胶片特性补偿**：针对不同胶片（如 Portra、HP5）做倒易律失效补偿数据库
- **精度**：参考 Lumu Power 2（硬件外设）和 Pellica 等已上线 App 的经验，通过校准可达 ±0.3 EV

### 3.1.1 曝光计算公式

所有公式以 **场景亮度 EV**（scene luminance）为中心，ISO 作为灵敏度参数参与计算，而非修正 EV 本身。

#### 基本定义

```
EV = scene luminance (场景亮度值)
N  = aperture f-number (光圈)
t  = shutter time in seconds (快门时间)
ISO = sensor/film sensitivity
```

#### evFromParams — 从曝光参数反推场景 EV

```
sceneEV = log₂(N² / t) − log₂(ISO / 100)
```

用途：相机传回一帧 metadata（N, t, ISO），反推当前场景亮度。

验证：

| N | t | ISO | sceneEV |
|---|----|-----|---------|
| f/8 | 1/250 | 400 | log₂(64×250) − log₂(4) = 14 − 2 = **12** |
| f/8 | 1/250 | 800 | log₂(64×250) − log₂(8) = 14 − 3 = **11** |
| f/8 | 1/500 | 400 | log₂(64×500) − log₂(4) = 15 − 2 = **13** |

ISO 翻倍 → same N,t 对应更暗场景 → sceneEV 更低 ✓
场景更亮（t 减半）→ sceneEV 更高 ✓

#### shutterFromEv — A 挡：根据场景 EV 算快门

```
t = N² · 100 / (ISO · 2^sceneEV)
```

用途：A 模式（光圈优先）下，用户设定 ISO + 光圈，App 自动计算快门。

验证：

| sceneEV | N | ISO | t |
|---------|---|-----|---|
| 12 | f/8 | 400 | 64 · 100 / (400 · 4096) = 6400 / 1,638,400 = **1/256** |
| 12 | f/8 | 800 | 64 · 100 / (800 · 4096) = 6400 / 3,276,800 = **1/512** |
| 13 | f/8 | 400 | 64 · 100 / (400 · 8192) = 6400 / 3,276,800 = **1/512** |

ISO 翻倍 → t 减半（更快快门）✓
场景更亮（sceneEV↑）→ t 减半（更快快门）✓

#### apertureFromEv — S 挡：根据场景 EV 算光圈

```
N = √(2^sceneEV · ISO · t / 100)
```

用途：S 模式（快门优先）下，用户设定 ISO + 快门，App 自动计算光圈。

验证：

| sceneEV | t | ISO | N |
|---------|---|-----|---|
| 12 | 1/250 | 400 | √(4096 · 400 · 0.004 / 100) = √(65.54) = **f/8.1** |
| 12 | 1/250 | 800 | √(4096 · 800 · 0.004 / 100) = √(131.07) = **f/11.4** |
| 13 | 1/250 | 400 | √(8192 · 400 · 0.004 / 100) = √(131.07) = **f/11.4** |

ISO 翻倍 → N 更大（更小光圈）✓
场景更亮（sceneEV↑）→ N 更大（更小光圈）✓

#### exposureDeviation — M 挡：曝光偏差

```dart
deviation = sceneEV − setEV
setEV = log₂(N²_user / t_user) − log₂(ISO_user / 100)
```

- `deviation > 0`：场景比设置亮 → 过曝（橙色标尺右偏）
- `deviation < 0`：场景比设置暗 → 欠曝（橙色标尺左偏）
- `deviation ≈ 0`：正确曝光（绿色标尺居中）

#### EV 补偿（Exposure Compensation）

EV 补偿的符号与场景 EV **相反**：

```
t_comp = N² · 100 / (ISO · 2^(sceneEV − EC))
N_comp = √(2^(sceneEV − EC) · ISO · t / 100)
```

| EC | 效果 | 公式影响 |
|----|------|---------|
| +1 | 过曝 1 挡（快门慢一挡/光圈大一挡） | sceneEV − 1 → t × 2 |
| −1 | 欠曝 1 挡（快门快一挡/光圈小一挡） | sceneEV + 1 → t / 2 |

### 3.2 测距 (Rangefinder / Distance Measurement)

#### 硬件依赖

| 设备类型 | 可用方案 | 精度 |
|----------|----------|------|
| iPhone Pro（12 Pro 起）| LiDAR dToF（扫描式） | cm 级 @ ≤5 m |
| iPhone 非 Pro、iPad 非 Pro | ARKit 单目深度估计 + 相位对焦数据 | dm 级 |
| Android（部分旗舰）| ToF 激光辅助对焦 * | 通常不开放给第三方 |
| Android（其他）| 单目视觉 + ML 深度估计 | dm ~ m 级 |

> \* Android OEM 的 ToF 硬件基本不通过标准 Camera2 API 暴露给第三方 App，仅供系统相机内部使用。即使有 `DEPTH16` / `DEPTH_POINT_CLOUD` 支持，各厂商实现迥异。**建议 Android 侧完全走单目 + ML 方案**。

#### 推荐方案

**iOS**：
- LiDAR 优先：ARKit `ARFrame.smoothedSceneDepth`（平滑深度图）→ 取中心点或点击点距离
- 非 Pro 机型：ARKit `ARFrame.estimatedDepthData`（单目估计）+ Camera 相位对焦辅助

**Android**：
- ARCore（Google Play Services for AR）Depth API：基于 ML 单目深度估计，覆盖广但精度一般
- Camera2 API `CONTROL_AF_MODE` + `LENS_FOCUS_DISTANCE`：可获取透镜对焦距离（单位 diopter），结合 PDAF 置信度推算

**统一上报**：
- 距离值在 UI 层统一显示
- 叠加景深标尺（DOF scale），根据画幅/焦距/光圈动态计算近界和远界
- 超焦距计算器

### 3.3 测色温 (Color Temperature)

#### 原理

从 YUV 帧或 RAW 帧的 R/G/B 通道比例，反推 CCT（相关色温）。公式基于 CIE 1931 色度图 + McCamy 算法。

#### 实现流程

```
RAW/YUV 帧 → RGB 均值（白/灰区域）→ xy 色度坐标 → CCT (K) + Duv
```

#### 关键点

- 需要用户对准白色/灰色表面（如白纸、18% 灰卡）
- 手机 ISP 的自动白平衡（AWB）会干扰测量 → **必须锁定 AWB**（iOS `AVCaptureDevice.lockForConfiguration()` + `setWhiteBalanceMode(.locked)`；Android `CONTROL_AWB_LOCK`）
- 校准：提供用户对已知光源（如日光 5500K）做偏差补偿
- **局限**：手机 CMOS 的 RGB 滤镜响应曲线与专业色度计（如 Sekonic C-800）差距显著，精度上限约为 ±200 K。若需专业级，应推荐外接硬件（如 SpectraCal C6）

### 3.4 取景辅助 (Viewfinder Assist)

#### 功能

1. **框线叠加**：根据画幅（135 / 120 / 大画幅）和焦距（mm），在 Live Preview 上叠加对应的取景框线
2. **视差补偿**：旁轴相机取景器与镜头存在视差，近摄时尤其明显 — 通过 LiDAR 测距自动平移框线
3. **景深指示**：根据距离 + 光圈 + 焦距，用 Zebra 条纹或渐变高亮显示合焦区域
4. **网格线**：三分法 / 黄金螺旋 / 水平仪

#### 实现

- Flutter `CustomPainter` 叠加在 `CameraPreview`（`Texture` widget）之上
- 视差计算：已知旁轴基线长度（如 Leica M 系列 69.25mm），结合 LiDAR 距离做三角平移
- 支持 49+ 种画幅预设（从 Super 8 到 20×24 英寸）
- 支持自定义镜头注册

---

## 4. 硬件兼容性矩阵

| 功能 | iOS 最低要求 | Android 最低要求 |
|------|------------|----------------|
| 测光（反射）| 任意 iPhone，iOS 15+ | 任意 Android 8+，Camera2 API |
| 测光（入射）| 任意 iPhone + 外接柔光罩 | 同上 + 外接柔光罩 |
| 测距（LiDAR）| iPhone 12 Pro+ | 不适用 |
| 测距（ML 单目）| 任意 iPhone（ARKit）| Android 8+，ARCore 支持 |
| 测距（对焦距离）| 任意 iPhone | Camera2 `LENS_FOCUS_DISTANCE` 支持 |
| 色温 | 任意 iPhone，需 AWB Lock | Camera2 `CONTROL_AWB_LOCK` 支持 |
| 取景辅助（框线）| 任意 iPhone | 任意 Android |
| 取景辅助（LiDAR 视差）| iPhone 12 Pro+ | 不适用 |

---

## 5. 精度对标方案

### 5.1 校准工作流

```
出厂预设 Profile
     ↓
用户首次启动 → 引导校准流程：
  1. 对 18% 灰卡测光 → 调 EV 偏移
  2. 对已知色温光源（如日光/钨丝灯）→ 调色温偏移
  3. 对已知距离（如 1m 标记）→ 调距离偏移
     ↓
保存为设备专属校准文件
     ↓
云端 Profile 共享 → 同型号手机可下载社区校准参数
```

### 5.2 精度验证方式

| 功能 | 验证工具 | 验证方法 |
|------|---------|----------|
| 测光 | Sekonic L-858 / Minolta VI F | 同场景同灰卡对比 EV 读数 |
| 测距 | 激光测距仪（如 Bosch GLM 系列）| 1m / 2m / 5m 定点对比 |
| 色温 | Sekonic C-800 / ColorChecker Passport | 标准光源下对比 K 值 + Duv |

### 5.3 预期精度

| 功能 | 校准前 | 校准后 |
|------|--------|--------|
| 反射测光 EV | ±1.0 EV | ±0.3 EV |
| LiDAR 测距 @ ≤1 m | ±2 cm | ±1 cm |
| LiDAR 测距 @ 1–5 m | ±5 cm | ±3 cm |
| 单目测距 | ±30% | ±15%（校准较难改善）|
| 色温 CCT | ±500 K | ±200 K |

---

## 6. 推荐技术架构

```
┌─────────────────────────────────────────┐
│                Flutter UI                │
│  ┌─────────┐ ┌────────┐ ┌────────────┐  │
│  │ Camera  │ │  HUD   │ │  Settings  │  │
│  │ Preview │ │ Overlay│ │  Panel     │  │
│  └────┬────┘ └────────┘ └────────────┘  │
│       │ CustomPainter                    │
├───────┴─────────────────────────────────┤
│          Dart 业务逻辑层                  │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌────────┐ │
│  │Meter │ │Range │ │Color │ │VFRew   │ │
│  │Engine│ │Engine│ │Engine│ │Engine  │ │
│  └──┬───┘ └──┬───┘ └──┬───┘ └───┬────┘ │
│     │        │         │         │       │
│  ┌──┴────────┴─────────┴─────────┴───┐  │
│  │         Calibration Manager       │  │
│  │         Device Profile DB         │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│          Flutter Platform Channel       │
├──────────┬──────────┬───────────────────┤
│  iOS      │ Android  │                  │
│  Native   │ Native   │  3rd SDK         │
│  Plugin   │ Plugin   │  (ARCore/MLKit)  │
│          │          │                  │
│ ARKit     │ CameraX  │ TensorFlow Lite  │
│ LiDAR     │ ARCore   │ CoreML (iOS)     │
│ AVFdn     │ ML Kit   │ ML Kit (Android)  │
└──────────┴──────────┴───────────────────┘
```

---

## 7. 关键依赖 / 插件

| 用途 | Flutter 包/原生方案 |
|------|-------------------|
| 相机控制 | `flutter_native_vision_camera`（零拷贝 FFI 帧处理，推荐）或官方 `camera` 包 |
| AR/深度 | iOS: ARKit（内置）；Android: `arcore_flutter_plugin` + ARCore Depth API |
| 设备传感器 | iOS: `sensors_plus` + 原生平台通道；Android: `sensors_plus` |
| 本地存储 | `isar` / `drift`（SQLite）— 存储校准参数、胶片库、拍摄日志 |
| 状态管理 | `riverpod`（推荐）或 `bloc` |
| 机器学习 | `tflite_flutter`（TensorFlow Lite 用于单目深度估计）|
| 文件导出 | `share_plus`（导出 CSV 曝光日志）|
| 国际化 | `flutter_localizations` / `slang`（中英双语）|

---

## 8. 开发路线图（预估）

| 阶段 | 内容 | 时间 |
|------|------|------|
| Phase 0 | 技术验证 POC — 单平台（iOS）实现基础测光 + LiDAR 测距 | 4 周 |
| Phase 1 | Flutter 框架搭建 + 相机预览 + 测光核心 + 校准系统 | 6 周 |
| Phase 2 | 测距模块（LiDAR + 单目）+ 景深计算器 | 4 周 |
| Phase 3 | 色温测量 + 取景框线叠加 + 视差补偿 | 4 周 |
| Phase 4 | Android 适配（CameraX/ARCore/ML Kit）+ 各型号校准 Profile | 6 周 |
| Phase 5 | 胶片数据库 + 曝光日志 + 分享导出 + 社区校准共享 | 4 周 |
| Phase 6 | Beta 测试 + 精度对标验证 + 上架准备 | 4 周 |

**总计约 32 周（8 个月），2–3 人团队。**

---

## 9. 核心风险 & 缓解

| 风险 | 说明 | 缓解 |
|------|------|------|
| Android 深度数据不可用 | OEM 不暴露 ToF 给第三方 | 走 ARCore + 单目 ML 方案；UI 标注"估算值" |
| 相机 RAW 帧访问受限 | 部分 Android 机型无法锁 AWB 或获取 RAW | 优先支持主流机型（Pixel / Samsung / Xiaomi）；使用 Camera2 `RAW_SENSOR` 能力查询 |
| 色温精度不达专业水准 | 手机 CMOS RGB 响应与专业色度计差距大 | 明确告知用户精度边界；提供外接色度计配对方案（预留蓝牙通信架构）|
| 低光测光不可靠 | EV < 3 时传感器噪声显著 | EV < 3 时提示"低光不准确，建议包围曝光"；叠加多帧降噪 |
| Apple 政策风险 | App Store 审核（需合理说明相机权限使用）| 在 Info.plist 中说明每个权限用途；App 功能专注摄影辅助而非系统级干预 |

---

## 10. 竞品参考

| App | 平台 | 覆盖功能 | 亮点 | 不足 |
|-----|------|---------|------|------|
| Light & Deep | iOS | 测光 + 测距 + 取景 | LiDAR 测距 + DOF Zebra 叠加；49 种画幅 | 仅 iOS；测光无校准系统 |
| FilmMeter | iOS | 测光 + 测距 | CoreML 场景识别；LiDAR 集成；胶片倒易律 | 仅 iOS；色温未覆盖 |
| Pellica | iOS/Android | 测光 | 入射/反射/点测；Sekonic 校准 | 纯测光，无测距/取景 |
| FilmBox | iOS | 测光 + 测距 + 闪灯计算 | Apple Log 模式专业测光 | 仅 iOS；色温未覆盖 |

**本 App 差异化定位**：唯一跨平台 + 同时覆盖测光/测距/色温/取景四大功能 + 用户可校准精度对标专业设备。

---

## 11. 硬件外设建议

对精度有极致要求的用户，可预留以下外接硬件接口：

| 外设 | 功能 | 通信方式 | 精度提升 |
|------|------|---------|----------|
| Lumu Power 2 | 入射测光 + 闪灯测光 | Lightning / 3.5mm | ±0.1 EV |
| Sekonic C-800 | 色温计 | 蓝牙（预留）| ±50 K |
| 手机用 18% 灰卡 | 校准测光/色温 | N/A | 基础校准 |
| 135 胶卷盒（DIY 柔光罩）| 入射测光 | N/A | 简易入射方案 |

---

*文档版本：v1.0 · 2026-06-14*
