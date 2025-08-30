-- Unified Test Framework
-- Provides common testing infrastructure for all test modules

local TestFramework = {}

-- Test statistics
local test_stats = {
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    current_suite = "",
    start_time = 0
}

-- Assertion functions
function TestFramework.assert_equal(expected, actual, message)
    if expected ~= actual then
        local error_msg = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
        error(error_msg)
    end
end

function TestFramework.assert_not_equal(expected, actual, message)
    if expected == actual then
        local error_msg = message or string.format("Expected not %s, got %s", tostring(expected), tostring(actual))
        error(error_msg)
    end
end

function TestFramework.assert_true(value, message)
    if not value then
        local error_msg = message or "Expected true, got false"
        error(error_msg)
    end
end

function TestFramework.assert_false(value, message)
    if value then
        local error_msg = message or "Expected false, got true"
        error(error_msg)
    end
end

function TestFramework.assert_not_nil(value, message)
    if value == nil then
        local error_msg = message or "Expected non-nil value"
        error(error_msg)
    end
end

function TestFramework.assert_nil(value, message)
    if value ~= nil then
        local error_msg = message or "Expected nil value"
        error(error_msg)
    end
end

function TestFramework.assert_type(value, expected_type, message)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        local error_msg = message or string.format("Expected type %s, got %s", expected_type, actual_type)
        error(error_msg)
    end
end

function TestFramework.assert_table_contains(table, key, message)
    if table[key] == nil then
        local error_msg = message or string.format("Table should contain key: %s", tostring(key))
        error(error_msg)
    end
end

function TestFramework.assert_string_contains(str, substring, message)
    if not string.find(str, substring, 1, true) then
        local error_msg = message or string.format("String should contain: %s", substring)
        error(error_msg)
    end
end

-- Simple assert function for general use
function TestFramework.assert(condition, message)
    if not condition then
        local error_msg = message or "Assertion failed"
        error(error_msg)
    end
end

-- Test runner functions
function TestFramework.run_test(name, test_func)
    test_stats.total_tests = test_stats.total_tests + 1
    print(string.format("Running test: %s", name))
    
    local success, error_msg = pcall(test_func)
    if success then
        test_stats.passed_tests = test_stats.passed_tests + 1
        print(string.format("  ✓ PASSED: %s", name))
    else
        test_stats.failed_tests = test_stats.failed_tests + 1
        print(string.format("  ✗ FAILED: %s", name))
        print(string.format("    Error: %s", error_msg))
    end
end

function TestFramework.run_suite(suite_name, tests)
    print(string.format("\n=== Running %s ===", suite_name))
    test_stats.current_suite = suite_name
    test_stats.start_time = os.clock()
    
    for test_name, test_func in pairs(tests) do
        TestFramework.run_test(test_name, test_func)
    end
    
    local end_time = os.clock()
    local duration = end_time - test_stats.start_time
    
    print(string.format("\n%s completed: %d/%d passed", 
        suite_name, test_stats.passed_tests, test_stats.total_tests))
    
    if test_stats.failed_tests > 0 then
        print(string.format("%d tests FAILED! ✗", test_stats.failed_tests))
    else
        print("All tests PASSED! ✓")
    end
    
    print(string.format("Duration: %.3f seconds", duration))
end

function TestFramework.get_stats()
    return {
        total = test_stats.total_tests,
        passed = test_stats.passed_tests,
        failed = test_stats.failed_tests,
        current_suite = test_stats.current_suite
    }
end

function TestFramework.reset_stats()
    test_stats.total_tests = 0
    test_stats.passed_tests = 0
    test_stats.failed_tests = 0
    test_stats.current_suite = ""
    test_stats.start_time = 0
end

-- Utility functions
function TestFramework.print_separator(char, length)
    char = char or "="
    length = length or 50
    print(string.rep(char, length))
end

function TestFramework.print_header(title)
    TestFramework.print_separator()
    print(title)
    TestFramework.print_separator()
end

-- Mock system integration
function TestFramework.setup_mock_environment()
    -- Set testing mode flag
    _G.TESTING_MODE = true
    
    -- Load mock bindings if available
    local success, mock_bindings = pcall(require, "tests.mock_ffi_bindings")
    if success then
        _G.MOCK_FFI_BINDINGS = mock_bindings
        print("Mock FFI bindings loaded for testing")
    else
        print("Warning: Mock FFI bindings not available")
    end
end

function TestFramework.cleanup_mock_environment()
    _G.TESTING_MODE = nil
    _G.MOCK_FFI_BINDINGS = nil
end

-- Performance testing helpers
function TestFramework.measure_time(func, iterations)
    iterations = iterations or 1
    local start_time = os.clock()
    
    for i = 1, iterations do
        func()
    end
    
    local end_time = os.clock()
    local total_time = end_time - start_time
    local avg_time = total_time / iterations
    
    return {
        total_time = total_time,
        avg_time = avg_time,
        iterations = iterations
    }
end

function TestFramework.benchmark(name, func, iterations)
    print(string.format("Benchmarking: %s (%d iterations)", name, iterations))
    local result = TestFramework.measure_time(func, iterations)
    print(string.format("  Total: %.6f seconds", result.total_time))
    print(string.format("  Average: %.6f seconds per iteration", result.avg_time))
    return result
end

-- Export all assertion functions to global scope for convenience
for name, func in pairs(TestFramework) do
    if string.find(name, "^assert_") then
        _G[name] = func
    end
end

return TestFramework
