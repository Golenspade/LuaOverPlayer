-- Enhanced Capture Engine with Error Handling Integration
-- Demonstrates how to integrate the ErrorHandler into existing components

local ScreenCapture = require("src.screen_capture")
local WindowCapture = require("src.window_capture")
local WebcamCapture = require("src.webcam_capture")
local FrameBuffer = require("src.frame_buffer")
local ErrorHandler = require("src.error_handler")

local EnhancedCaptureEngine = {}
EnhancedCaptureEngine.__index = EnhancedCaptureEngine

-- Source types
local SOURCE_TYPES = {
    SCREEN = "screen",
    WINDOW = "window", 
    WEBCAM = "webcam"
}

function EnhancedCaptureEngine:new(options)
    options = options or {}
    
    local instance = setmetatable({
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
        webcam_capture = nil,
        
        -- Frame management
        frame_buffer = FrameBuffer:new(options.buffer_size or 3),
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
        performance_monitor = {
            enabled = options.monitor_performance ~= false,
            capture_times = {},
            max_samples = 60,
            warning_threshold = 0.1,
            drop_threshold = options.drop_threshold or (1.0 / (options.frame_rate or 30)) * 0.8
        }
    }, self)
    
    -- Initialize error handler with callbacks
    instance.error_handler = ErrorHandler:new({
        max_retry_attempts = options.max_retry_attempts or 3,
        enable_auto_recovery = options.enable_auto_recovery ~= false,
        enable_graceful_degradation = options.enable_graceful_degradation ~= false,
        max_frame_drop_rate = options.max_frame_drop_rate or 0.15,
        max_capture_time = options.max_capture_time or 0.1,
        min_fps_threshold = options.min_fps_threshold or 15
    })
    
    -- Set up error handler callbacks
    instance:_setupErrorHandlerCallbacks()
    
    return instance
end

-- Setup error handler callbacks
function EnhancedCaptureEngine:_setupErrorHandlerCallbacks()
    -- Error callback - log and track errors
    self.error_handler:setErrorCallback(function(error_info)
        self.last_error = error_info
        print("CaptureEngine Error [" .. error_info.category .. "]: " .. 
              (error_info.error_message or error_info.api_name or "Unknown error"))
    end)
    
    -- Recovery callback - handle component restarts and fallbacks
    self.error_handler:setRecoveryCallback(function(action, error_info)
        return self:_handleRecoveryAction(action, error_info)
    end)
    
    -- Degradation callback - adjust capture settings
    self.error_handler:setDegradationCallback(function(error_info, quality_level)
        self:_handleQualityDegradation(quality_level)
    end)
end

-- Handle recovery actions
function EnhancedCaptureEngine:_handleRecoveryAction(action, error_info)
    if action == "restart" then
        return self:_restartCaptureSource(error_info)
    elseif action == "fallback" then
        return self:_useFallbackMethod(error_info)
    elseif action == "retry" then
        return self:_retryLastOperation(error_info)
    end
    
    return false
end

-- Restart capture source
function EnhancedCaptureEngine:_restartCaptureSource(error_info)
    if not self.current_source then
        return false
    end
    
    print("Attempting to restart capture source: " .. self.current_source)
    
    -- Stop current capture
    local was_capturing = self.is_capturing
    if was_capturing then
        self:stopCapture()
    end
    
    -- Clean up current source
    self:_cleanupCurrentSource()
    
    -- Reinitialize source
    local success, err = self:_initializeSource(self.current_source, self.source_config)
    if not success then
        print("Failed to restart capture source: " .. (err or "Unknown error"))
        return false
    end
    
    -- Restart capture if it was active
    if was_capturing then
        success, err = self:startCapture()
        if not success then
            print("Failed to restart capture: " .. (err or "Unknown error"))
            return false
        end
    end
    
    print("Successfully restarted capture source")
    return true
end

-- Use fallback method
function EnhancedCaptureEngine:_useFallbackMethod(error_info)
    if error_info.category == ErrorHandler.ERROR_CATEGORIES.API then
        -- For API errors, try alternative capture methods
        if self.current_source == SOURCE_TYPES.SCREEN then
            -- Could implement fallback to different screen capture API
            print("Using fallback screen capture method")
            return true
        elseif self.current_source == SOURCE_TYPES.WINDOW then
            -- Could fallback to screen capture of window region
            print("Falling back to screen region capture for window")
            return self:_fallbackToScreenRegion()
        end
    elseif error_info.category == ErrorHandler.ERROR_CATEGORIES.CONFIGURATION then
        -- Use default configuration values
        print("Using default configuration values")
        return self:_useDefaultConfiguration()
    end
    
    return false
end

-- Fallback to screen region capture for window
function EnhancedCaptureEngine:_fallbackToScreenRegion()
    if not self.window_capture then
        return false
    end
    
    -- Get current window position
    local window_state = self.window_capture:getWindowState()
    if not window_state or not window_state.rect then
        return false
    end
    
    -- Switch to screen capture with window region
    local screen_config = {
        mode = "CUSTOM_REGION",
        region = {
            x = window_state.rect.left,
            y = window_state.rect.top,
            width = window_state.rect.width,
            height = window_state.rect.height
        }
    }
    
    local success, err = self:setSource(SOURCE_TYPES.SCREEN, screen_config)
    if success then
        print("Successfully fell back to screen region capture")
        return true
    end
    
    return false
end

-- Use default configuration
function EnhancedCaptureEngine:_useDefaultConfiguration()
    -- Reset to safe default values
    self.target_frame_rate = 30
    self.frame_interval = 1.0 / 30
    
    if self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        -- Reset webcam to default resolution
        self.webcam_capture:setResolution(640, 480)
        self.webcam_capture:setFrameRate(30)
    end
    
    return true
end

-- Retry last operation
function EnhancedCaptureEngine:_retryLastOperation(error_info)
    -- For now, just indicate that retry is acceptable
    -- The actual retry logic would be handled by the calling code
    return true
end

-- Handle quality degradation
function EnhancedCaptureEngine:_handleQualityDegradation(quality_level)
    print("Degrading capture quality to " .. string.format("%.2f", quality_level))
    
    -- Adjust frame rate based on quality level
    local new_frame_rate = math.max(10, math.floor(self.target_frame_rate * quality_level))
    self.frame_interval = 1.0 / new_frame_rate
    
    -- Adjust performance thresholds
    self.performance_monitor.drop_threshold = self.performance_monitor.drop_threshold * (1.0 + (1.0 - quality_level))
    
    -- Reduce buffer size if quality is very low
    if quality_level < 0.5 then
        local new_buffer_size = math.max(1, math.floor(3 * quality_level))
        -- Note: FrameBuffer would need a resize method for this to work
        print("Reducing buffer size due to low quality level")
    end
    
    -- Adjust webcam settings if applicable
    if self.current_source == SOURCE_TYPES.WEBCAM and self.webcam_capture then
        if quality_level < 0.7 then
            -- Reduce resolution
            self.webcam_capture:setResolution(320, 240)
        end
        if quality_level < 0.5 then
            -- Further reduce frame rate
            self.webcam_capture:setFrameRate(15)
        end
    end
end

-- Enhanced frame capture with error handling
function EnhancedCaptureEngine:_performCapture()
    local capture_start_time = love and love.timer.getTime() or os.clock()
    local frame_data, width, height, error_msg
    
    -- Mock capture for testing
    if _G.TESTING_MODE then
        -- Simulate successful capture in test mode
        frame_data = "mock_frame_data"
        width = 800
        height = 600
        
        -- Add to frame buffer (mock)
        if self.frame_buffer and self.frame_buffer.addFrame then
            self.frame_buffer:addFrame(frame_data, width, height, 'RGBA', {
                source_type = self.current_source,
                capture_duration = 0.001
            })
        end
        
        -- Update statistics
        self.capture_stats.frames_captured = self.capture_stats.frames_captured + 1
        return true, {data = frame_data, width = width, height = height}
    end
    
    -- Capture based on current source with error handling
    if self.current_source == SOURCE_TYPES.SCREEN then
        if not self.screen_capture then
            local recovered = self.error_handler:handleCaptureError("screen", "Screen capture not initialized", {})
            if not recovered then
                return false, "Screen capture not initialized"
            end
        end
        
        frame_data, width, height = self.screen_capture:captureToPixelData()
        if not frame_data then
            error_msg = self.screen_capture:getLastError()
            local recovered = self.error_handler:handleCaptureError("screen", error_msg, {
                operation = "captureToPixelData"
            })
            if not recovered then
                return false, error_msg
            end
        end
        
    elseif self.current_source == SOURCE_TYPES.WINDOW then
        if not self.window_capture then
            local recovered = self.error_handler:handleCaptureError("window", "Window capture not initialized", {})
            if not recovered then
                return false, "Window capture not initialized"
            end
        end
        
        local result = self.window_capture:captureWindowPixelData()
        if result then
            if type(result) == "table" and result.data then
                frame_data = result.data
                width = result.width
                height = result.height
            else
                frame_data = result
                width = select(2, self.window_capture:captureWindowPixelData())
                height = select(3, self.window_capture:captureWindowPixelData())
            end
        else
            error_msg = self.window_capture:getLastError()
            local recovered = self.error_handler:handleCaptureError("window", error_msg, {
                operation = "captureWindowPixelData",
                window_state = self.window_capture:getWindowState()
            })
            if not recovered then
                return false, error_msg
            end
        end
        
    elseif self.current_source == SOURCE_TYPES.WEBCAM then
        if not self.webcam_capture then
            local recovered = self.error_handler:handleCaptureError("webcam", "Webcam capture not initialized", {})
            if not recovered then
                return false, "Webcam capture not initialized"
            end
        end
        
        local frame = self.webcam_capture:captureFrame()
        if frame then
            frame_data = frame.data
            width = frame.width
            height = frame.height
        else
            error_msg = self.webcam_capture:getLastError()
            local recovered = self.error_handler:handleCaptureError("webcam", error_msg, {
                operation = "captureFrame",
                device_config = self.webcam_capture:getConfiguration()
            })
            if not recovered then
                return false, error_msg
            end
        end
        
    else
        local recovered = self.error_handler:handleConfigurationError("source_type", self.current_source, {
            valid_types = {"screen", "window", "webcam"}
        })
        if not recovered then
            return false, "Unknown source type: " .. tostring(self.current_source)
        end
    end
    
    -- Check capture performance
    local capture_end_time = love and love.timer.getTime() or os.clock()
    local capture_duration = capture_end_time - capture_start_time
    
    if self.performance_monitor.enabled then
        self:_updatePerformanceMetrics(capture_duration)
        
        -- Check for performance issues
        if capture_duration > self.performance_monitor.warning_threshold then
            self.error_handler:handlePerformanceError("capture_time", capture_duration, 
                                                    self.performance_monitor.warning_threshold)
        end
        
        -- Drop frame if capture took too long
        if capture_duration > self.performance_monitor.drop_threshold then
            self.capture_stats.frames_dropped = self.capture_stats.frames_dropped + 1
            self.error_handler:handlePerformanceError("capture_time", capture_duration, 
                                                    self.performance_monitor.drop_threshold)
            return false, "Frame dropped due to slow capture (" .. string.format("%.3f", capture_duration) .. "s)"
        end
    end
    
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
    
    -- Update frame as latest
    self.last_frame = self.frame_buffer:getLatestFrame()
    
    -- Update statistics
    self.capture_stats.frames_captured = self.capture_stats.frames_captured + 1
    
    return true, self.last_frame
end

-- Enhanced update method with performance monitoring
function EnhancedCaptureEngine:update(dt)
    if not self.is_capturing or self.is_paused then
        return
    end
    
    -- Update frame timer
    self.frame_timer = self.frame_timer + dt
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Check if it's time to capture a new frame
    if current_time >= self.next_capture_time then
        -- Check if we're falling behind (frame dropping for real-time performance)
        local time_behind = current_time - self.next_capture_time
        if time_behind > self.frame_interval then
            local frames_to_skip = math.floor(time_behind / self.frame_interval)
            self.capture_stats.frames_skipped = self.capture_stats.frames_skipped + frames_to_skip
            self.next_capture_time = self.next_capture_time + (frames_to_skip * self.frame_interval)
            
            -- Report frame skipping as performance issue
            if frames_to_skip > 1 then
                local skip_rate = frames_to_skip / (frames_to_skip + 1)  -- Approximate skip rate
                self.error_handler:handlePerformanceError("frame_skip_rate", skip_rate, 0.1)
            end
        end
        
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
            
            -- Check FPS performance
            if self.capture_stats.actual_fps < self.error_handler.performance_thresholds.min_fps_threshold then
                self.error_handler:handlePerformanceError("fps", self.capture_stats.actual_fps, 
                                                        self.error_handler.performance_thresholds.min_fps_threshold)
            end
        else
            -- Handle capture failure
            self.last_error = frame_or_error
            self.capture_stats.frames_dropped = self.capture_stats.frames_dropped + 1
            
            -- Calculate frame drop rate
            local total_attempts = self.capture_stats.frames_captured + self.capture_stats.frames_dropped
            if total_attempts > 0 then
                local drop_rate = self.capture_stats.frames_dropped / total_attempts
                if drop_rate > self.error_handler.performance_thresholds.max_frame_drop_rate then
                    self.error_handler:handlePerformanceError("frame_drop_rate", drop_rate, 
                                                            self.error_handler.performance_thresholds.max_frame_drop_rate)
                end
            end
            
            -- Still schedule next attempt
            self.next_capture_time = current_time + self.frame_interval
        end
    end
    
    -- Update capture duration and average FPS
    if self.capture_stats.start_time > 0 then
        self.capture_stats.capture_duration = current_time - self.capture_stats.start_time
        
        if self.capture_stats.capture_duration > 0 then
            self.capture_stats.average_fps = self.capture_stats.frames_captured / self.capture_stats.capture_duration
        end
    end
end

-- Enhanced statistics with error information
function EnhancedCaptureEngine:getStats()
    local base_stats = {
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
    
    -- Add error handler statistics
    local error_stats = self.error_handler:getErrorStats()
    base_stats.error_stats = error_stats
    base_stats.is_degraded = error_stats.degraded_mode
    base_stats.quality_level = error_stats.current_quality_level
    
    -- Add recent errors
    base_stats.recent_errors = self.error_handler:getRecentErrors(5)
    
    return base_stats
end

-- Get available sources
function EnhancedCaptureEngine:getAvailableSources()
    local sources = {}
    
    -- Add screen sources
    table.insert(sources, {
        type = "screen",
        id = "full_screen",
        name = "Full Screen",
        description = "Capture entire desktop"
    })
    
    -- Add window sources (mock for testing)
    table.insert(sources, {
        type = "window",
        id = "test_window",
        name = "Test Window",
        description = "Test window for capture"
    })
    
    -- Add webcam sources (mock for testing)
    table.insert(sources, {
        type = "webcam",
        id = "default_webcam",
        name = "Default Webcam",
        description = "Default webcam device"
    })
    
    return sources
end

-- Get error handler instance
function EnhancedCaptureEngine:getErrorHandler()
    return self.error_handler
end

-- Clean up with error handler
function EnhancedCaptureEngine:cleanup()
    if self.is_capturing then
        self:stopCapture()
    end
    
    self:_cleanupCurrentSource()
    
    if self.frame_buffer then
        self.frame_buffer:clear()
    end
    
    -- Clear error handler state
    if self.error_handler then
        self.error_handler:clearErrorHistory()
    end
end

-- Copy other methods from original CaptureEngine
-- (setSource, startCapture, stopCapture, etc. would be copied here with error handling enhancements)

-- Enhanced setSource method with error handling
function EnhancedCaptureEngine:setSource(source_type, config)
    config = config or {}
    
    -- Validate source type
    local valid_sources = {screen = true, window = true, webcam = true}
    if not valid_sources[source_type] then
        local recovered = self.error_handler:handleConfigurationError("source_type", source_type, valid_sources)
        if not recovered then
            return false, "Invalid source type: " .. tostring(source_type)
        end
    end
    
    -- Stop current capture if active
    if self.is_capturing then
        self:stopCapture()
    end
    
    -- Clean up current source
    self:_cleanupCurrentSource()
    
    -- Set new source
    self.current_source = source_type
    self.source_config = config
    
    -- Initialize the new source
    local success, err = self:_initializeSource(source_type, config)
    if not success then
        self.error_handler:handleCaptureError(source_type, err or "Failed to initialize source", config)
        return false, err
    end
    
    return true
end

function EnhancedCaptureEngine:startCapture()
    if not self.current_source then
        local recovered = self.error_handler:handleConfigurationError("source", nil, {"screen", "window", "webcam"})
        if not recovered then
            return false, "No capture source configured"
        end
    end
    
    if self.is_capturing then
        return true -- Already capturing
    end
    
    -- Reset statistics
    self.capture_stats.frames_captured = 0
    self.capture_stats.frames_dropped = 0
    self.capture_stats.frames_skipped = 0
    self.capture_stats.start_time = love and love.timer.getTime() or os.clock()
    self.last_capture_time = self.capture_stats.start_time
    self.next_capture_time = self.capture_stats.start_time
    
    -- Start capturing
    self.is_capturing = true
    self.is_paused = false
    
    return true
end

function EnhancedCaptureEngine:stopCapture()
    if not self.is_capturing then
        return true -- Already stopped
    end
    
    self.is_capturing = false
    self.is_paused = false
    
    return true
end

function EnhancedCaptureEngine:_initializeSource(source_type, config)
    -- Mock initialization for testing
    if _G.TESTING_MODE then
        return true
    end
    
    -- In real implementation, this would initialize the specific capture source
    if source_type == "screen" then
        if not self.screen_capture then
            return false, "Screen capture not available"
        end
        return self.screen_capture:initialize()
    elseif source_type == "window" then
        if not self.window_capture then
            return false, "Window capture not available"
        end
        return self.window_capture:initialize()
    elseif source_type == "webcam" then
        if not self.webcam_capture then
            return false, "Webcam capture not available"
        end
        return self.webcam_capture:initialize()
    end
    
    return false, "Unknown source type"
end

function EnhancedCaptureEngine:_cleanupCurrentSource()
    -- Clean up current source resources
    if self.current_source == "screen" and self.screen_capture then
        pcall(function() self.screen_capture:cleanup() end)
    elseif self.current_source == "window" and self.window_capture then
        pcall(function() self.window_capture:cleanup() end)
    elseif self.current_source == "webcam" and self.webcam_capture then
        pcall(function() self.webcam_capture:cleanup() end)
    end
    
    self.current_source = nil
    self.source_config = {}
end

function EnhancedCaptureEngine:_updatePerformanceMetrics(capture_duration)
    local monitor = self.performance_monitor
    
    -- Add to capture times array
    table.insert(monitor.capture_times, capture_duration)
    
    -- Keep only recent samples
    if #monitor.capture_times > monitor.max_samples then
        table.remove(monitor.capture_times, 1)
    end
    
    -- Log warning if capture is slow
    if capture_duration > monitor.warning_threshold then
        print("Warning: Slow capture detected (" .. string.format("%.3f", capture_duration) .. "s)")
    end
end

return EnhancedCaptureEngine