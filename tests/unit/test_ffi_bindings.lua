-- Unit tests for FFI bindings
local FFIBindings = require("src.ffi_bindings")

local TestFFIBindings = {}

-- Test helper function
local function assert_test(condition, message)
    if not condition then
        error("Test failed: " .. (message or "assertion failed"))
    end
    print("✓ " .. (message or "test passed"))
end

-- Test screen dimensions
function TestFFIBindings.test_getScreenDimensions()
    local width, height = FFIBindings.getScreenDimensions()
    
    assert_test(type(width) == "number", "Screen width should be a number")
    assert_test(type(height) == "number", "Screen height should be a number")
    assert_test(width > 0, "Screen width should be positive")
    assert_test(height > 0, "Screen height should be positive")
    assert_test(width >= 640, "Screen width should be at least 640 pixels")
    assert_test(height >= 480, "Screen height should be at least 480 pixels")
    
    print("Screen dimensions: " .. width .. "x" .. height)
end

-- Test virtual screen dimensions
function TestFFIBindings.test_getVirtualScreenDimensions()
    local virtual = FFIBindings.getVirtualScreenDimensions()
    
    assert_test(type(virtual) == "table", "Virtual screen info should be a table")
    assert_test(type(virtual.width) == "number", "Virtual screen width should be a number")
    assert_test(type(virtual.height) == "number", "Virtual screen height should be a number")
    assert_test(virtual.width > 0, "Virtual screen width should be positive")
    assert_test(virtual.height > 0, "Virtual screen height should be positive")
    
    print("Virtual screen: " .. virtual.width .. "x" .. virtual.height .. 
          " at (" .. virtual.left .. "," .. virtual.top .. ")")
end

-- Test window validation functions
function TestFFIBindings.test_windowValidation()
    local desktopHwnd = FFIBindings.getDesktopWindow()
    
    assert_test(FFIBindings.isWindowValid(desktopHwnd), "Desktop window should be valid")
    assert_test(FFIBindings.isWindowVisible(desktopHwnd), "Desktop window should be visible")
    assert_test(not FFIBindings.isWindowValid(nil), "Nil window should be invalid")
    
    print("Window validation tests completed successfully")
end

-- Test foreground window
function TestFFIBindings.test_getForegroundWindow()
    local hwnd = FFIBindings.getForegroundWindow()
    
    -- Foreground window might be nil in some cases, but if it exists, it should be valid
    if hwnd ~= nil then
        assert_test(FFIBindings.isWindowValid(hwnd), "Foreground window should be valid if it exists")
        local title = FFIBindings.getWindowTitle(hwnd)
        print("Foreground window title: " .. (title or "No title"))
    else
        print("No foreground window detected")
    end
end

-- Test desktop window handle
function TestFFIBindings.test_getDesktopWindow()
    local hwnd = FFIBindings.getDesktopWindow()
    
    assert_test(hwnd ~= nil, "Desktop window handle should not be nil")
    print("Desktop window handle obtained successfully")
end

-- Test window rectangle for desktop
function TestFFIBindings.test_getWindowRect()
    local desktopHwnd = FFIBindings.getDesktopWindow()
    local rect, err = FFIBindings.getWindowRect(desktopHwnd)
    
    assert_test(rect ~= nil, "Window rectangle should not be nil: " .. (err or ""))
    assert_test(type(rect.left) == "number", "Rectangle left should be a number")
    assert_test(type(rect.top) == "number", "Rectangle top should be a number")
    assert_test(type(rect.right) == "number", "Rectangle right should be a number")
    assert_test(type(rect.bottom) == "number", "Rectangle bottom should be a number")
    assert_test(rect.width > 0, "Rectangle width should be positive")
    assert_test(rect.height > 0, "Rectangle height should be positive")
    
    print("Desktop rectangle: " .. rect.left .. "," .. rect.top .. " " .. rect.width .. "x" .. rect.height)
end

-- Test screen capture (basic functionality)
function TestFFIBindings.test_captureScreen()
    -- Test small region capture to avoid memory issues
    local bitmap = FFIBindings.captureScreen(0, 0, 100, 100)
    
    assert_test(bitmap ~= nil, "Screen capture should return a bitmap handle")
    
    -- Clean up
    FFIBindings.deleteBitmap(bitmap)
    print("Screen capture test completed successfully")
end

-- Test bitmap to pixel data conversion
function TestFFIBindings.test_bitmapToPixelData()
    -- Capture a small region
    local bitmap = FFIBindings.captureScreen(0, 0, 50, 50)
    assert_test(bitmap ~= nil, "Screen capture should succeed for pixel data test")
    
    local pixelData = FFIBindings.bitmapToPixelData(bitmap, 50, 50)
    
    assert_test(pixelData ~= nil, "Pixel data conversion should succeed")
    assert_test(type(pixelData) == "string", "Pixel data should be a string")
    assert_test(#pixelData == 50 * 50 * 4, "Pixel data should have correct size (50x50x4 bytes)")
    
    -- Clean up
    FFIBindings.deleteBitmap(bitmap)
    print("Bitmap to pixel data conversion test completed successfully")
end

-- Test invalid window handle
function TestFFIBindings.test_invalidWindowHandle()
    local rect, err = FFIBindings.getWindowRect(nil)
    
    assert_test(rect == nil, "Invalid window handle should return nil")
    assert_test(err ~= nil, "Invalid window handle should return error message")
    print("Invalid window handle test completed: " .. err)
end

-- Test findWindow with non-existent window
function TestFFIBindings.test_findNonExistentWindow()
    local ffi = require("ffi")
    local hwnd = FFIBindings.findWindow("NonExistentWindowName12345")
    
    -- This should return nil (or 0) for non-existent windows
    assert_test(hwnd == nil or hwnd == ffi.cast("void*", 0), "Non-existent window should return nil or null handle")
    print("Find non-existent window test completed successfully")
end

-- Run all tests
function TestFFIBindings.runAllTests()
    print("=== Running FFI Bindings Tests ===")
    
    local tests = {
        TestFFIBindings.test_getScreenDimensions,
        TestFFIBindings.test_getVirtualScreenDimensions,
        TestFFIBindings.test_getDesktopWindow,
        TestFFIBindings.test_getWindowRect,
        TestFFIBindings.test_windowValidation,
        TestFFIBindings.test_getForegroundWindow,
        TestFFIBindings.test_captureScreen,
        TestFFIBindings.test_bitmapToPixelData,
        TestFFIBindings.test_invalidWindowHandle,
        TestFFIBindings.test_findNonExistentWindow
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ Test " .. i .. " failed: " .. err)
        end
    end
    
    print("\n=== Test Results ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    
    if failed == 0 then
        print("All tests passed! ✓")
    else
        print("Some tests failed! ✗")
    end
    
    return failed == 0
end

return TestFFIBindings