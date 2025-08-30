# 测试目录结构

本目录包含了项目的所有测试文件，按照功能和类型进行了重新组织。

## 目录结构

```
tests/
├── unit/           # 单元测试 - 测试单个模块的功能
│   ├── test_advanced_capture_features.lua
│   ├── test_capture_engine.lua
│   ├── test_config_manager.lua
│   ├── test_dpi_awareness.lua
│   ├── test_error_handler.lua
│   ├── test_ffi_bindings.lua
│   ├── test_frame_buffer.lua
│   ├── test_memory_optimization.lua
│   ├── test_overlay_manager.lua
│   ├── test_performance_monitor.lua
│   ├── test_screen_capture.lua
│   ├── test_ui_controller.lua
│   ├── test_video_renderer.lua
│   ├── test_webcam_capture.lua
│   └── test_window_capture.lua
├── integration/    # 集成测试 - 测试模块间的交互
│   ├── test_advanced_features_integration.lua
│   ├── test_capture_engine_integration.lua
│   ├── test_complete_workflows.lua
│   ├── test_config_manager_integration.lua
│   ├── test_error_handler_integration.lua
│   ├── test_frame_buffer_integration.lua
│   ├── test_main_integration.lua
│   ├── test_overlay_integration.lua
│   ├── test_performance_integration.lua
│   ├── test_screen_capture_integration.lua
│   ├── test_ui_controller_integration.lua
│   ├── test_ui_display.lua
│   ├── test_video_renderer_integration.lua
│   ├── test_webcam_capture_integration.lua
│   ├── test_window_capture_integration.lua
│   └── run_integration_tests.lua
├── stress/         # 压力测试 - 性能和内存测试
│   ├── test_error_simulation.lua
│   ├── test_memory_optimization_stress.lua
│   ├── test_performance_stress.lua
│   └── run_memory_stress_tests.lua
├── demo/           # 演示和验证脚本
│   ├── demo_webcam_capture.lua
│   ├── test_capture_mac.lua
│   ├── test_screen_capture_comprehensive.lua
│   ├── validate_advanced_features.lua
│   ├── validate_memory_optimization.lua
│   └── test_capture/           # Mac平台捕获测试项目
├── utils/          # 测试工具和框架
│   ├── mock_ffi_bindings.lua
│   ├── test_advanced_features_runner.lua
│   └── test_framework.lua
├── run_all_tests.lua           # 运行所有测试的主脚本
├── run_tests.lua               # 基础测试运行器
└── README.md                   # 本文件
```

## 测试类型说明

### 单元测试 (unit/)

- 测试单个模块的功能
- 使用模拟对象隔离依赖
- 快速执行，适合开发过程中频繁运行
- 覆盖核心功能和边界条件

### 集成测试 (integration/)

- 测试多个模块之间的交互
- 验证组件间的接口和数据流
- 测试完整的工作流程
- 发现模块集成时的问题

### 压力测试 (stress/)

- 测试系统在高负载下的表现
- 内存泄漏检测
- 性能瓶颈识别
- 错误恢复能力测试

### 演示脚本 (demo/)

- 功能演示和验证
- API 使用示例
- 跨平台兼容性验证
- 用户文档的实际例子

### 测试工具 (utils/)

- 统一的测试框架
- 模拟对象和工具函数
- 测试辅助工具
- 跨平台兼容性支持

## 运行测试

### 运行所有测试

```bash
luajit tests/run_tests.lua
```

### 运行特定类型的测试

```bash
# 单元测试
luajit tests/unit/test_config_manager.lua

# 集成测试
luajit tests/integration/test_config_manager_integration.lua
luajit tests/integration/run_integration_tests.lua

# 压力测试
luajit tests/stress/test_performance_stress.lua
luajit tests/stress/run_memory_stress_tests.lua

# 演示脚本
luajit tests/demo/demo_webcam_capture.lua

# Mac平台捕获测试
love tests/demo/test_capture_mac.lua
```

### 运行验证脚本

```bash
luajit tests/demo/validate_advanced_features.lua
luajit tests/demo/validate_memory_optimization.lua
```

## 测试开发指南

### 编写单元测试

1. 使用 `tests/utils/test_framework.lua` 提供的断言函数
2. 使用 `tests/utils/mock_ffi_bindings.lua` 进行跨平台测试
3. 确保测试独立性，不依赖外部状态
4. 测试正常情况和异常情况

### 编写集成测试

1. 测试真实的模块交互
2. 验证数据流和状态变化
3. 测试完整的用例场景
4. 包含错误处理和恢复测试

### 编写压力测试

1. 模拟高负载场景
2. 监控内存使用和性能指标
3. 测试长时间运行的稳定性
4. 验证资源清理和回收

## 测试覆盖范围

- ✅ 配置管理 (ConfigManager)
- ✅ 捕获引擎 (CaptureEngine)
- ✅ 错误处理 (ErrorHandler)
- ✅ 帧缓冲 (FrameBuffer)
- ✅ 覆盖管理 (OverlayManager)
- ✅ UI 控制器 (UIController)
- ✅ 视频渲染 (VideoRenderer)
- ✅ 屏幕捕获 (ScreenCapture)
- ✅ 窗口捕获 (WindowCapture)
- ✅ 摄像头捕获 (WebcamCapture)
- ✅ 性能监控 (PerformanceMonitor)
- ✅ 内存优化 (MemoryPool, ResourceManager)

## 持续集成

测试结构支持 CI/CD 流水线：

1. 快速单元测试用于代码提交验证
2. 集成测试用于合并请求验证
3. 压力测试用于发布前验证
4. 演示脚本用于功能验证

## 贡献指南

添加新测试时：

1. 选择合适的测试类型目录
2. 遵循现有的命名约定
3. 使用统一的测试框架
4. 更新相关文档
5. 确保跨平台兼容性
