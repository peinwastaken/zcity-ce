--if not util.IsBinaryModuleInstalled("mysqloo") then return end

zc.db = zc.db or {}
local SQL_CONFIG_PATH = "config/sql.json"

function zc.db.Connect()
    local standart_tbl = {
            dbmodule = "sqlite",
            hostname = "your_MySQLServerAddres",
            username = "your_username",
            password = "your_password",
            database = "your_db",
            port = 3306
        }

    if not zc.DataFileExists(SQL_CONFIG_PATH) then
        zc.WriteData(SQL_CONFIG_PATH, standart_tbl, true)
    end

    local cfg = zc.ParseDataFile(SQL_CONFIG_PATH, standart_tbl)

    local dbmodule = cfg.dbmodule
    local hostname = cfg.hostname
    local username = cfg.username
    local password = cfg.password
    local database = cfg.database
    local port = cfg.port

    mysql:SetModule(dbmodule)
    mysql:Connect(hostname, username, password, database, port)
end

hook.Add("InitPostEntity", "ZC_DatabaseConnect", function()
	zc.db.Connect()
end)

--zc.db.Connect()

hook.Add("ZC_OnDatabaseConnected", "ZC_DatabaseThink", function()
    --print("asd")
	timer.Create("zbDatabaseThink", 0.5, 0, function()
		mysql:Think()
	end)
end)
