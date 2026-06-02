local zc = zc or {}

local GAMEMODE_DATA_PATH = "zcity_ce"

function zc.GetDataPath(path)
  if !path then
    return GAMEMODE_DATA_PATH
  end

  return GAMEMODE_DATA_PATH .. "/" .. string.TrimLeft(path, "/")
end

function zc.ParseDataFile(filePath)
  local fullPath = zc.GetDataPath(filePath)
  local exists = file.Exists(fullPath, "DATA")

  if !exists then 
    print("failed to find file " .. filePath)
    return nil
  end

  local json = file.Read(fullPath, "DATA")
  if !json then return nil end

  local tbl = util.JSONToTable(json)
  if !tbl then
    print("failed to parse file " .. filePath)
  end

  return tbl
end

function zc.EnsureDataFile(path)
  local fullPath = zc.GetDataPath(path)
  local exists = file.Exists(fullPath, "DATA")

  if !exists then
    local split = string.Split(string.TrimLeft(path, "/"), "/") // normalize path
    local fileName = table.remove(split, #split) // remove last value (filename)
    local current = zc.GetDataPath()

    for _, dirName in ipairs(split) do
      file.CreateDir(current .. "/" .. dirName)
      current = current .. "/" .. dirName
    end

    local finalPath = current .. "/" .. fileName
    file.Write(finalPath, "")
  end
end

function zc.WriteData(path, data, ensureExists)
  if !data then
    print("no data to write")
    return
  end

  if ensureExists then
    zc.EnsureDataFile(path)
  end
  
  local fullPath = zc.GetDataPath(path)

  // if data is table then convert to json
  data = type(data) == "table" and util.TableToJSON(data) or data or ""

  return file.Write(fullPath, data)
end
