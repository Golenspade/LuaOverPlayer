-- Mock FFI bindings for testing on non-Windows platforms
local MockFFIBindings = {}

-- Mock cursor state
local mock_cursor_position = {x = 150, y = 200}
local mock_cursor_visible = true
local mock_cursor_handle = 12345

-- Mock state - Default setup for backward compatibility
local mock_monitors = {
    {
        handle = "mock_monitor_1",
        left = 0, top = 0, right = 1920, bottom = 1080,
        width = 1920, height = 1080,
        workLeft = 0, workTop = 0, workRight = 1920, workBottom = 1040,
        workWidth = 1920, workHeight = 1040,
        isPrimary = true
    },
    {
        handle = "mock_monitor_2",
        left = 1920, top = 0, right = 3840, bottom = 1080,
        width = 1920, height = 1080,
        workLeft = 1920, workTop = 0, workRight = 3840, workBottom = 1040,
        workWidth = 1920, workHeight = 1040,
        isPrimary = false
    }
}

local failure_mode = false

-- Control functions for testing
function MockFFIBindings.setMockMonitors(monitors)
    mock_monitors = {}
    for i, monitor in ipairs(monitors) do
        local mock_monitor = {
            handle = "mock_monitor_" .. i,
            left = monitor.left,
            top = monitor.top,
            right = monitor.right,
            bottom = monitor.bottom,
            width = monitor.right - monitor.left,
            height = monitor.bottom - monitor.top,
            workLeft = monitor.workLeft or monitor.left,
            workTop = monitor.workTop or monitor.top,
            workRight = monitor.workRight or monitor.right,
            workBottom = monitor.workBottom or (monitor.bottom - 40),
            workWidth = (monitor.workRight or monitor.right) - (monitor.workLeft or monitor.left),
            workHeight = (monitor.workBottom or (monitor.bottom - 40)) - (monitor.workTop or monitor.top),
            isPrimary = monitor.isPrimary or false
        }
        table.insert(mock_monitors, mock_monitor)
    end
end

function MockFFIBindings.setFailureMode(enabled)
    failure_mode = enabled
end

-- Setup and cleanup functions for tests
function MockFFIBindings.setup()
    -- Reset to default state
    failure_mode = false
    -- Reset monitors to default
    MockFFIBindings.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}
    })
end

function MockFFIBindings.cleanup()
    -- Reset state
    failure_mode = false
end

-- Mock screen dimensions
function MockFFIBindings.getScreenDimensions()
    if failure_mode then
        return 0, 0
    end
    
    local primary = MockFFIBindings.getPrimaryMonitor()
    if primary then
        return primary.width, primary.height
    end
    return 1920, 1080
end

-- Mock virtual screen dimensions
function MockFFIBindings.getVirtualScreenDimensions()
    if failure_mode then
        return {width = 0, height = 0, left = 0, top = 0, right = 0, bottom = 0}
    end
    
    if #mock_monitors == 0 then
        return {width = 1920, height = 1080, left = 0, top = 0, right = 1920, bottom = 1080}
    end
    
    local minLeft, minTop = math.huge, math.huge
    local maxRight, maxBottom = -math.huge, -math.huge
    
    for _, monitor in ipairs(mock_monitors) do
        minLeft = math.min(minLeft, monitor.left)
        minTop = math.min(minTop, monitor.top)
        maxRight = math.max(maxRight, monitor.right)
        maxBottom = math.max(maxBottom, monitor.bottom)
    end
    
    return {
        width = maxRight - minLeft,
        height = maxBottom - minTop,
        left = minLeft,
        top = minTop,
        right = maxRight,
        bottom = maxBottom
    }
end

-- Mock monitor enumeration
function MockFFIBindings.enumerateMonitors()
    if failure_mode then
        return nil, "Mock API failure"
    end
    
    -- Return a copy of mock monitors
    local monitors = {}
    for _, monitor in ipairs(mock_monitors) do
        table.insert(monitors, {
            handle = monitor.handle,
            left = monitor.left,
            top = monitor.top,
            right = monitor.right,
            bottom = monitor.bottom,
            width = monitor.width,
            height = monitor.height,
            workLeft = monitor.workLeft,
            workTop = monitor.workTop,
            workRight = monitor.workRight,
            workBottom = monitor.workBottom,
            workWidth = monitor.workWidth,
            workHeight = monitor.workHeight,
            isPrimary = monitor.isPrimary
        })
    end
    
    return monitors
end

-- Mock primary monitor
function MockFFIBindings.getPrimaryMonitor()
    if failure_mode then
        return nil, "Mock API failure"
    end
    
    for _, monitor in ipairs(mock_monitors) do
        if monitor.isPrimary then
            return {
                handle = monitor.handle,
                left = monitor.left,
                top = monitor.top,
                right = monitor.right,
                bottom = monitor.bottom,
                width = monitor.width,
                height = monitor.height,
                workLeft = monitor.workLeft,
                workTop = monitor.workTop,
                workRight = monitor.workRight,
                workBottom = monitor.workBottom,
                workWidth = monitor.workWidth,
                workHeight = monitor.workHeight,
                isPrimary = monitor.isPrimary
            }
        end
    end
    
    -- Return first monitor if no primary found
    if #mock_monitors > 0 then
        local monitor = mock_monitors[1]
        return {
            handle = monitor.handle,
            left = monitor.left,
            top = monitor.top,
            right = monitor.right,
            bottom = monitor.bottom,
            width = monitor.width,
            height = monitor.height,
            workLeft = monitor.workLeft,
            workTop = monitor.workTop,
            workRight = monitor.workRight,
            workBottom = monitor.workBottom,
            workWidth = monitor.workWidth,
            workHeight = monitor.workHeight,
            isPrimary = true
        }
    end
    
    return nil, "No monitors available"
end

-- Mock window handle
function MockFFIBindings.findWindow(windowName)
    if windowName == "NonExistentWindowName12345" then
        return nil
    end
    return "mock_window_handle"
end

-- Mock desktop window
function MockFFIBindings.getDesktopWindow()
    return "mock_desktop_handle"
end

-- Mock window rectangle
function MockFFIBindings.getWindowRect(hwnd)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    return {
        left = 0,
        top = 0,
        right = 1920,
        bottom = 1080,
        width = 1920,
        height = 1080
    }
end

-- Mock client rectangle
function MockFFIBindings.getClientRect(hwnd)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    return {
        left = 0,
        top = 0,
        right = 800,
        bottom = 600,
        width = 800,
        height = 600
    }
end

-- Mock window validation
function MockFFIBindings.isWindowValid(hwnd)
    return hwnd ~= nil
end

function MockFFIBindings.isWindowVisible(hwnd)
    return hwnd ~= nil
end

-- Mock window title
function MockFFIBindings.getWindowTitle(hwnd)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    return "Mock Window Title"
end

-- Mock foreground window
function MockFFIBindings.getForegroundWindow()
    return "mock_foreground_window"
end

function MockFFIBindings.getActiveWindow()
    return "mock_active_window"
end

-- Mock window positioning
function MockFFIBindings.moveWindow(hwnd, x, y, width, height, repaint)
    return hwnd ~= nil
end

function MockFFIBindings.setWindowPos(hwnd, x, y, width, height, flags)
    return hwnd ~= nil
end

-- Mock screen capture functions
function MockFFIBindings.captureScreen(x, y, width, height)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    return "mock_bitmap_handle"
end

function MockFFIBindings.captureScreenRegion(x, y, width, height, monitorIndex)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    return "mock_bitmap_handle"
end

function MockFFIBindings.captureVirtualScreen()
    if failure_mode then
        return nil, "Mock capture failure"
    end
    return "mock_bitmap_handle"
end

function MockFFIBindings.captureMonitor(monitorIndex)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    
    if not monitorIndex or monitorIndex < 1 or monitorIndex > #mock_monitors then
        return nil, "Invalid monitor index"
    end
    
    return "mock_bitmap_handle"
end

-- Mock window capture
function MockFFIBindings.captureWindow(hwnd)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    return "mock_bitmap_handle", 800, 600
end

-- Mock bitmap to pixel data
function MockFFIBindings.bitmapToPixelData(bitmap, width, height)
    if failure_mode then
        return nil, "Mock conversion failure"
    end
    
    if bitmap == nil then
        return nil, "Invalid bitmap handle"
    end
    
    -- Return mock pixel data (RGBA format)
    width = width or 1920
    height = height or 1080
    local dataSize = width * height * 4
    return string.rep("\255\0\0\255", width * height) -- Red pixels
end

-- Mock window state functions
function MockFFIBindings.isWindowMinimized(hwnd)
    return hwnd == "mock_minimized_window"
end

function MockFFIBindings.isWindowMaximized(hwnd)
    return hwnd == "mock_maximized_window"
end

function MockFFIBindings.getWindowParent(hwnd)
    if hwnd == "mock_child_window" then
        return "mock_parent_window"
    end
    return nil
end

function MockFFIBindings.getWindowProcessId(hwnd)
    if hwnd == nil then
        return nil
    end
    return 1234  -- Mock process ID
end

-- Mock window enumeration
local mock_windows = {
    {
        handle = "mock_window_1",
        title = "Test Window 1",
        visible = true,
        minimized = false,
        maximized = false,
        processId = 1234
    },
    {
        handle = "mock_window_2", 
        title = "Test Window 2",
        visible = true,
        minimized = false,
        maximized = false,
        processId = 5678
    },
    {
        handle = "mock_window_3",
        title = "Hidden Window",
        visible = false,
        minimized = false,
        maximized = false,
        processId = 9012
    },
    {
        handle = "mock_minimized_window",
        title = "Minimized Window",
        visible = true,
        minimized = true,
        maximized = false,
        processId = 3456
    }
}

function MockFFIBindings.setMockWindows(windows)
    mock_windows = windows or {}
end

function MockFFIBindings.enumerateWindows(includeAll)
    -- Don't fail enumeration in failure mode, only capture operations
    -- if failure_mode then
    --     return nil, "Mock enumeration failure"
    -- end
    
    local windows = {}
    for _, window in ipairs(mock_windows) do
        -- Filter based on includeAll parameter
        if includeAll or (window.title and window.title ~= "" and not window.title:match("^%s*$")) then
            -- Add rect information for visible windows
            local windowInfo = {
                handle = window.handle,
                title = window.title,
                visible = window.visible,
                minimized = window.minimized,
                maximized = window.maximized,
                processId = window.processId
            }
            
            if window.visible then
                windowInfo.rect = {
                    left = 100,
                    top = 100,
                    right = 900,
                    bottom = 700,
                    width = 800,
                    height = 600
                }
            end
            
            table.insert(windows, windowInfo)
        end
    end
    
    return windows
end

function MockFFIBindings.findWindowsByTitle(pattern)
    if failure_mode then
        return nil, "Mock search failure"
    end
    
    if not pattern or pattern == "" then
        return nil, "Pattern cannot be empty"
    end
    
    local matches = {}
    for _, window in ipairs(mock_windows) do
        if window.title and string.find(window.title:lower(), pattern:lower()) then
            local windowInfo = {
                handle = window.handle,
                title = window.title,
                visible = window.visible,
                minimized = window.minimized,
                maximized = window.maximized,
                processId = window.processId
            }
            
            if window.visible then
                windowInfo.rect = {
                    left = 100,
                    top = 100,
                    right = 900,
                    bottom = 700,
                    width = 800,
                    height = 600
                }
            end
            
            table.insert(matches, windowInfo)
        end
    end
    
    return matches
end

function MockFFIBindings.getWindowByTitle(title)
    if failure_mode then
        return nil
    end
    
    if not title or title == "" then
        return nil
    end
    
    for _, window in ipairs(mock_windows) do
        if window.title == title then
            local windowInfo = {
                handle = window.handle,
                title = window.title,
                visible = window.visible,
                minimized = window.minimized,
                maximized = window.maximized,
                processId = window.processId
            }
            
            if window.visible then
                windowInfo.rect = {
                    left = 100,
                    top = 100,
                    right = 900,
                    bottom = 700,
                    width = 800,
                    height = 600
                }
            end
            
            return windowInfo
        end
    end
    
    return nil
end

-- Mock DPI awareness functions
function MockFFIBindings.setProcessDPIAware()
    return true  -- Always succeed in mock
end

function MockFFIBindings.getDPIScaling()
    -- Mock 150% scaling (common high DPI scenario)
    return 1.5, 1.5
end

function MockFFIBindings.convertLogicalToPhysical(x, y, width, height)
    local scaleX, scaleY = MockFFIBindings.getDPIScaling()
    
    return {
        x = math.floor(x * scaleX + 0.5),
        y = math.floor(y * scaleY + 0.5),
        width = math.floor(width * scaleX + 0.5),
        height = math.floor(height * scaleY + 0.5),
        scaleX = scaleX,
        scaleY = scaleY
    }
end

function MockFFIBindings.convertPhysicalToLogical(x, y, width, height)
    local scaleX, scaleY = MockFFIBindings.getDPIScaling()
    
    return {
        x = math.floor(x / scaleX + 0.5),
        y = math.floor(y / scaleY + 0.5),
        width = math.floor(width / scaleX + 0.5),
        height = math.floor(height / scaleY + 0.5),
        scaleX = scaleX,
        scaleY = scaleY
    }
end

-- Enhanced mock window rectangle with DPI support
function MockFFIBindings.getWindowRect(hwnd, dpiAware)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    local result = {
        left = 0,
        top = 0,
        right = 1920,
        bottom = 1080,
        width = 1920,
        height = 1080
    }
    
    -- If DPI aware, also provide physical coordinates
    if dpiAware then
        local physical = MockFFIBindings.convertLogicalToPhysical(
            result.left, result.top, result.width, result.height
        )
        result.physical = physical
        result.logical = {
            left = result.left,
            top = result.top,
            width = result.width,
            height = result.height
        }
    end
    
    return result
end

-- Enhanced mock window capture with DPI support
function MockFFIBindings.captureWindow(hwnd, dpiAware)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    -- Get window rectangle with DPI information
    local rect = MockFFIBindings.getWindowRect(hwnd, dpiAware)
    if not rect then
        return nil, "Failed to get window rectangle"
    end
    
    -- Determine capture dimensions
    local captureWidth, captureHeight
    if dpiAware and rect.physical then
        -- Use physical dimensions for DPI-aware capture
        captureWidth = rect.physical.width
        captureHeight = rect.physical.height
    else
        -- Use logical dimensions
        captureWidth = rect.width
        captureHeight = rect.height
    end
    
    -- Return mock result with DPI information
    local result = {
        bitmap = "mock_bitmap_handle",
        width = captureWidth,
        height = captureHeight,
        logical = {
            width = rect.width,
            height = rect.height
        }
    }
    
    if dpiAware and rect.physical then
        result.physical = {
            width = rect.physical.width,
            height = rect.physical.height
        }
        result.scaleX = rect.physical.scaleX
        result.scaleY = rect.physical.scaleY
    end
    
    return result
end

-- Backward compatible window capture (returns old format)
function MockFFIBindings.captureWindowLegacy(hwnd)
    local result = MockFFIBindings.captureWindow(hwnd, false)
    if type(result) == "table" and result.bitmap then
        return result.bitmap, result.width, result.height
    else
        return result  -- Error case
    end
end

-- Mock cursor capture functions
function MockFFIBindings.getCursorPosition()
    if failure_mode then
        return nil, "Mock cursor position failure"
    end
    return {x = mock_cursor_position.x, y = mock_cursor_position.y}
end

function MockFFIBindings.getCursorInfo()
    if failure_mode then
        return nil, "Mock cursor info failure"
    end
    
    return {
        visible = mock_cursor_visible,
        position = {x = mock_cursor_position.x, y = mock_cursor_position.y},
        handle = mock_cursor_handle
    }
end

function MockFFIBindings.getCurrentCursor()
    if failure_mode then
        return nil
    end
    return mock_cursor_handle
end

function MockFFIBindings.getCursorIconInfo(hCursor)
    if failure_mode then
        return nil, "Mock icon info failure"
    end
    
    if hCursor == nil then
        return nil, "Invalid cursor handle"
    end
    
    return {
        isIcon = false,
        hotspot = {x = 0, y = 0},
        maskBitmap = "mock_mask_bitmap",
        colorBitmap = "mock_color_bitmap"
    }
end

function MockFFIBindings.drawCursor(hdc, x, y, hCursor, width, height)
    if failure_mode then
        return false, "Mock draw cursor failure"
    end
    
    if hdc == nil or hCursor == nil then
        return false, "Invalid parameters"
    end
    
    return true  -- Mock success
end

function MockFFIBindings.captureScreenWithCursor(x, y, width, height)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    
    -- Return mock bitmap with cursor included
    return "mock_bitmap_with_cursor"
end

function MockFFIBindings.captureWindowWithCursor(hwnd, dpiAware)
    if failure_mode then
        return nil, "Mock capture failure"
    end
    
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    -- Get base window capture result
    local result = MockFFIBindings.captureWindow(hwnd, dpiAware)
    if type(result) == "table" and result.bitmap then
        -- Replace bitmap with cursor version
        result.bitmap = "mock_bitmap_with_cursor"
    end
    
    return result
end

-- Mock cursor state control functions for testing
function MockFFIBindings.setMockCursorPosition(x, y)
    mock_cursor_position.x = x
    mock_cursor_position.y = y
end

function MockFFIBindings.setMockCursorVisible(visible)
    mock_cursor_visible = visible
end

function MockFFIBindings.setMockCursorHandle(handle)
    mock_cursor_handle = handle
end

-- Mock cleanup
function MockFFIBindings.deleteBitmap(bitmap)
    -- No-op for mock
end

return MockFFIBindings