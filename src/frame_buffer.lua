-- Frame Buffer Manager - Handles video frame data and memory management
local MemoryPool = require("src.memory_pool")

local FrameBuffer = {}
FrameBuffer.__index = FrameBuffer

-- Frame data structure as defined in design document
local function createFrame(data, width, height, format, source_info)
    return {
        data = data,
        width = width or 0,
        height = height or 0,
        format = format or 'RGBA',
        timestamp = love and love.timer.getTime() or os.clock(),
        source_info = source_info or {}
    }
end

function FrameBuffer:new(max_frames, options)
    options = options or {}
    
    local buffer = setmetatable({
        frames = {},
        max_frames = max_frames or 3,
        current_index = 1,
        frame_count = 0,
        total_memory_bytes = 0,
        dropped_frames = 0,
        
        -- Memory optimization features
        memory_pool = options.memory_pool or MemoryPool:new({
            enabled = options.use_memory_pool ~= false
        }),
        use_memory_pool = options.use_memory_pool ~= false,
        intelligent_gc = options.intelligent_gc ~= false,
        gc_threshold = options.gc_threshold or 50, -- MB
        
        -- Garbage collection tracking
        gc_stats = {
            collections_triggered = 0,
            memory_freed_total = 0,
            last_gc_time = 0
        }
    }, self)
    
    -- Pre-allocate frame slots for circular buffer
    for i = 1, buffer.max_frames do
        buffer.frames[i] = nil
    end
    
    return buffer
end

-- Add a new frame to the circular buffer
function FrameBuffer:addFrame(frame_data, width, height, format, source_info)
    if not frame_data then
        error("Frame data cannot be nil")
    end
    
    if not width or width <= 0 or not height or height <= 0 then
        error("Invalid frame dimensions")
    end
    
    -- Create new frame using memory pool if enabled
    local frame
    if self.use_memory_pool then
        frame = self.memory_pool:acquire("FRAME_DATA")
        frame.data = frame_data
        frame.width = width
        frame.height = height
        frame.format = format or 'RGBA'
        frame.timestamp = love and love.timer.getTime() or os.clock()
        frame.source_info = source_info or {}
    else
        frame = createFrame(frame_data, width, height, format, source_info)
    end
    
    -- Calculate frame size in bytes (assuming 4 bytes per pixel for RGBA)
    local bytes_per_pixel = 4
    if format == 'RGB' then
        bytes_per_pixel = 3
    elseif format == 'GRAY' then
        bytes_per_pixel = 1
    end
    local frame_size = width * height * bytes_per_pixel
    
    -- If buffer is full, we'll overwrite the oldest frame
    local old_frame = self.frames[self.current_index]
    if old_frame then
        -- Subtract old frame size from total memory
        local old_size = old_frame.width * old_frame.height * 
                        (old_frame.format == 'RGB' and 3 or 
                         old_frame.format == 'GRAY' and 1 or 4)
        self.total_memory_bytes = self.total_memory_bytes - old_size
        
        -- Return old frame to memory pool if using pooling
        if self.use_memory_pool then
            self.memory_pool:release(old_frame)
        end
        
        -- If we're overwriting, count as dropped frame
        if self.frame_count >= self.max_frames then
            self.dropped_frames = self.dropped_frames + 1
        end
    end
    
    -- Store the new frame
    self.frames[self.current_index] = frame
    self.total_memory_bytes = self.total_memory_bytes + frame_size
    
    -- Update counters and advance circular buffer index
    if self.frame_count < self.max_frames then
        self.frame_count = self.frame_count + 1
    end
    
    self.current_index = (self.current_index % self.max_frames) + 1
    
    -- Check if intelligent garbage collection is needed
    if self.intelligent_gc then
        self:_checkIntelligentGC()
    end
    
    return true
end

-- Get the most recently added frame
function FrameBuffer:getLatestFrame()
    if self.frame_count == 0 then
        return nil
    end
    
    -- Calculate the index of the most recent frame
    local latest_index = self.current_index - 1
    if latest_index == 0 then
        latest_index = self.max_frames
    end
    
    return self.frames[latest_index]
end

-- Get frame by relative age (0 = latest, 1 = previous, etc.)
function FrameBuffer:getFrame(age)
    if not age or age < 0 or age >= self.frame_count then
        return nil
    end
    
    -- Calculate index going backwards from latest
    local target_index = self.current_index - 1 - age
    while target_index <= 0 do
        target_index = target_index + self.max_frames
    end
    
    return self.frames[target_index]
end

-- Clear all frames and reset buffer
function FrameBuffer:clear()
    -- Return frames to memory pool if using pooling
    if self.use_memory_pool then
        for i = 1, self.max_frames do
            if self.frames[i] then
                self.memory_pool:release(self.frames[i])
            end
            self.frames[i] = nil
        end
    else
        -- Clear all frame references for garbage collection
        for i = 1, self.max_frames do
            self.frames[i] = nil
        end
    end
    
    self.frame_count = 0
    self.current_index = 1
    self.total_memory_bytes = 0
    self.dropped_frames = 0
    
    -- Force garbage collection to free memory
    if collectgarbage then
        local memory_before = collectgarbage("count")
        collectgarbage("collect")
        local memory_after = collectgarbage("count")
        local memory_freed = (memory_before - memory_after) / 1024
        
        self.gc_stats.collections_triggered = self.gc_stats.collections_triggered + 1
        self.gc_stats.memory_freed_total = self.gc_stats.memory_freed_total + memory_freed
        self.gc_stats.last_gc_time = love and love.timer.getTime() or os.clock()
    end
end

-- Get current memory usage in bytes
function FrameBuffer:getMemoryUsage()
    return self.total_memory_bytes
end

-- Get buffer statistics
function FrameBuffer:getStats()
    return {
        frame_count = self.frame_count,
        max_frames = self.max_frames,
        memory_bytes = self.total_memory_bytes,
        memory_mb = self.total_memory_bytes / (1024 * 1024),
        dropped_frames = self.dropped_frames,
        utilization = self.frame_count / self.max_frames
    }
end

-- Check if buffer is full
function FrameBuffer:isFull()
    return self.frame_count >= self.max_frames
end

-- Resize buffer (will clear existing frames)
function FrameBuffer:resize(new_max_frames)
    if new_max_frames <= 0 then
        error("Buffer size must be positive")
    end
    
    self:clear()
    self.max_frames = new_max_frames
    
    -- Re-initialize frame slots
    for i = 1, self.max_frames do
        self.frames[i] = nil
    end
end

-- Check if intelligent garbage collection is needed
function FrameBuffer:_checkIntelligentGC()
    local current_memory = collectgarbage("count") / 1024  -- Convert to MB
    local current_time = love and love.timer.getTime() or os.clock()
    
    -- Only trigger GC if memory exceeds threshold and enough time has passed
    if current_memory > self.gc_threshold and 
       (current_time - self.gc_stats.last_gc_time) > 5.0 then  -- At least 5 seconds between GC
        
        local memory_before = collectgarbage("count")
        collectgarbage("collect")
        local memory_after = collectgarbage("count")
        local memory_freed = (memory_before - memory_after) / 1024
        
        self.gc_stats.collections_triggered = self.gc_stats.collections_triggered + 1
        self.gc_stats.memory_freed_total = self.gc_stats.memory_freed_total + memory_freed
        self.gc_stats.last_gc_time = current_time
    end
end

-- Get memory pool instance
function FrameBuffer:getMemoryPool()
    return self.memory_pool
end

-- Enable/disable memory pooling
function FrameBuffer:setMemoryPooling(enabled)
    if enabled and not self.use_memory_pool then
        -- Enabling memory pooling - clear buffer to start fresh
        self:clear()
        self.use_memory_pool = true
    elseif not enabled and self.use_memory_pool then
        -- Disabling memory pooling - clear buffer and force cleanup
        self:clear()
        self.memory_pool:forceCleanup()
        self.use_memory_pool = false
    end
end

-- Enable/disable intelligent garbage collection
function FrameBuffer:setIntelligentGC(enabled, threshold)
    self.intelligent_gc = enabled
    if threshold and threshold > 0 then
        self.gc_threshold = threshold
    end
end

-- Get garbage collection statistics
function FrameBuffer:getGCStats()
    return {
        collections_triggered = self.gc_stats.collections_triggered,
        memory_freed_total = self.gc_stats.memory_freed_total,
        last_gc_time = self.gc_stats.last_gc_time,
        current_memory_mb = collectgarbage("count") / 1024,
        gc_threshold = self.gc_threshold,
        intelligent_gc_enabled = self.intelligent_gc
    }
end

-- Force garbage collection and return memory freed
function FrameBuffer:forceGarbageCollection()
    local memory_before = collectgarbage("count")
    collectgarbage("collect")
    local memory_after = collectgarbage("count")
    local memory_freed = (memory_before - memory_after) / 1024
    
    self.gc_stats.collections_triggered = self.gc_stats.collections_triggered + 1
    self.gc_stats.memory_freed_total = self.gc_stats.memory_freed_total + memory_freed
    self.gc_stats.last_gc_time = love and love.timer.getTime() or os.clock()
    
    return memory_freed
end

-- Get comprehensive buffer statistics including memory optimization
function FrameBuffer:getOptimizedStats()
    local base_stats = self:getStats()
    
    -- Add memory optimization statistics
    base_stats.memory_optimization = {
        memory_pooling_enabled = self.use_memory_pool,
        intelligent_gc_enabled = self.intelligent_gc,
        gc_threshold_mb = self.gc_threshold,
        gc_stats = self:getGCStats()
    }
    
    -- Add memory pool statistics if enabled
    if self.use_memory_pool then
        base_stats.memory_pool_stats = self.memory_pool:getStats()
    end
    
    return base_stats
end

return FrameBuffer