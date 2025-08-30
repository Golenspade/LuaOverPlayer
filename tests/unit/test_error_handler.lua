-- Test Error Handler
-- Comprehensive tests for error handling, recovery, and degradation

local TestFramework = require("tests.test_framework")
local ErrorHandler = require("src.error_handler")

local TestErrorHandler = {}

-- Test error handler creation and initialization
function TestErrorHandler.testErrorHandlerCreation()
    -- Test default creation
    local handler = ErrorHandler:new()
    TestFramework.assert_not_nil(handler, "Error handler should be created")
    TestFramework.assert_equal(3, handler.max_retry_attempts, "Default retry attempts should be 3")
    TestFramework.assert_true(handler.enable_auto_recovery, "Auto recovery should be enabled by default")
    
    -- Test custom options
    local custom_handler = ErrorHandler:new({
        max_retry_attempts = 5,
        retry_delay = 2.0,
        enable_auto_recovery = false,
        max_frame_drop_rate = 0.2
    })
    
    TestFramework.assert_true(custom_handler.max_retry_attempts == 5, "Custom retry attempts should be set")
    TestFramework.assert_true(custom_handler.retry_delay == 2.0, "Custom retry delay should be set")
    TestFramework.assert_true(custom_handler.enable_auto_recovery == false, "Auto recovery should be disabled")
    TestFramework.assert_true(custom_handler.performance_thresholds.max_frame_drop_rate == 0.2, "Custom threshold should be set")
    
    return true
end

-- Test API error handling
function TestErrorHandler.testAPIErrorHandling()
    local handler = ErrorHandler:new()
    local errors_logged = {}
    
    -- Set error callback to verify logging
    handler:setErrorCallback(function(error_info)
        table.insert(errors_logged, error_info)
    end)
    
    -- Test API error handling
    local recovered, error_info = handler:handleAPIError("BitBlt", 0, {operation = "screen_capture"})
    
    TestFramework.assert_true(#errors_logged > 0, "Error should be logged")
    TestFramework.assert_true(error_info ~= nil, "Error info should be returned")
    TestFramework.assert_true(error_info.category == ErrorHandler.ERROR_CATEGORIES.API, "Error category should be API")
    TestFramework.assert_true(error_info.api_name == "BitBlt", "API name should be recorded")
    TestFramework.assert_true(error_info.error_code == 0, "Error code should be recorded")
    TestFramework.assert_true(handler.stats.total_errors == 1, "Total error count should be incremented")
    
    -- Test critical API error
    local recovered2, error_info2 = handler:handleAPIError("CreateCompatibleDC", 8, {})
    TestFramework.assert_true(error_info2.severity >= ErrorHandler.ERROR_SEVERITY.HIGH, "Critical API error should have high severity")
    TestFramework.assert_true(handler.stats.total_errors == 2, "Total error count should be 2")
    
    return true
end

-- Test resource error handling
function TestErrorHandler.testResourceErrorHandling()
    local handler = ErrorHandler:new()
    local degradation_triggered = false
    
    handler:setDegradationCallback(function(error_info, quality_level)
        degradation_triggered = true
    end)
    
    -- Test memory resource error
    local recovered, error_info = handler:handleResourceError("memory", {
        requested = 1024 * 1024 * 1024,  -- 1GB
        available = 512 * 1024 * 1024    -- 512MB
    }, 600 * 1024 * 1024)  -- Current usage: 600MB
    
    TestFramework.assert_true(error_info.category == ErrorHandler.ERROR_CATEGORIES.RESOURCE, "Error category should be RESOURCE")
    TestFramework.assert_true(error_info.resource_type == "memory", "Resource type should be memory")
    TestFramework.assert_true(error_info.severity >= ErrorHandler.ERROR_SEVERITY.HIGH, "Memory error should have high severity")
    
    -- Test device resource error
    local recovered2, error_info2 = handler:handleResourceError("device", {
        device_name = "webcam",
        error = "device_not_found"
    })
    
    TestFramework.assert_true(error_info2.resource_type == "device", "Resource type should be device")
    TestFramework.assert_true(handler.stats.total_errors == 2, "Total error count should be 2")
    
    return true
end

-- Test performance error handling
function TestErrorHandler.testPerformanceErrorHandling()
    local handler = ErrorHandler:new()
    local degradation_triggered = false
    
    handler:setDegradationCallback(function(error_info, quality_level)
        degradation_triggered = true
        TestFramework.assert_true(quality_level < 1.0, "Quality level should be reduced")
    end)
    
    -- Test frame drop rate error
    local recovered, error_info = handler:handlePerformanceError("frame_drop_rate", 0.25, 0.1)
    
    TestFramework.assert_true(error_info.category == ErrorHandler.ERROR_CATEGORIES.PERFORMANCE, "Error category should be PERFORMANCE")
    TestFramework.assert_true(error_info.metric == "frame_drop_rate", "Metric should be recorded")
    TestFramework.assert_true(error_info.current_value == 0.25, "Current value should be recorded")
    TestFramework.assert_true(error_info.threshold == 0.1, "Threshold should be recorded")
    TestFramework.assert_true(degradation_triggered, "Degradation should be triggered for performance issues")
    
    -- Test capture time error
    local recovered2, error_info2 = handler:handlePerformanceError("capture_time", 0.5, 0.1)
    TestFramework.assert_true(error_info2.severity >= ErrorHandler.ERROR_SEVERITY.HIGH, "Slow capture should have high severity")
    
    return true
end

-- Test configuration error handling
function TestErrorHandler.testConfigurationErrorHandling()
    local handler = ErrorHandler:new()
    
    -- Test invalid configuration
    local recovered, error_info = handler:handleConfigurationError("frame_rate", 150, {min = 1, max = 120})
    
    TestFramework.assert_true(error_info.category == ErrorHandler.ERROR_CATEGORIES.CONFIGURATION, "Error category should be CONFIGURATION")
    TestFramework.assert_true(error_info.config_type == "frame_rate", "Config type should be recorded")
    TestFramework.assert_true(error_info.invalid_value == 150, "Invalid value should be recorded")
    TestFramework.assert_true(error_info.valid_range ~= nil, "Valid range should be recorded")
    
    return true
end

-- Test capture error handling
function TestErrorHandler.testCaptureErrorHandling()
    local handler = ErrorHandler:new()
    
    -- Test capture initialization error
    local recovered, error_info = handler:handleCaptureError("webcam", "Failed to initialize device", {
        device_index = 0,
        attempted_resolution = "1920x1080"
    })
    
    TestFramework.assert_true(error_info.category == ErrorHandler.ERROR_CATEGORIES.CAPTURE, "Error category should be CAPTURE")
    TestFramework.assert_true(error_info.source_type == "webcam", "Source type should be recorded")
    TestFramework.assert_true(error_info.error_message == "Failed to initialize device", "Error message should be recorded")
    TestFramework.assert_true(error_info.context ~= nil, "Context should be recorded")
    
    return true
end

-- Test error severity determination
function TestErrorHandler.testErrorSeverityDetermination()
    local handler = ErrorHandler:new()
    
    -- Test API severity determination
    local severity1 = handler:_determineAPISeverity("BitBlt", 0)
    TestFramework.assert_true(severity1 >= ErrorHandler.ERROR_SEVERITY.MEDIUM, "BitBlt failure should have medium+ severity")
    
    local severity2 = handler:_determineAPISeverity("GetWindowText", 5)  -- Access denied
    TestFramework.assert_true(severity2 >= ErrorHandler.ERROR_SEVERITY.HIGH, "Access denied should have high severity")
    
    local severity3 = handler:_determineAPISeverity("CreateCompatibleBitmap", 8)  -- Out of memory
    TestFramework.assert_true(severity3 == ErrorHandler.ERROR_SEVERITY.CRITICAL, "Out of memory should be critical")
    
    -- Test resource severity determination
    local severity4 = handler:_determineResourceSeverity("memory", 600 * 1024 * 1024)
    TestFramework.assert_true(severity4 >= ErrorHandler.ERROR_SEVERITY.HIGH, "High memory usage should have high severity")
    
    -- Test performance severity determination
    local severity5 = handler:_determinePerformanceSeverity("frame_drop_rate", 0.3, 0.1)
    TestFramework.assert_true(severity5 >= ErrorHandler.ERROR_SEVERITY.HIGH, "High frame drop rate should have high severity")
    
    return true
end

-- Test recovery strategies
function TestErrorHandler.testRecoveryStrategies()
    local handler = ErrorHandler:new()
    
    -- Test API error strategy
    local api_error = {
        category = ErrorHandler.ERROR_CATEGORIES.API,
        severity = ErrorHandler.ERROR_SEVERITY.MEDIUM
    }
    local strategy1 = handler:_getRecoveryStrategy(api_error)
    TestFramework.assert_true(strategy1 == ErrorHandler.RECOVERY_STRATEGIES.RETRY, "Medium API error should use retry strategy")
    
    -- Test high severity API error strategy
    api_error.severity = ErrorHandler.ERROR_SEVERITY.HIGH
    local strategy2 = handler:_getRecoveryStrategy(api_error)
    TestFramework.assert_true(strategy2 == ErrorHandler.RECOVERY_STRATEGIES.FALLBACK, "High API error should use fallback strategy")
    
    -- Test resource error strategy
    local resource_error = {
        category = ErrorHandler.ERROR_CATEGORIES.RESOURCE,
        resource_type = "memory"
    }
    local strategy3 = handler:_getRecoveryStrategy(resource_error)
    TestFramework.assert_true(strategy3 == ErrorHandler.RECOVERY_STRATEGIES.DEGRADE, "Memory error should use degrade strategy")
    
    -- Test performance error strategy
    local performance_error = {
        category = ErrorHandler.ERROR_CATEGORIES.PERFORMANCE
    }
    local strategy4 = handler:_getRecoveryStrategy(performance_error)
    TestFramework.assert_true(strategy4 == ErrorHandler.RECOVERY_STRATEGIES.DEGRADE, "Performance error should use degrade strategy")
    
    return true
end

-- Test automatic recovery mechanism
function TestErrorHandler.testAutomaticRecovery()
    local handler = ErrorHandler:new({enable_auto_recovery = true})
    local recovery_attempted = false
    
    handler:setRecoveryCallback(function(action, error_info)
        recovery_attempted = true
        return true  -- Simulate successful recovery
    end)
    
    -- Test recovery attempt
    local recovered, error_info = handler:handleCaptureError("screen", "Temporary failure", {})
    
    TestFramework.assert_true(handler.stats.total_errors == 1, "Error should be counted")
    
    -- Test retry limit
    for i = 1, 5 do
        handler:handleAPIError("TestAPI", 0, {})
    end
    
    -- Should stop retrying after max attempts
    local error_key = "api_error_TestAPI"
    TestFramework.assert_true(handler.recovery_attempts[error_key] <= handler.max_retry_attempts, 
                        "Should not exceed max retry attempts")
    
    return true
end

-- Test graceful degradation
function TestErrorHandler.testGracefulDegradation()
    local handler = ErrorHandler:new({enable_graceful_degradation = true})
    local degradation_events = 0
    local final_quality_level = 1.0
    
    handler:setDegradationCallback(function(error_info, quality_level)
        degradation_events = degradation_events + 1
        final_quality_level = quality_level
    end)
    
    -- Trigger performance error that should cause degradation
    handler:handlePerformanceError("frame_drop_rate", 0.3, 0.1)
    
    TestFramework.assert_true(handler:isDegraded(), "System should be in degraded mode")
    TestFramework.assert_true(handler:getQualityLevel() < 1.0, "Quality level should be reduced")
    TestFramework.assert_true(degradation_events > 0, "Degradation callback should be called")
    TestFramework.assert_true(final_quality_level < 1.0, "Final quality level should be reduced")
    
    -- Test further degradation
    local initial_quality = handler:getQualityLevel()
    handler:handleResourceError("memory", {}, 700 * 1024 * 1024)
    
    TestFramework.assert_true(handler:getQualityLevel() < initial_quality, "Quality should degrade further")
    
    -- Test reset
    handler:resetDegradedMode()
    TestFramework.assert_true(not handler:isDegraded(), "Degraded mode should be reset")
    TestFramework.assert_true(handler:getQualityLevel() == 1.0, "Quality level should be reset")
    
    return true
end

-- Test error logging
function TestErrorHandler.testErrorLogging()
    local handler = ErrorHandler:new({log_errors = true})
    
    -- Generate some errors
    handler:handleAPIError("TestAPI1", 1, {})
    handler:handleResourceError("memory", {}, 100)
    handler:handlePerformanceError("fps", 10, 30)
    
    -- Test error history
    local recent_errors = handler:getRecentErrors(5)
    TestFramework.assert_true(#recent_errors == 3, "Should have 3 recent errors")
    
    -- Test error counts
    local stats = handler:getErrorStats()
    TestFramework.assert_true(stats.error_counts[ErrorHandler.ERROR_CATEGORIES.API] == 1, "Should have 1 API error")
    TestFramework.assert_true(stats.error_counts[ErrorHandler.ERROR_CATEGORIES.RESOURCE] == 1, "Should have 1 resource error")
    TestFramework.assert_true(stats.error_counts[ErrorHandler.ERROR_CATEGORIES.PERFORMANCE] == 1, "Should have 1 performance error")
    
    -- Test last error retrieval
    local last_api_error = handler:getLastError(ErrorHandler.ERROR_CATEGORIES.API)
    TestFramework.assert_true(last_api_error ~= nil, "Should have last API error")
    TestFramework.assert_true(last_api_error.api_name == "TestAPI1", "Last API error should be TestAPI1")
    
    return true
end

-- Test error statistics
function TestErrorHandler.testErrorStatistics()
    local handler = ErrorHandler:new()
    
    -- Initial stats should be zero
    local initial_stats = handler:getErrorStats()
    TestFramework.assert_true(initial_stats.total_errors == 0, "Initial total errors should be 0")
    TestFramework.assert_true(initial_stats.recovered_errors == 0, "Initial recovered errors should be 0")
    TestFramework.assert_true(initial_stats.unrecovered_errors == 0, "Initial unrecovered errors should be 0")
    
    -- Generate some errors
    handler:handleAPIError("TestAPI", 0, {})
    handler:handleResourceError("memory", {}, 100)
    
    local stats = handler:getErrorStats()
    TestFramework.assert_true(stats.total_errors == 2, "Should have 2 total errors")
    TestFramework.assert_true(stats.total_errors == stats.recovered_errors + stats.unrecovered_errors, 
                        "Total should equal recovered + unrecovered")
    
    -- Test stats clearing
    handler:clearErrorHistory()
    local cleared_stats = handler:getErrorStats()
    TestFramework.assert_true(cleared_stats.total_errors == 0, "Stats should be cleared")
    
    return true
end

-- Test error callbacks
function TestErrorHandler.testErrorCallbacks()
    local handler = ErrorHandler:new()
    local error_callback_called = false
    local recovery_callback_called = false
    local degradation_callback_called = false
    
    handler:setErrorCallback(function(error_info)
        error_callback_called = true
        TestFramework.assert_true(error_info ~= nil, "Error info should be provided to callback")
    end)
    
    handler:setRecoveryCallback(function(action, error_info)
        recovery_callback_called = true
        TestFramework.assert_true(action ~= nil, "Recovery action should be provided")
        return true
    end)
    
    handler:setDegradationCallback(function(error_info, quality_level)
        degradation_callback_called = true
        TestFramework.assert_true(quality_level ~= nil, "Quality level should be provided")
    end)
    
    -- Trigger error that should call all callbacks
    handler:handlePerformanceError("frame_drop_rate", 0.5, 0.1)
    
    TestFramework.assert_true(error_callback_called, "Error callback should be called")
    TestFramework.assert_true(degradation_callback_called, "Degradation callback should be called")
    
    return true
end

-- Test retry mechanism
function TestErrorHandler.testRetryMechanism()
    local handler = ErrorHandler:new({max_retry_attempts = 2})
    
    -- Test retry counting
    handler:handleAPIError("RetryTest", 0, {})
    handler:handleAPIError("RetryTest", 0, {})
    handler:handleAPIError("RetryTest", 0, {})  -- Should exceed max retries
    
    local error_key = "api_error_RetryTest"
    TestFramework.assert_true(handler.recovery_attempts[error_key] <= handler.max_retry_attempts, 
                        "Should not exceed max retry attempts")
    
    return true
end

-- Test degraded mode management
function TestErrorHandler.testDegradedModeManagement()
    local handler = ErrorHandler:new({enable_graceful_degradation = true})
    
    -- Initially not degraded
    TestFramework.assert_true(not handler:isDegraded(), "Should not be degraded initially")
    TestFramework.assert_true(handler:getQualityLevel() == 1.0, "Quality should be 1.0 initially")
    
    -- Trigger degradation
    handler:_initiateGracefulDegradation({category = "test"})
    
    TestFramework.assert_true(handler:isDegraded(), "Should be degraded after initiation")
    TestFramework.assert_true(handler:getQualityLevel() < 1.0, "Quality should be reduced")
    
    -- Further degradation
    local initial_quality = handler:getQualityLevel()
    handler:_initiateGracefulDegradation({category = "test"})
    
    TestFramework.assert_true(handler:getQualityLevel() < initial_quality, "Quality should degrade further")
    
    -- Reset
    handler:resetDegradedMode()
    TestFramework.assert_true(not handler:isDegraded(), "Should not be degraded after reset")
    TestFramework.assert_true(handler:getQualityLevel() == 1.0, "Quality should be reset to 1.0")
    
    return true
end

-- Test suite definition
local error_handler_tests = {
    testErrorHandlerCreation = TestErrorHandler.testErrorHandlerCreation,
    testAPIErrorHandling = TestErrorHandler.testAPIErrorHandling,
    testResourceErrorHandling = TestErrorHandler.testResourceErrorHandling,
    testPerformanceErrorHandling = TestErrorHandler.testPerformanceErrorHandling,
    testConfigurationErrorHandling = TestErrorHandler.testConfigurationErrorHandling,
    testCaptureErrorHandling = TestErrorHandler.testCaptureErrorHandling,
    testErrorSeverityDetermination = TestErrorHandler.testErrorSeverityDetermination,
    testRecoveryStrategies = TestErrorHandler.testRecoveryStrategies,
    testAutomaticRecovery = TestErrorHandler.testAutomaticRecovery,
    testGracefulDegradation = TestErrorHandler.testGracefulDegradation,
    testErrorLogging = TestErrorHandler.testErrorLogging,
    testErrorStatistics = TestErrorHandler.testErrorStatistics,
    testErrorCallbacks = TestErrorHandler.testErrorCallbacks,
    testRetryMechanism = TestErrorHandler.testRetryMechanism,
    testDegradedModeManagement = TestErrorHandler.testDegradedModeManagement
}

-- Run tests function
local function runErrorHandlerTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("ErrorHandler Tests", error_handler_tests)
    local stats = TestFramework.get_stats()
    TestFramework.cleanup_mock_environment()
    return stats
end

function TestErrorHandler.runAllTests()
    return runErrorHandlerTests()
end

return TestErrorHandler