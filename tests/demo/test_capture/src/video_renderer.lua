-- VideoRenderer: Handles frame display and rendering with LÖVE 2D
-- Supports multiple scaling modes and overlay functionality

local VideoRenderer = {}
VideoRenderer.__index = VideoRenderer

-- Create new VideoRenderer instance
function VideoRenderer:new()
    return setmetatable({
        current_texture = nil,
        display_mode = 'fit', -- 'fit', 'fill', 'stretch'
        overlay_mode = false,
        transparency = 1.0,
        last_frame_width = 0,
        last_frame_height = 0,
        render_stats = {
            frames_rendered = 0,
            last_update_time = 0
        }
    }, self)
end

-- Update the current frame texture from raw frame data
function VideoRenderer:updateFrame(frame_data, width, height)
    if not frame_data or width <= 0 or height <= 0 then
        return false, "Invalid frame data or dimensions"
    end
    
    -- Create or update texture
    local success, err = pcall(function()
        if type(frame_data) == "string" then
            -- Raw pixel data as string - create ImageData first
            local image_data = love.image.newImageData(width, height, "rgba8", frame_data)
            self.current_texture = love.graphics.newImage(image_data)
        elseif (type(frame_data) == "userdata" or type(frame_data) == "table") and frame_data.type and frame_data:type() == "ImageData" then
            -- Already ImageData (userdata in real LÖVE, table in tests)
            self.current_texture = love.graphics.newImage(frame_data)
        else
            error("Unsupported frame data type: " .. type(frame_data))
        end
    end)
    
    if not success then
        return false, "Failed to create texture: " .. tostring(err)
    end
    
    self.last_frame_width = width
    self.last_frame_height = height
    self.render_stats.last_update_time = love.timer.getTime()
    
    return true
end

-- Calculate scaling and positioning based on display mode
function VideoRenderer:_calculateScaling(target_width, target_height)
    if not self.current_texture then
        return 1, 1, 0, 0
    end
    
    local frame_width = self.last_frame_width
    local frame_height = self.last_frame_height
    
    if frame_width == 0 or frame_height == 0 then
        return 1, 1, 0, 0
    end
    
    local scale_x, scale_y = 1, 1
    local offset_x, offset_y = 0, 0
    
    if self.display_mode == 'stretch' then
        -- Stretch to fill entire target area (may distort aspect ratio)
        scale_x = target_width / frame_width
        scale_y = target_height / frame_height
        
    elseif self.display_mode == 'fill' then
        -- Scale to fill target area while maintaining aspect ratio (may crop)
        local scale = math.max(target_width / frame_width, target_height / frame_height)
        scale_x = scale
        scale_y = scale
        
        -- Center the image
        offset_x = (target_width - frame_width * scale) / 2
        offset_y = (target_height - frame_height * scale) / 2
        
    else -- 'fit' mode (default)
        -- Scale to fit within target area while maintaining aspect ratio
        local scale = math.min(target_width / frame_width, target_height / frame_height)
        scale_x = scale
        scale_y = scale
        
        -- Center the image
        offset_x = (target_width - frame_width * scale) / 2
        offset_y = (target_height - frame_height * scale) / 2
    end
    
    return scale_x, scale_y, offset_x, offset_y
end

-- Render the current frame to screen
function VideoRenderer:render(x, y, target_width, target_height)
    if not self.current_texture then
        return false, "No texture to render"
    end
    
    x = x or 0
    y = y or 0
    target_width = target_width or love.graphics.getWidth()
    target_height = target_height or love.graphics.getHeight()
    
    -- Calculate scaling and positioning
    local scale_x, scale_y, offset_x, offset_y = self:_calculateScaling(target_width, target_height)
    
    -- Set transparency
    love.graphics.setColor(1, 1, 1, self.transparency)
    
    -- Render the texture
    love.graphics.draw(
        self.current_texture,
        x + offset_x,
        y + offset_y,
        0, -- rotation
        scale_x,
        scale_y
    )
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
    
    self.render_stats.frames_rendered = self.render_stats.frames_rendered + 1
    
    return true
end

-- Set display scaling mode
function VideoRenderer:setDisplayMode(mode)
    local valid_modes = {fit = true, fill = true, stretch = true}
    
    if not valid_modes[mode] then
        return false, "Invalid display mode: " .. tostring(mode)
    end
    
    self.display_mode = mode
    return true
end

-- Alias for setDisplayMode (for compatibility)
function VideoRenderer:setScalingMode(mode)
    return self:setDisplayMode(mode)
end

-- Toggle overlay mode
function VideoRenderer:setOverlayMode(enabled)
    self.overlay_mode = enabled
    return true
end

-- Set transparency level (0.0 to 1.0)
function VideoRenderer:setTransparency(alpha)
    alpha = math.max(0.0, math.min(1.0, alpha or 1.0))
    self.transparency = alpha
    return true
end

-- Update method (called each frame)
function VideoRenderer:update(dt)
    -- Update timing information
    self.render_stats.last_update_time = love.timer.getTime()
    
    -- Could add frame interpolation or other time-based effects here
    return true
end

-- Get current renderer state
function VideoRenderer:getState()
    return {
        has_texture = self.current_texture ~= nil,
        display_mode = self.display_mode,
        overlay_mode = self.overlay_mode,
        transparency = self.transparency,
        frame_dimensions = {
            width = self.last_frame_width,
            height = self.last_frame_height
        },
        stats = {
            frames_rendered = self.render_stats.frames_rendered,
            last_update_time = self.render_stats.last_update_time
        }
    }
end

-- Clean up resources
function VideoRenderer:cleanup()
    if self.current_texture then
        self.current_texture:release()
        self.current_texture = nil
    end
    
    self.last_frame_width = 0
    self.last_frame_height = 0
    self.render_stats.frames_rendered = 0
end

return VideoRenderer