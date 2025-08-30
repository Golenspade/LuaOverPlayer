-- Integration tests for Window Capture functionality
-- Tests window state changes, capture accuracy, and edge cases

-- Detect platform and use appropriate FFI bindings
local ffi_bindings
local is_windows = package.config:sub(1,1) == '\\'

if is_windows then
    ffi_bindings = require("src.ffi_bindings")
else
    -- Use mock bindings for non-Windows platforms
    ffi_bindings = require("tests.mock_ffi_bindings")
    print("Running integration tests on non-Windows platform - using mock FFI bindings")
end

-- Mock the FFI bindings in window capture for testing
package.loaded["src.ffi_bindings"] = ffi_bindings
local WindowCapture = require("src.window_capture")

-- Test framework setup
local tests = {}
local test_count = 0
local passed_count = 0

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
              message or "values should be equal", tostring(expected), tostring(actual)))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Value should not be nil")
    end
end

local function assert_nil(value, message)
    if value ~= nil then
        error(message or "Value should be nil")
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "Value should be true")
    end
end

local function assert_false(value, message)
    if value then
        error(message or "Value should be false")
    end
end

-- Setup default mock windows for all tests
local function setup_default_mock_windows()
    if not is_windows then
        ffi_bindings.setMockWindows({
            {
                handle = "test_window_1",
                title = "Test Window 1",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            },
            {
                handle = "test_window_2",
                title = "Test Window 2", 
                visible = true,
                minimized = false,
                maximized = false,
                processId = 5678
            },
            {
                handle = "mock_minimized_window",
                title = "Minimized Window",
                visible = true,
                minimized = true,
                maximized = false,
                processId = 3456
            },
            {
                handle = "hidden_window",
                title = "Hidden Window",
                visible = false,
                minimized = false,
                maximized = false,
                processId = 9012
            }
        })
        -- Reset failure mode
        ffi_bindings.setFailureMode(false)
    end
end

local function run_test(name, test_func)
    test_count = test_count + 1
    print(string.format("Running integration test: %s", name))
    
    -- Setup default mock windows before each test
    setup_default_mock_windows()
    
    local success, error_msg = pcall(test_func)
    if success then
        passed_count = passed_count + 1
        print(string.format("  ✓ PASSED: %s", name))
    else
        print(string.format("  ✗ FAILED: %s", name))
        print(string.format("    Error: %s", error_msg))
    end
end

-- Test window state change detection
function tests.test_window_state_changes()
    local capture = WindowCapture:new()
    
    -- Set up mock windows with different states
    if not is_windows then
        ffi_bindings.setMockWindows({
            {
                handle = "test_window_1",
                title = "Test Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            }
        })
    end
    
    -- Find and set target window
    local windows = capture:enumerateWindows(false)
    assert_not_nil(windows, "Should enumerate windows")
    assert_true(type(windows) == "table", "Windows should be a table")
    assert_true(#windows > 0, "Should find at least one window")
    
    local success = capture:setTargetWindow(windows[1])
    assert_true(success, "Should set target window")
    
    -- Get initial state
    local initial_state = capture:getWindowState()
    assert_not_nil(initial_state, "Should get initial window state")
    
    -- Test state properties
    assert_true(type(initial_state.visible) == "boolean", "State should have visible property")
    assert_true(type(initial_state.minimized) == "boolean", "State should have minimized property")
    assert_true(type(initial_state.maximized) == "boolean", "State should have maximized property")
    assert_true(type(initial_state.capturable) == "boolean", "State should have capturable property")
    
    -- Test window change detection (initially should be false)
    local changed = capture:hasWindowChanged()
    assert_false(changed, "Window should not be changed initially")
end

-- Test handling of minimized windows
function tests.test_minimized_window_handling()
    local capture = WindowCapture:new()
    
    if not is_windows then
        -- Set up mock minimized window
        ffi_bindings.setMockWindows({
            {
                handle = "mock_minimized_window",
                title = "Minimized Window",
                visible = true,
                minimized = true,
                maximized = false,
                processId = 1234
            }
        })
    end
    
    -- Find minimized window
    local windows = capture:enumerateWindows(true)  -- Include all windows
    assert_not_nil(windows, "Should enumerate windows for minimized test")
    
    local minimized_window = nil
    
    for _, window in ipairs(windows) do
        if window.minimized then
            minimized_window = window
            break
        end
    end
    
    if minimized_window then
        local success = capture:setTargetWindow(minimized_window)
        assert_true(success, "Should be able to set minimized window as target")
        
        -- Try to capture minimized window (should fail)
        local bitmap, err = capture:captureWindow()
        assert_nil(bitmap, "Should not capture minimized window")
        assert_not_nil(err, "Should return error for minimized window")
        
        local state = capture:getWindowState()
        assert_not_nil(state, "Should get state for minimized window")
        assert_true(state.minimized, "State should show window is minimized")
        assert_false(state.capturable, "Minimized window should not be capturable")
    end
end

-- Test handling of hidden windows
function tests.test_hidden_window_handling()
    local capture = WindowCapture:new()
    
    if not is_windows then
        -- Set up mock hidden window
        ffi_bindings.setMockWindows({
            {
                handle = "hidden_window",
                title = "Hidden Window",
                visible = false,
                minimized = false,
                maximized = false,
                processId = 1234
            }
        })
    end
    
    -- Find hidden window
    local windows = capture:enumerateWindows(true)  -- Include all windows
    assert_not_nil(windows, "Should enumerate windows for hidden test")
    
    local hidden_window = nil
    
    for _, window in ipairs(windows) do
        if not window.visible then
            hidden_window = window
            break
        end
    end
    
    if hidden_window then
        local success = capture:setTargetWindow(hidden_window)
        assert_true(success, "Should be able to set hidden window as target")
        
        -- Try to capture hidden window (should fail)
        local bitmap, err = capture:captureWindow()
        assert_nil(bitmap, "Should not capture hidden window")
        assert_not_nil(err, "Should return error for hidden window")
        
        local state = capture:getWindowState()
        assert_not_nil(state, "Should get state for hidden window")
        assert_false(state.visible, "State should show window is not visible")
        assert_false(state.capturable, "Hidden window should not be capturable")
    end
end

-- Test automatic window tracking
function tests.test_automatic_window_tracking()
    local capture = WindowCapture:new()
    
    -- Ensure tracking is enabled
    capture:setTracking(true)
    
    if not is_windows then
        ffi_bindings.setMockWindows({
            {
                handle = "tracking_window",
                title = "Tracking Test Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            }
        })
    end
    
    -- Set target window
    local windows = capture:enumerateWindows(false)
    if #windows > 0 then
        local success = capture:setTargetWindow(windows[1])
        assert_true(success, "Should set target window for tracking test")
        
        -- Update window state multiple times
        for i = 1, 3 do
            local update_success = capture:updateWindowState()
            assert_true(update_success, "Should update window state successfully")
            
            local state = capture:getWindowState()
            assert_not_nil(state, "Should get window state after update")
        end
    end
end

-- Test capture accuracy with different window sizes
function tests.test_capture_accuracy_different_sizes()
    local capture = WindowCapture:new()
    
    if not is_windows then
        -- Set up mock windows with different sizes
        ffi_bindings.setMockWindows({
            {
                handle = "small_window",
                title = "Small Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            },
            {
                handle = "large_window", 
                title = "Large Window",
                visible = true,
                minimized = false,
                maximized = true,
                processId = 5678
            }
        })
    end
    
    local windows = capture:enumerateWindows(false)
    assert_not_nil(windows, "Should enumerate windows for capture accuracy test")
    
    for _, window in ipairs(windows) do
        if window.capturable then
            local success = capture:setTargetWindow(window)
            assert_true(success, "Should set window as target")
            
            -- Test capture
            local bitmap, width, height = capture:captureWindow()
            
            if bitmap then
                assert_not_nil(width, "Should return width")
                assert_not_nil(height, "Should return height")
                assert_true(width > 0, "Width should be positive")
                assert_true(height > 0, "Height should be positive")
                
                -- Test pixel data conversion
                local pixelData, w, h = capture:captureWindowPixelData()
                assert_not_nil(pixelData, "Should convert to pixel data")
                assert_equal(w, width, "Pixel data width should match")
                assert_equal(h, height, "Pixel data height should match")
            end
        end
    end
end

-- Test error recovery mechanisms
function tests.test_error_recovery()
    local capture = WindowCapture:new()
    
    -- Enable auto retry
    capture:setAutoRetry(true, 2)
    
    -- First get windows before enabling failure mode
    local windows = capture:enumerateWindows(false)
    assert_not_nil(windows, "Should enumerate windows for error recovery test")
    
    if not is_windows then
        -- Set up a window that will cause capture failures
        ffi_bindings.setMockWindows({
            {
                handle = "problematic_window",
                title = "Problematic Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            }
        })
        
        -- Re-enumerate after setting up problematic window
        windows = capture:enumerateWindows(false)
        assert_not_nil(windows, "Should enumerate windows after setup")
        
        -- Enable failure mode temporarily (only affects capture, not enumeration)
        ffi_bindings.setFailureMode(true)
    end
    
    if #windows > 0 then
        local success = capture:setTargetWindow(windows[1])
        assert_true(success, "Should set target window")
        
        -- Try to capture (should fail with mock failure mode)
        local bitmap, err = capture:captureWindow()
        if not is_windows then
            assert_nil(bitmap, "Should fail to capture in failure mode")
            assert_not_nil(err, "Should return error message")
            
            -- Check retry count
            assert_true(capture.retry_count > 0, "Should have incremented retry count")
            
            -- Disable failure mode and try again
            ffi_bindings.setFailureMode(false)
            
            -- Clear error and try again
            capture:clearError()
            bitmap, err = capture:captureWindow()
            assert_not_nil(bitmap, "Should succeed after clearing failure mode")
        end
    end
    
    -- Reset failure mode
    if not is_windows then
        ffi_bindings.setFailureMode(false)
    end
end

-- Test window enumeration filtering
function tests.test_window_enumeration_filtering()
    local capture = WindowCapture:new()
    
    if not is_windows then
        -- Set up various types of windows
        ffi_bindings.setMockWindows({
            {
                handle = "normal_window",
                title = "Normal Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            },
            {
                handle = "no_title_window",
                title = "",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 5678
            },
            {
                handle = "hidden_window",
                title = "Hidden Window",
                visible = false,
                minimized = false,
                maximized = false,
                processId = 9012
            }
        })
    end
    
    -- Test filtered enumeration (should exclude windows without titles)
    local filtered_windows = capture:enumerateWindows(false)
    assert_not_nil(filtered_windows, "Should return filtered windows")
    
    -- Test all windows enumeration
    local all_windows = capture:enumerateWindows(true)
    assert_not_nil(all_windows, "Should return all windows")
    
    -- All windows should be >= filtered windows
    assert_true(#all_windows >= #filtered_windows, "All windows should be >= filtered windows")
    
    -- Check that filtered windows have titles
    for _, window in ipairs(filtered_windows) do
        assert_not_nil(window.title, "Filtered window should have title")
        assert_true(window.title ~= "", "Filtered window title should not be empty")
    end
end

-- Test performance under load
function tests.test_performance_under_load()
    local capture = WindowCapture:new()
    
    -- Test rapid enumeration
    local start_time = os.clock()
    for i = 1, 10 do
        local windows = capture:enumerateWindows(false)
        assert_not_nil(windows, "Should enumerate windows in performance test")
    end
    local enumeration_time = os.clock() - start_time
    
    print(string.format("    10 enumerations took %.3f seconds", enumeration_time))
    assert_true(enumeration_time < 1.0, "10 enumerations should complete within 1 second")
    
    -- Test rapid state updates if we have a target
    local windows = capture:enumerateWindows(false)
    assert_not_nil(windows, "Should enumerate windows for performance test")
    
    if #windows > 0 then
        capture:setTargetWindow(windows[1])
        
        start_time = os.clock()
        for i = 1, 20 do
            capture:updateWindowState()
        end
        local update_time = os.clock() - start_time
        
        print(string.format("    20 state updates took %.3f seconds", update_time))
        assert_true(update_time < 0.5, "20 state updates should complete within 0.5 seconds")
    end
end

-- Test concurrent capture operations
function tests.test_concurrent_operations()
    -- Create multiple capture instances
    local capture1 = WindowCapture:new()
    local capture2 = WindowCapture:new()
    
    -- Both should be able to enumerate windows independently
    local windows1 = capture1:enumerateWindows(false)
    local windows2 = capture2:enumerateWindows(false)
    
    assert_not_nil(windows1, "First capture should enumerate windows")
    assert_not_nil(windows2, "Second capture should enumerate windows")
    
    -- Both should be able to set different targets
    if #windows1 > 0 then
        local success1 = capture1:setTargetWindow(windows1[1])
        assert_true(success1, "First capture should set target")
        
        if #windows2 > 0 then
            local success2 = capture2:setTargetWindow(windows2[1])
            assert_true(success2, "Second capture should set target")
            
            -- Both should maintain independent state
            local state1 = capture1:getWindowState()
            local state2 = capture2:getWindowState()
            
            assert_not_nil(state1, "First capture should have state")
            assert_not_nil(state2, "Second capture should have state")
        end
    end
end

-- Run all integration tests
local function run_all_tests()
    print("Starting Window Capture Integration Tests")
    print("=" .. string.rep("=", 60))
    
    for test_name, test_func in pairs(tests) do
        run_test(test_name, test_func)
    end
    
    print("=" .. string.rep("=", 60))
    print(string.format("Integration tests completed: %d/%d passed", passed_count, test_count))
    
    if passed_count == test_count then
        print("All integration tests PASSED! ✓")
        return true
    else
        print(string.format("%d integration tests FAILED! ✗", test_count - passed_count))
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_window_capture_integration%.lua$") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for external use
return {
    run_all_tests = run_all_tests,
    tests = tests
}