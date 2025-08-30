-- Memory Optimization Unit Tests - Basic functionality tests for memory pool and resource manager

local TestFramework = require("tests.test_framework")
local MemoryPool = require("src.memory_pool")
local ResourceManager = require("src.resource_manager")
local FrameBuffer = require("src.frame_buffer")

local MemoryOptimizationTests = {}

-- Test 1: Memory Pool Basic Operations
function MemoryOptimizationTests.testMemoryPoolBasicOperations()
    local test = TestFramework:new("Memory Pool Basic Operations")
    
    local pool = MemoryPool:new({
        enabled = true,
        debug_mode = false
    })
    
    -- Test object acquisition
    local obj1 = pool:acquire("FRAME_DATA")
    test:assert(obj1 ~= nil, "Should acquire frame data object")
    test:assert(obj1.data == nil, "Frame data should be initially nil")
    test:assert(obj1.width == 0, "Frame width should be initially 0")
    
    -- Test object release and reuse
    pool:release(obj1)
    local obj2 = pool:acquire("FRAME_DATA")
    test:assert(obj2 == obj1, "Should reuse released object")
    
    -- Test different pool types
    local pixel_buffer = pool:acquire("PIXEL_BUFFER", 1920 * 1080 * 4)
    test:assert(pixel_buffer ~= nil, "Should acquire pixel buffer")
    test:assert(pixel_buffer.capacity >= 1920 * 1080 * 4, "Pixel buffer should have adequate capacity")
    
    local metadata = pool:acquire("METADATA")
    test:assert(metadata ~= nil, "Should acquire metadata object")
    test:assert(metadata.source_type == nil, "Metadata should be initially empty")
    
    -- Test pool statistics
    local stats = pool:getStats()
    test:assert(stats.enabled == true, "Pool should be enabled")
    test:assert(stats.global_stats.total_allocations >= 3, "Should track allocations")
    
    -- Clean up
    pool:release(obj2)
    pool:release(pixel_buffer)
    pool:release(metadata)
    
    return test:complete()
end

-- Test 2: Resource Manager Basic Operations
function MemoryOptimizationTests.testResourceManagerBasicOperations()
    local test = TestFramework:new("Resource Manager Basic Operations")
    
    local resource_manager = ResourceManager:new({
        enabled = true,
        memory_monitoring = true,
        leak_detection = true
    })
    
    -- Test initialization
    local success = resource_manager:initialize()
    test:assert(success == true, "Resource manager should initialize successfully")
    
    -- Test resource tracking
    local test_object = {data = "test"}
    resource_manager:trackResource(test_object, "temporary_objects", {size = 100})
    
    -- Test memory monitoring
    local initial_memory = collectgarbage("count") / 1024
    
    -- Simulate some memory usage
    local large_table = {}
    for i = 1, 1000 do
        large_table[i] = string.rep("x", 1000)
    end
    
    -- Update resource manager
    resource_manager:update(0.033)
    
    local stats = resource_manager:getStats()
    test:assert(stats.enabled == true, "Resource manager should be enabled")
    test:assert(stats.memory.current > 0, "Should track current memory usage")
    test:assert(stats.tracked_resources.temporary_objects >= 1, "Should track temporary objects")
    
    -- Test cleanup
    local cleanup_result = resource_manager:forceCleanup()
    test:assert(cleanup_result.memory_freed >= 0, "Cleanup should report memory freed")
    
    -- Clean up
    resource_manager:untrackResource(test_object, "temporary_objects")
    large_table = nil
    
    return test:complete()
end

-- Test 3: Frame Buffer with Memory Optimization
function MemoryOptimizationTests.testFrameBufferMemoryOptimization()
    local test = TestFramework:new("Frame Buffer Memory Optimization")
    
    local frame_buffer = FrameBuffer:new(3, {
        use_memory_pool = true,
        intelligent_gc = true,
        gc_threshold = 10  -- Low threshold for testing
    })
    
    -- Test frame addition with memory pooling
    local frame_data = {}
    for i = 1, 640 * 480 * 4 do
        frame_data[i] = i % 256
    end
    
    local success = frame_buffer:addFrame(frame_data, 640, 480, 'RGBA', {test = true})
    test:assert(success == true, "Should add frame successfully")
    
    -- Test frame retrieval
    local latest_frame = frame_buffer:getLatestFrame()
    test:assert(latest_frame ~= nil, "Should retrieve latest frame")
    test:assert(latest_frame.width == 640, "Frame width should be correct")
    test:assert(latest_frame.height == 480, "Frame height should be correct")
    
    -- Test memory pool integration
    local pool_stats = frame_buffer:getMemoryPool():getStats()
    test:assert(pool_stats.enabled == true, "Memory pool should be enabled")
    
    -- Test optimized statistics
    local optimized_stats = frame_buffer:getOptimizedStats()
    test:assert(optimized_stats.memory_optimization ~= nil, "Should have memory optimization stats")
    test:assert(optimized_stats.memory_optimization.memory_pooling_enabled == true, "Memory pooling should be enabled")
    
    -- Test intelligent GC
    frame_buffer:setIntelligentGC(true, 5)  -- Very low threshold
    
    -- Add more frames to potentially trigger GC
    for i = 1, 5 do
        local large_frame_data = {}
        for j = 1, 1920 * 1080 * 4 do
            large_frame_data[j] = j % 256
        end
        frame_buffer:addFrame(large_frame_data, 1920, 1080, 'RGBA', {frame = i})
    end
    
    local gc_stats = frame_buffer:getGCStats()
    test:assert(gc_stats.collections_triggered >= 0, "Should track GC collections")
    
    return test:complete()
end

-- Test 4: Memory Pool Cleanup and Efficiency
function MemoryOptimizationTests.testMemoryPoolCleanupEfficiency()
    local test = TestFramework:new("Memory Pool Cleanup and Efficiency")
    
    local pool = MemoryPool:new({
        enabled = true,
        debug_mode = false
    })
    
    -- Allocate and release many objects to test efficiency
    local objects = {}
    
    -- Phase 1: Allocate objects
    for i = 1, 50 do
        local obj = pool:acquire("FRAME_DATA")
        table.insert(objects, obj)
    end
    
    -- Phase 2: Release half the objects
    for i = 1, 25 do
        pool:release(table.remove(objects))
    end
    
    -- Phase 3: Allocate more objects (should reuse released ones)
    for i = 1, 25 do
        local obj = pool:acquire("FRAME_DATA")
        table.insert(objects, obj)
    end
    
    local stats = pool:getStats()
    local frame_pool_stats = stats.pool_stats.FRAME_DATA
    
    test:assert(frame_pool_stats.total_reused > 0, "Should have reused objects")
    test:assert(frame_pool_stats.reuse_rate > 0, "Should have positive reuse rate")
    
    -- Test cleanup
    for _, obj in ipairs(objects) do
        pool:release(obj)
    end
    
    local cleanup_result = pool:cleanup()
    test:assert(type(cleanup_result) == "table", "Cleanup should return result table")
    
    -- Test force cleanup
    local force_cleanup_count = pool:forceCleanup()
    test:assert(force_cleanup_count >= 0, "Force cleanup should return count")
    
    return test:complete()
end

-- Test 5: Resource Manager Memory Monitoring
function MemoryOptimizationTests.testResourceManagerMemoryMonitoring()
    local test = TestFramework:new("Resource Manager Memory Monitoring")
    
    local memory_warnings = 0
    local memory_criticals = 0
    
    local resource_manager = ResourceManager:new({
        enabled = true,
        memory_monitoring = true,
        on_memory_warning = function(info)
            memory_warnings = memory_warnings + 1
        end,
        on_memory_critical = function(info)
            memory_criticals = memory_criticals + 1
        end
    })
    
    resource_manager:initialize()
    
    -- Test memory sampling
    local initial_stats = resource_manager:getStats()
    test:assert(initial_stats.memory.baseline > 0, "Should have baseline memory measurement")
    
    -- Simulate memory usage over time
    for i = 1, 10 do
        resource_manager:update(0.1)  -- Simulate 100ms updates
    end
    
    local updated_stats = resource_manager:getStats()
    test:assert(updated_stats.memory.samples_count > 0, "Should have memory samples")
    
    -- Test recommendations
    local recommendations = resource_manager:getRecommendations()
    test:assert(type(recommendations) == "table", "Should return recommendations table")
    
    -- Test aggressive mode
    resource_manager:setAggressiveMode(true)
    test:assert(resource_manager.aggressive_mode == true, "Should enable aggressive mode")
    
    resource_manager:setAggressiveMode(false)
    test:assert(resource_manager.aggressive_mode == false, "Should disable aggressive mode")
    
    return test:complete()
end

-- Test 6: Integration Test - All Components Working Together
function MemoryOptimizationTests.testIntegrationAllComponents()
    local test = TestFramework:new("Integration Test - All Components")
    
    -- Create resource manager
    local resource_manager = ResourceManager:new({
        enabled = true,
        memory_monitoring = true,
        leak_detection = true
    })
    resource_manager:initialize()
    
    -- Create frame buffer with resource manager's memory pool
    local frame_buffer = FrameBuffer:new(5, {
        use_memory_pool = true,
        intelligent_gc = true,
        memory_pool = resource_manager:getMemoryPool()
    })
    
    -- Simulate capture session
    for i = 1, 20 do
        -- Generate test frame data
        local frame_data = {}
        local size = 800 * 600 * 4
        for j = 1, size do
            frame_data[j] = (i + j) % 256
        end
        
        -- Add frame to buffer
        frame_buffer:addFrame(frame_data, 800, 600, 'RGBA', {frame_number = i})
        
        -- Track frame in resource manager
        resource_manager:trackResource(frame_data, "frame_buffers", {
            frame_number = i,
            size = size
        })
        
        -- Update resource manager
        resource_manager:update(0.033)
        
        -- Untrack every few frames to simulate cleanup
        if i % 5 == 0 then
            resource_manager:untrackResource(frame_data, "frame_buffers")
        end
    end
    
    -- Get comprehensive statistics
    local buffer_stats = frame_buffer:getOptimizedStats()
    local resource_stats = resource_manager:getStats()
    local pool_stats = resource_manager:getMemoryPool():getStats()
    
    -- Verify integration
    test:assert(buffer_stats.frame_count > 0, "Frame buffer should have frames")
    test:assert(resource_stats.memory.current > 0, "Resource manager should track memory")
    test:assert(pool_stats.global_stats.total_allocations > 0, "Memory pool should have allocations")
    
    -- Test cleanup integration
    local cleanup_result = resource_manager:forceCleanup()
    frame_buffer:clear()
    
    test:assert(cleanup_result.memory_freed >= 0, "Should perform cleanup")
    test:assert(frame_buffer:getStats().frame_count == 0, "Frame buffer should be cleared")
    
    return test:complete()
end

-- Run all memory optimization tests
function MemoryOptimizationTests.runAllTests()
    local results = {}
    
    print("=== Memory Optimization Unit Tests ===")
    
    -- Run each test
    table.insert(results, MemoryOptimizationTests.testMemoryPoolBasicOperations())
    table.insert(results, MemoryOptimizationTests.testResourceManagerBasicOperations())
    table.insert(results, MemoryOptimizationTests.testFrameBufferMemoryOptimization())
    table.insert(results, MemoryOptimizationTests.testMemoryPoolCleanupEfficiency())
    table.insert(results, MemoryOptimizationTests.testResourceManagerMemoryMonitoring())
    table.insert(results, MemoryOptimizationTests.testIntegrationAllComponents())
    
    -- Summary
    local passed = 0
    local failed = 0
    
    for _, result in ipairs(results) do
        if result.success then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
    
    print(string.format("\n=== Memory Optimization Unit Test Summary ==="))
    print(string.format("Total tests: %d", #results))
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    
    if failed > 0 then
        print("\nFailed tests:")
        for _, result in ipairs(results) do
            if not result.success then
                print(string.format("  - %s: %s", result.test_name, result.error or "Unknown error"))
            end
        end
    end
    
    return {
        total = #results,
        passed = passed,
        failed = failed,
        results = results
    }
end

return MemoryOptimizationTests