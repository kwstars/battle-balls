local skynet = require "skynet"
local s = require "service"

--- 创建新的服务。
-- 该函数是nodemgr节点管理服务的远程调用接口，用于创建新的服务实例。
-- @param source 调用来源的服务地址。
-- @param name 新服务的名称。
-- @param ... 传递给新服务的参数。
-- @return number 新建服务的ID。
s.resp.newservice = function(source, name, ...)
    -- 使用skynet框架的newservice方法创建新服务
    local srv = skynet.newservice(name, ...)
    -- 返回新建服务的ID
    return srv
end

s.start(...)
