#!/usr/bin/env lua

-- Simple test runner for advanced capture features
-- This can be run independently to test the advanced features

-- Add src and tests directories to package path
package.path = package.path .. ";./src/?.lua;./tests/?.lua"

-- Set testing mode
_G.TESTING_MODE = true

print("Advanced Capture Features Test Runner")
print("====================================")

-- Test the advanced capture features module
local success, result = pcall(function()
    local TestAdvancedCaptureFeatures = require("test_advanced_capture_features")
    return TestAdvancedCaptureFeatures.run_all_tests()
end)

if success and result then
    print("\n✅ Advanced Capture Features tests completed successfully!")
else
    print("\n❌ Advanced Capture Features tests failed!")
    if not success then
        print("Error: " .. tostring(result))
    end
end

-- Test the integration tests
local success2, result2 = pcall(function()
    local TestAdvancedFeaturesIntegration = require("test_advanced_features_integration")
    return TestAdvancedFeaturesIntegration.run_all_tests()
end)

if success2 and result2 then
    print("\n✅ Advanced Features Integration tests completed successfully!")
else
    print("\n❌ Advanced Features Integration tests failed!")
    if not success2 then
        print("Error: " .. tostring(result2))
    end
end

-- Overall result
if success and result and success2 and result2 then
    print("\n🎉 All advanced features tests passed!")
    os.exit(0)
else
    print("\n💥 Some tests failed!")
    os.exit(1)
end