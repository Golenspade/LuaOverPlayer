-- End-to-end integration tests for main application loop
-- Tests complete workflows and component integration

local TestFramework = require("tests.test_framework")

-- Mock LÖVE 2D environment for testing
local MockLove = {
    timer = {
        getTime = function() return os.clock() end
    },
    window = {
        setTitle = function(title) return true end,
        setMode = function(w, h, flags) return true end,
        getMode = function() return 800, 600, {borderless = false} end,
        setPosition = function(x, y) return true end,
        getPosition = function() return 100, 100 end,
        getFullscreen = function() return false end,
        setFullscreen = function(fs) return true end
    },
    graphics = {
        clear = function() end,
        setColor = function() end,
        print = function() end,
        rectangle = function() end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        newFont = function(size) 
            return {
                getHeight = function() return size or 12 end,
                getWidth = function(text) return (text and #text or 0) * (size or 12) * 0.6 end
            }
        end,
        setFont = function() end,
        getFont = function() 
            return {
                getHeight = function() return 12 end,
                getWidth = function(text) return (text and #text or 0) * 7 end
            }
        end,
        newImage = function(data)
            return {
                getWidth = function() return 100 end,
                getHeight = function() return 100 end
            }
        end
    },
    image = {
        newImageData = function(w, h, format, data)
            return {
                type = function() return "ImageData" end,
                getWidth = function() return w end,
                getHeight = function() return h end,
                getData = function() return data end
            }
        end
    },
    mouse = {
        getPosition = function() return 400, 300 end
    },
    keyboard = {
        isDown = function() return false end
    },
    event = {
        quit = function() end
    }
}

-- Set up mock environment
_G.love = MockLove
_G.TESTING_MODE = true

-- Test suite for main application integration
local MainIntegrationTests = {}

function MainIntegrationTests.testApplicationInitialization()
    print("Testing application initialization...")
    
    -- Load main.lua in test environment
    local main_chunk = loadfile("main.lua")
    if not main_chunk then
        error("Failed to load main.lua")
    end
    
    -- Execute main.lua to set up the app
    local success, err = pcall(main_chunk)
    if not success then
        error("Failed to execute main.lua: " .. tostring(err))
    end
    
    -- Test love.load function
    local load_success, load_err = pcall(love.load)
    TestFramework.assert(load_success, "love.load should execute without error: " .. tostring(load_err))
    
    -- Verify app global exists and is initialized
    TestFramework.assert(_G.app ~= nil, "Global app object should exist")
    TestFramework.assert(_G.app.initialized == true, "App should be initialized")
    
    -- Verify all core components are created
    TestFramework.assert(_G.app.capture_engine ~= nil, "Capture engine should be initialized")
    TestFramework.assert(_G.app.video_renderer ~= nil, "Video renderer should be initialized")
    TestFramework.assert(_G.app.ui_controller ~= nil, "UI controller should be initialized")
    TestFramework.assert(_G.app.error_handler ~= nil, "Error handler should be initialized")
    TestFramework.assert(_G.app.config_manager ~= nil, "Config manager should be initialized")
    TestFramework.assert(_G.app.performance_monitor ~= nil, "Performance monitor should be initialized")
    TestFramework.assert(_G.app.overlay_manager ~= nil, "Overlay manager should be initialized")
    
    print("✓ Application initialization test passed")
end

function MainIntegrationTests.testUpdateLoop()
    print("Testing update loop...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    local initial_frame_count = _G.app.frame_count
    
    -- Test multiple update cycles
    for i = 1, 10 do
        local success, err = pcall(love.update, 1/60)  -- 60 FPS delta time
        TestFramework.assert(success, "love.update should execute without error: " .. tostring(err))
    end
    
    -- Verify frame count increased
    TestFramework.assert(_G.app.frame_count > initial_frame_count, "Frame count should increase")
    
    -- Verify last update time is recent
    local current_time = love.timer.getTime()
    TestFramework.assert(current_time - _G.app.last_update_time < 1.0, "Last update time should be recent")
    
    print("✓ Update loop test passed")
end

function MainIntegrationTests.testDrawLoop()
    print("Testing draw loop...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test draw function
    local success, err = pcall(love.draw)
    TestFramework.assert(success, "love.draw should execute without error: " .. tostring(err))
    
    print("✓ Draw loop test passed")
end

function MainIntegrationTests.testInputHandling()
    print("Testing input handling...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test keyboard input
    local success, err = pcall(love.keypressed, "space")
    TestFramework.assert(success, "Keyboard input should be handled without error: " .. tostring(err))
    
    -- Test mouse input
    success, err = pcall(love.mousepressed, 100, 100, 1, false, 1)
    TestFramework.assert(success, "Mouse press should be handled without error: " .. tostring(err))
    
    success, err = pcall(love.mousereleased, 100, 100, 1, false, 1)
    TestFramework.assert(success, "Mouse release should be handled without error: " .. tostring(err))
    
    print("✓ Input handling test passed")
end

function MainIntegrationTests.testErrorRecovery()
    print("Testing error recovery...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test error handling - directly test the recovery mechanism
    local initial_recovery_attempts = _G.app.recovery_attempts
    
    -- Reset last recovery time to allow immediate recovery
    _G.app.last_recovery_time = 0
    
    -- Directly call attemptRecovery to test the mechanism
    local recovery_success = _G.app:attemptRecovery("test_recovery")
    
    -- Verify recovery was attempted
    TestFramework.assert(_G.app.recovery_attempts > initial_recovery_attempts, 
                        "Recovery should be attempted (initial: " .. 
                        initial_recovery_attempts .. ", current: " .. _G.app.recovery_attempts .. 
                        ", success: " .. tostring(recovery_success) .. ")")
    
    print("✓ Error recovery test passed")
end

function MainIntegrationTests.testConfigurationIntegration()
    print("Testing configuration integration...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test configuration access
    local config = _G.app.config_manager:getAll()
    TestFramework.assert(config ~= nil, "Configuration should be accessible")
    TestFramework.assert(config.app ~= nil, "App configuration should exist")
    TestFramework.assert(config.capture ~= nil, "Capture configuration should exist")
    
    -- Test configuration change
    local old_fps = _G.app.config_manager:get("performance.target_fps") or 30
    _G.app.config_manager:set("performance.target_fps", 60)
    local new_fps = _G.app.config_manager:get("performance.target_fps")
    TestFramework.assert(new_fps == 60, "Configuration should be updated")
    
    -- Restore original value
    _G.app.config_manager:set("performance.target_fps", old_fps)
    
    print("✓ Configuration integration test passed")
end

function MainIntegrationTests.testPerformanceMonitoring()
    print("Testing performance monitoring integration...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Run several update cycles to generate performance data
    for i = 1, 30 do
        love.update(1/30)  -- 30 FPS
    end
    
    -- Get performance metrics
    local metrics = _G.app.performance_monitor:getMetrics()
    TestFramework.assert(metrics ~= nil, "Performance metrics should be available")
    TestFramework.assert(metrics.frames_processed > 0, "Frames should be processed")
    TestFramework.assert(metrics.current_fps > 0, "FPS should be calculated")
    
    -- Test performance summary
    local summary = _G.app.performance_monitor:getPerformanceSummary()
    TestFramework.assert(summary ~= nil, "Performance summary should be available")
    TestFramework.assert(summary.fps ~= nil, "FPS should be in summary")
    
    print("✓ Performance monitoring integration test passed")
end

function MainIntegrationTests.testCaptureEngineIntegration()
    print("Testing capture engine integration...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test capture engine access through UI controller
    local capture_stats = _G.app.capture_engine:getStats()
    TestFramework.assert(capture_stats ~= nil, "Capture stats should be available")
    
    -- Test source configuration
    local success, err = _G.app.capture_engine:setSource("screen", {})
    TestFramework.assert(success, "Should be able to set capture source: " .. tostring(err))
    
    print("✓ Capture engine integration test passed")
end

function MainIntegrationTests.testVideoRendererIntegration()
    print("Testing video renderer integration...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test renderer configuration
    local success, err = _G.app.video_renderer:setScalingMode("fit")
    TestFramework.assert(success, "Should be able to set scaling mode: " .. tostring(err))
    
    -- Test renderer state
    local state = _G.app.video_renderer:getState()
    TestFramework.assert(state ~= nil, "Renderer state should be available")
    
    print("✓ Video renderer integration test passed")
end

function MainIntegrationTests.testOverlayManagerIntegration()
    print("Testing overlay manager integration...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test overlay configuration
    local success, err = _G.app.overlay_manager:setTransparency(0.8)
    TestFramework.assert(success, "Should be able to set transparency: " .. tostring(err))
    
    -- Test overlay state
    local state = _G.app.overlay_manager:getState()
    TestFramework.assert(state ~= nil, "Overlay state should be available")
    TestFramework.assert(state.transparency == 0.8, "Transparency should be set correctly")
    
    print("✓ Overlay manager integration test passed")
end

function MainIntegrationTests.testApplicationShutdown()
    print("Testing application shutdown...")
    
    -- Ensure app is initialized
    if not _G.app or not _G.app.initialized then
        MainIntegrationTests.testApplicationInitialization()
    end
    
    -- Test controlled shutdown
    local success, err = pcall(_G.app.initiateShutdown, _G.app)
    TestFramework.assert(success, "Shutdown should execute without error: " .. tostring(err))
    
    -- Verify shutdown state
    TestFramework.assert(_G.app.shutdown_requested == true, "Shutdown should be requested")
    
    print("✓ Application shutdown test passed")
end

function MainIntegrationTests.testCompleteWorkflow()
    print("Testing complete application workflow...")
    
    -- Reset global state
    _G.app = nil
    
    -- Test complete workflow from start to finish
    local main_chunk = loadfile("main.lua")
    TestFramework.assert(main_chunk ~= nil, "Should be able to load main.lua")
    
    -- Execute main.lua
    local success, err = pcall(main_chunk)
    TestFramework.assert(success, "Should execute main.lua: " .. tostring(err))
    
    -- Initialize application
    success, err = pcall(love.load)
    TestFramework.assert(success, "Should initialize application: " .. tostring(err))
    
    -- Run application for several frames
    for i = 1, 60 do  -- 1 second at 60 FPS
        success, err = pcall(love.update, 1/60)
        TestFramework.assert(success, "Update cycle " .. i .. " should succeed: " .. tostring(err))
        
        success, err = pcall(love.draw)
        TestFramework.assert(success, "Draw cycle " .. i .. " should succeed: " .. tostring(err))
    end
    
    -- Test some user interactions
    success, err = pcall(love.keypressed, "f1")  -- Help key
    TestFramework.assert(success, "Should handle F1 key: " .. tostring(err))
    
    success, err = pcall(love.mousepressed, 200, 200, 1, false, 1)
    TestFramework.assert(success, "Should handle mouse click: " .. tostring(err))
    
    -- Test configuration change during runtime
    _G.app.config_manager:set("performance.target_fps", 45)
    
    -- Run a few more frames to test configuration change
    for i = 1, 10 do
        love.update(1/45)  -- New frame rate
    end
    
    -- Verify application stats
    local stats = _G.app:getApplicationStats()
    TestFramework.assert(stats.initialized == true, "Application should be initialized")
    TestFramework.assert(stats.frame_count > 60, "Should have processed frames")
    TestFramework.assert(stats.uptime > 0, "Should have uptime")
    
    -- Test shutdown
    success, err = pcall(love.quit)
    TestFramework.assert(success, "Should shutdown cleanly: " .. tostring(err))
    
    print("✓ Complete workflow test passed")
end

-- Run all integration tests
function MainIntegrationTests.runAllTests()
    print("=== Running Main Application Integration Tests ===")
    
    local tests = {
        MainIntegrationTests.testApplicationInitialization,
        MainIntegrationTests.testUpdateLoop,
        MainIntegrationTests.testDrawLoop,
        MainIntegrationTests.testInputHandling,
        MainIntegrationTests.testErrorRecovery,
        MainIntegrationTests.testConfigurationIntegration,
        MainIntegrationTests.testPerformanceMonitoring,
        MainIntegrationTests.testCaptureEngineIntegration,
        MainIntegrationTests.testVideoRendererIntegration,
        MainIntegrationTests.testOverlayManagerIntegration,
        MainIntegrationTests.testApplicationShutdown,
        MainIntegrationTests.testCompleteWorkflow
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ Test failed: " .. tostring(err))
        end
    end
    
    print("=== Integration Test Results ===")
    print("Passed: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))
    
    if failed == 0 then
        print("🎉 All integration tests passed!")
    else
        print("❌ Some integration tests failed")
    end
    
    return failed == 0
end

return MainIntegrationTests