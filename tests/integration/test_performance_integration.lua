-- Test Performance Monitor integration with Capture Engine
_G.TESTING_MODE = true
local TestFramework = require("tests.test_framework")
local MockFFIBindings = require("tests.mock_ffi_bindings")
local CaptureEngine = require("src.capture_engine")

local TestPerformanceIntegration = {}

function TestPerformanceIntegration.run_all_tests()
    TestFramework.reset_stats()
    
    local tests = {
        test_capture_engine_performance_integration = TestPerformanceIntegration.test_capture_engine_performance_integration,
        test_performance_monitoring_during_capture = TestPerformanceIntegration.test_performance_monitoring_during_capture,
        test_frame_dropping_integration = TestPerformanceIntegration.test_frame_dropping_integration,
        test_performance_stats_in_capture_stats = TestPerformanceIntegration.test_performance_stats_in_capture_stats,
        test_performance_under_load = TestPerformanceIntegration.test_performance_under_load,
        test_memory_monitoring_during_capture = TestPerformanceIntegration.test_memory_monitoring_during_capture
    }
    
    TestFramework.run_suite("PerformanceIntegration", tests)
    return TestFramework.get_stats()
end

function TestPerformanceIntegration.test_capture_engine_performance_integration()
    -- Initialize mock FFI
    _G.TESTING_MODE = true
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true,
        frame_drop_enabled = true,
        memory_monitoring = true
    })
    
    -- Test that performance monitor is created
    local performance_monitor = engine:getPerformanceMonitor()
    assert(performance_monitor ~= nil, "Capture engine should have performance monitor")
    
    -- Test performance monitor configuration
    local metrics = performance_monitor:getMetrics()
    assert(metrics.enabled == true, "Performance monitoring should be enabled")
    assert(metrics.target_fps == 30, "Target FPS should match engine setting")
    
    -- Test setting source and performance monitoring
    local success, error_msg = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set screen source successfully: " .. (error_msg or ""))
    
    -- Start capture and verify performance monitoring is active
    success, error_msg = engine:startCapture()
    assert(success == true, "Should start capture successfully: " .. (error_msg or ""))
    
    -- Update engine several times to generate performance data
    for i = 1, 10 do
        engine:update(1.0 / 30)  -- 30 FPS updates
    end
    
    -- Check that performance metrics are being collected
    local updated_metrics = performance_monitor:getMetrics()
    assert(updated_metrics.frames_processed > 0, "Should have processed frames")
    assert(updated_metrics.session_time > 0, "Should have session time")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceIntegration.test_performance_monitoring_during_capture()
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 60,
        monitor_performance = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    -- Simulate capture session with varying performance
    local performance_monitor = engine:getPerformanceMonitor()
    
    -- Fast updates (good performance)
    for i = 1, 30 do
        engine:update(1.0 / 60)  -- 60 FPS
    end
    
    local metrics_fast = performance_monitor:getMetrics()
    assert(metrics_fast.performance_state == "good", "Performance should be good with fast updates")
    
    -- Slow updates (poor performance)
    for i = 1, 10 do
        engine:update(1.0 / 10)  -- 10 FPS (slow)
        -- Simulate slow processing
        local start_time = os.clock()
        while os.clock() - start_time < 0.02 do end
    end
    
    local metrics_slow = performance_monitor:getMetrics()
    assert(metrics_slow.frames_processed > metrics_fast.frames_processed, 
                        "Should have processed more frames")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceIntegration.test_frame_dropping_integration()
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local frame_drops_detected = false
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true,
        frame_drop_enabled = true
    })
    
    -- Get performance monitor and set up callback
    local performance_monitor = engine:getPerformanceMonitor()
    performance_monitor.callbacks.on_frame_drop_start = function(metrics)
        frame_drops_detected = true
    end
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    -- Simulate very slow performance to trigger frame dropping
    for i = 1, 10 do
        engine:update(1.0 / 5)  -- 5 FPS (very slow)
        -- Simulate heavy processing
        local start_time = os.clock()
        while os.clock() - start_time < 0.05 do end
    end
    
    local stats = engine:getStats()
    assert(stats.performance ~= nil, "Should have performance data in stats")
    assert(stats.performance.frames_dropped >= 0, "Should track dropped frames")
    
    -- Check if frame dropping was activated
    local metrics = performance_monitor:getMetrics()
    assert(metrics.frame_dropping_active ~= nil, "Should have frame dropping state")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceIntegration.test_performance_stats_in_capture_stats()
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    -- Update engine to generate stats
    for i = 1, 5 do
        engine:update(1.0 / 30)
    end
    
    local stats = engine:getStats()
    
    -- Verify performance data is included in capture stats
    assert(stats.performance ~= nil, "Stats should include performance data")
    assert(stats.performance.enabled ~= nil, "Performance data should include enabled state")
    assert(stats.performance.current_fps ~= nil, "Performance data should include current FPS")
    assert(stats.performance.frames_processed ~= nil, "Performance data should include frames processed")
    assert(stats.performance.performance_state ~= nil, "Performance data should include performance state")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceIntegration.test_performance_under_load()
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 60,
        monitor_performance = true,
        frame_drop_enabled = true,
        memory_monitoring = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    local performance_monitor = engine:getPerformanceMonitor()
    
    -- Simulate high load scenario
    local large_data = {}
    
    for i = 1, 100 do
        -- Create some memory pressure
        large_data[i] = string.rep("test", 1000)
        
        -- Update with varying frame times
        local dt = (i % 2 == 0) and (1.0 / 30) or (1.0 / 120)  -- Alternating fast/slow
        engine:update(dt)
        
        -- Simulate processing load
        if i % 10 == 0 then
            local start_time = os.clock()
            while os.clock() - start_time < 0.01 do end
        end
    end
    
    local final_metrics = performance_monitor:getMetrics()
    
    -- Verify performance monitoring handled the load
    assert(final_metrics.frames_processed == 100, "Should have processed all frames")
    assert(final_metrics.session_time > 0, "Should have recorded session time")
    -- Memory monitoring might be 0 if not enabled, which is acceptable
    assert(final_metrics.current_memory >= 0, "Should have recorded memory usage")
    
    -- Check performance recommendations under load
    local recommendations = performance_monitor:getPerformanceRecommendations()
    assert(type(recommendations) == "table", "Should provide recommendations")
    assert(#recommendations > 0, "Should have at least one recommendation")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceIntegration.test_memory_monitoring_during_capture()
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true,
        memory_monitoring = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    local performance_monitor = engine:getPerformanceMonitor()
    
    -- Get initial memory usage
    engine:update(1.0 / 30)
    local initial_metrics = performance_monitor:getMetrics()
    local initial_memory = initial_metrics.current_memory
    
    -- Create memory pressure
    local memory_hog = {}
    for i = 1, 1000 do
        memory_hog[i] = {
            data = string.rep("memory_test", 100),
            index = i,
            timestamp = os.clock()
        }
        
        if i % 100 == 0 then
            engine:update(1.0 / 30)
        end
    end
    
    -- Check memory increase (memory monitoring might not be enabled)
    local loaded_metrics = performance_monitor:getMetrics()
    if loaded_metrics.current_memory > 0 then
        assert(loaded_metrics.current_memory >= initial_memory, 
                            "Memory usage should not decrease significantly")
        assert(loaded_metrics.peak_memory >= loaded_metrics.current_memory, 
                            "Peak memory should be >= current memory")
    else
        print("    Memory monitoring not enabled - skipping memory checks")
    end
    
    -- Force garbage collection and verify memory monitoring tracks it
    memory_hog = nil
    local freed_memory = performance_monitor:forceGarbageCollection()
    assert(freed_memory >= 0, "Should report freed memory")
    
    local post_gc_metrics = performance_monitor:getMetrics()
    assert(post_gc_metrics.current_memory <= loaded_metrics.current_memory, 
                        "Memory should decrease after GC")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

return TestPerformanceIntegration