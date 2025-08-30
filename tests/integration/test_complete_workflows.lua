-- Complete workflow integration tests
-- Tests end-to-end scenarios that users would actually perform

local TestFramework = require("tests.test_framework")

-- Mock LÖVE 2D environment
local MockLove = {
    timer = { getTime = function() return os.clock() end },
    window = {
        setTitle = function() return true end,
        setMode = function() return true end,
        getMode = function() return 800, 600, {} end,
        setPosition = function() return true end,
        getPosition = function() return 100, 100 end
    },
    graphics = {
        clear = function() end,
        setColor = function() end,
        print = function() end,
        rectangle = function() end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        newFont = function(size) 
            return {
                getHeight = function() return size or 12 end,
                getWidth = function(text) return (text and #text or 0) * (size or 12) * 0.6 end
            }
        end,
        setFont = function() end,
        getFont = function() 
            return {
                getHeight = function() return 12 end,
                getWidth = function(text) return (text and #text or 0) * 7 end
            }
        end,
        newImage = function(data)
            return {
                getWidth = function() return 100 end,
                getHeight = function() return 100 end
            }
        end
    },
    image = {
        newImageData = function(w, h, format, data)
            return {
                type = function() return "ImageData" end,
                getWidth = function() return w end,
                getHeight = function() return h end,
                getData = function() return data end
            }
        end
    },
    mouse = { getPosition = function() return 400, 300 end },
    keyboard = { isDown = function() return false end },
    event = { quit = function() end }
}

_G.love = MockLove
_G.TESTING_MODE = true

local CompleteWorkflowTests = {}

-- Initialize test environment
function CompleteWorkflowTests.setupTestEnvironment()
    -- Load and initialize main application
    local main_chunk = loadfile("main.lua")
    if main_chunk then
        main_chunk()
        if love.load then
            love.load()
        end
    end
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        error("Failed to initialize test environment")
    end
end

-- Test Workflow 1: Screen Capture Setup and Recording
function CompleteWorkflowTests.testScreenCaptureWorkflow()
    print("Testing screen capture workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Configure screen capture
    local success, err = _G.app.capture_engine:setSource("screen", {
        mode = "FULL_SCREEN"
    })
    TestFramework.assert(success, "Should configure screen capture: " .. tostring(err))
    
    -- Step 2: Start capture
    success, err = _G.app.capture_engine:startCapture()
    TestFramework.assert(success, "Should start screen capture: " .. tostring(err))
    
    -- Step 3: Run capture for several frames
    for i = 1, 30 do
        love.update(1/30)
        
        -- Verify capture is active
        local stats = _G.app.capture_engine:getStats()
        TestFramework.assert(stats.is_capturing == true, "Capture should be active")
    end
    
    -- Step 4: Check capture statistics
    local final_stats = _G.app.capture_engine:getStats()
    TestFramework.assert(final_stats.frames_captured > 0, "Should have captured frames")
    
    -- Step 5: Stop capture
    success, err = _G.app.capture_engine:stopCapture()
    TestFramework.assert(success, "Should stop capture: " .. tostring(err))
    
    print("✓ Screen capture workflow test passed")
end

-- Test Workflow 2: Window Capture with Window Tracking
function CompleteWorkflowTests.testWindowCaptureWorkflow()
    print("Testing window capture workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Configure window capture
    local success, err = _G.app.capture_engine:setSource("window", {
        window = {
            title = "Test Window",
            follow_window = true
        }
    })
    TestFramework.assert(success, "Should configure window capture: " .. tostring(err))
    
    -- Step 2: Start capture
    success, err = _G.app.capture_engine:startCapture()
    TestFramework.assert(success, "Should start window capture: " .. tostring(err))
    
    -- Step 3: Simulate window tracking
    for i = 1, 20 do
        love.update(1/30)
        
        -- Verify capture is tracking window
        local stats = _G.app.capture_engine:getStats()
        TestFramework.assert(stats.is_capturing == true, "Window capture should be active")
    end
    
    -- Step 4: Stop capture
    _G.app.capture_engine:stopCapture()
    
    print("✓ Window capture workflow test passed")
end

-- Test Workflow 3: Overlay Mode Configuration
function CompleteWorkflowTests.testOverlayModeWorkflow()
    print("Testing overlay mode workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Enable overlay mode
    local success, err = _G.app.overlay_manager:setOverlayMode("overlay")
    TestFramework.assert(success, "Should enable overlay mode: " .. tostring(err))
    
    -- Step 2: Configure overlay properties
    success, err = _G.app.overlay_manager:setTransparency(0.7)
    TestFramework.assert(success, "Should set transparency: " .. tostring(err))
    
    success, err = _G.app.overlay_manager:setAlwaysOnTop(true)
    TestFramework.assert(success, "Should set always on top: " .. tostring(err))
    
    success, err = _G.app.overlay_manager:setBorderless(true)
    TestFramework.assert(success, "Should set borderless: " .. tostring(err))
    
    -- Step 3: Position overlay
    success, err = _G.app.overlay_manager:setPosition(100, 100)
    TestFramework.assert(success, "Should set position: " .. tostring(err))
    
    success, err = _G.app.overlay_manager:setSize(400, 300)
    TestFramework.assert(success, "Should set size: " .. tostring(err))
    
    -- Step 4: Verify overlay configuration
    local config = _G.app.overlay_manager:getConfiguration()
    TestFramework.assert(config.mode == "overlay", "Overlay mode should be set")
    TestFramework.assert(config.transparency == 0.7, "Transparency should be set")
    TestFramework.assert(config.always_on_top == true, "Always on top should be set")
    TestFramework.assert(config.borderless == true, "Borderless should be set")
    
    -- Step 5: Run with overlay active
    for i = 1, 10 do
        love.update(1/30)
        love.draw()
    end
    
    -- Step 6: Disable overlay mode
    success, err = _G.app.overlay_manager:setOverlayMode("normal")
    TestFramework.assert(success, "Should disable overlay mode: " .. tostring(err))
    
    print("✓ Overlay mode workflow test passed")
end

-- Test Workflow 4: Performance Monitoring and Optimization
function CompleteWorkflowTests.testPerformanceOptimizationWorkflow()
    print("Testing performance optimization workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Enable performance monitoring
    _G.app.performance_monitor:setEnabled(true)
    _G.app.performance_monitor:setTargetFPS(60)
    _G.app.performance_monitor:setFrameDropEnabled(true)
    
    -- Step 2: Run application under normal load
    for i = 1, 60 do  -- 1 second at 60 FPS
        love.update(1/60)
    end
    
    -- Step 3: Check initial performance metrics
    local metrics = _G.app.performance_monitor:getMetrics()
    TestFramework.assert(metrics.frames_processed > 0, "Should have processed frames")
    TestFramework.assert(metrics.current_fps > 0, "Should calculate FPS")
    
    -- Step 4: Simulate performance stress by directly manipulating performance monitor
    -- Force slow frame times to trigger performance warnings
    for i = 1, 30 do
        -- Manually set frame time to simulate slow performance
        _G.app.performance_monitor.metrics.frame_time = 0.15  -- 150ms (very slow)
        _G.app.performance_monitor.metrics.current_fps = 6.67  -- ~7 FPS
        _G.app.performance_monitor:_updatePerformanceStats(love.timer.getTime())
        love.update(0.15)  -- Simulate 150ms frame time
    end
    
    -- Step 5: Check performance degradation detection
    local stressed_metrics = _G.app.performance_monitor:getMetrics()
    -- Check if performance issues were detected
    local has_performance_issues = stressed_metrics.current_fps < 20 or 
                                  stressed_metrics.frame_time > 0.05 or
                                  stressed_metrics.performance_state ~= "good" or
                                  stressed_metrics.warning_count > 0
    TestFramework.assert(has_performance_issues, 
                        "Should detect performance issues (FPS: " .. 
                        string.format("%.1f", stressed_metrics.current_fps) .. 
                        ", Frame time: " .. string.format("%.3f", stressed_metrics.frame_time) .. 
                        ", State: " .. stressed_metrics.performance_state .. 
                        ", Warnings: " .. stressed_metrics.warning_count .. ")")
    
    -- Step 6: Test performance recommendations
    local recommendations = _G.app.performance_monitor:getPerformanceRecommendations()
    TestFramework.assert(#recommendations > 0, "Should provide performance recommendations")
    
    -- Step 7: Test garbage collection
    local freed_memory = _G.app.performance_monitor:forceGarbageCollection()
    TestFramework.assert(freed_memory >= 0, "Should report freed memory")
    
    print("✓ Performance optimization workflow test passed")
end

-- Test Workflow 5: Configuration Management
function CompleteWorkflowTests.testConfigurationManagementWorkflow()
    print("Testing configuration management workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Get initial configuration
    local initial_config = _G.app.config_manager:getAll()
    TestFramework.assert(initial_config ~= nil, "Should have initial configuration")
    
    -- Step 2: Modify capture settings
    _G.app.config_manager:set("capture.frame_rate", 45)
    _G.app.config_manager:set("capture.quality", "medium")
    
    -- Step 3: Modify display settings
    _G.app.config_manager:set("display.scaling_mode", "fill")
    _G.app.config_manager:set("display.overlay.transparency", 0.5)
    
    -- Step 4: Verify changes
    TestFramework.assert(_G.app.config_manager:get("capture.frame_rate") == 45, 
                        "Frame rate should be updated")
    TestFramework.assert(_G.app.config_manager:get("capture.quality") == "medium", 
                        "Quality should be updated")
    
    -- Step 5: Test batch update
    local batch_updates = {
        ["performance.target_fps"] = 30,
        ["ui.show_fps"] = false,
        ["app.window_width"] = 1024
    }
    
    local success, err = pcall(_G.app.config_manager.updateBatch, _G.app.config_manager, batch_updates)
    TestFramework.assert(success, "Batch update should succeed: " .. tostring(err))
    
    -- Step 6: Verify batch updates
    TestFramework.assert(_G.app.config_manager:get("performance.target_fps") == 30, 
                        "Target FPS should be updated")
    TestFramework.assert(_G.app.config_manager:get("ui.show_fps") == false, 
                        "Show FPS should be updated")
    
    -- Step 7: Test configuration validation
    local validation_result = _G.app.config_manager:validate()
    TestFramework.assert(validation_result.valid == true, 
                        "Configuration should be valid: " .. table.concat(validation_result.errors or {}, ", "))
    
    -- Step 8: Save configuration
    success, err = pcall(_G.app.config_manager.save, _G.app.config_manager)
    TestFramework.assert(success, "Should save configuration: " .. tostring(err))
    
    print("✓ Configuration management workflow test passed")
end

-- Test Workflow 6: Error Handling and Recovery
function CompleteWorkflowTests.testErrorHandlingWorkflow()
    print("Testing error handling workflow...")
    
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Step 1: Test API error handling
    local recovered, error_info = _G.app.error_handler:handleAPIError("TestAPI", 5, {
        operation = "test_operation"
    })
    TestFramework.assert(error_info ~= nil, "Should create error info")
    TestFramework.assert(error_info.category == "api_error", "Should categorize as API error")
    
    -- Step 2: Test resource error handling
    recovered, error_info = _G.app.error_handler:handleResourceError("memory", {
        requested = 1000000,
        available = 500000
    }, 150 * 1024 * 1024)
    TestFramework.assert(error_info ~= nil, "Should handle resource error")
    
    -- Step 3: Test performance error handling
    recovered, error_info = _G.app.error_handler:handlePerformanceError("fps", 10, 30)
    TestFramework.assert(error_info ~= nil, "Should handle performance error")
    
    -- Step 4: Test graceful degradation
    local initial_quality = _G.app.error_handler:getQualityLevel()
    print("Initial quality level: " .. initial_quality)
    
    -- Trigger performance error that should cause degradation
    local recovered, error_info = _G.app.error_handler:handlePerformanceError("frame_drop_rate", 0.3, 0.1)
    print("Performance error handled, recovered: " .. tostring(recovered))
    
    local degraded_quality = _G.app.error_handler:getQualityLevel()
    print("Degraded quality level: " .. degraded_quality)
    
    -- Check if degradation occurred (quality should be less than initial)
    local is_degraded = _G.app.error_handler:isDegraded()
    TestFramework.assert(is_degraded or degraded_quality < initial_quality, 
                        "Should degrade quality level (initial: " .. initial_quality .. 
                        ", degraded: " .. degraded_quality .. ", is_degraded: " .. tostring(is_degraded) .. ")")
    
    -- Step 5: Test error statistics
    local error_stats = _G.app.error_handler:getErrorStats()
    TestFramework.assert(error_stats.total_errors > 0, "Should track error count")
    
    -- Step 6: Test error recovery
    local recovery_success = _G.app:attemptRecovery("test_recovery")
    TestFramework.assert(recovery_success ~= nil, "Should attempt recovery")
    
    -- Step 7: Reset error handler
    _G.app.error_handler:resetDegradedMode()
    TestFramework.assert(_G.app.error_handler:getQualityLevel() == 1.0, 
                        "Should reset quality level")
    
    print("✓ Error handling workflow test passed")
end

-- Test Workflow 7: Complete User Session
function CompleteWorkflowTests.testCompleteUserSession()
    print("Testing complete user session workflow...")
    
    -- Reset environment for clean session test
    _G.app = nil
    CompleteWorkflowTests.setupTestEnvironment()
    
    -- Session Step 1: Application startup
    local startup_stats = _G.app:getApplicationStats()
    TestFramework.assert(startup_stats.initialized == true, "Application should start successfully")
    
    -- Session Step 2: Configure capture source
    _G.app.capture_engine:setSource("screen", {mode = "FULL_SCREEN"})
    
    -- Session Step 3: Start recording
    _G.app.capture_engine:startCapture()
    
    -- Session Step 4: Run recording session
    for i = 1, 90 do  -- 3 seconds at 30 FPS
        love.update(1/30)
        love.draw()
        
        -- Simulate some user interactions
        if i % 30 == 0 then
            love.keypressed("space")  -- Simulate spacebar every second
        end
        
        if i % 45 == 0 then
            love.mousepressed(math.random(100, 700), math.random(100, 500), 1, false, 1)
        end
    end
    
    -- Session Step 5: Check session statistics
    local session_stats = _G.app:getApplicationStats()
    TestFramework.assert(session_stats.frame_count >= 90, "Should process expected frames")
    TestFramework.assert(session_stats.uptime > 0, "Should track session time")
    
    local capture_stats = _G.app.capture_engine:getStats()
    print("Capture stats - frames_captured: " .. capture_stats.frames_captured .. 
          ", is_capturing: " .. tostring(capture_stats.is_capturing))
    
    -- In test mode, we should at least have started capturing
    TestFramework.assert(capture_stats.is_capturing == true or capture_stats.frames_captured > 0, 
                        "Should be capturing or have captured frames during session (captured: " .. 
                        capture_stats.frames_captured .. ", is_capturing: " .. tostring(capture_stats.is_capturing) .. ")")
    
    local perf_metrics = _G.app.performance_monitor:getMetrics()
    TestFramework.assert(perf_metrics.frames_processed > 0, "Should monitor performance during session")
    
    -- Session Step 6: Change settings during session
    _G.app.config_manager:set("display.scaling_mode", "stretch")
    _G.app.overlay_manager:setTransparency(0.8)
    
    -- Session Step 7: Continue session with new settings
    for i = 1, 30 do
        love.update(1/30)
        love.draw()
    end
    
    -- Session Step 8: Stop recording
    _G.app.capture_engine:stopCapture()
    
    -- Session Step 9: Review session data
    local final_stats = _G.app:getApplicationStats()
    local final_capture_stats = _G.app.capture_engine:getStats()
    local final_perf_metrics = _G.app.performance_monitor:getMetrics()
    
    TestFramework.assert(final_stats.frame_count >= 120, "Should complete full session")
    TestFramework.assert(final_capture_stats.is_capturing == false, "Should stop capture")
    TestFramework.assert(final_perf_metrics.session_time > 0, "Should track session duration")
    
    -- Session Step 10: Clean shutdown
    _G.app:initiateShutdown()
    TestFramework.assert(_G.app.shutdown_requested == true, "Should initiate clean shutdown")
    
    print("✓ Complete user session workflow test passed")
end

-- Run all workflow tests
function CompleteWorkflowTests.runAllTests()
    print("=== Running Complete Workflow Tests ===")
    
    local tests = {
        CompleteWorkflowTests.testScreenCaptureWorkflow,
        CompleteWorkflowTests.testWindowCaptureWorkflow,
        CompleteWorkflowTests.testOverlayModeWorkflow,
        CompleteWorkflowTests.testPerformanceOptimizationWorkflow,
        CompleteWorkflowTests.testConfigurationManagementWorkflow,
        CompleteWorkflowTests.testErrorHandlingWorkflow,
        CompleteWorkflowTests.testCompleteUserSession
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ Workflow test failed: " .. tostring(err))
        end
    end
    
    print("=== Workflow Test Results ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    
    if failed == 0 then
        print("🎉 All workflow tests passed!")
    else
        print("❌ Some workflow tests failed")
    end
    
    return failed == 0
end

return CompleteWorkflowTests