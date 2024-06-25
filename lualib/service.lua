local skynet = require "skynet"
local cluster = require "skynet.cluster"

local M = {
    -- 服务的名称和ID
    name = "",
    id = 0,
    -- 服务的回调函数，包括退出和初始化回调
    exit = nil, -- 当服务退出时调用的函数
    init = nil, -- 当服务初始化时调用的函数
    -- 服务的响应方法集合，用于分发处理不同的请求
    resp = {}
}

--[[
function exit_dispatch()
	if M.exit then
		M.exit()
	end
	skynet.ret()
	skynet.exit()
end
--]]

function traceback(err)
    skynet.error(tostring(err))
    skynet.error(debug.traceback())
end

-- 消息分发函数
-- @param session 会话ID，用于标识请求和响应
-- @param address 发送消息的来源地址
-- @param cmd 请求的命令或方法名
-- @param ... 请求的参数
local dispatch = function(session, address, cmd, ...)
    -- 从响应方法集合中查找对应的处理函数
    local fun = M.resp[cmd]
    -- 如果没有找到处理函数，直接返回
    if not fun then
        skynet.ret()
        return
    end

    -- 使用xpcall调用处理函数，以捕获任何错误。第一个参数是调用的函数，第二个是错误处理函数
    local ret = table.pack(xpcall(fun, traceback, address, ...))
    local isok = ret[1] -- xpcall的调用结果，成功为true，失败为false

    -- 如果调用失败，直接返回
    if not isok then
        skynet.ret()
        return
    end

    -- 如果调用成功，将结果打包返回给调用者
    skynet.retpack(table.unpack(ret, 2))
end

-- 初始化函数
function init()
    -- 设置消息分发的处理方式，当接收到lua类型的消息时，调用dispatch函数进行处理
    skynet.dispatch("lua", dispatch)
    -- 如果模块M定义了init初始化函数，则调用该函数进行额外的初始化操作
    if M.init then
        M.init()
    end
end

-- 调用服务的函数 适用于“需要请求并等待结果”的场景。
-- @param node 接收方所在的节点
-- @param srv 接收方的服务名
-- @param ... 传递给服务的参数
function M.call(node, srv, ...)
    local mynode = skynet.getenv("node") -- 获取当前节点名称
    if node == mynode then
        -- 如果目标服务在当前节点，使用skynet.call进行本地调用
        return skynet.call(srv, "lua", ...)
    else
        -- 如果目标服务在其他节点，使用cluster.call进行远程调用
        return cluster.call(node, srv, ...)
    end
end

-- 发送消息给服务的函数 适用于“只需通知，不关心结果”的场景
-- @param node 接收方所在的节点
-- @param srv 接收方的服务名
-- @param ... 传递给服务的参数
function M.send(node, srv, ...)
    local mynode = skynet.getenv("node") -- 获取当前节点名称
    if node == mynode then
        -- 如果目标服务在当前节点，使用skynet.send进行本地消息发送
        return skynet.send(srv, "lua", ...)
    else
        -- 如果目标服务在其他节点，使用cluster.send进行远程消息发送
        return cluster.send(node, srv, ...)
    end
end

-- 启动服务的函数
-- @param name 服务的名称
-- @param id 服务的ID
-- @param ... 传递给服务初始化函数的额外参数
function M.start(name, id, ...)
    M.name = name -- 设置服务名称
    M.id = tonumber(id) -- 将ID转换为数字并设置
    skynet.start(init) -- 使用Skynet框架的start方法启动服务，传入初始化函数
end

return M
