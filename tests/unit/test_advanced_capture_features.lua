-- Test Advanced Capture Features
-- Tests cursor capture, area selection, and hotkey functionality

local TestFramework = require("tests.test_framework")
local AdvancedCaptureFeatures = require("src.advanced_capture_features")

-- Set testing mode to use mock bindings
_G.TESTING_MODE = true

local TestAdvancedCaptureFeatures = {}

-- Test cursor capture functionality
function TestAdvancedCaptureFeatures.test_cursor_capture_enable_disable()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test enabling cursor capture
    local success, error_msg = features:setCursorCapture(true, "system")
    TestFramework.assert(success, "Should enable cursor capture successfully")
    TestFramework.assert(error_msg == nil, "Should not return error when enabling cursor capture")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.cursor_capture.enabled, "Cursor capture should be enabled in configuration")
    TestFramework.assert(config.cursor_capture.mode == "system", "Cursor capture mode should be 'system'")
    
    -- Test disabling cursor capture
    success, error_msg = features:setCursorCapture(false)
    TestFramework.assert(success, "Should disable cursor capture successfully")
    TestFramework.assert(error_msg == nil, "Should not return error when disabling cursor capture")
    
    config = features:getConfiguration()
    TestFramework.assert(not config.cursor_capture.enabled, "Cursor capture should be disabled in configuration")
    
    print("✓ Cursor capture enable/disable test passed")
end

function TestAdvancedCaptureFeatures.test_cursor_capture_invalid_mode()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test invalid cursor capture mode
    local success, error_msg = features:setCursorCapture(true, "invalid_mode")
    TestFramework.assert(not success, "Should fail with invalid cursor capture mode")
    TestFramework.assert(error_msg ~= nil, "Should return error message for invalid mode")
    TestFramework.assert(string.find(error_msg, "Invalid cursor capture mode"), "Error message should mention invalid mode")
    
    print("✓ Cursor capture invalid mode test passed")
end

function TestAdvancedCaptureFeatures.test_cursor_info_retrieval()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Enable cursor capture first
    features:setCursorCapture(true, "system")
    
    -- Test cursor info retrieval
    local cursor_info = features:getCursorInfo()
    TestFramework.assert(cursor_info ~= nil, "Should retrieve cursor info when enabled")
    TestFramework.assert(cursor_info.position ~= nil, "Cursor info should include position")
    TestFramework.assert(type(cursor_info.position.x) == "number", "Cursor position x should be a number")
    TestFramework.assert(type(cursor_info.position.y) == "number", "Cursor position y should be a number")
    
    -- Test cursor info when disabled
    features:setCursorCapture(false)
    cursor_info = features:getCursorInfo()
    TestFramework.assert(cursor_info == nil, "Should return nil when cursor capture is disabled")
    
    print("✓ Cursor info retrieval test passed")
end

-- Test area selection functionality
function TestAdvancedCaptureFeatures.test_area_selection_lifecycle()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test starting area selection
    local success = features:startAreaSelection()
    TestFramework.assert(success, "Should start area selection successfully")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.area_selection.state == "selecting", "Area selection state should be 'selecting'")
    
    -- Test area selection with mouse input
    local completed, area = features:updateAreaSelection(100, 100, true)  -- Start selection
    TestFramework.assert(not completed, "Selection should not be completed on first click")
    
    completed, area = features:updateAreaSelection(200, 150, false)  -- End selection
    TestFramework.assert(completed, "Selection should be completed when mouse released")
    TestFramework.assert(area ~= nil, "Should return selected area")
    TestFramework.assert(area.x == 100, "Area x should match start position")
    TestFramework.assert(area.y == 100, "Area y should match start position")
    TestFramework.assert(area.width == 100, "Area width should be calculated correctly")
    TestFramework.assert(area.height == 50, "Area height should be calculated correctly")
    
    config = features:getConfiguration()
    TestFramework.assert(config.area_selection.state == "selected", "Area selection state should be 'selected'")
    TestFramework.assert(config.area_selection.current_area ~= nil, "Current area should be set")
    
    print("✓ Area selection lifecycle test passed")
end

function TestAdvancedCaptureFeatures.test_area_selection_minimum_size()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    features:startAreaSelection()
    
    -- Test selection that's too small (should restart selection)
    local completed, area = features:updateAreaSelection(100, 100, true)  -- Start
    completed, area = features:updateAreaSelection(105, 105, false)  -- End (5x5 area, too small)
    
    TestFramework.assert(not completed, "Small selection should not be completed")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.area_selection.state == "selecting", "Should restart selection for small area")
    
    print("✓ Area selection minimum size test passed")
end

function TestAdvancedCaptureFeatures.test_area_selection_cancel()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    features:startAreaSelection()
    
    -- Test canceling area selection
    local success = features:cancelAreaSelection()
    TestFramework.assert(success, "Should cancel area selection successfully")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.area_selection.state == "inactive", "Area selection state should be 'inactive'")
    TestFramework.assert(config.area_selection.current_area == nil, "Current area should be cleared")
    
    print("✓ Area selection cancel test passed")
end

-- Test hotkey functionality
function TestAdvancedCaptureFeatures.test_hotkey_registration()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    local callback_called = false
    local callback_action = nil
    local callback_state = nil
    
    local function test_callback(action, state)
        callback_called = true
        callback_action = action
        callback_state = state
    end
    
    -- Test registering hotkey callback
    local success, error_msg = features:registerHotkeyCallback("toggle_capture", test_callback)
    TestFramework.assert(success, "Should register hotkey callback successfully")
    TestFramework.assert(error_msg == nil, "Should not return error when registering callback")
    
    -- Test registering callback for invalid action
    success, error_msg = features:registerHotkeyCallback("invalid_action", test_callback)
    TestFramework.assert(not success, "Should fail to register callback for invalid action")
    TestFramework.assert(error_msg ~= nil, "Should return error for invalid action")
    
    print("✓ Hotkey registration test passed")
end

function TestAdvancedCaptureFeatures.test_hotkey_binding_update()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test setting hotkey binding
    local success, error_msg = features:setHotkeyBinding("toggle_capture", "ctrl+shift+t")
    TestFramework.assert(success, "Should set hotkey binding successfully")
    TestFramework.assert(error_msg == nil, "Should not return error when setting binding")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.hotkeys.bindings.toggle_capture == "ctrl+shift+t", "Hotkey binding should be updated")
    
    -- Test setting binding for invalid action
    success, error_msg = features:setHotkeyBinding("invalid_action", "f1")
    TestFramework.assert(not success, "Should fail to set binding for invalid action")
    TestFramework.assert(error_msg ~= nil, "Should return error for invalid action")
    
    print("✓ Hotkey binding update test passed")
end

function TestAdvancedCaptureFeatures.test_hotkey_detection()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    local callback_calls = {}
    local function test_callback(action, state)
        table.insert(callback_calls, {action = action, state = state})
    end
    
    features:registerHotkeyCallback("toggle_capture", test_callback)
    
    -- Test hotkey press detection
    local pressed_keys = {f9 = true}
    features:updateHotkeys(pressed_keys)
    
    TestFramework.assert(#callback_calls == 1, "Should trigger callback on hotkey press")
    TestFramework.assert(callback_calls[1].action == "toggle_capture", "Callback should receive correct action")
    TestFramework.assert(callback_calls[1].state == "pressed", "Callback should receive 'pressed' state")
    
    -- Test hotkey release detection
    pressed_keys = {}
    features:updateHotkeys(pressed_keys)
    
    TestFramework.assert(#callback_calls == 2, "Should trigger callback on hotkey release")
    TestFramework.assert(callback_calls[2].state == "released", "Callback should receive 'released' state")
    
    print("✓ Hotkey detection test passed")
end

function TestAdvancedCaptureFeatures.test_complex_hotkey_combinations()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Set complex hotkey combination
    features:setHotkeyBinding("toggle_capture", "ctrl+shift+f9")
    
    local callback_calls = {}
    local function test_callback(action, state)
        table.insert(callback_calls, {action = action, state = state})
    end
    
    features:registerHotkeyCallback("toggle_capture", test_callback)
    
    -- Test partial combination (should not trigger)
    local pressed_keys = {ctrl = true, f9 = true}  -- Missing shift
    features:updateHotkeys(pressed_keys)
    TestFramework.assert(#callback_calls == 0, "Should not trigger callback for partial combination")
    
    -- Test complete combination (should trigger)
    pressed_keys = {ctrl = true, shift = true, f9 = true}
    features:updateHotkeys(pressed_keys)
    TestFramework.assert(#callback_calls == 1, "Should trigger callback for complete combination")
    
    print("✓ Complex hotkey combinations test passed")
end

-- Test visual feedback functionality
function TestAdvancedCaptureFeatures.test_visual_feedback_settings()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test enabling visual feedback
    local success = features:setVisualFeedback(true)
    TestFramework.assert(success, "Should enable visual feedback successfully")
    
    -- Test disabling visual feedback
    success = features:setVisualFeedback(false)
    TestFramework.assert(success, "Should disable visual feedback successfully")
    
    print("✓ Visual feedback settings test passed")
end

function TestAdvancedCaptureFeatures.test_grid_overlay_settings()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test enabling grid overlay
    local success = features:setGridOverlay(true, 25)
    TestFramework.assert(success, "Should enable grid overlay successfully")
    
    local config = features:getConfiguration()
    TestFramework.assert(config.overlay.grid_visible, "Grid should be visible in configuration")
    TestFramework.assert(config.overlay.grid_size == 25, "Grid size should be updated")
    
    -- Test disabling grid overlay
    success = features:setGridOverlay(false)
    TestFramework.assert(success, "Should disable grid overlay successfully")
    
    config = features:getConfiguration()
    TestFramework.assert(not config.overlay.grid_visible, "Grid should not be visible in configuration")
    
    print("✓ Grid overlay settings test passed")
end

-- Test configuration management
function TestAdvancedCaptureFeatures.test_configuration_retrieval()
    local features = AdvancedCaptureFeatures:new({
        cursor_capture = true,
        hotkeys_enabled = true,
        toggle_key = "f8"
    })
    features:initialize()
    
    local config = features:getConfiguration()
    
    -- Test configuration structure
    TestFramework.assert(config.cursor_capture ~= nil, "Configuration should include cursor_capture")
    TestFramework.assert(config.area_selection ~= nil, "Configuration should include area_selection")
    TestFramework.assert(config.hotkeys ~= nil, "Configuration should include hotkeys")
    TestFramework.assert(config.overlay ~= nil, "Configuration should include overlay")
    
    -- Test hotkey configuration
    TestFramework.assert(config.hotkeys.enabled, "Hotkeys should be enabled")
    TestFramework.assert(config.hotkeys.bindings.toggle_capture == "f8", "Custom toggle key should be set")
    
    print("✓ Configuration retrieval test passed")
end

-- Test error handling
function TestAdvancedCaptureFeatures.test_error_handling()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test error retrieval
    local error_msg = features:getLastError()
    TestFramework.assert(error_msg == nil, "Should have no error initially")
    
    -- Trigger an error
    features:setCursorCapture(true, "invalid_mode")
    error_msg = features:getLastError()
    TestFramework.assert(error_msg ~= nil, "Should have error after invalid operation")
    TestFramework.assert(string.find(error_msg, "Invalid cursor capture mode"), "Error should describe the problem")
    
    print("✓ Error handling test passed")
end

-- Test edge cases and boundary conditions
function TestAdvancedCaptureFeatures.test_edge_cases()
    local features = AdvancedCaptureFeatures:new()
    features:initialize()
    
    -- Test area selection with negative coordinates
    features:startAreaSelection()
    local completed, area = features:updateAreaSelection(200, 200, true)  -- Start
    completed, area = features:updateAreaSelection(100, 100, false)  -- End (reverse selection)
    
    if completed and area then
        TestFramework.assert(area.x == 100, "Should handle reverse selection correctly (x)")
        TestFramework.assert(area.y == 100, "Should handle reverse selection correctly (y)")
        TestFramework.assert(area.width == 100, "Should calculate width correctly for reverse selection")
        TestFramework.assert(area.height == 100, "Should calculate height correctly for reverse selection")
    end
    
    -- Test hotkey update with empty key set
    features:updateHotkeys({})
    -- Should not crash or cause errors
    
    -- Test cursor info when not initialized
    local cursor_info = features:getCursorInfo()
    -- Should handle gracefully (return nil when disabled)
    
    print("✓ Edge cases test passed")
end

-- Integration test with multiple features
function TestAdvancedCaptureFeatures.test_feature_integration()
    local features = AdvancedCaptureFeatures:new({
        cursor_capture = true,
        hotkeys_enabled = true
    })
    features:initialize()
    
    -- Enable multiple features
    features:setCursorCapture(true, "system")
    features:setVisualFeedback(true)
    features:setGridOverlay(true, 20)
    
    -- Start area selection
    features:startAreaSelection()
    
    -- Register hotkey callback
    local hotkey_triggered = false
    features:registerHotkeyCallback("area_select", function() hotkey_triggered = true end)
    
    -- Test that all features work together
    local config = features:getConfiguration()
    TestFramework.assert(config.cursor_capture.enabled, "Cursor capture should be enabled")
    TestFramework.assert(config.area_selection.state == "selecting", "Area selection should be active")
    TestFramework.assert(config.hotkeys.enabled, "Hotkeys should be enabled")
    TestFramework.assert(config.overlay.grid_visible, "Grid overlay should be visible")
    
    -- Test hotkey while in area selection mode
    features:updateHotkeys({f12 = true})
    TestFramework.assert(hotkey_triggered, "Hotkey should work during area selection")
    
    print("✓ Feature integration test passed")
end

-- Run all tests
function TestAdvancedCaptureFeatures.run_all_tests()
    print("Running Advanced Capture Features Tests...")
    print("=" .. string.rep("=", 50))
    
    -- Cursor capture tests
    TestAdvancedCaptureFeatures.test_cursor_capture_enable_disable()
    TestAdvancedCaptureFeatures.test_cursor_capture_invalid_mode()
    TestAdvancedCaptureFeatures.test_cursor_info_retrieval()
    
    -- Area selection tests
    TestAdvancedCaptureFeatures.test_area_selection_lifecycle()
    TestAdvancedCaptureFeatures.test_area_selection_minimum_size()
    TestAdvancedCaptureFeatures.test_area_selection_cancel()
    
    -- Hotkey tests
    TestAdvancedCaptureFeatures.test_hotkey_registration()
    TestAdvancedCaptureFeatures.test_hotkey_binding_update()
    TestAdvancedCaptureFeatures.test_hotkey_detection()
    TestAdvancedCaptureFeatures.test_complex_hotkey_combinations()
    
    -- Visual feedback tests
    TestAdvancedCaptureFeatures.test_visual_feedback_settings()
    TestAdvancedCaptureFeatures.test_grid_overlay_settings()
    
    -- Configuration and error handling tests
    TestAdvancedCaptureFeatures.test_configuration_retrieval()
    TestAdvancedCaptureFeatures.test_error_handling()
    
    -- Edge cases and integration tests
    TestAdvancedCaptureFeatures.test_edge_cases()
    TestAdvancedCaptureFeatures.test_feature_integration()
    
    print("=" .. string.rep("=", 50))
    print("✅ All Advanced Capture Features tests passed!")
    
    return true
end

return TestAdvancedCaptureFeatures