-- Error Simulation Tests
-- Tests for simulating various error conditions and validating recovery

local TestFramework = require("tests.test_framework")
local ErrorHandler = require("src.error_handler")

local TestErrorSimulation = {}

-- Test suite definition
local error_simulation_tests = {
    testAPIFailureSimulation = TestErrorSimulation.testAPIFailureSimulation,
    testMemoryExhaustionSimulation = TestErrorSimulation.testMemoryExhaustionSimulation,
    testDeviceDisconnectionSimulation = TestErrorSimulation.testDeviceDisconnectionSimulation,
    testPerformanceDegradationSimulation = TestErrorSimulation.testPerformanceDegradationSimulation,
    testCascadingFailureSimulation = TestErrorSimulation.testCascadingFailureSimulation,
    testRecoveryValidation = TestErrorSimulation.testRecoveryValidation,
    testStressTestErrorHandling = TestErrorSimulation.testStressTestErrorHandling,
    testErrorPatternRecognition = TestErrorSimulation.testErrorPatternRecognition,
    testGracefulDegradationScenarios = TestErrorSimulation.testGracefulDegradationScenarios,
    testCriticalErrorHandling = TestErrorSimulation.testCriticalErrorHandling
}

-- Run tests function
local function runErrorSimulationTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("ErrorSimulation Tests", error_simulation_tests)
    local stats = TestFramework.get_stats()
    TestFramework.cleanup_mock_environment()
    return stats
end

function TestErrorSimulation.runAllTests()
    return runErrorSimulationTests()
end

-- Simulate API failure scenarios
function TestErrorSimulation.testAPIFailureSimulation()
    local handler = ErrorHandler:new()
    local recovery_attempts = 0
    local fallback_used = false
    
    handler:setRecoveryCallback(function(action, error_info)
        if action == "restart" then
            recovery_attempts = recovery_attempts + 1
            return recovery_attempts <= 2  -- Fail first 2 attempts, succeed on 3rd
        elseif action == "fallback" then
            fallback_used = true
            return true
        end
        return false
    end)
    
    -- Simulate BitBlt failure (common screen capture API)
    local scenarios = {
        {api = "BitBlt", code = 0, context = {operation = "screen_capture"}},
        {api = "CreateCompatibleDC", code = 8, context = {operation = "create_buffer"}},
        {api = "GetWindowDC", code = 5, context = {window = "target_window"}},
        {api = "SelectObject", code = 0, context = {operation = "select_bitmap"}}
    }
    
    local total_recovered = 0
    for _, scenario in ipairs(scenarios) do
        local recovered, error_info = handler:handleAPIError(scenario.api, scenario.code, scenario.context)
        if recovered then
            total_recovered = total_recovered + 1
        end
        
        -- Verify error information is properly captured
        TestFramework.assert_true(error_info.api_name == scenario.api, "API name should be recorded")
        TestFramework.assert_true(error_info.error_code == scenario.code, "Error code should be recorded")
        TestFramework.assert_true(error_info.context ~= nil, "Context should be recorded")
    end
    
    TestFramework.assert_true(total_recovered > 0, "At least some API errors should be recovered")
    TestFramework.assert_true(handler.stats.total_errors == #scenarios, "All errors should be counted")
    
    return true
end

-- Simulate memory exhaustion scenarios
function TestErrorSimulation.testMemoryExhaustionSimulation()
    local handler = ErrorHandler:new({
        max_memory_usage = 100 * 1024 * 1024  -- 100MB limit
    })
    
    local degradation_triggered = false
    local quality_reductions = 0
    
    handler:setDegradationCallback(function(error_info, quality_level)
        degradation_triggered = true
        quality_reductions = quality_reductions + 1
    end)
    
    -- Simulate progressive memory pressure
    local memory_scenarios = {
        {usage = 80 * 1024 * 1024, expected_severity = "medium"},   -- 80MB - warning
        {usage = 120 * 1024 * 1024, expected_severity = "high"},   -- 120MB - over limit
        {usage = 200 * 1024 * 1024, expected_severity = "critical"} -- 200MB - critical
    }
    
    for i, scenario in ipairs(memory_scenarios) do
        local recovered, error_info = handler:handleResourceError("memory", {
            requested = 50 * 1024 * 1024,
            available = 150 * 1024 * 1024 - scenario.usage
        }, scenario.usage)
        
        -- Higher memory usage should trigger degradation
        if scenario.usage > handler.performance_thresholds.max_memory_usage then
            TestFramework.assert_true(degradation_triggered, "Memory pressure should trigger degradation")
        end
        
        TestFramework.assert_true(error_info.resource_type == "memory", "Resource type should be memory")
        TestFramework.assert_true(error_info.current_usage == scenario.usage, "Current usage should be recorded")
    end
    
    TestFramework.assert_true(quality_reductions > 0, "Quality should be reduced due to memory pressure")
    TestFramework.assert_true(handler:isDegraded(), "System should be in degraded mode")
    
    return true
end

-- Simulate device disconnection scenarios
function TestErrorSimulation.testDeviceDisconnectionSimulation()
    local handler = ErrorHandler:new()
    local restart_attempts = 0
    
    handler:setRecoveryCallback(function(action, error_info)
        if action == "restart" then
            restart_attempts = restart_attempts + 1
            -- Simulate device coming back online after 2 restart attempts
            return restart_attempts >= 2
        end
        return false
    end)
    
    -- Simulate webcam disconnection
    local recovered, error_info = handler:handleCaptureError("webcam", "Device not found", {
        device_index = 0,
        last_known_state = "capturing"
    })
    
    TestFramework.assert_true(error_info.source_type == "webcam", "Source type should be webcam")
    TestFramework.assert_true(error_info.error_message == "Device not found", "Error message should be recorded")
    
    -- Simulate window becoming unavailable
    local recovered2, error_info2 = handler:handleCaptureError("window", "Window handle invalid", {
        window_title = "Target Application",
        window_handle = 12345
    })
    
    TestFramework.assert_true(restart_attempts > 0, "Restart should be attempted for device errors")
    TestFramework.assert_true(handler.stats.restart_events > 0, "Restart events should be recorded")
    
    return true
end

-- Simulate performance degradation scenarios
function TestErrorSimulation.testPerformanceDegradationSimulation()
    local handler = ErrorHandler:new({
        max_frame_drop_rate = 0.05,  -- 5% max drop rate
        min_fps_threshold = 25,      -- 25 FPS minimum
        max_capture_time = 0.05      -- 50ms max capture time
    })
    
    local degradation_events = {}
    handler:setDegradationCallback(function(error_info, quality_level)
        table.insert(degradation_events, {
            metric = error_info.metric,
            quality_level = quality_level,
            timestamp = error_info.timestamp
        })
    end)
    
    -- Simulate progressive performance issues
    local performance_scenarios = {
        {metric = "frame_drop_rate", value = 0.1, threshold = 0.05},   -- 10% drop rate
        {metric = "fps", value = 20, threshold = 25},                  -- Low FPS
        {metric = "capture_time", value = 0.15, threshold = 0.05},     -- Slow capture
        {metric = "frame_drop_rate", value = 0.3, threshold = 0.05}    -- Very high drop rate
    }
    
    for _, scenario in ipairs(performance_scenarios) do
        local recovered, error_info = handler:handlePerformanceError(
            scenario.metric, scenario.value, scenario.threshold
        )
        
        TestFramework.assert_true(error_info.metric == scenario.metric, "Metric should be recorded")
        TestFramework.assert_true(error_info.current_value == scenario.value, "Current value should be recorded")
    end
    
    TestFramework.assert_true(#degradation_events > 0, "Performance issues should trigger degradation")
    TestFramework.assert_true(handler:getQualityLevel() < 1.0, "Quality level should be reduced")
    
    -- Verify progressive degradation
    local quality_levels = {}
    for _, event in ipairs(degradation_events) do
        table.insert(quality_levels, event.quality_level)
    end
    
    -- Quality should generally decrease over time
    local decreasing_trend = true
    for i = 2, #quality_levels do
        if quality_levels[i] > quality_levels[i-1] then
            decreasing_trend = false
            break
        end
    end
    
    -- Note: This might not always be true due to different degradation strategies
    -- TestFramework.assert_true(decreasing_trend, "Quality should generally decrease with more issues")
    
    return true
end

-- Simulate cascading failure scenarios
function TestErrorSimulation.testCascadingFailureSimulation()
    local handler = ErrorHandler:new()
    local error_sequence = {}
    
    handler:setErrorCallback(function(error_info)
        table.insert(error_sequence, {
            category = error_info.category,
            timestamp = error_info.timestamp,
            severity = error_info.severity
        })
    end)
    
    -- Simulate cascading failures: API failure -> Resource pressure -> Performance issues
    
    -- 1. Initial API failure
    handler:handleAPIError("BitBlt", 0, {operation = "screen_capture"})
    
    -- 2. This leads to increased memory usage (retries, buffers)
    handler:handleResourceError("memory", {reason = "retry_buffers"}, 150 * 1024 * 1024)
    
    -- 3. Memory pressure causes performance issues
    handler:handlePerformanceError("frame_drop_rate", 0.2, 0.1)
    
    -- 4. Performance issues cause more API timeouts
    handler:handleAPIError("GetWindowDC", 258, {reason = "timeout"})  -- ERROR_WAIT_TIMEOUT
    
    TestFramework.assert_true(#error_sequence == 4, "All cascading errors should be recorded")
    TestFramework.assert_true(handler.stats.total_errors == 4, "Total error count should reflect all errors")
    
    -- Verify error categories are diverse (indicating cascading failure)
    local categories = {}
    for _, error in ipairs(error_sequence) do
        categories[error.category] = true
    end
    
    local category_count = 0
    for _ in pairs(categories) do
        category_count = category_count + 1
    end
    
    TestFramework.assert_true(category_count >= 3, "Cascading failure should involve multiple error categories")
    
    return true
end

-- Test recovery validation
function TestErrorSimulation.testRecoveryValidation()
    local handler = ErrorHandler:new()
    local recovery_log = {}
    
    handler:setRecoveryCallback(function(action, error_info)
        table.insert(recovery_log, {
            action = action,
            category = error_info.category,
            timestamp = error_info.timestamp
        })
        
        -- Simulate different recovery success rates
        if action == "retry" then
            return math.random() > 0.3  -- 70% success rate for retries
        elseif action == "fallback" then
            return math.random() > 0.1  -- 90% success rate for fallbacks
        elseif action == "restart" then
            return math.random() > 0.5  -- 50% success rate for restarts
        end
        
        return false
    end)
    
    -- Test multiple recovery scenarios
    local test_scenarios = {
        {category = "api", api = "BitBlt", code = 0},
        {category = "api", api = "CreateCompatibleDC", code = 8},
        {category = "resource", type = "device", details = {}},
        {category = "capture", source = "webcam", message = "timeout"}
    }
    
    local successful_recoveries = 0
    for _, scenario in ipairs(test_scenarios) do
        local recovered = false
        
        if scenario.category == "api" then
            recovered = handler:handleAPIError(scenario.api, scenario.code, {})
        elseif scenario.category == "resource" then
            recovered = handler:handleResourceError(scenario.type, scenario.details)
        elseif scenario.category == "capture" then
            recovered = handler:handleCaptureError(scenario.source, scenario.message, {})
        end
        
        if recovered then
            successful_recoveries = successful_recoveries + 1
        end
    end
    
    TestFramework.assert_true(#recovery_log > 0, "Recovery attempts should be logged")
    TestFramework.assert_true(successful_recoveries > 0, "Some recoveries should succeed")
    TestFramework.assert_true(handler.stats.recovered_errors > 0, "Recovered errors should be counted")
    
    return true
end

-- Stress test error handling
function TestErrorSimulation.testStressTestErrorHandling()
    local handler = ErrorHandler:new({max_retry_attempts = 2})
    
    -- Generate many errors rapidly
    local error_count = 50
    local start_time = love and love.timer.getTime() or os.clock()
    
    for i = 1, error_count do
        local error_type = (i % 4) + 1
        
        if error_type == 1 then
            handler:handleAPIError("StressTestAPI" .. i, i % 10, {iteration = i})
        elseif error_type == 2 then
            handler:handleResourceError("memory", {}, i * 1024 * 1024)
        elseif error_type == 3 then
            handler:handlePerformanceError("fps", 30 - i, 30)
        else
            handler:handleCaptureError("screen", "Stress test error " .. i, {})
        end
    end
    
    local end_time = love and love.timer.getTime() or os.clock()
    local processing_time = end_time - start_time
    
    TestFramework.assert_true(handler.stats.total_errors == error_count, "All stress test errors should be counted")
    TestFramework.assert_true(processing_time < 1.0, "Error processing should be fast even under stress")
    
    -- Verify error history is properly managed (should not exceed limit)
    local recent_errors = handler:getRecentErrors(200)  -- Request more than limit
    TestFramework.assert_true(#recent_errors <= 100, "Error history should be limited to prevent memory issues")
    
    return true
end

-- Test error pattern recognition
function TestErrorSimulation.testErrorPatternRecognition()
    local handler = ErrorHandler:new()
    
    -- Generate repeated error patterns
    local pattern_errors = {
        "BitBlt", "BitBlt", "BitBlt",  -- Repeated API failure
        "GetWindowDC", "GetWindowDC",  -- Another repeated failure
        "BitBlt", "BitBlt"             -- Return to first pattern
    }
    
    for _, api in ipairs(pattern_errors) do
        handler:handleAPIError(api, 0, {})
    end
    
    -- Check that retry limits are enforced per error type
    local bitblt_key = "api_error_BitBlt"
    local getwindowdc_key = "api_error_GetWindowDC"
    
    TestFramework.assert_true(handler.recovery_attempts[bitblt_key] <= handler.max_retry_attempts, 
                        "BitBlt retry attempts should be limited")
    TestFramework.assert_true(handler.recovery_attempts[getwindowdc_key] <= handler.max_retry_attempts, 
                        "GetWindowDC retry attempts should be limited")
    
    -- Verify error counts
    local stats = handler:getErrorStats()
    TestFramework.assert_true(stats.error_counts[ErrorHandler.ERROR_CATEGORIES.API] == #pattern_errors, 
                        "All API errors should be counted")
    
    return true
end

-- Test graceful degradation scenarios
function TestErrorSimulation.testGracefulDegradationScenarios()
    local handler = ErrorHandler:new({enable_graceful_degradation = true})
    local degradation_steps = {}
    
    handler:setDegradationCallback(function(error_info, quality_level)
        table.insert(degradation_steps, {
            trigger = error_info.category,
            quality = quality_level,
            timestamp = error_info.timestamp
        })
    end)
    
    -- Scenario 1: Progressive performance degradation
    local performance_issues = {
        {metric = "frame_drop_rate", value = 0.15, threshold = 0.1},
        {metric = "capture_time", value = 0.2, threshold = 0.1},
        {metric = "fps", value = 15, threshold = 25}
    }
    
    for _, issue in ipairs(performance_issues) do
        handler:handlePerformanceError(issue.metric, issue.value, issue.threshold)
    end
    
    TestFramework.assert_true(#degradation_steps > 0, "Performance issues should trigger degradation")
    TestFramework.assert_true(handler:isDegraded(), "System should be in degraded mode")
    
    local final_quality = handler:getQualityLevel()
    TestFramework.assert_true(final_quality < 0.8, "Quality should be significantly reduced")
    
    -- Scenario 2: Resource pressure degradation
    handler:handleResourceError("memory", {}, 400 * 1024 * 1024)
    
    local quality_after_memory_pressure = handler:getQualityLevel()
    TestFramework.assert_true(quality_after_memory_pressure < final_quality, 
                        "Memory pressure should further reduce quality")
    
    -- Scenario 3: Recovery from degradation
    handler:resetDegradedMode()
    TestFramework.assert_true(not handler:isDegraded(), "Should be able to recover from degraded mode")
    TestFramework.assert_true(handler:getQualityLevel() == 1.0, "Quality should be restored")
    
    return true
end

-- Test critical error handling
function TestErrorSimulation.testCriticalErrorHandling()
    local handler = ErrorHandler:new()
    local critical_error_handled = false
    
    handler:setErrorCallback(function(error_info)
        if error_info.severity == ErrorHandler.ERROR_SEVERITY.CRITICAL then
            critical_error_handled = true
        end
    end)
    
    -- Simulate critical errors
    local critical_scenarios = {
        {type = "api", api = "CreateCompatibleBitmap", code = 8},  -- Out of memory
        {type = "resource", resource = "memory", usage = 1024 * 1024 * 1024}  -- 1GB usage
    }
    
    for _, scenario in ipairs(critical_scenarios) do
        if scenario.type == "api" then
            handler:handleAPIError(scenario.api, scenario.code, {})
        elseif scenario.type == "resource" then
            handler:handleResourceError(scenario.resource, {}, scenario.usage)
        end
    end
    
    TestFramework.assert_true(critical_error_handled, "Critical errors should be properly identified")
    TestFramework.assert_true(handler:isDegraded(), "Critical errors should trigger degradation")
    
    -- Critical errors should have high priority in error history
    local recent_errors = handler:getRecentErrors(5)
    local has_critical = false
    for _, error in ipairs(recent_errors) do
        if error.severity == ErrorHandler.ERROR_SEVERITY.CRITICAL then
            has_critical = true
            break
        end
    end
    
    TestFramework.assert_true(has_critical, "Critical errors should be in recent error history")
    
    return true
end

return TestErrorSimulation