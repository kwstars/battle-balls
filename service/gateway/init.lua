local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"

conns = {} -- 存储连接信息，格式为：[文件描述符fd] = 连接对象conn。若客户端发送了消息，可由底层Socket获取连接标识fd。gateway 则由fd索引到conn对象，再由playerid属性找到player对象，进而知道它的代理服务（agent）在哪里，并将消息转发给agent。
players = {} -- 存储玩家信息，格式为：[玩家ID] = 玩家对象gateplayer。若agent发来消息，只要附带着玩家id，gateway即可由playerid索引到gateplayer对象，进而通过conn属性找到对应的连接及其fd，向对应客户端发送消息。

-- 连接类的构造函数
function conn()
    local m = {
        fd = nil, -- 文件描述符
        playerid = nil -- 玩家ID
    }
    return m
end

-- 玩家类的构造函数
function gateplayer()
    local m = {
        playerid = nil, -- 玩家ID
        agent = nil, -- 玩家代理
        conn = nil -- 玩家连接
    }
    return m
end

local str_pack = function(cmd, msg)
    return table.concat(msg, ",") .. "\r\n"
end


local str_unpack = function(msgstr)
    local msg = {}

    while true do
        local arg, rest = string.match(msgstr, "(.-),(.*)")
        if arg then
            msgstr = rest
            table.insert(msg, arg)
        else
            table.insert(msg, msgstr)
            break
        end
    end

    return msg[1], msg
end

-- send_by_fd方法：用于login服务的消息转发，将消息发送到指定的客户端fd。
-- @param source 消息发送方，例如 "login1"。
-- @param fd 客户端的文件描述符。
-- @param msg 要发送的消息内容。
s.resp.send_by_fd = function(source, fd, msg)
    -- 如果fd对应的连接不存在，则直接返回
    if not conns[fd] then
        return
    end

    -- 使用str_pack函数对消息进行编码
    local buff = str_pack(msg[1], msg)
    -- 打印发送的消息内容，用于调试
    skynet.error("send " .. fd .. " [" .. msg[1] .. "] {" .. table.concat(msg, ",") .. "}")
    -- 使用socket.write函数将编码后的消息发送给客户端
    socket.write(fd, buff)
end

-- send方法：用于agent的消息转发，将消息发送给指定玩家id的客户端。
-- @param source 消息发送方。
-- @param playerid 目标玩家的id。
-- @param msg 要发送的消息内容。
s.resp.send = function(source, playerid, msg)
    -- 根据玩家id查找对应的玩家信息
    local gplayer = players[playerid]
    -- 如果玩家不存在，则直接返回
    if gplayer == nil then
        return
    end
    -- 获取玩家对应的连接信息
    local c = gplayer.conn
    -- 如果连接信息不存在，则直接返回
    if c == nil then
        return
    end

    -- 调用send_by_fd函数，将消息发送到玩家对应的客户端fd
    s.resp.send_by_fd(nil, c.fd, msg)
end

--- 确认代理服务。
-- 确保玩家的代理服务已经被正确设置，并将玩家信息注册到网关。
-- @param source 消息发送方。
-- @param fd 客户端连接标识。
-- @param playerid 已登录的角色（玩家）ID。
-- @param agent 处理该角色的代理服务ID。
-- @return boolean 返回是否成功关联玩家ID和fd。
s.resp.sure_agent = function(source, fd, playerid, agent)
  -- 查找对应的客户端连接
  local conn = conns[fd]
  -- 如果在登录过程中玩家已经下线，则请求踢出玩家
  if not conn then
    skynet.call("agentmgr", "lua", "reqkick", playerid, "未完成登陆即下线")
    return false
  end

  -- 将玩家ID关联到连接上
  conn.playerid = playerid

  -- 创建一个新的gateplayer对象，并设置其属性
  local gplayer = gateplayer()
  gplayer.playerid = playerid
  gplayer.agent = agent
  gplayer.conn = conn
  -- 将gateplayer对象注册到players表中，完成玩家的注册
  players[playerid] = gplayer

  return true
end

--- 断开连接处理。
-- 当agentmgr决定踢出玩家或玩家正常断线时，此函数被调用以清理玩家的连接信息。
-- @param fd 客户端连接的文件描述符。
local disconnect = function(fd)
  -- 获取对应的连接对象
  local c = conns[fd]
  -- 如果连接不存在，则直接返回
  if not c then
    return
  end

  -- 获取玩家ID
  local playerid = c.playerid
  if not playerid then
    -- 玩家还未完成登录，无需进一步处理
    return
  else
    -- 玩家已在游戏中，需要进行清理操作
    -- 从玩家列表中移除玩家信息
    players[playerid] = nil
    -- 设置踢出原因
    local reason = "断线"
    -- 通知agent管理器踢出玩家
    skynet.call("agentmgr", "lua", "reqkick", playerid, reason)
  end
end

--- 踢出玩家。
-- 当需要强制玩家下线时调用此函数，它会清理玩家的连接信息并关闭连接。
-- @param source 调用源的标识。
-- @param playerid 被踢出玩家的ID。
s.resp.kick = function(source, playerid)
  -- 尝试获取被踢玩家的信息
  local gplayer = players[playerid]
  -- 如果玩家信息不存在，则直接返回
  if not gplayer then
    return
  end

  -- 获取玩家的连接对象
  local c = gplayer.conn
  -- 从玩家列表中移除该玩家
  players[playerid] = nil

  -- 如果连接对象不存在，则直接返回
  if not c then
    return
  end
  -- 从连接列表中移除该连接
  conns[c.fd] = nil

  -- 调用disconnect函数处理玩家断开连接的逻辑
  disconnect(c.fd)
  -- 关闭玩家的socket连接
  socket.close(c.fd)
end

-- 处理接收到的消息
local process_msg = function(fd, msgstr)
    -- 解析消息字符串，获取命令和消息内容
    local cmd, msg = str_unpack(msgstr)
    -- 打印接收到的消息
    skynet.error("recv " .. fd .. " [" .. cmd .. "] {" .. table.concat(msg, ",") .. "}")

    -- 获取当前连接对应的玩家信息
    local conn = conns[fd]
    local playerid = conn.playerid
    -- 如果玩家尚未完成登录流程
    if not playerid then
        -- 随机选择一个登录服务器进行登录
        local node = skynet.getenv("node")
        local nodecfg = runconfig[node]
        local loginid = math.random(1, #nodecfg.login)
        local login = "login" .. loginid
        -- 向登录服务器发送消息
        skynet.send(login, "lua", "client", fd, cmd, msg)
    else
        -- 如果玩家已经登录，获取玩家的代理服务器信息
        local gplayer = players[playerid]
        local agent = gplayer.agent
        -- 向代理服务器发送消息
        skynet.send(agent, "lua", "client", cmd, msg)
    end
end

local process_buff = function(fd, readbuff)
    -- 循环处理缓冲区中的数据
    while true do
        -- 使用正则表达式分割消息和剩余数据
        -- msgstr为完整的一条消息，rest为剩余的消息缓冲区内容
        local msgstr, rest = string.match(readbuff, "(.-)\r\n(.*)")
        if msgstr then
            -- 如果成功提取到一条消息
            readbuff = rest -- 更新缓冲区为剩余的内容
            process_msg(fd, msgstr) -- 处理提取出的消息
        else
            -- 如果没有更多完整的消息可以提取，返回当前的缓冲区内容
            return readbuff
        end
    end
end

-- 每一条连接接收数据处理
-- 协议格式 cmd,arg1,arg2,...#
local recv_loop = function(fd)
    -- 初始化：开启socket连接，并定义readbuff作为数据缓冲区
    socket.start(fd)
    skynet.error("socket connected " .. fd)
    local readbuff = ""
    while true do
        -- 循环：尝试从socket中读取数据
        local recvstr = socket.read(fd)
        if recvstr then
            -- 若有数据：接收到的数据追加到readbuff中
            readbuff = readbuff .. recvstr
            -- 调用process_buff处理readbuff中的数据，返回未处理的剩余数据
            readbuff = process_buff(fd, readbuff)
        else
            -- 若断开连接：记录日志，调用disconnect处理断开连接的事务，关闭socket
            skynet.error("socket close " .. fd)
            disconnect(fd)
            socket.close(fd)
            return
        end
    end
end

-- 当有新的客户端连接时的处理函数
local connect = function(fd, addr)
    print("connect from " .. addr .. " " .. fd) -- 打印连接来源的地址和文件描述符
    local c = conn() -- 创建一个新的连接对象
    conns[fd] = c -- 将新连接对象与文件描述符关联
    c.fd = fd -- 设置连接对象的文件描述符属性
    skynet.fork(recv_loop, fd) -- 开启一个新的协程来处理接收到的数据
end

function s.init()
    -- 获取配置文件中的节点名，例如 "node1"
    local node = skynet.getenv("node")
    -- 根据节点名获取节点配置，配置内容可能包括gateway、login等
    local nodecfg = runconfig[node]
    -- 获取当前服务（gateway）要监听的端口号
    local port = nodecfg.gateway[s.id].port

    -- 在指定端口上监听，准备接收客户端连接
    local listenfd = socket.listen("0.0.0.0", port)
    -- 打印监听状态，包括监听的地址和端口
    skynet.error("Listen socket :", "0.0.0.0", port)
    -- 当有客户端连接时，调用connect方法处理该连接
    socket.start(listenfd, connect)
end

s.start(...)

--[[ 带有粘包处理
function process_msgbuff(id, msgbuff)
    skynet.error("process_msgbuff" .. msgbuff)

    local cmd, msg = jspack.unpack(msgbuff)

    print(cmd)
    print(msg.hello)
    print(msg.a)
    --socket.write(id, msgbuff)
    --分发
end

function process_buff(id, readbuff)
    while true do
        local bufflen = string.len(readbuff)
        if bufflen < 2 then
            break
        end
        local len, remain = string.unpack(string.format("> i2 c%d", bufflen-2), readbuff)
        if bufflen < len then
            break
        end

        local str, nextbuff = string.unpack(string.format("> c%d c%d", len, bufflen-2-len), remain)
        readbuff = nextbuff or ""

        process_msgbuff(id, str)
    end
    return  readbuff
end

--每一条连接做处理
function run(id)
    socket.start(id)
    local readbuff = ""
	while true do
		local str = socket.read(id)
        if str then
            readbuff = readbuff..str
            skynet.error("recv " ..str)
            readbuff = process_buff(id, readbuff)
        else
            skynet.error("close " ..id)
            socket.close(id)
            return
		end
	end
end
--]]
