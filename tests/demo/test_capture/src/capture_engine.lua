-- Capture Engine - Core logic for managing video capture sources
local ScreenCapture = require("src.screen_capture")
local WindowCapture = require("src.window_capture")
local WebcamCapture = require("src.webcam_capture")
local FrameBuffer = require("src.frame_buffer")
local PerformanceMonitor = require("src.performance_monitor")
local ResourceManager = require("src.resource_manager")

local CaptureEngine = {}
CaptureEngine.__index = CaptureEngine

-- Source types
local SOURCE_TYPES = {
    SCREEN = "screen",
    WINDOW = "window", 
    WEBCAM = "webcam"
}

function CaptureEngine:new(options)
    options = options or {}
    
    return setmetatable({
        -- Core state
        current_source = nil,
        target_frame_rate = options.frame_rate or 30,
        is_capturing = false,
        is_paused = false,
        source_config = {},
        last_error = nil,
        
        -- Capture modules
        screen_capture = nil,
        window_capture = nil,
        webcam_capture = nil,  -- Will be implemented in task 7
        
        -- Resource management
        resource_manager = ResourceManager:new({
            enabled = options.resource_optimization ~= false,
            aggressive_mode = options.aggressive_cleanup or false,
            memory_monitoring = options.memory_monitoring ~= false,
            leak_detection = options.leak_detection ~= false,
            memory_pool_config = options.memory_pool_config,
            on_memory_warning = function(info)
                print("CaptureEngine: Memory warning - " .. string.format("%.1f MB", info.current_memory))
            end,
            on_memory_critical = function(info)
                print("CaptureEngine: Critical memory usage - " .. string.format("%.1f MB", info.current_memory))
            end,
            on_leak_detected = function(info)
                print("CaptureEngine: Potential memory leak detected - " .. 
                      string.format("%.1f MB growth over %.1f seconds", info.growth_mb, info.time_span))
            end
        }),
        
        -- Frame management
        frame_buffer = FrameBuffer:new(options.buffer_size or 3, {
            use_memory_pool = options.use_memory_pool ~= false,
            intelligent_gc = options.intelligent_gc ~= false,
            gc_threshold = options.gc_threshold or 50,
            memory_pool = nil  -- Will be set from resource manager
        }),
        last_frame = nil,
        
        -- Timing and frame rate control
        frame_interval = 1.0 / (options.frame_rate or 30),
        last_capture_time = 0,
        next_capture_time = 0,
        frame_timer = 0,
        
        -- Statistics and monitoring
        capture_stats = {
            frames_captured = 0,
            frames_dropped = 0,
            frames_skipped = 0,
            last_capture_time = 0,
            average_fps = 0,
            actual_fps = 0,
            capture_duration = 0,
            start_time = 0
        },
        
        -- Performance monitoring
        performance_monitor = PerformanceMonitor:new({
            enabled = options.monitor_performance ~= false,
            target_fps = options.frame_rate or 30,
            frame_drop_enabled = options.frame_drop_enabled ~= false,
            memory_monitoring = options.memory_monitoring ~= false,
            on_performance_warning = function(metrics)
                print("Performance warning: FPS=" .. string.format("%.1f", metrics.current_fps) .. 
                      ", Memory=" .. string.format("%.1f MB", metrics.current_memory))
            end,
            on_performance_critical = function(metrics)
                print("Critical performance issue: FPS=" .. string.format("%.1f", metrics.current_fps) .. 
                      ", Memory=" .. string.format("%.1f MB", metrics.current_memory))
            end,
            on_frame_drop_start = function(metrics)
                print("Frame dropping activated due to performance issues")
            end,
            on_frame_drop_stop = function(metrics)
                print("Frame dropping deactivated - performance recovered")
            end
        })
    }, self)
end

-- Set capture source and configuration with proper cleanup and switching
function CaptureEngine:setSource(source_type, config)
    if not SOURCE_TYPES[source_type:upper()] then
        self.last_error = "Invalid source type: " .. tostring(source_type)
        return false, self.last_error
    end
    
    local new_source = source_type:lower()
    local was_capturing = self.is_capturing
    
    -- Stop current capture if switching sources
    if was_capturing and self.current_source ~= new_source then
        self:stopCapture()
    end
    
    -- Clean up previous source if switching
    if self.current_source and self.current_source ~= new_source then
        self:_cleanupCurrentSource()
    end
    
    self.current_source = new_source
    self.source_config = config or {}
    
    -- Initialize the appropriate capture module
    local success, err = self:_initializeSource(new_source, config)
    if not success then
        self.last_error = err
        return false, err
    end
    
    -- Restart capture if it was previously active
    if was_capturing then
        return self:startCapture()
    end
    
    return true
end

-- Private method to initialize capture source
function CaptureEngine:_initializeSource(source_type, config)
    if source_type == SOURCE_TYPES.SCREEN then
        return self:_initializeScreenCapture(config)
    elseif source_type == SOURCE_TYPES.WINDOW then
        return self:_initializeWindowCapture(config)
    elseif source_type == SOURCE_TYPES.WEBCAM then
        return self:_initializeWebcamCapture(config)
    else
        return false, "Unknown source type: " .. tostring(source_type)
    end
end

-- Initialize screen capture
function CaptureEngine:_initializeScreenCapture(config)
    self.screen_capture = ScreenCapture:new()
    local success, err = self.screen_capture:initialize()
    if not success then
        return false, err
    end
    
    -- Configure screen capture based on config
    if config then
        if config.mode then
            local success, err = self.screen_capture:setMode(config.mode)
            if not success then
                return false, err
            end
        end
        
        if config.region then
            local r = config.region
            local success, err = self.screen_capture:setRegion(r.x, r.y, r.width, r.height)
            if not success then
                return false, err
            end
        end
        
        if config.monitor_index then
            local success, err = self.screen_capture:setMonitor(config.monitor_index)
            if not success then
                return false, err
            end
        end
    end
    
    return true
end

-- Initialize window capture
function CaptureEngine:_initializeWindowCapture(config)
    local options = {}
    if config then
        options.dpi_aware = config.dpi_aware
        options.auto_dpi_setup = config.auto_dpi_setup
    end
    
    self.window_capture = WindowCapture:new(options)
    
    -- Set target window if specified
    if config and config.window then
        local success, err = self.window_capture:setTargetWindow(config.window)
        if not success then
            return false, err
        end
    end
    
    -- Configure window capture options
    if config then
        if config.tracking ~= nil then
            self.window_capture:setTracking(config.tracking)
        end
        
        if config.capture_borders ~= nil then
            self.window_capture:setBorderCapture(config.capture_borders)
        end
        
        if config.auto_retry ~= nil then
            self.window_capture:setAutoRetry(config.auto_retry, config.max_retries)
        end
    end
    
    return true
end

-- Initialize webcam capture
function CaptureEngine:_initializeWebcamCapture(config)
    self.webcam_capture = WebcamCapture:new(config)
    local success, err = self.webcam_capture:initialize()
    if not success then
        return false, err
    end
    
    -- Configure webcam based on config
    if config then
        if config.device_index ~= nil then
            local success, err = self.webcam_capture:setDevice(config.device_index)
            if not success then
                return false, err
            end
        end
        
        if config.resolution then
            local r = config.resolution
            local success, err = self.webcam_capture:setResolution(r.width, r.height)
            if not success then
                return false, err
            end
        end
        
        if config.frame_rate then
            local success, err = self.webcam_capture:setFrameRate(config.frame_rate)
            if not success then
                return false, err
            end
        end
    end
    
    return true
end

-- Clean up current capture source
function CaptureEngine:_cleanupCurrentSource()
    -- No explicit cleanup needed for current modules
    -- They will be garbage collected when references are removed
    self.screen_capture = nil
    self.window_capture = nil
    self.webcam_capture = nil
end

-- Start capturing frames with proper timing initialization
function CaptureEngine:startCapture()
    if not self.current_source then
        self.last_error = "No capture source configured"
        return false, self.last_error
    end
    
    -- Verify source is properly initialized
    if not self:_isSourceReady() then
        self.last_error = "Capture source not properly initialized"
        return false, self.last_error
    end
    
    -- Initialize timing
    local current_time = love and love.timer.getTime() or os.clock()
    self.is_capturing = true
    self.last_capture_time = current_time
    self.next_capture_time = current_time
    self.frame_timer = 0
    
    -- Reset statistics
    self.capture_stats.frames_captured = 0
    self.capture_stats.frames_dropped = 0
    self.capture_stats.frames_skipped = 0
    self.capture_stats.start_time = current_time
    self.capture_stats.capture_duration = 0
    self.capture_stats.average_fps = 0
    self.capture_stats.actual_fps = 0
    
    -- Initialize resource management
    self.resource_manager:initialize()
    
    -- Connect memory pool to frame buffer
    self.frame_buffer.memory_pool = self.resource_manager:getMemoryPool()
    
    -- Initialize performance monitoring
    self.performance_monitor:initialize()
    
    -- Clear frame buffer
    self.frame_buffer:clear()
    
    -- Start capture on the source if needed
    if self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        local success, err = self.webcam_capture:startCapture()
        if not success then
            self.last_error = err
            self.is_capturing = false
            return false, err
        end
    end
    
    return true
end

-- Stop capturing frames with cleanup
function CaptureEngine:stopCapture()
    -- Stop source-specific capture
    if self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        self.webcam_capture:stopCapture()
    end
    
    self.is_capturing = false
    self.is_paused = false
    
    -- Update final statistics
    if self.capture_stats.start_time > 0 then
        local current_time = love and love.timer.getTime() or os.clock()
        self.capture_stats.capture_duration = current_time - self.capture_stats.start_time
        
        if self.capture_stats.capture_duration > 0 then
            self.capture_stats.average_fps = self.capture_stats.frames_captured / self.capture_stats.capture_duration
        end
    end
    
    return true
end

-- Pause capturing frames (Requirement 4.3 - immediate response to controls)
function CaptureEngine:pauseCapture()
    if not self.is_capturing then
        self.last_error = "Cannot pause - not currently capturing"
        return false, self.last_error
    end
    
    self.is_paused = true
    return true
end

-- Resume capturing frames (Requirement 4.3 - immediate response to controls)
function CaptureEngine:resumeCapture()
    if not self.is_capturing then
        self.last_error = "Cannot resume - not currently capturing"
        return false, self.last_error
    end
    
    if not self.is_paused then
        return true  -- Already running
    end
    
    self.is_paused = false
    
    -- Reset timing to prevent burst of captures
    local current_time = love and love.timer.getTime() or os.clock()
    self.next_capture_time = current_time + self.frame_interval
    
    return true
end

-- Check if capture is currently paused
function CaptureEngine:isPaused()
    return self.is_paused
end

-- Check if current source is ready for capture
function CaptureEngine:_isSourceReady()
    if self.current_source == SOURCE_TYPES.SCREEN then
        return self.screen_capture ~= nil
    elseif self.current_source == SOURCE_TYPES.WINDOW then
        return self.window_capture ~= nil and self.window_capture:getTargetWindow() ~= nil
    elseif self.current_source == SOURCE_TYPES.WEBCAM then
        return self.webcam_capture ~= nil
    end
    return false
end

-- Update method to be called each frame for timing control
function CaptureEngine:update(dt)
    -- Always update resource manager and performance monitor
    self.resource_manager:update(dt)
    self.performance_monitor:update(dt)
    
    if not self.is_capturing or self.is_paused then
        return
    end
    
    -- Update frame timer
    self.frame_timer = self.frame_timer + dt
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Check if it's time to capture a new frame
    if current_time >= self.next_capture_time then
        -- Check if we're falling behind (Requirement 4.4 - frame dropping for real-time performance)
        local time_behind = current_time - self.next_capture_time
        if time_behind > self.frame_interval then
            -- We're more than one frame behind, skip frames to catch up
            local frames_to_skip = math.floor(time_behind / self.frame_interval)
            self.capture_stats.frames_skipped = self.capture_stats.frames_skipped + frames_to_skip
            
            -- Record skipped frames in performance monitor
            for i = 1, frames_to_skip do
                self.performance_monitor:recordSkippedFrame()
            end
            
            self.next_capture_time = self.next_capture_time + (frames_to_skip * self.frame_interval)
        end
        
        -- Check if performance monitor suggests dropping this frame
        if self.performance_monitor:shouldDropFrame() then
            -- Skip this frame for performance
            self.capture_stats.frames_dropped = self.capture_stats.frames_dropped + 1
            self.next_capture_time = current_time + self.frame_interval
        else
            local success, frame_or_error = self:_performCapture()
            
            if success then
                -- Schedule next capture
                self.next_capture_time = current_time + self.frame_interval
                
                -- Update actual FPS calculation
                local time_since_last = current_time - self.last_capture_time
                if time_since_last > 0 then
                    self.capture_stats.actual_fps = 1.0 / time_since_last
                end
                self.last_capture_time = current_time
            else
                -- Handle capture failure
                self.last_error = frame_or_error
                self.capture_stats.frames_dropped = self.capture_stats.frames_dropped + 1
                
                -- Still schedule next attempt
                self.next_capture_time = current_time + self.frame_interval
            end
        end
    end
    
    -- Update capture duration
    if self.capture_stats.start_time > 0 then
        self.capture_stats.capture_duration = current_time - self.capture_stats.start_time
        
        -- Calculate average FPS over entire session
        if self.capture_stats.capture_duration > 0 then
            self.capture_stats.average_fps = self.capture_stats.frames_captured / self.capture_stats.capture_duration
        end
    end
end

-- Internal method to perform actual frame capture
function CaptureEngine:_performCapture()
    local capture_start_time = love and love.timer.getTime() or os.clock()
    local frame_data, width, height, error_msg
    
    -- Capture based on current source
    if self.current_source == SOURCE_TYPES.SCREEN then
        if not self.screen_capture then
            return false, "Screen capture not initialized"
        end
        
        frame_data, width, height = self.screen_capture:captureToPixelData()
        if not frame_data then
            error_msg = self.screen_capture:getLastError()
        end
        
    elseif self.current_source == SOURCE_TYPES.WINDOW then
        if not self.window_capture then
            return false, "Window capture not initialized"
        end
        
        local result = self.window_capture:captureWindowPixelData()
        if result then
            if type(result) == "table" and result.data then
                -- New format with DPI info
                frame_data = result.data
                width = result.width
                height = result.height
            else
                -- Legacy format
                frame_data = result
                width = select(2, self.window_capture:captureWindowPixelData())
                height = select(3, self.window_capture:captureWindowPixelData())
            end
        else
            error_msg = self.window_capture:getLastError()
        end
        
    elseif self.current_source == SOURCE_TYPES.WEBCAM then
        if not self.webcam_capture then
            return false, "Webcam capture not initialized"
        end
        
        local frame = self.webcam_capture:captureFrame()
        if frame then
            frame_data = frame.data
            width = frame.width
            height = frame.height
        else
            error_msg = self.webcam_capture:getLastError()
        end
        
    else
        return false, "Unknown source type: " .. tostring(self.current_source)
    end
    
    -- Check capture performance - performance monitor handles this automatically
    local capture_end_time = love and love.timer.getTime() or os.clock()
    local capture_duration = capture_end_time - capture_start_time
    
    if not frame_data then
        return false, error_msg or "Frame capture failed"
    end
    
    -- Create frame object and add to buffer
    local source_info = {
        source_type = self.current_source,
        capture_duration = capture_duration
    }
    
    -- Add source-specific metadata
    if self.current_source == SOURCE_TYPES.WINDOW and self.window_capture then
        local window_state = self.window_capture:getWindowState()
        if window_state then
            source_info.window_title = window_state.title
            source_info.window_rect = window_state.rect
        end
    end
    
    self.frame_buffer:addFrame(frame_data, width, height, 'RGBA', source_info)
    
    -- Track frame data for resource management
    self.resource_manager:trackResource(frame_data, "frame_buffers", {
        width = width,
        height = height,
        source = self.current_source,
        size_bytes = width * height * 4
    })
    
    -- Update frame as latest
    self.last_frame = self.frame_buffer:getLatestFrame()
    
    -- Update statistics
    self.capture_stats.frames_captured = self.capture_stats.frames_captured + 1
    
    return true, self.last_frame
end

-- Get performance monitor instance
function CaptureEngine:getPerformanceMonitor()
    return self.performance_monitor
end

-- Manual frame capture (for immediate capture needs)
function CaptureEngine:captureFrame()
    if not self.is_capturing or not self.current_source then
        return nil, "Not currently capturing"
    end
    
    local success, frame_or_error = self:_performCapture()
    
    if success then
        return frame_or_error
    else
        self.last_error = frame_or_error
        return nil, frame_or_error
    end
end

-- Get the most recent frame
function CaptureEngine:getFrame()
    return self.last_frame
end

-- Get frame from buffer by age (0 = latest, 1 = previous, etc.)
function CaptureEngine:getFrameByAge(age)
    return self.frame_buffer:getFrame(age or 0)
end



-- Get current target frame rate
function CaptureEngine:getFrameRate()
    return self.target_frame_rate
end

-- Get comprehensive capture statistics and status
function CaptureEngine:getStats()
    local stats = {
        -- Basic status
        is_capturing = self.is_capturing,
        is_paused = self.is_paused,
        source = self.current_source,
        target_frame_rate = self.target_frame_rate,
        
        -- Frame statistics
        frames_captured = self.capture_stats.frames_captured,
        frames_dropped = self.capture_stats.frames_dropped,
        frames_skipped = self.capture_stats.frames_skipped,
        
        -- Performance metrics
        average_fps = self.capture_stats.average_fps,
        actual_fps = self.capture_stats.actual_fps,
        capture_duration = self.capture_stats.capture_duration,
        
        -- Buffer information
        buffer_stats = self.frame_buffer:getStats(),
        
        -- Error information
        last_error = self.last_error
    }
    
    -- Add performance monitoring data
    if self.performance_monitor.enabled then
        stats.performance = self.performance_monitor:getMetrics()
    end
    
    -- Add resource management data
    if self.resource_manager.enabled then
        stats.resource_management = self.resource_manager:getStats()
    end
    
    -- Add source-specific information
    if self.current_source == SOURCE_TYPES.SCREEN and self.screen_capture then
        local capture_info = self.screen_capture:getCaptureInfo()
        stats.capture_region = capture_info
        stats.monitors = self.screen_capture:getMonitors()
        
    elseif self.current_source == SOURCE_TYPES.WINDOW and self.window_capture then
        local window_state = self.window_capture:getWindowState()
        stats.window_state = window_state
        stats.dpi_info = self.window_capture:getDPIInfo()
        
    elseif self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        local webcam_stats = self.webcam_capture:getStats()
        stats.webcam_stats = webcam_stats
        stats.webcam_config = self.webcam_capture:getConfiguration()
    end
    
    return stats
end

-- Get available sources and their configurations
function CaptureEngine:getAvailableSources()
    local sources = {}
    
    -- Screen capture is always available
    sources[SOURCE_TYPES.SCREEN] = {
        available = true,
        monitors = self:getAvailableMonitors()
    }
    
    -- Window capture
    sources[SOURCE_TYPES.WINDOW] = {
        available = true,
        windows = self:getAvailableWindows()
    }
    
    -- Webcam capture
    local webcam_available = WebcamCapture:new():isAvailable()
    sources[SOURCE_TYPES.WEBCAM] = {
        available = webcam_available,
        devices = webcam_available and self:getAvailableWebcams() or {},
        reason = webcam_available and nil or "Media Foundation not available"
    }
    
    return sources
end

-- Get available monitors (for screen capture)
function CaptureEngine:getAvailableMonitors()
    if not self.screen_capture then
        local temp_capture = ScreenCapture:new()
        local success = temp_capture:initialize()
        if success then
            return temp_capture:getMonitors()
        end
        return {}
    end
    
    return self.screen_capture:getMonitors()
end

-- Get available windows (for window capture)
function CaptureEngine:getAvailableWindows()
    if not self.window_capture then
        local temp_capture = WindowCapture:new()
        return temp_capture:enumerateWindows() or {}
    end
    
    return self.window_capture:enumerateWindows() or {}
end

-- Get available webcams (for webcam capture)
function CaptureEngine:getAvailableWebcams()
    if not self.webcam_capture then
        local temp_capture = WebcamCapture:new()
        local success = temp_capture:initialize()
        if success then
            local devices = temp_capture:getAvailableDevices()
            temp_capture:cleanup()
            return devices or {}
        end
        return {}
    end
    
    return self.webcam_capture:getAvailableDevices() or {}
end

-- Get optimal capture settings for current configuration
function CaptureEngine:getOptimalSettings()
    if self.current_source == SOURCE_TYPES.SCREEN then
        if not self.screen_capture then
            local temp_capture = ScreenCapture:new()
            local success = temp_capture:initialize()
            if success then
                return temp_capture:getOptimalSettings()
            end
        else
            return self.screen_capture:getOptimalSettings()
        end
        
    elseif self.current_source == SOURCE_TYPES.WINDOW then
        -- Return window-specific optimal settings
        return {
            recommended_fps = 30,
            max_width = 1920,
            max_height = 1080,
            dpi_aware = true,
            auto_retry = true
        }
    end
    
    -- Default settings for other sources
    return {
        recommended_fps = 30,
        max_width = 1920,
        max_height = 1080
    }
end

-- Get available configuration options for a source type (Requirement 5.2)
function CaptureEngine:getSourceConfigurationOptions(source_type)
    source_type = source_type and source_type:lower() or self.current_source
    
    if source_type == SOURCE_TYPES.SCREEN then
        return {
            modes = {
                "FULL_SCREEN",
                "MONITOR", 
                "CUSTOM_REGION"
            },
            options = {
                {
                    name = "mode",
                    type = "enum",
                    values = {"FULL_SCREEN", "MONITOR", "CUSTOM_REGION"},
                    default = "FULL_SCREEN",
                    description = "Screen capture mode"
                },
                {
                    name = "monitor_index", 
                    type = "integer",
                    min = 1,
                    max = 8,
                    default = 1,
                    description = "Monitor to capture (for MONITOR mode)"
                },
                {
                    name = "region",
                    type = "object",
                    properties = {
                        x = {type = "integer", min = 0},
                        y = {type = "integer", min = 0}, 
                        width = {type = "integer", min = 1},
                        height = {type = "integer", min = 1}
                    },
                    description = "Custom capture region (for CUSTOM_REGION mode)"
                }
            },
            frame_rate_range = {min = 1, max = 120, recommended = 30},
            resolution_limits = {max_width = 7680, max_height = 4320}
        }
        
    elseif source_type == SOURCE_TYPES.WINDOW then
        return {
            options = {
                {
                    name = "window",
                    type = "string",
                    description = "Target window title or handle"
                },
                {
                    name = "tracking",
                    type = "boolean", 
                    default = true,
                    description = "Automatically track window position/size changes"
                },
                {
                    name = "dpi_aware",
                    type = "boolean",
                    default = true,
                    description = "Enable DPI awareness for high-DPI displays"
                },
                {
                    name = "capture_borders",
                    type = "boolean",
                    default = false,
                    description = "Include window borders in capture"
                },
                {
                    name = "auto_retry",
                    type = "boolean",
                    default = true,
                    description = "Automatically retry on capture failures"
                },
                {
                    name = "max_retries",
                    type = "integer",
                    min = 1,
                    max = 10,
                    default = 3,
                    description = "Maximum retry attempts"
                }
            },
            frame_rate_range = {min = 1, max = 60, recommended = 30},
            resolution_limits = {max_width = 3840, max_height = 2160}
        }
        
    elseif source_type == SOURCE_TYPES.WEBCAM then
        local webcam_available = WebcamCapture:new():isAvailable()
        
        if not webcam_available then
            return {
                available = false,
                reason = "Media Foundation not available"
            }
        end
        
        return {
            available = true,
            options = {
                {
                    name = "device_index",
                    type = "integer",
                    min = 0,
                    max = 10,
                    default = 0,
                    description = "Webcam device index"
                },
                {
                    name = "resolution",
                    type = "object", 
                    properties = {
                        width = {type = "integer", min = 160, max = 1920},
                        height = {type = "integer", min = 120, max = 1080}
                    },
                    default = {width = 640, height = 480},
                    description = "Capture resolution"
                },
                {
                    name = "frame_rate",
                    type = "integer",
                    min = 1,
                    max = 60,
                    default = 30,
                    description = "Capture frame rate"
                },
                {
                    name = "pixel_format",
                    type = "enum",
                    values = {"RGB24", "YUY2", "NV12"},
                    default = "RGB24",
                    description = "Pixel format for capture"
                }
            },
            frame_rate_range = {min = 1, max = 60, recommended = 30},
            resolution_limits = {max_width = 1920, max_height = 1080}
        }
    end
    
    return {
        error = "Unknown source type: " .. tostring(source_type)
    }
end

-- Enable/disable performance monitoring
function CaptureEngine:setPerformanceMonitoring(enabled)
    self.performance_monitor:setEnabled(enabled)
end

-- Set target frame rate for performance monitoring
function CaptureEngine:setFrameRate(fps)
    if fps <= 0 or fps > 120 then
        return false, "Frame rate must be between 1 and 120 FPS"
    end
    
    self.target_frame_rate = fps
    self.frame_interval = 1.0 / fps
    
    -- Update performance monitor target FPS
    self.performance_monitor:setTargetFPS(fps)
    
    return true
end

-- Get current source configuration
function CaptureEngine:getSourceConfig()
    return {
        source_type = self.current_source,
        config = self.source_config
    }
end

-- Update source configuration without switching sources
function CaptureEngine:updateSourceConfig(config)
    if not self.current_source then
        return false, "No source currently set"
    end
    
    -- Merge new config with existing
    for key, value in pairs(config) do
        self.source_config[key] = value
    end
    
    -- Apply configuration changes to current source
    if self.current_source == SOURCE_TYPES.SCREEN and self.screen_capture then
        return self:_applyScreenConfig(config)
    elseif self.current_source == SOURCE_TYPES.WINDOW and self.window_capture then
        return self:_applyWindowConfig(config)
    elseif self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        return self:_applyWebcamConfig(config)
    end
    
    return true
end

-- Apply screen capture configuration changes
function CaptureEngine:_applyScreenConfig(config)
    if config.mode then
        local success, err = self.screen_capture:setMode(config.mode)
        if not success then
            return false, err
        end
    end
    
    if config.region then
        local r = config.region
        local success, err = self.screen_capture:setRegion(r.x, r.y, r.width, r.height)
        if not success then
            return false, err
        end
    end
    
    if config.monitor_index then
        local success, err = self.screen_capture:setMonitor(config.monitor_index)
        if not success then
            return false, err
        end
    end
    
    return true
end

-- Apply window capture configuration changes
function CaptureEngine:_applyWindowConfig(config)
    if config.window then
        local success, err = self.window_capture:setTargetWindow(config.window)
        if not success then
            return false, err
        end
    end
    
    if config.tracking ~= nil then
        self.window_capture:setTracking(config.tracking)
    end
    
    if config.capture_borders ~= nil then
        self.window_capture:setBorderCapture(config.capture_borders)
    end
    
    if config.auto_retry ~= nil then
        self.window_capture:setAutoRetry(config.auto_retry, config.max_retries)
    end
    
    if config.dpi_aware ~= nil then
        local success = self.window_capture:setDPIAware(config.dpi_aware)
        if not success then
            return false, self.window_capture:getLastError()
        end
    end
    
    return true
end

-- Apply webcam capture configuration changes
function CaptureEngine:_applyWebcamConfig(config)
    if config.device_index ~= nil then
        local success, err = self.webcam_capture:setDevice(config.device_index)
        if not success then
            return false, err
        end
    end
    
    if config.resolution then
        local r = config.resolution
        local success, err = self.webcam_capture:setResolution(r.width, r.height)
        if not success then
            return false, err
        end
    end
    
    if config.frame_rate then
        local success, err = self.webcam_capture:setFrameRate(config.frame_rate)
        if not success then
            return false, err
        end
    end
    
    return true
end

-- Get last error message
function CaptureEngine:getLastError()
    return self.last_error
end

-- Clear error state
function CaptureEngine:clearError()
    self.last_error = nil
end

-- Export source types for external use
CaptureEngine.SOURCE_TYPES = SOURCE_TYPES

return CaptureEngine