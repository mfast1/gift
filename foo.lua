api_panel = {}
api_panel.url=#
api_panel.key=#
api_panel.id=#

function api_panel.getusers(node_id)
    return api_panel.url.."/api_mfast/users?key="..api_panel.key.."&node_id=" .. node_id
end

json = require("dkjson")
Gusers = {}

-- function serializeTable(val, name, skipnewlines, depth)
--     skipnewlines = skipnewlines or false
--     depth = depth or 0
--     local tmp = string.rep(" ", depth)
--     if name then tmp = tmp .. name .. " = " end
--     if type(val) == "table" then
--         tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

--         for k, v in pairs(val) do
--             tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
--         end
--         tmp = tmp .. string.rep(" ", depth) .. "}"
--     elseif type(val) == "number" then
--         tmp = tmp .. tostring(val)
--     elseif type(val) == "string" then
--         tmp = tmp .. string.format("%q", val)
--     elseif type(val) == "boolean" then
--         tmp = tmp .. (val and "true" or "false")
--     else
--         tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
--     end
--     return tmp
-- end

local function get_users(node_id)
    local users = {}
    local response_body = {}
    local https = require("ssl.https")
    local ltn12 = require("ltn12")
    https.TIMEOUT=10
    local res, code, headers = https.request{
        url = api_panel.getusers(node_id),
        method = "GET",
        sink = ltn12.sink.table(response_body),
        protocol = "sslv23"
    }
    if res ~= 1 or code ~= 200 then
        return nil
    end
    if type(response_body) == "table" then
        response_body = table.concat(response_body)
    else
        print("Not a table:", type(response_body))
        return nil
    end
    local result, pos, err = json.decode(response_body, 1, nil)
    if err then
        return nil
    end
    for k,v in pairs(result["data"]) do
        users[v["tlshost"]] = v["id"]
    end
    core.Debug("get_users!")
    return users
end

local function update_users()
    local tbl = {}
    for node_id in string.gmatch(api_panel.id, "[^,]*") do
        local new_users = get_users(node_id)
        if new_users == nil then
            return
        end
        Gusers[node_id] = new_users
        core.Debug("update_users!")
    end
end

local function update_users_work()
    while true do
        core.sleep(60)
        update_users()
    end
end

local function get_user_id(sni, node_id)
    local tlshost = string.sub(sni, 1, 32)
    if Gusers[node_id] ~= nil then
        if Gusers[node_id][tlshost] ~= nil then
            return Gusers[node_id][tlshost]
        end
    end
    return "0"
end

local function check_user(txn, node_id)
    local sni = txn.f:ssl_fc_sni()
    local user = nil
    if sni ~= nil and string.len(sni) > 32 then
        local tlshost = string.sub(sni,1, 32)
        if Gusers[node_id] ~= nil then
            if Gusers[node_id][tlshost] ~= nil then
                core.Debug("check_user good, node:" .. node_id)
                return false
            end
        end
    end
    core.Debug("check_user bad!")
    return true
end

update_users()
core.register_fetches("check_user", check_user)
core.register_converters("get_user_id", get_user_id)
core.register_task(update_users_work)
