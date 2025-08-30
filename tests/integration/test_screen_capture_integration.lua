-- Integration tests for Screen Capture with Capture Engine
local CaptureEngine = require("src.capture_engine")
local mock_ffi = require("tests.mock_ffi_bindings")

-- Enable testing mode
_G.TESTING_MODE = true

-- Test framework setup
local tests = {}
local test_count = 0
local passed_count = 0

local function assert_equal(actual, expected, message)
    test_count = test_count + 1
    if actual == expected then
        passed_count = passed_count + 1
        print("✓ " .. (message or "Test passed"))
    else
        print("✗ " .. (message or "Test failed") .. 
              " - Expected: " .. tostring(expected) .. 
              ", Got: " .. tostring(actual))
    end
end

local function assert_true(condition, message)
    assert_equal(condition, true, message)
end

local function assert_false(condition, message)
    assert_equal(condition, false, message)
end

local function assert_not_nil(value, message)
    test_count = test_count + 1
    if value ~= nil then
        passed_count = passed_count + 1
        print("✓ " .. (message or "Value is not nil"))
    else
        print("✗ " .. (message or "Value should not be nil"))
    end
end

-- Test: Basic screen capture setup
function tests.test_basic_screen_capture_setup()
    print("\n--- Testing Basic Screen Capture Setup ---")
    
    -- Setup mock monitors
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true}
    })
    
    local engine = CaptureEngine:new()
    
    -- Test setting screen source
    local success = engine:setSource("screen")
    assert_true(success, "Screen source set successfully")
    assert_equal(engine.current_source, "screen", "Current source is screen")
    assert_not_nil(engine.screen_capture, "Screen capture instance created")
end

-- Test: Screen capture with different modes
function tests.test_screen_capture_modes()
    print("\n--- Testing Screen Capture Modes ---")
    
    -- Setup dual monitor configuration
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
    })
    
    local engine = CaptureEngine:new()
    
    -- Test full screen mode
    local success = engine:setSource("screen", {mode = "full_screen"})
    assert_true(success, "Full screen mode configured")
    
    local stats = engine:getStats()
    assert_equal(stats.capture_region.mode, "FULL_SCREEN", "Full screen mode active")
    assert_equal(stats.capture_region.width, 1920, "Full screen width correct")
    assert_equal(stats.capture_region.height, 1080, "Full screen height correct")
    
    -- Test monitor mode
    success = engine:setSource("screen", {mode = "monitor", monitor_index = 2})
    assert_true(success, "Monitor mode configured")
    
    stats = engine:getStats()
    assert_equal(stats.capture_region.mode, "MONITOR", "Monitor mode active")
    assert_equal(stats.capture_region.x, 1920, "Monitor X position correct")
    
    -- Test custom region mode
    success = engine:setSource("screen", {
        mode = "custom_region",
        region = {x = 100, y = 100, width = 800, height = 600}
    })
    assert_true(success, "Custom region mode configured")
    
    stats = engine:getStats()
    assert_equal(stats.capture_region.mode, "CUSTOM_REGION", "Custom region mode active")
    assert_equal(stats.capture_region.x, 100, "Custom region X correct")
    assert_equal(stats.capture_region.width, 800, "Custom region width correct")
end

-- Test: Frame capture functionality
function tests.test_frame_capture()
    print("\n--- Testing Frame Capture Functionality ---")
    
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true}
    })
    
    local engine = CaptureEngine:new()
    engine:setSource("screen")
    
    -- Test capture before starting
    local frame = engine:captureFrame()
    assert_equal(frame, nil, "No frame captured before starting")
    
    -- Start capture
    local success = engine:startCapture()
    assert_true(success, "Capture started successfully")
    assert_true(engine.is_capturing, "Engine is capturing")
    
    -- Capture a frame
    frame = engine:captureFrame()
    assert_not_nil(frame, "Frame captured successfully")
    assert_not_nil(frame.data, "Frame has pixel data")
    assert_equal(frame.width, 1920, "Frame width correct")
    assert_equal(frame.height, 1080, "Frame height correct")
    assert_equal(frame.source, "screen", "Frame source correct")
    
    -- Test getting the same frame
    local same_frame = engine:getFrame()
    assert_equal(same_frame, frame, "getFrame returns same frame")
    
    -- Stop capture
    success = engine:stopCapture()
    assert_true(success, "Capture stopped successfully")
    assert_false(engine.is_capturing, "Engine is not capturing")
end

-- Test: Capture statistics
function tests.test_capture_statistics()
    print("\n--- Testing Capture Statistics ---")
    
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true}
    })
    
    local engine = CaptureEngine:new()
    engine:setSource("screen")
    engine:startCapture()
    
    -- Initial stats
    local stats = engine:getStats()
    assert_equal(stats.frames_captured, 0, "Initial frames captured is 0")
    assert_equal(stats.frames_dropped, 0, "Initial frames dropped is 0")
    
    -- Capture some frames
    for i = 1, 3 do
        engine:captureFrame()
    end
    
    stats = engine:getStats()
    assert_equal(stats.frames_captured, 3, "Frames captured count updated")
    assert_equal(stats.source, "screen", "Source in stats correct")
    assert_true(stats.is_capturing, "Capturing status in stats correct")
    assert_not_nil(stats.monitors, "Monitor info in stats")
    assert_equal(#stats.monitors, 1, "Correct number of monitors in stats")
end

-- Test: Monitor enumeration through engine
function tests.test_monitor_enumeration_through_engine()
    print("\n--- Testing Monitor Enumeration Through Engine ---")
    
    -- Setup triple monitor configuration
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false},
        {left = 3840, top = 0, right = 5760, bottom = 1080, isPrimary = false}
    })
    
    local engine = CaptureEngine:new()
    
    -- Get monitors without setting source
    local monitors = engine:getAvailableMonitors()
    assert_not_nil(monitors, "Monitors enumerated without source")
    assert_equal(#monitors, 3, "Three monitors detected")
    
    -- Verify primary monitor
    local primary_found = false
    for _, monitor in ipairs(monitors) do
        if monitor.isPrimary then
            primary_found = true
            assert_equal(monitor.width, 1920, "Primary monitor width correct")
            assert_equal(monitor.height, 1080, "Primary monitor height correct")
            break
        end
    end
    assert_true(primary_found, "Primary monitor found")
end

-- Test: Optimal settings calculation
function tests.test_optimal_settings_through_engine()
    print("\n--- Testing Optimal Settings Through Engine ---")
    
    -- Test different resolutions
    local test_cases = {
        {width = 1280, height = 720, expected_fps = 60},
        {width = 1920, height = 1080, expected_fps = 30},
        {width = 3840, height = 2160, expected_fps = 24}
    }
    
    for i, case in ipairs(test_cases) do
        mock_ffi.setMockMonitors({
            {left = 0, top = 0, right = case.width, bottom = case.height, isPrimary = true}
        })
        
        local engine = CaptureEngine:new()
        engine:setSource("screen")
        
        local settings = engine:getOptimalSettings()
        assert_equal(settings.max_width, case.width, 
                    "Optimal width for " .. case.width .. "x" .. case.height)
        assert_equal(settings.recommended_fps, case.expected_fps, 
                    "Optimal FPS for " .. case.width .. "x" .. case.height)
    end
end

-- Test: Error handling in integration
function tests.test_error_handling_integration()
    print("\n--- Testing Error Handling Integration ---")
    
    local engine = CaptureEngine:new()
    
    -- Test invalid source type
    local success, err = engine:setSource("invalid_source")
    assert_false(success, "Invalid source type rejected")
    assert_not_nil(err, "Error message provided")
    
    -- Test capture without source
    success, err = engine:startCapture()
    assert_false(success, "Start capture fails without source")
    
    -- Test with API failures
    mock_ffi.setFailureMode(true)
    
    success, err = engine:setSource("screen")
    assert_false(success, "Screen source fails when API fails")
    
    -- Reset failure mode
    mock_ffi.setFailureMode(false)
    
    -- Test frame capture failure
    engine:setSource("screen")
    engine:startCapture()
    
    mock_ffi.setFailureMode(true)
    local frame = engine:captureFrame()
    assert_equal(frame, nil, "Frame capture fails when API fails")
    
    local stats = engine:getStats()
    assert_equal(stats.frames_dropped, 1, "Frame drop counted")
    
    mock_ffi.setFailureMode(false)
end

-- Test: Configuration validation
function tests.test_configuration_validation()
    print("\n--- Testing Configuration Validation ---")
    
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true}
    })
    
    local engine = CaptureEngine:new()
    
    -- Test invalid region configuration
    local success, err = engine:setSource("screen", {
        mode = "custom_region",
        region = {x = 100, y = 100, width = 0, height = 600}
    })
    assert_false(success, "Invalid region rejected")
    
    -- Test invalid monitor index
    success, err = engine:setSource("screen", {
        mode = "monitor",
        monitor_index = 5
    })
    assert_false(success, "Invalid monitor index rejected")
    
    -- Test valid configuration
    success = engine:setSource("screen", {
        mode = "custom_region",
        region = {x = 100, y = 100, width = 800, height = 600}
    })
    assert_true(success, "Valid configuration accepted")
end

-- Run all tests
function tests.run_all()
    print("=== Screen Capture Integration Tests ===")
    
    tests.test_basic_screen_capture_setup()
    tests.test_screen_capture_modes()
    tests.test_frame_capture()
    tests.test_capture_statistics()
    tests.test_monitor_enumeration_through_engine()
    tests.test_optimal_settings_through_engine()
    tests.test_error_handling_integration()
    tests.test_configuration_validation()
    
    print("\n=== Test Results ===")
    print("Total tests: " .. test_count)
    print("Passed: " .. passed_count)
    print("Failed: " .. (test_count - passed_count))
    print("Success rate: " .. math.floor((passed_count / test_count) * 100) .. "%")
    
    return passed_count == test_count
end

return tests