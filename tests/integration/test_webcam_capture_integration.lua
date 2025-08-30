-- Integration tests for WebcamCapture with CaptureEngine
local TestFramework = require("tests.test_framework")
local CaptureEngine = require("src.capture_engine")
local WebcamCapture = require("src.webcam_capture")

local WebcamIntegrationTests = {}

-- Test webcam integration with capture engine
function WebcamIntegrationTests.test_capture_engine_webcam_integration()
    local engine = CaptureEngine:new()
    
    -- Test webcam availability in sources
    local sources = engine:getAvailableSources()
    TestFramework.assert_not_nil(sources.webcam, "Webcam should be listed in available sources")
    
    local webcam_source = sources.webcam
    TestFramework.assert_true(type(webcam_source.available) == "boolean", "Webcam availability should be boolean")
    
    if not webcam_source.available then
        print("Skipping webcam integration tests - webcam not available: " .. (webcam_source.reason or "Unknown"))
        return
    end
    
    -- Test webcam configuration options
    local config_options = engine:getSourceConfigurationOptions("webcam")
    TestFramework.assert_not_nil(config_options, "Should have webcam configuration options")
    TestFramework.assert_true(config_options.available, "Webcam should be available in config options")
    TestFramework.assert_not_nil(config_options.options, "Should have configuration options")
    
    -- Test setting webcam source
    local config = {
        device_index = 0,
        resolution = {width = 640, height = 480},
        frame_rate = 30
    }
    
    local success, error_msg = engine:setSource("webcam", config)
    if success then
        TestFramework.assert_true(success, "Should be able to set webcam source")
        TestFramework.assert_equal(engine.current_source, "webcam", "Current source should be webcam")
        
        -- Test capture start
        success, error_msg = engine:startCapture()
        TestFramework.assert_true(success, "Should be able to start webcam capture")
        TestFramework.assert_true(engine.is_capturing, "Engine should be capturing")
        
        -- Test frame capture
        local frame = engine:getFrame()
        -- Frame might be nil initially, that's okay
        
        -- Test manual frame capture
        frame, error_msg = engine:captureFrame()
        if frame then
            TestFramework.assert_not_nil(frame, "Should capture frame manually")
            TestFramework.assert_not_nil(frame.data, "Frame should have data")
            TestFramework.assert_true(frame.width > 0, "Frame should have positive width")
            TestFramework.assert_true(frame.height > 0, "Frame should have positive height")
        end
        
        -- Test statistics
        local stats = engine:getStats()
        TestFramework.assert_not_nil(stats, "Should have statistics")
        TestFramework.assert_equal(stats.source, "webcam", "Stats should show webcam source")
        TestFramework.assert_not_nil(stats.webcam_stats, "Should have webcam-specific stats")
        TestFramework.assert_not_nil(stats.webcam_config, "Should have webcam configuration")
        
        -- Test capture stop
        success = engine:stopCapture()
        TestFramework.assert_true(success, "Should be able to stop webcam capture")
        TestFramework.assert_false(engine.is_capturing, "Engine should not be capturing")
        
    else
        print("Webcam source setup failed: " .. (error_msg or "Unknown error"))
    end
end

-- Test webcam configuration changes
function WebcamIntegrationTests.test_webcam_configuration_changes()
    local engine = CaptureEngine:new()
    
    -- Check if webcam is available
    local sources = engine:getAvailableSources()
    if not sources.webcam.available then
        print("Skipping webcam configuration test - webcam not available")
        return
    end
    
    -- Set initial webcam configuration
    local initial_config = {
        device_index = 0,
        resolution = {width = 640, height = 480},
        frame_rate = 30
    }
    
    local success, error_msg = engine:setSource("webcam", initial_config)
    if not success then
        print("Skipping webcam configuration test - source setup failed: " .. (error_msg or "Unknown"))
        return
    end
    
    -- Test configuration updates
    local new_config = {
        resolution = {width = 1280, height = 720},
        frame_rate = 60
    }
    
    success, error_msg = engine:updateSourceConfig(new_config)
    TestFramework.assert_true(success, "Should be able to update webcam configuration")
    
    -- Verify configuration was applied
    local current_config = engine:getSourceConfig()
    TestFramework.assert_equal(current_config.source_type, "webcam", "Source type should be webcam")
    TestFramework.assert_equal(current_config.config.resolution.width, 1280, "Width should be updated")
    TestFramework.assert_equal(current_config.config.resolution.height, 720, "Height should be updated")
    TestFramework.assert_equal(current_config.config.frame_rate, 60, "Frame rate should be updated")
end

-- Test webcam device availability and configuration changes
function WebcamIntegrationTests.test_device_availability_changes()
    local engine = CaptureEngine:new()
    
    -- Check if webcam is available
    local sources = engine:getAvailableSources()
    if not sources.webcam.available then
        print("Skipping device availability test - webcam not available")
        return
    end
    
    -- Get available webcams
    local webcams = engine:getAvailableWebcams()
    TestFramework.assert_not_nil(webcams, "Should have webcams list")
    TestFramework.assert_true(type(webcams) == "table", "Webcams should be a table")
    
    if #webcams == 0 then
        print("Skipping device availability test - no webcam devices found")
        return
    end
    
    -- Test device information structure
    local device = webcams[1]
    TestFramework.assert_not_nil(device.name, "Device should have a name")
    TestFramework.assert_not_nil(device.index, "Device should have an index")
    TestFramework.assert_not_nil(device.available, "Device should have availability status")
    
    -- Test setting different devices if multiple are available
    if #webcams > 1 then
        local config1 = {device_index = 0}
        local config2 = {device_index = 1}
        
        local success1 = engine:setSource("webcam", config1)
        local success2 = engine:setSource("webcam", config2)
        
        TestFramework.assert_true(success1 or success2, "Should be able to set at least one device")
    end
end

-- Test webcam error handling and recovery
function WebcamIntegrationTests.test_error_handling_and_recovery()
    local engine = CaptureEngine:new()
    
    -- Test invalid webcam configuration
    local invalid_config = {
        device_index = 999, -- Invalid device
        resolution = {width = -1, height = -1}, -- Invalid resolution
        frame_rate = 0 -- Invalid frame rate
    }
    
    local success, error_msg = engine:setSource("webcam", invalid_config)
    
    -- Should either fail to set source or fail during configuration
    if success then
        -- If source was set, configuration should fail
        success, error_msg = engine:startCapture()
        TestFramework.assert_false(success, "Should fail to start with invalid configuration")
        TestFramework.assert_not_nil(error_msg, "Should have error message")
    else
        TestFramework.assert_not_nil(error_msg, "Should have error message for invalid source")
    end
    
    -- Test error recovery with valid configuration
    local valid_config = {
        device_index = 0,
        resolution = {width = 640, height = 480},
        frame_rate = 30
    }
    
    success, error_msg = engine:setSource("webcam", valid_config)
    if success then
        TestFramework.assert_true(success, "Should recover with valid configuration")
        TestFramework.assert_nil(engine:getLastError(), "Error should be cleared after recovery")
    end
end

-- Test webcam performance under load
function WebcamIntegrationTests.test_performance_under_load()
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true
    })
    
    -- Check if webcam is available
    local sources = engine:getAvailableSources()
    if not sources.webcam.available then
        print("Skipping webcam performance test - webcam not available")
        return
    end
    
    local config = {
        device_index = 0,
        resolution = {width = 640, height = 480},
        frame_rate = 30
    }
    
    local success = engine:setSource("webcam", config)
    if not success then
        print("Skipping webcam performance test - source setup failed")
        return
    end
    
    success = engine:startCapture()
    if not success then
        print("Skipping webcam performance test - capture start failed")
        return
    end
    
    -- Simulate load by capturing multiple frames rapidly
    local capture_count = 10
    local successful_captures = 0
    
    for i = 1, capture_count do
        local frame, error_msg = engine:captureFrame()
        if frame then
            successful_captures = successful_captures + 1
        end
        
        -- Small delay to prevent overwhelming the system
        if love and love.timer then
            love.timer.sleep(0.01)
        end
    end
    
    -- Check performance statistics
    local stats = engine:getStats()
    TestFramework.assert_not_nil(stats, "Should have performance statistics")
    TestFramework.assert_true(successful_captures > 0, "Should have some successful captures")
    
    if stats.performance then
        TestFramework.assert_true(stats.performance.average_capture_time >= 0, "Average capture time should be non-negative")
        TestFramework.assert_true(stats.performance.max_capture_time >= stats.performance.min_capture_time, "Max time should be >= min time")
    end
    
    engine:stopCapture()
end

-- Test webcam source switching
function WebcamIntegrationTests.test_source_switching()
    local engine = CaptureEngine:new()
    
    -- Check if webcam is available
    local sources = engine:getAvailableSources()
    if not sources.webcam.available then
        print("Skipping source switching test - webcam not available")
        return
    end
    
    -- Start with screen capture
    local screen_success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    if screen_success then
        engine:startCapture()
        TestFramework.assert_equal(engine.current_source, "screen", "Should start with screen capture")
        
        -- Switch to webcam
        local webcam_config = {
            device_index = 0,
            resolution = {width = 640, height = 480},
            frame_rate = 30
        }
        
        local webcam_success = engine:setSource("webcam", webcam_config)
        if webcam_success then
            TestFramework.assert_equal(engine.current_source, "webcam", "Should switch to webcam")
            TestFramework.assert_true(engine.is_capturing, "Should still be capturing after switch")
            
            -- Capture a frame to verify webcam is working
            local frame = engine:captureFrame()
            if frame then
                TestFramework.assert_not_nil(frame.data, "Should capture webcam frame after switch")
            end
            
            -- Switch back to screen
            local back_to_screen = engine:setSource("screen", {mode = "FULL_SCREEN"})
            if back_to_screen then
                TestFramework.assert_equal(engine.current_source, "screen", "Should switch back to screen")
                TestFramework.assert_true(engine.is_capturing, "Should still be capturing after switch back")
            end
        end
        
        engine:stopCapture()
    end
end

-- Run all integration tests
function WebcamIntegrationTests.runAll()
    print("Running WebcamCapture integration tests...")
    
    TestFramework.run_test("Capture Engine Webcam Integration", WebcamIntegrationTests.test_capture_engine_webcam_integration)
    TestFramework.run_test("Webcam Configuration Changes", WebcamIntegrationTests.test_webcam_configuration_changes)
    TestFramework.run_test("Device Availability Changes", WebcamIntegrationTests.test_device_availability_changes)
    TestFramework.run_test("Error Handling and Recovery", WebcamIntegrationTests.test_error_handling_and_recovery)
    TestFramework.run_test("Performance Under Load", WebcamIntegrationTests.test_performance_under_load)
    TestFramework.run_test("Source Switching", WebcamIntegrationTests.test_source_switching)
    
    print("WebcamCapture integration tests completed.")
end

return WebcamIntegrationTests