-- Test suite for DPI Awareness functionality
-- Tests DPI scaling, coordinate conversion, and high-DPI capture

-- Detect platform and use appropriate FFI bindings
local ffi_bindings
local is_windows = package.config:sub(1,1) == '\\'

if is_windows then
    ffi_bindings = require("src.ffi_bindings")
else
    -- Use mock bindings for non-Windows platforms
    ffi_bindings = require("tests.mock_ffi_bindings")
    print("Running DPI tests on non-Windows platform - using mock FFI bindings")
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

local function assert_close(actual, expected, tolerance, message)
    tolerance = tolerance or 0.01
    if math.abs(actual - expected) > tolerance then
        error(string.format("Assertion failed: %s\nExpected: %s (±%s)\nActual: %s", 
              message or "values should be close", tostring(expected), tostring(tolerance), tostring(actual)))
    end
end

local function run_test(name, test_func)
    test_count = test_count + 1
    print(string.format("Running DPI test: %s", name))
    
    local success, error_msg = pcall(test_func)
    if success then
        passed_count = passed_count + 1
        print(string.format("  ✓ PASSED: %s", name))
    else
        print(string.format("  ✗ FAILED: %s", name))
        print(string.format("    Error: %s", error_msg))
    end
end

-- Test DPI scaling detection
function tests.test_dpi_scaling_detection()
    local scaleX, scaleY = ffi_bindings.getDPIScaling()
    
    assert_not_nil(scaleX, "Should return X scale factor")
    assert_not_nil(scaleY, "Should return Y scale factor")
    assert_true(scaleX > 0, "X scale factor should be positive")
    assert_true(scaleY > 0, "Y scale factor should be positive")
    
    print(string.format("    Detected DPI scaling: %.2fx, %.2fy", scaleX, scaleY))
end

-- Test coordinate conversion functions
function tests.test_coordinate_conversion()
    -- Test logical to physical conversion
    local physical = ffi_bindings.convertLogicalToPhysical(100, 100, 800, 600)
    
    assert_not_nil(physical, "Should return physical coordinates")
    assert_not_nil(physical.x, "Should have x coordinate")
    assert_not_nil(physical.y, "Should have y coordinate")
    assert_not_nil(physical.width, "Should have width")
    assert_not_nil(physical.height, "Should have height")
    assert_not_nil(physical.scaleX, "Should have X scale factor")
    assert_not_nil(physical.scaleY, "Should have Y scale factor")
    
    -- Test physical to logical conversion (should be inverse)
    local logical = ffi_bindings.convertPhysicalToLogical(
        physical.x, physical.y, physical.width, physical.height
    )
    
    assert_close(logical.x, 100, 1, "X coordinate should convert back")
    assert_close(logical.y, 100, 1, "Y coordinate should convert back")
    assert_close(logical.width, 800, 1, "Width should convert back")
    assert_close(logical.height, 600, 1, "Height should convert back")
    
    print(string.format("    Logical (100,100,800x600) -> Physical (%d,%d,%dx%d)", 
          physical.x, physical.y, physical.width, physical.height))
end

-- Test DPI-aware window capture creation
function tests.test_dpi_aware_capture_creation()
    -- Create DPI-aware capture instance
    local capture = WindowCapture:new({ dpi_aware = true })
    
    assert_not_nil(capture, "Should create DPI-aware capture instance")
    assert_true(capture.dpi_aware, "Should be DPI aware")
    assert_true(capture.auto_dpi_setup, "Should have auto DPI setup enabled")
    
    -- Test DPI info retrieval
    local dpiInfo = capture:getDPIInfo()
    assert_not_nil(dpiInfo, "Should return DPI info")
    assert_true(dpiInfo.dpiAware, "Should report as DPI aware")
    assert_true(type(dpiInfo.scaleX) == "number", "Should have X scale factor")
    assert_true(type(dpiInfo.scaleY) == "number", "Should have Y scale factor")
    
    print(string.format("    DPI Info: %.2fx, %.2fy, aware=%s", 
          dpiInfo.scaleX, dpiInfo.scaleY, tostring(dpiInfo.dpiAware)))
end

-- Test DPI-aware window rectangle retrieval
function tests.test_dpi_aware_window_rect()
    if not is_windows then
        -- Set up mock window for testing
        ffi_bindings.setMockWindows({
            {
                handle = "dpi_test_window",
                title = "DPI Test Window",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234
            }
        })
    end
    
    -- Test regular window rectangle
    local hwnd = ffi_bindings.getDesktopWindow()
    local rect = ffi_bindings.getWindowRect(hwnd, false)
    
    assert_not_nil(rect, "Should get window rectangle")
    assert_not_nil(rect.width, "Should have width")
    assert_not_nil(rect.height, "Should have height")
    
    -- Test DPI-aware window rectangle
    local dpiRect = ffi_bindings.getWindowRect(hwnd, true)
    
    assert_not_nil(dpiRect, "Should get DPI-aware window rectangle")
    assert_not_nil(dpiRect.logical, "Should have logical coordinates")
    assert_not_nil(dpiRect.physical, "Should have physical coordinates")
    
    -- Physical dimensions should be larger than logical (assuming scaling > 1.0)
    local scaleX, scaleY = ffi_bindings.getDPIScaling()
    if scaleX > 1.0 then
        assert_true(dpiRect.physical.width >= dpiRect.logical.width, 
                   "Physical width should be >= logical width")
    end
    
    print(string.format("    Logical: %dx%d, Physical: %dx%d", 
          dpiRect.logical.width, dpiRect.logical.height,
          dpiRect.physical.width, dpiRect.physical.height))
end

-- Test DPI-aware window capture
function tests.test_dpi_aware_window_capture()
    local capture = WindowCapture:new({ dpi_aware = true })
    
    if not is_windows then
        -- Set up mock window for testing
        ffi_bindings.setMockWindows({
            {
                handle = "dpi_capture_window",
                title = "DPI Capture Window",
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
    
    if #windows > 0 then
        local success = capture:setTargetWindow(windows[1])
        assert_true(success, "Should set target window")
        
        -- Perform DPI-aware capture
        local result = capture:captureWindow()
        assert_not_nil(result, "Should capture window")
        
        if type(result) == "table" then
            assert_not_nil(result.bitmap, "Should have bitmap")
            assert_not_nil(result.width, "Should have width")
            assert_not_nil(result.height, "Should have height")
            assert_not_nil(result.logical, "Should have logical dimensions")
            
            -- Check if physical dimensions are provided (depends on scaling)
            local scaleX, scaleY = ffi_bindings.getDPIScaling()
            if scaleX > 1.0 then
                assert_not_nil(result.physical, "Should have physical dimensions")
                assert_true(result.width >= result.logical.width, 
                           "Capture width should be >= logical width")
            end
            
            print(string.format("    Captured: %dx%d (logical: %dx%d)", 
                  result.width, result.height,
                  result.logical.width, result.logical.height))
        end
    end
end

-- Test DPI-aware pixel data capture
function tests.test_dpi_aware_pixel_data()
    local capture = WindowCapture:new({ dpi_aware = true })
    
    if not is_windows then
        -- Set up mock window for testing
        ffi_bindings.setMockWindows({
            {
                handle = "dpi_pixel_window",
                title = "DPI Pixel Window",
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
    
    if #windows > 0 then
        local success = capture:setTargetWindow(windows[1])
        assert_true(success, "Should set target window")
        
        -- Capture pixel data
        local result = capture:captureWindowPixelData()
        assert_not_nil(result, "Should capture pixel data")
        
        if type(result) == "table" then
            assert_not_nil(result.data, "Should have pixel data")
            assert_not_nil(result.width, "Should have width")
            assert_not_nil(result.height, "Should have height")
            assert_not_nil(result.logical, "Should have logical dimensions")
            
            -- Verify data size matches dimensions
            local expectedSize = result.width * result.height * 4  -- 4 bytes per pixel
            assert_equal(string.len(result.data), expectedSize, "Pixel data size should match dimensions")
            
            print(string.format("    Pixel data: %dx%d, %d bytes", 
                  result.width, result.height, string.len(result.data)))
        end
    end
end

-- Test DPI configuration changes
function tests.test_dpi_configuration()
    local capture = WindowCapture:new({ dpi_aware = false })
    
    -- Initially not DPI aware
    assert_false(capture.dpi_aware, "Should not be DPI aware initially")
    
    -- Enable DPI awareness
    local success = capture:setDPIAware(true)
    assert_true(success, "Should enable DPI awareness")
    assert_true(capture.dpi_aware, "Should be DPI aware after enabling")
    
    -- Disable DPI awareness
    capture:setDPIAware(false)
    assert_false(capture.dpi_aware, "Should not be DPI aware after disabling")
    
    -- Test DPI info retrieval
    local dpiInfo = capture:getDPIInfo()
    assert_not_nil(dpiInfo, "Should get DPI info")
    assert_false(dpiInfo.dpiAware, "Should report as not DPI aware")
end

-- Test backward compatibility
function tests.test_backward_compatibility()
    -- Create regular (non-DPI-aware) capture instance
    local capture = WindowCapture:new()
    
    assert_false(capture.dpi_aware, "Should not be DPI aware by default")
    
    if not is_windows then
        -- Set up mock window for testing
        ffi_bindings.setMockWindows({
            {
                handle = "compat_window",
                title = "Compatibility Window",
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
    
    if #windows > 0 then
        local success = capture:setTargetWindow(windows[1])
        assert_true(success, "Should set target window")
        
        -- Capture should work in legacy mode
        local result = capture:captureWindow()
        assert_not_nil(result, "Should capture window in legacy mode")
        
        -- Should return table format even in legacy mode
        if type(result) == "table" then
            assert_not_nil(result.bitmap, "Should have bitmap")
            assert_not_nil(result.width, "Should have width")
            assert_not_nil(result.height, "Should have height")
        end
    end
end

-- Test process DPI awareness setting
function tests.test_process_dpi_awareness()
    -- Test setting process DPI aware
    local success = ffi_bindings.setProcessDPIAware()
    assert_true(success, "Should set process DPI aware")
    
    -- Test that it doesn't fail when called multiple times
    success = ffi_bindings.setProcessDPIAware()
    assert_true(success, "Should succeed when called multiple times")
end

-- Run all DPI tests
local function run_all_tests()
    print("Starting DPI Awareness Tests")
    print("=" .. string.rep("=", 50))
    
    for test_name, test_func in pairs(tests) do
        run_test(test_name, test_func)
    end
    
    print("=" .. string.rep("=", 50))
    print(string.format("DPI tests completed: %d/%d passed", passed_count, test_count))
    
    if passed_count == test_count then
        print("All DPI tests PASSED! ✓")
        return true
    else
        print(string.format("%d DPI tests FAILED! ✗", test_count - passed_count))
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_dpi_awareness%.lua$") then
    local success = run_all_tests()
    os.exit(success and 0 or 1)
end

-- Export for external use
return {
    run_all_tests = run_all_tests,
    tests = tests
}