-- Integration tests for UIController with real components
local TestFramework = require("tests.test_framework")

-- Mock LÖVE 2D environment for testing
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
        clear = function(...) end,
        newImage = function(imageData) 
            return {
                getWidth = function() return imageData.width or 100 end,
                getHeight = function() return imageData.height or 100 end,
                release = function() end
            }
        end,
        draw = function(...) end
    },
    timer = {
        getTime = function() return os.clock() end
    },
    image = {
        newImageData = function(width, height, format, data)
            return {
                width = width,
                height = height,
                format = format,
                data = data,
                type = function() return "ImageData" end
            }
        end
    },
    mouse = {
        getPosition = function() return 0, 0 end
    }
}

-- Set up mock environment
_G.love = mock_love

-- Load real components
local CaptureEngine = require("src.capture_engine")
local VideoRenderer = require("src.video_renderer")
local UIController = require("src.ui_controller")

-- Test functions
local function testCaptureEngineIntegration()
    -- Create real capture engine with mock FFI
    local capture_engine = CaptureEngine:new({
        frame_rate = 30,
        buffer_size = 3
    })
    
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    TestFramework.assert_not_nil(ui, "Should create UIController with real CaptureEngine")
    
    local success = ui:initialize()
    TestFramework.assert_true(success, "Should initialize successfully")
    
    -- Test getting available sources
    local sources = ui.available_sources
    TestFramework.assert_not_nil(sources, "Should get available sources")
    TestFramework.assert_not_nil(sources.screen, "Should have screen source")
    TestFramework.assert_not_nil(sources.window, "Should have window source")
end

local function testVideoRendererIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    
    -- Test renderer integration
    TestFramework.assert_equal(ui.renderer, renderer, "Should store renderer reference")
    
    -- Test frame update through UI
    local frame_data = string.rep("\255\255\255\255", 100 * 100) -- White 100x100 RGBA
    local success = renderer:updateFrame(frame_data, 100, 100)
    TestFramework.assert_true(success, "Should update frame through renderer")
    
    local state = renderer:getState()
    TestFramework.assert_true(state.has_texture, "Should have texture after frame update")
end

local function testCompleteCaptureWorkflow()
    local capture_engine = CaptureEngine:new({frame_rate = 30})
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    
    -- Test complete workflow: select source -> start capture -> pause -> resume -> stop
    
    -- 1. Select screen source
    ui:_selectSource("screen")
    TestFramework.assert_equal(ui.selected_source, "screen", "Should select screen source")
    TestFramework.assert_true(ui.buttons.start_capture.enabled, "Should enable start button")
    
    -- 2. Start capture
    ui:_startCapture()
    TestFramework.assert_true(ui.capture_status.is_capturing, "Should start capturing")
    TestFramework.assert_true(capture_engine:getStats().is_capturing, "Engine should be capturing")
    
    -- 3. Pause capture
    ui:_togglePause()
    TestFramework.assert_true(ui.capture_status.is_paused, "Should pause capturing")
    TestFramework.assert_true(capture_engine:isPaused(), "Engine should be paused")
    
    -- 4. Resume capture
    ui:_togglePause()
    TestFramework.assert_false(ui.capture_status.is_paused, "Should resume capturing")
    TestFramework.assert_false(capture_engine:isPaused(), "Engine should be resumed")
    
    -- 5. Stop capture
    ui:_stopCapture()
    TestFramework.assert_false(ui.capture_status.is_capturing, "Should stop capturing")
    TestFramework.assert_false(capture_engine:getStats().is_capturing, "Engine should be stopped")
end

local function testUIUpdateLoopIntegration()
    local capture_engine = CaptureEngine:new({frame_rate = 30})
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    ui:_selectSource("screen")
    ui:_startCapture()
    
    -- Simulate several update cycles
    for i = 1, 10 do
        ui:update(0.016) -- ~60 FPS update rate
    end
    
    -- Check that stats are being updated
    local ui_state = ui:getState()
    TestFramework.assert_true(ui_state.capture_status.elapsed_time > 0, "Should track elapsed time")
    TestFramework.assert_true(ui.update_stats.update_count >= 10, "Should track update count")
end

local function testErrorPropagation()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    
    -- Try to start capture without selecting source
    ui:_startCapture()
    TestFramework.assert_false(ui.capture_status.is_capturing, "Should not start without source")
    TestFramework.assert_not_equal(ui.status_message, "", "Should show error message")
    TestFramework.assert_equal(ui.status_type, "error", "Should be error type message")
end

local function testSourceConfigurationIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    
    -- Test getting source configuration options
    local screen_config = ui.source_configs.screen
    TestFramework.assert_not_nil(screen_config, "Should have screen configuration")
    TestFramework.assert_not_nil(screen_config.options, "Should have configuration options")
    
    -- Test selecting source with configuration
    ui:_selectSource("screen")
    local engine_config = capture_engine:getSourceConfig()
    TestFramework.assert_equal(engine_config.source_type, "screen", "Engine should have correct source type")
end

local function testInputHandlingIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    ui:_selectSource("screen")
    
    -- Test keyboard shortcuts affecting engine state
    local handled = ui:handleInput("space", "pressed")
    TestFramework.assert_true(handled, "Should handle space key")
    TestFramework.assert_true(capture_engine:getStats().is_capturing, "Should start engine capture")
    
    handled = ui:handleInput("s", "pressed")
    TestFramework.assert_true(handled, "Should handle 's' key")
    TestFramework.assert_false(capture_engine:getStats().is_capturing, "Should stop engine capture")
end

local function testButtonClickIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    
    -- Test source selection button click
    local select_button = ui.buttons.select_source
    local clicked = ui:handleMouseInput(
        select_button.x + 10, 
        select_button.y + 10, 
        1, 
        "pressed"
    )
    
    TestFramework.assert_true(clicked, "Should handle button click")
    TestFramework.assert_equal(ui.current_screen, "source_selection", "Should switch to source selection")
    
    -- Test source button click
    local screen_button = ui.buttons.source_screen
    if screen_button then
        clicked = ui:handleMouseInput(
            screen_button.x + 10,
            screen_button.y + 10,
            1,
            "pressed"
        )
        
        TestFramework.assert_true(clicked, "Should handle source button click")
        TestFramework.assert_equal(ui.selected_source, "screen", "Should select screen source")
        TestFramework.assert_equal(capture_engine:getSourceConfig().source_type, "screen", "Should configure engine")
    end
end

local function testStatusDisplayIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    ui:_selectSource("screen")
    ui:_startCapture()
    
    -- Update to get real stats from engine
    ui:update(0.016)
    
    local ui_state = ui:getState()
    local engine_stats = capture_engine:getStats()
    
    TestFramework.assert_equal(ui_state.capture_status.is_capturing, engine_stats.is_capturing, 
               "UI status should match engine status")
    TestFramework.assert_equal(ui_state.capture_status.source_type, engine_stats.source, 
               "UI source should match engine source")
end

local function testResourceCleanupIntegration()
    local capture_engine = CaptureEngine:new()
    local renderer = VideoRenderer:new()
    local ui = UIController:new(capture_engine, renderer)
    
    ui:initialize()
    ui:_selectSource("screen")
    ui:_startCapture()
    
    -- Test cleanup while capturing
    ui:cleanup()
    
    -- UI should be cleaned up
    TestFramework.assert_nil(next(ui.fonts), "Should clear UI fonts")
    TestFramework.assert_nil(next(ui.buttons), "Should clear UI buttons")
    
    -- Renderer should still be functional
    local renderer_state = renderer:getState()
    TestFramework.assert_not_nil(renderer_state, "Renderer should still be accessible")
end

-- Test suite definition
local ui_controller_integration_tests = {
    testCaptureEngineIntegration = testCaptureEngineIntegration,
    testVideoRendererIntegration = testVideoRendererIntegration,
    testCompleteCaptureWorkflow = testCompleteCaptureWorkflow,
    testUIUpdateLoopIntegration = testUIUpdateLoopIntegration,
    testErrorPropagation = testErrorPropagation,
    testSourceConfigurationIntegration = testSourceConfigurationIntegration,
    testInputHandlingIntegration = testInputHandlingIntegration,
    testButtonClickIntegration = testButtonClickIntegration,
    testStatusDisplayIntegration = testStatusDisplayIntegration,
    testResourceCleanupIntegration = testResourceCleanupIntegration
}

-- Run tests function
local function runUIControllerIntegrationTests()
    TestFramework.setup_mock_environment()
    TestFramework.run_suite("UIController Integration Tests", ui_controller_integration_tests)
    TestFramework.cleanup_mock_environment()
    
    local stats = TestFramework.get_stats()
    return {
        passed = stats.passed,
        total = stats.total,
        failures = {} -- TestFramework doesn't provide detailed failure info
    }
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_ui_controller_integration%.lua$") then
    local results = runUIControllerIntegrationTests()
    
    print("\n" .. string.rep("=", 50))
    print("UI CONTROLLER INTEGRATION TEST RESULTS")
    print(string.rep("=", 50))
    
    if results.passed == results.total then
        print("✅ All integration tests passed! (" .. results.passed .. "/" .. results.total .. ")")
    else
        print("❌ Some integration tests failed. (" .. results.passed .. "/" .. results.total .. ")")
    end
    
    print(string.rep("=", 50))
end

return {
    runUIControllerIntegrationTests = runUIControllerIntegrationTests
}