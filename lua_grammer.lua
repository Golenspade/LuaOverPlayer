#!/usr/bin/env lua
-- Lua完整语法示例 - 包含所有主要语法特性

--[[
多行注释
演示Lua的所有语法特性
]]

-- =============================================================================
-- 1. 基本数据类型
-- =============================================================================

-- nil类型
local nil_value = nil
print("nil值:", nil_value)

-- 布尔类型
local bool_true = true
local bool_false = false
print("布尔值:", bool_true, bool_false)

-- 数字类型 (Lua中数字都是double)
local integer = 42
local float = 3.14159
local scientific = 1.23e10
local hex = 0xFF
print("数字:", integer, float, scientific, hex)

-- 字符串类型
local str1 = "双引号字符串"
local str2 = '单引号字符串'
local str3 = [[多行字符串
可以包含换行]]
local str4 = [==[可以包含[[ ]]的多行字符串]==]
print("字符串:", str1, str2)

-- =============================================================================
-- 2. 变量声明和作用域
-- =============================================================================

-- 全局变量 (不推荐)
global_var = "我是全局变量"

-- 局部变量 (推荐)
local local_var = "我是局部变量"

-- 多重赋值
local a, b, c = 1, 2, 3
local x, y = 10, 20
x, y = y, x  -- 交换值
print("交换后:", x, y)

-- =============================================================================
-- 3. 运算符
-- =============================================================================

-- 算术运算符
local num1, num2 = 10, 3
print("算术运算:")
print("加法:", num1 + num2)
print("减法:", num1 - num2)
print("乘法:", num1 * num2)
print("除法:", num1 / num2)
print("取模:", num1 % num2)
print("幂运算:", num1 ^ num2)
print("负号:", -num1)

-- 关系运算符
print("\n关系运算:")
print("等于:", num1 == num2)
print("不等于:", num1 ~= num2)
print("小于:", num1 < num2)
print("小于等于:", num1 <= num2)
print("大于:", num1 > num2)
print("大于等于:", num1 >= num2)

-- 逻辑运算符
print("\n逻辑运算:")
print("and:", true and false)
print("or:", true or false)
print("not:", not true)

-- 字符串连接
local str_concat = "Hello" .. " " .. "World"
print("字符串连接:", str_concat)

-- 长度运算符
print("字符串长度:", #str_concat)

-- =============================================================================
-- 4. 控制结构
-- =============================================================================

-- if-then-else
local score = 85
if score >= 90 then
    print("优秀")
elseif score >= 80 then
    print("良好")
elseif score >= 60 then
    print("及格")
else
    print("不及格")
end

-- while循环
local i = 1
while i <= 3 do
    print("while循环:", i)
    i = i + 1
end

-- repeat-until循环
local j = 1
repeat
    print("repeat循环:", j)
    j = j + 1
until j > 3

-- for数值循环
print("for数值循环:")
for k = 1, 5 do
    print("  ", k)
end

for k = 5, 1, -2 do  -- 步长为-2
    print("  倒序:", k)
end

-- break和goto (Lua 5.2+)
for k = 1, 10 do
    if k == 3 then
        goto continue
    end
    if k == 7 then
        break
    end
    print("循环值:", k)
    ::continue::
end

-- =============================================================================
-- 5. 表(Table) - Lua最重要的数据结构
-- =============================================================================

-- 创建空表
local empty_table = {}

-- 数组风格的表
local array = {10, 20, 30, "hello", true}
print("数组元素:", array[1], array[4])

-- 字典风格的表
local dict = {
    name = "张三",
    age = 25,
    city = "北京",
    ["特殊键"] = "特殊值"
}
print("字典:", dict.name, dict["age"])

-- 混合表
local mixed = {
    "first",     -- [1]
    "second",    -- [2]
    x = 10,
    y = 20,
    [100] = "hundred"
}

-- 嵌套表
local nested = {
    person = {
        name = "李四",
        contact = {
            email = "lisi@example.com",
            phone = "123456789"
        }
    }
}
print("嵌套访问:", nested.person.contact.email)

-- for泛型循环遍历表
print("\n遍历数组:")
for index, value in ipairs(array) do
    print("  ", index, value)
end

print("\n遍历字典:")
for key, value in pairs(dict) do
    print("  ", key, value)
end

-- 表操作
table.insert(array, "new_item")  -- 插入
table.remove(array, 1)           -- 删除第一个元素
print("表长度:", #array)

-- =============================================================================
-- 6. 函数
-- =============================================================================

-- 基本函数定义
local function greet(name)
    return "Hello, " .. name
end
print(greet("World"))

-- 多参数和多返回值
local function math_ops(a, b)
    return a + b, a - b, a * b, a / b
end
local add, sub, mul, div = math_ops(10, 5)
print("多返回值:", add, sub, mul, div)

-- 可变参数
local function sum(...)
    local args = {...}  -- 将可变参数打包成表
    local total = 0
    for i = 1, #args do
        total = total + args[i]
    end
    return total
end
print("可变参数求和:", sum(1, 2, 3, 4, 5))

-- select函数处理可变参数
local function print_args(...)
    local n = select("#", ...)  -- 获取参数个数
    for i = 1, n do
        print("参数" .. i .. ":", select(i, ...))
    end
end
print_args("a", "b", "c")

-- 函数作为一等公民
local function apply_operation(a, b, op)
    return op(a, b)
end

local function add(x, y) return x + y end
local function multiply(x, y) return x * y end

print("函数作为参数:", apply_operation(5, 3, add))
print("函数作为参数:", apply_operation(5, 3, multiply))

-- 匿名函数和闭包
local function create_counter()
    local count = 0
    return function()
        count = count + 1
        return count
    end
end

local counter = create_counter()
print("闭包计数器:", counter(), counter(), counter())

-- 局部函数
local function factorial(n)
    if n <= 1 then
        return 1
    else
        return n * factorial(n - 1)
    end
end
print("递归阶乘:", factorial(5))

-- =============================================================================
-- 7. 字符串操作
-- =============================================================================

local test_string = "Hello, Lua Programming!"

-- 字符串库函数
print("\n字符串操作:")
print("长度:", string.len(test_string))
print("转大写:", string.upper(test_string))
print("转小写:", string.lower(test_string))
print("子串:", string.sub(test_string, 1, 5))
print("查找:", string.find(test_string, "Lua"))
print("替换:", string.gsub(test_string, "Lua", "Python"))
print("重复:", string.rep("Ha", 3))

-- 字符串格式化
local formatted = string.format("姓名: %s, 年龄: %d, 分数: %.2f", "张三", 25, 89.567)
print("格式化:", formatted)

-- 字符和字节
print("字符码:", string.byte("A"))
print("码转字符:", string.char(65))

-- 模式匹配
local text = "电话: 123-456-7890"
local phone = string.match(text, "(%d+)%-(%d+)%-(%d+)")
print("模式匹配:", phone)

-- 字符串迭代
for word in string.gmatch("hello world lua", "%w+") do
    print("单词:", word)
end

-- =============================================================================
-- 8. 表操作库
-- =============================================================================

local fruits = {"apple", "banana", "orange"}

-- 表操作
table.insert(fruits, "grape")      -- 末尾插入
table.insert(fruits, 2, "mango")   -- 指定位置插入
print("插入后:", table.concat(fruits, ", "))

table.remove(fruits, 1)            -- 删除指定位置
print("删除后:", table.concat(fruits, ", "))

table.sort(fruits)                 -- 排序
print("排序后:", table.concat(fruits, ", "))

-- 自定义排序
local numbers = {3, 1, 4, 1, 5, 9, 2, 6}
table.sort(numbers, function(a, b) return a > b end)  -- 降序
print("降序排序:", table.concat(numbers, ", "))

-- =============================================================================
-- 9. 数学库
-- =============================================================================

print("\n数学函数:")
print("绝对值:", math.abs(-5))
print("向上取整:", math.ceil(4.3))
print("向下取整:", math.floor(4.7))
print("最大值:", math.max(1, 5, 3))
print("最小值:", math.min(1, 5, 3))
print("随机数:", math.random())
print("随机数(1-10):", math.random(1, 10))
print("平方根:", math.sqrt(16))
print("幂运算:", math.pow(2, 3))
print("pi:", math.pi)
print("sin(π/2):", math.sin(math.pi/2))

-- 设置随机种子
math.randomseed(os.time())

-- =============================================================================
-- 10. 输入输出
-- =============================================================================

-- 标准输出
print("标准输出")
io.write("不换行输出")
io.write(" 继续输出\n")

-- 格式化输出
io.write(string.format("格式化输出: %d + %d = %d\n", 2, 3, 2+3))

-- 文件操作
local file = io.open("test.txt", "w")
if file then
    file:write("这是测试文件\n")
    file:write("第二行内容\n")
    file:close()
    print("文件写入成功")
else
    print("文件打开失败")
end

-- 读取文件
file = io.open("test.txt", "r")
if file then
    local content = file:read("*all")  -- 读取全部内容
    print("文件内容:", content)
    file:close()
    
    -- 删除测试文件
    os.remove("test.txt")
end

-- =============================================================================
-- 11. 模式匹配详解
-- =============================================================================

local pattern_text = "Email: user@example.com, Phone: 123-456-7890"

-- 基本模式匹配
print("\n模式匹配:")
print("匹配邮箱:", string.match(pattern_text, "([%w%.]+)@([%w%.]+)"))

-- 全局匹配
local numbers_text = "数字: 123, 456, 789"
for num in string.gmatch(numbers_text, "%d+") do
    print("找到数字:", num)
end

-- 替换
local replaced = string.gsub("hello hello hello", "hello", "hi")
print("替换结果:", replaced)

-- =============================================================================
-- 12. 元表(Metatable)和元方法
-- =============================================================================

-- 创建一个向量类
local Vector = {}
Vector.__index = Vector

function Vector.new(x, y)
    local self = setmetatable({}, Vector)
    self.x = x or 0
    self.y = y or 0
    return self
end

-- 元方法：加法
function Vector.__add(a, b)
    return Vector.new(a.x + b.x, a.y + b.y)
end

-- 元方法：字符串表示
function Vector.__tostring(self)
    return string.format("Vector(%g, %g)", self.x, self.y)
end

-- 元方法：索引
function Vector.__index(self, key)
    if key == "magnitude" then
        return math.sqrt(self.x^2 + self.y^2)
    end
    return Vector[key]  -- 回退到类方法
end

-- 使用元表
local v1 = Vector.new(3, 4)
local v2 = Vector.new(1, 2)
local v3 = v1 + v2

print("\n元表示例:")
print("v1:", v1)
print("v2:", v2)
print("v3 = v1 + v2:", v3)
print("v1的模长:", v1.magnitude)

-- =============================================================================
-- 13. 协程(Coroutine)
-- =============================================================================

-- 创建协程
local function producer()
    for i = 1, 5 do
        print("生产:", i)
        coroutine.yield(i)  -- 让出控制权
    end
end

local co = coroutine.create(producer)

print("\n协程示例:")
while coroutine.status(co) ~= "dead" do
    local success, value = coroutine.resume(co)
    if success and value then
        print("消费:", value)
    end
end

-- 协程用于迭代器
local function range(n)
    return coroutine.wrap(function()
        for i = 1, n do
            coroutine.yield(i)
        end
    end)
end

print("协程迭代器:")
for i in range(3) do
    print("迭代值:", i)
end

-- =============================================================================
-- 14. 模块和包
-- =============================================================================

-- 创建模块
local mymodule = {}

mymodule.version = "1.0"

function mymodule.hello(name)
    return "Hello from module, " .. (name or "World")
end

function mymodule.add(a, b)
    return (a or 0) + (b or 0)
end

-- 私有函数
local function private_function()
    return "这是私有函数"
end

mymodule.call_private = function()
    return private_function()
end

print("\n模块示例:")
print("模块版本:", mymodule.version)
print("模块函数:", mymodule.hello("Lua"))
print("模块计算:", mymodule.add(5, 3))
print("调用私有:", mymodule.call_private())

-- =============================================================================
-- 15. 错误处理
-- =============================================================================

-- pcall保护调用
local function risky_function(x)
    if x < 0 then
        error("参数不能为负数")
    end
    return math.sqrt(x)
end

print("\n错误处理:")
local success, result = pcall(risky_function, 16)
if success then
    print("成功执行:", result)
else
    print("执行错误:", result)
end

local success, result = pcall(risky_function, -1)
if success then
    print("成功执行:", result)
else
    print("捕获错误:", result)
end

-- xpcall with error handler
local function error_handler(err)
    return "错误处理器: " .. tostring(err)
end

local success, result = xpcall(function() error("测试错误") end, error_handler)
print("xpcall结果:", success, result)

-- assert断言
local function divide(a, b)
    assert(b ~= 0, "除数不能为零")
    return a / b
end

print("断言测试:", divide(10, 2))
-- divide(10, 0)  -- 这会触发断言错误

-- =============================================================================
-- 16. 弱引用表
-- =============================================================================

-- 弱引用表示例
local weak_table = {}
setmetatable(weak_table, {__mode = "k"})  -- 键弱引用

local key = {}
weak_table[key] = "some value"
print("弱引用表大小:", #weak_table)

key = nil  -- 移除对键的引用
collectgarbage()  -- 强制垃圾回收
print("垃圾回收后表大小:", #weak_table)

-- =============================================================================
-- 17. 调试库基本使用
-- =============================================================================

-- 获取调用信息
local function get_caller_info()
    local info = debug.getinfo(2, "nSl")
    return info
end

local function test_debug()
    local info = get_caller_info()
    print("\n调试信息:")
    print("函数名:", info.name or "未知")
    print("文件:", info.short_src)
    print("行号:", info.currentline)
end

test_debug()

-- =============================================================================
-- 18. 迭代器模式
-- =============================================================================

-- 自定义迭代器
local function pairs_reverse(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    
    local i = #keys + 1
    return function()
        i = i - 1
        if i > 0 then
            return keys[i], t[keys[i]]
        end
    end
end

print("\n自定义迭代器:")
local test_table = {a = 1, b = 2, c = 3}
for k, v in pairs_reverse(test_table) do
    print("逆序:", k, v)
end

-- =============================================================================
-- 19. 操作系统接口
-- =============================================================================

print("\n系统信息:")
print("当前时间:", os.date())
print("时间戳:", os.time())
print("系统:", os.getenv("OS") or "Unix-like")

-- 执行系统命令(注意安全性)
-- os.execute("echo Hello from system")

-- =============================================================================
-- 20. 类型检查和转换
-- =============================================================================

local function check_types()
    local values = {42, "hello", {}, true, nil, function() end}
    
    print("\n类型检查:")
    for i, v in ipairs(values) do
        print(string.format("值: %s, 类型: %s", tostring(v), type(v)))
    end
    
    -- 数字转换
    local str_num = "123.45"
    local num = tonumber(str_num)
    print("字符串转数字:", str_num, "->", num, type(num))
    
    -- 字符串转换
    local num_val = 456.78
    local str = tostring(num_val)
    print("数字转字符串:", num_val, "->", str, type(str))
end

check_types()

-- =============================================================================
-- 21. 综合示例：简单的面向对象编程
-- =============================================================================

-- 定义一个动物基类
local Animal = {}
Animal.__index = Animal

function Animal.new(name, species)
    local self = setmetatable({}, Animal)
    self.name = name or "Unknown"
    self.species = species or "Unknown"
    return self
end

function Animal:speak()
    return self.name .. " makes a sound"
end

function Animal:info()
    return string.format("%s is a %s", self.name, self.species)
end

-- 继承：狗类
local Dog = setmetatable({}, {__index = Animal})
Dog.__index = Dog

function Dog.new(name, breed)
    local self = Animal.new(name, "Dog")
    setmetatable(self, Dog)
    self.breed = breed or "Mixed"
    return self
end

function Dog:speak()
    return self.name .. " says Woof!"
end

function Dog:fetch()
    return self.name .. " is fetching the ball!"
end

-- 使用面向对象
print("\n面向对象示例:")
local animal = Animal.new("Generic", "Animal")
local dog = Dog.new("Buddy", "Golden Retriever")

print(animal:info())
print(animal:speak())
print(dog:info())
print(dog:speak())
print(dog:fetch())

-- =============================================================================
-- 22. 尾调用优化示例
-- =============================================================================

-- 尾递归优化
local function tail_factorial(n, acc)
    acc = acc or 1
    if n <= 1 then
        return acc
    else
        return tail_factorial(n - 1, n * acc)  -- 尾调用
    end
end

print("\n尾递归示例:")
print("尾递归阶乘(10):", tail_factorial(10))

-- =============================================================================
-- 总结
-- =============================================================================

print("\n" .. string.rep("=", 50))
print("Lua语法特性展示完毕！")
print("涵盖了:")
print("- 基本数据类型和变量")
print("- 运算符和表达式") 
print("- 控制流程")
print("- 表和数组")
print("- 函数和闭包")
print("- 字符串处理")
print("- 模式匹配")
print("- 元表和元方法")
print("- 协程")
print("- 模块化编程")
print("- 错误处理")
print("- 面向对象编程")
print("- 系统接口")
print("- 以及更多...")
print(string.rep("=", 50))