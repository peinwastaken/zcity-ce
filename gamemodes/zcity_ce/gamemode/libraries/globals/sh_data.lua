local zc = zc or {}

local GAMEMODE_DATA_PATH = "zcity_ce"

function zc.NormalizePath(path)
  return string.Trim(path or "", "/")
end

function zc.GetDataPath(path)
  if !path then
    return GAMEMODE_DATA_PATH
  end

  return GAMEMODE_DATA_PATH .. "/" .. zc.NormalizePath(path)
end

function zc.ParseDataFile(filePath, default)
  local fullPath = zc.GetDataPath(filePath)
  local exists = file.Exists(fullPath, "DATA")

  if !exists then 
    print("failed to find file " .. filePath)
    return default
  end

  local json = file.Read(fullPath, "DATA")
  if !json then return default end

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
    path = zc.NormalizePath(path)
    local split = string.Split(path, "/") // normalize path
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

function zc.DataFileExists(filePath)
  local filePath = zc.GetDataPath(path)
  return file.Exists(filePath, "DATA")
end

function zc.DeleteDataFile(path)
  if !zc.DataFileExists(path) then
    print("file " .. path .. " not found")
    return false
  end

  local dataPath = zc.GetDataPath(path)
  return file.Delete(dataPath, "DATA")
end

function zc.GetDataFiles(dir, pattern)
  pattern = pattern or "*"

  local dataPath = zc.GetDataPath(dir)
  return file.Find(string.format("%s/%s", dataPath, pattern), "DATA")
end

function zc.ReadDataFile(filePath)
  local dataPath = zc.GetDataPath(filePath)
  return file.Read(dataPath, "DATA")
end