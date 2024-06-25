local skynet = require "skynet"
local s = require "service"

--- 定义玩家状态常量。
-- 用于表示玩家在游戏中的不同状态。
STATUS = {
    LOGIN = 1, -- 登录中：玩家正在尝试登录游戏。
    GAME = 2, -- 游戏中：玩家已成功登录并处于游戏过程中。
    LOGOUT = 3 -- 登出中：玩家正在退出游戏。
}

--- 初始化玩家列表。
-- 用于存储当前所有玩家的状态信息。
local players = {}

--- 创建一个新的玩家管理对象。
-- 该函数用于初始化一个新的玩家对象，包含玩家的基本信息和状态。
-- @return table 返回一个包含玩家信息的表。
function mgrplayer()
    -- 初始化玩家信息结构
    local m = {
        playerid = nil, -- 玩家ID
        node = nil, -- 玩家所在的节点，包括gateway和agent
        agent = nil, -- 玩家对应的agent服务ID
        status = nil, -- 玩家当前的状态，例如“登录中”
        gate = nil -- 玩家对应的gateway ID
    }
    return m
end

--- 处理玩家登录请求的函数。
-- 该函数用于处理玩家的登录请求，包括登录仲裁、顶替已在线玩家、记录在线信息以及创建agent服务。
-- @param source 请求来源。
-- @param playerid 玩家ID。
-- @param node 玩家所在的节点。
-- @param gate 玩家连接的网关。
-- @return boolean, agent 登录是否成功，以及agent服务的ID。
s.resp.reqlogin = function(source, playerid, node, gate)
    -- 尝试获取玩家信息
    local mplayer = players[playerid]
    -- 登录仲裁：判断玩家是否可以登录（仅STATUS.GAME状态）
    if mplayer and mplayer.status ~= STATUS.GAME then
        -- 如果玩家不在游戏中状态，记录错误并返回失败
        skynet.error("reqlogin fail, player is not in GAME status " .. playerid)
        return false
    end
    -- 顶替已在线玩家：如果该角色已在线，需要先把它踢下线
    if mplayer then
        -- 获取玩家所在的节点、代理和网关信息
        local pnode = mplayer.node
        local pagent = mplayer.agent
        local pgate = mplayer.gate
        -- 设置玩家状态为LOGOUT，并发送踢下线的命令
        mplayer.status = STATUS.LOGOUT
        s.call(pnode, pagent, "kick") -- 通知agent处理玩家登出
        s.send(pnode, pagent, "exit") -- 通知agent退出服务
        s.send(pnode, pgate, "send", playerid, {"kick", "顶替下线"}) -- 通知网关踢下线
        s.call(pnode, pgate, "kick", playerid) -- 通知网关踢出玩家
    end
    -- 记录在线信息：将新建的mgrplayer对象记录为STATUS.LOGIN（登录中）状态
    local player = mgrplayer() -- 创建新的玩家对象
    player.playerid = playerid
    player.node = node
    player.gate = gate
    player.agent = nil -- 初始时没有agent
    player.status = STATUS.LOGIN -- 设置状态为登录中
    players[playerid] = player -- 记录玩家信息
    -- 让nodemgr创建agent服务
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
    player.agent = agent -- 记录agent服务ID
    -- 登录完成，设置mgrplayer为STATUS.GAME状态（游戏中）
    player.status = STATUS.GAME
    return true, agent -- 返回成功和agent服务ID
end

--- 请求踢出玩家。
-- 该函数用于处理玩家的登出请求，包括保存数据和退出服务。
-- @param source 请求来源。
-- @param playerid 被踢出玩家的ID。
-- @param reason 踢出的原因。
-- @return boolean 操作是否成功。
s.resp.reqkick = function(source, playerid, reason)
    -- 获取玩家信息
    local mplayer = players[playerid]
    -- 如果玩家不存在，则返回失败
    if not mplayer then
        return false
    end

    -- 如果玩家不在游戏中，则返回失败
    if mplayer.status ~= STATUS.GAME then
        return false
    end

    -- 获取玩家所在的节点、代理和网关
    local pnode = mplayer.node
    local pagent = mplayer.agent
    local pgate = mplayer.gate
    -- 设置玩家状态为登出中
    mplayer.status = STATUS.LOGOUT

    -- 先发送kick命令让agent处理保存数据等事情
    s.call(pnode, pagent, "kick")
    -- 再发送exit命令让agent退出服务
    s.send(pnode, pagent, "exit")
    -- 通知网关踢出玩家
    s.send(pnode, pgate, "kick", playerid)
    -- 从玩家列表中移除该玩家
    players[playerid] = nil

    return true
end

-- 情况 永不下线

s.start(...)
