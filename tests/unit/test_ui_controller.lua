-- Test suite for UIController
local TestFramework = require("tests.test_framework")

-- Mock dependencies
local MockCaptureEngine = {}
MockCaptureEngine.__index = MockCaptureEngine

function MockCaptureEngine:new()
    return setmetatable({
        current_source = nil,
        is_capturing = false,
        is_paused = false,
        available_sources = {
            screen = {
                available = true,
                monitors = {{name = "Primary", width = 1920, height = 1080}}
            },
            window = {
                available = true,
                windows = {{title = "Test Window", handle = 123}}
            },
            webcam = {
                available = true,
                devices = {{name = "Test Camera", index = 0}}
            }
        },
        stats = {
            actual_fps = 30.0,
            frames_captured = 100,
            is_capturing = false,
            is_paused = false
        },
        last_frame = nil
    }, self)
end

function MockCaptureEngine:getAvailableSources()
    return self.available_sources
end

function MockCaptureEngine:getSourceConfigurationOptions(source_type)
    if source_type == "screen" then
        return {
            options = {
                {name = "mode", type = "enum", values = {"FULL_SCREEN", "MONITOR"}, default = "FULL_SCREEN"}
            }
        }
    elseif source_type == "window" then
        return {
            options = {
                {name = "window", type = "string", description = "Target window"}
            }
        }
    elseif source_type == "webcam" then
        return {
            options = {
                {name = "device_index", type = "integer", default = 0}
            }
        }
    end
    return {}
end

function MockCaptureEngine:setSource(source_type, config)
    self.current_source = source_type
    return true
end

function MockCaptureEngine:startCapture()
    if not self.current_source then
        return false, "No source selected"
    end
    self.is_capturing = true
    self.stats.is_capturing = true
    return true
end

function MockCaptureEngine:stopCapture()
    self.is_capturing = false
    self.is_paused = false
    self.stats.is_capturing = false
    self.stats.is_paused = false
    return true
end

function MockCaptureEngine:pauseCapture()
    if not self.is_capturing then
        return false, "Not capturing"
    end
    self.is_paused = true
    self.stats.is_paused = true
    return true
end

function MockCaptureEngine:resumeCapture()
    if not self.is_capturing then
        return false, "Not capturing"
    end
    self.is_paused = false
    self.stats.is_paused = false
    return true
end

function MockCaptureEngine:getStats()
    return self.stats
end

function MockCaptureEngine:getFrame()
    return self.last_frame
end

function MockCaptureEngine:update(dt)
    -- Mock update
end

function MockCaptureEngine:getSourceConfig()
    return {
        source_type = self.current_source,
        config = {}
    }
end

function MockCaptureEngine:isPaused()
    return self.is_paused
end

-- Mock VideoRenderer
local MockVideoRenderer = {}
MockVideoRenderer.__index = MockVideoRenderer

function MockVideoRenderer:new()
    return setmetatable({
        current_frame = nil,
        display_mode = 'fit',
        overlay_mode = false,
        transparency = 1.0
    }, self)
end

function MockVideoRenderer:updateFrame(frame_data, width, height)
    self.current_frame = {data = frame_data, width = width, height = height}
    return true
end

function MockVideoRenderer:render(x, y, width, height)
    return true
end

function MockVideoRenderer:setDisplayMode(mode)
    self.display_mode = mode
    return true
end

function MockVideoRenderer:setOverlayMode(enabled)
    self.overlay_mode = enabled
    return true
end

function MockVideoRenderer:setTransparency(alpha)
    self.transparency = alpha
    return true
end

function MockVideoRenderer:getState()
    return {
        has_texture = self.current_frame ~= nil,
        display_mode = self.display_mode,
        overlay_mode = self.overlay_mode,
        transparency = self.transparency
    }
end

function MockVideoRenderer:cleanup()
    self.current_frame = nil
end

-- Mock LÖVE 2D functions
local mock_love = {
    graphics = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        newFont = function(size) 
            return {
                getWidth = function(text) return #text * (size or 12) * 0.6 end,
                getHeight = function() return size or 12 end,
                release = function() end
            }
        end,
        setFont = function(font) end,
        setColor = function(...) end,
        rectangle = function(...) end,
        print = function(...) end,
        clear = function(...) end
    },
    timer = {
        getTime = function() return os.clock() end
    },
    mouse = {
        getPosition = function() return 0, 0 end
    }
}

-- Set up mock environment
_G.love = mock_love

-- Load UIController after setting up mocks
local UIController = require("src.ui_controller")

-- Test functions
local function testUIControllerCreation()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    
    local ui = UIController:new(capture_engine, renderer)
    
    TestFramework.assert_not_nil(ui, "UIController should be created")
    TestFramework.assert_equal(ui.capture_engine, capture_engine, "Should store capture engine reference")
    TestFramework.assert_equal(ui.renderer, renderer, "Should store renderer reference")
    TestFramework.assert_equal(ui.current_screen, "main", "Should start on main screen")
    TestFramework.assert_nil(ui.selected_source, "Should start with no source selected")
end

local function testUIControllerInitialization()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    local success = ui:initialize()
    
    TestFramework.assert_true(success, "Initialization should succeed")
    TestFramework.assert_not_nil(ui.fonts.normal, "Should create normal font")
    TestFramework.assert_not_nil(ui.fonts.large, "Should create large font")
    TestFramework.assert_not_nil(ui.fonts.small, "Should create small font")
    TestFramework.assert_not_nil(ui.buttons.select_source, "Should create select source button")
    TestFramework.assert_not_nil(ui.buttons.start_capture, "Should create start capture button")
    TestFramework.assert_not_nil(ui.buttons.stop_capture, "Should create stop capture button")
    TestFramework.assert_not_nil(ui.buttons.pause_capture, "Should create pause capture button")
end

local function testSourceSelection()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test showing source selection
    ui:_showSourceSelection()
    TestFramework.assert_equal(ui.current_screen, "source_selection", "Should switch to source selection screen")
    TestFramework.assert_not_nil(ui.buttons.back, "Should create back button")
    TestFramework.assert_not_nil(ui.buttons.source_screen, "Should create screen source button")
    TestFramework.assert_not_nil(ui.buttons.source_window, "Should create window source button")
    TestFramework.assert_not_nil(ui.buttons.source_webcam, "Should create webcam source button")
    
    -- Test selecting a source
    ui:_selectSource("screen")
    TestFramework.assert_equal(ui.selected_source, "screen", "Should select screen source")
    TestFramework.assert_equal(ui.current_screen, "main", "Should return to main screen")
    TestFramework.assert_true(ui.buttons.start_capture.enabled, "Should enable start capture button")
end

local function testCaptureControls()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Select a source first
    ui:_selectSource("screen")
    
    -- Test start capture
    ui:_startCapture()
    TestFramework.assert_true(ui.capture_status.is_capturing, "Should start capturing")
    TestFramework.assert_false(ui.buttons.start_capture.enabled, "Should disable start button")
    TestFramework.assert_true(ui.buttons.stop_capture.enabled, "Should enable stop button")
    TestFramework.assert_true(ui.buttons.pause_capture.enabled, "Should enable pause button")
    
    -- Test pause capture
    ui:_togglePause()
    TestFramework.assert_true(ui.capture_status.is_paused, "Should pause capturing")
    TestFramework.assert_equal(ui.buttons.pause_capture.text, "Resume", "Should change button text to Resume")
    
    -- Test resume capture
    ui:_togglePause()
    TestFramework.assert_false(ui.capture_status.is_paused, "Should resume capturing")
    TestFramework.assert_equal(ui.buttons.pause_capture.text, "Pause", "Should change button text to Pause")
    
    -- Test stop capture
    ui:_stopCapture()
    TestFramework.assert_false(ui.capture_status.is_capturing, "Should stop capturing")
    TestFramework.assert_true(ui.buttons.start_capture.enabled, "Should enable start button")
    TestFramework.assert_false(ui.buttons.stop_capture.enabled, "Should disable stop button")
    TestFramework.assert_false(ui.buttons.pause_capture.enabled, "Should disable pause button")
end

local function testInputHandling()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test keyboard input
    local handled = ui:handleInput("escape", "pressed")
    TestFramework.assert_false(handled, "Should not handle escape on main screen")
    
    -- Switch to source selection and test escape
    ui:_showSourceSelection()
    handled = ui:handleInput("escape", "pressed")
    TestFramework.assert_true(handled, "Should handle escape on source selection screen")
    TestFramework.assert_equal(ui.current_screen, "main", "Should return to main screen")
    
    -- Test space bar shortcut
    ui:_selectSource("screen")
    handled = ui:handleInput("space", "pressed")
    TestFramework.assert_true(handled, "Should handle space bar")
    TestFramework.assert_true(ui.capture_status.is_capturing, "Should start capture with space bar")
    
    -- Test 's' key to stop
    handled = ui:handleInput("s", "pressed")
    TestFramework.assert_true(handled, "Should handle 's' key")
    TestFramework.assert_false(ui.capture_status.is_capturing, "Should stop capture with 's' key")
end

local function testMouseInputHandling()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test mouse position tracking
    ui:handleMouseInput(100, 200, 1, "moved")
    TestFramework.assert_equal(ui.mouse.x, 100, "Should track mouse X position")
    TestFramework.assert_equal(ui.mouse.y, 200, "Should track mouse Y position")
    
    -- Test button click detection
    local button = ui.buttons.select_source
    local clicked = ui:handleMouseInput(button.x + 10, button.y + 10, 1, "pressed")
    TestFramework.assert_true(clicked, "Should detect button click")
    TestFramework.assert_equal(ui.current_screen, "source_selection", "Should respond to button click")
end

local function testStatusMessages()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test setting status message
    ui:_setStatusMessage("Test message", "success")
    TestFramework.assert_equal(ui.status_message, "Test message", "Should set status message")
    TestFramework.assert_equal(ui.status_type, "success", "Should set status type")
    TestFramework.assert_true(ui.status_timeout > 0, "Should set status timeout")
    
    -- Test message clearing after timeout
    -- The timeout logic requires status_timeout > 0 AND current_time > status_timeout
    -- So we need to set a positive timeout that's still less than current time
    local current_time = love.timer.getTime()
    ui.status_timeout = 0.001 -- Set to a small positive value that's definitely in the past
    
    ui:update(0.016) -- Simulate frame update
    
    TestFramework.assert_equal(ui.status_message, "", "Should clear expired status message")
end

local function testErrorHandling()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    
    -- Test creation without required parameters
    local success, err = pcall(function()
        UIController:new(nil, renderer)
    end)
    TestFramework.assert_false(success, "Should fail without capture engine")
    
    success, err = pcall(function()
        UIController:new(capture_engine, nil)
    end)
    TestFramework.assert_false(success, "Should fail without renderer")
    
    -- Test capture without source selection
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    ui:_startCapture()
    TestFramework.assert_false(ui.capture_status.is_capturing, "Should not start capture without source")
    TestFramework.assert_not_equal(ui.status_message, "", "Should show error message")
end

local function testUIStateManagement()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test getting UI state
    local state = ui:getState()
    TestFramework.assert_equal(state.current_screen, "main", "Should return current screen")
    TestFramework.assert_nil(state.selected_source, "Should return selected source")
    TestFramework.assert_not_nil(state.capture_status, "Should return capture status")
    TestFramework.assert_not_nil(state.available_sources, "Should return available sources")
    
    -- Test state changes
    ui:_selectSource("webcam")
    state = ui:getState()
    TestFramework.assert_equal(state.selected_source, "webcam", "Should reflect source selection")
end

local function testResourceCleanup()
    local capture_engine = MockCaptureEngine:new()
    local renderer = MockVideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    ui:initialize()
    
    -- Test cleanup
    ui:cleanup()
    TestFramework.assert_nil(next(ui.fonts), "Should clear fonts")
    TestFramework.assert_nil(next(ui.buttons), "Should clear buttons")
    TestFramework.assert_nil(next(ui.ui_elements), "Should clear UI elements")
end

-- Test suite definition
local ui_controller_tests = {
    testUIControllerCreation = testUIControllerCreation,
    testUIControllerInitialization = testUIControllerInitialization,
    testSourceSelection = testSourceSelection,
    testCaptureControls = testCaptureControls,
    testInputHandling = testInputHandling,
    testMouseInputHandling = testMouseInputHandling,
    testStatusMessages = testStatusMessages,
    testErrorHandling = testErrorHandling,
    testUIStateManagement = testUIStateManagement,
    testResourceCleanup = testResourceCleanup
}

-- Run tests function
local function runUIControllerTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("UIController Tests", ui_controller_tests)
    TestFramework.cleanup_mock_environment()
    
    local stats = TestFramework.get_stats()
    return {
        passed = stats.passed,
        total = stats.total,
        failures = {} -- TestFramework doesn't provide detailed failure info
    }
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_ui_controller%.lua$") then
    local results = runUIControllerTests()
    
    print("\n" .. string.rep("=", 50))
    print("UI CONTROLLER TEST RESULTS")
    print(string.rep("=", 50))
    
    if results.passed == results.total then
        print("✅ All tests passed! (" .. results.passed .. "/" .. results.total .. ")")
    else
        print("❌ Some tests failed. (" .. results.passed .. "/" .. results.total .. ")")
    end
    
    print(string.rep("=", 50))
end

return {
    runUIControllerTests = runUIControllerTests,
    MockCaptureEngine = MockCaptureEngine,
    MockVideoRenderer = MockVideoRenderer
}