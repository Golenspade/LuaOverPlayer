-- Memory Optimization Stress Tests - Extended capture sessions and memory leak detection
-- Tests memory pool, resource manager, and intelligent garbage collection under stress

local TestFramework = require("tests.test_framework")
local FrameBuffer = require("src.frame_buffer")
local MemoryPool = require("src.memory_pool")
local ResourceManager = require("src.resource_manager")

local MemoryOptimizationStressTests = {}

-- Test configuration
local STRESS_TEST_CONFIG = {
    -- Extended session parameters
    EXTENDED_SESSION_DURATION = 300,  -- 5 minutes in seconds
    HIGH_FREQUENCY_DURATION = 60,     -- 1 minute of high frequency
    MEMORY_LEAK_DURATION = 120,       -- 2 minutes for leak detection
    
    -- Frame generation parameters
    FRAME_SIZES = {
        {width = 640, height = 480},    -- VGA
        {width = 1280, height = 720},   -- HD
        {width = 1920, height = 1080},  -- Full HD
        {width = 2560, height = 1440}   -- QHD
    },
    
    -- Stress test thresholds
    MAX_MEMORY_GROWTH_MB = 100,        -- Maximum acceptable memory growth
    MAX_GC_FREQUENCY = 10,             -- Maximum GC per minute
    MIN_POOL_EFFICIENCY = 70,          -- Minimum pool hit rate percentage
    MAX_LEAK_RATE_MB_PER_MIN = 5       -- Maximum leak rate
}

-- Helper function to generate test frame data
local function generateTestFrameData(width, height, pattern)
    pattern = pattern or "solid"
    local size = width * height * 4  -- RGBA
    local data = {}
    
    if pattern == "solid" then
        -- Solid color pattern
        for i = 1, size, 4 do
            data[i] = 255     -- R
            data[i+1] = 128   -- G
            data[i+2] = 64    -- B
            data[i+3] = 255   -- A
        end
    elseif pattern == "gradient" then
        -- Gradient pattern
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                local i = (y * width + x) * 4 + 1
                data[i] = math.floor((x / width) * 255)     -- R
                data[i+1] = math.floor((y / height) * 255)  -- G
                data[i+2] = 128                             -- B
                data[i+3] = 255                             -- A
            end
        end
    elseif pattern == "noise" then
        -- Random noise pattern
        math.randomseed(os.time())
        for i = 1, size do
            data[i] = math.random(0, 255)
        end
    end
    
    return data
end

-- Helper function to simulate time passage
local function simulateTime(duration, callback, interval)
    interval = interval or 0.033  -- ~30 FPS
    local elapsed = 0
    local frame_count = 0
    
    while elapsed < duration do
        if callback then
            callback(elapsed, frame_count)
        end
        
        elapsed = elapsed + interval
        frame_count = frame_count + 1
        
        -- Yield control periodically to prevent blocking
        if frame_count % 100 == 0 then
            collectgarbage("step", 1)  -- Small GC step
        end
    end
    
    return frame_count
end

-- Test 1: Extended capture session with memory monitoring
function MemoryOptimizationStressTests.testExtendedCaptureSession()
    local test = TestFramework:new("Extended Capture Session Memory Test")
    
    -- Create frame buffer with memory optimization
    local frame_buffer = FrameBuffer:new(5, {
        use_memory_pool = true,
        intelligent_gc = true,
        gc_threshold = 50
    })
    
    -- Create resource manager
    local resource_manager = ResourceManager:new({
        enabled = true,
        aggressive_mode = false,
        memory_monitoring = true,
        leak_detection = true
    })
    resource_manager:initialize()
    
    local initial_memory = collectgarbage("count") / 1024
    local frame_count = 0
    local memory_samples = {}
    
    test:log("Starting extended capture session...")
    test:log(string.format("Initial memory: %.2f MB", initial_memory))
    
    -- Simulate extended capture session
    local total_frames = simulateTime(STRESS_TEST_CONFIG.EXTENDED_SESSION_DURATION, function(elapsed, frame_num)
        -- Generate frame with varying sizes
        local size_index = (frame_num % #STRESS_TEST_CONFIG.FRAME_SIZES) + 1
        local size = STRESS_TEST_CONFIG.FRAME_SIZES[size_index]
        local pattern = (frame_num % 3 == 0) and "noise" or "gradient"
        
        local frame_data = generateTestFrameData(size.width, size.height, pattern)
        frame_buffer:addFrame(frame_data, size.width, size.height, 'RGBA', {
            frame_number = frame_num,
            pattern = pattern
        })
        
        frame_count = frame_count + 1
        
        -- Update resource manager
        resource_manager:update(0.033)
        
        -- Sample memory every 10 seconds
        if elapsed > 0 and math.floor(elapsed) % 10 == 0 and frame_num % 300 == 0 then
            local current_memory = collectgarbage("count") / 1024
            table.insert(memory_samples, {
                time = elapsed,
                memory = current_memory,
                frames = frame_count
            })
            
            test:log(string.format("Time: %.0fs, Memory: %.2f MB, Frames: %d", 
                     elapsed, current_memory, frame_count))
        end
    end, 0.033)
    
    local final_memory = collectgarbage("count") / 1024
    local memory_growth = final_memory - initial_memory
    
    -- Get statistics
    local buffer_stats = frame_buffer:getOptimizedStats()
    local resource_stats = resource_manager:getStats()
    local pool_stats = frame_buffer:getMemoryPool():getStats()
    
    test:log(string.format("Extended session completed:"))
    test:log(string.format("  Duration: %d seconds", STRESS_TEST_CONFIG.EXTENDED_SESSION_DURATION))
    test:log(string.format("  Total frames: %d", total_frames))
    test:log(string.format("  Final memory: %.2f MB", final_memory))
    test:log(string.format("  Memory growth: %.2f MB", memory_growth))
    test:log(string.format("  GC collections: %d", buffer_stats.memory_optimization.gc_stats.collections_triggered))
    test:log(string.format("  Memory freed by GC: %.2f MB", buffer_stats.memory_optimization.gc_stats.memory_freed_total))
    
    -- Verify memory growth is within acceptable limits
    test:assert(memory_growth < STRESS_TEST_CONFIG.MAX_MEMORY_GROWTH_MB, 
                string.format("Memory growth %.2f MB exceeds limit %d MB", 
                             memory_growth, STRESS_TEST_CONFIG.MAX_MEMORY_GROWTH_MB))
    
    -- Verify pool efficiency
    local frame_pool_stats = pool_stats.pool_stats.FRAME_DATA
    if frame_pool_stats then
        test:assert(frame_pool_stats.reuse_rate >= STRESS_TEST_CONFIG.MIN_POOL_EFFICIENCY,
                    string.format("Pool efficiency %.1f%% below minimum %d%%", 
                                 frame_pool_stats.reuse_rate, STRESS_TEST_CONFIG.MIN_POOL_EFFICIENCY))
    end
    
    -- Check for potential memory leaks
    test:assert(resource_stats.leak_detection.potential_leaks == 0,
                string.format("Detected %d potential memory leaks", resource_stats.leak_detection.potential_leaks))
    
    return test:complete()
end

-- Test 2: High frequency frame generation stress test
function MemoryOptimizationStressTests.testHighFrequencyStress()
    local test = TestFramework:new("High Frequency Frame Generation Stress Test")
    
    local frame_buffer = FrameBuffer:new(3, {
        use_memory_pool = true,
        intelligent_gc = true,
        gc_threshold = 30
    })
    
    local initial_memory = collectgarbage("count") / 1024
    local frame_count = 0
    local gc_count_before = frame_buffer:getGCStats().collections_triggered
    
    test:log("Starting high frequency stress test...")
    test:log(string.format("Initial memory: %.2f MB", initial_memory))
    
    -- Generate frames at very high frequency (120 FPS equivalent)
    local total_frames = simulateTime(STRESS_TEST_CONFIG.HIGH_FREQUENCY_DURATION, function(elapsed, frame_num)
        -- Use large frames to stress memory system
        local frame_data = generateTestFrameData(1920, 1080, "noise")
        frame_buffer:addFrame(frame_data, 1920, 1080, 'RGBA', {
            frame_number = frame_num,
            high_frequency = true
        })
        
        frame_count = frame_count + 1
    end, 0.0083)  -- ~120 FPS
    
    local final_memory = collectgarbage("count") / 1024
    local memory_growth = final_memory - initial_memory
    local gc_count_after = frame_buffer:getGCStats().collections_triggered
    local gc_triggered = gc_count_after - gc_count_before
    
    test:log(string.format("High frequency test completed:"))
    test:log(string.format("  Duration: %d seconds", STRESS_TEST_CONFIG.HIGH_FREQUENCY_DURATION))
    test:log(string.format("  Total frames: %d (~%.1f FPS)", total_frames, total_frames / STRESS_TEST_CONFIG.HIGH_FREQUENCY_DURATION))
    test:log(string.format("  Memory growth: %.2f MB", memory_growth))
    test:log(string.format("  GC collections triggered: %d", gc_triggered))
    
    -- Verify system handled high frequency without excessive memory growth
    test:assert(memory_growth < 50, 
                string.format("High frequency test memory growth %.2f MB too high", memory_growth))
    
    -- Verify GC frequency is reasonable
    local gc_per_minute = (gc_triggered / STRESS_TEST_CONFIG.HIGH_FREQUENCY_DURATION) * 60
    test:assert(gc_per_minute <= STRESS_TEST_CONFIG.MAX_GC_FREQUENCY,
                string.format("GC frequency %.1f/min exceeds limit %d/min", 
                             gc_per_minute, STRESS_TEST_CONFIG.MAX_GC_FREQUENCY))
    
    return test:complete()
end

-- Test 3: Memory leak detection test
function MemoryOptimizationStressTests.testMemoryLeakDetection()
    local test = TestFramework:new("Memory Leak Detection Test")
    
    local resource_manager = ResourceManager:new({
        enabled = true,
        leak_detection = true,
        debug_mode = true
    })
    resource_manager:initialize()
    
    local initial_memory = collectgarbage("count") / 1024
    local leaked_objects = {}
    
    test:log("Starting memory leak detection test...")
    test:log(string.format("Initial memory: %.2f MB", initial_memory))
    
    -- Simulate memory leak by creating objects and not releasing them
    local leak_simulation_frames = simulateTime(STRESS_TEST_CONFIG.MEMORY_LEAK_DURATION / 2, function(elapsed, frame_num)
        -- Create "leaked" objects
        local leaked_data = generateTestFrameData(800, 600, "solid")
        table.insert(leaked_objects, leaked_data)
        
        resource_manager:update(0.033)
        
        -- Intentionally don't release these objects to simulate leak
    end, 0.1)  -- 10 FPS for leak simulation
    
    -- Continue running without creating more leaks
    local normal_frames = simulateTime(STRESS_TEST_CONFIG.MEMORY_LEAK_DURATION / 2, function(elapsed, frame_num)
        resource_manager:update(0.033)
    end, 0.033)
    
    local final_memory = collectgarbage("count") / 1024
    local memory_growth = final_memory - initial_memory
    local resource_stats = resource_manager:getStats()
    
    test:log(string.format("Memory leak test completed:"))
    test:log(string.format("  Simulated leak objects: %d", #leaked_objects))
    test:log(string.format("  Memory growth: %.2f MB", memory_growth))
    test:log(string.format("  Potential leaks detected: %d", resource_stats.leak_detection.potential_leaks))
    test:log(string.format("  Leak warnings: %d", resource_stats.leak_detection.leak_warnings))
    
    -- Verify leak detection is working
    test:assert(resource_stats.leak_detection.potential_leaks > 0,
                "Memory leak detection should have detected simulated leaks")
    
    -- Clean up leaked objects
    leaked_objects = {}
    collectgarbage("collect")
    
    return test:complete()
end

-- Test 4: Memory pool efficiency under various allocation patterns
function MemoryOptimizationStressTests.testMemoryPoolEfficiency()
    local test = TestFramework:new("Memory Pool Efficiency Test")
    
    local memory_pool = MemoryPool:new({
        enabled = true,
        debug_mode = true
    })
    
    local initial_memory = collectgarbage("count") / 1024
    local allocated_objects = {}
    
    test:log("Starting memory pool efficiency test...")
    
    -- Test 1: Rapid allocation and deallocation
    test:log("Phase 1: Rapid allocation/deallocation")
    for i = 1, 1000 do
        local obj = memory_pool:acquire("FRAME_DATA")
        table.insert(allocated_objects, obj)
        
        -- Release every other object immediately
        if i % 2 == 0 then
            memory_pool:release(table.remove(allocated_objects))
        end
    end
    
    -- Release remaining objects
    for _, obj in ipairs(allocated_objects) do
        memory_pool:release(obj)
    end
    allocated_objects = {}
    
    local phase1_stats = memory_pool:getStats()
    test:log(string.format("  Pool hits: %d, misses: %d, efficiency: %.1f%%", 
             phase1_stats.global_stats.pool_hits, 
             phase1_stats.global_stats.pool_misses,
             (phase1_stats.global_stats.pool_hits / (phase1_stats.global_stats.pool_hits + phase1_stats.global_stats.pool_misses)) * 100))
    
    -- Test 2: Burst allocation pattern
    test:log("Phase 2: Burst allocation pattern")
    for burst = 1, 10 do
        -- Allocate burst
        for i = 1, 50 do
            local obj = memory_pool:acquire("PIXEL_BUFFER", 1920 * 1080 * 4)
            table.insert(allocated_objects, obj)
        end
        
        -- Release burst
        for i = 1, 25 do  -- Release half
            memory_pool:release(table.remove(allocated_objects))
        end
        
        -- Cleanup every few bursts
        if burst % 3 == 0 then
            memory_pool:cleanup()
        end
    end
    
    -- Clean up remaining
    for _, obj in ipairs(allocated_objects) do
        memory_pool:release(obj)
    end
    
    local final_stats = memory_pool:getStats()
    local final_memory = collectgarbage("count") / 1024
    local memory_growth = final_memory - initial_memory
    
    test:log(string.format("Memory pool efficiency test completed:"))
    test:log(string.format("  Total allocations: %d", final_stats.global_stats.total_allocations))
    test:log(string.format("  Pool hits: %d", final_stats.global_stats.pool_hits))
    test:log(string.format("  Pool efficiency: %.1f%%", 
             (final_stats.global_stats.pool_hits / final_stats.global_stats.total_allocations) * 100))
    test:log(string.format("  Memory growth: %.2f MB", memory_growth))
    
    -- Verify pool efficiency
    local efficiency = (final_stats.global_stats.pool_hits / final_stats.global_stats.total_allocations) * 100
    test:assert(efficiency >= STRESS_TEST_CONFIG.MIN_POOL_EFFICIENCY,
                string.format("Pool efficiency %.1f%% below minimum %d%%", 
                             efficiency, STRESS_TEST_CONFIG.MIN_POOL_EFFICIENCY))
    
    return test:complete()
end

-- Test 5: Resource manager under sustained load
function MemoryOptimizationStressTests.testResourceManagerSustainedLoad()
    local test = TestFramework:new("Resource Manager Sustained Load Test")
    
    local resource_manager = ResourceManager:new({
        enabled = true,
        aggressive_mode = false,
        memory_monitoring = true,
        leak_detection = true
    })
    resource_manager:initialize()
    
    local frame_buffer = FrameBuffer:new(10, {
        use_memory_pool = true,
        intelligent_gc = true
    })
    
    local initial_memory = collectgarbage("count") / 1024
    local frame_count = 0
    local cleanup_count = 0
    
    test:log("Starting resource manager sustained load test...")
    
    -- Simulate sustained load with varying patterns
    local total_frames = simulateTime(180, function(elapsed, frame_num)  -- 3 minutes
        -- Vary frame sizes and patterns to create different memory pressures
        local size_pattern = math.floor(elapsed / 30) % 4 + 1  -- Change every 30 seconds
        local size = STRESS_TEST_CONFIG.FRAME_SIZES[size_pattern]
        
        local pattern = "noise"
        if elapsed > 60 and elapsed < 120 then
            pattern = "gradient"  -- Different pattern in middle minute
        end
        
        local frame_data = generateTestFrameData(size.width, size.height, pattern)
        frame_buffer:addFrame(frame_data, size.width, size.height, 'RGBA', {
            frame_number = frame_num,
            load_test = true
        })
        
        -- Track some resources
        if frame_num % 10 == 0 then
            resource_manager:trackResource(frame_data, "temporary_objects", {
                size = size.width * size.height * 4,
                created_at = elapsed
            })
        end
        
        resource_manager:update(0.033)
        frame_count = frame_count + 1
        
        -- Trigger cleanup occasionally
        if frame_num % 500 == 0 then
            resource_manager:forceCleanup()
            cleanup_count = cleanup_count + 1
        end
    end, 0.033)
    
    local final_memory = collectgarbage("count") / 1024
    local memory_growth = final_memory - initial_memory
    local resource_stats = resource_manager:getStats()
    
    test:log(string.format("Sustained load test completed:"))
    test:log(string.format("  Duration: 180 seconds"))
    test:log(string.format("  Total frames: %d", total_frames))
    test:log(string.format("  Memory growth: %.2f MB", memory_growth))
    test:log(string.format("  Forced cleanups: %d", cleanup_count))
    test:log(string.format("  GC collections: %d", resource_stats.garbage_collection.total_collections))
    test:log(string.format("  Average GC time: %.3f ms", resource_stats.garbage_collection.average_gc_time * 1000))
    
    -- Verify sustained load handling
    test:assert(memory_growth < STRESS_TEST_CONFIG.MAX_MEMORY_GROWTH_MB,
                string.format("Memory growth %.2f MB exceeds limit", memory_growth))
    
    test:assert(resource_stats.leak_detection.potential_leaks <= 1,
                string.format("Too many potential leaks detected: %d", resource_stats.leak_detection.potential_leaks))
    
    return test:complete()
end

-- Run all memory optimization stress tests
function MemoryOptimizationStressTests.runAllTests()
    local results = {}
    
    print("=== Memory Optimization Stress Tests ===")
    print("WARNING: These tests may take several minutes to complete")
    print("")
    
    -- Run each test
    table.insert(results, MemoryOptimizationStressTests.testExtendedCaptureSession())
    table.insert(results, MemoryOptimizationStressTests.testHighFrequencyStress())
    table.insert(results, MemoryOptimizationStressTests.testMemoryLeakDetection())
    table.insert(results, MemoryOptimizationStressTests.testMemoryPoolEfficiency())
    table.insert(results, MemoryOptimizationStressTests.testResourceManagerSustainedLoad())
    
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
    
    print(string.format("\n=== Memory Optimization Stress Test Summary ==="))
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

return MemoryOptimizationStressTests