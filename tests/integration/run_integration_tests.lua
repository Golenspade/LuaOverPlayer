#!/usr/bin/env lua

-- Integration Test Runner for Lua Video Capture Player
-- Runs all end-to-end integration tests for the main application

print("=== Lua Video Capture Player Integration Test Suite ===")
print("Testing complete application integration and workflows...")
print()

-- Set up test environment
_G.TESTING_MODE = true

-- Import test suites
local MainIntegrationTests = require("tests.test_main_integration")
local CompleteWorkflowTests = require("tests.test_complete_workflows")

-- Test execution tracking
local total_passed = 0
local total_failed = 0
local test_suites = {}

-- Helper function to run a test suite
local function runTestSuite(name, test_suite)
    print("Running " .. name .. "...")
    print(string.rep("=", 50))
    
    local start_time = os.clock()
    local success, result = pcall(test_suite.runAllTests)
    local end_time = os.clock()
    
    if success then
        if result then
            print("✅ " .. name .. " - ALL TESTS PASSED")
            total_passed = total_passed + 1
        else
            print("❌ " .. name .. " - SOME TESTS FAILED")
            total_failed = total_failed + 1
        end
    else
        print("💥 " .. name .. " - TEST SUITE CRASHED: " .. tostring(result))
        total_failed = total_failed + 1
    end
    
    print("Duration: " .. string.format("%.2f", end_time - start_time) .. " seconds")
    print()
    
    table.insert(test_suites, {
        name = name,
        success = success and result,
        duration = end_time - start_time,
        error = success and "" or tostring(result)
    })
end

-- Run all test suites
print("Starting integration tests...")
print()

-- Test Suite 1: Main Application Integration
runTestSuite("Main Application Integration Tests", MainIntegrationTests)

-- Test Suite 2: Complete Workflow Tests
runTestSuite("Complete Workflow Tests", CompleteWorkflowTests)

-- Print final results
print(string.rep("=", 60))
print("FINAL INTEGRATION TEST RESULTS")
print(string.rep("=", 60))

local total_duration = 0
for _, suite in ipairs(test_suites) do
    local status = suite.success and "✅ PASS" or "❌ FAIL"
    print(string.format("%-40s %s (%.2fs)", suite.name, status, suite.duration))
    if not suite.success and suite.error ~= "" then
        print("  Error: " .. suite.error)
    end
    total_duration = total_duration + suite.duration
end

print()
print("Summary:")
print("  Test Suites Passed: " .. total_passed)
print("  Test Suites Failed: " .. total_failed)
print("  Total Test Suites:  " .. (total_passed + total_failed))
print("  Total Duration:     " .. string.format("%.2f", total_duration) .. " seconds")
print()

if total_failed == 0 then
    print("🎉 ALL INTEGRATION TESTS PASSED! 🎉")
    print("The Lua Video Capture Player main application integration is working correctly.")
    os.exit(0)
else
    print("❌ SOME INTEGRATION TESTS FAILED")
    print("Please review the failed tests and fix any issues before proceeding.")
    os.exit(1)
end