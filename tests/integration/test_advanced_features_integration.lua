-- Integration Tests for Advanced Capture Features
-- Tests integration of cursor capture, area selection, and hotkeys with capture modules

local TestFramework = require("tests.test_framework")
local ScreenCapture = require("src.screen_capture")
local WindowCapture = require("src.window_capture")

-- Set testing mode to use mock bindings
_G.TESTING_MODE = true

local TestAdvancedFeaturesIntegration = {}

-- Test screen capture with cursor capture
function TestAdvancedFeaturesIntegration.test_screen_capture_with_cursor()
    local screen_capture = ScreenCapture:new({cursor_capture = true})
    screen_capture:initialize()
    
    -- Enable cursor capture
    local success, error_msg = screen_capture:setCursorCapture(true)
    TestFramework.assert(success, "Should enable cursor capture on screen capture")
    TestFramework.assert(error_msg == nil, "Should not return error when enabling cursor capture")
    
    -- Test capture with cursor
    local bitmap, width, height = screen_capture:capture()
    TestFramework.assert(bitmap ~= nil, "Should capture screen with cursor successfully")
    TestFramework.assert(width > 0, "Captured width should be positive")
    TestFramework.assert(height > 0, "Captured height should be positive")
    
    -- Verify cursor capture is enabled in configuration
    local config = screen_capture:getAdvancedConfiguration()
    TestFramework.assert(config.cursor_capture.enabled, "Cursor capture should be enabled in configuration")
    
    print("✓ Screen capture with cursor test passed")
end

function TestAdvancedFeaturesIntegration.test_screen_capture_area_selection()
    local screen_capture = ScreenCapture:new()
    screen_capture:initialize()
    
    -- Start area selection
    local success = screen_capture:startAreaSelection()
    TestFramework.assert(success, "Should start area selection successfully")
    
    -- Simulate mouse input for area selection
    local completed, area = screen_capture:updateAreaSelection(100, 100, true)  -- Start
    TestFramework.assert(not completed, "Selection should not be completed on start")
    
    completed, area = screen_capture:updateAreaSelection(300, 200, false)  -- End
    TestFramework.assert(completed, "Selection should be completed on end")
    TestFramework.assert(area ~= nil, "Should return selected area")
    TestFramework.assert(area.width == 200, "Selected area width should be correct")
    TestFramework.assert(area.height == 100, "Selected area height should be correct")
    
    -- Verify that the screen capture region was updated
    local capture_info = screen_capture:getCaptureInfo()
    TestFramework.assert(capture_info.mode == "CUSTOM_REGION", "Capture mode should be set to custom region")
    TestFramework.assert(capture_info.x == area.x, "Capture region x should match selected area")
    TestFramework.assert(capture_info.y == area.y, "Capture region y should match selected area")
    TestFramework.assert(capture_info.width == area.width, "Capture region width should match selected area")
    TestFramework.assert(capture_info.height == area.height, "Capture region height should match selected area")
    
    print("✓ Screen capture area selection test passed")
end

function TestAdvancedFeaturesIntegration.test_screen_capture_area_selection_cancel()
    local screen_capture = ScreenCapture:new()
    screen_capture:initialize()
    
    -- Start area selection
    screen_capture:startAreaSelection()
    
    -- Cancel area selection
    local success = screen_capture:cancelAreaSelection()
    TestFramework.assert(success, "Should cancel area selection successfully")
    
    -- Verify area selection is cancelled
    local config = screen_capture:getAdvancedConfiguration()
    TestFramework.assert(config.area_selection.state == "inactive", "Area selection should be inactive after cancel")
    TestFramework.assert(config.area_selection.current_area == nil, "Current area should be cleared after cancel")
    
    print("✓ Screen capture area selection cancel test passed")
end

function TestAdvancedFeaturesIntegration.test_window_capture_with_cursor()
    local window_capture = WindowCapture:new({cursor_capture = true})
    window_capture:initializeAdvancedFeatures()
    
    -- Set a mock target window
    local mock_window = {
        handle = 1,
        title = "Test Window",
        visible = true,
        minimized = false,
        rect = {left = 100, top = 100, right = 500, bottom = 400, width = 400, height = 300}
    }
    
    local success = window_capture:setTargetWindow(mock_window)
    TestFramework.assert(success, "Should set target window successfully")
    
    -- Enable cursor capture
    success = window_capture:setCursorCapture(true)
    TestFramework.assert(success, "Should enable cursor capture on window capture")
    
    -- Test capture with cursor
    local result = window_capture:captureWindow()
    TestFramework.assert(result ~= nil, "Should capture window with cursor successfully")
    
    -- Verify cursor capture is enabled in configuration
    local config = window_capture:getAdvancedConfiguration()
    TestFramework.assert(config.cursor_capture.enabled, "Cursor capture should be enabled in configuration")
    
    print("✓ Window capture with cursor test passed")
end

function TestAdvancedFeaturesIntegration.test_hotkey_integration_screen_capture()
    local screen_capture = ScreenCapture:new({hotkeys_enabled = true})
    screen_capture:initialize()
    
    local hotkey_actions = {}
    
    -- Register hotkey callbacks
    local success = screen_capture:registerHotkeyCallback("toggle_capture", function(action, state)
        table.insert(hotkey_actions, {action = action, state = state})
    end)
    TestFramework.assert(success, "Should register toggle_capture hotkey callback")
    
    success = screen_capture:registerHotkeyCallback("area_select", function(action, state)
        table.insert(hotkey_actions, {action = action, state = state})
    end)
    TestFramework.assert(success, "Should register area_select hotkey callback")
    
    -- Test hotkey triggering
    screen_capture:updateHotkeys({f9 = true})  -- Toggle capture hotkey
    TestFramework.assert(#hotkey_actions == 1, "Should trigger toggle_capture hotkey")
    TestFramework.assert(hotkey_actions[1].action == "toggle_capture", "Should trigger correct action")
    TestFramework.assert(hotkey_actions[1].state == "pressed", "Should trigger with pressed state")
    
    screen_capture:updateHotkeys({f12 = true})  -- Area select hotkey
    TestFramework.assert(#hotkey_actions == 2, "Should trigger area_select hotkey")
    TestFramework.assert(hotkey_actions[2].action == "area_select", "Should trigger correct action")
    
    print("✓ Hotkey integration with screen capture test passed")
end

function TestAdvancedFeaturesIntegration.test_hotkey_integration_window_capture()
    local window_capture = WindowCapture:new({hotkeys_enabled = true})
    window_capture:initializeAdvancedFeatures()
    
    local hotkey_actions = {}
    
    -- Register hotkey callback
    local success = window_capture:registerHotkeyCallback("toggle_capture", function(action, state)
        table.insert(hotkey_actions, {action = action, state = state})
    end)
    TestFramework.assert(success, "Should register hotkey callback for window capture")
    
    -- Test hotkey triggering
    window_capture:updateHotkeys({f9 = true})
    TestFramework.assert(#hotkey_actions == 1, "Should trigger hotkey for window capture")
    TestFramework.assert(hotkey_actions[1].action == "toggle_capture", "Should trigger correct action")
    
    print("✓ Hotkey integration with window capture test passed")
end

function TestAdvancedFeaturesIntegration.test_custom_hotkey_bindings()
    local screen_capture = ScreenCapture:new({
        hotkeys_enabled = true,
        toggle_key = "ctrl+shift+c",
        area_select_key = "ctrl+a"
    })
    screen_capture:initialize()
    
    local hotkey_actions = {}
    
    -- Register callbacks
    screen_capture:registerHotkeyCallback("toggle_capture", function(action, state)
        table.insert(hotkey_actions, {action = action, state = state, key = "toggle"})
    end)
    
    screen_capture:registerHotkeyCallback("area_select", function(action, state)
        table.insert(hotkey_actions, {action = action, state = state, key = "area"})
    end)
    
    -- Test custom hotkey combinations
    screen_capture:updateHotkeys({ctrl = true, shift = true, c = true})
    TestFramework.assert(#hotkey_actions == 1, "Should trigger custom toggle hotkey")
    TestFramework.assert(hotkey_actions[1].key == "toggle", "Should trigger toggle action")
    
    screen_capture:updateHotkeys({ctrl = true, a = true})
    TestFramework.assert(#hotkey_actions == 2, "Should trigger custom area select hotkey")
    TestFramework.assert(hotkey_actions[2].key == "area", "Should trigger area select action")
    
    print("✓ Custom hotkey bindings test passed")
end

function TestAdvancedFeaturesIntegration.test_visual_feedback_integration()
    local screen_capture = ScreenCapture:new()
    screen_capture:initialize()
    
    -- Test visual feedback settings
    local success = screen_capture:setVisualFeedback(true)
    TestFramework.assert(success, "Should enable visual feedback")
    
    success = screen_capture:setGridOverlay(true, 25)
    TestFramework.assert(success, "Should enable grid overlay")
    
    -- Verify settings in configuration
    local config = screen_capture:getAdvancedConfiguration()
    TestFramework.assert(config.overlay.grid_visible, "Grid overlay should be visible")
    TestFramework.assert(config.overlay.grid_size == 25, "Grid size should be set correctly")
    
    print("✓ Visual feedback integration test passed")
end

function TestAdvancedFeaturesIntegration.test_multiple_features_combined()
    local screen_capture = ScreenCapture:new({
        cursor_capture = true,
        hotkeys_enabled = true,
        toggle_key = "f8"
    })
    screen_capture:initialize()
    
    -- Enable multiple advanced features
    screen_capture:setCursorCapture(true)
    screen_capture:setVisualFeedback(true)
    screen_capture:setGridOverlay(true, 30)
    
    local hotkey_triggered = false
    screen_capture:registerHotkeyCallback("toggle_capture", function()
        hotkey_triggered = true
    end)
    
    -- Start area selection
    screen_capture:startAreaSelection()
    
    -- Test that all features work together
    local config = screen_capture:getAdvancedConfiguration()
    TestFramework.assert(config.cursor_capture.enabled, "Cursor capture should be enabled")
    TestFramework.assert(config.area_selection.state == "selecting", "Area selection should be active")
    TestFramework.assert(config.hotkeys.enabled, "Hotkeys should be enabled")
    TestFramework.assert(config.overlay.grid_visible, "Grid overlay should be visible")
    
    -- Test hotkey while other features are active
    screen_capture:updateHotkeys({f8 = true})
    TestFramework.assert(hotkey_triggered, "Hotkey should work with other features active")
    
    -- Complete area selection
    local completed, area = screen_capture:updateAreaSelection(50, 50, true)
    completed, area = screen_capture:updateAreaSelection(150, 100, false)
    
    if completed and area then
        -- Test capture with all features enabled
        local bitmap, width, height = screen_capture:capture()
        TestFramework.assert(bitmap ~= nil, "Should capture with all features enabled")
        TestFramework.assert(width == area.width, "Captured width should match selected area")
        TestFramework.assert(height == area.height, "Captured height should match selected area")
    end
    
    print("✓ Multiple features combined test passed")
end

function TestAdvancedFeaturesIntegration.test_error_handling_integration()
    local screen_capture = ScreenCapture:new()
    screen_capture:initialize()
    
    -- Test invalid hotkey registration
    local success, error_msg = screen_capture:registerHotkeyCallback("invalid_action", function() end)
    TestFramework.assert(not success, "Should fail to register invalid hotkey action")
    TestFramework.assert(error_msg ~= nil, "Should return error message for invalid action")
    
    -- Test invalid hotkey binding
    success, error_msg = screen_capture:setHotkeyBinding("invalid_action", "f1")
    TestFramework.assert(not success, "Should fail to set invalid hotkey binding")
    TestFramework.assert(error_msg ~= nil, "Should return error message for invalid binding")
    
    -- Test area selection without proper initialization
    local area = screen_capture:getSelectedArea()
    TestFramework.assert(area == nil, "Should return nil for area when not selected")
    
    print("✓ Error handling integration test passed")
end

function TestAdvancedFeaturesIntegration.test_performance_with_advanced_features()
    local screen_capture = ScreenCapture:new({
        cursor_capture = true,
        hotkeys_enabled = true
    })
    screen_capture:initialize()
    
    -- Enable all advanced features
    screen_capture:setCursorCapture(true)
    screen_capture:setVisualFeedback(true)
    screen_capture:setGridOverlay(true, 20)
    
    -- Register multiple hotkey callbacks
    for i = 1, 5 do
        screen_capture:registerHotkeyCallback("toggle_capture", function() end)
    end
    
    -- Perform multiple operations to test performance
    local start_time = os.clock()
    
    for i = 1, 100 do
        screen_capture:updateHotkeys({f9 = true})
        screen_capture:updateHotkeys({})
        
        if i % 10 == 0 then
            local config = screen_capture:getAdvancedConfiguration()
            -- Just access configuration to test performance
        end
    end
    
    local end_time = os.clock()
    local elapsed = end_time - start_time
    
    TestFramework.assert(elapsed < 1.0, "Advanced features should not significantly impact performance")
    
    print("✓ Performance with advanced features test passed")
end

-- Run all integration tests
function TestAdvancedFeaturesIntegration.run_all_tests()
    print("Running Advanced Features Integration Tests...")
    print("=" .. string.rep("=", 60))
    
    -- Screen capture integration tests
    TestAdvancedFeaturesIntegration.test_screen_capture_with_cursor()
    TestAdvancedFeaturesIntegration.test_screen_capture_area_selection()
    TestAdvancedFeaturesIntegration.test_screen_capture_area_selection_cancel()
    
    -- Window capture integration tests
    TestAdvancedFeaturesIntegration.test_window_capture_with_cursor()
    
    -- Hotkey integration tests
    TestAdvancedFeaturesIntegration.test_hotkey_integration_screen_capture()
    TestAdvancedFeaturesIntegration.test_hotkey_integration_window_capture()
    TestAdvancedFeaturesIntegration.test_custom_hotkey_bindings()
    
    -- Visual feedback integration tests
    TestAdvancedFeaturesIntegration.test_visual_feedback_integration()
    
    -- Combined features tests
    TestAdvancedFeaturesIntegration.test_multiple_features_combined()
    
    -- Error handling and performance tests
    TestAdvancedFeaturesIntegration.test_error_handling_integration()
    TestAdvancedFeaturesIntegration.test_performance_with_advanced_features()
    
    print("=" .. string.rep("=", 60))
    print("✅ All Advanced Features Integration tests passed!")
    
    return true
end

return TestAdvancedFeaturesIntegration