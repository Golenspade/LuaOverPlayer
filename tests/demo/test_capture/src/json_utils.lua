-- Simple JSON utilities for configuration management
-- Basic JSON encoder/decoder for Lua tables

local JsonUtils = {}

-- Escape special characters in strings
local function escapeString(str)
    local escape_chars = {
        ['"'] = '\\"',
        ['\\'] = '\\\\',
        ['/'] = '\\/',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
    }
    
    return str:gsub('["\\\b\f\n\r\t/]', escape_chars)
end

-- Encode a Lua value to JSON string
function JsonUtils.encode(value, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local next_indent_str = string.rep("  ", indent + 1)
    
    if value == nil then
        return "null"
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "string" then
        return '"' .. escapeString(value) .. '"'
    elseif type(value) == "table" then
        -- Check if it's an array (consecutive integer keys starting from 1)
        local is_array = true
        local max_index = 0
        local count = 0
        
        for k, v in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
                is_array = false
                break
            end
            max_index = math.max(max_index, k)
        end
        
        if is_array and count == max_index then
            -- Encode as array
            local parts = {}
            for i = 1, max_index do
                table.insert(parts, next_indent_str .. JsonUtils.encode(value[i], indent + 1))
            end
            if #parts == 0 then
                return "[]"
            else
                return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent_str .. "]"
            end
        else
            -- Encode as object
            local parts = {}
            local keys = {}
            
            -- Sort keys for consistent output
            for k in pairs(value) do
                table.insert(keys, k)
            end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            
            for _, k in ipairs(keys) do
                local v = value[k]
                local key_str = '"' .. escapeString(tostring(k)) .. '"'
                local value_str = JsonUtils.encode(v, indent + 1)
                table.insert(parts, next_indent_str .. key_str .. ": " .. value_str)
            end
            
            if #parts == 0 then
                return "{}"
            else
                return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent_str .. "}"
            end
        end
    else
        error("Cannot encode value of type " .. type(value))
    end
end

-- Simple JSON decoder (handles basic cases)
function JsonUtils.decode(json_str)
    if not json_str or json_str == "" then
        return nil
    end
    
    -- Remove leading/trailing whitespace
    json_str = json_str:gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Handle simple cases
    if json_str == "null" then
        return nil
    elseif json_str == "true" then
        return true
    elseif json_str == "false" then
        return false
    elseif json_str:match("^%-?%d+%.?%d*$") then
        return tonumber(json_str)
    elseif json_str:match('^".*"$') then
        -- Simple string (doesn't handle all escape sequences)
        return json_str:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
    elseif json_str:match("^%{") and json_str:match("%}$") then
        -- Object - use a more robust parser
        return JsonUtils._parseObject(json_str)
    elseif json_str:match("^%[") and json_str:match("%]$") then
        -- Array - use a more robust parser
        return JsonUtils._parseArray(json_str)
    else
        error("Invalid JSON: " .. json_str:sub(1, 50) .. (json_str:len() > 50 and "..." or ""))
    end
end

-- Parse JSON object with proper nesting support
function JsonUtils._parseObject(json_str)
    local result = {}
    local content = json_str:sub(2, -2) -- Remove { }
    
    if content:gsub("%s", "") == "" then
        return result
    end
    
    local pos = 1
    local len = content:len()
    
    while pos <= len do
        -- Skip whitespace
        while pos <= len and content:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
        
        if pos > len then break end
        
        -- Parse key
        if content:sub(pos, pos) ~= '"' then
            error("Expected key to start with quote at position " .. pos)
        end
        
        local key_start = pos + 1
        local key_end = key_start
        while key_end <= len and content:sub(key_end, key_end) ~= '"' do
            key_end = key_end + 1
        end
        
        if key_end > len then
            error("Unterminated key string")
        end
        
        local key = content:sub(key_start, key_end - 1)
        pos = key_end + 1
        
        -- Skip whitespace and colon
        while pos <= len and content:sub(pos, pos):match("[%s:]") do
            pos = pos + 1
        end
        
        -- Parse value
        local value_start = pos
        local value_end = JsonUtils._findValueEnd(content, pos)
        local value_str = content:sub(value_start, value_end)
        
        result[key] = JsonUtils.decode(value_str)
        pos = value_end + 1
        
        -- Skip comma and whitespace
        while pos <= len and content:sub(pos, pos):match("[%s,]") do
            pos = pos + 1
        end
    end
    
    return result
end

-- Parse JSON array
function JsonUtils._parseArray(json_str)
    local result = {}
    local content = json_str:sub(2, -2) -- Remove [ ]
    
    if content:gsub("%s", "") == "" then
        return result
    end
    
    local pos = 1
    local len = content:len()
    local index = 1
    
    while pos <= len do
        -- Skip whitespace
        while pos <= len and content:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
        
        if pos > len then break end
        
        -- Parse value
        local value_start = pos
        local value_end = JsonUtils._findValueEnd(content, pos)
        local value_str = content:sub(value_start, value_end)
        
        result[index] = JsonUtils.decode(value_str)
        index = index + 1
        pos = value_end + 1
        
        -- Skip comma and whitespace
        while pos <= len and content:sub(pos, pos):match("[%s,]") do
            pos = pos + 1
        end
    end
    
    return result
end

-- Find the end of a JSON value (handles nesting)
function JsonUtils._findValueEnd(str, start_pos)
    local pos = start_pos
    local len = str:len()
    local char = str:sub(pos, pos)
    
    if char == '"' then
        -- String value
        pos = pos + 1
        while pos <= len do
            if str:sub(pos, pos) == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then
                return pos
            end
            pos = pos + 1
        end
        error("Unterminated string")
    elseif char == '{' then
        -- Object value
        local brace_count = 1
        pos = pos + 1
        while pos <= len and brace_count > 0 do
            local c = str:sub(pos, pos)
            if c == '{' then
                brace_count = brace_count + 1
            elseif c == '}' then
                brace_count = brace_count - 1
            end
            pos = pos + 1
        end
        return pos - 1
    elseif char == '[' then
        -- Array value
        local bracket_count = 1
        pos = pos + 1
        while pos <= len and bracket_count > 0 do
            local c = str:sub(pos, pos)
            if c == '[' then
                bracket_count = bracket_count + 1
            elseif c == ']' then
                bracket_count = bracket_count - 1
            end
            pos = pos + 1
        end
        return pos - 1
    else
        -- Primitive value (number, boolean, null)
        while pos <= len do
            local c = str:sub(pos, pos)
            if c:match("[,%s%]%}]") then
                return pos - 1
            end
            pos = pos + 1
        end
        return len
    end
end

return JsonUtils