-- Test suite for Window Capture functionality
-- Tests window enumeration, selection, capture, and state tracking

-- Detect platform and use appropriate FFI bindings
local ffi_bindings
local is_windows = package.config:sub(1,1) == '\\'

if is_windows then
    ffi_bindings = require("src.ffi_bindings")
else
    -- Use mock bindings for non-Windows platforms
    ffi_bindings = require("tests.mock_ffi_bindings")
    print("Running on non-Windows platform - using mock FFI bindings")
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

local function run_test(name, test_func)
    test_count = test_count + 1
    print(string.format("Running test: %s", name))
    
    local success, error_msg = pcall(test_func)
    if success then
        passed_count = passed_count + 1
        print(string.format("  ✓ PASSED: %s", name))
    else
        print(string.format("  ✗ FAILED: %s", name))
        print(string.format("    Error: %s", error_msg))
    end
end

-- Test window capture creation
function tests.test_window_capture_creation()
    local capture = WindowCapture:new()
    assert_not_nil(capture, "WindowCapture instance should be created")
    assert_nil(capture.target_window, "Target window should be nil initially")
    assert_true(capture.tracking_enabled, "Tracking should be enabled by default")
    assert_false(capture.capture_borders, "Border capture should be disabled by default")
    assert_true(capture.auto_retry, "Auto retry should be enabled by default")
    assert_equal(capture.max_retries, 3, "Max retries should be 3 by default")
end

-- Test window enumeration
function tests.test_window_enumeration()
    local capture = WindowCapture:new()
    
    -- Test basic enumeration
    local windows = capture:enumerateWindows(false)
    assert_not_nil(windows, "Should return windows list")
    assert_true(type(windows) == "table", "Windows should be a table")
    
    -- Each window should have required properties
    if #windows > 0 then
        local window = windows[1]
        assert_not_nil(window.handle, "Window should have handle")
        assert_not_nil(window.title, "Window should have title")
        assert_true(type(window.visible) == "boolean", "Window should have visible property")
        assert_true(type(window.capturable) == "boolean", "Window should have capturable property")
    end
end

-- Test window enumeration with all windows
function tests.test_window_enumeration_all()
    local capture = WindowCapture:new()
    
    local windows_filtered = capture:enumerateWindows(false)
    local windows_all = capture:enumerateWindows(true)
    
    assert_not_nil(windows_filtered, "Should return filtered windows list")
    assert_not_nil(windows_all, "Should return all windows list")
    
    -- All windows list should typically be larger or equal
    assert_true(#windows_all >= #windows_filtered, "All windows should be >= filtered windows")
end

-- Test finding windows by title
function tests.test_find_windows_by_title()
    local capture = WindowCapture:new()
    
    -- Test with empty pattern (should fail)
    local windows, err = capture:findWindowsByTitle("")
    assert_nil(windows, "Should fail with empty pattern")
    assert_not_nil(err, "Should return error message")
    
    -- Test with common window pattern
    windows = capture:findWindowsByTitle("explorer")
    -- Note: This might not find anything depending on system state
    -- Just verify it returns a table or nil without error
    assert_true(windows == nil or type(windows) == "table", "Should return table or nil")
end

-- Test getting window by exact title
function tests.test_get_window_by_title()
    local capture = WindowCapture:new()
    
    -- Test with empty title (should fail)
    local window, err = capture:getWindowByTitle("")
    assert_nil(window, "Should fail with empty title")
    assert_not_nil(err, "Should return error message")
    
    -- Test with non-existent window
    window, err = capture:getWindowByTitle("NonExistentWindow12345")
    assert_nil(window, "Should not find non-existent window")
    assert_not_nil(err, "Should return error message")
end

-- Test setting target window
function tests.test_set_target_window()
    local capture = WindowCapture:new()
    
    -- Test with invalid input
    local success, err = capture:setTargetWindow(nil)
    assert_false(success, "Should fail with nil window")
    assert_not_nil(err, "Should return error message")
    
    success, err = capture:setTargetWindow({})
    assert_false(success, "Should fail with empty table")
    assert_not_nil(err, "Should return error message")
    
    -- Test with non-existent window title
    success, err = capture:setTargetWindow("NonExistentWindow12345")
    assert_false(success, "Should fail with non-existent window")
    assert_not_nil(err, "Should return error message")
end

-- Test window state updates
function tests.test_window_state_update()
    local capture = WindowCapture:new()
    
    -- Test without target window
    local success, err = capture:updateWindowState()
    assert_false(success, "Should fail without target window")
    assert_not_nil(err, "Should return error message")
    
    -- Test getting window state without target
    local state, err2 = capture:getWindowState()
    assert_nil(state, "Should not return state without target")
    assert_not_nil(err2, "Should return error message")
end

-- Test window capture without target
function tests.test_capture_without_target()
    local capture = WindowCapture:new()
    
    local bitmap, err = capture:captureWindow()
    assert_nil(bitmap, "Should not capture without target window")
    assert_not_nil(err, "Should return error message")
    
    local pixelData, err2 = capture:captureWindowPixelData()
    assert_nil(pixelData, "Should not capture pixel data without target")
    assert_not_nil(err2, "Should return error message")
end

-- Test configuration methods
function tests.test_configuration_methods()
    local capture = WindowCapture:new()
    
    -- Test tracking configuration
    capture:setTracking(false)
    assert_false(capture.tracking_enabled, "Tracking should be disabled")
    
    capture:setTracking(true)
    assert_true(capture.tracking_enabled, "Tracking should be enabled")
    
    -- Test border capture configuration
    capture:setBorderCapture(true)
    assert_true(capture.capture_borders, "Border capture should be enabled")
    
    capture:setBorderCapture(false)
    assert_false(capture.capture_borders, "Border capture should be disabled")
    
    -- Test auto retry configuration
    capture:setAutoRetry(false, 5)
    assert_false(capture.auto_retry, "Auto retry should be disabled")
    assert_equal(capture.max_retries, 5, "Max retries should be 5")
    
    capture:setAutoRetry(true, 10)
    assert_true(capture.auto_retry, "Auto retry should be enabled")
    assert_equal(capture.max_retries, 10, "Max retries should be 10")
end

-- Test error handling
function tests.test_error_handling()
    local capture = WindowCapture:new()
    
    -- Initially no error
    assert_nil(capture:getLastError(), "Should have no error initially")
    
    -- Trigger an error
    capture:setTargetWindow("NonExistentWindow12345")
    assert_not_nil(capture:getLastError(), "Should have error after failed operation")
    
    -- Clear error
    capture:clearError()
    assert_nil(capture:getLastError(), "Error should be cleared")
    assert_equal(capture.retry_count, 0, "Retry count should be reset")
end

-- Test window change detection
function tests.test_window_change_detection()
    local capture = WindowCapture:new()
    
    -- Test without target window
    local changed = capture:hasWindowChanged()
    assert_false(changed, "Should not detect change without target window")
end

-- Integration test with real desktop window
function tests.test_desktop_window_integration()
    local capture = WindowCapture:new()
    
    -- Try to get desktop window (should always exist)
    local desktop_hwnd = ffi_bindings.getDesktopWindow()
    assert_not_nil(desktop_hwnd, "Desktop window should exist")
    
    -- Create a mock window object for desktop
    local desktop_window = {
        handle = desktop_hwnd,
        title = "Desktop",
        visible = true,
        minimized = false,
        maximized = false,
        rect = ffi_bindings.getWindowRect(desktop_hwnd)
    }
    
    if desktop_window.rect then
        local success = capture:setTargetWindow(desktop_window)
        assert_true(success, "Should be able to set desktop as target")
        
        local target = capture:getTargetWindow()
        assert_not_nil(target, "Should have target window")
        assert_equal(target.handle, desktop_hwnd, "Target should be desktop window")
        
        -- Test state update
        success = capture:updateWindowState()
        assert_true(success, "Should be able to update desktop window state")
        
        local state = capture:getWindowState()
        assert_not_nil(state, "Should get window state")
        assert_true(type(state.visible) == "boolean", "State should have visible property")
    end
end

-- Test FFI bindings integration
function tests.test_ffi_bindings_integration()
    -- Test window enumeration through FFI
    local windows = ffi_bindings.enumerateWindows(false)
    assert_not_nil(windows, "FFI should enumerate windows")
    assert_true(type(windows) == "table", "Windows should be a table")
    
    -- Test desktop window access
    local desktop = ffi_bindings.getDesktopWindow()
    assert_not_nil(desktop, "Should get desktop window handle")
    
    local is_valid = ffi_bindings.isWindowValid(desktop)
    assert_true(is_valid, "Desktop window should be valid")
    
    local is_visible = ffi_bindings.isWindowVisible(desktop)
    assert_true(is_visible, "Desktop window should be visible")
end

-- Performance test for window enumeration
function tests.test_enumeration_performance()
    local capture = WindowCapture:new()
    
    local start_time = os.clock()
    local windows = capture:enumerateWindows(false)
    local end_time = os.clock()
    
    local duration = end_time - start_time
    assert_true(duration < 1.0, "Window enumeration should complete within 1 second")
    
    print(string.format("    Window enumeration took %.3f seconds", duration))
    if windows then
        print(string.format("    Found %d windows", #windows))
    end
end

-- Test memory cleanup
function tests.test_memory_cleanup()
    local capture = WindowCapture:new()
    
    -- Test that we can create and destroy multiple instances
    for i = 1, 10 do
        local temp_capture = WindowCapture:new()
        temp_capture:enumerateWindows(false)
        temp_capture = nil
    end
    
    -- Force garbage collection
    collectgarbage("collect")
    
    -- Should still be able to use original capture
    local windows = capture:enumerateWindows(false)
    assert_true(windows == nil or type(windows) == "table", "Should still work after cleanup")
end

-- Run all tests
local function run_all_tests()
    print("Starting Window Capture Tests")
    print("=" .. string.rep("=", 50))
    
    for test_name, test_func in pairs(tests) do
        run_test(test_name, test_func)
    end
    
    print("=" .. string.rep("=", 50))
    print(string.format("Tests completed: %d/%d passed", passed_count, test_count))
    
    if passed_count == test_count then
        print("All tests PASSED! ✓")
        return true
    else
        print(string.format("%d tests FAILED! ✗", test_count - passed_count))
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_window_capture%.lua$") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for external use
return {
    run_all_tests = run_all_tests,
    tests = tests
}