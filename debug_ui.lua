-- 调试UI显示问题
-- 直接测试UI控制器的绘制功能

-- 模拟LÖVE环境
local mock_love = {
    graphics = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        setColor = function() end,
        rectangle = function() end,
        print = function(text, x, y) 
            print("Drawing text: '" .. text .. "' at (" .. (x or 0) .. ", " .. (y or 0) .. ")")
        end,
        newFont = function(size) 
            return {
                getWidth = function(text) return #text * (size or 12) * 0.6 end
            }
        end,
        setFont = function() end
    },
    mouse = {
        getPosition = function() return 0, 0 end
    }
}

-- 替换全局love对象进行测试
_G.love = mock_love

-- 加载UI控制器
local UIController = require("src.ui_controller")

-- 创建模拟的依赖组件
local mock_capture_engine = {
    getAvailableSources = function() 
        return {
            {type = "screen", name = "Primary Screen"},
            {type = "window", name = "Test Window"}
        }
    end
}

local mock_renderer = {
    render = function() end
}

-- 创建UI控制器实例
print("Creating UI Controller...")
local ui = UIController:new(mock_capture_engine, mock_renderer, {})

-- 初始化UI控制器
print("Initializing UI Controller...")
local success, err = ui:initialize()

if success then
    print("✅ UI Controller initialized successfully")
    
    -- 测试绘制
    print("Testing draw method...")
    ui:draw()
    
    print("✅ Draw method executed without errors")
else
    print("❌ UI Controller initialization failed: " .. tostring(err))
end