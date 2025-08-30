-- 简化的UI演示版本
-- 用于验证基本界面显示功能

function love.load()
    print("=== Simple UI Demo Starting ===")
    
    -- 基本窗口设置
    love.window.setTitle("Lua Video Capture Player - Demo")
    
    -- 简单状态
    demo = {
        initialized = true,
        message = "Lua Video Capture Player",
        submessage = "界面正常显示 - UI Working",
        buttons = {
            {text = "开始捕获 Start Capture", x = 50, y = 100, w = 200, h = 40},
            {text = "选择源 Select Source", x = 50, y = 150, w = 200, h = 40},
            {text = "设置 Settings", x = 50, y = 200, w = 200, h = 40},
            {text = "退出 Exit", x = 50, y = 250, w = 200, h = 40}
        },
        mouse_x = 0,
        mouse_y = 0
    }
    
    print("=== Demo initialized successfully ===")
end

function love.update(dt)
    -- 更新鼠标位置
    demo.mouse_x, demo.mouse_y = love.mouse.getPosition()
end

function love.draw()
    -- 清除屏幕
    love.graphics.clear(0.1, 0.1, 0.1, 1.0)
    
    -- 绘制标题
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(demo.message, 50, 30, 0, 2, 2)
    love.graphics.print(demo.submessage, 50, 60)
    
    -- 绘制按钮
    for i, button in ipairs(demo.buttons) do
        -- 检查鼠标悬停
        local hover = demo.mouse_x >= button.x and demo.mouse_x <= button.x + button.w and
                     demo.mouse_y >= button.y and demo.mouse_y <= button.y + button.h
        
        -- 绘制按钮背景
        if hover then
            love.graphics.setColor(0.4, 0.4, 0.4, 1.0)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
        end
        love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
        
        -- 绘制按钮边框
        love.graphics.setColor(0.6, 0.6, 0.6, 1.0)
        love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
        
        -- 绘制按钮文字
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(button.text, button.x + 10, button.y + 12)
    end
    
    -- 绘制状态信息
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("鼠标位置 Mouse: " .. demo.mouse_x .. ", " .. demo.mouse_y, 50, 320)
    love.graphics.print("按ESC退出 Press ESC to exit", 50, 340)
    love.graphics.print("这是简化演示版本 This is a simplified demo", 50, 360)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- 左键
        -- 检查按钮点击
        for i, btn in ipairs(demo.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h then
                print("Button clicked: " .. btn.text)
                
                if i == 4 then -- 退出按钮
                    love.event.quit()
                end
            end
        end
    end
end