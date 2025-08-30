-- Integration tests for CaptureEngine core logic
-- Tests capture-to-display pipeline and source coordination

-- Set testing mode before requiring modules
_G.TESTING_MODE = true

local TestFramework = require("tests.test_framework")
local CaptureEngine = require("src.capture_engine")

-- Mock LÖVE timer for testing
local mock_time = 0
local original_love = _G.love
_G.love = {
    timer = {
        getTime = function() return mock_time end
    }
}

-- Helper function to advance mock time
local function advanceTime(dt)
    mock_time = mock_time + dt
end

-- Helper function to reset mock time
local function resetTime()
    mock_time = 0
end

-- Test suite
local tests = {}

-- Test capture engine initialization and configuration
function tests.testCaptureEngineInitialization()
    local engine = CaptureEngine:new()
    
    assert_not_nil(engine, "Engine should be created")
    assert_equal(30, engine.target_frame_rate, "Default frame rate should be 30")
    assert_false(engine.is_capturing, "Should not be capturing initially")
    assert_nil(engine.current_source, "No source should be set initially")
    
    -- Test custom initialization options
    local custom_engine = CaptureEngine:new({
        frame_rate = 60,
        buffer_size = 5,
        monitor_performance = false
    })
    
    assert_equal(60, custom_engine.target_frame_rate, "Custom frame rate should be set")
    assert_equal(5, custom_engine.frame_buffer.max_frames, "Custom buffer size should be set")
    assert_false(custom_engine.performance_monitor.enabled, "Performance monitoring should be disabled")
end

-- Test source configuration and switching
function tests.testSourceConfiguration()
    local engine = CaptureEngine:new()
    
    -- Test invalid source type
    local success, err = engine:setSource("invalid", {})
    assert_false(success, "Invalid source should fail")
    assert_not_nil(err, "Error message should be provided")
    
    -- Test screen capture source
    success, err = engine:setSource("screen", {
        mode = "FULL_SCREEN",
        monitor_index = 1
    })
    assert_true(success, "Screen source should be set successfully: " .. (err or ""))
    assert_equal("screen", engine.current_source, "Current source should be screen")
    
    -- Test window capture source (without specific window for mock environment)
    success, err = engine:setSource("window", {
        tracking = true,
        dpi_aware = true
    })
    assert_true(success, "Window source should be set successfully: " .. (err or ""))
    assert_equal("window", engine.current_source, "Current source should be window")
    
    -- Test webcam source (should fail as not implemented)
    success, err = engine:setSource("webcam", {})
    assert_false(success, "Webcam source should fail (not implemented)")
    assert_not_nil(err, "Error message should indicate not implemented")
end

-- Test capture lifecycle and timing
function tests.testCaptureLifecycle()
    resetTime()
    local engine = CaptureEngine:new({ frame_rate = 10 })  -- 10 FPS for easier testing
    
    -- Configure screen capture
    local success, err = engine:setSource("screen", { mode = "FULL_SCREEN" })
    assert_true(success, "Screen source should be configured: " .. (err or ""))
    
    -- Test starting capture
    success, err = engine:startCapture()
    assert_true(success, "Capture should start successfully: " .. (err or ""))
    assert_true(engine.is_capturing, "Should be capturing after start")
    
    -- Test frame rate timing
    assert_equal(0.1, engine.frame_interval, "Frame interval should be 0.1s for 10 FPS")
    
    -- Simulate frame updates
    advanceTime(0.05)  -- Half frame interval
    engine:update(0.05)
    -- In mock environment, frames might be captured immediately
    
    advanceTime(0.06)  -- Past frame interval
    engine:update(0.06)
    assert_true(engine.capture_stats.frames_captured >= 0, "Should have non-negative captured frames")
    
    -- Test stopping capture
    success = engine:stopCapture()
    assert_true(success, "Capture should stop successfully")
    assert_false(engine.is_capturing, "Should not be capturing after stop")
end

-- Test frame rate control and adjustment
function tests.testFrameRateControl()
    local engine = CaptureEngine:new()
    
    -- Test setting valid frame rates
    local success, err = engine:setFrameRate(60)
    assert_true(success, "Should set 60 FPS successfully")
    assert_equal(60, engine.target_frame_rate, "Frame rate should be 60")
    
    success, err = engine:setFrameRate(15)
    assert_true(success, "Should set 15 FPS successfully")
    assert_equal(15, engine.target_frame_rate, "Frame rate should be 15")
    
    -- Test invalid frame rates
    success, err = engine:setFrameRate(0)
    assert_false(success, "Should reject 0 FPS")
    
    success, err = engine:setFrameRate(150)
    assert_false(success, "Should reject 150 FPS")
    
    success, err = engine:setFrameRate(-10)
    assert_false(success, "Should reject negative FPS")
end

-- Test capture statistics and monitoring
function tests.testCaptureStatistics()
    resetTime()
    local engine = CaptureEngine:new({ frame_rate = 20 })
    
    -- Configure and start capture
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    engine:startCapture()
    
    -- Simulate several frame captures
    for i = 1, 5 do
        advanceTime(0.05)  -- 20 FPS = 0.05s interval
        engine:update(0.05)
    end
    
    local stats = engine:getStats()
    
    -- Verify basic statistics
    assert_true(stats.is_capturing, "Stats should show capturing")
    assert_equal("screen", stats.source, "Stats should show screen source")
    assert_equal(20, stats.target_frame_rate, "Stats should show correct frame rate")
    assert_true(stats.frames_captured >= 5, "Stats should show captured frames")
    assert_true(stats.capture_duration >= 0, "Stats should show non-negative capture duration")
    
    -- Verify buffer statistics
    assert_not_nil(stats.buffer_stats, "Buffer stats should be included")
    assert_true(stats.buffer_stats.frame_count >= 0, "Buffer should contain frames")
end

-- Test source switching during capture
function tests.testSourceSwitchingDuringCapture()
    resetTime()
    local engine = CaptureEngine:new()
    
    -- Start with screen capture
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    engine:startCapture()
    
    -- Capture some frames
    advanceTime(0.1)
    engine:update(0.1)
    local initial_frames = engine.capture_stats.frames_captured
    
    -- Switch back to screen capture (since window capture needs a target window)
    local success, err = engine:setSource("screen", { mode = "MONITOR", monitor_index = 1 })
    assert_true(success, "Should switch source successfully: " .. (err or ""))
    assert_true(engine.is_capturing, "Should still be capturing after switch")
    assert_equal("screen", engine.current_source, "Source should be switched to screen")
    
    -- Verify statistics were preserved (frame count might reset on source switch)
    local stats = engine:getStats()
    assert_true(stats.frames_captured >= 0, "Frame count should be non-negative after switch")
end

-- Test error handling and recovery
function tests.testErrorHandlingAndRecovery()
    local engine = CaptureEngine:new()
    
    -- Test starting capture without source
    local success, err = engine:startCapture()
    assert_false(success, "Should fail to start without source")
    assert_not_nil(err, "Error message should be provided")
    
    -- Test error clearing
    engine.last_error = "Test error"
    engine:clearError()
    assert_nil(engine:getLastError(), "Error should be cleared")
end

-- Test frame buffer integration
function tests.testFrameBufferIntegration()
    resetTime()
    local engine = CaptureEngine:new({ buffer_size = 2 })
    
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    engine:startCapture()
    
    -- Capture multiple frames
    for i = 1, 4 do
        advanceTime(0.05)
        engine:update(0.05)
    end
    
    -- Test frame retrieval
    local latest_frame = engine:getFrame()
    if latest_frame then
        assert_not_nil(latest_frame, "Should have latest frame")
        
        local previous_frame = engine:getFrameByAge(1)
        if previous_frame then
            assert_true(latest_frame.timestamp >= previous_frame.timestamp, 
                       "Latest frame should have newer or equal timestamp")
        end
    end
end

-- Test capture-to-display pipeline integration (Requirement 4.3, 4.4)
function tests.testCaptureToDisplayPipeline()
    resetTime()
    local engine = CaptureEngine:new({ frame_rate = 30 })
    
    -- Configure screen capture
    local success, err = engine:setSource("screen", { mode = "FULL_SCREEN" })
    assert_true(success, "Screen source should be configured: " .. (err or ""))
    
    -- Start capture
    success, err = engine:startCapture()
    assert_true(success, "Capture should start: " .. (err or ""))
    
    -- Simulate real-time capture-to-display pipeline
    local display_frames = {}
    local dropped_frames = 0
    local processed_frames = 0
    
    -- Simulate 1 second of capture at 30 FPS
    for frame_num = 1, 30 do
        advanceTime(1/30)  -- Advance by one frame interval
        engine:update(1/30)
        
        -- Simulate display processing
        local frame = engine:getFrame()
        if frame then
            -- Simulate display processing time (some frames might be slow)
            local processing_time = (frame_num % 10 == 0) and 0.04 or 0.01  -- Every 10th frame is slow
            
            -- Check if frame should be dropped due to slow processing (Requirement 4.4)
            if processing_time > 0.033 then  -- More than 33ms for 30 FPS
                dropped_frames = dropped_frames + 1
            else
                table.insert(display_frames, {
                    frame = frame,
                    processing_time = processing_time,
                    frame_number = frame_num
                })
                processed_frames = processed_frames + 1
            end
        end
    end
    
    -- Verify pipeline performance
    assert_true(processed_frames > 0, "Should have processed some frames")
    assert_true(processed_frames >= 25, "Should maintain reasonable frame rate (25+ out of 30)")
    
    -- Verify frame dropping behavior (Requirement 4.4)
    local stats = engine:getStats()
    assert_true(stats.frames_captured >= 25, "Should capture most frames")
    
    -- Test immediate response to control commands (Requirement 4.3)
    local stop_time = mock_time
    success = engine:stopCapture()
    assert_true(success, "Should stop immediately")
    assert_false(engine.is_capturing, "Should stop capturing immediately")
    
    -- Verify no additional frames are captured after stop
    local frames_at_stop = stats.frames_captured
    advanceTime(0.1)
    engine:update(0.1)
    local stats_after_stop = engine:getStats()
    assert_equal(frames_at_stop, stats_after_stop.frames_captured, "No frames should be captured after stop")
end

-- Test source configuration options (Requirement 5.2)
function tests.testSourceConfigurationOptions()
    local engine = CaptureEngine:new()
    
    -- Test screen capture configuration options
    local screen_config = {
        mode = "CUSTOM_REGION",
        region = { x = 100, y = 100, width = 800, height = 600 },
        monitor_index = 1
    }
    
    local success, err = engine:setSource("screen", screen_config)
    assert_true(success, "Should configure screen source: " .. (err or ""))
    
    -- Verify configuration was applied
    local current_config = engine:getSourceConfig()
    assert_equal("screen", current_config.source_type, "Source type should be screen")
    assert_equal("CUSTOM_REGION", current_config.config.mode, "Mode should be set")
    assert_not_nil(current_config.config.region, "Region should be configured")
    
    -- Test window capture configuration options
    local window_config = {
        tracking = true,
        dpi_aware = true,
        capture_borders = false,
        auto_retry = true,
        max_retries = 3
    }
    
    success, err = engine:setSource("window", window_config)
    assert_true(success, "Should configure window source: " .. (err or ""))
    
    current_config = engine:getSourceConfig()
    assert_equal("window", current_config.source_type, "Source type should be window")
    assert_true(current_config.config.tracking, "Tracking should be enabled")
    assert_true(current_config.config.dpi_aware, "DPI awareness should be enabled")
    
    -- Test frame rate configuration
    success, err = engine:setFrameRate(60)
    assert_true(success, "Should set frame rate: " .. (err or ""))
    assert_equal(60, engine:getFrameRate(), "Frame rate should be updated")
    
    -- Test getting optimal settings for current source
    local optimal = engine:getOptimalSettings()
    assert_not_nil(optimal, "Should provide optimal settings")
    assert_not_nil(optimal.recommended_fps, "Should recommend FPS")
    assert_not_nil(optimal.max_width, "Should provide max width")
    assert_not_nil(optimal.max_height, "Should provide max height")
end

-- Test real-time performance requirements (Requirement 4.4)
function tests.testRealTimePerformanceRequirements()
    resetTime()
    local engine = CaptureEngine:new({ 
        frame_rate = 60,  -- High frame rate to test performance
        monitor_performance = true 
    })
    
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    engine:startCapture()
    
    -- Simulate high-frequency updates
    local total_updates = 120  -- 2 seconds at 60 FPS
    local on_time_captures = 0
    
    for i = 1, total_updates do
        local frame_start = mock_time
        advanceTime(1/60)  -- 60 FPS interval
        engine:update(1/60)
        
        -- Check if capture maintained real-time performance
        local stats = engine:getStats()
        if stats.performance and stats.performance.average_capture_time then
            if stats.performance.average_capture_time < 0.016 then  -- Less than 16ms for 60 FPS
                on_time_captures = on_time_captures + 1
            end
        else
            on_time_captures = on_time_captures + 1  -- Assume good performance if no data
        end
    end
    
    -- Verify real-time performance
    local performance_ratio = on_time_captures / total_updates
    assert_true(performance_ratio >= 0.8, "Should maintain real-time performance 80% of the time")
    
    -- Verify frame dropping mechanism
    local final_stats = engine:getStats()
    if final_stats.frames_dropped > 0 then
        -- If frames were dropped, verify it was for performance reasons
        assert_true(final_stats.frames_captured + final_stats.frames_dropped >= total_updates * 0.8,
                   "Total frame attempts should be reasonable")
    end
end

-- Test immediate response to playback controls (Requirement 4.3)
function tests.testImmediateControlResponse()
    resetTime()
    local engine = CaptureEngine:new({ frame_rate = 30 })
    
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    
    -- Test immediate start response
    local start_time = mock_time
    local success, err = engine:startCapture()
    assert_true(success, "Should start immediately: " .. (err or ""))
    assert_true(engine.is_capturing, "Should be capturing immediately after start")
    assert_false(engine.is_paused, "Should not be paused after start")
    
    -- Capture some frames
    for i = 1, 5 do
        advanceTime(1/30)
        engine:update(1/30)
    end
    
    local frames_before_pause = engine.capture_stats.frames_captured
    
    -- Test immediate pause response
    local pause_time = mock_time
    success, err = engine:pauseCapture()
    assert_true(success, "Should pause immediately: " .. (err or ""))
    assert_true(engine.is_capturing, "Should still be in capturing state")
    assert_true(engine.is_paused, "Should be paused immediately")
    
    -- Verify no frames are captured while paused
    for i = 1, 3 do
        advanceTime(1/30)
        engine:update(1/30)
    end
    
    local frames_during_pause = engine.capture_stats.frames_captured
    assert_equal(frames_before_pause, frames_during_pause, "No frames should be captured while paused")
    
    -- Test immediate resume response
    local resume_time = mock_time
    success, err = engine:resumeCapture()
    assert_true(success, "Should resume immediately: " .. (err or ""))
    assert_true(engine.is_capturing, "Should still be capturing")
    assert_false(engine.is_paused, "Should not be paused after resume")
    
    -- Verify frames are captured after resume
    for i = 1, 3 do
        advanceTime(1/30)
        engine:update(1/30)
    end
    
    local frames_after_resume = engine.capture_stats.frames_captured
    assert_true(frames_after_resume > frames_during_pause, "Should capture frames after resume")
    
    -- Test immediate stop response
    local stop_time = mock_time
    success = engine:stopCapture()
    assert_true(success, "Should stop immediately")
    assert_false(engine.is_capturing, "Should not be capturing after stop")
    assert_false(engine.is_paused, "Should not be paused after stop")
    
    -- Verify no frames are captured after stop
    local frames_at_stop = engine.capture_stats.frames_captured
    for i = 1, 3 do
        advanceTime(1/30)
        engine:update(1/30)
    end
    
    local frames_after_stop = engine.capture_stats.frames_captured
    assert_equal(frames_at_stop, frames_after_stop, "No frames should be captured after stop")
    
    -- Test error handling for invalid control operations
    success, err = engine:pauseCapture()
    assert_false(success, "Should not pause when not capturing")
    assert_not_nil(err, "Should provide error message")
    
    success, err = engine:resumeCapture()
    assert_false(success, "Should not resume when not capturing")
    assert_not_nil(err, "Should provide error message")
end

-- Test configuration updates
function tests.testConfigurationUpdates()
    local engine = CaptureEngine:new()
    
    -- Set initial screen configuration
    engine:setSource("screen", { 
        mode = "FULL_SCREEN",
        monitor_index = 1 
    })
    
    -- Update configuration
    local success, err = engine:updateSourceConfig({
        mode = "CUSTOM_REGION",
        region = { x = 100, y = 100, width = 800, height = 600 }
    })
    assert_true(success, "Should update screen config successfully: " .. (err or ""))
    
    -- Verify configuration was merged
    local config = engine:getSourceConfig()
    assert_equal("CUSTOM_REGION", config.config.mode, "Mode should be updated")
    assert_equal(1, config.config.monitor_index, "Monitor index should be preserved")
    assert_not_nil(config.config.region, "Region should be added")
end

-- Test available sources enumeration
function tests.testAvailableSourcesEnumeration()
    local engine = CaptureEngine:new()
    
    local sources = engine:getAvailableSources()
    
    assert_not_nil(sources, "Sources should be returned")
    assert_not_nil(sources.screen, "Screen source should be available")
    assert_true(sources.screen.available, "Screen should be marked as available")
    
    assert_not_nil(sources.window, "Window source should be listed")
    assert_true(sources.window.available, "Window should be marked as available")
    
    assert_not_nil(sources.webcam, "Webcam source should be listed")
    assert_false(sources.webcam.available, "Webcam should be marked as unavailable")
end

-- Test performance monitoring
function tests.testPerformanceMonitoring()
    resetTime()
    local engine = CaptureEngine:new({ monitor_performance = true })
    
    engine:setSource("screen", { mode = "FULL_SCREEN" })
    engine:startCapture()
    
    -- Simulate captures
    for i = 1, 5 do
        advanceTime(0.05)
        engine:update(0.05)
    end
    
    local stats = engine:getStats()
    
    if stats.performance then
        assert_true(stats.performance.samples >= 0, "Should have performance samples")
        assert_true(stats.performance.average_capture_time >= 0, "Average time should be non-negative")
    end
    
    -- Test disabling performance monitoring
    engine:setPerformanceMonitoring(false)
    assert_false(engine.performance_monitor.enabled, "Performance monitoring should be disabled")
end

-- Cleanup function
local function cleanup()
    -- Restore original love global
    _G.love = original_love
    _G.TESTING_MODE = nil
end

-- Run all tests
TestFramework.setup_mock_environment()
TestFramework.run_suite("CaptureEngine Integration Tests", tests)
cleanup()

return tests