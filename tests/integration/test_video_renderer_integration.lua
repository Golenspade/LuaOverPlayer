-- Integration tests for VideoRenderer with frame buffer
local VideoRenderer = require("src.video_renderer")
local FrameBuffer = require("src.frame_buffer")

-- Simple test framework
local TestFramework = {}
TestFramework.tests = {}
TestFramework.passed = 0
TestFramework.failed = 0

function TestFramework:test(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

function TestFramework:assert(condition, message)
    if not condition then
        error(message or "Assertion failed")
    end
end

function TestFramework:assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", 
              message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

function TestFramework:assertNotNil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end

function TestFramework:assertTrue(value, message)
    if not value then
        error(message or "Expected true")
    end
end

function TestFramework:run()
    print("Running VideoRenderer Integration tests...")
    print("=" .. string.rep("=", 50))
    
    for _, test in ipairs(self.tests) do
        local success, error_msg = pcall(test.func)
        if success then
            print("✓ " .. test.name)
            self.passed = self.passed + 1
        else
            print("✗ " .. test.name .. ": " .. error_msg)
            self.failed = self.failed + 1
        end
    end
    
    print(string.rep("=", 60))
    print(string.format("Results: %d passed, %d failed, %d total", 
          self.passed, self.failed, self.passed + self.failed))
    
    if self.failed == 0 then
        print("All integration tests passed! ✓")
        return true
    else
        print("Some integration tests failed! ✗")
        return false
    end
end

-- Mock LÖVE 2D functions for testing
local mock_love = {
    graphics = {
        newImage = function(image_data)
            return {
                type = function() return "Texture" end,
                getWidth = function() return image_data.width or 100 end,
                getHeight = function() return image_data.height or 100 end,
                release = function() end
            }
        end,
        draw = function() end,
        setColor = function() end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end
    },
    image = {
        newImageData = function(width, height, format, data)
            return {
                type = function() return "ImageData" end,
                width = width,
                height = height,
                format = format,
                data = data
            }
        end
    },
    timer = {
        getTime = function() return os.clock() end
    }
}

-- Replace global love with mock for testing
local original_love = _G.love
_G.love = mock_love

local function create_test_frame_data(width, height, pattern)
    pattern = pattern or "checkerboard"
    local data = {}
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if pattern == "checkerboard" then
                if (x + y) % 2 == 0 then
                    table.insert(data, string.char(255, 0, 0, 255))  -- Red
                else
                    table.insert(data, string.char(0, 255, 0, 255))  -- Green
                end
            elseif pattern == "gradient" then
                local intensity = math.floor((x / width) * 255)
                table.insert(data, string.char(intensity, intensity, intensity, 255))
            else -- solid
                table.insert(data, string.char(128, 128, 128, 255))  -- Gray
            end
        end
    end
    return table.concat(data)
end

-- Test VideoRenderer with FrameBuffer integration
TestFramework:test("VideoRenderer with FrameBuffer integration", function()
    local renderer = VideoRenderer:new()
    local buffer = FrameBuffer:new(3)
    
    -- Create test frames
    local frame1 = create_test_frame_data(100, 100, "checkerboard")
    local frame2 = create_test_frame_data(100, 100, "gradient")
    local frame3 = create_test_frame_data(100, 100, "solid")
    
    -- Add frames to buffer
    buffer:addFrame(frame1, 100, 100)
    buffer:addFrame(frame2, 100, 100)
    buffer:addFrame(frame3, 100, 100)
    
    -- Get latest frame and render it
    local latest_frame = buffer:getLatestFrame()
    TestFramework:assertNotNil(latest_frame, "Should get latest frame from buffer")
    
    local success = renderer:updateFrame(latest_frame.data, latest_frame.width, latest_frame.height)
    TestFramework:assertTrue(success, "Should update renderer with frame from buffer")
    
    -- Test rendering
    success = renderer:render(0, 0, 200, 200)
    TestFramework:assertTrue(success, "Should render frame successfully")
    
    -- Verify state
    local state = renderer:getState()
    TestFramework:assertTrue(state.has_texture, "Renderer should have texture")
    TestFramework:assertEqual(state.frame_dimensions.width, 100, "Frame width should match")
    TestFramework:assertEqual(state.frame_dimensions.height, 100, "Frame height should match")
end)

-- Test multiple scaling modes with different aspect ratios
TestFramework:test("Multiple scaling modes with different aspect ratios", function()
    local renderer = VideoRenderer:new()
    
    -- Test with wide frame (16:9)
    local wide_frame = create_test_frame_data(160, 90, "gradient")
    renderer:updateFrame(wide_frame, 160, 90)
    
    -- Test fit mode
    renderer:setDisplayMode('fit')
    local scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(320, 240)
    TestFramework:assertEqual(scale_x, scale_y, "Fit mode should maintain aspect ratio")
    
    -- Test fill mode
    renderer:setDisplayMode('fill')
    scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(320, 240)
    TestFramework:assertEqual(scale_x, scale_y, "Fill mode should maintain aspect ratio")
    
    -- Test stretch mode
    renderer:setDisplayMode('stretch')
    scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(320, 240)
    TestFramework:assertEqual(scale_x, 2.0, "Stretch mode should scale width independently")
    TestFramework:assertEqual(scale_y, 8/3, "Stretch mode should scale height independently")
end)

-- Test performance with multiple frame updates
TestFramework:test("Performance with multiple frame updates", function()
    local renderer = VideoRenderer:new()
    local start_time = os.clock()
    
    -- Update renderer with multiple frames rapidly
    for i = 1, 10 do
        local frame_data = create_test_frame_data(50, 50, "solid")
        local success = renderer:updateFrame(frame_data, 50, 50)
        TestFramework:assertTrue(success, "Frame update " .. i .. " should succeed")
        
        -- Render each frame
        success = renderer:render(0, 0, 100, 100)
        TestFramework:assertTrue(success, "Frame render " .. i .. " should succeed")
    end
    
    local end_time = os.clock()
    local duration = end_time - start_time
    
    -- Should complete reasonably quickly (less than 1 second)
    TestFramework:assert(duration < 1.0, "Multiple frame updates should complete quickly")
    
    -- Check final state
    local state = renderer:getState()
    TestFramework:assertEqual(state.stats.frames_rendered, 10, "Should have rendered 10 frames")
end)

-- Test error recovery scenarios
TestFramework:test("Error recovery scenarios", function()
    local renderer = VideoRenderer:new()
    
    -- Try to render without texture
    local success, err = renderer:render(0, 0, 100, 100)
    TestFramework:assert(not success, "Should fail to render without texture")
    TestFramework:assertNotNil(err, "Should return error message")
    
    -- Add valid frame
    local frame_data = create_test_frame_data(50, 50)
    success = renderer:updateFrame(frame_data, 50, 50)
    TestFramework:assertTrue(success, "Should succeed with valid frame")
    
    -- Now rendering should work
    success = renderer:render(0, 0, 100, 100)
    TestFramework:assertTrue(success, "Should render successfully after adding frame")
    
    -- Test cleanup and recovery
    renderer:cleanup()
    local state = renderer:getState()
    TestFramework:assert(not state.has_texture, "Should not have texture after cleanup")
    
    -- Should be able to add new frame after cleanup
    success = renderer:updateFrame(frame_data, 50, 50)
    TestFramework:assertTrue(success, "Should be able to add frame after cleanup")
end)

-- Test transparency and overlay features
TestFramework:test("Transparency and overlay features", function()
    local renderer = VideoRenderer:new()
    local frame_data = create_test_frame_data(100, 100)
    renderer:updateFrame(frame_data, 100, 100)
    
    -- Test transparency settings
    renderer:setTransparency(0.5)
    TestFramework:assertEqual(renderer.transparency, 0.5, "Should set transparency to 0.5")
    
    -- Test overlay mode
    renderer:setOverlayMode(true)
    TestFramework:assertTrue(renderer.overlay_mode, "Should enable overlay mode")
    
    -- Rendering should still work with transparency and overlay
    local success = renderer:render(0, 0, 200, 200)
    TestFramework:assertTrue(success, "Should render with transparency and overlay")
    
    -- Test state includes overlay and transparency info
    local state = renderer:getState()
    TestFramework:assertTrue(state.overlay_mode, "State should reflect overlay mode")
    TestFramework:assertEqual(state.transparency, 0.5, "State should reflect transparency")
end)

-- Only run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_video_renderer_integration%.lua$") then
    TestFramework:run()
end

-- Restore original love global
_G.love = original_love

-- Return test results for integration with main test runner
return TestFramework.failed == 0