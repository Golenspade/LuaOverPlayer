-- Error Handler - Comprehensive error management system
-- Provides categorized error handling, automatic recovery, and graceful degradation

local ErrorHandler = {}
ErrorHandler.__index = ErrorHandler

-- Error categories (Requirement 8.1)
local ERROR_CATEGORIES = {
    API = "api_error",           -- Windows API call failures
    RESOURCE = "resource_error", -- Memory allocation, device access
    PERFORMANCE = "performance_error", -- Frame drops, timeout issues
    CONFIGURATION = "configuration_error", -- Invalid settings, missing devices
    CAPTURE = "capture_error",   -- Capture-specific failures
    SYSTEM = "system_error"      -- System-level issues
}

-- Error severity levels
local ERROR_SEVERITY = {
    LOW = 1,      -- Minor issues, can continue normally
    MEDIUM = 2,   -- Moderate issues, may need adjustment
    HIGH = 3,     -- Serious issues, functionality impacted
    CRITICAL = 4  -- Critical issues, system may be unstable
}

-- Recovery strategies
local RECOVERY_STRATEGIES = {
    RETRY = "retry",                    -- Retry the operation
    FALLBACK = "fallback",             -- Use alternative method
    DEGRADE = "degrade",               -- Reduce quality/functionality
    RESTART = "restart",               -- Restart component
    NOTIFY_ONLY = "notify_only"        -- Just notify user, no action
}

function ErrorHandler:new(options)
    options = options or {}
    
    return setmetatable({
        -- Configuration
        max_retry_attempts = options.max_retry_attempts or 3,
        retry_delay = options.retry_delay or 1.0,
        enable_auto_recovery = options.enable_auto_recovery ~= false,
        enable_graceful_degradation = options.enable_graceful_degradation ~= false,
        log_errors = options.log_errors ~= false,
        
        -- Error tracking
        error_history = {},
        error_counts = {},
        last_errors = {},
        recovery_attempts = {},
        
        -- Performance thresholds
        performance_thresholds = {
            max_frame_drop_rate = options.max_frame_drop_rate or 0.1, -- 10%
            max_capture_time = options.max_capture_time or 0.1,       -- 100ms
            max_memory_usage = options.max_memory_usage or 500 * 1024 * 1024, -- 500MB
            min_fps_threshold = options.min_fps_threshold or 15
        },
        
        -- Recovery state
        degraded_mode = false,
        current_quality_level = 1.0,
        disabled_features = {},
        
        -- Callbacks
        error_callback = options.error_callback,
        recovery_callback = options.recovery_callback,
        degradation_callback = options.degradation_callback,
        
        -- Statistics
        stats = {
            total_errors = 0,
            recovered_errors = 0,
            unrecovered_errors = 0,
            degradation_events = 0,
            restart_events = 0
        }
    }, self)
end

-- Handle API errors (Requirement 8.1)
function ErrorHandler:handleAPIError(api_name, error_code, context)
    local error_info = {
        category = ERROR_CATEGORIES.API,
        api_name = api_name,
        error_code = error_code,
        context = context or {},
        timestamp = love and love.timer.getTime() or os.clock(),
        severity = self:_determineAPISeverity(api_name, error_code)
    }
    
    -- Log the error
    self:_logError(error_info)
    
    -- Determine recovery strategy
    local strategy = self:_getRecoveryStrategy(error_info)
    
    -- Attempt recovery
    local recovered = false
    if self.enable_auto_recovery then
        recovered = self:_attemptRecovery(error_info, strategy)
    end
    
    -- Update statistics
    self.stats.total_errors = self.stats.total_errors + 1
    if recovered then
        self.stats.recovered_errors = self.stats.recovered_errors + 1
    else
        self.stats.unrecovered_errors = self.stats.unrecovered_errors + 1
    end
    
    return recovered, error_info
end

-- Handle resource errors (Requirement 8.2)
function ErrorHandler:handleResourceError(resource_type, details, current_usage)
    local error_info = {
        category = ERROR_CATEGORIES.RESOURCE,
        resource_type = resource_type,
        details = details or {},
        current_usage = current_usage,
        timestamp = love and love.timer.getTime() or os.clock(),
        severity = self:_determineResourceSeverity(resource_type, current_usage)
    }
    
    self:_logError(error_info)
    
    local strategy = self:_getRecoveryStrategy(error_info)
    local recovered = false
    
    if self.enable_auto_recovery then
        recovered = self:_attemptRecovery(error_info, strategy)
    end
    
    -- If resource error is severe, consider degradation
    if not recovered and error_info.severity >= ERROR_SEVERITY.HIGH then
        if self.enable_graceful_degradation then
            self:_initiateGracefulDegradation(error_info)
        end
    end
    
    self.stats.total_errors = self.stats.total_errors + 1
    if recovered then
        self.stats.recovered_errors = self.stats.recovered_errors + 1
    else
        self.stats.unrecovered_errors = self.stats.unrecovered_errors + 1
    end
    
    return recovered, error_info
end

-- Handle performance errors (Requirement 8.3)
function ErrorHandler:handlePerformanceError(metric, current_value, threshold)
    local error_info = {
        category = ERROR_CATEGORIES.PERFORMANCE,
        metric = metric,
        current_value = current_value,
        threshold = threshold,
        timestamp = love and love.timer.getTime() or os.clock(),
        severity = self:_determinePerformanceSeverity(metric, current_value, threshold)
    }
    
    self:_logError(error_info)
    
    local strategy = self:_getRecoveryStrategy(error_info)
    local recovered = false
    
    if self.enable_auto_recovery then
        recovered = self:_attemptRecovery(error_info, strategy)
    end
    
    -- Performance issues often require degradation
    if not recovered and self.enable_graceful_degradation then
        self:_initiateGracefulDegradation(error_info)
    end
    
    self.stats.total_errors = self.stats.total_errors + 1
    if recovered then
        self.stats.recovered_errors = self.stats.recovered_errors + 1
    else
        self.stats.unrecovered_errors = self.stats.unrecovered_errors + 1
    end
    
    return recovered, error_info
end

-- Handle configuration errors
function ErrorHandler:handleConfigurationError(config_type, invalid_value, valid_range)
    local error_info = {
        category = ERROR_CATEGORIES.CONFIGURATION,
        config_type = config_type,
        invalid_value = invalid_value,
        valid_range = valid_range,
        timestamp = love and love.timer.getTime() or os.clock(),
        severity = ERROR_SEVERITY.MEDIUM
    }
    
    self:_logError(error_info)
    
    local strategy = self:_getRecoveryStrategy(error_info)
    local recovered = false
    
    if self.enable_auto_recovery then
        recovered = self:_attemptRecovery(error_info, strategy)
    end
    
    self.stats.total_errors = self.stats.total_errors + 1
    if recovered then
        self.stats.recovered_errors = self.stats.recovered_errors + 1
    else
        self.stats.unrecovered_errors = self.stats.unrecovered_errors + 1
    end
    
    return recovered, error_info
end

-- Handle capture-specific errors
function ErrorHandler:handleCaptureError(source_type, error_message, context)
    local error_info = {
        category = ERROR_CATEGORIES.CAPTURE,
        source_type = source_type,
        error_message = error_message,
        context = context or {},
        timestamp = love and love.timer.getTime() or os.clock(),
        severity = self:_determineCaptureErrorSeverity(source_type, error_message)
    }
    
    self:_logError(error_info)
    
    local strategy = self:_getRecoveryStrategy(error_info)
    local recovered = false
    
    if self.enable_auto_recovery then
        recovered = self:_attemptRecovery(error_info, strategy)
    end
    
    self.stats.total_errors = self.stats.total_errors + 1
    if recovered then
        self.stats.recovered_errors = self.stats.recovered_errors + 1
    else
        self.stats.unrecovered_errors = self.stats.unrecovered_errors + 1
    end
    
    return recovered, error_info
end

-- Determine API error severity
function ErrorHandler:_determineAPISeverity(api_name, error_code)
    -- Check critical error codes first
    if error_code == 8 then -- Not enough memory
        return ERROR_SEVERITY.CRITICAL
    elseif error_code == 5 then -- Access denied
        return ERROR_SEVERITY.HIGH
    elseif error_code == 0 then -- Generic failure
        -- Check if it's a critical API
        local critical_apis = {
            "BitBlt", "CreateCompatibleDC", "CreateCompatibleBitmap",
            "GetDC", "GetWindowDC"
        }
        
        for _, critical_api in ipairs(critical_apis) do
            if api_name == critical_api then
                return ERROR_SEVERITY.HIGH
            end
        end
        
        return ERROR_SEVERITY.MEDIUM
    end
    
    return ERROR_SEVERITY.MEDIUM
end

-- Determine resource error severity
function ErrorHandler:_determineResourceSeverity(resource_type, current_usage)
    if resource_type == "memory" then
        if current_usage and current_usage > self.performance_thresholds.max_memory_usage then
            return ERROR_SEVERITY.CRITICAL
        end
        return ERROR_SEVERITY.HIGH
    elseif resource_type == "device" then
        return ERROR_SEVERITY.HIGH
    elseif resource_type == "handle" then
        return ERROR_SEVERITY.MEDIUM
    end
    
    return ERROR_SEVERITY.MEDIUM
end

-- Determine performance error severity
function ErrorHandler:_determinePerformanceSeverity(metric, current_value, threshold)
    if metric == "frame_drop_rate" then
        if current_value > threshold * 2 then
            return ERROR_SEVERITY.HIGH
        elseif current_value > threshold then
            return ERROR_SEVERITY.MEDIUM
        end
    elseif metric == "capture_time" then
        if current_value > threshold * 3 then
            return ERROR_SEVERITY.HIGH
        elseif current_value > threshold then
            return ERROR_SEVERITY.MEDIUM
        end
    elseif metric == "fps" then
        if current_value < threshold * 0.5 then
            return ERROR_SEVERITY.HIGH
        elseif current_value < threshold then
            return ERROR_SEVERITY.MEDIUM
        end
    end
    
    return ERROR_SEVERITY.LOW
end

-- Determine capture error severity
function ErrorHandler:_determineCaptureErrorSeverity(source_type, error_message)
    local high_severity_patterns = {
        "failed to initialize",
        "device not found",
        "access denied",
        "out of memory"
    }
    
    local error_lower = error_message:lower()
    for _, pattern in ipairs(high_severity_patterns) do
        if string.find(error_lower, pattern) then
            return ERROR_SEVERITY.HIGH
        end
    end
    
    return ERROR_SEVERITY.MEDIUM
end

-- Get recovery strategy for error
function ErrorHandler:_getRecoveryStrategy(error_info)
    local category = error_info.category
    local severity = error_info.severity
    
    if category == ERROR_CATEGORIES.API then
        if severity >= ERROR_SEVERITY.HIGH then
            return RECOVERY_STRATEGIES.FALLBACK
        else
            return RECOVERY_STRATEGIES.RETRY
        end
    elseif category == ERROR_CATEGORIES.RESOURCE then
        if error_info.resource_type == "memory" then
            return RECOVERY_STRATEGIES.DEGRADE
        else
            return RECOVERY_STRATEGIES.RESTART
        end
    elseif category == ERROR_CATEGORIES.PERFORMANCE then
        return RECOVERY_STRATEGIES.DEGRADE
    elseif category == ERROR_CATEGORIES.CONFIGURATION then
        return RECOVERY_STRATEGIES.FALLBACK
    elseif category == ERROR_CATEGORIES.CAPTURE then
        if severity >= ERROR_SEVERITY.HIGH then
            return RECOVERY_STRATEGIES.RESTART
        else
            return RECOVERY_STRATEGIES.RETRY
        end
    end
    
    return RECOVERY_STRATEGIES.NOTIFY_ONLY
end

-- Attempt recovery based on strategy
function ErrorHandler:_attemptRecovery(error_info, strategy)
    local error_key = self:_getErrorKey(error_info)
    
    -- Check if we've already tried to recover this error too many times
    local attempts = self.recovery_attempts[error_key] or 0
    if attempts >= self.max_retry_attempts then
        return false
    end
    
    self.recovery_attempts[error_key] = attempts + 1
    
    if strategy == RECOVERY_STRATEGIES.RETRY then
        return self:_retryOperation(error_info)
    elseif strategy == RECOVERY_STRATEGIES.FALLBACK then
        return self:_useFallbackMethod(error_info)
    elseif strategy == RECOVERY_STRATEGIES.DEGRADE then
        return self:_degradePerformance(error_info)
    elseif strategy == RECOVERY_STRATEGIES.RESTART then
        return self:_restartComponent(error_info)
    end
    
    return false
end

-- Retry operation with delay
function ErrorHandler:_retryOperation(error_info)
    -- Wait before retry
    if self.retry_delay > 0 then
        -- In a real implementation, we might use a timer or coroutine
        -- For now, we'll just simulate the delay
    end
    
    -- The actual retry would be handled by the calling component
    -- We just indicate that retry is recommended
    return true
end

-- Use fallback method
function ErrorHandler:_useFallbackMethod(error_info)
    if error_info.category == ERROR_CATEGORIES.API then
        -- For API errors, suggest using alternative APIs
        if error_info.api_name == "BitBlt" then
            -- Could fallback to different capture method
            return true
        end
    elseif error_info.category == ERROR_CATEGORIES.CONFIGURATION then
        -- Use default values
        return true
    end
    
    return false
end

-- Degrade performance to maintain stability
function ErrorHandler:_degradePerformance(error_info)
    if not self.enable_graceful_degradation then
        return false
    end
    
    local degraded = false
    
    if error_info.category == ERROR_CATEGORIES.PERFORMANCE then
        if error_info.metric == "frame_drop_rate" then
            -- Reduce frame rate
            self.current_quality_level = math.max(0.5, self.current_quality_level * 0.8)
            degraded = true
        elseif error_info.metric == "capture_time" then
            -- Reduce capture quality or resolution
            self.current_quality_level = math.max(0.3, self.current_quality_level * 0.7)
            degraded = true
        end
    elseif error_info.category == ERROR_CATEGORIES.RESOURCE then
        if error_info.resource_type == "memory" then
            -- Reduce buffer sizes
            self.current_quality_level = math.max(0.4, self.current_quality_level * 0.6)
            degraded = true
        end
    end
    
    if degraded then
        self.degraded_mode = true
        self.stats.degradation_events = self.stats.degradation_events + 1
        
        if self.degradation_callback then
            self.degradation_callback(error_info, self.current_quality_level)
        end
    end
    
    return degraded
end

-- Restart component
function ErrorHandler:_restartComponent(error_info)
    self.stats.restart_events = self.stats.restart_events + 1
    
    if self.recovery_callback then
        return self.recovery_callback("restart", error_info)
    end
    
    return false
end

-- Initiate graceful degradation (Requirement 8.3)
function ErrorHandler:_initiateGracefulDegradation(error_info)
    if self.degraded_mode then
        -- Already in degraded mode, further reduce quality
        self.current_quality_level = math.max(0.1, self.current_quality_level * 0.5)
    else
        -- Enter degraded mode
        self.degraded_mode = true
        self.current_quality_level = 0.7
    end
    
    self.stats.degradation_events = self.stats.degradation_events + 1
    
    if self.degradation_callback then
        self.degradation_callback(error_info, self.current_quality_level)
    end
end

-- Log error information
function ErrorHandler:_logError(error_info)
    if not self.log_errors then
        return
    end
    
    -- Add to error history
    table.insert(self.error_history, error_info)
    
    -- Keep only recent errors (last 100)
    if #self.error_history > 100 then
        table.remove(self.error_history, 1)
    end
    
    -- Update error counts
    local category = error_info.category
    self.error_counts[category] = (self.error_counts[category] or 0) + 1
    
    -- Store as last error for category
    self.last_errors[category] = error_info
    
    -- Print error message
    local message = self:_formatErrorMessage(error_info)
    print("ERROR [" .. category .. "]: " .. message)
    
    -- Call error callback if provided
    if self.error_callback then
        self.error_callback(error_info)
    end
end

-- Format error message for logging
function ErrorHandler:_formatErrorMessage(error_info)
    local parts = {}
    
    if error_info.api_name then
        table.insert(parts, "API: " .. error_info.api_name)
    end
    
    if error_info.error_code then
        table.insert(parts, "Code: " .. error_info.error_code)
    end
    
    if error_info.error_message then
        table.insert(parts, "Message: " .. error_info.error_message)
    end
    
    if error_info.resource_type then
        table.insert(parts, "Resource: " .. error_info.resource_type)
    end
    
    if error_info.metric then
        table.insert(parts, "Metric: " .. error_info.metric .. " = " .. tostring(error_info.current_value))
    end
    
    return table.concat(parts, ", ")
end

-- Generate error key for tracking
function ErrorHandler:_getErrorKey(error_info)
    local key_parts = {error_info.category}
    
    if error_info.api_name then
        table.insert(key_parts, error_info.api_name)
    end
    
    if error_info.resource_type then
        table.insert(key_parts, error_info.resource_type)
    end
    
    if error_info.metric then
        table.insert(key_parts, error_info.metric)
    end
    
    return table.concat(key_parts, "_")
end

-- Get error statistics
function ErrorHandler:getErrorStats()
    return {
        total_errors = self.stats.total_errors,
        recovered_errors = self.stats.recovered_errors,
        unrecovered_errors = self.stats.unrecovered_errors,
        degradation_events = self.stats.degradation_events,
        restart_events = self.stats.restart_events,
        error_counts = self.error_counts,
        degraded_mode = self.degraded_mode,
        current_quality_level = self.current_quality_level,
        disabled_features = self.disabled_features
    }
end

-- Get recent errors
function ErrorHandler:getRecentErrors(count)
    count = count or 10
    local recent = {}
    local start_index = math.max(1, #self.error_history - count + 1)
    
    for i = start_index, #self.error_history do
        table.insert(recent, self.error_history[i])
    end
    
    return recent
end

-- Get last error for category
function ErrorHandler:getLastError(category)
    return self.last_errors[category]
end

-- Clear error history
function ErrorHandler:clearErrorHistory()
    self.error_history = {}
    self.error_counts = {}
    self.last_errors = {}
    self.recovery_attempts = {}
    
    self.stats.total_errors = 0
    self.stats.recovered_errors = 0
    self.stats.unrecovered_errors = 0
    self.stats.degradation_events = 0
    self.stats.restart_events = 0
end

-- Reset degraded mode
function ErrorHandler:resetDegradedMode()
    self.degraded_mode = false
    self.current_quality_level = 1.0
    self.disabled_features = {}
end

-- Check if system is in degraded mode
function ErrorHandler:isDegraded()
    return self.degraded_mode
end

-- Get current quality level
function ErrorHandler:getQualityLevel()
    return self.current_quality_level
end

-- Set error callback
function ErrorHandler:setErrorCallback(callback)
    self.error_callback = callback
end

-- Set recovery callback
function ErrorHandler:setRecoveryCallback(callback)
    self.recovery_callback = callback
end

-- Set degradation callback
function ErrorHandler:setDegradationCallback(callback)
    self.degradation_callback = callback
end

-- Export error categories and severity levels
ErrorHandler.ERROR_CATEGORIES = ERROR_CATEGORIES
ErrorHandler.ERROR_SEVERITY = ERROR_SEVERITY
ErrorHandler.RECOVERY_STRATEGIES = RECOVERY_STRATEGIES

return ErrorHandler