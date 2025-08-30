-- Performance Monitor - Real-time performance metrics collection and optimization
-- Handles FPS monitoring, memory usage tracking, and frame dropping mechanisms

local PerformanceMonitor = {}
PerformanceMonitor.__index = PerformanceMonitor

-- Performance thresholds and constants
local PERFORMANCE_CONSTANTS = {
    -- Frame rate thresholds
    TARGET_FPS_TOLERANCE = 0.9,  -- Drop frames if actual FPS < target * tolerance
    CRITICAL_FPS_THRESHOLD = 15, -- Critical performance threshold
    
    -- Memory thresholds (in MB)
    MEMORY_WARNING_THRESHOLD = 100,
    MEMORY_CRITICAL_THRESHOLD = 200,
    
    -- Timing thresholds (in seconds)
    FRAME_TIME_WARNING = 0.05,   -- 50ms per frame (20 FPS)
    FRAME_TIME_CRITICAL = 0.1,   -- 100ms per frame (10 FPS)
    
    -- Sample sizes for averaging
    FPS_SAMPLE_SIZE = 60,        -- 60 samples for FPS averaging
    MEMORY_SAMPLE_SIZE = 30,     -- 30 samples for memory averaging
    FRAME_TIME_SAMPLE_SIZE = 60, -- 60 samples for frame time averaging
    
    -- Update intervals
    MEMORY_UPDATE_INTERVAL = 1.0, -- Update memory stats every second
    STATS_UPDATE_INTERVAL = 0.1   -- Update performance stats 10 times per second
}

function PerformanceMonitor:new(options)
    options = options or {}
    
    return setmetatable({
        -- Configuration
        enabled = options.enabled ~= false,
        target_fps = options.target_fps or 30,
        frame_drop_enabled = options.frame_drop_enabled ~= false,
        memory_monitoring = options.memory_monitoring ~= false,
        
        -- Performance metrics
        metrics = {
            -- Frame rate metrics
            current_fps = 0,
            average_fps = 0,
            min_fps = math.huge,
            max_fps = 0,
            
            -- Frame timing
            frame_time = 0,
            average_frame_time = 0,
            min_frame_time = math.huge,
            max_frame_time = 0,
            
            -- Memory usage (in MB)
            current_memory = 0,
            average_memory = 0,
            peak_memory = 0,
            
            -- Frame statistics
            frames_processed = 0,
            frames_dropped = 0,
            frames_skipped = 0,
            
            -- Performance warnings
            warning_count = 0,
            critical_count = 0
        },
        
        -- Sample arrays for averaging
        samples = {
            fps = {},
            frame_times = {},
            memory = {}
        },
        
        -- Timing data
        timing = {
            last_frame_time = 0,
            last_memory_update = 0,
            last_stats_update = 0,
            session_start_time = 0,
            total_session_time = 0
        },
        
        -- Frame dropping logic
        frame_dropping = {
            consecutive_slow_frames = 0,
            drop_threshold = 3,  -- Drop after 3 consecutive slow frames
            recovery_threshold = 10, -- Stop dropping after 10 good frames
            currently_dropping = false,
            drop_ratio = 0.5  -- Drop every other frame when dropping
        },
        
        -- Performance state
        performance_state = "good", -- "good", "warning", "critical"
        last_performance_check = 0,
        
        -- Callbacks for performance events
        callbacks = {
            on_performance_warning = options.on_performance_warning,
            on_performance_critical = options.on_performance_critical,
            on_frame_drop_start = options.on_frame_drop_start,
            on_frame_drop_stop = options.on_frame_drop_stop
        }
    }, self)
end

-- Initialize performance monitoring
function PerformanceMonitor:initialize()
    if not self.enabled then
        return true
    end
    
    -- Reset all metrics
    self:reset()
    
    -- Initialize timing
    local current_time = love and love.timer.getTime() or os.clock()
    self.timing.session_start_time = current_time
    self.timing.last_frame_time = current_time
    self.timing.last_memory_update = current_time
    self.timing.last_stats_update = current_time
    
    return true
end

-- Reset all performance metrics
function PerformanceMonitor:reset()
    -- Reset metrics
    self.metrics.current_fps = 0
    self.metrics.average_fps = 0
    self.metrics.min_fps = math.huge
    self.metrics.max_fps = 0
    
    self.metrics.frame_time = 0
    self.metrics.average_frame_time = 0
    self.metrics.min_frame_time = math.huge
    self.metrics.max_frame_time = 0
    
    self.metrics.current_memory = 0
    self.metrics.average_memory = 0
    self.metrics.peak_memory = 0
    
    self.metrics.frames_processed = 0
    self.metrics.frames_dropped = 0
    self.metrics.frames_skipped = 0
    
    self.metrics.warning_count = 0
    self.metrics.critical_count = 0
    
    -- Clear sample arrays
    self.samples.fps = {}
    self.samples.frame_times = {}
    self.samples.memory = {}
    
    -- Reset frame dropping state
    self.frame_dropping.consecutive_slow_frames = 0
    self.frame_dropping.currently_dropping = false
    
    -- Reset performance state
    self.performance_state = "good"
end

-- Update performance metrics (called each frame)
function PerformanceMonitor:update(dt)
    if not self.enabled then
        return
    end
    
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Update frame timing
    self:_updateFrameTiming(current_time, dt)
    
    -- Update memory usage periodically
    if current_time - self.timing.last_memory_update >= PERFORMANCE_CONSTANTS.MEMORY_UPDATE_INTERVAL then
        self:_updateMemoryUsage(current_time)
    end
    
    -- Update performance statistics periodically
    if current_time - self.timing.last_stats_update >= PERFORMANCE_CONSTANTS.STATS_UPDATE_INTERVAL then
        self:_updatePerformanceStats(current_time)
    end
    
    -- Check for performance issues
    self:_checkPerformanceThresholds()
    
    -- Update total session time
    self.timing.total_session_time = current_time - self.timing.session_start_time
end

-- Update frame timing metrics
function PerformanceMonitor:_updateFrameTiming(current_time, dt)
    -- Calculate frame time
    local frame_time = current_time - self.timing.last_frame_time
    self.timing.last_frame_time = current_time
    
    -- Update frame time metrics
    self.metrics.frame_time = frame_time
    self.metrics.min_frame_time = math.min(self.metrics.min_frame_time, frame_time)
    self.metrics.max_frame_time = math.max(self.metrics.max_frame_time, frame_time)
    
    -- Add to frame time samples
    table.insert(self.samples.frame_times, frame_time)
    if #self.samples.frame_times > PERFORMANCE_CONSTANTS.FRAME_TIME_SAMPLE_SIZE then
        table.remove(self.samples.frame_times, 1)
    end
    
    -- Calculate average frame time
    if #self.samples.frame_times > 0 then
        local total_time = 0
        for _, time in ipairs(self.samples.frame_times) do
            total_time = total_time + time
        end
        self.metrics.average_frame_time = total_time / #self.samples.frame_times
    end
    
    -- Calculate FPS from frame time
    if frame_time > 0 then
        local current_fps = 1.0 / frame_time
        -- Cap FPS at reasonable maximum (1000 FPS) to avoid calculation issues
        current_fps = math.min(current_fps, 1000)
        
        self.metrics.current_fps = current_fps
        self.metrics.min_fps = math.min(self.metrics.min_fps, current_fps)
        self.metrics.max_fps = math.max(self.metrics.max_fps, current_fps)
        
        -- Add to FPS samples
        table.insert(self.samples.fps, current_fps)
        if #self.samples.fps > PERFORMANCE_CONSTANTS.FPS_SAMPLE_SIZE then
            table.remove(self.samples.fps, 1)
        end
        
        -- Calculate average FPS
        if #self.samples.fps > 0 then
            local total_fps = 0
            for _, fps in ipairs(self.samples.fps) do
                total_fps = total_fps + fps
            end
            self.metrics.average_fps = total_fps / #self.samples.fps
        end
    end
    
    self.metrics.frames_processed = self.metrics.frames_processed + 1
end

-- Update memory usage metrics
function PerformanceMonitor:_updateMemoryUsage(current_time)
    self.timing.last_memory_update = current_time
    
    if not self.memory_monitoring then
        return
    end
    
    -- Get current memory usage
    local memory_kb = collectgarbage("count")
    local memory_mb = memory_kb / 1024
    
    self.metrics.current_memory = memory_mb
    self.metrics.peak_memory = math.max(self.metrics.peak_memory, memory_mb)
    
    -- Add to memory samples
    table.insert(self.samples.memory, memory_mb)
    if #self.samples.memory > PERFORMANCE_CONSTANTS.MEMORY_SAMPLE_SIZE then
        table.remove(self.samples.memory, 1)
    end
    
    -- Calculate average memory usage
    if #self.samples.memory > 0 then
        local total_memory = 0
        for _, memory in ipairs(self.samples.memory) do
            total_memory = total_memory + memory
        end
        self.metrics.average_memory = total_memory / #self.samples.memory
    end
end

-- Update performance statistics
function PerformanceMonitor:_updatePerformanceStats(current_time)
    self.timing.last_stats_update = current_time
    
    -- Update performance state based on current metrics
    local old_state = self.performance_state
    
    if self.metrics.current_fps < PERFORMANCE_CONSTANTS.CRITICAL_FPS_THRESHOLD or
       self.metrics.frame_time > PERFORMANCE_CONSTANTS.FRAME_TIME_CRITICAL or
       self.metrics.current_memory > PERFORMANCE_CONSTANTS.MEMORY_CRITICAL_THRESHOLD then
        self.performance_state = "critical"
        self.metrics.critical_count = self.metrics.critical_count + 1
    elseif self.metrics.current_fps < self.target_fps * PERFORMANCE_CONSTANTS.TARGET_FPS_TOLERANCE or
           self.metrics.frame_time > PERFORMANCE_CONSTANTS.FRAME_TIME_WARNING or
           self.metrics.current_memory > PERFORMANCE_CONSTANTS.MEMORY_WARNING_THRESHOLD then
        self.performance_state = "warning"
        self.metrics.warning_count = self.metrics.warning_count + 1
    else
        self.performance_state = "good"
    end
    
    -- Trigger callbacks on state changes
    if old_state ~= self.performance_state then
        if self.performance_state == "warning" and self.callbacks.on_performance_warning then
            self.callbacks.on_performance_warning(self:getMetrics())
        elseif self.performance_state == "critical" and self.callbacks.on_performance_critical then
            self.callbacks.on_performance_critical(self:getMetrics())
        end
    end
end

-- Check performance thresholds and manage frame dropping
function PerformanceMonitor:_checkPerformanceThresholds()
    if not self.frame_drop_enabled then
        return
    end
    
    local should_drop = false
    
    -- Check if current performance is below threshold
    if self.metrics.frame_time > PERFORMANCE_CONSTANTS.FRAME_TIME_WARNING or
       self.metrics.current_fps < self.target_fps * PERFORMANCE_CONSTANTS.TARGET_FPS_TOLERANCE then
        self.frame_dropping.consecutive_slow_frames = self.frame_dropping.consecutive_slow_frames + 1
        
        if self.frame_dropping.consecutive_slow_frames >= self.frame_dropping.drop_threshold then
            should_drop = true
        end
    else
        -- Performance is good, reset counter
        if self.frame_dropping.consecutive_slow_frames > 0 then
            self.frame_dropping.consecutive_slow_frames = math.max(0, self.frame_dropping.consecutive_slow_frames - 1)
        end
    end
    
    -- Update frame dropping state
    if should_drop and not self.frame_dropping.currently_dropping then
        self.frame_dropping.currently_dropping = true
        if self.callbacks.on_frame_drop_start then
            self.callbacks.on_frame_drop_start(self:getMetrics())
        end
    elseif not should_drop and self.frame_dropping.currently_dropping then
        self.frame_dropping.currently_dropping = false
        if self.callbacks.on_frame_drop_stop then
            self.callbacks.on_frame_drop_stop(self:getMetrics())
        end
    end
end

-- Check if current frame should be dropped for performance
function PerformanceMonitor:shouldDropFrame()
    if not self.enabled or not self.frame_drop_enabled then
        return false
    end
    
    if not self.frame_dropping.currently_dropping then
        return false
    end
    
    -- Simple frame dropping strategy: drop every other frame
    local should_drop = (self.metrics.frames_processed % 2) == 0
    
    if should_drop then
        self.metrics.frames_dropped = self.metrics.frames_dropped + 1
    end
    
    return should_drop
end

-- Record a skipped frame (when capture timing causes frame skip)
function PerformanceMonitor:recordSkippedFrame()
    if self.enabled then
        self.metrics.frames_skipped = self.metrics.frames_skipped + 1
    end
end

-- Get current performance metrics
function PerformanceMonitor:getMetrics()
    return {
        -- Current state
        enabled = self.enabled,
        performance_state = self.performance_state,
        
        -- Frame rate metrics
        current_fps = self.metrics.current_fps,
        average_fps = self.metrics.average_fps,
        target_fps = self.target_fps,
        min_fps = self.metrics.min_fps == math.huge and 0 or self.metrics.min_fps,
        max_fps = self.metrics.max_fps,
        
        -- Frame timing
        frame_time = self.metrics.frame_time,
        average_frame_time = self.metrics.average_frame_time,
        min_frame_time = self.metrics.min_frame_time == math.huge and 0 or self.metrics.min_frame_time,
        max_frame_time = self.metrics.max_frame_time,
        
        -- Memory usage
        current_memory = self.metrics.current_memory,
        average_memory = self.metrics.average_memory,
        peak_memory = self.metrics.peak_memory,
        
        -- Frame statistics
        frames_processed = self.metrics.frames_processed,
        frames_dropped = self.metrics.frames_dropped,
        frames_skipped = self.metrics.frames_skipped,
        
        -- Performance issues
        warning_count = self.metrics.warning_count,
        critical_count = self.metrics.critical_count,
        
        -- Frame dropping state
        frame_dropping_active = self.frame_dropping.currently_dropping,
        consecutive_slow_frames = self.frame_dropping.consecutive_slow_frames,
        
        -- Session info
        session_time = self.timing.total_session_time,
        
        -- Calculated metrics
        drop_rate = self.metrics.frames_processed > 0 and 
                   (self.metrics.frames_dropped / self.metrics.frames_processed) * 100 or 0,
        skip_rate = self.metrics.frames_processed > 0 and 
                   (self.metrics.frames_skipped / self.metrics.frames_processed) * 100 or 0
    }
end

-- Get performance summary for display
function PerformanceMonitor:getPerformanceSummary()
    local metrics = self:getMetrics()
    
    return {
        fps = string.format("%.1f", metrics.current_fps),
        avg_fps = string.format("%.1f", metrics.average_fps),
        frame_time = string.format("%.1f ms", metrics.frame_time * 1000),
        memory = string.format("%.1f MB", metrics.current_memory),
        state = metrics.performance_state,
        drops = metrics.frames_dropped,
        skips = metrics.frames_skipped,
        drop_rate = string.format("%.1f%%", metrics.drop_rate),
        session_time = string.format("%.1f s", metrics.session_time)
    }
end

-- Set target frame rate
function PerformanceMonitor:setTargetFPS(fps)
    if fps > 0 and fps <= 120 then
        self.target_fps = fps
        return true
    end
    return false
end

-- Enable/disable frame dropping
function PerformanceMonitor:setFrameDropEnabled(enabled)
    self.frame_drop_enabled = enabled
    if not enabled then
        self.frame_dropping.currently_dropping = false
        self.frame_dropping.consecutive_slow_frames = 0
    end
end

-- Enable/disable memory monitoring
function PerformanceMonitor:setMemoryMonitoring(enabled)
    self.memory_monitoring = enabled
    if not enabled then
        self.metrics.current_memory = 0
        self.metrics.average_memory = 0
        self.metrics.peak_memory = 0
        self.samples.memory = {}
    end
end

-- Force garbage collection and return memory freed
function PerformanceMonitor:forceGarbageCollection()
    if not self.memory_monitoring then
        return 0
    end
    
    local before = collectgarbage("count")
    collectgarbage("collect")
    local after = collectgarbage("count")
    
    local freed_kb = before - after
    local freed_mb = freed_kb / 1024
    
    -- Update current memory after GC
    self.metrics.current_memory = after / 1024
    
    return freed_mb
end

-- Get performance recommendations based on current state
function PerformanceMonitor:getPerformanceRecommendations()
    local recommendations = {}
    local metrics = self:getMetrics()
    
    if metrics.performance_state == "critical" then
        table.insert(recommendations, "Critical performance issues detected")
        
        if metrics.current_fps < 15 then
            table.insert(recommendations, "Consider reducing capture resolution or frame rate")
        end
        
        if metrics.current_memory > PERFORMANCE_CONSTANTS.MEMORY_CRITICAL_THRESHOLD then
            table.insert(recommendations, "High memory usage - consider reducing buffer size")
        end
        
        if metrics.frame_time > PERFORMANCE_CONSTANTS.FRAME_TIME_CRITICAL then
            table.insert(recommendations, "Frame processing is very slow - check system resources")
        end
        
    elseif metrics.performance_state == "warning" then
        table.insert(recommendations, "Performance warnings detected")
        
        if metrics.current_fps < metrics.target_fps * 0.8 then
            table.insert(recommendations, "Frame rate below target - consider optimizing settings")
        end
        
        if metrics.current_memory > PERFORMANCE_CONSTANTS.MEMORY_WARNING_THRESHOLD then
            table.insert(recommendations, "Memory usage is elevated - monitor for leaks")
        end
        
        if metrics.drop_rate > 5 then
            table.insert(recommendations, "High frame drop rate - consider reducing quality settings")
        end
        
    else
        table.insert(recommendations, "Performance is good")
        
        if metrics.average_fps > metrics.target_fps * 1.2 then
            table.insert(recommendations, "Performance headroom available - can increase quality")
        end
    end
    
    return recommendations
end

-- Enable/disable performance monitoring
function PerformanceMonitor:setEnabled(enabled)
    self.enabled = enabled
    if enabled then
        self:initialize()
    else
        self:reset()
    end
end

return PerformanceMonitor