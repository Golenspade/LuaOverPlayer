-- Tests for Screen Capture functionality
local ScreenCapture = require("src.screen_capture")
local mock_ffi = require("tests.mock_ffi_bindings")

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

-- Test: ScreenCapture initialization
function tests.test_initialization()
    print("\n--- Testing ScreenCapture Initialization ---")
    
    local capture = ScreenCapture:new()
    assert_not_nil(capture, "ScreenCapture instance created")
    assert_equal(capture.mode, "FULL_SCREEN", "Default mode is FULL_SCREEN")
    assert_equal(capture.monitor_index, 1, "Default monitor index is 1")
    assert_equal(#capture.monitors, 0, "Monitors list initially empty")
end

-- Test: Monitor enumeration
function tests.test_monitor_enumeration()
    print("\n--- Testing Monitor Enumeration ---")
    
    -- Mock monitor data
    mock_ffi.setMockMonitors({
        {
            left = 0, top = 0, right = 1920, bottom = 1080,
            workLeft = 0, workTop = 0, workRight = 1920, workBottom = 1040,
            isPrimary = true
        },
        {
            left = 1920, top = 0, right = 3840, bottom = 1080,
            workLeft = 1920, workTop = 0, workRight = 3840, workBottom = 1040,
            isPrimary = false
        }
    })
    
    local capture = ScreenCapture:new()
    local success, err = capture:initialize()
    
    assert_true(success, "Initialization successful")
    
    local monitors = capture:getMonitors()
    assert_equal(#monitors, 2, "Two monitors detected")
    
    if #monitors >= 1 then
        assert_equal(monitors[1].width, 1920, "First monitor width correct")
        assert_equal(monitors[1].height, 1080, "First monitor height correct")
        assert_true(monitors[1].isPrimary, "First monitor is primary")
    end
    
    if #monitors >= 2 then
        assert_equal(monitors[2].left, 1920, "Second monitor left position correct")
        assert_false(monitors[2].isPrimary, "Second monitor is not primary")
    end
end

-- Test: Capture mode setting
function tests.test_capture_modes()
    print("\n--- Testing Capture Modes ---")
    
    local capture = ScreenCapture:new()
    capture:initialize()
    
    -- Test valid modes
    local success = capture:setMode("full_screen")
    assert_true(success, "Set FULL_SCREEN mode")
    assert_equal(capture.mode, "FULL_SCREEN", "Mode set correctly")
    
    success = capture:setMode("custom_region")
    assert_true(success, "Set CUSTOM_REGION mode")
    assert_equal(capture.mode, "CUSTOM_REGION", "Mode set correctly")
    
    success = capture:setMode("monitor")
    assert_true(success, "Set MONITOR mode")
    assert_equal(capture.mode, "MONITOR", "Mode set correctly")
    
    success = capture:setMode("virtual_screen")
    assert_true(success, "Set VIRTUAL_SCREEN mode")
    assert_equal(capture.mode, "VIRTUAL_SCREEN", "Mode set correctly")
    
    -- Test invalid mode
    local success, err = capture:setMode("invalid_mode")
    assert_false(success, "Invalid mode rejected")
    assert_not_nil(err, "Error message provided for invalid mode")
end

-- Test: Custom region configuration
function tests.test_custom_region()
    print("\n--- Testing Custom Region Configuration ---")
    
    local capture = ScreenCapture:new()
    
    -- Test valid region
    local success = capture:setRegion(100, 100, 800, 600)
    assert_true(success, "Valid region set successfully")
    assert_equal(capture.region.x, 100, "Region X coordinate correct")
    assert_equal(capture.region.y, 100, "Region Y coordinate correct")
    assert_equal(capture.region.width, 800, "Region width correct")
    assert_equal(capture.region.height, 600, "Region height correct")
    assert_equal(capture.mode, "CUSTOM_REGION", "Mode automatically set to CUSTOM_REGION")
    
    -- Test invalid regions
    local success, err = capture:setRegion("invalid", 100, 800, 600)
    assert_false(success, "Invalid X coordinate rejected")
    
    success, err = capture:setRegion(100, 100, 0, 600)
    assert_false(success, "Zero width rejected")
    
    success, err = capture:setRegion(100, 100, 800, -100)
    assert_false(success, "Negative height rejected")
end

-- Test: Monitor selection
function tests.test_monitor_selection()
    print("\n--- Testing Monitor Selection ---")
    
    -- Setup mock monitors
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
    })
    
    local capture = ScreenCapture:new()
    capture:initialize()
    
    -- Test valid monitor selection
    local success = capture:setMonitor(1)
    assert_true(success, "First monitor selected successfully")
    assert_equal(capture.monitor_index, 1, "Monitor index set correctly")
    assert_equal(capture.mode, "MONITOR", "Mode set to MONITOR")
    
    success = capture:setMonitor(2)
    assert_true(success, "Second monitor selected successfully")
    assert_equal(capture.monitor_index, 2, "Monitor index updated")
    
    -- Test invalid monitor selection
    success, err = capture:setMonitor(0)
    assert_false(success, "Zero monitor index rejected")
    
    success, err = capture:setMonitor(5)
    assert_false(success, "Out of range monitor index rejected")
    
    success, err = capture:setMonitor("invalid")
    assert_false(success, "Non-numeric monitor index rejected")
end

-- Test: Capture info generation
function tests.test_capture_info()
    print("\n--- Testing Capture Info Generation ---")
    
    -- Setup mock monitors
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
    })
    
    local capture = ScreenCapture:new()
    capture:initialize()
    
    -- Test full screen mode info
    capture:setMode("full_screen")
    local info = capture:getCaptureInfo()
    assert_equal(info.mode, "FULL_SCREEN", "Full screen mode info correct")
    assert_equal(info.width, 1920, "Full screen width correct")
    assert_equal(info.height, 1080, "Full screen height correct")
    
    -- Test custom region mode info
    capture:setRegion(200, 150, 640, 480)
    info = capture:getCaptureInfo()
    assert_equal(info.mode, "CUSTOM_REGION", "Custom region mode info correct")
    assert_equal(info.x, 200, "Custom region X correct")
    assert_equal(info.y, 150, "Custom region Y correct")
    assert_equal(info.width, 640, "Custom region width correct")
    assert_equal(info.height, 480, "Custom region height correct")
    
    -- Test monitor mode info
    capture:setMonitor(2)
    info = capture:getCaptureInfo()
    assert_equal(info.mode, "MONITOR", "Monitor mode info correct")
    assert_equal(info.x, 1920, "Monitor X position correct")
    assert_equal(info.width, 1920, "Monitor width correct")
end

-- Test: Region validation
function tests.test_region_validation()
    print("\n--- Testing Region Validation ---")
    
    -- Setup mock monitors
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
    })
    
    local capture = ScreenCapture:new()
    capture:initialize()
    
    -- Test valid regions (intersecting with monitors)
    local valid = capture:validateRegion(100, 100, 800, 600)
    assert_true(valid, "Region within first monitor is valid")
    
    valid = capture:validateRegion(2000, 100, 800, 600)
    assert_true(valid, "Region within second monitor is valid")
    
    valid = capture:validateRegion(1800, 100, 400, 600)
    assert_true(valid, "Region spanning both monitors is valid")
    
    -- Test invalid regions (not intersecting with any monitor)
    local valid, err = capture:validateRegion(5000, 5000, 800, 600)
    assert_false(valid, "Region outside all monitors is invalid")
    assert_not_nil(err, "Error message provided for invalid region")
end

-- Test: Optimal settings calculation
function tests.test_optimal_settings()
    print("\n--- Testing Optimal Settings Calculation ---")
    
    -- Test with different monitor resolutions
    local test_cases = {
        {width = 1280, height = 720, expected_fps = 60},   -- 720p
        {width = 1920, height = 1080, expected_fps = 30},  -- 1080p
        {width = 3840, height = 2160, expected_fps = 24}   -- 4K
    }
    
    for i, case in ipairs(test_cases) do
        mock_ffi.setMockMonitors({
            {left = 0, top = 0, right = case.width, bottom = case.height, isPrimary = true}
        })
        
        local capture = ScreenCapture:new()
        capture:initialize()
        
        local settings = capture:getOptimalSettings()
        assert_equal(settings.max_width, case.width, 
                    "Optimal width for " .. case.width .. "x" .. case.height)
        assert_equal(settings.max_height, case.height, 
                    "Optimal height for " .. case.width .. "x" .. case.height)
        assert_equal(settings.recommended_fps, case.expected_fps, 
                    "Optimal FPS for " .. case.width .. "x" .. case.height)
    end
end

-- Test: Multi-monitor scenarios
function tests.test_multi_monitor_scenarios()
    print("\n--- Testing Multi-Monitor Scenarios ---")
    
    -- Test various multi-monitor configurations
    local configs = {
        -- Dual monitor horizontal
        {
            {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
            {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
        },
        -- Dual monitor vertical
        {
            {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
            {left = 0, top = 1080, right = 1920, bottom = 2160, isPrimary = false}
        },
        -- Triple monitor
        {
            {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
            {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false},
            {left = 3840, top = 0, right = 5760, bottom = 1080, isPrimary = false}
        }
    }
    
    for i, config in ipairs(configs) do
        mock_ffi.setMockMonitors(config)
        
        local capture = ScreenCapture:new()
        local success = capture:initialize()
        assert_true(success, "Multi-monitor config " .. i .. " initialized")
        
        local monitors = capture:getMonitors()
        assert_equal(#monitors, #config, "Correct number of monitors detected for config " .. i)
        
        -- Test capturing each monitor
        for j = 1, #monitors do
            local success = capture:setMonitor(j)
            assert_true(success, "Monitor " .. j .. " selected in config " .. i)
            
            local info = capture:getCaptureInfo()
            assert_equal(info.width, monitors[j].width, 
                        "Monitor " .. j .. " width correct in config " .. i)
            assert_equal(info.height, monitors[j].height, 
                        "Monitor " .. j .. " height correct in config " .. i)
        end
    end
end

-- Test: Error handling
function tests.test_error_handling()
    print("\n--- Testing Error Handling ---")
    
    -- Test with mock API failures first
    mock_ffi.setFailureMode(true)
    
    local capture = ScreenCapture:new()
    
    -- Test operations when API fails
    local success, err = capture:setMonitor(1)
    assert_false(success, "Monitor selection fails when API fails")
    assert_not_nil(err, "Error message provided for API failure")
    
    success, err = capture:initialize()
    assert_false(success, "Initialization fails when API fails")
    assert_not_nil(err, "Error message provided for API failure")
    
    -- Reset failure mode
    mock_ffi.setFailureMode(false)
end

-- Run all tests
function tests.run_all()
    print("=== Screen Capture Tests ===")
    
    tests.test_initialization()
    tests.test_monitor_enumeration()
    tests.test_capture_modes()
    tests.test_custom_region()
    tests.test_monitor_selection()
    tests.test_capture_info()
    tests.test_region_validation()
    tests.test_optimal_settings()
    tests.test_multi_monitor_scenarios()
    tests.test_error_handling()
    
    print("\n=== Test Results ===")
    print("Total tests: " .. test_count)
    print("Passed: " .. passed_count)
    print("Failed: " .. (test_count - passed_count))
    print("Success rate: " .. math.floor((passed_count / test_count) * 100) .. "%")
    
    return passed_count == test_count
end

return tests