-- Screen Capture Module
-- Implements screen capture functionality with multi-monitor support and configurable regions

-- Use mock bindings for testing if available
local ffi_bindings
local success, mock_bindings = pcall(require, "tests.mock_ffi_bindings")
if success and _G.TESTING_MODE then
    ffi_bindings = mock_bindings
else
    ffi_bindings = require("src.ffi_bindings")
end

local AdvancedCaptureFeatures = require("src.advanced_capture_features")

local ScreenCapture = {}
ScreenCapture.__index = ScreenCapture

-- Capture modes
local CAPTURE_MODES = {
    FULL_SCREEN = "FULL_SCREEN",
    CUSTOM_REGION = "CUSTOM_REGION", 
    MONITOR = "MONITOR",
    VIRTUAL_SCREEN = "VIRTUAL_SCREEN"
}

function ScreenCapture:new(options)
    options = options or {}
    
    return setmetatable({
        mode = CAPTURE_MODES.FULL_SCREEN,
        region = {x = 0, y = 0, width = nil, height = nil},
        monitor_index = 1,
        monitors = {},
        last_error = nil,
        
        -- Advanced features integration
        advanced_features = AdvancedCaptureFeatures:new({
            cursor_capture = options.cursor_capture,
            hotkeys_enabled = options.hotkeys_enabled,
            toggle_key = options.toggle_key,
            area_select_key = options.area_select_key
        }),
        cursor_capture_enabled = options.cursor_capture or false
    }, self)
end

-- Initialize and enumerate monitors
function ScreenCapture:initialize()
    local monitors, err = ffi_bindings.enumerateMonitors()
    if not monitors then
        self.last_error = err or "Failed to enumerate monitors"
        return false, self.last_error
    end
    
    self.monitors = monitors
    
    -- Initialize advanced features
    local success = self.advanced_features:initialize()
    if not success then
        print("Warning: Failed to initialize advanced capture features")
    end
    
    return true
end

-- Get available monitors
function ScreenCapture:getMonitors()
    if #self.monitors == 0 then
        self:initialize()
    end
    return self.monitors
end

-- Set capture mode
function ScreenCapture:setMode(mode)
    if not CAPTURE_MODES[mode:upper()] then
        self.last_error = "Invalid capture mode: " .. tostring(mode)
        return false, self.last_error
    end
    
    self.mode = CAPTURE_MODES[mode:upper()]
    return true
end

-- Set custom capture region
function ScreenCapture:setRegion(x, y, width, height)
    if type(x) ~= "number" or type(y) ~= "number" or 
       type(width) ~= "number" or type(height) ~= "number" then
        self.last_error = "Region coordinates must be numbers"
        return false, self.last_error
    end
    
    if width <= 0 or height <= 0 then
        self.last_error = "Region width and height must be positive"
        return false, self.last_error
    end
    
    self.region = {x = x, y = y, width = width, height = height}
    self.mode = CAPTURE_MODES.CUSTOM_REGION
    return true
end

-- Set monitor to capture
function ScreenCapture:setMonitor(index)
    if type(index) ~= "number" or index < 1 then
        self.last_error = "Monitor index must be a positive number"
        return false, self.last_error
    end
    
    -- Ensure monitors are enumerated first
    if #self.monitors == 0 then
        local success, err = self:initialize()
        if not success then
            self.last_error = err or "Failed to initialize monitors"
            return false, self.last_error
        end
    end
    
    if index > #self.monitors then
        self.last_error = "Monitor index " .. index .. " exceeds available monitors (" .. #self.monitors .. ")"
        return false, self.last_error
    end
    
    self.monitor_index = index
    self.mode = CAPTURE_MODES.MONITOR
    return true
end

-- Get capture region info based on current mode
function ScreenCapture:getCaptureInfo()
    local info = {
        mode = self.mode,
        x = 0,
        y = 0,
        width = 0,
        height = 0
    }
    
    if self.mode == CAPTURE_MODES.FULL_SCREEN then
        local primary = ffi_bindings.getPrimaryMonitor()
        if primary then
            info.x = primary.left
            info.y = primary.top
            info.width = primary.width
            info.height = primary.height
        else
            info.width, info.height = ffi_bindings.getScreenDimensions()
        end
        
    elseif self.mode == CAPTURE_MODES.CUSTOM_REGION then
        info.x = self.region.x
        info.y = self.region.y
        info.width = self.region.width
        info.height = self.region.height
        
    elseif self.mode == CAPTURE_MODES.MONITOR then
        if #self.monitors == 0 then
            self:initialize()
        end
        
        local monitor = self.monitors[self.monitor_index]
        if monitor then
            info.x = monitor.left
            info.y = monitor.top
            info.width = monitor.width
            info.height = monitor.height
        end
        
    elseif self.mode == CAPTURE_MODES.VIRTUAL_SCREEN then
        local virtual = ffi_bindings.getVirtualScreenDimensions()
        info.x = virtual.left
        info.y = virtual.top
        info.width = virtual.width
        info.height = virtual.height
    end
    
    return info
end

-- Capture screen based on current configuration
function ScreenCapture:capture()
    self.last_error = nil
    
    local bitmap, width, height
    
    if self.mode == CAPTURE_MODES.FULL_SCREEN then
        local primary = ffi_bindings.getPrimaryMonitor()
        if primary then
            if self.cursor_capture_enabled then
                bitmap = ffi_bindings.captureScreenWithCursor(primary.left, primary.top, primary.width, primary.height)
            else
                bitmap = ffi_bindings.captureScreen(primary.left, primary.top, primary.width, primary.height)
            end
            width, height = primary.width, primary.height
        else
            if self.cursor_capture_enabled then
                bitmap = ffi_bindings.captureScreenWithCursor()
            else
                bitmap = ffi_bindings.captureScreen()
            end
            width, height = ffi_bindings.getScreenDimensions()
        end
        
    elseif self.mode == CAPTURE_MODES.CUSTOM_REGION then
        if self.cursor_capture_enabled then
            bitmap = ffi_bindings.captureScreenWithCursor(self.region.x, self.region.y, self.region.width, self.region.height)
        else
            bitmap = ffi_bindings.captureScreen(self.region.x, self.region.y, self.region.width, self.region.height)
        end
        width, height = self.region.width, self.region.height
        
    elseif self.mode == CAPTURE_MODES.MONITOR then
        bitmap = ffi_bindings.captureMonitor(self.monitor_index)
        if bitmap and self.monitors[self.monitor_index] then
            width = self.monitors[self.monitor_index].width
            height = self.monitors[self.monitor_index].height
            
            -- Add cursor if enabled (monitor capture doesn't have built-in cursor support)
            if self.cursor_capture_enabled then
                local monitor = self.monitors[self.monitor_index]
                bitmap = ffi_bindings.captureScreenWithCursor(monitor.left, monitor.top, monitor.width, monitor.height)
            end
        end
        
    elseif self.mode == CAPTURE_MODES.VIRTUAL_SCREEN then
        local virtual = ffi_bindings.getVirtualScreenDimensions()
        if self.cursor_capture_enabled then
            bitmap = ffi_bindings.captureScreenWithCursor(virtual.left, virtual.top, virtual.width, virtual.height)
        else
            bitmap = ffi_bindings.captureVirtualScreen()
        end
        width, height = virtual.width, virtual.height
        
    else
        self.last_error = "Invalid capture mode"
        return nil, self.last_error
    end
    
    if not bitmap then
        self.last_error = "Screen capture failed"
        return nil, self.last_error
    end
    
    return bitmap, width, height
end

-- Capture and convert to pixel data
function ScreenCapture:captureToPixelData()
    local bitmap, width, height = self:capture()
    if not bitmap then
        return nil, self.last_error
    end
    
    local pixelData = ffi_bindings.bitmapToPixelData(bitmap, width, height)
    ffi_bindings.deleteBitmap(bitmap)
    
    if not pixelData then
        self.last_error = "Failed to convert bitmap to pixel data"
        return nil, self.last_error
    end
    
    return pixelData, width, height
end

-- Get last error message
function ScreenCapture:getLastError()
    return self.last_error
end

-- Validate capture region against monitor bounds
function ScreenCapture:validateRegion(x, y, width, height)
    if #self.monitors == 0 then
        self:initialize()
    end
    
    -- Check if region intersects with any monitor
    for _, monitor in ipairs(self.monitors) do
        local regionRight = x + width
        local regionBottom = y + height
        
        if not (x >= monitor.right or regionRight <= monitor.left or
                y >= monitor.bottom or regionBottom <= monitor.top) then
            return true  -- Region intersects with this monitor
        end
    end
    
    return false, "Capture region does not intersect with any monitor"
end

-- Get optimal capture settings for performance
function ScreenCapture:getOptimalSettings()
    local primary = ffi_bindings.getPrimaryMonitor()
    if not primary then
        return {
            mode = CAPTURE_MODES.FULL_SCREEN,
            max_width = 1920,
            max_height = 1080,
            recommended_fps = 30
        }
    end
    
    local settings = {
        mode = CAPTURE_MODES.FULL_SCREEN,
        max_width = primary.width,
        max_height = primary.height,
        recommended_fps = 30
    }
    
    -- Adjust FPS based on resolution
    local pixels = primary.width * primary.height
    if pixels > 1920 * 1080 then
        settings.recommended_fps = 24  -- 4K or higher
    elseif pixels > 1280 * 720 then
        settings.recommended_fps = 30  -- 1080p
    else
        settings.recommended_fps = 60  -- 720p or lower
    end
    
    return settings
end

-- Advanced Features Integration (Requirements 1.1, 2.2, 5.4)

-- Enable/disable cursor capture
function ScreenCapture:setCursorCapture(enabled)
    self.cursor_capture_enabled = enabled
    return self.advanced_features:setCursorCapture(enabled)
end

-- Start area selection mode
function ScreenCapture:startAreaSelection()
    return self.advanced_features:startAreaSelection()
end

-- Update area selection with mouse input
function ScreenCapture:updateAreaSelection(mouse_x, mouse_y, mouse_pressed)
    local completed, area = self.advanced_features:updateAreaSelection(mouse_x, mouse_y, mouse_pressed)
    
    if completed and area then
        -- Apply selected area as custom region
        self:setRegion(area.x, area.y, area.width, area.height)
        return true, area
    end
    
    return completed, area
end

-- Get currently selected area
function ScreenCapture:getSelectedArea()
    return self.advanced_features:getSelectedArea()
end

-- Cancel area selection
function ScreenCapture:cancelAreaSelection()
    return self.advanced_features:cancelAreaSelection()
end

-- Register hotkey callback
function ScreenCapture:registerHotkeyCallback(action, callback)
    return self.advanced_features:registerHotkeyCallback(action, callback)
end

-- Update hotkeys (should be called from main update loop)
function ScreenCapture:updateHotkeys(pressed_keys)
    return self.advanced_features:updateHotkeys(pressed_keys)
end

-- Set hotkey binding
function ScreenCapture:setHotkeyBinding(action, binding)
    return self.advanced_features:setHotkeyBinding(action, binding)
end

-- Draw area selection overlay (should be called from render loop)
function ScreenCapture:drawAreaSelection()
    return self.advanced_features:drawAreaSelection()
end

-- Get advanced features configuration
function ScreenCapture:getAdvancedConfiguration()
    return self.advanced_features:getConfiguration()
end

-- Set visual feedback options
function ScreenCapture:setVisualFeedback(enabled)
    return self.advanced_features:setVisualFeedback(enabled)
end

-- Set grid overlay options
function ScreenCapture:setGridOverlay(enabled, grid_size)
    return self.advanced_features:setGridOverlay(enabled, grid_size)
end

-- Export capture modes for external use
ScreenCapture.MODES = CAPTURE_MODES

return ScreenCapture