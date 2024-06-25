local skynet = require "skynet"
local s = require "service"

local balls = {} -- [playerid] = ball
local foods = {} -- [id] = food
local food_maxid = 0
local food_count = 0
-- 球
function ball()
    local m = {
        playerid = nil,
        node = nil,
        agent = nil,
        x = math.random(0, 100),
        y = math.random(0, 100),
        size = 2,
        speedx = 0,
        speedy = 0
    }
    return m
end

-- 食物
function food()
    local m = {
        id = nil,
        x = math.random(0, 100),
        y = math.random(0, 100)
    }
    return m
end

-- 球列表
local function balllist_msg()
    local msg = {"balllist"}
    for i, v in pairs(balls) do
        table.insert(msg, v.playerid)
        table.insert(msg, v.x)
        table.insert(msg, v.y)
        table.insert(msg, v.size)
    end
    return msg
end

-- 食物列表
local function foodlist_msg()
    local msg = {"foodlist"}
    for i, v in pairs(foods) do
        table.insert(msg, v.id)
        table.insert(msg, v.x)
        table.insert(msg, v.y)
    end
    return msg
end

-- 广播
function broadcast(msg)
    for i, v in pairs(balls) do
        s.send(v.node, v.agent, "send", msg)
    end
end

-- 进入战斗场景
s.resp.enter = function(source, playerid, node, agent)
    -- 1）判定能否进入战斗场景
    if balls[playerid] then
        -- 如果玩家已在战场内，不可再次进入，返回失败信息（false）
        return false
    end

    -- 2）创建ball对象
    local b = ball() -- 创建玩家对应的ball对象
    b.playerid = playerid -- 玩家ID
    b.node = node -- 节点信息
    b.agent = agent -- 代理信息

    -- 3）向战场内的其他玩家广播enter协议
    local entermsg = {"enter", playerid, b.x, b.y, b.size} -- 构造enter消息
    broadcast(entermsg) -- 广播enter消息

    -- 4）将ball对象存入balls表
    balls[playerid] = b -- 记录玩家的ball对象

    -- 5）向玩家回应成功进入的信息
    local ret_msg = {"enter", 0, "进入成功"} -- 构造成功进入的回应消息
    s.send(b.node, b.agent, "send", ret_msg) -- 向agent发送成功进入的消息

    -- 6）向玩家发送战场信息
    s.send(b.node, b.agent, "send", balllist_msg()) -- 发送战场中的ball列表
    s.send(b.node, b.agent, "send", foodlist_msg()) -- 发送战场中的food列表

    return true -- 返回成功进入的信息
end

-- 玩家离开战斗场景
-- 当玩家需要离开战斗场景时，该函数被调用。
-- @param source 发起离开请求的服务地址。
-- @param playerid 玩家的唯一标识ID。
s.resp.leave = function(source, playerid)
    -- 检查玩家是否在战场中
    if not balls[playerid] then
        -- 如果玩家不在战场中，返回失败信息（false）
        return false
    end
    -- 将玩家从战场中移除
    balls[playerid] = nil

    -- 构造离开消息
    local leavemsg = {"leave", playerid}
    -- 向战场内的其他玩家广播离开消息
    broadcast(leavemsg)
end

-- 改变球体的速度
-- 当玩家需要改变其球体在战斗场景中的速度时，该函数被调用。
-- @param source 发起速度改变请求的服务地址。
-- @param playerid 玩家的唯一标识ID。
-- @param x 球体在x轴方向上的速度。
-- @param y 球体在y轴方向上的速度。
s.resp.shift = function(source, playerid, x, y)
    local b = balls[playerid]
    if not b then
        return false
    end
    b.speedx = x
    b.speedy = y
end

--- 更新食物状态。
-- 服务端会每隔一小段时间放置一个新食物，此方法用于实现该功能。
function food_update()
    -- 判断食物总量：场景中最多能有50个食物，多了就不再生成。
    if food_count > 50 then
        return
    end

    -- 控制生成时间：计算一个0到100的随机数，只有大于等于98才往下执行，即往下执行的概率是1/50。
    -- 由于主循环每0.2秒调用一次food_update，因此平均下来每10秒会生成一个食物。
    if math.random(1, 100) < 98 then
        return
    end

    -- 生成食物：创建food类型对象f，把它添加到foods列表中，并广播addfood协议。
    -- 生成食物时，会更新食物总量food_count和食物最大标识food_maxid。
    food_maxid = food_maxid + 1
    food_count = food_count + 1
    local f = food()
    f.id = food_maxid
    foods[f.id] = f

    -- 广播addfood协议，通知所有客户端添加新食物。
    local msg = {"addfood", f.id, f.x, f.y}
    broadcast(msg)
end

function move_update()
    for i, v in pairs(balls) do
        v.x = v.x + v.speedx * 0.2
        v.y = v.y + v.speedy * 0.2
        if v.speedx ~= 0 or v.speedy ~= 0 then
            local msg = {"move", v.playerid, v.x, v.y}
            broadcast(msg)
        end
    end
end

--- 吃食物更新。
-- 遍历所有的球和食物，判断小球是否和食物发生了碰撞。
function eat_update()
    for pid, b in pairs(balls) do -- 遍历所有球
        for fid, f in pairs(foods) do -- 遍历所有食物
            -- 使用两点间距离公式判断球和食物是否碰撞
            if (b.x - f.x) ^ 2 + (b.y - f.y) ^ 2 < b.size ^ 2 then
                -- 如果发生碰撞，球的大小增加
                b.size = b.size + 1
                -- 食物总量减少
                food_count = food_count - 1
                -- 广播eat协议，通知所有客户端
                local msg = {"eat", b.playerid, fid, b.size}
                broadcast(msg)
                -- 让食物消失
                foods[fid] = nil
            end
        end
    end
end

function update(frame)
    food_update()
    move_update()
    eat_update()
    -- 碰撞略
    -- 分裂略
end

s.init = function()
    skynet.fork(function()
        -- 保持帧率执行
        local stime = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local isok, err = pcall(update, frame)
            if not isok then
                skynet.error(err)
            end
            local etime = skynet.now()
            local waittime = frame * 20 - (etime - stime)
            if waittime <= 0 then
                waittime = 2
            end
            skynet.sleep(waittime)
        end
    end)
end

s.start(...)
