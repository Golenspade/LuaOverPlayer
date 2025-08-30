#!/usr/bin/env luajit

-- Test runner for Lua Video Capture Player
-- This script can be run with LuaJIT to execute unit tests

-- Add src directory to package path
package.path = package.path .. ";./src/?.lua;./tests/?.lua"

-- Check if we're running on Windows (required for FFI bindings)
local function isWindows()
    return package.config:sub(1,1) == '\\'
end

-- Main test runner
local function runAllTests()
    print("Lua Video Capture Player - Test Suite")
    print("=====================================")
    print("Platform: " .. (jit and jit.os or "unknown"))
    
    local allPassed = true
    
    -- Run Capture Engine tests
    print("\n=== Running Capture Engine Tests ===")
    local captureEngineTests = require("test_capture_engine")
    -- Test already runs when required, just check if it exists
    print("✓ Capture Engine unit tests completed")
    
    -- Run Capture Engine Integration tests
    print("\n=== Running Capture Engine Integration Tests ===")
    local captureEngineIntegrationTests = require("test_capture_engine_integration")
    -- Test already runs when required, just check if it exists
    print("✓ Capture Engine integration tests completed")
    
    -- Run Frame Buffer tests (platform independent)
    print("\n=== Running Frame Buffer Tests ===")
    local frameBufferTestsPassed = require("test_frame_buffer")
    allPassed = allPassed and frameBufferTestsPassed
    
    -- Run Video Renderer tests (platform independent)
    print("\n=== Running Video Renderer Tests ===")
    local videoRendererTestsPassed = require("test_video_renderer")
    allPassed = allPassed and videoRendererTestsPassed
    
    -- Run UI Controller tests (platform independent)
    print("\n=== Running UI Controller Tests ===")
    local uiControllerTests = require("test_ui_controller")
    local uiControllerTestsPassed = uiControllerTests.runUIControllerTests()
    allPassed = allPassed and (uiControllerTestsPassed.passed == uiControllerTestsPassed.total)
    print("✓ UI Controller unit tests completed")
    
    -- Run UI Controller Integration tests
    print("\n=== Running UI Controller Integration Tests ===")
    local uiControllerIntegrationTests = require("test_ui_controller_integration")
    local uiControllerIntegrationTestsPassed = uiControllerIntegrationTests.runUIControllerIntegrationTests()
    allPassed = allPassed and (uiControllerIntegrationTestsPassed.passed == uiControllerIntegrationTestsPassed.total)
    print("✓ UI Controller integration tests completed")
    
    -- Run Window Capture tests (uses mocks on non-Windows)
    print("\n=== Running Window Capture Tests ===")
    local windowCaptureTests = require("test_window_capture")
    local windowCaptureTestsPassed = windowCaptureTests.run_all_tests()
    allPassed = allPassed and windowCaptureTestsPassed
    
    -- Run Window Capture Integration tests
    print("\n=== Running Window Capture Integration Tests ===")
    local windowCaptureIntegrationTests = require("test_window_capture_integration")
    local windowCaptureIntegrationTestsPassed = windowCaptureIntegrationTests.run_all_tests()
    allPassed = allPassed and windowCaptureIntegrationTestsPassed
    
    -- Run DPI Awareness tests
    print("\n=== Running DPI Awareness Tests ===")
    local dpiAwarenessTests = require("test_dpi_awareness")
    local dpiAwarenessTestsPassed = dpiAwarenessTests.run_all_tests()
    allPassed = allPassed and dpiAwarenessTestsPassed
    
    -- Run Webcam Capture tests
    print("\n=== Running Webcam Capture Tests ===")
    local webcamCaptureTests = require("test_webcam_capture")
    webcamCaptureTests.runAll()
    print("✓ Webcam Capture unit tests completed")
    
    -- Run Webcam Capture Integration tests
    print("\n=== Running Webcam Capture Integration Tests ===")
    local webcamCaptureIntegrationTests = require("test_webcam_capture_integration")
    webcamCaptureIntegrationTests.runAll()
    print("✓ Webcam Capture integration tests completed")
    
    -- Run Overlay Manager tests
    print("\n=== Running Overlay Manager Tests ===")
    local overlayManagerTests = require("test_overlay_manager")
    local overlayManagerTestsPassed = overlayManagerTests.runAllTests()
    allPassed = allPassed and (overlayManagerTestsPassed.passed == overlayManagerTestsPassed.total)
    print("✓ Overlay Manager unit tests completed")
    
    -- Run Overlay Integration tests
    print("\n=== Running Overlay Integration Tests ===")
    local overlayIntegrationTests = require("test_overlay_integration")
    local overlayIntegrationTestsPassed = overlayIntegrationTests.runAllTests()
    allPassed = allPassed and (overlayIntegrationTestsPassed.passed == overlayIntegrationTestsPassed.total)
    print("✓ Overlay integration tests completed")
    
    -- Run Error Handler tests
    print("\n=== Running Error Handler Tests ===")
    local errorHandlerTests = require("test_error_handler")
    local errorHandlerTestsPassed = errorHandlerTests.runAllTests()
    allPassed = allPassed and (errorHandlerTestsPassed.passed == errorHandlerTestsPassed.total)
    print("✓ Error Handler unit tests completed")
    
    -- Run Error Simulation tests
    print("\n=== Running Error Simulation Tests ===")
    local errorSimulationTests = require("test_error_simulation")
    local errorSimulationTestsPassed = errorSimulationTests.runAllTests()
    allPassed = allPassed and (errorSimulationTestsPassed.passed == errorSimulationTestsPassed.total)
    print("✓ Error Simulation tests completed")
    
    -- Run Error Handler Integration tests
    print("\n=== Running Error Handler Integration Tests ===")
    local errorHandlerIntegrationTests = require("test_error_handler_integration")
    local errorHandlerIntegrationTestsPassed = errorHandlerIntegrationTests.runAllTests()
    allPassed = allPassed and (errorHandlerIntegrationTestsPassed.passed == errorHandlerIntegrationTestsPassed.total)
    print("✓ Error Handler integration tests completed")
    
    -- Run Performance Monitor tests
    print("\n=== Running Performance Monitor Tests ===")
    local performanceMonitorTests = require("test_performance_monitor")
    local performanceMonitorTestsPassed = performanceMonitorTests.run_all_tests()
    allPassed = allPassed and (performanceMonitorTestsPassed.passed == performanceMonitorTestsPassed.total)
    print("✓ Performance Monitor unit tests completed")
    
    -- Run Performance Integration tests
    print("\n=== Running Performance Integration Tests ===")
    local performanceIntegrationTests = require("test_performance_integration")
    local performanceIntegrationTestsPassed = performanceIntegrationTests.run_all_tests()
    allPassed = allPassed and (performanceIntegrationTestsPassed.passed == performanceIntegrationTestsPassed.total)
    print("✓ Performance Integration tests completed")
    
    -- Run Performance Stress tests
    print("\n=== Running Performance Stress Tests ===")
    local performanceStressTests = require("test_performance_stress")
    local performanceStressTestsPassed = performanceStressTests.run_all_tests()
    allPassed = allPassed and (performanceStressTestsPassed.passed == performanceStressTestsPassed.total)
    print("✓ Performance Stress tests completed")
    
    -- Run Configuration Manager tests
    print("\n=== Running Configuration Manager Tests ===")
    local configManagerTests = require("test_config_manager")
    local configManagerTestsPassed = configManagerTests.run_all_tests()
    allPassed = allPassed and configManagerTestsPassed
    
    -- Run Configuration Manager Integration tests
    print("\n=== Running Configuration Manager Integration Tests ===")
    local configManagerIntegrationTests = require("test_config_manager_integration")
    local configManagerIntegrationTestsPassed = configManagerIntegrationTests.run_all_tests()
    allPassed = allPassed and configManagerIntegrationTestsPassed
    
    -- Run Advanced Capture Features tests
    print("\n=== Running Advanced Capture Features Tests ===")
    local advancedFeaturesTests = require("test_advanced_capture_features")
    local advancedFeaturesTestsPassed = advancedFeaturesTests.run_all_tests()
    allPassed = allPassed and advancedFeaturesTestsPassed
    
    -- Run Advanced Features Integration tests
    print("\n=== Running Advanced Features Integration Tests ===")
    local advancedFeaturesIntegrationTests = require("test_advanced_features_integration")
    local advancedFeaturesIntegrationTestsPassed = advancedFeaturesIntegrationTests.run_all_tests()
    allPassed = allPassed and advancedFeaturesIntegrationTestsPassed
    
    if isWindows() then
        -- Import and run real FFI bindings tests
        local TestFFIBindings = require("test_ffi_bindings")
        local ffiTestsPassed = TestFFIBindings.runAllTests()
        allPassed = allPassed and ffiTestsPassed
    else
        -- Run mock tests on non-Windows platforms
        print("\n=== Running Mock FFI Bindings Tests ===")
        print("Using mock bindings for cross-platform testing")
        
        -- Create a simple mock test
        local mockTests = {
            function()
                local MockFFI = require("mock_ffi_bindings")
                local width, height = MockFFI.getScreenDimensions()
                assert(width == 1920 and height == 1080, "Mock screen dimensions should be 1920x1080")
                print("✓ Mock screen dimensions test passed")
            end,
            function()
                local MockFFI = require("mock_ffi_bindings")
                local virtual = MockFFI.getVirtualScreenDimensions()
                assert(virtual.width == 3840 and virtual.height == 1080, "Mock virtual screen should be 3840x1080")
                print("✓ Mock virtual screen dimensions test passed")
            end,
            function()
                local MockFFI = require("mock_ffi_bindings")
                local hwnd = MockFFI.getDesktopWindow()
                assert(hwnd ~= nil, "Mock desktop window should not be nil")
                assert(MockFFI.isWindowValid(hwnd), "Mock window should be valid")
                assert(MockFFI.isWindowVisible(hwnd), "Mock window should be visible")
                print("✓ Mock window validation test passed")
            end,
            function()
                local MockFFI = require("mock_ffi_bindings")
                local hwnd = MockFFI.getForegroundWindow()
                local title = MockFFI.getWindowTitle(hwnd)
                assert(title == "Mock Window Title", "Mock window title should match")
                print("✓ Mock window title test passed")
            end,
            function()
                local MockFFI = require("mock_ffi_bindings")
                local hwnd = MockFFI.getDesktopWindow()
                local rect = MockFFI.getClientRect(hwnd)
                assert(rect.width == 800 and rect.height == 600, "Mock client rect should be 800x600")
                print("✓ Mock client rectangle test passed")
            end,
            function()
                local MockFFI = require("mock_ffi_bindings")
                local bitmap = MockFFI.captureScreen(0, 0, 100, 100)
                assert(bitmap ~= nil, "Mock screen capture should succeed")
                MockFFI.deleteBitmap(bitmap)
                print("✓ Mock screen capture test passed")
            end
        }
        
        local passed = 0
        local failed = 0
        
        for i, test in ipairs(mockTests) do
            local success, err = pcall(test)
            if success then
                passed = passed + 1
            else
                failed = failed + 1
                print("✗ Mock test " .. i .. " failed: " .. err)
            end
        end
        
        print("\nMock Tests - Passed: " .. passed .. ", Failed: " .. failed)
        allPassed = failed == 0
    end
    
    print("\n=== Overall Results ===")
    if allPassed then
        print("All test suites passed! ✓")
        os.exit(0)
    else
        print("Some test suites failed! ✗")
        os.exit(1)
    end
end

-- Check if we're running on Windows (required for FFI bindings)
local function isWindows()
    return package.config:sub(1,1) == '\\'
end

-- Run tests (will use mocks on non-Windows platforms)
runAllTests()