return {
    -- cluster项指明服务端系统包含两个节点
    cluster = {
        node1 = "127.0.0.1:7771",
        node2 = "127.0.0.1:7772"
    },
    -- agentmgr项指明全局唯一的agentmgr服务位于节点1处。
    agentmgr = {
        node = "node1"
    },
    -- scene 项指明在节点1开启编号为1001和1002的两个战斗场景服 务，语句“node2={1003}”代表在节点2开启编号为1003的场景服务。 为了方便前期开启单个节点来调试功能，我们先把node2={1003}这行 代码注释掉，用时再开启。
    scene = {
        node1 = {1001, 1002}
        -- node2 = {1003},
    },
    -- 节点1
    node1 = {
        gateway = {
            [1] = {
                port = 8001
            },
            [2] = {
                port = 8002
            }
        },
        login = {
            [1] = {},
            [2] = {}
        }
    },

    -- 节点2
    node2 = {
        gateway = {
            [1] = {
                port = 8011
            },
            [2] = {
                port = 8022
            }
        },
        login = {
            [1] = {},
            [2] = {}
        }
    }
}