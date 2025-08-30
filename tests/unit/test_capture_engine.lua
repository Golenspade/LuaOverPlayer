-- Unit tests for CaptureEngine core functionality
-- Set testing mode before requiring modules
_G.TESTING_MODE = true

local TestFramework = require("tests.test_framework")
local CaptureEngine = require("src.capture_engine")

-- Mock LÖVE timer for consistent testing
local mock_time = 0
local original_love = _G.love
_G.love = {
    timer = {
        getTime = function() return mock_time end
    }
}

-- Helper to advance mock time
local function advanceTime(dt)
    mock_time = mock_time + dt
end

-- Helper to reset mock time
local function resetTime()
    mock_time = 0
end

-- Test suite
local tests = {}

-- Test basic engine creation and initialization
function tests.testEngineCreation()
    local engine = CaptureEngine:new()
    
    assert_not_nil(engine, "Engine should be created")
    assert_not_nil(engine.frame_buffer, "Frame buffer should be initialized")
    assert_equal(30, engine.target_frame_rate, "Default frame rate should be 30")
    assert_false(engine.is_capturing, "Should not be capturing initially")
    assert_nil(engine.current_source, "No source should be set")
    
    -- Test custom options
    local custom_engine = CaptureEngine:new({
        frame_rate = 60,
        buffer_size = 5,
        monitor_performance = false
    })
    
    assert_equal(60, custom_engine.target_frame_rate, "Custom frame rate should be set")
    assert_equal(5, custom_engine.frame_buffer.max_frames, "Custom buffer size should be set")
    assert_false(custom_engine.performance_monitor.enabled, "Performance monitoring should be disabled")
end

-- Test source type validation
function tests.testSourceTypeValidation()
    local engine = CaptureEngine:new()
    
    -- Test valid source types (excluding webcam as it's not implemented)
    local success, err = engine:setSource("screen", {})
    assert_true(success, "Screen source should be accepted: " .. (err or ""))
    
    success, err = engine:setSource("window", {})
    assert_true(success, "Window source should be accepted: " .. (err or ""))
    
    -- Test invalid source types
    success, err = engine:setSource("invalid", {})
    assert_false(success, "Invalid source should be rejected")
    assert_not_nil(err, "Error message should be provided for invalid source")
    
    success, err = engine:setSource("", {})
    assert_false(success, "Empty source should be rejected")
end

-- Test frame rate control
function tests.testFrameRateControl()
    local engine = CaptureEngine:new()
    
    -- Test valid frame rates
    local success, err = engine:setFrameRate(60)
    assert_true(success, "Should set 60 FPS successfully: " .. (err or ""))
    assert_equal(60, engine.target_frame_rate, "Frame rate should be 60")
    
    success, err = engine:setFrameRate(15)
    assert_true(success, "Should set 15 FPS successfully: " .. (err or ""))
    assert_equal(15, engine.target_frame_rate, "Frame rate should be 15")
    
    -- Test invalid frame rates
    success, err = engine:setFrameRate(0)
    assert_false(success, "Should reject 0 FPS")
    
    success, err = engine:setFrameRate(150)
    assert_false(success, "Should reject 150 FPS")
end

-- Test capture state management
function tests.testCaptureStateManagement()
    resetTime()
    local engine = CaptureEngine:new()
    
    -- Test starting capture without source
    local success, err = engine:startCapture()
    assert_false(success, "Should not start capture without source")
    assert_not_nil(err, "Error message should be provided")
    
    -- Set a source and test capture lifecycle
    engine:setSource("screen", { mode = "fullscreen" })
    
    success, err = engine:startCapture()
    assert_true(success, "Should start capture with valid source: " .. (err or ""))
    assert_true(engine.is_capturing, "Should be in capturing state")
    
    -- Test stopping capture
    success = engine:stopCapture()
    assert_true(success, "Should stop capture successfully")
    assert_false(engine.is_capturing, "Should not be in capturing state")
end

-- Test statistics tracking
function tests.testStatisticsTracking()
    resetTime()
    local engine = CaptureEngine:new()
    
    engine:setSource("screen", { mode = "fullscreen" })
    engine:startCapture()
    
    -- Initial statistics
    local stats = engine:getStats()
    assert_equal(0, stats.frames_captured, "Initial frames captured should be 0")
    assert_equal(0, stats.frames_dropped, "Initial frames dropped should be 0")
    assert_equal(0, stats.capture_duration, "Initial capture duration should be 0")
    
    -- Simulate frame captures
    advanceTime(0.1)
    engine:update(0.1)
    
    stats = engine:getStats()
    assert_true(stats.frames_captured >= 0, "Should have non-negative captured frames")
    assert_true(stats.capture_duration >= 0, "Should have non-negative capture duration")
    assert_not_nil(stats.buffer_stats, "Should include buffer statistics")
end

-- Test source configuration management
function tests.testSourceConfigurationManagement()
    local engine = CaptureEngine:new()
    
    -- Test screen configuration
    local screen_config = {
        mode = "CUSTOM_REGION",
        region = { x = 100, y = 100, width = 800, height = 600 },
        monitor_index = 1
    }
    
    local success, err = engine:setSource("screen", screen_config)
    assert_true(success, "Should set screen source with config: " .. (err or ""))
    
    local current_config = engine:getSourceConfig()
    assert_equal("screen", current_config.source_type, "Source type should be screen")
    assert_equal("CUSTOM_REGION", current_config.config.mode, "Mode should be set")
    assert_not_nil(current_config.config.region, "Region should be set")
end

-- Test error handling and recovery
function tests.testErrorHandlingAndRecovery()
    local engine = CaptureEngine:new()
    
    -- Test error state management
    engine.last_error = "Test error"
    assert_equal("Test error", engine:getLastError(), "Should return last error")
    
    engine:clearError()
    assert_nil(engine:getLastError(), "Error should be cleared")
    
    -- Test invalid operations
    local success, err = engine:updateSourceConfig({})
    assert_false(success, "Should fail to update config without source")
    assert_not_nil(err, "Error message should be provided")
end

-- Test source availability checking
function tests.testSourceAvailability()
    local engine = CaptureEngine:new()
    
    local sources = engine:getAvailableSources()
    
    assert_not_nil(sources, "Should return sources list")
    assert_not_nil(sources.screen, "Screen source should be listed")
    assert_not_nil(sources.window, "Window source should be listed")
    assert_not_nil(sources.webcam, "Webcam source should be listed")
    
    assert_true(sources.screen.available, "Screen should be available")
    assert_true(sources.window.available, "Window should be available")
    assert_false(sources.webcam.available, "Webcam should not be available")
end

-- Test optimal settings calculation
function tests.testOptimalSettings()
    local engine = CaptureEngine:new()
    
    -- Test default settings
    local settings = engine:getOptimalSettings()
    assert_not_nil(settings, "Should return optimal settings")
    assert_not_nil(settings.recommended_fps, "Should have recommended FPS")
    assert_not_nil(settings.max_width, "Should have max width")
    assert_not_nil(settings.max_height, "Should have max height")
    
    -- Test source-specific settings
    engine:setSource("screen", { mode = "fullscreen" })
    local screen_settings = engine:getOptimalSettings()
    assert_not_nil(screen_settings, "Should return screen-specific settings")
    
    engine:setSource("window", { window = "Test Window" })
    local window_settings = engine:getOptimalSettings()
    assert_not_nil(window_settings, "Should return window-specific settings")
end

-- Cleanup function
local function cleanup()
    -- Restore original love global
    _G.love = original_love
    _G.TESTING_MODE = nil
end

-- Run all tests
TestFramework.setup_mock_environment()
TestFramework.run_suite("CaptureEngine Unit Tests", tests)
cleanup()

return tests