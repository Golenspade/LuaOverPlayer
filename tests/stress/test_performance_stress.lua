-- Performance stress tests for various load conditions
_G.TESTING_MODE = true
local TestFramework = require("tests.test_framework")
local MockFFIBindings = require("tests.mock_ffi_bindings")
local CaptureEngine = require("src.capture_engine")
local PerformanceMonitor = require("src.performance_monitor")

local TestPerformanceStress = {}

function TestPerformanceStress.run_all_tests()
    TestFramework.reset_stats()
    
    local tests = {
        test_high_frame_rate_stress = TestPerformanceStress.test_high_frame_rate_stress,
        test_memory_pressure_stress = TestPerformanceStress.test_memory_pressure_stress,
        test_extended_capture_session = TestPerformanceStress.test_extended_capture_session,
        test_rapid_source_switching = TestPerformanceStress.test_rapid_source_switching,
        test_concurrent_performance_monitoring = TestPerformanceStress.test_concurrent_performance_monitoring,
        test_frame_drop_recovery = TestPerformanceStress.test_frame_drop_recovery
    }
    
    TestFramework.run_suite("PerformanceStress", tests)
    return TestFramework.get_stats()
end

function TestPerformanceStress.test_high_frame_rate_stress()
    print("  Testing high frame rate stress (120 FPS)...")
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 120,
        monitor_performance = true,
        frame_drop_enabled = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    local performance_monitor = engine:getPerformanceMonitor()
    local start_time = os.clock()
    
    -- Run at high frame rate for 5 seconds (600 frames)
    local frame_count = 0
    while os.clock() - start_time < 5.0 and frame_count < 600 do
        engine:update(1.0 / 120)  -- 120 FPS
        frame_count = frame_count + 1
        
        -- Add some processing load every 10 frames
        if frame_count % 10 == 0 then
            local process_start = os.clock()
            while os.clock() - process_start < 0.001 do end
        end
    end
    
    local metrics = performance_monitor:getMetrics()
    
    assert(metrics.frames_processed > 500, "Should process most frames at high rate")
    assert(metrics.session_time >= 4.5, "Should run for expected duration")
    assert(metrics.current_fps > 0, "Should maintain positive FPS")
    
    -- Check that performance monitoring handled the high load
    local recommendations = performance_monitor:getPerformanceRecommendations()
    assert(type(recommendations) == "table", "Should provide recommendations")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceStress.test_memory_pressure_stress()
    print("  Testing memory pressure stress...")
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
    local memory_hogs = {}
    
    -- Create increasing memory pressure
    for i = 1, 50 do
        -- Create large data structures
        memory_hogs[i] = {}
        for j = 1, 100 do
            memory_hogs[i][j] = {
                data = string.rep("stress_test_data_" .. i .. "_" .. j, 50),
                timestamp = os.clock(),
                frame_number = i,
                nested_data = {}
            }
            
            -- Add nested data to increase memory usage
            for k = 1, 10 do
                memory_hogs[i][j].nested_data[k] = string.rep("nested", 20)
            end
        end
        
        -- Update engine during memory allocation
        engine:update(1.0 / 30)
        
        -- Check memory every 10 iterations
        if i % 10 == 0 then
            local metrics = performance_monitor:getMetrics()
            assert(metrics.current_memory > 0, "Should track memory usage")
            
            -- Force GC occasionally to test memory monitoring
            if i % 20 == 0 then
                local freed = performance_monitor:forceGarbageCollection()
                assert(freed >= 0, "Should report freed memory")
            end
        end
    end
    
    local final_metrics = performance_monitor:getMetrics()
    assert(final_metrics.peak_memory > 0, "Should have recorded peak memory")
    assert(final_metrics.current_memory > 0, "Should have current memory usage")
    assert(final_metrics.frames_processed == 50, "Should have processed all frames")
    
    -- Clean up memory and verify monitoring tracks it
    memory_hogs = nil
    local freed_memory = performance_monitor:forceGarbageCollection()
    assert(freed_memory > 0, "Should free significant memory")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceStress.test_extended_capture_session()
    print("  Testing extended capture session...")
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true,
        frame_drop_enabled = true,
        memory_monitoring = true
    })
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    local performance_monitor = engine:getPerformanceMonitor()
    local start_time = os.clock()
    
    -- Run for extended period (10 seconds, 300 frames)
    local frame_count = 0
    local memory_snapshots = {}
    
    while os.clock() - start_time < 10.0 and frame_count < 300 do
        engine:update(1.0 / 30)
        frame_count = frame_count + 1
        
        -- Vary the load to simulate real usage
        if frame_count % 30 == 0 then  -- Every second
            -- Take memory snapshot
            local metrics = performance_monitor:getMetrics()
            table.insert(memory_snapshots, {
                time = os.clock() - start_time,
                memory = metrics.current_memory,
                fps = metrics.current_fps,
                frame = frame_count
            })
            
            -- Simulate periodic heavy processing
            local process_start = os.clock()
            while os.clock() - process_start < 0.01 do end
        end
        
        -- Simulate varying frame processing times
        if frame_count % 60 == 0 then  -- Every 2 seconds
            local process_start = os.clock()
            while os.clock() - process_start < 0.02 do end
        end
    end
    
    local final_metrics = performance_monitor:getMetrics()
    
    assert(final_metrics.frames_processed >= 250, "Should process most frames in extended session")
    assert(final_metrics.session_time >= 9.0, "Should run for expected duration")
    assert(#memory_snapshots >= 8, "Should have taken multiple memory snapshots")
    
    -- Verify memory stability over time (no major leaks)
    local first_memory = memory_snapshots[1].memory
    local last_memory = memory_snapshots[#memory_snapshots].memory
    local memory_growth = last_memory - first_memory
    
    -- Allow some memory growth but not excessive
    assert(memory_growth < 50, "Memory growth should be reasonable over extended session")
    
    -- Check performance consistency
    local fps_values = {}
    for _, snapshot in ipairs(memory_snapshots) do
        table.insert(fps_values, snapshot.fps)
    end
    
    -- Calculate FPS variance
    local fps_sum = 0
    for _, fps in ipairs(fps_values) do
        fps_sum = fps_sum + fps
    end
    local fps_avg = fps_sum / #fps_values
    
    assert(fps_avg > 15, "Average FPS should be reasonable")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceStress.test_rapid_source_switching()
    print("  Testing rapid source switching...")
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true
    })
    
    local performance_monitor = engine:getPerformanceMonitor()
    local sources = {"screen", "window"}
    local switch_count = 0
    
    -- Rapidly switch between sources
    for i = 1, 20 do
        local source = sources[(i % 2) + 1]
        local config = {}
        
        if source == "screen" then
            config = {mode = "FULL_SCREEN"}
        else
            config = {window = "Test Window", tracking = true}
        end
        
        local success = engine:setSource(source, config)
        assert(success == true, "Should set source: " .. source)
        
        success = engine:startCapture()
        assert(success == true, "Should start capture")
        
        -- Run briefly
        for j = 1, 5 do
            engine:update(1.0 / 30)
        end
        
        engine:stopCapture()
        switch_count = switch_count + 1
        
        -- Check performance monitoring stability
        local metrics = performance_monitor:getMetrics()
        assert(metrics.enabled == true, "Performance monitoring should remain enabled")
    end
    
    assert(switch_count == 20, "Should have completed all source switches")
    
    local final_metrics = performance_monitor:getMetrics()
    assert(final_metrics.frames_processed > 0, "Should have processed frames during switching")
    
    MockFFIBindings.cleanup()
    
    return true
end

function TestPerformanceStress.test_concurrent_performance_monitoring()
    print("  Testing concurrent performance monitoring...")
    
    -- Create multiple performance monitors to test concurrent usage
    local monitors = {}
    local monitor_count = 5
    
    for i = 1, monitor_count do
        monitors[i] = PerformanceMonitor:new({
            target_fps = 30 + (i * 10),  -- Different target FPS for each
            frame_drop_enabled = true,
            memory_monitoring = true
        })
        monitors[i]:initialize()
    end
    
    -- Update all monitors concurrently
    for frame = 1, 100 do
        local dt = 1.0 / 30
        
        for i = 1, monitor_count do
            monitors[i]:update(dt)
            
            -- Add varying load to each monitor
            if frame % (i + 1) == 0 then
                local start_time = os.clock()
                while os.clock() - start_time < 0.001 * i do end
            end
        end
        
        -- Simulate some global processing
        if frame % 10 == 0 then
            local start_time = os.clock()
            while os.clock() - start_time < 0.005 do end
        end
    end
    
    -- Verify all monitors collected data independently
    for i = 1, monitor_count do
        local metrics = monitors[i]:getMetrics()
        assert(metrics.frames_processed == 100, "Monitor " .. i .. " should process all frames")
        assert(metrics.target_fps == 30 + (i * 10), "Monitor " .. i .. " should have correct target FPS")
        assert(metrics.session_time > 0, "Monitor " .. i .. " should have session time")
    end
    
    return true
end

function TestPerformanceStress.test_frame_drop_recovery()
    print("  Testing frame drop recovery...")
    _G.TESTING_MODE = true
    MockFFIBindings.setup()
    
    local frame_drop_events = {
        start_count = 0,
        stop_count = 0
    }
    
    local engine = CaptureEngine:new({
        frame_rate = 60,
        monitor_performance = true,
        frame_drop_enabled = true
    })
    
    local performance_monitor = engine:getPerformanceMonitor()
    
    -- Set up callbacks to track frame drop events
    performance_monitor.callbacks.on_frame_drop_start = function(metrics)
        frame_drop_events.start_count = frame_drop_events.start_count + 1
    end
    
    performance_monitor.callbacks.on_frame_drop_stop = function(metrics)
        frame_drop_events.stop_count = frame_drop_events.stop_count + 1
    end
    
    local success = engine:setSource("screen", {mode = "FULL_SCREEN"})
    assert(success == true, "Should set source")
    
    success = engine:startCapture()
    assert(success == true, "Should start capture")
    
    -- Phase 1: Cause performance issues to trigger frame dropping
    for i = 1, 10 do
        engine:update(1.0 / 10)  -- 10 FPS (slow)
        -- Simulate heavy processing
        local start_time = os.clock()
        while os.clock() - start_time < 0.05 do end
    end
    
    local metrics_during_drop = performance_monitor:getMetrics()
    assert(metrics_during_drop.frames_dropped > 0, "Should have dropped frames during poor performance")
    
    -- Phase 2: Improve performance to trigger recovery
    for i = 1, 20 do
        engine:update(1.0 / 60)  -- 60 FPS (good)
        -- Minimal processing
        local start_time = os.clock()
        while os.clock() - start_time < 0.001 do end
    end
    
    local metrics_after_recovery = performance_monitor:getMetrics()
    assert(metrics_after_recovery.frames_processed > metrics_during_drop.frames_processed, 
                        "Should have processed more frames after recovery")
    
    -- Phase 3: Cause issues again to test repeated recovery
    for i = 1, 8 do
        engine:update(1.0 / 8)  -- 8 FPS (very slow)
        local start_time = os.clock()
        while os.clock() - start_time < 0.06 do end
    end
    
    -- Phase 4: Final recovery
    for i = 1, 15 do
        engine:update(1.0 / 60)  -- 60 FPS (good)
    end
    
    local final_metrics = performance_monitor:getMetrics()
    
    -- Verify frame drop recovery worked
    assert(frame_drop_events.start_count > 0, "Frame dropping should have started")
    assert(final_metrics.frames_processed > 40, "Should have processed frames throughout test")
    
    -- Get performance recommendations after stress test
    local recommendations = performance_monitor:getPerformanceRecommendations()
    assert(type(recommendations) == "table", "Should provide recommendations after stress")
    
    engine:stopCapture()
    MockFFIBindings.cleanup()
    
    return true
end

return TestPerformanceStress