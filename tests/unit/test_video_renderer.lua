-- Unit tests for VideoRenderer class
local VideoRenderer = require("src.video_renderer")

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

function TestFramework:assertNil(value, message)
    if value ~= nil then
        error(message or "Expected nil value")
    end
end

function TestFramework:assertTrue(value, message)
    if not value then
        error(message or "Expected true")
    end
end

function TestFramework:assertFalse(value, message)
    if value then
        error(message or "Expected false")
    end
end

function TestFramework:run()
    print("Running VideoRenderer tests...")
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
        print("All tests passed! ✓")
        return true
    else
        print("Some tests failed! ✗")
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

local function create_test_frame_data(width, height)
    -- Create simple test pattern (alternating pixels)
    local data = {}
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if (x + y) % 2 == 0 then
                table.insert(data, string.char(255, 0, 0, 255))  -- Red pixel
            else
                table.insert(data, string.char(0, 255, 0, 255))  -- Green pixel
            end
        end
    end
    return table.concat(data)
end

local function create_test_image_data(width, height)
    local image_data = mock_love.image.newImageData(width, height, "rgba8", create_test_frame_data(width, height))
    -- Add proper type method for ImageData detection
    image_data.type = function(self) return "ImageData" end
    return image_data
end

-- Test VideoRenderer creation
TestFramework:test("VideoRenderer creation", function()
    local renderer = VideoRenderer:new()
    
    TestFramework:assertNotNil(renderer, "Renderer should be created")
    TestFramework:assertEqual(renderer.display_mode, 'fit', "Default display mode should be 'fit'")
    TestFramework:assertEqual(renderer.overlay_mode, false, "Default overlay mode should be false")
    TestFramework:assertEqual(renderer.transparency, 1.0, "Default transparency should be 1.0")
    TestFramework:assertNil(renderer.current_texture, "Initial texture should be nil")
end)

-- Test frame update with string data
TestFramework:test("VideoRenderer updateFrame with string data", function()
    local renderer = VideoRenderer:new()
    local frame_data = create_test_frame_data(100, 100)
    
    local success, err = renderer:updateFrame(frame_data, 100, 100)
    
    TestFramework:assertTrue(success, "Frame update should succeed: " .. tostring(err))
    TestFramework:assertNotNil(renderer.current_texture, "Texture should be created")
    TestFramework:assertEqual(renderer.last_frame_width, 100, "Frame width should be stored")
    TestFramework:assertEqual(renderer.last_frame_height, 100, "Frame height should be stored")
end)

-- Test frame update with ImageData
TestFramework:test("VideoRenderer updateFrame with ImageData", function()
    local renderer = VideoRenderer:new()
    local image_data = create_test_image_data(50, 50)
    
    local success, err = renderer:updateFrame(image_data, 50, 50)
    
    TestFramework:assertTrue(success, "Frame update should succeed: " .. tostring(err))
    TestFramework:assertNotNil(renderer.current_texture, "Texture should be created")
    TestFramework:assertEqual(renderer.last_frame_width, 50, "Frame width should be stored")
    TestFramework:assertEqual(renderer.last_frame_height, 50, "Frame height should be stored")
end)

-- Test invalid frame data
TestFramework:test("VideoRenderer updateFrame with invalid data", function()
    local renderer = VideoRenderer:new()
    
    -- Test nil data
    local success, err = renderer:updateFrame(nil, 100, 100)
    TestFramework:assertFalse(success, "Should fail with nil data")
    TestFramework:assertNotNil(err, "Should return error message")
    
    -- Test invalid dimensions
    success, err = renderer:updateFrame("data", 0, 100)
    TestFramework:assertFalse(success, "Should fail with zero width")
    
    success, err = renderer:updateFrame("data", 100, -1)
    TestFramework:assertFalse(success, "Should fail with negative height")
end)

-- Test display mode setting
TestFramework:test("VideoRenderer setDisplayMode", function()
    local renderer = VideoRenderer:new()
    
    -- Test valid modes
    local success = renderer:setDisplayMode('fill')
    TestFramework:assertTrue(success, "Should accept 'fill' mode")
    TestFramework:assertEqual(renderer.display_mode, 'fill', "Display mode should be updated")
    
    success = renderer:setDisplayMode('stretch')
    TestFramework:assertTrue(success, "Should accept 'stretch' mode")
    TestFramework:assertEqual(renderer.display_mode, 'stretch', "Display mode should be updated")
    
    success = renderer:setDisplayMode('fit')
    TestFramework:assertTrue(success, "Should accept 'fit' mode")
    TestFramework:assertEqual(renderer.display_mode, 'fit', "Display mode should be updated")
    
    -- Test invalid mode
    success = renderer:setDisplayMode('invalid')
    TestFramework:assertFalse(success, "Should reject invalid mode")
    TestFramework:assertEqual(renderer.display_mode, 'fit', "Display mode should remain unchanged")
end)

-- Test scaling calculations
TestFramework:test("VideoRenderer scaling calculations", function()
    local renderer = VideoRenderer:new()
    local frame_data = create_test_frame_data(200, 100) -- 2:1 aspect ratio
    renderer:updateFrame(frame_data, 200, 100)
    
    -- Test 'fit' mode - should maintain aspect ratio and fit within bounds
    renderer:setDisplayMode('fit')
    local scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(400, 400)
    TestFramework:assertEqual(scale_x, scale_y, "Fit mode should maintain aspect ratio")
    TestFramework:assertEqual(scale_x, 2.0, "Should scale to fit width")
    TestFramework:assertEqual(offset_y, 100, "Should center vertically") -- (400 - 100*2) / 2 = 100
    
    -- Test 'fill' mode - should maintain aspect ratio and fill bounds
    renderer:setDisplayMode('fill')
    scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(400, 400)
    TestFramework:assertEqual(scale_x, scale_y, "Fill mode should maintain aspect ratio")
    TestFramework:assertEqual(scale_y, 4.0, "Should scale to fill height")
    TestFramework:assertEqual(offset_x, -200, "Should center horizontally (with cropping)")
    
    -- Test 'stretch' mode - should fill bounds exactly
    renderer:setDisplayMode('stretch')
    scale_x, scale_y, offset_x, offset_y = renderer:_calculateScaling(400, 400)
    TestFramework:assertEqual(scale_x, 2.0, "Should stretch to target width")
    TestFramework:assertEqual(scale_y, 4.0, "Should stretch to target height")
    TestFramework:assertEqual(offset_x, 0, "No horizontal offset in stretch mode")
    TestFramework:assertEqual(offset_y, 0, "No vertical offset in stretch mode")
end)

-- Test overlay mode
TestFramework:test("VideoRenderer overlay mode", function()
    local renderer = VideoRenderer:new()
    
    local success = renderer:setOverlayMode(true)
    TestFramework:assertTrue(success, "Should enable overlay mode")
    TestFramework:assertTrue(renderer.overlay_mode, "Overlay mode should be enabled")
    
    success = renderer:setOverlayMode(false)
    TestFramework:assertTrue(success, "Should disable overlay mode")
    TestFramework:assertFalse(renderer.overlay_mode, "Overlay mode should be disabled")
end)

-- Test transparency
TestFramework:test("VideoRenderer transparency", function()
    local renderer = VideoRenderer:new()
    
    local success = renderer:setTransparency(0.5)
    TestFramework:assertTrue(success, "Should set transparency")
    TestFramework:assertEqual(renderer.transparency, 0.5, "Transparency should be set")
    
    -- Test clamping
    renderer:setTransparency(-0.5)
    TestFramework:assertEqual(renderer.transparency, 0.0, "Should clamp to 0.0")
    
    renderer:setTransparency(1.5)
    TestFramework:assertEqual(renderer.transparency, 1.0, "Should clamp to 1.0")
end)

-- Test render function
TestFramework:test("VideoRenderer render", function()
    local renderer = VideoRenderer:new()
    
    -- Test render without texture
    local success, err = renderer:render(0, 0, 100, 100)
    TestFramework:assertFalse(success, "Should fail without texture")
    TestFramework:assertNotNil(err, "Should return error message")
    
    -- Test render with texture
    local frame_data = create_test_frame_data(50, 50)
    renderer:updateFrame(frame_data, 50, 50)
    
    success = renderer:render(10, 20, 200, 200)
    TestFramework:assertTrue(success, "Should render successfully with texture")
    
    -- Test render with default parameters
    success = renderer:render()
    TestFramework:assertTrue(success, "Should render with default parameters")
end)

-- Test state retrieval
TestFramework:test("VideoRenderer getState", function()
    local renderer = VideoRenderer:new()
    
    local state = renderer:getState()
    TestFramework:assertNotNil(state, "Should return state object")
    TestFramework:assertFalse(state.has_texture, "Should indicate no texture initially")
    TestFramework:assertEqual(state.display_mode, 'fit', "Should return current display mode")
    TestFramework:assertNotNil(state.frame_dimensions, "Should include frame dimensions")
    TestFramework:assertNotNil(state.stats, "Should include stats")
    
    -- Add texture and check state
    local frame_data = create_test_frame_data(100, 200)
    renderer:updateFrame(frame_data, 100, 200)
    
    state = renderer:getState()
    TestFramework:assertTrue(state.has_texture, "Should indicate texture present")
    TestFramework:assertEqual(state.frame_dimensions.width, 100, "Should return frame width")
    TestFramework:assertEqual(state.frame_dimensions.height, 200, "Should return frame height")
end)

-- Test cleanup
TestFramework:test("VideoRenderer cleanup", function()
    local renderer = VideoRenderer:new()
    local frame_data = create_test_frame_data(50, 50)
    renderer:updateFrame(frame_data, 50, 50)
    
    TestFramework:assertNotNil(renderer.current_texture, "Should have texture before cleanup")
    
    renderer:cleanup()
    
    TestFramework:assertNil(renderer.current_texture, "Should clear texture after cleanup")
    TestFramework:assertEqual(renderer.last_frame_width, 0, "Should reset frame width")
    TestFramework:assertEqual(renderer.last_frame_height, 0, "Should reset frame height")
    TestFramework:assertEqual(renderer.render_stats.frames_rendered, 0, "Should reset stats")
end)

-- Only run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_video_renderer%.lua$") then
    TestFramework:run()
end

-- Restore original love global
_G.love = original_love

-- Return test results for integration with main test runner
return TestFramework.failed == 0