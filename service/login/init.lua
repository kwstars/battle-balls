local skynet = require "skynet"
local s = require "service"

s.client = {}

--- 处理客户端请求的函数。
-- 该函数用于处理从客户端接收到的消息，并根据消息类型调用相应的处理方法。
-- @param source 消息发送方的标识，通常是某个gateway。
-- @param fd 客户端连接的文件描述符，用于标识客户端连接。
-- @param cmd 消息或命令的类型，用于决定如何处理接收到的消息。
-- @param msg 实际接收到的消息内容，通常是一个协议对象。
s.resp.client = function(source, fd, cmd, msg)
  -- 检查是否存在对应cmd的处理方法
  if s.client[cmd] then
    -- 如果存在，调用该方法并传入必要的参数
    local ret_msg = s.client[cmd](fd, msg, source)
    -- 将处理结果发送回消息来源
    skynet.send(source, "lua", "send_by_fd", fd, ret_msg)
  else
    -- 如果不存在对应的处理方法，记录错误信息
    skynet.error("s.resp.client fail", cmd)
  end
end

s.client.login = function(fd, msg, source)
    skynet.error("login recv "..msg[1].. " " .. msg[2])
    local playerid = tonumber(msg[2])
    local pw = tonumber(msg[3])
    local gate = source
    node = skynet.getenv("node")
    -- 校验用户名密码
    if pw ~= 123 then
        return {"login", 1, "密码错误"}
    end
    -- 发给agentmgr
    local isok, agent = skynet.call("agentmgr", "lua", "reqlogin", playerid, node, gate)
    if not isok then
        return {"login", 1, "请求mgr失败"}
    end
    -- 回应gate
    local isok = skynet.call(gate, "lua", "sure_agent", fd, playerid, agent)
    if not isok then
        return {"login", 1, "gate注册失败"}
    end
    skynet.error("login succ " .. playerid)
    return {"login", 0, "登陆成功"}
end

s.start(...)
