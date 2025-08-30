-- Resource Manager - Intelligent resource monitoring and automatic cleanup
-- Handles memory optimization, garbage collection, and resource leak detection

local MemoryPool = require("src.memory_pool")

local ResourceManager = {}
ResourceManager.__index = ResourceManager

-- Resource monitoring thresholds
local RESOURCE_THRESHOLDS = {
    -- Memory thresholds (in MB)
    MEMORY_WARNING = 150,
    MEMORY_CRITICAL = 300,
    MEMORY_EMERGENCY = 500,
    
    -- GC trigger thresholds
    GC_TRIGGER_INTERVAL = 10.0,  -- Minimum seconds between forced GC
    GC_MEMORY_THRESHOLD = 50,    -- MB increase to trigger GC
    GC_ALLOCATION_THRESHOLD = 1000, -- Allocations to trigger GC
    
    -- Resource leak detection
    LEAK_CHECK_INTERVAL = 30.0,
    LEAK_GROWTH_THRESHOLD = 20,  -- MB growth over interval
    LEAK_OBJECT_THRESHOLD = 100, -- Objects held too long
    
    -- Cleanup intervals
    ROUTINE_CLEANUP_INTERVAL = 60.0,
    AGGRESSIVE_CLEANUP_INTERVAL = 15.0,
    EMERGENCY_CLEANUP_INTERVAL = 5.0
}

function ResourceManager:new(options)
    options = options or {}
    
    return setmetatable({
        -- Configuration
        enabled = options.enabled ~= false,
        aggressive_mode = options.aggressive_mode or false,
        debug_mode = options.debug_mode or false,
        
        -- Memory pool integration
        memory_pool = MemoryPool:new(options.memory_pool_config),
        
        -- Resource tracking
        resource_tracking = {
            frame_buffers = {},
            capture_objects = {},
            texture_objects = {},
            temporary_objects = {}
        },
        
        -- Memory monitoring
        memory_stats = {
            baseline_memory = 0,
            peak_memory = 0,
            last_gc_memory = 0,
            gc_count = 0,
            forced_gc_count = 0,
            memory_samples = {},
            sample_count = 0
        },
        
        -- Timing for various operations
        timing = {
            last_gc_time = 0,
            last_leak_check = 0,
            last_routine_cleanup = 0,
            last_memory_sample = 0,
            session_start = 0
        },
        
        -- Resource leak detection
        leak_detection = {
            enabled = options.leak_detection ~= false,
            tracked_objects = {},
            potential_leaks = {},
            leak_warnings = 0
        },
        
        -- Cleanup strategies
        cleanup_strategies = {
            routine = true,
            aggressive = false,
            emergency = false
        },
        
        -- Performance impact tracking
        performance_impact = {
            gc_time_total = 0,
            cleanup_time_total = 0,
            operations_count = 0
        },
        
        -- Callbacks
        callbacks = {
            on_memory_warning = options.on_memory_warning,
            on_memory_critical = options.on_memory_critical,
            on_leak_detected = options.on_leak_detected,
            on_cleanup_performed = options.on_cleanup_performed
        }
    }, self)
end

-- Initialize resource manager
function ResourceManager:initialize()
    if not self.enabled then
        return true
    end
    
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Initialize timing
    self.timing.session_start = current_time
    self.timing.last_gc_time = current_time
    self.timing.last_leak_check = current_time
    self.timing.last_routine_cleanup = current_time
    self.timing.last_memory_sample = current_time
    
    -- Record baseline memory
    collectgarbage("collect")  -- Clean start
    self.memory_stats.baseline_memory = collectgarbage("count") / 1024
    self.memory_stats.last_gc_memory = self.memory_stats.baseline_memory
    self.memory_stats.peak_memory = self.memory_stats.baseline_memory
    
    -- Initialize memory pool
    self.memory_pool:setEnabled(true)
    
    if self.debug_mode then
        print(string.format("ResourceManager: Initialized with baseline memory: %.2f MB", 
              self.memory_stats.baseline_memory))
    end
    
    return true
end

-- Update resource manager (called each frame)
function ResourceManager:update(dt)
    if not self.enabled then
        return
    end
    
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Sample memory usage periodically
    if current_time - self.timing.last_memory_sample >= 1.0 then
        self:_sampleMemoryUsage(current_time)
    end
    
    -- Check for garbage collection needs
    self:_checkGarbageCollection(current_time)
    
    -- Perform leak detection
    if self.leak_detection.enabled and 
       current_time - self.timing.last_leak_check >= RESOURCE_THRESHOLDS.LEAK_CHECK_INTERVAL then
        self:_performLeakDetection(current_time)
    end
    
    -- Perform routine cleanup
    local cleanup_interval = self:_getCleanupInterval()
    if current_time - self.timing.last_routine_cleanup >= cleanup_interval then
        self:_performRoutineCleanup(current_time)
    end
    
    -- Update memory pool
    self.memory_pool:cleanup()
end

-- Sample current memory usage
function ResourceManager:_sampleMemoryUsage(current_time)
    local current_memory = collectgarbage("count") / 1024
    
    -- Add to samples (keep last 60 samples = 1 minute)
    table.insert(self.memory_stats.memory_samples, {
        time = current_time,
        memory = current_memory
    })
    
    if #self.memory_stats.memory_samples > 60 then
        table.remove(self.memory_stats.memory_samples, 1)
    end
    
    self.memory_stats.sample_count = self.memory_stats.sample_count + 1
    self.timing.last_memory_sample = current_time
    
    -- Update peak memory
    if current_memory > self.memory_stats.peak_memory then
        self.memory_stats.peak_memory = current_memory
    end
    
    -- Check memory thresholds
    self:_checkMemoryThresholds(current_memory)
end

-- Check if garbage collection is needed
function ResourceManager:_checkGarbageCollection(current_time)
    local current_memory = collectgarbage("count") / 1024
    local memory_growth = current_memory - self.memory_stats.last_gc_memory
    local time_since_gc = current_time - self.timing.last_gc_time
    
    local should_gc = false
    local gc_reason = ""
    
    -- Check various GC triggers
    if time_since_gc >= RESOURCE_THRESHOLDS.GC_TRIGGER_INTERVAL then
        if memory_growth >= RESOURCE_THRESHOLDS.GC_MEMORY_THRESHOLD then
            should_gc = true
            gc_reason = "memory growth"
        elseif current_memory >= RESOURCE_THRESHOLDS.MEMORY_WARNING then
            should_gc = true
            gc_reason = "memory threshold"
        elseif self.aggressive_mode and memory_growth >= 20 then
            should_gc = true
            gc_reason = "aggressive mode"
        end
    end
    
    -- Emergency GC for critical memory usage
    if current_memory >= RESOURCE_THRESHOLDS.MEMORY_EMERGENCY then
        should_gc = true
        gc_reason = "emergency"
        self.cleanup_strategies.emergency = true
    end
    
    if should_gc then
        self:_performGarbageCollection(current_time, gc_reason)
    end
end

-- Perform garbage collection with timing
function ResourceManager:_performGarbageCollection(current_time, reason)
    local gc_start = love and love.timer.getTime() or os.clock()
    local memory_before = collectgarbage("count") / 1024
    
    -- Perform garbage collection
    collectgarbage("collect")
    
    local gc_end = love and love.timer.getTime() or os.clock()
    local memory_after = collectgarbage("count") / 1024
    local gc_time = gc_end - gc_start
    local memory_freed = memory_before - memory_after
    
    -- Update statistics
    self.memory_stats.gc_count = self.memory_stats.gc_count + 1
    self.memory_stats.forced_gc_count = self.memory_stats.forced_gc_count + 1
    self.memory_stats.last_gc_memory = memory_after
    self.timing.last_gc_time = current_time
    self.performance_impact.gc_time_total = self.performance_impact.gc_time_total + gc_time
    
    if self.debug_mode then
        print(string.format("ResourceManager: GC (%s) freed %.2f MB in %.3f ms", 
              reason, memory_freed, gc_time * 1000))
    end
    
    return memory_freed
end

-- Check memory usage against thresholds
function ResourceManager:_checkMemoryThresholds(current_memory)
    if current_memory >= RESOURCE_THRESHOLDS.MEMORY_CRITICAL then
        if not self.cleanup_strategies.aggressive then
            self.cleanup_strategies.aggressive = true
            self.aggressive_mode = true
            
            if self.callbacks.on_memory_critical then
                self.callbacks.on_memory_critical({
                    current_memory = current_memory,
                    threshold = RESOURCE_THRESHOLDS.MEMORY_CRITICAL,
                    peak_memory = self.memory_stats.peak_memory
                })
            end
        end
    elseif current_memory >= RESOURCE_THRESHOLDS.MEMORY_WARNING then
        if self.callbacks.on_memory_warning then
            self.callbacks.on_memory_warning({
                current_memory = current_memory,
                threshold = RESOURCE_THRESHOLDS.MEMORY_WARNING,
                peak_memory = self.memory_stats.peak_memory
            })
        end
    else
        -- Memory usage is normal, disable aggressive mode
        if self.cleanup_strategies.aggressive then
            self.cleanup_strategies.aggressive = false
            self.aggressive_mode = false
        end
    end
end

-- Perform leak detection
function ResourceManager:_performLeakDetection(current_time)
    local current_memory = collectgarbage("count") / 1024
    
    -- Check for sustained memory growth
    if #self.memory_stats.memory_samples >= 30 then  -- At least 30 seconds of data
        local old_sample = self.memory_stats.memory_samples[1]
        local memory_growth = current_memory - old_sample.memory
        local time_span = current_time - old_sample.time
        
        if memory_growth >= RESOURCE_THRESHOLDS.LEAK_GROWTH_THRESHOLD and time_span >= 30 then
            local growth_rate = memory_growth / time_span  -- MB per second
            
            local leak_info = {
                growth_mb = memory_growth,
                time_span = time_span,
                growth_rate = growth_rate,
                current_memory = current_memory,
                detection_time = current_time
            }
            
            table.insert(self.leak_detection.potential_leaks, leak_info)
            self.leak_detection.leak_warnings = self.leak_detection.leak_warnings + 1
            
            if self.callbacks.on_leak_detected then
                self.callbacks.on_leak_detected(leak_info)
            end
            
            if self.debug_mode then
                print(string.format("ResourceManager: Potential leak detected - %.2f MB growth over %.1f seconds", 
                      memory_growth, time_span))
            end
        end
    end
    
    self.timing.last_leak_check = current_time
end

-- Get appropriate cleanup interval based on current state
function ResourceManager:_getCleanupInterval()
    if self.cleanup_strategies.emergency then
        return RESOURCE_THRESHOLDS.EMERGENCY_CLEANUP_INTERVAL
    elseif self.cleanup_strategies.aggressive then
        return RESOURCE_THRESHOLDS.AGGRESSIVE_CLEANUP_INTERVAL
    else
        return RESOURCE_THRESHOLDS.ROUTINE_CLEANUP_INTERVAL
    end
end

-- Perform routine cleanup operations
function ResourceManager:_performRoutineCleanup(current_time)
    local cleanup_start = love and love.timer.getTime() or os.clock()
    local memory_before = collectgarbage("count") / 1024
    
    local cleanup_actions = {}
    
    -- Clean up memory pool
    local pool_cleanup = self.memory_pool:cleanup()
    if #pool_cleanup > 0 then
        table.insert(cleanup_actions, "memory_pool")
    end
    
    -- Clean up tracked resources
    local resource_cleanup = self:_cleanupTrackedResources()
    if resource_cleanup > 0 then
        table.insert(cleanup_actions, "tracked_resources")
    end
    
    -- Clean up old memory samples
    self:_cleanupMemorySamples()
    
    -- Clean up old leak detection data
    self:_cleanupLeakDetection()
    
    local cleanup_end = love and love.timer.getTime() or os.clock()
    local memory_after = collectgarbage("count") / 1024
    local cleanup_time = cleanup_end - cleanup_start
    local memory_freed = memory_before - memory_after
    
    -- Update statistics
    self.timing.last_routine_cleanup = current_time
    self.performance_impact.cleanup_time_total = self.performance_impact.cleanup_time_total + cleanup_time
    self.performance_impact.operations_count = self.performance_impact.operations_count + 1
    
    if self.callbacks.on_cleanup_performed then
        self.callbacks.on_cleanup_performed({
            actions = cleanup_actions,
            memory_freed = memory_freed,
            cleanup_time = cleanup_time
        })
    end
    
    if self.debug_mode and (#cleanup_actions > 0 or memory_freed > 1) then
        print(string.format("ResourceManager: Cleanup freed %.2f MB in %.3f ms (%s)", 
              memory_freed, cleanup_time * 1000, table.concat(cleanup_actions, ", ")))
    end
end

-- Clean up tracked resources
function ResourceManager:_cleanupTrackedResources()
    local cleaned_count = 0
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Clean up old frame buffer references
    for obj, info in pairs(self.resource_tracking.frame_buffers) do
        if current_time - info.created_time > 300 then  -- 5 minutes old
            self.resource_tracking.frame_buffers[obj] = nil
            cleaned_count = cleaned_count + 1
        end
    end
    
    -- Clean up old temporary objects
    for obj, info in pairs(self.resource_tracking.temporary_objects) do
        if current_time - info.created_time > 60 then  -- 1 minute old
            self.resource_tracking.temporary_objects[obj] = nil
            cleaned_count = cleaned_count + 1
        end
    end
    
    return cleaned_count
end

-- Clean up old memory samples
function ResourceManager:_cleanupMemorySamples()
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Keep only samples from last 5 minutes
    local cutoff_time = current_time - 300
    local new_samples = {}
    
    for _, sample in ipairs(self.memory_stats.memory_samples) do
        if sample.time >= cutoff_time then
            table.insert(new_samples, sample)
        end
    end
    
    self.memory_stats.memory_samples = new_samples
end

-- Clean up old leak detection data
function ResourceManager:_cleanupLeakDetection()
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Keep only leaks from last 10 minutes
    local cutoff_time = current_time - 600
    local new_leaks = {}
    
    for _, leak in ipairs(self.leak_detection.potential_leaks) do
        if leak.detection_time >= cutoff_time then
            table.insert(new_leaks, leak)
        end
    end
    
    self.leak_detection.potential_leaks = new_leaks
end

-- Register a resource for tracking
function ResourceManager:trackResource(obj, resource_type, metadata)
    if not self.enabled or not obj then
        return
    end
    
    local tracking_table = self.resource_tracking[resource_type]
    if not tracking_table then
        tracking_table = {}
        self.resource_tracking[resource_type] = tracking_table
    end
    
    tracking_table[obj] = {
        created_time = love and love.timer.getTime() or os.clock(),
        metadata = metadata or {}
    }
end

-- Unregister a resource from tracking
function ResourceManager:untrackResource(obj, resource_type)
    if not self.enabled or not obj then
        return
    end
    
    local tracking_table = self.resource_tracking[resource_type]
    if tracking_table then
        tracking_table[obj] = nil
    end
end

-- Get memory pool instance
function ResourceManager:getMemoryPool()
    return self.memory_pool
end

-- Force immediate cleanup
function ResourceManager:forceCleanup()
    if not self.enabled then
        return {memory_freed = 0, actions = {}}
    end
    
    local cleanup_start = love and love.timer.getTime() or os.clock()
    local memory_before = collectgarbage("count") / 1024
    
    local actions = {}
    
    -- Force memory pool cleanup
    local pool_freed = self.memory_pool:forceCleanup()
    if pool_freed > 0 then
        table.insert(actions, "memory_pool")
    end
    
    -- Clear all tracked resources
    for resource_type, _ in pairs(self.resource_tracking) do
        self.resource_tracking[resource_type] = {}
    end
    table.insert(actions, "tracked_resources")
    
    -- Force garbage collection
    collectgarbage("collect")
    table.insert(actions, "garbage_collection")
    
    local cleanup_end = love and love.timer.getTime() or os.clock()
    local memory_after = collectgarbage("count") / 1024
    local cleanup_time = cleanup_end - cleanup_start
    local memory_freed = memory_before - memory_after
    
    -- Update statistics
    self.memory_stats.forced_gc_count = self.memory_stats.forced_gc_count + 1
    self.performance_impact.cleanup_time_total = self.performance_impact.cleanup_time_total + cleanup_time
    
    if self.debug_mode then
        print(string.format("ResourceManager: Force cleanup freed %.2f MB in %.3f ms", 
              memory_freed, cleanup_time * 1000))
    end
    
    return {
        memory_freed = memory_freed,
        cleanup_time = cleanup_time,
        actions = actions
    }
end

-- Get comprehensive resource statistics
function ResourceManager:getStats()
    local current_memory = collectgarbage("count") / 1024
    local session_time = (love and love.timer.getTime() or os.clock()) - self.timing.session_start
    
    -- Calculate memory statistics
    local memory_growth = current_memory - self.memory_stats.baseline_memory
    local average_memory = 0
    if #self.memory_stats.memory_samples > 0 then
        local total = 0
        for _, sample in ipairs(self.memory_stats.memory_samples) do
            total = total + sample.memory
        end
        average_memory = total / #self.memory_stats.memory_samples
    end
    
    -- Count tracked resources
    local tracked_counts = {}
    for resource_type, tracking_table in pairs(self.resource_tracking) do
        local count = 0
        for _ in pairs(tracking_table) do
            count = count + 1
        end
        tracked_counts[resource_type] = count
    end
    
    return {
        enabled = self.enabled,
        session_time = session_time,
        
        -- Memory statistics
        memory = {
            current = current_memory,
            baseline = self.memory_stats.baseline_memory,
            peak = self.memory_stats.peak_memory,
            average = average_memory,
            growth = memory_growth,
            samples_count = #self.memory_stats.memory_samples
        },
        
        -- Garbage collection statistics
        garbage_collection = {
            total_collections = self.memory_stats.gc_count,
            forced_collections = self.memory_stats.forced_gc_count,
            total_gc_time = self.performance_impact.gc_time_total,
            average_gc_time = self.memory_stats.forced_gc_count > 0 and 
                             (self.performance_impact.gc_time_total / self.memory_stats.forced_gc_count) or 0
        },
        
        -- Resource tracking
        tracked_resources = tracked_counts,
        
        -- Leak detection
        leak_detection = {
            enabled = self.leak_detection.enabled,
            potential_leaks = #self.leak_detection.potential_leaks,
            leak_warnings = self.leak_detection.leak_warnings
        },
        
        -- Cleanup statistics
        cleanup = {
            operations_count = self.performance_impact.operations_count,
            total_cleanup_time = self.performance_impact.cleanup_time_total,
            average_cleanup_time = self.performance_impact.operations_count > 0 and
                                  (self.performance_impact.cleanup_time_total / self.performance_impact.operations_count) or 0
        },
        
        -- Memory pool statistics
        memory_pool = self.memory_pool:getStats(),
        
        -- Current cleanup strategy
        cleanup_strategy = {
            routine = self.cleanup_strategies.routine,
            aggressive = self.cleanup_strategies.aggressive,
            emergency = self.cleanup_strategies.emergency
        }
    }
end

-- Get memory usage recommendations
function ResourceManager:getRecommendations()
    local stats = self:getStats()
    local recommendations = {}
    
    -- Memory usage recommendations
    if stats.memory.current >= RESOURCE_THRESHOLDS.MEMORY_CRITICAL then
        table.insert(recommendations, {
            type = "critical",
            message = "Critical memory usage - consider reducing buffer sizes or capture quality"
        })
    elseif stats.memory.current >= RESOURCE_THRESHOLDS.MEMORY_WARNING then
        table.insert(recommendations, {
            type = "warning", 
            message = "High memory usage - monitor for potential leaks"
        })
    end
    
    -- Leak detection recommendations
    if stats.leak_detection.potential_leaks > 0 then
        table.insert(recommendations, {
            type = "warning",
            message = string.format("%d potential memory leaks detected", stats.leak_detection.potential_leaks)
        })
    end
    
    -- Memory pool recommendations
    local pool_stats = stats.memory_pool.pool_stats
    for pool_type, pool_stat in pairs(pool_stats) do
        if pool_stat.reuse_rate < 50 then
            table.insert(recommendations, {
                type = "optimization",
                message = string.format("Low reuse rate for %s pool (%.1f%%) - consider adjusting pool size", 
                         pool_type, pool_stat.reuse_rate)
            })
        end
    end
    
    -- Performance recommendations
    if stats.garbage_collection.average_gc_time > 0.01 then  -- 10ms
        table.insert(recommendations, {
            type = "performance",
            message = "High garbage collection time - consider enabling aggressive cleanup mode"
        })
    end
    
    return recommendations
end

-- Enable/disable resource manager
function ResourceManager:setEnabled(enabled)
    self.enabled = enabled
    self.memory_pool:setEnabled(enabled)
    
    if enabled then
        self:initialize()
    end
end

-- Enable/disable aggressive cleanup mode
function ResourceManager:setAggressiveMode(enabled)
    self.aggressive_mode = enabled
    self.cleanup_strategies.aggressive = enabled
end

-- Enable/disable leak detection
function ResourceManager:setLeakDetection(enabled)
    self.leak_detection.enabled = enabled
    
    if not enabled then
        self.leak_detection.potential_leaks = {}
        self.leak_detection.tracked_objects = {}
    end
end

return ResourceManager