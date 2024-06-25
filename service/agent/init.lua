local skynet = require "skynet"
local s = require "service"

s.client = {}
s.gate = nil

require "scene"

--- 处理客户端命令的函数。
-- 该函数用于处理从客户端接收到的命令，并根据命令执行相应的操作。
-- @param source 发送命令的客户端的服务地址。
-- @param cmd 接收到的命令。
-- @param msg 与命令相关的消息内容。
s.resp.client = function(source, cmd, msg)
    s.gate = source -- 记录发送命令的客户端服务地址
    -- 检查是否存在对应的命令处理函数
    if s.client[cmd] then
        -- 如果存在，调用该命令的处理函数，并传入消息内容和来源地址
        local ret_msg = s.client[cmd](msg, source)
        -- 如果处理函数返回了消息，则将该消息发送回客户端
        if ret_msg then
            skynet.send(source, "lua", "send", s.id, ret_msg)
        end
    else
        -- 如果不存在对应的命令处理函数，记录错误信息
        skynet.error("s.resp.client fail", cmd)
    end
end

--- 处理工作命令的函数。
-- 当客户端发送工作命令时，该函数被调用来增加玩家的金币数量。
-- @param msg 客户端发送的消息，本函数中未使用。
-- @return table 返回一个包含命令名称和更新后的金币数量的表。
s.client.work = function(msg)
    -- 增加玩家的金币数量
    s.data.coin = s.data.coin + 1
    -- 返回命令名称和更新后的金币数量
    return {"work", s.data.coin}
end

--- 处理玩家被踢出的函数。
-- 当玩家需要被踢出游戏时，该函数被调用。
-- @param source 发起踢出请求的服务地址。
s.resp.kick = function(source)
    s.leave_scene() -- 玩家离开当前场景
    -- 在此处保存角色数据
    skynet.sleep(200) -- 模拟数据保存过程中的延时
end

--- 处理服务退出的函数。
-- 当服务需要被终止时，该函数被调用。
-- @param source 发起退出请求的服务地址。
s.resp.exit = function(source)
    skynet.exit() -- 终止当前服务
end

--- 向客户端发送消息的函数。
-- 该函数用于通过网关服务向客户端发送消息。
-- @param source 发起发送请求的服务地址。
-- @param msg 要发送给客户端的消息内容。
s.resp.send = function(source, msg)
    -- 使用skynet框架的send方法，通过网关服务向客户端发送消息
    skynet.send(s.gate, "lua", "send", s.id, msg)
end

--- 初始化服务。
-- 该函数在服务启动时被调用，用于初始化玩家数据。
s.init = function()
    -- playerid = s.id  -- 将服务ID设置为玩家ID
    -- 在此处加载角色数据
    skynet.sleep(200) -- 模拟数据加载过程中的延时
    s.data = {
        coin = 100, -- 初始化玩家的金币数量
        hp = 200 -- 初始化玩家的生命值
    }
end

s.start(...)
