-- Error Handler Integration Tests
-- Tests for error handling integration with capture components

local TestFramework = require("tests.test_framework")
local ErrorHandler = require("src.error_handler")
local EnhancedCaptureEngine = require("src.enhanced_capture_engine")

local TestErrorHandlerIntegration = {}

-- Test suite definition
local error_handler_integration_tests = {
    testCaptureEngineErrorIntegration = TestErrorHandlerIntegration.testCaptureEngineErrorIntegration,
    testPerformanceMonitoringIntegration = TestErrorHandlerIntegration.testPerformanceMonitoringIntegration,
    testRecoveryCallbackIntegration = TestErrorHandlerIntegration.testRecoveryCallbackIntegration,
    testDegradationCallbackIntegration = TestErrorHandlerIntegration.testDegradationCallbackIntegration,
    testErrorPropagationThroughComponents = TestErrorHandlerIntegration.testErrorPropagationThroughComponents,
    testCascadingErrorHandling = TestErrorHandlerIntegration.testCascadingErrorHandling,
    testErrorHandlerWithRealCapture = TestErrorHandlerIntegration.testErrorHandlerWithRealCapture,
    testSystemWideErrorRecovery = TestErrorHandlerIntegration.testSystemWideErrorRecovery,
    testErrorHandlerMemoryManagement = TestErrorHandlerIntegration.testErrorHandlerMemoryManagement,
    testErrorHandlerThreadSafety = TestErrorHandlerIntegration.testErrorHandlerThreadSafety
}

-- Run tests function
local function runErrorHandlerIntegrationTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("ErrorHandlerIntegration Tests", error_handler_integration_tests)
    local stats = TestFramework.get_stats()
    TestFramework.cleanup_mock_environment()
    return stats
end

function TestErrorHandlerIntegration.runAllTests()
    return runErrorHandlerIntegrationTests()
end

-- Test error handler integration with capture engine
function TestErrorHandlerIntegration.testCaptureEngineErrorIntegration()
    local capture_engine = EnhancedCaptureEngine:new({
        enable_auto_recovery = true,
        enable_graceful_degradation = true,
        max_retry_attempts = 2
    })
    
    local error_handler = capture_engine:getErrorHandler()
    TestFramework.assert_true(error_handler ~= nil, "Capture engine should have error handler")
    
    -- Test that errors are properly routed through error handler
    local error_logged = false
    error_handler:setErrorCallback(function(error_info)
        error_logged = true
        TestFramework.assert_true(error_info.category ~= nil, "Error should have category")
        TestFramework.assert_true(error_info.timestamp ~= nil, "Error should have timestamp")
    end)
    
    -- Simulate a capture error
    error_handler:handleCaptureError("screen", "Test capture failure", {
        operation = "test_capture"
    })
    
    TestFramework.assert_true(error_logged, "Error should be logged through callback")
    
    -- Test error statistics integration
    local stats = capture_engine:getStats()
    TestFramework.assert_true(stats.error_stats ~= nil, "Stats should include error information")
    TestFramework.assert_true(stats.error_stats.total_errors > 0, "Error count should be tracked")
    TestFramework.assert_true(stats.recent_errors ~= nil, "Recent errors should be available")
    
    return true
end

-- Test performance monitoring integration
function TestErrorHandlerIntegration.testPerformanceMonitoringIntegration()
    local capture_engine = EnhancedCaptureEngine:new({
        monitor_performance = true,
        max_frame_drop_rate = 0.1,
        max_capture_time = 0.05,
        min_fps_threshold = 20
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local performance_errors = {}
    
    error_handler:setErrorCallback(function(error_info)
        if error_info.category == ErrorHandler.ERROR_CATEGORIES.PERFORMANCE then
            table.insert(performance_errors, error_info)
        end
    end)
    
    -- Simulate performance issues
    error_handler:handlePerformanceError("frame_drop_rate", 0.25, 0.1)
    error_handler:handlePerformanceError("capture_time", 0.15, 0.05)
    error_handler:handlePerformanceError("fps", 15, 20)
    
    TestFramework.assert_true(#performance_errors == 3, "All performance errors should be captured")
    
    -- Verify different performance metrics are handled
    local metrics = {}
    for _, error in ipairs(performance_errors) do
        metrics[error.metric] = true
    end
    
    TestFramework.assert_true(metrics["frame_drop_rate"], "Frame drop rate errors should be handled")
    TestFramework.assert_true(metrics["capture_time"], "Capture time errors should be handled")
    TestFramework.assert_true(metrics["fps"], "FPS errors should be handled")
    
    return true
end

-- Test recovery callback integration
function TestErrorHandlerIntegration.testRecoveryCallbackIntegration()
    local capture_engine = EnhancedCaptureEngine:new({
        enable_auto_recovery = true
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local recovery_actions = {}
    
    -- Override recovery callback to track actions
    local original_callback = error_handler.recovery_callback
    error_handler:setRecoveryCallback(function(action, error_info)
        table.insert(recovery_actions, {
            action = action,
            category = error_info.category,
            timestamp = error_info.timestamp
        })
        
        -- Call original callback if it exists
        if original_callback then
            return original_callback(action, error_info)
        end
        
        return true  -- Simulate successful recovery
    end)
    
    -- Trigger errors that should cause recovery attempts
    error_handler:handleCaptureError("webcam", "Device disconnected", {})
    error_handler:handleAPIError("BitBlt", 5, {})  -- Access denied
    error_handler:handleResourceError("memory", {}, 600 * 1024 * 1024)
    
    TestFramework.assert_true(#recovery_actions > 0, "Recovery actions should be triggered")
    
    -- Verify different recovery strategies are used
    local strategies = {}
    for _, action in ipairs(recovery_actions) do
        strategies[action.action] = true
    end
    
    TestFramework.assert_true(next(strategies) ~= nil, "At least one recovery strategy should be used")
    
    return true
end

-- Test degradation callback integration
function TestErrorHandlerIntegration.testDegradationCallbackIntegration()
    local capture_engine = EnhancedCaptureEngine:new({
        enable_graceful_degradation = true
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local degradation_events = {}
    
    -- Override degradation callback to track events
    local original_callback = error_handler.degradation_callback
    error_handler:setDegradationCallback(function(error_info, quality_level)
        table.insert(degradation_events, {
            trigger_category = error_info.category,
            quality_level = quality_level,
            timestamp = error_info.timestamp
        })
        
        -- Call original callback if it exists
        if original_callback then
            original_callback(error_info, quality_level)
        end
    end)
    
    -- Trigger errors that should cause degradation
    error_handler:handlePerformanceError("frame_drop_rate", 0.3, 0.1)
    error_handler:handleResourceError("memory", {}, 700 * 1024 * 1024)
    
    TestFramework.assert_true(#degradation_events > 0, "Degradation events should be triggered")
    TestFramework.assert_true(error_handler:isDegraded(), "System should be in degraded mode")
    
    -- Verify quality levels are decreasing
    for i, event in ipairs(degradation_events) do
        TestFramework.assert_true(event.quality_level < 1.0, "Quality level should be reduced")
        if i > 1 then
            TestFramework.assert_true(event.quality_level <= degradation_events[i-1].quality_level, 
                               "Quality should not increase during degradation")
        end
    end
    
    return true
end

-- Test error propagation through components
function TestErrorHandlerIntegration.testErrorPropagationThroughComponents()
    local capture_engine = EnhancedCaptureEngine:new()
    local error_handler = capture_engine:getErrorHandler()
    
    local error_chain = {}
    error_handler:setErrorCallback(function(error_info)
        table.insert(error_chain, {
            category = error_info.category,
            source = error_info.api_name or error_info.resource_type or error_info.source_type,
            timestamp = error_info.timestamp
        })
    end)
    
    -- Simulate error propagation: API failure -> Resource issue -> Performance problem
    
    -- 1. API failure in screen capture
    error_handler:handleAPIError("BitBlt", 0, {component = "screen_capture"})
    
    -- 2. This causes increased memory usage (retry buffers)
    error_handler:handleResourceError("memory", {reason = "retry_allocation"}, 200 * 1024 * 1024)
    
    -- 3. Memory pressure causes performance degradation
    error_handler:handlePerformanceError("frame_drop_rate", 0.2, 0.1)
    
    TestFramework.assert_true(#error_chain == 3, "All errors in chain should be captured")
    
    -- Verify error categories are different (showing propagation)
    local categories = {}
    for _, error in ipairs(error_chain) do
        categories[error.category] = true
    end
    
    TestFramework.assert_true(categories[ErrorHandler.ERROR_CATEGORIES.API], "API error should be in chain")
    TestFramework.assert_true(categories[ErrorHandler.ERROR_CATEGORIES.RESOURCE], "Resource error should be in chain")
    TestFramework.assert_true(categories[ErrorHandler.ERROR_CATEGORIES.PERFORMANCE], "Performance error should be in chain")
    
    return true
end

-- Test cascading error handling
function TestErrorHandlerIntegration.testCascadingErrorHandling()
    local capture_engine = EnhancedCaptureEngine:new({
        max_retry_attempts = 1,  -- Low retry count to trigger cascading faster
        enable_graceful_degradation = true
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local total_errors = 0
    local degradation_triggered = false
    
    error_handler:setErrorCallback(function(error_info)
        total_errors = total_errors + 1
    end)
    
    error_handler:setDegradationCallback(function(error_info, quality_level)
        degradation_triggered = true
    end)
    
    -- Simulate cascading failure scenario
    local cascade_errors = {
        {type = "api", api = "GetWindowDC", code = 5},
        {type = "api", api = "GetWindowDC", code = 5},  -- Retry fails
        {type = "resource", resource = "handle", usage = 100},
        {type = "performance", metric = "capture_time", value = 0.2, threshold = 0.1},
        {type = "performance", metric = "frame_drop_rate", value = 0.4, threshold = 0.1}
    }
    
    for _, error in ipairs(cascade_errors) do
        if error.type == "api" then
            error_handler:handleAPIError(error.api, error.code, {})
        elseif error.type == "resource" then
            error_handler:handleResourceError(error.resource, {}, error.usage)
        elseif error.type == "performance" then
            error_handler:handlePerformanceError(error.metric, error.value, error.threshold)
        end
    end
    
    TestFramework.assert_true(total_errors == #cascade_errors, "All cascading errors should be counted")
    TestFramework.assert_true(degradation_triggered, "Cascading errors should trigger degradation")
    TestFramework.assert_true(error_handler:isDegraded(), "System should be degraded after cascade")
    
    return true
end

-- Test error handler with real capture scenarios
function TestErrorHandlerIntegration.testErrorHandlerWithRealCapture()
    local capture_engine = EnhancedCaptureEngine:new({
        frame_rate = 30,
        enable_auto_recovery = true,
        monitor_performance = true
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local capture_errors = {}
    
    error_handler:setErrorCallback(function(error_info)
        if error_info.category == ErrorHandler.ERROR_CATEGORIES.CAPTURE then
            table.insert(capture_errors, error_info)
        end
    end)
    
    -- Simulate real capture scenarios with errors
    
    -- 1. Invalid source configuration
    error_handler:handleConfigurationError("source_type", "invalid_source", {
        valid_types = {"screen", "window", "webcam"}
    })
    
    -- 2. Device initialization failure
    error_handler:handleCaptureError("webcam", "Failed to initialize device", {
        device_index = 99,  -- Invalid device
        requested_resolution = "1920x1080"
    })
    
    -- 3. Window not found
    error_handler:handleCaptureError("window", "Target window not found", {
        window_title = "NonExistentWindow",
        search_attempts = 3
    })
    
    TestFramework.assert_true(#capture_errors == 2, "Capture-specific errors should be tracked")
    
    -- Verify error context is preserved
    for _, error in ipairs(capture_errors) do
        TestFramework.assert_true(error.context ~= nil, "Capture errors should have context")
        TestFramework.assert_true(error.source_type ~= nil, "Capture errors should have source type")
    end
    
    return true
end

-- Test system-wide error recovery
function TestErrorHandlerIntegration.testSystemWideErrorRecovery()
    local capture_engine = EnhancedCaptureEngine:new({
        enable_auto_recovery = true,
        max_retry_attempts = 2
    })
    
    local error_handler = capture_engine:getErrorHandler()
    local recovery_success_count = 0
    local recovery_failure_count = 0
    
    error_handler:setRecoveryCallback(function(action, error_info)
        -- Simulate varying recovery success rates
        local success_rate = 0.7  -- 70% success rate
        local success = math.random() < success_rate
        
        if success then
            recovery_success_count = recovery_success_count + 1
        else
            recovery_failure_count = recovery_failure_count + 1
        end
        
        return success
    end)
    
    -- Generate multiple system errors
    local system_errors = {
        {category = "api", api = "CreateCompatibleDC", code = 8},
        {category = "resource", type = "memory", usage = 800 * 1024 * 1024},
        {category = "capture", source = "screen", message = "Display driver error"},
        {category = "performance", metric = "fps", value = 5, threshold = 15}
    }
    
    for _, error in ipairs(system_errors) do
        if error.category == "api" then
            error_handler:handleAPIError(error.api, error.code, {})
        elseif error.category == "resource" then
            error_handler:handleResourceError(error.type, {}, error.usage)
        elseif error.category == "capture" then
            error_handler:handleCaptureError(error.source, error.message, {})
        elseif error.category == "performance" then
            error_handler:handlePerformanceError(error.metric, error.value, error.threshold)
        end
    end
    
    local stats = error_handler:getErrorStats()
    TestFramework.assert_true(stats.total_errors == #system_errors, "All system errors should be counted")
    TestFramework.assert_true(recovery_success_count + recovery_failure_count > 0, "Recovery should be attempted")
    TestFramework.assert_true(stats.recovered_errors == recovery_success_count, "Recovery stats should match")
    
    return true
end

-- Test error handler memory management
function TestErrorHandlerIntegration.testErrorHandlerMemoryManagement()
    local error_handler = ErrorHandler:new({
        log_errors = true
    })
    
    -- Generate many errors to test memory management
    local error_count = 150  -- More than the default history limit of 100
    
    for i = 1, error_count do
        error_handler:handleAPIError("TestAPI" .. (i % 10), i % 5, {iteration = i})
    end
    
    -- Verify error history is limited
    local recent_errors = error_handler:getRecentErrors(200)  -- Request more than limit
    TestFramework.assert_true(#recent_errors <= 100, "Error history should be limited to prevent memory issues")
    
    -- Verify most recent errors are kept
    local last_error = recent_errors[#recent_errors]
    TestFramework.assert_true(last_error.context.iteration >= error_count - 100, 
                        "Most recent errors should be preserved")
    
    -- Test error history clearing
    error_handler:clearErrorHistory()
    local cleared_errors = error_handler:getRecentErrors(10)
    TestFramework.assert_true(#cleared_errors == 0, "Error history should be cleared")
    
    local stats = error_handler:getErrorStats()
    TestFramework.assert_true(stats.total_errors == 0, "Error counts should be reset")
    
    return true
end

-- Test error handler thread safety (basic test)
function TestErrorHandlerIntegration.testErrorHandlerThreadSafety()
    local error_handler = ErrorHandler:new()
    
    -- Simulate concurrent error handling
    -- Note: This is a basic test since Lua doesn't have true threading
    -- In a real implementation, this would test with actual threads
    
    local concurrent_errors = {}
    local error_handler_calls = 0
    
    error_handler:setErrorCallback(function(error_info)
        error_handler_calls = error_handler_calls + 1
        table.insert(concurrent_errors, error_info)
    end)
    
    -- Simulate rapid error generation (as if from multiple threads)
    local start_time = love and love.timer.getTime() or os.clock()
    
    for i = 1, 20 do
        error_handler:handleAPIError("ConcurrentAPI", i % 3, {thread_id = i % 4})
        error_handler:handleResourceError("memory", {}, i * 1024 * 1024)
        error_handler:handlePerformanceError("fps", 30 - i, 30)
    end
    
    local end_time = love and love.timer.getTime() or os.clock()
    local processing_time = end_time - start_time
    
    TestFramework.assert_true(error_handler_calls == 60, "All concurrent errors should be processed")
    TestFramework.assert_true(#concurrent_errors == 60, "All errors should be logged")
    TestFramework.assert_true(processing_time < 0.1, "Concurrent error processing should be fast")
    
    -- Verify error handler state is consistent
    local stats = error_handler:getErrorStats()
    TestFramework.assert_true(stats.total_errors == 60, "Error count should be consistent")
    
    return true
end

return TestErrorHandlerIntegration