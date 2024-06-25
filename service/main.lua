local skynet = require "skynet"
local skynet_manager = require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function()
    -- 初始化
    local mynode = skynet.getenv("node") -- 获取当前节点名称
    local nodecfg = runconfig[mynode] -- 获取当前节点的配置信息

    -- 节点管理
    local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0) -- 创建节点管理服务
    skynet.name("nodemgr", nodemgr) -- 为节点管理服务设置别名

    -- 集群
    cluster.reload(runconfig.cluster) -- 重新加载集群配置
    cluster.open(mynode) -- 开启当前节点的集群服务

    -- gate
    for i, v in pairs(nodecfg.gateway or {}) do -- 遍历并启动所有网关服务
        local srv = skynet.newservice("gateway", "gateway", i)
        skynet.name("gateway" .. i, srv) -- 为每个网关服务设置别名
    end

    -- login
    for i, v in pairs(nodecfg.login or {}) do -- 遍历并启动所有登录服务
        local srv = skynet.newservice("login", "login", i)
        skynet.name("login" .. i, srv) -- 为每个登录服务设置别名
    end

    -- agentmgr
    local anode = runconfig.agentmgr.node -- 获取代理管理服务所在节点
    if mynode == anode then -- 如果当前节点是代理管理服务节点
        local srv = skynet.newservice("agentmgr", "agentmgr", 0) -- 创建代理管理服务
        skynet.name("agentmgr", srv) -- 为代理管理服务设置别名
    else -- 如果当前节点不是代理管理服务节点
        local proxy = cluster.proxy(anode, "agentmgr") -- 创建代理管理服务的代理
        skynet.name("agentmgr", proxy) -- 为代理设置别名
    end

    -- scene (sid->sceneid)
    for _, sid in pairs(runconfig.scene[mynode] or {}) do -- 遍历并启动所有场景服务
        local srv = skynet.newservice("scene", "scene", sid)
        skynet.name("scene" .. sid, srv) -- 为每个场景服务设置别名
    end

    -- 退出自身
    skynet.exit() -- 启动完成后，退出当前服务
end)
