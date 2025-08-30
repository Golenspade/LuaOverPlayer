-- Memory Pool Manager - Optimized memory allocation for frequent frame operations
-- Implements object pooling to reduce garbage collection pressure

local MemoryPool = {}
MemoryPool.__index = MemoryPool

-- Pool types for different allocation patterns
local POOL_TYPES = {
    FRAME_DATA = "frame_data",
    PIXEL_BUFFER = "pixel_buffer", 
    METADATA = "metadata",
    TEMP_BUFFER = "temp_buffer"
}

-- Default pool configurations
local DEFAULT_POOL_CONFIG = {
    [POOL_TYPES.FRAME_DATA] = {
        initial_size = 5,
        max_size = 20,
        growth_factor = 1.5,
        shrink_threshold = 0.3,
        cleanup_interval = 30.0
    },
    [POOL_TYPES.PIXEL_BUFFER] = {
        initial_size = 3,
        max_size = 10,
        growth_factor = 2.0,
        shrink_threshold = 0.2,
        cleanup_interval = 60.0
    },
    [POOL_TYPES.METADATA] = {
        initial_size = 10,
        max_size = 50,
        growth_factor = 1.3,
        shrink_threshold = 0.4,
        cleanup_interval = 45.0
    },
    [POOL_TYPES.TEMP_BUFFER] = {
        initial_size = 2,
        max_size = 8,
        growth_factor = 2.0,
        shrink_threshold = 0.25,
        cleanup_interval = 20.0
    }
}

function MemoryPool:new(config)
    config = config or {}
    
    local pool = setmetatable({
        -- Pool configuration
        config = {},
        
        -- Object pools by type
        pools = {},
        
        -- Pool statistics
        stats = {
            total_allocations = 0,
            total_deallocations = 0,
            pool_hits = 0,
            pool_misses = 0,
            memory_saved = 0,
            gc_collections = 0
        },
        
        -- Timing for cleanup
        last_cleanup = {},
        
        -- Memory tracking
        allocated_objects = {},
        object_sizes = {},
        
        -- Performance monitoring
        enabled = config.enabled ~= false,
        debug_mode = config.debug_mode or false
    }, self)
    
    -- Initialize pool configurations
    for pool_type, default_config in pairs(DEFAULT_POOL_CONFIG) do
        pool.config[pool_type] = {}
        for key, value in pairs(default_config) do
            pool.config[pool_type][key] = config[pool_type] and config[pool_type][key] or value
        end
    end
    
    -- Initialize pools
    for pool_type, _ in pairs(POOL_TYPES) do
        pool.pools[pool_type] = {
            available = {},
            in_use = {},
            total_created = 0,
            total_reused = 0
        }
        pool.last_cleanup[pool_type] = love and love.timer.getTime() or os.clock()
    end
    
    return pool
end

-- Get an object from the pool or create a new one
function MemoryPool:acquire(pool_type, size_hint)
    if not self.enabled then
        return self:_createNewObject(pool_type, size_hint)
    end
    
    -- Convert string to pool type constant if needed
    local actual_pool_type = pool_type
    if type(pool_type) == "string" then
        -- Handle string input by finding matching pool type
        local found = false
        for key, value in pairs(POOL_TYPES) do
            if key == pool_type or value == pool_type then
                actual_pool_type = key
                found = true
                break
            end
        end
        if not found then
            error("Invalid pool type: " .. tostring(pool_type))
        end
    end
    
    local pool = self.pools[actual_pool_type]
    local obj = nil
    
    -- Try to reuse an object from the pool
    if #pool.available > 0 then
        obj = table.remove(pool.available)
        pool.total_reused = pool.total_reused + 1
        self.stats.pool_hits = self.stats.pool_hits + 1
        
        -- Reset object state
        self:_resetObject(obj, actual_pool_type, size_hint)
    else
        -- Create new object
        obj = self:_createNewObject(actual_pool_type, size_hint)
        pool.total_created = pool.total_created + 1
        self.stats.pool_misses = self.stats.pool_misses + 1
    end
    
    -- Track object usage
    pool.in_use[obj] = true
    self.allocated_objects[obj] = {
        pool_type = actual_pool_type,
        allocated_time = love and love.timer.getTime() or os.clock(),
        size = size_hint or 0
    }
    
    self.stats.total_allocations = self.stats.total_allocations + 1
    
    if self.debug_mode then
        print(string.format("MemoryPool: Acquired %s object (pool: %d available, %d in use)", 
              actual_pool_type, #pool.available, self:_countInUse(actual_pool_type)))
    end
    
    return obj
end

-- Return an object to the pool
function MemoryPool:release(obj)
    if not self.enabled or not obj then
        return
    end
    
    local obj_info = self.allocated_objects[obj]
    if not obj_info then
        if self.debug_mode then
            print("MemoryPool: Warning - releasing untracked object")
        end
        return
    end
    
    local pool_type = obj_info.pool_type
    local pool = self.pools[pool_type]
    local config = self.config[pool_type]
    
    -- Remove from in-use tracking
    pool.in_use[obj] = nil
    self.allocated_objects[obj] = nil
    
    -- Return to pool if under max size (use default if no config)
    local max_size = config and config.max_size or 20
    if #pool.available < max_size then
        table.insert(pool.available, obj)
    else
        -- Pool is full, let object be garbage collected
        obj = nil
    end
    
    self.stats.total_deallocations = self.stats.total_deallocations + 1
    
    if self.debug_mode then
        print(string.format("MemoryPool: Released %s object (pool: %d available, %d in use)", 
              pool_type, #pool.available, self:_countInUse(pool_type)))
    end
end

-- Create a new object based on pool type
function MemoryPool:_createNewObject(pool_type, size_hint)
    -- Handle string input
    if type(pool_type) == "string" then
        if pool_type == "FRAME_DATA" then
            pool_type = POOL_TYPES.FRAME_DATA
        elseif pool_type == "PIXEL_BUFFER" then
            pool_type = POOL_TYPES.PIXEL_BUFFER
        elseif pool_type == "METADATA" then
            pool_type = POOL_TYPES.METADATA
        elseif pool_type == "TEMP_BUFFER" then
            pool_type = POOL_TYPES.TEMP_BUFFER
        end
    end
    
    if pool_type == POOL_TYPES.FRAME_DATA then
        return {
            data = nil,
            width = 0,
            height = 0,
            format = 'RGBA',
            timestamp = 0,
            source_info = {}
        }
    elseif pool_type == POOL_TYPES.PIXEL_BUFFER then
        -- Create a reusable pixel buffer
        local size = size_hint or 1920 * 1080 * 4  -- Default to 1080p RGBA
        return {
            buffer = {},  -- Will be resized as needed
            capacity = size,
            used_size = 0
        }
    elseif pool_type == POOL_TYPES.METADATA then
        return {
            source_type = nil,
            capture_duration = 0,
            window_title = nil,
            window_rect = nil,
            dpi_info = nil,
            device_info = nil
        }
    elseif pool_type == POOL_TYPES.TEMP_BUFFER then
        return {
            data = {},
            size = 0,
            purpose = nil
        }
    else
        error("Unknown pool type: " .. tostring(pool_type))
    end
end

-- Reset object state for reuse
function MemoryPool:_resetObject(obj, pool_type, size_hint)
    if pool_type == POOL_TYPES.FRAME_DATA then
        obj.data = nil
        obj.width = 0
        obj.height = 0
        obj.format = 'RGBA'
        obj.timestamp = 0
        obj.source_info = {}
    elseif pool_type == POOL_TYPES.PIXEL_BUFFER then
        obj.used_size = 0
        -- Resize buffer if needed
        local required_size = size_hint or obj.capacity
        if required_size > obj.capacity then
            obj.capacity = required_size
            -- Buffer will be resized on first use
        end
    elseif pool_type == POOL_TYPES.METADATA then
        obj.source_type = nil
        obj.capture_duration = 0
        obj.window_title = nil
        obj.window_rect = nil
        obj.dpi_info = nil
        obj.device_info = nil
    elseif pool_type == POOL_TYPES.TEMP_BUFFER then
        obj.size = 0
        obj.purpose = nil
        -- Keep data table but clear it
        for k in pairs(obj.data) do
            obj.data[k] = nil
        end
    end
end

-- Count objects currently in use for a pool type
function MemoryPool:_countInUse(pool_type)
    local count = 0
    local pool = self.pools[pool_type]
    for _ in pairs(pool.in_use) do
        count = count + 1
    end
    return count
end

-- Perform periodic cleanup of pools
function MemoryPool:cleanup()
    if not self.enabled then
        return
    end
    
    local current_time = love and love.timer.getTime() or os.clock()
    local cleaned_pools = {}
    
    for pool_type, pool in pairs(self.pools) do
        local config = self.config[pool_type]
        if not config then
            -- Skip cleanup for pools without configuration
        else
            local last_cleanup = self.last_cleanup[pool_type]
            
            -- Check if cleanup interval has passed
            if current_time - last_cleanup >= config.cleanup_interval then
            local initial_size = #pool.available
            local target_size = math.max(config.initial_size, 
                                       math.floor(#pool.available * config.shrink_threshold))
            
            -- Remove excess objects from pool
            while #pool.available > target_size do
                table.remove(pool.available)
            end
            
            local cleaned_count = initial_size - #pool.available
            if cleaned_count > 0 then
                table.insert(cleaned_pools, {
                    type = pool_type,
                    cleaned = cleaned_count,
                    remaining = #pool.available
                })
            end
            
            self.last_cleanup[pool_type] = current_time
            end
        end
    end
    
    -- Force garbage collection if we cleaned up objects
    if #cleaned_pools > 0 then
        collectgarbage("collect")
        self.stats.gc_collections = self.stats.gc_collections + 1
        
        if self.debug_mode then
            for _, cleanup_info in ipairs(cleaned_pools) do
                print(string.format("MemoryPool: Cleaned %d %s objects (%d remaining)", 
                      cleanup_info.cleaned, cleanup_info.type, cleanup_info.remaining))
            end
        end
    end
    
    return cleaned_pools
end

-- Get pool statistics
function MemoryPool:getStats()
    local pool_stats = {}
    
    for pool_type, pool in pairs(self.pools) do
        pool_stats[pool_type] = {
            available = #pool.available,
            in_use = self:_countInUse(pool_type),
            total_created = pool.total_created,
            total_reused = pool.total_reused,
            reuse_rate = pool.total_created > 0 and 
                        (pool.total_reused / (pool.total_created + pool.total_reused)) * 100 or 0
        }
    end
    
    return {
        enabled = self.enabled,
        global_stats = self.stats,
        pool_stats = pool_stats,
        memory_usage = collectgarbage("count") / 1024,  -- MB
        total_pools = #self.pools
    }
end

-- Get memory usage summary
function MemoryPool:getMemoryUsage()
    local total_objects = 0
    local total_available = 0
    local total_in_use = 0
    
    for pool_type, pool in pairs(self.pools) do
        total_available = total_available + #pool.available
        total_in_use = total_in_use + self:_countInUse(pool_type)
    end
    
    total_objects = total_available + total_in_use
    
    return {
        total_objects = total_objects,
        available_objects = total_available,
        in_use_objects = total_in_use,
        utilization = total_objects > 0 and (total_in_use / total_objects) * 100 or 0,
        lua_memory_kb = collectgarbage("count"),
        lua_memory_mb = collectgarbage("count") / 1024
    }
end

-- Force cleanup of all pools
function MemoryPool:forceCleanup()
    local cleaned_total = 0
    
    for pool_type, pool in pairs(self.pools) do
        local initial_size = #pool.available
        local config = self.config[pool_type]
        
        -- Shrink to initial size
        while #pool.available > config.initial_size do
            table.remove(pool.available)
            cleaned_total = cleaned_total + 1
        end
        
        self.last_cleanup[pool_type] = love and love.timer.getTime() or os.clock()
    end
    
    -- Force garbage collection
    collectgarbage("collect")
    self.stats.gc_collections = self.stats.gc_collections + 1
    
    if self.debug_mode then
        print(string.format("MemoryPool: Force cleanup removed %d objects", cleaned_total))
    end
    
    return cleaned_total
end

-- Reset all pools and statistics
function MemoryPool:reset()
    -- Clear all pools
    for pool_type, pool in pairs(self.pools) do
        pool.available = {}
        pool.in_use = {}
        pool.total_created = 0
        pool.total_reused = 0
        self.last_cleanup[pool_type] = love and love.timer.getTime() or os.clock()
    end
    
    -- Clear tracking
    self.allocated_objects = {}
    self.object_sizes = {}
    
    -- Reset statistics
    self.stats = {
        total_allocations = 0,
        total_deallocations = 0,
        pool_hits = 0,
        pool_misses = 0,
        memory_saved = 0,
        gc_collections = 0
    }
    
    -- Force garbage collection
    collectgarbage("collect")
    self.stats.gc_collections = 1
end

-- Enable/disable memory pooling
function MemoryPool:setEnabled(enabled)
    if not enabled and self.enabled then
        -- Disabling - clean up all pools
        self:forceCleanup()
    end
    
    self.enabled = enabled
end

-- Configure pool settings
function MemoryPool:configurePool(pool_type, config)
    if not POOL_TYPES[pool_type:upper()] then
        return false, "Invalid pool type: " .. tostring(pool_type)
    end
    
    local pool_config = self.config[pool_type]
    for key, value in pairs(config) do
        if pool_config[key] ~= nil then
            pool_config[key] = value
        end
    end
    
    return true
end

-- Get pool configuration
function MemoryPool:getPoolConfig(pool_type)
    if pool_type then
        return self.config[pool_type]
    else
        return self.config
    end
end

return MemoryPool