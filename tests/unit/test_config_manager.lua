-- Test suite for ConfigManager
-- Tests persistent storage, validation, and runtime updates

local TestFramework = require("tests.test_framework")
local ConfigManager = require("src.config_manager")

-- Use our custom JSON utilities
local json = require("src.json_utils")

-- Use our custom LFS utilities
local lfs = require("src.lfs_utils")

-- Replace global modules for testing
package.loaded["src.json_utils"] = json
package.loaded["src.lfs_utils"] = lfs

-- Mock io operations for testing
local mock_files = {}
local original_io_open = io.open

local function mock_io_open(filename, mode)
    if filename:match("config/settings%.json") then
        if mode == "r" then
            if mock_files[filename] then
                return {
                    read = function(self, format)
                        return mock_files[filename]
                    end,
                    close = function() end
                }
            else
                return nil -- File doesn't exist
            end
        elseif mode == "w" then
            return {
                write = function(self, content)
                    mock_files[filename] = content
                end,
                close = function() end
            }
        end
    end
    return original_io_open(filename, mode)
end

-- Replace global modules for testing
io.open = mock_io_open

local TestConfigManager = {}

function TestConfigManager.test_config_manager_creation()
    -- Test successful creation
    local config_manager = ConfigManager:new()
    TestFramework.assert_not_nil(config_manager, "ConfigManager should be created")
    TestFramework.assert_not_nil(config_manager.config, "Config should be initialized")
    
    -- Test default values are loaded
    TestFramework.assert_equal(config_manager:get("app.window_width"), 800, "Default window width should be 800")
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 30, "Default frame rate should be 30")
    TestFramework.assert_equal(config_manager:get("capture.webcam.resolution.width"), 640, "Default webcam width should be 640")
end

function TestConfigManager.test_config_get_set()
    local config_manager = ConfigManager:new()
    
    -- Test getting existing values
    local frame_rate = config_manager:get("capture.frame_rate")
    TestFramework.assert_equal(frame_rate, 30, "Should get default frame rate")
    
    -- Test setting valid values
    local success = pcall(function()
        config_manager:set("capture.frame_rate", 60)
    end)
    TestFramework.assert_true(success, "Should successfully set valid frame rate")
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 60, "Frame rate should be updated")
    
    -- Test setting invalid values
    local invalid_success = pcall(function()
        config_manager:set("capture.frame_rate", 200) -- Invalid: > 120
    end)
    TestFramework.assert_false(invalid_success, "Should reject invalid frame rate")
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 60, "Frame rate should remain unchanged")
    
    -- Test nested path setting
    success = pcall(function()
        config_manager:set("capture.webcam.resolution.width", 1280)
    end)
    TestFramework.assert_true(success, "Should set nested webcam resolution")
    TestFramework.assert_equal(config_manager:get("capture.webcam.resolution.width"), 1280, "Webcam width should be updated")
end

function TestConfigManager.test_config_validation()
    local config_manager = ConfigManager:new()
    
    -- Test valid configuration
    local validation_result = config_manager:validate()
    TestFramework.assert_true(validation_result.valid, "Default config should be valid")
    TestFramework.assert_equal(#validation_result.errors, 0, "Should have no validation errors")
    
    -- Test validation rules for webcam settings (Requirement 3.3)
    local webcam_tests = {
        {"capture.webcam.resolution.width", 1920, true},
        {"capture.webcam.resolution.width", 0, false},
        {"capture.webcam.resolution.width", 5000, false},
        {"capture.webcam.fps", 30, true},
        {"capture.webcam.fps", 0, false},
        {"capture.webcam.fps", 150, false}
    }
    
    for _, test_case in ipairs(webcam_tests) do
        local path, value, should_be_valid = test_case[1], test_case[2], test_case[3]
        
        -- Temporarily set the value for validation
        local old_value = config_manager:get(path)
        if path:match("width") then
            config_manager.config.capture.webcam.resolution.width = value
        else
            config_manager.config.capture.webcam.fps = value
        end
        
        local result = config_manager:validate()
        if should_be_valid then
            TestFramework.assert_true(result.valid, string.format("Value %s for %s should be valid", value, path))
        else
            TestFramework.assert_false(result.valid, string.format("Value %s for %s should be invalid", value, path))
        end
        
        -- Restore old value
        if path:match("width") then
            config_manager.config.capture.webcam.resolution.width = old_value
        else
            config_manager.config.capture.webcam.fps = old_value
        end
    end
    
    -- Test overlay validation (Requirement 7.3)
    local overlay_tests = {
        {"display.overlay.x", 100, true},
        {"display.overlay.x", -10, false},
        {"display.overlay.transparency", 0.5, true},
        {"display.overlay.transparency", 1.5, false}
    }
    
    for _, test_case in ipairs(overlay_tests) do
        local path, value, should_be_valid = test_case[1], test_case[2], test_case[3]
        
        local old_value = config_manager:get(path)
        if path:match("overlay%.x") then
            config_manager.config.display.overlay.x = value
        elseif path:match("transparency") then
            config_manager.config.display.overlay.transparency = value
        end
        
        local result = config_manager:validate()
        if should_be_valid then
            TestFramework.assert_true(result.valid, string.format("Overlay value %s for %s should be valid", value, path))
        else
            TestFramework.assert_false(result.valid, string.format("Overlay value %s for %s should be invalid", value, path))
        end
        
        -- Restore
        if path:match("overlay%.x") then
            config_manager.config.display.overlay.x = old_value
        elseif path:match("transparency") then
            config_manager.config.display.overlay.transparency = old_value
        end
    end
end

function TestConfigManager.test_config_persistence()
    -- Clear mock files
    mock_files = {}
    
    local config_manager = ConfigManager:new()
    
    -- Modify configuration
    config_manager:set("capture.frame_rate", 45)
    config_manager:set("capture.webcam.resolution.width", 1280)
    
    -- Test saving
    local save_success = pcall(function()
        config_manager:save()
    end)
    TestFramework.assert_true(save_success, "Should save configuration successfully")
    
    -- Verify file was written
    local config_file = "config/settings.json"
    TestFramework.assert_not_nil(mock_files[config_file], "Config file should be written")
    
    -- Test loading from saved file
    local new_config_manager = ConfigManager:new()
    TestFramework.assert_equal(new_config_manager:get("capture.frame_rate"), 45, "Should load saved frame rate")
    TestFramework.assert_equal(new_config_manager:get("capture.webcam.resolution.width"), 1280, "Should load saved webcam width")
end

function TestConfigManager.test_config_callbacks()
    local config_manager = ConfigManager:new()
    
    local callback_called = false
    local callback_path = nil
    local callback_new_value = nil
    local callback_old_value = nil
    
    -- Register callback
    config_manager:onConfigChange("capture.frame_rate", function(path, new_val, old_val)
        callback_called = true
        callback_path = path
        callback_new_value = new_val
        callback_old_value = old_val
    end)
    
    -- Change configuration
    config_manager:set("capture.frame_rate", 50)
    
    -- Verify callback was called
    TestFramework.assert_true(callback_called, "Callback should be called on config change")
    TestFramework.assert_equal(callback_path, "capture.frame_rate", "Callback should receive correct path")
    TestFramework.assert_equal(callback_new_value, 50, "Callback should receive new value")
    TestFramework.assert_equal(callback_old_value, 30, "Callback should receive old value")
end

function TestConfigManager.test_config_batch_updates()
    local config_manager = ConfigManager:new()
    
    -- Test valid batch update
    local updates = {
        ["capture.frame_rate"] = 25,
        ["capture.webcam.fps"] = 25,
        ["display.overlay.transparency"] = 0.7
    }
    
    local success = pcall(function()
        config_manager:updateBatch(updates)
    end)
    
    TestFramework.assert_true(success, "Batch update should succeed with valid values")
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 25, "Frame rate should be updated")
    TestFramework.assert_equal(config_manager:get("capture.webcam.fps"), 25, "Webcam FPS should be updated")
    TestFramework.assert_equal(config_manager:get("display.overlay.transparency"), 0.7, "Overlay transparency should be updated")
    
    -- Test invalid batch update (should revert all changes)
    local invalid_updates = {
        ["capture.frame_rate"] = 15, -- Valid
        ["capture.webcam.fps"] = 200 -- Invalid (> 120)
    }
    
    local invalid_success = pcall(function()
        config_manager:updateBatch(invalid_updates)
    end)
    
    TestFramework.assert_false(invalid_success, "Batch update should fail with invalid values")
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 25, "Frame rate should remain unchanged after failed batch")
    TestFramework.assert_equal(config_manager:get("capture.webcam.fps"), 25, "Webcam FPS should remain unchanged after failed batch")
end

function TestConfigManager.test_config_reset()
    local config_manager = ConfigManager:new()
    
    -- Modify some values
    config_manager:set("capture.frame_rate", 45)
    config_manager:set("app.window_width", 1200)
    
    -- Reset to defaults
    config_manager:resetToDefaults()
    
    -- Verify values are reset
    TestFramework.assert_equal(config_manager:get("capture.frame_rate"), 30, "Frame rate should be reset to default")
    TestFramework.assert_equal(config_manager:get("app.window_width"), 800, "Window width should be reset to default")
end

-- Run all tests
function TestConfigManager.run_all_tests()
    TestFramework.reset_stats()
    
    local tests = {
        test_config_manager_creation = TestConfigManager.test_config_manager_creation,
        test_config_get_set = TestConfigManager.test_config_get_set,
        test_config_validation = TestConfigManager.test_config_validation,
        test_config_persistence = TestConfigManager.test_config_persistence,
        test_config_callbacks = TestConfigManager.test_config_callbacks,
        test_config_batch_updates = TestConfigManager.test_config_batch_updates,
        test_config_reset = TestConfigManager.test_config_reset
    }
    
    TestFramework.run_suite("ConfigManager", tests)
    local stats = TestFramework.get_stats()
    
    return stats.failed == 0
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_config_manager%.lua$") then
    TestConfigManager.run_all_tests()
end

return TestConfigManager