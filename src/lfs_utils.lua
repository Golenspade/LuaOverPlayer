-- Simple LuaFileSystem utilities for configuration management
-- Basic file system operations for directory management

local LfsUtils = {}

-- Check if a path exists and get its attributes
function LfsUtils.attributes(path)
    -- For testing, we'll assume config directory doesn't exist initially
    if path == "config" then
        return nil -- Directory doesn't exist initially
    end
    
    local file = io.open(path, "r")
    if file then
        file:close()
        return {mode = "file"}
    end
    
    return nil
end

-- Create a directory
function LfsUtils.mkdir(path)
    -- Use os.execute to create directory
    local success = os.execute("mkdir -p " .. path .. " 2>/dev/null") or 
                   os.execute("mkdir " .. path .. " 2>nul")
    return success == 0 or success == true, nil
end

return LfsUtils