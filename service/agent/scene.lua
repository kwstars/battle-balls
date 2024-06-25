local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"
local mynode = skynet.getenv("node")

s.snode = nil -- scene_node
s.sname = nil -- scene_id

--- 随机选择场景服务。
-- 为了模拟合适的匹配机制，该方法返回同节点场景服务的概率是其他节点的数倍。
local function random_scene()
    -- 先把所有配置了场景服务的节点都放在表nodes中
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        -- 同一节点（mynode）会插入多次，使它能有更高被选中的概率
        if runconfig.scene[mynode] then
            table.insert(nodes, mynode)
        end
    end
    -- 在nodes表随机选择一个节点（scenenode）
    local idx = math.random(1, #nodes)
    local scenenode = nodes[idx]
    -- 再在选出的节点中随机选出一个场景（sceneid）
    local scenelist = runconfig.scene[scenenode]
    local idx = math.random(1, #scenelist)
    local sceneid = scenelist[idx]
    -- 返回选中的节点和场景ID
    return scenenode, sceneid
end

-- 让玩家进入比赛的功能
s.client.enter = function(msg)
    -- 1）检查玩家是否已经在场景中
    if s.sname then
        -- 如果玩家已在场景中，返回错误信息
        return {"enter", 1, "已在场景"}
    end
    -- 2）调用random_scene随机获取一个场景服务
    local snode, sid = random_scene() -- 获取场景服务的节点和id
    local sname = "scene" .. sid -- 构造场景名

    -- 3）向场景服务发送enter消息，请求进入场景
    local isok = s.call(snode, sname, "enter", s.id, mynode, skynet.self())
    if not isok then
        -- 如果进入失败，返回错误信息
        return {"enter", 1, "进入失败"}
    end
    -- 如果成功进入场景，更新s.snode和s.sname
    s.snode = snode
    s.sname = sname
    -- 成功进入场景，不返回错误信息
    return nil
end

-- 改变方向
s.client.shift = function(msg)
    if not s.sname then
        return
    end
    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.snode, s.sname, "shift", s.id, x, y)
end

s.leave_scene = function()
    -- 不在场景
    if not s.sname then
        return
    end
    s.call(s.snode, s.sname, "leave", s.id)
    s.snode = nil
    s.sname = nil
end
