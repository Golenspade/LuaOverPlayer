-- Integration test for FrameBuffer with design document data structures
local FrameBuffer = require("src.frame_buffer")

-- Test that FrameBuffer works with the exact Frame structure from design document
local function testDesignDocumentCompliance()
    print("Testing Frame Buffer compliance with design document...")
    
    local buffer = FrameBuffer:new(3)
    
    -- Create frame data matching design document Frame structure
    local test_frame_data = "mock_image_data_rgba"
    local width, height = 640, 480
    local format = 'RGBA'
    local source_info = {
        source_type = 'screen',
        monitor_index = 1,
        capture_region = {x = 0, y = 0, width = width, height = height}
    }
    
    -- Add frame using design document interface
    local success = buffer:addFrame(test_frame_data, width, height, format, source_info)
    assert(success, "Frame should be added successfully")
    
    -- Retrieve frame and verify structure matches design document
    local frame = buffer:getLatestFrame()
    assert(frame ~= nil, "Frame should not be nil")
    assert(frame.data == test_frame_data, "Frame data should match")
    assert(frame.width == width, "Frame width should match")
    assert(frame.height == height, "Frame height should match")
    assert(frame.format == format, "Frame format should match")
    assert(frame.timestamp ~= nil, "Frame should have timestamp")
    assert(frame.source_info.source_type == 'screen', "Source info should be preserved")
    
    -- Test memory management as specified in requirements 6.2, 6.3
    local memory_usage = buffer:getMemoryUsage()
    local expected_memory = width * height * 4 -- RGBA = 4 bytes per pixel
    assert(memory_usage == expected_memory, 
           string.format("Memory usage should be %d bytes, got %d", expected_memory, memory_usage))
    
    -- Test circular buffer behavior for requirement 6.3 (efficient memory usage)
    local initial_memory = memory_usage
    
    -- Fill buffer to capacity
    buffer:addFrame(test_frame_data, width, height, format, source_info)
    buffer:addFrame(test_frame_data, width, height, format, source_info)
    
    -- Memory should be 3x the frame size
    local full_memory = buffer:getMemoryUsage()
    assert(full_memory == expected_memory * 3, "Full buffer should use 3x frame memory")
    
    -- Add one more frame (should overwrite oldest)
    buffer:addFrame(test_frame_data, width, height, format, source_info)
    local overflow_memory = buffer:getMemoryUsage()
    assert(overflow_memory == expected_memory * 3, "Overflow should maintain same memory usage")
    
    -- Verify dropped frame tracking for requirement 8.3 (error handling)
    local stats = buffer:getStats()
    assert(stats.dropped_frames == 1, "Should have 1 dropped frame after overflow")
    
    -- Test cleanup for requirement 6.3 (memory management)
    buffer:clear()
    assert(buffer:getMemoryUsage() == 0, "Memory should be freed after clear")
    assert(buffer:getLatestFrame() == nil, "Buffer should be empty after clear")
    
    print("✓ Design document compliance test passed")
    return true
end

-- Test error handling as specified in requirement 8.3
local function testErrorHandling()
    print("Testing error handling compliance...")
    
    local buffer = FrameBuffer:new(2)
    
    -- Test nil data handling
    local success, err = pcall(function()
        buffer:addFrame(nil, 100, 100)
    end)
    assert(not success, "Should reject nil frame data")
    
    -- Test invalid dimensions
    success, err = pcall(function()
        buffer:addFrame("data", 0, 100)
    end)
    assert(not success, "Should reject zero width")
    
    success, err = pcall(function()
        buffer:addFrame("data", 100, -1)
    end)
    assert(not success, "Should reject negative height")
    
    print("✓ Error handling compliance test passed")
    return true
end

-- Test performance characteristics for requirement 6.2
local function testPerformanceCharacteristics()
    print("Testing performance characteristics...")
    
    local buffer = FrameBuffer:new(10)
    local frame_data = string.rep("x", 1920 * 1080 * 4) -- Large frame data
    
    -- Measure time for multiple frame additions
    local start_time = os.clock()
    for i = 1, 20 do -- Add more frames than buffer size
        buffer:addFrame(frame_data, 1920, 1080, "RGBA", {frame_id = i})
    end
    local end_time = os.clock()
    
    local elapsed = end_time - start_time
    print(string.format("  Added 20 large frames in %.3f seconds", elapsed))
    
    -- Verify circular buffer maintained constant memory
    local stats = buffer:getStats()
    assert(stats.frame_count == 10, "Should maintain max frame count")
    assert(stats.dropped_frames == 10, "Should have dropped 10 frames")
    
    -- Verify latest frame is the most recent
    local latest = buffer:getLatestFrame()
    assert(latest.source_info.frame_id == 20, "Latest frame should be frame 20")
    
    print("✓ Performance characteristics test passed")
    return true
end

-- Run all integration tests
local function runIntegrationTests()
    print("Frame Buffer Integration Tests")
    print("=" .. string.rep("=", 40))
    
    local all_passed = true
    
    all_passed = all_passed and testDesignDocumentCompliance()
    all_passed = all_passed and testErrorHandling()
    all_passed = all_passed and testPerformanceCharacteristics()
    
    print("=" .. string.rep("=", 40))
    if all_passed then
        print("All integration tests passed! ✓")
    else
        print("Some integration tests failed! ✗")
    end
    
    return all_passed
end

-- Run tests if this file is executed directly
if arg and arg[0] and arg[0]:match("test_frame_buffer_integration%.lua$") then
    return runIntegrationTests()
else
    -- Return the test function for use by other test runners
    return {runIntegrationTests = runIntegrationTests}
end