-- Integration tests for ConfigManager with other system components
-- Tests runtime configuration updates and component integration

local TestFramework = require("tests.test_framework")
local ConfigManager = require("src.config_manager")

-- Mock components for integration testing
local MockCaptureEngine = {}
MockCaptureEngine.__index = MockCaptureEngine

function MockCaptureEngine:new()
    return setmetatable({
        frame_rate = 30,
        source_config = {},
        callbacks_received = {}
    }, self)
end

function MockCaptureEngine:setFrameRate(fps)
    self.frame_rate = fps
    table.insert(self.callbacks_received, {"setFrameRate", fps})
end

function MockCaptureEngine:configureWebcam(config)
    self.source_config.webcam = config
    table.insert(self.callbacks_received, {"configureWebcam", config})
end

function MockCaptureEngine:configureScreen(config)
    self.source_config.screen = config
    table.insert(self.callbacks_received, {"configureScreen", config})
end

local MockVideoRenderer = {}
MockVideoRenderer.__index = MockVideoRenderer

function MockVideoRenderer:new()
    return setmetatable({
        scaling_mode = "fit",
        overlay_config = {},
        callbacks_received = {}
    }, self)
end

function MockVideoRenderer:setScalingMode(mode)
    self.scaling_mode = mode
    table.insert(self.callbacks_received, {"setScalingMode", mode})
end

function MockVideoRenderer:configureOverlay(config)
    self.overlay_config = config
    table.insert(self.callbacks_received, {"configureOverlay", config})
end

function MockVideoRenderer:setTransparency(alpha)
    self.overlay_config.transparency = alpha
    table.insert(self.callbacks_received, {"setTransparency", alpha})
end

-- Use our custom utilities for testing
local json = require("src.json_utils")
local lfs = require("src.lfs_utils")

package.loaded["src.json_utils"] = json
package.loaded["src.lfs_utils"] = lfs

-- Mock io operations
local mock_files = {}
io.open = function(filename, mode)
    if filename:match("config/settings%.json") then
        if mode == "r" then
            return mock_files[filename] and {
                read = function() return mock_files[filename] end,
                close = function() end
            } or nil
        elseif mode == "w" then
            return {
                write = function(self, content) mock_files[filename] = content end,
                close = function() end
            }
        end
    end
    return nil
end

local TestConfigManagerIntegration = {}

function TestConfigManagerIntegration.test_capture_engine_integration()
    local config_manager = ConfigManager:new()
    local capture_engine = MockCaptureEngine:new()
    
    -- Register callbacks for capture-related config changes
    config_manager:onConfigChange("capture.frame_rate", function(path, new_val, old_val)
        capture_engine:setFrameRate(new_val)
    end)
    
    config_manager:onConfigChange("capture.webcam", function(path, new_val, old_val)
        if path:match("capture%.webcam") then
            local webcam_config = config_manager:get("capture.webcam")
            capture_engine:configureWebcam(webcam_config)
        end
    end)
    
    config_manager:onConfigChange("capture.screen", function(path, new_val, old_val)
        if path:match("capture%.screen") then
            local screen_config = config_manager:get("capture.screen")
            capture_engine:configureScreen(screen_config)
        end
    end)
    
    -- Test frame rate change propagation
    config_manager:set("capture.frame_rate", 60)
    TestFramework.assert_equal(capture_engine.frame_rate, 60, "Capture engine should receive frame rate update")
    TestFramework.assert_equal(#capture_engine.callbacks_received, 1, "Should receive one callback")
    TestFramework.assert_equal(capture_engine.callbacks_received[1][1], "setFrameRate", "Should call setFrameRate")
    
    -- Test webcam configuration change (Requirement 3.3)
    config_manager:set("capture.webcam.resolution.width", 1280)
    TestFramework.assert_not_nil(capture_engine.source_config.webcam, "Webcam config should be updated")
    TestFramework.assert_equal(capture_engine.source_config.webcam.resolution.width, 1280, "Webcam width should be updated")
    
    -- Test batch update with multiple capture settings
    local updates = {
        ["capture.frame_rate"] = 45,
        ["capture.webcam.fps"] = 45
    }
    config_manager:updateBatch(updates)
    
    TestFramework.assert_equal(capture_engine.frame_rate, 45, "Frame rate should be updated via batch")
    TestFramework.assert_true(#capture_engine.callbacks_received >= 2, "Should receive multiple callbacks")
end

function TestConfigManagerIntegration.test_video_renderer_integration()
    local config_manager = ConfigManager:new()
    local video_renderer = MockVideoRenderer:new()
    
    -- Register callbacks for display-related config changes
    config_manager:onConfigChange("display.scaling_mode", function(path, new_val, old_val)
        video_renderer:setScalingMode(new_val)
    end)
    
    config_manager:onConfigChange("display.overlay", function(path, new_val, old_val)
        if path:match("display%.overlay") then
            local overlay_config = config_manager:get("display.overlay")
            video_renderer:configureOverlay(overlay_config)
        end
    end)
    
    -- Test scaling mode change
    config_manager:set("display.scaling_mode", "fill")
    TestFramework.assert_equal(video_renderer.scaling_mode, "fill", "Video renderer should receive scaling mode update")
    TestFramework.assert_equal(#video_renderer.callbacks_received, 1, "Should receive one callback")
    
    -- Test overlay configuration change (Requirement 7.3)
    config_manager:set("display.overlay.x", 200)
    TestFramework.assert_not_nil(video_renderer.overlay_config, "Overlay config should be updated")
    TestFramework.assert_equal(video_renderer.overlay_config.x, 200, "Overlay X position should be updated")
    
    config_manager:set("display.overlay.transparency", 0.5)
    TestFramework.assert_equal(video_renderer.overlay_config.transparency, 0.5, "Overlay transparency should be updated")
end

function TestConfigManagerIntegration.test_runtime_configuration_updates()
    local config_manager = ConfigManager:new()
    local capture_engine = MockCaptureEngine:new()
    local video_renderer = MockVideoRenderer:new()
    
    -- Simulate a running application with active components
    local app_state = {
        is_capturing = true,
        current_source = "webcam",
        components_updated = {}
    }
    
    -- Register comprehensive callbacks
    config_manager:onConfigChange("capture", function(path, new_val, old_val)
        table.insert(app_state.components_updated, "capture_engine")
        if path:match("frame_rate") then
            capture_engine:setFrameRate(new_val)
        elseif path:match("webcam") then
            capture_engine:configureWebcam(config_manager:get("capture.webcam"))
        end
    end)
    
    config_manager:onConfigChange("display", function(path, new_val, old_val)
        table.insert(app_state.components_updated, "video_renderer")
        if path:match("scaling_mode") then
            video_renderer:setScalingMode(new_val)
        elseif path:match("overlay") then
            video_renderer:configureOverlay(config_manager:get("display.overlay"))
        end
    end)
    
    -- Test runtime updates while "capturing"
    TestFramework.assert_true(app_state.is_capturing, "Application should be in capturing state")
    
    -- Update webcam settings during capture (Requirement 3.3)
    config_manager:set("capture.webcam.resolution.height", 720)
    TestFramework.assert_true(#app_state.components_updated > 0, "Components should be notified of updates")
    TestFramework.assert_equal(capture_engine.source_config.webcam.resolution.height, 720, "Webcam height should be updated during runtime")
    
    -- Update overlay settings during capture (Requirement 7.3)
    config_manager:set("display.overlay.width", 500)
    TestFramework.assert_equal(video_renderer.overlay_config.width, 500, "Overlay width should be updated during runtime")
    
    -- Test batch runtime update
    local runtime_updates = {
        ["capture.frame_rate"] = 50,
        ["display.overlay.transparency"] = 0.8,
        ["capture.webcam.fps"] = 50
    }
    
    config_manager:updateBatch(runtime_updates)
    
    TestFramework.assert_equal(capture_engine.frame_rate, 50, "Frame rate should be updated in batch during runtime")
    TestFramework.assert_equal(video_renderer.overlay_config.transparency, 0.8, "Overlay transparency should be updated in batch")
end

function TestConfigManagerIntegration.test_configuration_persistence_integration()
    -- Clear mock files
    mock_files = {}
    
    -- Create initial configuration
    local config_manager1 = ConfigManager:new()
    config_manager1:set("capture.webcam.resolution.width", 1920)
    config_manager1:set("display.overlay.x", 150)
    config_manager1:save()
    
    -- Simulate application restart - create new config manager
    local config_manager2 = ConfigManager:new()
    
    -- Verify persistence of webcam settings (Requirement 3.3)
    TestFramework.assert_equal(config_manager2:get("capture.webcam.resolution.width"), 1920, 
                     "Webcam resolution should persist across restarts")
    
    -- Verify persistence of overlay settings (Requirement 7.3)
    TestFramework.assert_equal(config_manager2:get("display.overlay.x"), 150, 
                     "Overlay position should persist across restarts")
    
    -- Test that components can be reconfigured from persisted settings
    local capture_engine = MockCaptureEngine:new()
    local video_renderer = MockVideoRenderer:new()
    
    -- Apply persisted configuration to components
    capture_engine:configureWebcam(config_manager2:get("capture.webcam"))
    video_renderer:configureOverlay(config_manager2:get("display.overlay"))
    
    TestFramework.assert_equal(capture_engine.source_config.webcam.resolution.width, 1920, 
                     "Capture engine should be configured with persisted webcam settings")
    TestFramework.assert_equal(video_renderer.overlay_config.x, 150, 
                     "Video renderer should be configured with persisted overlay settings")
end

function TestConfigManagerIntegration.test_configuration_validation_integration()
    local config_manager = ConfigManager:new()
    local capture_engine = MockCaptureEngine:new()
    
    -- Register callback that should not be called for invalid updates
    local callback_called = false
    config_manager:onConfigChange("capture.webcam.fps", function(path, new_val, old_val)
        callback_called = true
        capture_engine:configureWebcam(config_manager:get("capture.webcam"))
    end)
    
    -- Attempt invalid webcam FPS update (Requirement 3.3)
    local success = pcall(function()
        config_manager:set("capture.webcam.fps", 200) -- Invalid: > 120
    end)
    
    TestFramework.assert_false(success, "Invalid webcam FPS should be rejected")
    TestFramework.assert_false(callback_called, "Callback should not be called for invalid updates")
    TestFramework.assert_equal(config_manager:get("capture.webcam.fps"), 30, "Webcam FPS should remain at default")
    
    -- Test valid update works
    success = pcall(function()
        config_manager:set("capture.webcam.fps", 60)
    end)
    
    TestFramework.assert_true(success, "Valid webcam FPS should be accepted")
    TestFramework.assert_true(callback_called, "Callback should be called for valid updates")
    TestFramework.assert_equal(capture_engine.source_config.webcam.fps, 60, "Capture engine should receive valid update")
end

-- Run all integration tests
function TestConfigManagerIntegration.run_all_tests()
    TestFramework.reset_stats()
    
    local tests = {
        test_capture_engine_integration = TestConfigManagerIntegration.test_capture_engine_integration,
        test_video_renderer_integration = TestConfigManagerIntegration.test_video_renderer_integration,
        test_runtime_configuration_updates = TestConfigManagerIntegration.test_runtime_configuration_updates,
        test_configuration_persistence_integration = TestConfigManagerIntegration.test_configuration_persistence_integration,
        test_configuration_validation_integration = TestConfigManagerIntegration.test_configuration_validation_integration
    }
    
    TestFramework.run_suite("ConfigManager Integration", tests)
    local stats = TestFramework.get_stats()
    
    return stats.failed == 0
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_config_manager_integration%.lua$") then
    TestConfigManagerIntegration.run_all_tests()
end

return TestConfigManagerIntegration