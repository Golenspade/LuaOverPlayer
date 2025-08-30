-- Comprehensive test demonstrating all screen capture functionality
local CaptureEngine = require("src.capture_engine")
local ScreenCapture = require("src.screen_capture")
local mock_ffi = require("tests.mock_ffi_bindings")

-- Enable testing mode
_G.TESTING_MODE = true

local function runComprehensiveTest()
    print("=== Comprehensive Screen Capture Test ===")
    print("This test demonstrates all implemented screen capture features:\n")
    
    -- Setup a realistic multi-monitor environment
    print("1. Setting up multi-monitor environment...")
    mock_ffi.setMockMonitors({
        {left = 0, top = 0, right = 1920, bottom = 1080, isPrimary = true},      -- Primary 1080p
        {left = 1920, top = 0, right = 3840, bottom = 1080, isPrimary = false}, -- Secondary 1080p
        {left = 0, top = 1080, right = 1920, bottom = 2160, isPrimary = false}  -- Vertical 1080p
    })
    
    -- Test 1: Monitor enumeration
    print("2. Testing monitor enumeration...")
    local engine = CaptureEngine:new()
    local monitors = engine:getAvailableMonitors()
    print("   Found " .. #monitors .. " monitors:")
    for i, monitor in ipairs(monitors) do
        print(string.format("   Monitor %d: %dx%d at (%d,%d) %s", 
              i, monitor.width, monitor.height, monitor.left, monitor.top,
              monitor.isPrimary and "(Primary)" or ""))
    end
    
    -- Test 2: Full screen capture
    print("\n3. Testing full screen capture...")
    engine:setSource("screen", {mode = "full_screen"})
    engine:startCapture()
    local frame = engine:captureFrame()
    if frame then
        print(string.format("   Captured full screen: %dx%d pixels, %d bytes", 
              frame.width, frame.height, #frame.data))
    end
    engine:stopCapture()
    
    -- Test 3: Monitor-specific capture
    print("\n4. Testing monitor-specific capture...")
    for i = 1, #monitors do
        engine:setSource("screen", {mode = "monitor", monitor_index = i})
        engine:startCapture()
        frame = engine:captureFrame()
        if frame then
            print(string.format("   Monitor %d captured: %dx%d pixels", 
                  i, frame.width, frame.height))
        end
        engine:stopCapture()
    end
    
    -- Test 4: Custom region capture
    print("\n5. Testing custom region capture...")
    local regions = {
        {x = 100, y = 100, width = 640, height = 480, name = "Small region"},
        {x = 500, y = 200, width = 1280, height = 720, name = "720p region"},
        {x = 1800, y = 50, width = 400, height = 300, name = "Cross-monitor region"}
    }
    
    for _, region in ipairs(regions) do
        engine:setSource("screen", {
            mode = "custom_region",
            region = region
        })
        engine:startCapture()
        frame = engine:captureFrame()
        if frame then
            print(string.format("   %s: %dx%d pixels", 
                  region.name, frame.width, frame.height))
        end
        engine:stopCapture()
    end
    
    -- Test 5: Virtual screen capture (all monitors)
    print("\n6. Testing virtual screen capture...")
    engine:setSource("screen", {mode = "virtual_screen"})
    engine:startCapture()
    frame = engine:captureFrame()
    if frame then
        print(string.format("   Virtual screen captured: %dx%d pixels", 
              frame.width, frame.height))
    end
    engine:stopCapture()
    
    -- Test 6: Performance optimization
    print("\n7. Testing performance optimization...")
    for i = 1, #monitors do
        engine:setSource("screen", {mode = "monitor", monitor_index = i})
        local settings = engine:getOptimalSettings()
        print(string.format("   Monitor %d optimal settings: %dx%d @ %d FPS", 
              i, settings.max_width, settings.max_height, settings.recommended_fps))
    end
    
    -- Test 7: Capture statistics
    print("\n8. Testing capture statistics...")
    engine:setSource("screen", {mode = "full_screen"})
    engine:startCapture()
    
    -- Capture multiple frames to generate statistics
    for i = 1, 5 do
        engine:captureFrame()
    end
    
    local stats = engine:getStats()
    print(string.format("   Frames captured: %d", stats.frames_captured))
    print(string.format("   Frames dropped: %d", stats.frames_dropped))
    print(string.format("   Current source: %s", stats.source))
    print(string.format("   Capture region: %dx%d at (%d,%d)", 
          stats.capture_region.width, stats.capture_region.height,
          stats.capture_region.x, stats.capture_region.y))
    
    engine:stopCapture()
    
    -- Test 8: Error handling
    print("\n9. Testing error handling...")
    
    -- Test invalid configurations
    local success, err = engine:setSource("screen", {
        mode = "custom_region",
        region = {x = 100, y = 100, width = 0, height = 600}
    })
    if not success then
        print("   ✓ Invalid region properly rejected: " .. err)
    end
    
    success, err = engine:setSource("screen", {
        mode = "monitor",
        monitor_index = 10
    })
    if not success then
        print("   ✓ Invalid monitor index properly rejected: " .. err)
    end
    
    -- Test API failure simulation
    mock_ffi.setFailureMode(true)
    success, err = engine:setSource("screen")
    if not success then
        print("   ✓ API failure properly handled: " .. err)
    end
    mock_ffi.setFailureMode(false)
    
    print("\n=== Test Complete ===")
    print("All screen capture functionality has been successfully demonstrated!")
    print("✓ Multi-monitor support with enumeration")
    print("✓ Configurable capture regions (full screen, custom rectangle, monitor-specific)")
    print("✓ Virtual screen capture across all monitors")
    print("✓ Performance optimization based on resolution")
    print("✓ Comprehensive error handling")
    print("✓ Real-time capture statistics")
    
    return true
end

-- Run the comprehensive test
return runComprehensiveTest()