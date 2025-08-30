-- OverlayManager: Handles overlay window configuration and transparency features
-- Supports borderless, always-on-top, and transparent window modes

local FFIBindings = require("src.ffi_bindings")

local OverlayManager = {}
OverlayManager.__index = OverlayManager

-- Overlay modes
local OVERLAY_MODES = {
    NORMAL = "normal",
    OVERLAY = "overlay",
    TRANSPARENT_OVERLAY = "transparent_overlay",
    CLICK_THROUGH = "click_through"
}

-- Create new OverlayManager instance
function OverlayManager:new()
    return setmetatable({
        -- Current overlay configuration
        mode = OVERLAY_MODES.NORMAL,
        transparency = 1.0,  -- 0.0 to 1.0
        always_on_top = false,
        borderless = false,
        click_through = false,
        hide_from_taskbar = false,
        
        -- Window positioning and sizing
        position = {x = 100, y = 100},
        size = {width = 800, height = 600},
        
        -- Original window settings (for restoration)
        original_settings = {
            mode = nil,
            position = nil,
            size = nil,
            borderless = nil
        },
        
        -- Window handle cache
        window_handle = nil,
        
        -- State tracking
        is_overlay_active = false,
        last_update_time = 0
    }, self)
end

-- Initialize overlay manager
function OverlayManager:initialize()
    -- Cache the LÖVE window handle
    self.window_handle = FFIBindings.getLoveWindowHandle()
    
    -- Store original window settings
    self:_storeOriginalSettings()
    
    return true
end

-- Store original window settings for restoration
function OverlayManager:_storeOriginalSettings()
    -- Check if love.window is available (for testing)
    if not love or not love.window then
        self.original_settings = {
            mode = {width = 800, height = 600, flags = {borderless = false}},
            position = {x = 100, y = 100},
            borderless = false
        }
        return
    end
    
    local width, height, flags = love.window.getMode()
    local x, y = love.window.getPosition()
    
    self.original_settings = {
        mode = {width = width, height = height, flags = flags},
        position = {x = x, y = y},
        borderless = flags.borderless or false
    }
end

-- Set overlay mode (Requirement 7.1 - borderless, always-on-top window mode)
function OverlayManager:setOverlayMode(mode)
    local valid_modes = {}
    for _, v in pairs(OVERLAY_MODES) do
        valid_modes[v] = true
    end
    
    if not valid_modes[mode] then
        return false, "Invalid overlay mode: " .. tostring(mode)
    end
    
    local old_mode = self.mode
    self.mode = mode
    
    -- Apply the overlay configuration
    local success, err = self:_applyOverlayConfiguration()
    if not success then
        self.mode = old_mode  -- Revert on failure
        return false, err
    end
    
    self.is_overlay_active = (mode ~= OVERLAY_MODES.NORMAL)
    return true
end

-- Set transparency level (Requirement 7.2 - transparency and alpha blending)
function OverlayManager:setTransparency(alpha)
    alpha = math.max(0.0, math.min(1.0, alpha or 1.0))
    self.transparency = alpha
    
    -- Apply transparency if in overlay mode
    if self.is_overlay_active then
        return self:_applyTransparency()
    end
    
    return true
end

-- Set always on top behavior
function OverlayManager:setAlwaysOnTop(enabled)
    self.always_on_top = enabled
    
    -- Apply immediately if overlay is active
    if self.is_overlay_active then
        return self:_applyAlwaysOnTop()
    end
    
    return true
end

-- Set borderless window mode
function OverlayManager:setBorderless(enabled)
    self.borderless = enabled
    
    -- Apply immediately if overlay is active
    if self.is_overlay_active then
        return self:_applyBorderless()
    end
    
    return true
end

-- Set click-through behavior
function OverlayManager:setClickThrough(enabled)
    self.click_through = enabled
    
    -- Apply immediately if overlay is active
    if self.is_overlay_active then
        return self:_applyClickThrough()
    end
    
    return true
end

-- Set taskbar visibility
function OverlayManager:setTaskbarVisible(visible)
    self.hide_from_taskbar = not visible
    
    -- Apply immediately if overlay is active
    if self.is_overlay_active then
        return self:_applyTaskbarVisibility()
    end
    
    return true
end

-- Set overlay position (Requirement 7.3 - positioning controls)
function OverlayManager:setPosition(x, y)
    self.position.x = x or self.position.x
    self.position.y = y or self.position.y
    
    -- Apply position immediately
    return self:_applyPosition()
end

-- Set overlay size (Requirement 7.3 - sizing controls)
function OverlayManager:setSize(width, height)
    self.size.width = width or self.size.width
    self.size.height = height or self.size.height
    
    -- Apply size immediately
    return self:_applySize()
end

-- Get current overlay configuration
function OverlayManager:getConfiguration()
    return {
        mode = self.mode,
        transparency = self.transparency,
        always_on_top = self.always_on_top,
        borderless = self.borderless,
        click_through = self.click_through,
        hide_from_taskbar = self.hide_from_taskbar,
        position = {x = self.position.x, y = self.position.y},
        size = {width = self.size.width, height = self.size.height},
        is_active = self.is_overlay_active
    }
end

-- Apply complete overlay configuration
function OverlayManager:_applyOverlayConfiguration()
    if self.mode == OVERLAY_MODES.NORMAL then
        return self:_restoreNormalMode()
    end
    
    -- Apply all overlay settings
    local success, err
    
    -- Set borderless mode
    success, err = self:_applyBorderless()
    if not success then return false, err end
    
    -- Set always on top
    success, err = self:_applyAlwaysOnTop()
    if not success then return false, err end
    
    -- Set transparency
    success, err = self:_applyTransparency()
    if not success then return false, err end
    
    -- Set click-through for transparent overlay modes
    if self.mode == OVERLAY_MODES.CLICK_THROUGH then
        success, err = self:_applyClickThrough()
        if not success then return false, err end
    end
    
    -- Set taskbar visibility
    success, err = self:_applyTaskbarVisibility()
    if not success then return false, err end
    
    -- Apply position and size
    success, err = self:_applyPosition()
    if not success then return false, err end
    
    success, err = self:_applySize()
    if not success then return false, err end
    
    return true
end

-- Apply borderless window setting
function OverlayManager:_applyBorderless()
    local should_be_borderless = self.borderless and self.is_overlay_active
    
    -- Use LÖVE's window mode setting for borderless
    local width, height, flags = love.window.getMode()
    flags.borderless = should_be_borderless
    
    local success = love.window.setMode(width, height, flags)
    if not success then
        return false, "Failed to set borderless mode"
    end
    
    -- Update cached window handle after mode change
    self.window_handle = FFIBindings.getLoveWindowHandle()
    
    return true
end

-- Apply always on top setting
function OverlayManager:_applyAlwaysOnTop()
    if not self.window_handle then
        self.window_handle = FFIBindings.getLoveWindowHandle()
    end
    
    if self.window_handle then
        local should_be_topmost = self.always_on_top and self.is_overlay_active
        return FFIBindings.setWindowAlwaysOnTop(self.window_handle, should_be_topmost)
    end
    
    return true  -- No error if we can't get handle
end

-- Apply transparency setting
function OverlayManager:_applyTransparency()
    if not self.window_handle then
        self.window_handle = FFIBindings.getLoveWindowHandle()
    end
    
    if self.window_handle then
        -- Convert 0.0-1.0 range to 0-255 range for Windows API
        local alpha = math.floor(self.transparency * 255)
        return FFIBindings.setWindowTransparency(self.window_handle, alpha)
    end
    
    return true  -- No error if we can't get handle
end

-- Apply click-through setting
function OverlayManager:_applyClickThrough()
    if not self.window_handle then
        self.window_handle = FFIBindings.getLoveWindowHandle()
    end
    
    if self.window_handle then
        local should_be_click_through = self.click_through and self.is_overlay_active
        return FFIBindings.setWindowClickThrough(self.window_handle, should_be_click_through)
    end
    
    return true  -- No error if we can't get handle
end

-- Apply taskbar visibility setting
function OverlayManager:_applyTaskbarVisibility()
    if not self.window_handle then
        self.window_handle = FFIBindings.getLoveWindowHandle()
    end
    
    if self.window_handle then
        local should_hide = self.hide_from_taskbar and self.is_overlay_active
        return FFIBindings.setWindowTaskbarVisible(self.window_handle, not should_hide)
    end
    
    return true  -- No error if we can't get handle
end

-- Apply window position
function OverlayManager:_applyPosition()
    local success = love.window.setPosition(self.position.x, self.position.y)
    if not success then
        return false, "Failed to set window position"
    end
    
    return true
end

-- Apply window size
function OverlayManager:_applySize()
    local width, height, flags = love.window.getMode()
    
    local success = love.window.setMode(self.size.width, self.size.height, flags)
    if not success then
        return false, "Failed to set window size"
    end
    
    -- Update cached window handle after mode change
    self.window_handle = FFIBindings.getLoveWindowHandle()
    
    return true
end

-- Restore normal (non-overlay) mode
function OverlayManager:_restoreNormalMode()
    -- Restore original window settings
    if self.original_settings.mode then
        local flags = self.original_settings.mode.flags
        flags.borderless = self.original_settings.borderless
        
        local success = love.window.setMode(
            self.original_settings.mode.width,
            self.original_settings.mode.height,
            flags
        )
        
        if not success then
            return false, "Failed to restore window mode"
        end
    end
    
    -- Restore original position
    if self.original_settings.position then
        love.window.setPosition(
            self.original_settings.position.x,
            self.original_settings.position.y
        )
    end
    
    -- Update window handle
    self.window_handle = FFIBindings.getLoveWindowHandle()
    
    -- Remove always on top
    if self.window_handle then
        FFIBindings.setWindowAlwaysOnTop(self.window_handle, false)
        FFIBindings.setWindowTransparency(self.window_handle, 255)  -- Full opacity
        FFIBindings.setWindowClickThrough(self.window_handle, false)
        FFIBindings.setWindowTaskbarVisible(self.window_handle, true)
    end
    
    return true
end

-- Update overlay manager (called each frame)
function OverlayManager:update(dt)
    self.last_update_time = love.timer.getTime()
    
    -- Refresh window handle periodically if lost
    if not self.window_handle and self.is_overlay_active then
        self.window_handle = FFIBindings.getLoveWindowHandle()
    end
end

-- Get current overlay state
function OverlayManager:getState()
    return {
        mode = self.mode,
        is_active = self.is_overlay_active,
        transparency = self.transparency,
        always_on_top = self.always_on_top,
        borderless = self.borderless,
        click_through = self.click_through,
        hide_from_taskbar = self.hide_from_taskbar,
        position = self.position,
        size = self.size,
        window_handle = self.window_handle ~= nil,
        last_update_time = self.last_update_time
    }
end

-- Cleanup overlay manager
function OverlayManager:cleanup()
    -- Restore normal mode before cleanup
    if self.is_overlay_active then
        self:setOverlayMode(OVERLAY_MODES.NORMAL)
    end
    
    self.window_handle = nil
end

-- Export overlay modes for external use
OverlayManager.MODES = OVERLAY_MODES

return OverlayManager