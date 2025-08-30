-- Window Capture Module
-- Provides window enumeration, selection, and capture functionality
-- with automatic window tracking and state handling

-- Use mock bindings for testing if available
local ffi_bindings
local success, mock_bindings = pcall(require, "tests.mock_ffi_bindings")
if success and _G.TESTING_MODE then
    ffi_bindings = mock_bindings
else
    ffi_bindings = require("src.ffi_bindings")
end

local AdvancedCaptureFeatures = require("src.advanced_capture_features")

local WindowCapture = {}
WindowCapture.__index = WindowCapture

-- Create new window capture instance
function WindowCapture:new(options)
    options = options or {}
    
    local instance = setmetatable({
        target_window = nil,
        last_rect = nil,
        tracking_enabled = true,
        capture_borders = false,
        auto_retry = true,
        retry_count = 0,
        max_retries = 3,
        last_error = nil,
        dpi_aware = options.dpi_aware or false,
        auto_dpi_setup = options.auto_dpi_setup ~= false,  -- Default to true
        
        -- Advanced features integration
        advanced_features = AdvancedCaptureFeatures:new({
            cursor_capture = options.cursor_capture,
            hotkeys_enabled = options.hotkeys_enabled,
            toggle_key = options.toggle_key,
            area_select_key = options.area_select_key
        }),
        cursor_capture_enabled = options.cursor_capture or false
    }, self)
    
    -- Automatically set process DPI aware if requested
    if instance.auto_dpi_setup and instance.dpi_aware then
        local success = ffi_bindings.setProcessDPIAware()
        if not success then
            instance.last_error = "Failed to set process DPI aware"
        end
    end
    
    return instance
end

-- Enumerate all available windows
function WindowCapture:enumerateWindows(includeAll)
    includeAll = includeAll or false
    local windows, err = ffi_bindings.enumerateWindows(includeAll)
    
    if not windows then
        self.last_error = err
        return nil, err
    end
    
    -- Filter out system windows and add additional metadata
    local filtered = {}
    for _, window in ipairs(windows) do
        -- Skip windows with very small dimensions (likely system windows)
        if window.rect and window.rect.width > 50 and window.rect.height > 50 then
            -- Add capture status
            window.capturable = self:_isWindowCapturable(window.handle)
            table.insert(filtered, window)
        elseif not window.rect and window.visible then
            -- Include visible windows without rect (might be special windows)
            window.capturable = self:_isWindowCapturable(window.handle)
            table.insert(filtered, window)
        end
    end
    
    return filtered
end

-- Find windows by title pattern
function WindowCapture:findWindowsByTitle(pattern)
    if not pattern or pattern == "" then
        return nil, "Pattern cannot be empty"
    end
    
    local windows, err = ffi_bindings.findWindowsByTitle(pattern)
    if not windows then
        self.last_error = err
        return nil, err
    end
    
    -- Add capture status to each window
    for _, window in ipairs(windows) do
        window.capturable = self:_isWindowCapturable(window.handle)
    end
    
    return windows
end

-- Get window by exact title
function WindowCapture:getWindowByTitle(title)
    if not title or title == "" then
        return nil, "Title cannot be empty"
    end
    
    local window = ffi_bindings.getWindowByTitle(title)
    if not window then
        self.last_error = "Window not found: " .. title
        return nil, self.last_error
    end
    
    window.capturable = self:_isWindowCapturable(window.handle)
    return window
end

-- Set target window for capture
function WindowCapture:setTargetWindow(window)
    if type(window) == "string" then
        -- If string provided, treat as window title
        local found_window, err = self:getWindowByTitle(window)
        if not found_window then
            return false, err
        end
        window = found_window
    elseif type(window) == "table" and window.handle then
        -- Window object provided
        -- Validate the window still exists
        if not ffi_bindings.isWindowValid(window.handle) then
            return false, "Window handle is no longer valid"
        end
    else
        return false, "Invalid window parameter"
    end
    
    self.target_window = window
    self.last_rect = window.rect
    self.retry_count = 0
    self.last_error = nil
    
    return true
end

-- Get current target window
function WindowCapture:getTargetWindow()
    return self.target_window
end

-- Update target window state
function WindowCapture:updateWindowState()
    if not self.target_window then
        return false, "No target window set"
    end
    
    local hwnd = self.target_window.handle
    
    -- Check if window still exists
    if not ffi_bindings.isWindowValid(hwnd) then
        self.last_error = "Target window no longer exists"
        return false, self.last_error
    end
    
    -- Update window properties
    self.target_window.visible = ffi_bindings.isWindowVisible(hwnd)
    self.target_window.minimized = ffi_bindings.isWindowMinimized(hwnd)
    self.target_window.maximized = ffi_bindings.isWindowMaximized(hwnd)
    self.target_window.title = ffi_bindings.getWindowTitle(hwnd)
    
    -- Update rectangle if window is visible
    if self.target_window.visible and not self.target_window.minimized then
        local rect = ffi_bindings.getWindowRect(hwnd)
        if rect then
            self.target_window.rect = rect
            self.last_rect = rect
        end
    end
    
    return true
end

-- Capture the target window
function WindowCapture:captureWindow()
    if not self.target_window then
        return nil, "No target window set"
    end
    
    -- Update window state first
    local success, err = self:updateWindowState()
    if not success then
        return nil, err
    end
    
    local hwnd = self.target_window.handle
    
    -- Handle minimized windows
    if self.target_window.minimized then
        if self.auto_retry and self.retry_count < self.max_retries then
            self.retry_count = self.retry_count + 1
            self.last_error = "Window is minimized (retry " .. self.retry_count .. "/" .. self.max_retries .. ")"
            return nil, self.last_error
        else
            return nil, "Cannot capture minimized window"
        end
    end
    
    -- Handle hidden windows
    if not self.target_window.visible then
        return nil, "Cannot capture hidden window"
    end
    
    -- Perform the capture with DPI awareness and cursor support
    local result
    if self.dpi_aware then
        if self.cursor_capture_enabled then
            result = ffi_bindings.captureWindowWithCursor(hwnd, true)
        else
            result = ffi_bindings.captureWindow(hwnd, true)
        end
    else
        -- Use legacy capture for backward compatibility
        if self.cursor_capture_enabled then
            result = ffi_bindings.captureWindowWithCursor(hwnd, false)
        else
            local bitmap, width, height = ffi_bindings.captureWindowLegacy(hwnd)
            if bitmap then
                result = {
                    bitmap = bitmap,
                    width = width,
                    height = height,
                    logical = { width = width, height = height }
                }
            else
                result = bitmap  -- Error message
            end
        end
    end
    
    if not result or (type(result) == "string") then
        self.retry_count = self.retry_count + 1
        self.last_error = "Failed to capture window: " .. (result or "unknown error")
        
        if self.auto_retry and self.retry_count < self.max_retries then
            return nil, self.last_error
        else
            return nil, self.last_error
        end
    end
    
    -- Reset retry count on successful capture
    self.retry_count = 0
    self.last_error = nil
    
    return result
end

-- Capture window and convert to pixel data
function WindowCapture:captureWindowPixelData()
    local result = self:captureWindow()
    if not result or type(result) == "string" then
        return nil, result  -- Error message
    end
    
    local bitmap, width, height
    if type(result) == "table" then
        bitmap = result.bitmap
        width = result.width
        height = result.height
    else
        -- Legacy format (shouldn't happen with new code, but just in case)
        bitmap = result
        width = select(2, self:captureWindow())
        height = select(3, self:captureWindow())
    end
    
    local pixelData = ffi_bindings.bitmapToPixelData(bitmap, width, height)
    ffi_bindings.deleteBitmap(bitmap)  -- Clean up bitmap
    
    if not pixelData then
        return nil, "Failed to convert bitmap to pixel data"
    end
    
    -- Return pixel data with DPI information if available
    if type(result) == "table" then
        return {
            data = pixelData,
            width = width,
            height = height,
            logical = result.logical,
            physical = result.physical,
            scaleX = result.scaleX,
            scaleY = result.scaleY
        }
    else
        return pixelData, width, height
    end
end

-- Check if window moved or resized
function WindowCapture:hasWindowChanged()
    if not self.target_window or not self.last_rect then
        return false
    end
    
    local success = self:updateWindowState()
    if not success then
        return true  -- Consider changed if we can't update state
    end
    
    local current_rect = self.target_window.rect
    if not current_rect then
        return true  -- Consider changed if no current rect
    end
    
    -- Compare rectangles
    return (current_rect.left ~= self.last_rect.left or
            current_rect.top ~= self.last_rect.top or
            current_rect.width ~= self.last_rect.width or
            current_rect.height ~= self.last_rect.height)
end

-- Get window state information
function WindowCapture:getWindowState()
    if not self.target_window then
        return nil, "No target window set"
    end
    
    self:updateWindowState()
    
    return {
        title = self.target_window.title,
        visible = self.target_window.visible,
        minimized = self.target_window.minimized,
        maximized = self.target_window.maximized,
        rect = self.target_window.rect,
        capturable = self:_isWindowCapturable(self.target_window.handle),
        changed = self:hasWindowChanged(),
        processId = self.target_window.processId
    }
end

-- Enable/disable automatic window tracking
function WindowCapture:setTracking(enabled)
    self.tracking_enabled = enabled
end

-- Enable/disable border capture
function WindowCapture:setBorderCapture(enabled)
    self.capture_borders = enabled
end

-- Enable/disable automatic retry on failure
function WindowCapture:setAutoRetry(enabled, maxRetries)
    self.auto_retry = enabled
    self.max_retries = maxRetries or 3
end

-- Enable/disable DPI awareness
function WindowCapture:setDPIAware(enabled)
    self.dpi_aware = enabled
    
    -- Set process DPI aware if enabling
    if enabled and self.auto_dpi_setup then
        local success = ffi_bindings.setProcessDPIAware()
        if not success then
            self.last_error = "Failed to set process DPI aware"
            return false
        end
    end
    
    return true
end

-- Get current DPI scaling information
function WindowCapture:getDPIInfo()
    local scaleX, scaleY = ffi_bindings.getDPIScaling()
    return {
        scaleX = scaleX,
        scaleY = scaleY,
        dpiAware = self.dpi_aware,
        autoSetup = self.auto_dpi_setup
    }
end

-- Get last error message
function WindowCapture:getLastError()
    return self.last_error
end

-- Reset error state
function WindowCapture:clearError()
    self.last_error = nil
    self.retry_count = 0
end

-- Advanced Features Integration (Requirements 2.2, 5.4)

-- Enable/disable cursor capture
function WindowCapture:setCursorCapture(enabled)
    self.cursor_capture_enabled = enabled
    return self.advanced_features:setCursorCapture(enabled)
end

-- Register hotkey callback
function WindowCapture:registerHotkeyCallback(action, callback)
    return self.advanced_features:registerHotkeyCallback(action, callback)
end

-- Update hotkeys (should be called from main update loop)
function WindowCapture:updateHotkeys(pressed_keys)
    return self.advanced_features:updateHotkeys(pressed_keys)
end

-- Set hotkey binding
function WindowCapture:setHotkeyBinding(action, binding)
    return self.advanced_features:setHotkeyBinding(action, binding)
end

-- Get advanced features configuration
function WindowCapture:getAdvancedConfiguration()
    return self.advanced_features:getConfiguration()
end

-- Initialize advanced features
function WindowCapture:initializeAdvancedFeatures()
    return self.advanced_features:initialize()
end

-- Private helper functions

-- Check if a window can be captured
function WindowCapture:_isWindowCapturable(hwnd)
    if not ffi_bindings.isWindowValid(hwnd) then
        return false
    end
    
    -- Check if window is visible
    if not ffi_bindings.isWindowVisible(hwnd) then
        return false
    end
    
    -- Check if window is minimized
    if ffi_bindings.isWindowMinimized(hwnd) then
        return false
    end
    
    -- Check if window has valid dimensions
    local rect = ffi_bindings.getWindowRect(hwnd)
    if not rect or rect.width <= 0 or rect.height <= 0 then
        return false
    end
    
    -- Additional checks could be added here (e.g., window class, style, etc.)
    
    return true
end

return WindowCapture