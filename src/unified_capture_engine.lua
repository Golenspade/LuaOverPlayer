-- Unified Capture Engine
-- Combines screen capture and window capture functionality into a single, cohesive system

-- Use mock bindings for testing if available
local ffi_bindings
local success, mock_bindings = pcall(require, "tests.mock_ffi_bindings")
if success and _G.TESTING_MODE then
    ffi_bindings = mock_bindings
else
    ffi_bindings = require("src.ffi_bindings")
end

local ScreenCapture = require("src.screen_capture")
local WindowCapture = require("src.window_capture")

local UnifiedCaptureEngine = {}
UnifiedCaptureEngine.__index = UnifiedCaptureEngine

-- Source types
local SOURCE_TYPES = {
    SCREEN = "screen",
    WINDOW = "window",
    MONITOR = "monitor",
    REGION = "region",
    VIRTUAL_SCREEN = "virtual_screen"
}

-- Capture modes
local CAPTURE_MODES = {
    CONTINUOUS = "continuous",
    SINGLE = "single",
    TIMED = "timed"
}

function UnifiedCaptureEngine:new(options)
    options = options or {}
    
    local instance = setmetatable({
        -- Core components
        screen_capture = ScreenCapture:new(),
        window_capture = WindowCapture:new(options),
        
        -- State management
        current_source = nil,
        current_mode = CAPTURE_MODES.SINGLE,
        is_capturing = false,
        
        -- Configuration
        frame_rate = options.frame_rate or 30,
        quality = options.quality or "high",
        dpi_aware = options.dpi_aware or false,
        
        -- Statistics
        stats = {
            frames_captured = 0,
            frames_dropped = 0,
            last_capture_time = 0,
            average_fps = 0,
            errors = 0
        },
        
        -- Error handling
        last_error = nil,
        error_callback = options.error_callback,
        
        -- Performance
        performance_mode = options.performance_mode or "balanced"
    }, self)
    
    -- Initialize components
    instance:initialize()
    
    return instance
end

-- Initialize the capture engine
function UnifiedCaptureEngine:initialize()
    -- Initialize screen capture
    local success, err = self.screen_capture:initialize()
    if not success then
        self.last_error = "Failed to initialize screen capture: " .. (err or "unknown error")
        return false, self.last_error
    end
    
    -- Set DPI awareness if requested
    if self.dpi_aware then
        self.window_capture:setDPIAware(true)
    end
    
    return true
end

-- Set capture source
function UnifiedCaptureEngine:setSource(source_type, config)
    if not SOURCE_TYPES[source_type:upper()] then
        self.last_error = "Invalid source type: " .. tostring(source_type)
        return false, self.last_error
    end
    
    self.current_source = source_type:lower()
    local success, err
    
    if self.current_source == SOURCE_TYPES.SCREEN then
        success, err = self.screen_capture:setMode("FULL_SCREEN")
        
    elseif self.current_source == SOURCE_TYPES.MONITOR then
        local monitor_index = config and config.monitor_index or 1
        success, err = self.screen_capture:setMonitor(monitor_index)
        
    elseif self.current_source == SOURCE_TYPES.REGION then
        local region = config and config.region
        if region then
            success, err = self.screen_capture:setRegion(region.x, region.y, region.width, region.height)
        else
            success, err = false, "Region configuration required"
        end
        
    elseif self.current_source == SOURCE_TYPES.VIRTUAL_SCREEN then
        success, err = self.screen_capture:setMode("VIRTUAL_SCREEN")
        
    elseif self.current_source == SOURCE_TYPES.WINDOW then
        local window = config and config.window
        if window then
            success, err = self.window_capture:setTargetWindow(window)
        else
            success, err = false, "Window configuration required"
        end
    end
    
    if not success then
        self.last_error = err
        return false, err
    end
    
    return true
end

-- Set capture mode
function UnifiedCaptureEngine:setMode(mode)
    if not CAPTURE_MODES[mode:upper()] then
        self.last_error = "Invalid capture mode: " .. tostring(mode)
        return false, self.last_error
    end
    
    self.current_mode = CAPTURE_MODES[mode:upper()]
    return true
end

-- Start capturing
function UnifiedCaptureEngine:startCapture()
    if not self.current_source then
        self.last_error = "No capture source configured"
        return false, self.last_error
    end
    
    self.is_capturing = true
    self.stats.frames_captured = 0
    self.stats.frames_dropped = 0
    self.stats.errors = 0
    self.stats.last_capture_time = love and love.timer.getTime() or os.clock()
    
    return true
end

-- Stop capturing
function UnifiedCaptureEngine:stopCapture()
    self.is_capturing = false
    return true
end

-- Capture a single frame
function UnifiedCaptureEngine:captureFrame()
    if not self.is_capturing then
        return nil, "Not currently capturing"
    end
    
    local frame_data, width, height, error_msg
    
    if self.current_source == SOURCE_TYPES.WINDOW then
        frame_data, width, height = self.window_capture:captureWindowPixelData()
        if not frame_data then
            error_msg = self.window_capture:getLastError()
        end
    else
        -- All other sources use screen capture
        frame_data, width, height = self.screen_capture:captureToPixelData()
        if not frame_data then
            error_msg = self.screen_capture:getLastError()
        end
    end
    
    if not frame_data then
        self.last_error = error_msg or "Frame capture failed"
        self.stats.frames_dropped = self.stats.frames_dropped + 1
        self.stats.errors = self.stats.errors + 1
        
        if self.error_callback then
            self.error_callback(self.last_error)
        end
        
        return nil, self.last_error
    end
    
    -- Update statistics
    self.stats.frames_captured = self.stats.frames_captured + 1
    local current_time = love and love.timer.getTime() or os.clock()
    local time_diff = current_time - self.stats.last_capture_time
    if time_diff > 0 then
        self.stats.average_fps = 1.0 / time_diff
    end
    self.stats.last_capture_time = current_time
    
    return {
        data = frame_data,
        width = width,
        height = height,
        timestamp = current_time,
        source = self.current_source
    }
end

-- Get available sources
function UnifiedCaptureEngine:getAvailableSources()
    local sources = {}
    
    -- Screen sources
    local monitors = self.screen_capture:getMonitors()
    for i, monitor in ipairs(monitors) do
        table.insert(sources, {
            type = SOURCE_TYPES.MONITOR,
            id = i,
            name = "Monitor " .. i,
            description = string.format("%dx%d at (%d,%d)", 
                monitor.width, monitor.height, monitor.left, monitor.top)
        })
    end
    
    -- Window sources
    local windows = self.window_capture:enumerateWindows(false)
    for _, window in ipairs(windows) do
        if window.capturable then
            table.insert(sources, {
                type = SOURCE_TYPES.WINDOW,
                id = window.handle,
                name = window.title,
                description = string.format("Window: %s", window.title)
            })
        end
    end
    
    -- Add virtual screen
    table.insert(sources, {
        type = SOURCE_TYPES.VIRTUAL_SCREEN,
        id = "virtual",
        name = "Virtual Screen",
        description = "All monitors combined"
    })
    
    return sources
end

-- Get capture statistics
function UnifiedCaptureEngine:getStats()
    local stats = {
        is_capturing = self.is_capturing,
        source = self.current_source,
        mode = self.current_mode,
        frame_rate = self.frame_rate,
        frames_captured = self.stats.frames_captured,
        frames_dropped = self.stats.frames_dropped,
        average_fps = self.stats.average_fps,
        errors = self.stats.errors,
        last_error = self.last_error
    }
    
    -- Add source-specific information
    if self.current_source == SOURCE_TYPES.WINDOW then
        local window_state = self.window_capture:getWindowState()
        if window_state then
            stats.window_state = window_state
        end
    else
        local capture_info = self.screen_capture:getCaptureInfo()
        stats.capture_info = capture_info
    end
    
    return stats
end

-- Get optimal settings for current configuration
function UnifiedCaptureEngine:getOptimalSettings()
    local settings = {
        recommended_fps = 30,
        max_width = 1920,
        max_height = 1080,
        quality = "high"
    }
    
    if self.current_source == SOURCE_TYPES.WINDOW then
        local window_state = self.window_capture:getWindowState()
        if window_state and window_state.rect then
            settings.max_width = window_state.rect.width
            settings.max_height = window_state.rect.height
        end
    else
        local capture_info = self.screen_capture:getCaptureInfo()
        if capture_info then
            settings.max_width = capture_info.width
            settings.max_height = capture_info.height
        end
    end
    
    -- Adjust FPS based on resolution
    local pixels = settings.max_width * settings.max_height
    if pixels > 1920 * 1080 then
        settings.recommended_fps = 24  -- 4K or higher
    elseif pixels > 1280 * 720 then
        settings.recommended_fps = 30  -- 1080p
    else
        settings.recommended_fps = 60  -- 720p or lower
    end
    
    return settings
end

-- Get last error
function UnifiedCaptureEngine:getLastError()
    return self.last_error
end

-- Clear error state
function UnifiedCaptureEngine:clearError()
    self.last_error = nil
    self.stats.errors = 0
end

-- Export constants
UnifiedCaptureEngine.SOURCE_TYPES = SOURCE_TYPES
UnifiedCaptureEngine.CAPTURE_MODES = CAPTURE_MODES

return UnifiedCaptureEngine
