#!/usr/bin/env lua

-- Memory Optimization Stress Test Runner
-- Runs comprehensive stress tests for memory optimization features

-- Add src directory to package path
package.path = package.path .. ";src/?.lua;tests/?.lua"

local MemoryOptimizationStressTests = require("tests.test_memory_optimization_stress")

-- Configuration
local TEST_CONFIG = {
    run_individual_tests = true,
    run_full_suite = true,
    verbose_output = true,
    save_results = true
}

-- Helper function to format time duration
local function formatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    if minutes > 0 then
        return string.format("%dm %.1fs", minutes, secs)
    else
        return string.format("%.1fs", secs)
    end
end

-- Helper function to format memory size
local function formatMemory(mb)
    if mb >= 1024 then
        return string.format("%.2f GB", mb / 1024)
    else
        return string.format("%.2f MB", mb)
    end
end

-- Print system information
local function printSystemInfo()
    print("=== System Information ===")
    print("Lua version: " .. _VERSION)
    print("Platform: " .. (jit and jit.version or "Standard Lua"))
    
    -- Get initial memory usage
    collectgarbage("collect")
    local initial_memory = collectgarbage("count") / 1024
    print(string.format("Initial memory usage: %s", formatMemory(initial_memory)))
    
    -- Get garbage collector settings
    local gc_mode = collectgarbage("count") and "incremental" or "generational"
    print("Garbage collector mode: " .. gc_mode)
    print("")
end

-- Run individual test with timing and memory tracking
local function runIndividualTest(test_name, test_function)
    print(string.format("--- Running %s ---", test_name))
    
    local start_time = os.clock()
    local start_memory = collectgarbage("count") / 1024
    
    local success, result = pcall(test_function)
    
    local end_time = os.clock()
    local end_memory = collectgarbage("count") / 1024
    
    local duration = end_time - start_time
    local memory_delta = end_memory - start_memory
    
    if success and result and result.success then
        print(string.format("✓ PASSED in %s (memory delta: %+.2f MB)", 
              formatDuration(duration), memory_delta))
        if result.assertions_passed then
            print(string.format("  Assertions passed: %d", result.assertions_passed))
        end
    else
        print(string.format("✗ FAILED in %s (memory delta: %+.2f MB)", 
              formatDuration(duration), memory_delta))
        if result and result.error then
            print("  Error: " .. result.error)
        elseif not success then
            print("  Error: " .. tostring(result))
        end
    end
    
    print("")
    return success and result and result.success
end

-- Main execution
local function main()
    print("Memory Optimization Stress Test Runner")
    print("=====================================")
    print("")
    
    printSystemInfo()
    
    local total_start_time = os.clock()
    local total_start_memory = collectgarbage("count") / 1024
    
    local results = {
        individual_tests = {},
        full_suite = nil
    }
    
    -- Run individual tests if requested
    if TEST_CONFIG.run_individual_tests then
        print("=== Individual Test Results ===")
        
        local individual_tests = {
            {"Extended Capture Session", MemoryOptimizationStressTests.testExtendedCaptureSession},
            {"High Frequency Stress", MemoryOptimizationStressTests.testHighFrequencyStress},
            {"Memory Leak Detection", MemoryOptimizationStressTests.testMemoryLeakDetection},
            {"Memory Pool Efficiency", MemoryOptimizationStressTests.testMemoryPoolEfficiency},
            {"Resource Manager Sustained Load", MemoryOptimizationStressTests.testResourceManagerSustainedLoad}
        }
        
        for _, test_info in ipairs(individual_tests) do
            local test_name, test_function = test_info[1], test_info[2]
            local success = runIndividualTest(test_name, test_function)
            table.insert(results.individual_tests, {
                name = test_name,
                success = success
            })
            
            -- Force garbage collection between tests
            collectgarbage("collect")
        end
    end
    
    -- Run full test suite if requested
    if TEST_CONFIG.run_full_suite then
        print("=== Full Test Suite ===")
        
        local suite_start_time = os.clock()
        local suite_start_memory = collectgarbage("count") / 1024
        
        local success, suite_results = pcall(MemoryOptimizationStressTests.runAllTests)
        
        local suite_end_time = os.clock()
        local suite_end_memory = collectgarbage("count") / 1024
        
        local suite_duration = suite_end_time - suite_start_time
        local suite_memory_delta = suite_end_memory - suite_start_memory
        
        if success and suite_results then
            print(string.format("Full suite completed in %s (memory delta: %+.2f MB)", 
                  formatDuration(suite_duration), suite_memory_delta))
            print(string.format("Results: %d passed, %d failed out of %d total", 
                  suite_results.passed, suite_results.failed, suite_results.total))
            
            results.full_suite = suite_results
        else
            print(string.format("Full suite FAILED in %s", formatDuration(suite_duration)))
            if not success then
                print("Error: " .. tostring(suite_results))
            end
            
            results.full_suite = {
                success = false,
                error = success and "Unknown error" or tostring(suite_results)
            }
        end
        
        print("")
    end
    
    -- Final summary
    local total_end_time = os.clock()
    local total_end_memory = collectgarbage("count") / 1024
    
    local total_duration = total_end_time - total_start_time
    local total_memory_delta = total_end_memory - total_start_memory
    
    print("=== Final Summary ===")
    print(string.format("Total execution time: %s", formatDuration(total_duration)))
    print(string.format("Total memory delta: %+.2f MB", total_memory_delta))
    
    -- Count individual test results
    if #results.individual_tests > 0 then
        local individual_passed = 0
        for _, result in ipairs(results.individual_tests) do
            if result.success then
                individual_passed = individual_passed + 1
            end
        end
        print(string.format("Individual tests: %d/%d passed", individual_passed, #results.individual_tests))
    end
    
    -- Show full suite results
    if results.full_suite then
        if results.full_suite.passed and results.full_suite.total then
            print(string.format("Full suite: %d/%d passed", results.full_suite.passed, results.full_suite.total))
        else
            print("Full suite: FAILED")
        end
    end
    
    -- Memory usage recommendations
    print("")
    print("=== Memory Usage Analysis ===")
    if total_memory_delta > 50 then
        print("⚠️  High memory delta detected - check for potential leaks")
    elseif total_memory_delta > 20 then
        print("⚠️  Moderate memory delta - monitor memory usage")
    else
        print("✓ Memory delta within acceptable range")
    end
    
    local final_memory = collectgarbage("count") / 1024
    print(string.format("Final memory usage: %s", formatMemory(final_memory)))
    
    -- Force final cleanup
    collectgarbage("collect")
    local cleaned_memory = collectgarbage("count") / 1024
    local gc_freed = final_memory - cleaned_memory
    
    if gc_freed > 1 then
        print(string.format("Garbage collection freed: %s", formatMemory(gc_freed)))
    end
    
    print("")
    print("Memory optimization stress tests completed.")
    
    -- Return overall success status
    local overall_success = true
    
    if #results.individual_tests > 0 then
        for _, result in ipairs(results.individual_tests) do
            if not result.success then
                overall_success = false
                break
            end
        end
    end
    
    if results.full_suite and results.full_suite.failed and results.full_suite.failed > 0 then
        overall_success = false
    end
    
    return overall_success
end

-- Execute main function
local success = main()
os.exit(success and 0 or 1)