-- Unit tests for OverlayManager
-- Tests overlay window configuration and transparency features

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

local OverlayManager = require("src.overlay_manager")

local TestOverlayManager = {}

-- Test suite definition
local overlay_manager_tests = {
    testCreation = TestOverlayManager.testCreation,
    testInitialization = TestOverlayManager.testInitialization,
    testOverlayModeSettings = TestOverlayManager.testOverlayModeSettings,
    testTransparencyControl = TestOverlayManager.testTransparencyControl,
    testAlwaysOnTopControl = TestOverlayManager.testAlwaysOnTopControl,
    testBorderlessControl = TestOverlayManager.testBorderlessControl,
    testClickThroughControl = TestOverlayManager.testClickThroughControl,
    testTaskbarVisibilityControl = TestOverlayManager.testTaskbarVisibilityControl,
    testPositionControl = TestOverlayManager.testPositionControl,
    testSizeControl = TestOverlayManager.testSizeControl,
    testConfigurationRetrieval = TestOverlayManager.testConfigurationRetrieval,
    testStateManagement = TestOverlayManager.testStateManagement,
    testModeTransitions = TestOverlayManager.testModeTransitions,
    testErrorHandling = TestOverlayManager.testErrorHandling,
    testCleanup = TestOverlayManager.testCleanup
}

-- Run tests function
local function runOverlayManagerTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("OverlayManager Tests", overlay_manager_tests)
    
    local stats = TestFramework.get_stats()
    TestFramework.cleanup_mock_environment()
    
    return stats
end

function TestOverlayManager.runAllTests()
    return runOverlayManagerTests()
end

function TestOverlayManager.testCreation()
    local overlay = OverlayManager:new()
    
    TestFramework.assert(overlay ~= nil, "OverlayManager should be created")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.NORMAL, "Should start in normal mode")
    TestFramework.assert(overlay.transparency == 1.0, "Should start with full opacity")
    TestFramework.assert(overlay.always_on_top == false, "Should start without always on top")
    TestFramework.assert(overlay.borderless == false, "Should start without borderless")
    TestFramework.assert(overlay.click_through == false, "Should start without click through")
    TestFramework.assert(overlay.hide_from_taskbar == false, "Should start visible in taskbar")
    TestFramework.assert(overlay.is_overlay_active == false, "Should start inactive")
    
    return true
end

function TestOverlayManager.testInitialization()
    local overlay = OverlayManager:new()
    
    -- Mock love.window functions for testing
    local original_getMode = love.window.getMode
    local original_getPosition = love.window.getPosition
    
    love.window.getMode = function()
        return 800, 600, {borderless = false, resizable = true}
    end
    
    love.window.getPosition = function()
        return 100, 100
    end
    
    local success = overlay:initialize()
    
    -- Restore original functions
    love.window.getMode = original_getMode
    love.window.getPosition = original_getPosition
    
    TestFramework.assert(success == true, "Initialization should succeed")
    TestFramework.assert(overlay.original_settings.mode ~= nil, "Should store original mode")
    TestFramework.assert(overlay.original_settings.position ~= nil, "Should store original position")
    
    return true
end

function TestOverlayManager.testOverlayModeSettings()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test setting valid overlay modes
    local success, err = overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    TestFramework.assert(success == true, "Should set overlay mode successfully")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.OVERLAY, "Mode should be updated")
    TestFramework.assert(overlay.is_overlay_active == true, "Should be active in overlay mode")
    
    success, err = overlay:setOverlayMode(OverlayManager.MODES.TRANSPARENT_OVERLAY)
    TestFramework.assert(success == true, "Should set transparent overlay mode")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.TRANSPARENT_OVERLAY, "Mode should be updated")
    
    success, err = overlay:setOverlayMode(OverlayManager.MODES.CLICK_THROUGH)
    TestFramework.assert(success == true, "Should set click-through mode")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.CLICK_THROUGH, "Mode should be updated")
    
    -- Test setting normal mode
    success, err = overlay:setOverlayMode(OverlayManager.MODES.NORMAL)
    TestFramework.assert(success == true, "Should set normal mode")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.NORMAL, "Mode should be updated")
    TestFramework.assert(overlay.is_overlay_active == false, "Should be inactive in normal mode")
    
    -- Test invalid mode
    success, err = overlay:setOverlayMode("invalid_mode")
    TestFramework.assert(success == false, "Should reject invalid mode")
    TestFramework.assert(err ~= nil, "Should provide error message")
    
    return true
end

function TestOverlayManager.testTransparencyControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test setting valid transparency values
    local success = overlay:setTransparency(0.5)
    TestFramework.assert(success == true, "Should set transparency successfully")
    TestFramework.assert(overlay.transparency == 0.5, "Transparency should be updated")
    
    success = overlay:setTransparency(0.0)
    TestFramework.assert(success == true, "Should set minimum transparency")
    TestFramework.assert(overlay.transparency == 0.0, "Should be fully transparent")
    
    success = overlay:setTransparency(1.0)
    TestFramework.assert(success == true, "Should set maximum transparency")
    TestFramework.assert(overlay.transparency == 1.0, "Should be fully opaque")
    
    -- Test clamping of invalid values
    success = overlay:setTransparency(-0.5)
    TestFramework.assert(overlay.transparency == 0.0, "Should clamp negative values to 0")
    
    success = overlay:setTransparency(1.5)
    TestFramework.assert(overlay.transparency == 1.0, "Should clamp values above 1 to 1")
    
    success = overlay:setTransparency(nil)
    TestFramework.assert(overlay.transparency == 1.0, "Should default nil to 1.0")
    
    return true
end

function TestOverlayManager.testAlwaysOnTopControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test enabling always on top
    local success = overlay:setAlwaysOnTop(true)
    TestFramework.assert(success == true, "Should enable always on top")
    TestFramework.assert(overlay.always_on_top == true, "Always on top should be enabled")
    
    -- Test disabling always on top
    success = overlay:setAlwaysOnTop(false)
    TestFramework.assert(success == true, "Should disable always on top")
    TestFramework.assert(overlay.always_on_top == false, "Always on top should be disabled")
    
    return true
end

function TestOverlayManager.testBorderlessControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test enabling borderless
    local success = overlay:setBorderless(true)
    TestFramework.assert(success == true, "Should enable borderless")
    TestFramework.assert(overlay.borderless == true, "Borderless should be enabled")
    
    -- Test disabling borderless
    success = overlay:setBorderless(false)
    TestFramework.assert(success == true, "Should disable borderless")
    TestFramework.assert(overlay.borderless == false, "Borderless should be disabled")
    
    return true
end

function TestOverlayManager.testClickThroughControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test enabling click through
    local success = overlay:setClickThrough(true)
    TestFramework.assert(success == true, "Should enable click through")
    TestFramework.assert(overlay.click_through == true, "Click through should be enabled")
    
    -- Test disabling click through
    success = overlay:setClickThrough(false)
    TestFramework.assert(success == true, "Should disable click through")
    TestFramework.assert(overlay.click_through == false, "Click through should be disabled")
    
    return true
end

function TestOverlayManager.testTaskbarVisibilityControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test hiding from taskbar
    local success = overlay:setTaskbarVisible(false)
    TestFramework.assert(success == true, "Should hide from taskbar")
    TestFramework.assert(overlay.hide_from_taskbar == true, "Should be hidden from taskbar")
    
    -- Test showing in taskbar
    success = overlay:setTaskbarVisible(true)
    TestFramework.assert(success == true, "Should show in taskbar")
    TestFramework.assert(overlay.hide_from_taskbar == false, "Should be visible in taskbar")
    
    return true
end

function TestOverlayManager.testPositionControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test setting position
    local success = overlay:setPosition(200, 150)
    TestFramework.assert(success == true, "Should set position successfully")
    TestFramework.assert(overlay.position.x == 200, "X position should be updated")
    TestFramework.assert(overlay.position.y == 150, "Y position should be updated")
    
    -- Test setting partial position
    success = overlay:setPosition(300, nil)
    TestFramework.assert(overlay.position.x == 300, "X position should be updated")
    TestFramework.assert(overlay.position.y == 150, "Y position should remain unchanged")
    
    success = overlay:setPosition(nil, 250)
    TestFramework.assert(overlay.position.x == 300, "X position should remain unchanged")
    TestFramework.assert(overlay.position.y == 250, "Y position should be updated")
    
    return true
end

function TestOverlayManager.testSizeControl()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test setting size
    local success = overlay:setSize(1024, 768)
    TestFramework.assert(success == true, "Should set size successfully")
    TestFramework.assert(overlay.size.width == 1024, "Width should be updated")
    TestFramework.assert(overlay.size.height == 768, "Height should be updated")
    
    -- Test setting partial size
    success = overlay:setSize(1280, nil)
    TestFramework.assert(overlay.size.width == 1280, "Width should be updated")
    TestFramework.assert(overlay.size.height == 768, "Height should remain unchanged")
    
    success = overlay:setSize(nil, 720)
    TestFramework.assert(overlay.size.width == 1280, "Width should remain unchanged")
    TestFramework.assert(overlay.size.height == 720, "Height should be updated")
    
    return true
end

function TestOverlayManager.testConfigurationRetrieval()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Set some configuration values
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    overlay:setTransparency(0.7)
    overlay:setAlwaysOnTop(true)
    overlay:setBorderless(true)
    overlay:setPosition(150, 200)
    overlay:setSize(900, 700)
    
    local config = overlay:getConfiguration()
    
    TestFramework.assert(config.mode == OverlayManager.MODES.OVERLAY, "Should return correct mode")
    TestFramework.assert(config.transparency == 0.7, "Should return correct transparency")
    TestFramework.assert(config.always_on_top == true, "Should return correct always on top")
    TestFramework.assert(config.borderless == true, "Should return correct borderless")
    TestFramework.assert(config.position.x == 150, "Should return correct X position")
    TestFramework.assert(config.position.y == 200, "Should return correct Y position")
    TestFramework.assert(config.size.width == 900, "Should return correct width")
    TestFramework.assert(config.size.height == 700, "Should return correct height")
    TestFramework.assert(config.is_active == true, "Should return correct active state")
    
    return true
end

function TestOverlayManager.testStateManagement()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test initial state
    local state = overlay:getState()
    TestFramework.assert(state.mode == OverlayManager.MODES.NORMAL, "Should start in normal mode")
    TestFramework.assert(state.is_active == false, "Should start inactive")
    
    -- Test state after activation
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    state = overlay:getState()
    TestFramework.assert(state.mode == OverlayManager.MODES.OVERLAY, "Should be in overlay mode")
    TestFramework.assert(state.is_active == true, "Should be active")
    
    -- Test update function
    overlay:update(0.016)  -- Simulate 60 FPS
    state = overlay:getState()
    TestFramework.assert(state.last_update_time > 0, "Should track update time")
    
    return true
end

function TestOverlayManager.testModeTransitions()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test transition from normal to overlay
    overlay:setOverlayMode(OverlayManager.MODES.NORMAL)
    TestFramework.assert(overlay.is_overlay_active == false, "Should be inactive in normal mode")
    
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    TestFramework.assert(overlay.is_overlay_active == true, "Should be active in overlay mode")
    
    -- Test transition between overlay modes
    overlay:setOverlayMode(OverlayManager.MODES.TRANSPARENT_OVERLAY)
    TestFramework.assert(overlay.is_overlay_active == true, "Should remain active")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.TRANSPARENT_OVERLAY, "Mode should change")
    
    overlay:setOverlayMode(OverlayManager.MODES.CLICK_THROUGH)
    TestFramework.assert(overlay.is_overlay_active == true, "Should remain active")
    TestFramework.assert(overlay.mode == OverlayManager.MODES.CLICK_THROUGH, "Mode should change")
    
    -- Test transition back to normal
    overlay:setOverlayMode(OverlayManager.MODES.NORMAL)
    TestFramework.assert(overlay.is_overlay_active == false, "Should be inactive in normal mode")
    
    return true
end

function TestOverlayManager.testErrorHandling()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Test invalid overlay mode
    local success, err = overlay:setOverlayMode("invalid")
    TestFramework.assert(success == false, "Should reject invalid mode")
    TestFramework.assert(type(err) == "string", "Should provide error message")
    TestFramework.assert(string.find(err:lower(), "invalid"), "Error should mention invalid mode")
    
    -- Test that invalid mode doesn't change current mode
    local original_mode = overlay.mode
    overlay:setOverlayMode("invalid")
    TestFramework.assert(overlay.mode == original_mode, "Mode should not change on error")
    
    return true
end

function TestOverlayManager.testCleanup()
    local overlay = OverlayManager:new()
    overlay:initialize()
    
    -- Set overlay mode and properties
    overlay:setOverlayMode(OverlayManager.MODES.OVERLAY)
    overlay:setTransparency(0.5)
    overlay:setAlwaysOnTop(true)
    
    TestFramework.assert(overlay.is_overlay_active == true, "Should be active before cleanup")
    
    -- Test cleanup
    overlay:cleanup()
    
    TestFramework.assert(overlay.window_handle == nil, "Window handle should be cleared")
    
    return true
end

return TestOverlayManager