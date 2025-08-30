-- Integration tests for overlay functionality
-- Tests overlay behavior and z-order management (Requirement 7.4)

local TestFramework = require("tests.test_framework")

-- Mock love.window for testing
if not love then
    _G.love = {}
end

if not love.window then
    love.window = {
        getMode = function()
            return 800, 600, {borderless = false, resizable = true}
        end,
        getPosition = function()
            return 100, 100
        end,
        setMode = function(width, height, flags)
            return true
        end,
        setPosition = function(x, y)
            return true
        end,
        getTitle = function()
            return "Test Window"
        end
    }
end

if not love.timer then
    love.timer = {
        getTime = function()
            return os.clock()
        end
    }
end

if not love.graphics then
    love.graphics = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end
    }
end

local OverlayManager = require("src.overlay_manager")
local UIController = require("src.ui_controller")
local VideoRenderer = require("src.video_renderer")
local CaptureEngine = require("src.capture_engine")

local TestOverlayIntegration = {}

-- Test suite definition
local overlay_integration_tests = {
    testUIControllerOverlayIntegration = TestOverlayIntegration.testUIControllerOverlayIntegration,
    testOverlayWithVideoRenderer = TestOverlayIntegration.testOverlayWithVideoRenderer,
    testOverlayWithCaptureEngine = TestOverlayIntegration.testOverlayWithCaptureEngine,
    testOverlayModeTransitions = TestOverlayIntegration.testOverlayModeTransitions,
    testOverlayKeyboardShortcuts = TestOverlayIntegration.testOverlayKeyboardShortcuts,
    testOverlaySettingsScreen = TestOverlayIntegration.testOverlaySettingsScreen,
    testOverlayStateConsistency = TestOverlayIntegration.testOverlayStateConsistency,
    testOverlayErrorRecovery = TestOverlayIntegration.testOverlayErrorRecovery,
    testOverlayPerformanceImpact = TestOverlayIntegration.testOverlayPerformanceImpact,
    testZOrderManagement = TestOverlayIntegration.testZOrderManagement
}

-- Run tests function
local function runOverlayIntegrationTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("OverlayIntegration Tests", overlay_integration_tests)
    
    local stats = TestFramework.get_stats()
    TestFramework.cleanup_mock_environment()
    
    return stats
end

function TestOverlayIntegration.runAllTests()
    return runOverlayIntegrationTests()
end

function TestOverlayIntegration.testUIControllerOverlayIntegration()
    -- Create mock capture engine
    local mockCaptureEngine = {
        getAvailableSources = function() return {
            screen = {available = true},
            window = {available = true, windows = {{title = "Test Window"}}},
            webcam = {available = false}
        } end,
        getSourceConfigurationOptions = function() return {} end,
        setSource = function() return true end,
        startCapture = function() return true end,
        stopCapture = function() return true end,
        pauseCapture = function() return true end,
        resumeCapture = function() return true end,
        getStats = function() return {actual_fps = 30, frames_captured = 100} end,
        getFrame = function() return nil end,
        update = function() end
    }
    
    local renderer = VideoRenderer:new()
    local ui = UIController:new(mockCaptureEngine, renderer)
    
    TestFramework.assert(ui.overlay_manager ~= nil, "UI controller should have overlay manager")
    
    local success = ui:initialize()
    TestFramework.assert(success == true, "UI controller should initialize successfully")
    
    -- Test overlay manager integration
    local overlay_config = ui.overlay_manager:getConfiguration()
    TestFramework.assert(overlay_config ~= nil, "Should get overlay configuration")
    TestFramework.assert(overlay_config.mode == OverlayManager.MODES.NORMAL, "Should start in normal mode")
    
    -- Test overlay settings screen
    ui:_showOverlaySettings()
    TestFramework.assert(ui.current_screen == "overlay_settings", "Should show overlay settings screen")
    TestFramework.assert(ui.buttons ~= nil, "Should have overlay control buttons")
    
    -- Test overlay mode setting through UI
    ui:_setOverlayMode(OverlayManager.MODES.OVERLAY)
    overlay_config = ui.overlay_manager:getConfiguration()
    TestFramework.assert(overlay_config.mode == OverlayManager.MODES.OVERLAY, "Should set overlay mode")
    TestFramework.assert(overlay_config.is_active == true, "Should be active")
    
    ui:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayWithVideoRenderer()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    local renderer = VideoRenderer:new()
    
    -- Test renderer transparency integration
    overlay:setTransparency(0.5)
    renderer:setTransparency(0.5)
    
    local renderer_state = renderer:getState()
    TestFramework.assert(renderer_state.transparency == 0.5, "Renderer should match overlay transparency")
    
    -- Test overlay mode with renderer
    overlay:setOverlayMode(OverlayManager.MODES.TRANSPARENT_OVERLAY)
    renderer:setOverlayMode(true)
    
    renderer_state = renderer:getState()
    TestFramework.assert(renderer_state.overlay_mode == true, "Renderer should be in overlay mode")
    
    overlay:cleanup()
    renderer:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayWithCaptureEngine()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Create mock capture engine
    local captureEngine = CaptureEngine:new()
    
    -- Test overlay doesn't interfere with capture
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    
    local sources = captureEngine:getAvailableSources()
    TestFramework.assert(sources ~= nil, "Should still get available sources in overlay mode")
    
    -- Test capture with overlay active
    local success = captureEngine:setSource("screen", {mode = "FULL_SCREEN"})
    TestFramework.assert(success == true, "Should set source with overlay active")
    
    overlay:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayModeTransitions()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test all mode transitions
    local modes = {
        OverlayManager.MODES.NORMAL,
        OverlayManager.MODES.OVERLAY,
        OverlayManager.MODES.TRANSPARENT_OVERLAY,
        OverlayManager.MODES.CLICK_THROUGH
    }
    
    for i, mode in ipairs(modes) do
        local success = overlay:setOverlayMode(mode)
        TestFramework.assert(success == true, "Should transition to " .. mode)
        
        local config = overlay:getConfiguration()
        TestFramework.assert(config.mode == mode, "Mode should be set correctly")
        
        local expected_active = (mode ~= OverlayManager.MODES.NORMAL)
        TestFramework.assert(config.is_active == expected_active, "Active state should match mode")
    end
    
    -- Test rapid mode transitions
    for i = 1, 10 do
        local mode = modes[math.random(#modes)]
        local success = overlay:setOverlayMode(mode)
        TestFramework.assert(success == true, "Should handle rapid transitions")
    end
    
    overlay:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayKeyboardShortcuts()
    -- Create mock capture engine
    local mockCaptureEngine = {
        getAvailableSources = function() return {screen = {available = true}} end,
        getSourceConfigurationOptions = function() return {} end,
        setSource = function() return true end,
        startCapture = function() return true end,
        stopCapture = function() return true end,
        pauseCapture = function() return true end,
        resumeCapture = function() return true end,
        getStats = function() return {actual_fps = 30, frames_captured = 100} end,
        getFrame = function() return nil end,
        update = function() end
    }
    
    local renderer = VideoRenderer:new()
    local ui = UIController:new(mockCaptureEngine, renderer)
    ui:initialize()
    
    -- Test overlay settings shortcut
    local handled = ui:handleInput("o", "pressed")
    TestFramework.assert(handled == true, "Should handle overlay settings shortcut")
    TestFramework.assert(ui.current_screen == "overlay_settings", "Should show overlay settings")
    
    -- Test always on top shortcut
    local original_config = ui.overlay_manager:getConfiguration()
    handled = ui:handleInput("t", "pressed")
    TestFramework.assert(handled == true, "Should handle always on top shortcut")
    
    local new_config = ui.overlay_manager:getConfiguration()
    TestFramework.assert(new_config.always_on_top ~= original_config.always_on_top, "Should toggle always on top")
    
    -- Test borderless shortcut
    original_config = ui.overlay_manager:getConfiguration()
    handled = ui:handleInput("b", "pressed")
    TestFramework.assert(handled == true, "Should handle borderless shortcut")
    
    new_config = ui.overlay_manager:getConfiguration()
    TestFramework.assert(new_config.borderless ~= original_config.borderless, "Should toggle borderless")
    
    -- Test transparency shortcuts
    original_config = ui.overlay_manager:getConfiguration()
    handled = ui:handleInput("+", "pressed")
    TestFramework.assert(handled == true, "Should handle transparency increase shortcut")
    
    new_config = ui.overlay_manager:getConfiguration()
    TestFramework.assert(new_config.transparency >= original_config.transparency, "Should increase transparency")
    
    handled = ui:handleInput("-", "pressed")
    TestFramework.assert(handled == true, "Should handle transparency decrease shortcut")
    
    ui:cleanup()
    return true
end

function TestOverlayIntegration.testOverlaySettingsScreen()
    -- Create mock capture engine
    local mockCaptureEngine = {
        getAvailableSources = function() return {screen = {available = true}} end,
        getSourceConfigurationOptions = function() return {} end,
        setSource = function() return true end,
        getStats = function() return {actual_fps = 30, frames_captured = 100} end,
        getFrame = function() return nil end,
        update = function() end
    }
    
    local renderer = VideoRenderer:new()
    local ui = UIController:new(mockCaptureEngine, renderer)
    ui:initialize()
    
    -- Show overlay settings screen
    ui:_showOverlaySettings()
    
    TestFramework.assert(ui.current_screen == "overlay_settings", "Should be in overlay settings screen")
    TestFramework.assert(ui.buttons ~= nil, "Should have buttons")
    
    -- Check for expected buttons
    local expected_buttons = {
        "back",
        "mode_normal",
        "mode_overlay", 
        "mode_transparent_overlay",
        "mode_click_through",
        "transparency_decrease",
        "transparency_increase",
        "toggle_always_on_top",
        "toggle_borderless",
        "toggle_click_through",
        "toggle_hide_from_taskbar"
    }
    
    for _, button_name in ipairs(expected_buttons) do
        TestFramework.assert(ui.buttons[button_name] ~= nil, "Should have " .. button_name .. " button")
        TestFramework.assert(ui.buttons[button_name].enabled == true, "Button should be enabled")
    end
    
    -- Test button actions
    local original_config = ui.overlay_manager:getConfiguration()
    
    -- Test mode button
    if ui.buttons.mode_overlay and ui.buttons.mode_overlay.action then
        ui.buttons.mode_overlay.action()
        local new_config = ui.overlay_manager:getConfiguration()
        TestFramework.assert(new_config.mode == OverlayManager.MODES.OVERLAY, "Should set overlay mode")
    end
    
    -- Test transparency buttons
    if ui.buttons.transparency_increase and ui.buttons.transparency_increase.action then
        ui.buttons.transparency_increase.action()
        local new_config = ui.overlay_manager:getConfiguration()
        TestFramework.assert(new_config.transparency >= original_config.transparency, "Should increase transparency")
    end
    
    ui:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayStateConsistency()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Set multiple overlay properties
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    overlay:setTransparency(0.7)
    overlay:setAlwaysOnTop(true)
    overlay:setBorderless(true)
    overlay:setClickThrough(false)
    overlay:setPosition(200, 150)
    overlay:setSize(1024, 768)
    
    -- Verify state consistency
    local config = overlay:getConfiguration()
    local state = overlay:getState()
    
    TestFramework.assert(config.mode == state.mode, "Config and state mode should match")
    TestFramework.assert(config.transparency == state.transparency, "Config and state transparency should match")
    TestFramework.assert(config.always_on_top == state.always_on_top, "Config and state always_on_top should match")
    TestFramework.assert(config.borderless == state.borderless, "Config and state borderless should match")
    TestFramework.assert(config.click_through == state.click_through, "Config and state click_through should match")
    TestFramework.assert(config.is_active == state.is_active, "Config and state active should match")
    
    -- Test state after mode change
    overlay:setOverlayMode(OverlayManager.MODES.NORMAL)
    config = overlay:getConfiguration()
    state = overlay:getState()
    
    TestFramework.assert(config.is_active == false, "Should be inactive in normal mode")
    TestFramework.assert(state.is_active == false, "State should match config")
    
    overlay:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayErrorRecovery()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test recovery from invalid mode setting
    local original_mode = overlay.mode
    local success, err = overlay:setOverlayMode("invalid_mode")
    
    TestFramework.assert(success == false, "Should reject invalid mode")
    TestFramework.assert(overlay.mode == original_mode, "Should maintain original mode on error")
    
    -- Test that overlay still works after error
    success = overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    TestFramework.assert(success == true, "Should work normally after error")
    
    success = overlay:setTransparency(0.5)
    TestFramework.assert(success == true, "Should set transparency after error")
    
    overlay:cleanup()
    return true
end

function TestOverlayIntegration.testOverlayPerformanceImpact()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Measure update performance
    local start_time = love.timer.getTime()
    
    for i = 1, 1000 do
        overlay:update(0.016)  -- Simulate 60 FPS
    end
    
    local end_time = love.timer.getTime()
    local elapsed = end_time - start_time
    
    TestFramework.assert(elapsed < 0.1, "Overlay updates should be fast (< 0.1s for 1000 updates)")
    
    -- Test performance with mode changes
    start_time = love.timer.getTime()
    
    local modes = {
        OverlayManager.MODES.NORMAL,
        OverlayManager.MODES.OVERLAY,
        OverlayManager.MODES.TRANSPARENT_OVERLAY,
        OverlayManager.MODES.CLICK_THROUGH
    }
    
    for i = 1, 100 do
        local mode = modes[(i % #modes) + 1]
        overlay:setOverlayMode(mode)
        overlay:update(0.016)
    end
    
    end_time = love.timer.getTime()
    elapsed = end_time - start_time
    
    TestFramework.assert(elapsed < 1.0, "Mode changes should be reasonably fast (< 1s for 100 changes)")
    
    overlay:cleanup()
    return true
end

function TestOverlayIntegration.testZOrderManagement()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test z-order management (Requirement 7.4)
    local success = overlay:setAlwaysOnTop(true)
    TestFramework.assert(success == true, "Should set always on top")
    
    local config = overlay:getConfiguration()
    TestFramework.assert(config.always_on_top == true, "Should be always on top")
    
    -- Test z-order with overlay mode
    success = overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    TestFramework.assert(success == true, "Should set overlay mode")
    
    config = overlay:getConfiguration()
    TestFramework.assert(config.always_on_top == true, "Should maintain always on top in overlay mode")
    TestFramework.assert(config.is_active == true, "Should be active")
    
    -- Test z-order restoration
    success = overlay:setOverlayMode(OverlayManager.MODES.NORMAL)
    TestFramework.assert(success == true, "Should restore normal mode")
    
    config = overlay:getConfiguration()
    TestFramework.assert(config.is_active == false, "Should be inactive in normal mode")
    
    overlay:cleanup()
    return true
end

return TestOverlayIntegration