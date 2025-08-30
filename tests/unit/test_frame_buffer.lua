-- Unit tests for FrameBuffer class
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

function TestFramework:assertNil(value, message)
    if value ~= nil then
        error(message or "Expected nil value")
    end
end

function TestFramework:run()
    print("Running FrameBuffer tests...")
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
    
    print("=" .. string.rep("=", 50))
    print(string.format("Results: %d passed, %d failed", self.passed, self.failed))
    return self.failed == 0
end-
- Helper function to create test frame data
local function createTestFrameData(width, height, pattern)
    pattern = pattern or "solid"
    local data = {}
    
    for y = 1, height do
        for x = 1, width do
            if pattern == "solid" then
                table.insert(data, 255) -- R
                table.insert(data, 0)   -- G
                table.insert(data, 0)   -- B
                table.insert(data, 255) -- A
            elseif pattern == "gradient" then
                local intensity = math.floor((x + y) / (width + height) * 255)
                table.insert(data, intensity)
                table.insert(data, intensity)
                table.insert(data, intensity)
                table.insert(data, 255)
            end
        end
    end
    
    return data
end

-- Test: Basic buffer creation
TestFramework:test("Buffer creation with default size", function()
    local buffer = FrameBuffer:new()
    TestFramework:assertEqual(buffer.max_frames, 3, "Default buffer size should be 3")
    TestFramework:assertEqual(buffer.frame_count, 0, "Initial frame count should be 0")
    TestFramework:assertEqual(buffer.current_index, 1, "Initial index should be 1")
end)

-- Test: Buffer creation with custom size
TestFramework:test("Buffer creation with custom size", function()
    local buffer = FrameBuffer:new(5)
    TestFramework:assertEqual(buffer.max_frames, 5, "Custom buffer size should be respected")
    TestFramework:assertEqual(buffer.frame_count, 0, "Initial frame count should be 0")
end)

-- Test: Adding single frame
TestFramework:test("Adding single frame", function()
    local buffer = FrameBuffer:new(3)
    local frame_data = createTestFrameData(10, 10)
    
    local result = buffer:addFrame(frame_data, 10, 10, "RGBA")
    TestFramework:assert(result, "addFrame should return true on success")
    TestFramework:assertEqual(buffer.frame_count, 1, "Frame count should be 1")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 400, "Memory usage should be 10*10*4 = 400 bytes")
end)

-- Test: Getting latest frame
TestFramework:test("Getting latest frame", function()
    local buffer = FrameBuffer:new(3)
    local frame_data = createTestFrameData(5, 5)
    
    -- Empty buffer should return nil
    TestFramework:assertNil(buffer:getLatestFrame(), "Empty buffer should return nil")
    
    -- Add frame and retrieve it
    buffer:addFrame(frame_data, 5, 5, "RGBA", {source = "test"})
    local latest = buffer:getLatestFrame()
    
    TestFramework:assertNotNil(latest, "Latest frame should not be nil")
    TestFramework:assertEqual(latest.width, 5, "Frame width should match")
    TestFramework:assertEqual(latest.height, 5, "Frame height should match")
    TestFramework:assertEqual(latest.format, "RGBA", "Frame format should match")
    TestFramework:assertEqual(latest.source_info.source, "test", "Source info should match")
    TestFramework:assertNotNil(latest.timestamp, "Frame should have timestamp")
end)-- He
lper function to create test frame data
local function createTestFrameData(width, height, pattern)
    pattern = pattern or "solid"
    local data = {}
    
    for y = 1, height do
        for x = 1, width do
            if pattern == "solid" then
                table.insert(data, 255) -- R
                table.insert(data, 0)   -- G
                table.insert(data, 0)   -- B
                table.insert(data, 255) -- A
            elseif pattern == "gradient" then
                local intensity = math.floor((x + y) / (width + height) * 255)
                table.insert(data, intensity)
                table.insert(data, intensity)
                table.insert(data, intensity)
                table.insert(data, 255)
            end
        end
    end
    
    return data
end

-- Test: Basic buffer creation
TestFramework:test("Buffer creation with default size", function()
    local buffer = FrameBuffer:new()
    TestFramework:assertEqual(buffer.max_frames, 3, "Default buffer size should be 3")
    TestFramework:assertEqual(buffer.frame_count, 0, "Initial frame count should be 0")
    TestFramework:assertEqual(buffer.current_index, 1, "Initial index should be 1")
end)

-- Test: Buffer creation with custom size
TestFramework:test("Buffer creation with custom size", function()
    local buffer = FrameBuffer:new(5)
    TestFramework:assertEqual(buffer.max_frames, 5, "Custom buffer size should be respected")
    TestFramework:assertEqual(buffer.frame_count, 0, "Initial frame count should be 0")
end)

-- Test: Adding single frame
TestFramework:test("Adding single frame", function()
    local buffer = FrameBuffer:new(3)
    local frame_data = createTestFrameData(10, 10)
    
    local result = buffer:addFrame(frame_data, 10, 10, "RGBA")
    TestFramework:assert(result, "addFrame should return true on success")
    TestFramework:assertEqual(buffer.frame_count, 1, "Frame count should be 1")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 400, "Memory usage should be 10*10*4 = 400 bytes")
end)

-- Test: Getting latest frame
TestFramework:test("Getting latest frame", function()
    local buffer = FrameBuffer:new(3)
    local frame_data = createTestFrameData(5, 5)
    
    -- Empty buffer should return nil
    TestFramework:assertNil(buffer:getLatestFrame(), "Empty buffer should return nil")
    
    -- Add frame and retrieve it
    buffer:addFrame(frame_data, 5, 5, "RGBA", {source = "test"})
    local latest = buffer:getLatestFrame()
    
    TestFramework:assertNotNil(latest, "Latest frame should not be nil")
    TestFramework:assertEqual(latest.width, 5, "Frame width should match")
    TestFramework:assertEqual(latest.height, 5, "Frame height should match")
    TestFramework:assertEqual(latest.format, "RGBA", "Frame format should match")
    TestFramework:assertEqual(latest.source_info.source, "test", "Source info should match")
    TestFramework:assertNotNil(latest.timestamp, "Frame should have timestamp")
end)

-- Test: Circular buffer behavior
TestFramework:test("Circular buffer overflow", function()
    local buffer = FrameBuffer:new(2) -- Small buffer for testing
    local frame_data1 = createTestFrameData(3, 3)
    local frame_data2 = createTestFrameData(3, 3)
    local frame_data3 = createTestFrameData(3, 3)
    
    -- Add frames to fill buffer
    buffer:addFrame(frame_data1, 3, 3, "RGBA", {id = 1})
    buffer:addFrame(frame_data2, 3, 3, "RGBA", {id = 2})
    TestFramework:assertEqual(buffer.frame_count, 2, "Buffer should be full")
    TestFramework:assert(buffer:isFull(), "Buffer should report as full")
    
    -- Add third frame (should overwrite first)
    buffer:addFrame(frame_data3, 3, 3, "RGBA", {id = 3})
    TestFramework:assertEqual(buffer.frame_count, 2, "Frame count should remain at max")
    TestFramework:assertEqual(buffer.dropped_frames, 1, "Should have 1 dropped frame")
    
    -- Latest frame should be the third one
    local latest = buffer:getLatestFrame()
    TestFramework:assertEqual(latest.source_info.id, 3, "Latest frame should be frame 3")
end)

-- Test: Frame retrieval by age
TestFramework:test("Frame retrieval by age", function()
    local buffer = FrameBuffer:new(3)
    
    -- Add multiple frames
    buffer:addFrame(createTestFrameData(2, 2), 2, 2, "RGBA", {id = 1})
    buffer:addFrame(createTestFrameData(2, 2), 2, 2, "RGBA", {id = 2})
    buffer:addFrame(createTestFrameData(2, 2), 2, 2, "RGBA", {id = 3})
    
    -- Test frame retrieval
    local frame0 = buffer:getFrame(0) -- Latest
    local frame1 = buffer:getFrame(1) -- Previous
    local frame2 = buffer:getFrame(2) -- Oldest
    
    TestFramework:assertEqual(frame0.source_info.id, 3, "Frame 0 should be latest (id=3)")
    TestFramework:assertEqual(frame1.source_info.id, 2, "Frame 1 should be previous (id=2)")
    TestFramework:assertEqual(frame2.source_info.id, 1, "Frame 2 should be oldest (id=1)")
    
    -- Test invalid indices
    TestFramework:assertNil(buffer:getFrame(-1), "Negative index should return nil")
    TestFramework:assertNil(buffer:getFrame(3), "Out of range index should return nil")
end)

-- Test: Memory management and cleanup
TestFramework:test("Memory management", function()
    local buffer = FrameBuffer:new(2)
    
    -- Add frames of different sizes
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "RGBA") -- 400 bytes
    TestFramework:assertEqual(buffer:getMemoryUsage(), 400, "Memory usage after first frame")
    
    buffer:addFrame(createTestFrameData(5, 5), 5, 5, "RGB") -- 75 bytes
    TestFramework:assertEqual(buffer:getMemoryUsage(), 475, "Memory usage after second frame")
    
    -- Add third frame (should replace first)
    buffer:addFrame(createTestFrameData(8, 8), 8, 8, "RGBA") -- 256 bytes
    TestFramework:assertEqual(buffer:getMemoryUsage(), 331, "Memory should be 75 + 256 = 331 bytes")
    
    -- Clear buffer
    buffer:clear()
    TestFramework:assertEqual(buffer:getMemoryUsage(), 0, "Memory usage should be 0 after clear")
    TestFramework:assertEqual(buffer.frame_count, 0, "Frame count should be 0 after clear")
    TestFramework:assertEqual(buffer.dropped_frames, 0, "Dropped frames should reset after clear")
end)

-- Test: Buffer statistics
TestFramework:test("Buffer statistics", function()
    local buffer = FrameBuffer:new(4)
    
    -- Add some frames
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "RGBA")
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "RGBA")
    
    local stats = buffer:getStats()
    TestFramework:assertEqual(stats.frame_count, 2, "Stats should show correct frame count")
    TestFramework:assertEqual(stats.max_frames, 4, "Stats should show correct max frames")
    TestFramework:assertEqual(stats.memory_bytes, 800, "Stats should show correct memory usage")
    TestFramework:assertEqual(stats.memory_mb, 800 / (1024 * 1024), "Stats should show correct MB")
    TestFramework:assertEqual(stats.utilization, 0.5, "Stats should show 50% utilization")
    TestFramework:assertEqual(stats.dropped_frames, 0, "Stats should show no dropped frames")
end)

-- Test: Buffer resize
TestFramework:test("Buffer resize", function()
    local buffer = FrameBuffer:new(2)
    
    -- Add frames
    buffer:addFrame(createTestFrameData(5, 5), 5, 5, "RGBA")
    buffer:addFrame(createTestFrameData(5, 5), 5, 5, "RGBA")
    
    -- Resize buffer (should clear existing frames)
    buffer:resize(5)
    TestFramework:assertEqual(buffer.max_frames, 5, "Buffer size should be updated")
    TestFramework:assertEqual(buffer.frame_count, 0, "Frames should be cleared after resize")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 0, "Memory should be cleared after resize")
end)

-- Test: Error handling
TestFramework:test("Error handling", function()
    local buffer = FrameBuffer:new(3)
    
    -- Test nil frame data
    local success, err = pcall(function()
        buffer:addFrame(nil, 10, 10)
    end)
    TestFramework:assert(not success, "Should error on nil frame data")
    
    -- Test invalid dimensions
    success, err = pcall(function()
        buffer:addFrame(createTestFrameData(5, 5), 0, 5)
    end)
    TestFramework:assert(not success, "Should error on zero width")
    
    success, err = pcall(function()
        buffer:addFrame(createTestFrameData(5, 5), 5, -1)
    end)
    TestFramework:assert(not success, "Should error on negative height")
    
    -- Test invalid resize
    success, err = pcall(function()
        buffer:resize(0)
    end)
    TestFramework:assert(not success, "Should error on zero buffer size")
end)

-- Test: Different pixel formats
TestFramework:test("Different pixel formats", function()
    local buffer = FrameBuffer:new(3)
    
    -- Test RGBA format (4 bytes per pixel)
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "RGBA")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 400, "RGBA should use 4 bytes per pixel")
    
    buffer:clear()
    
    -- Test RGB format (3 bytes per pixel)
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "RGB")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 300, "RGB should use 3 bytes per pixel")
    
    buffer:clear()
    
    -- Test GRAY format (1 byte per pixel)
    buffer:addFrame(createTestFrameData(10, 10), 10, 10, "GRAY")
    TestFramework:assertEqual(buffer:getMemoryUsage(), 100, "GRAY should use 1 byte per pixel")
end)

-- Run all tests
return TestFramework:run()