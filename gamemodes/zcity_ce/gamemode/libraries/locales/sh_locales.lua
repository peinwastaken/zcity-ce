local languageCvar = CLIENT and CreateClientConVar("zc_language", "en", true, false, "Changes the language (after changing type \"retry\" in console)") or {
  GetString = function()
    return "en"
  end
}

local locale = {}
zb.locale = locale or {}

local LOCALE_PATH = "gamemodes/zcity_ce/gamemode/locales"

/*
"en": {
  "metadata": {
    "id": "en",
    "name": "English",
    "nativeName": "English"
  },
  "localeKeys": {
    "locale_key1": "hi, im a locale entry",
    "locale_key2": "locale entry",
    "locale_key3": "locale entry",
  }
}
*/

/*
  zb.locale.GetLocalized("locale_key1") -> "hi, im a locale entry"
  zb.locale.GetLocalized("locale_key_missing") -> "locale_key_missing"
*/

locale.locales = {}

function locale.LoadAll()
  local searchPath = LOCALE_PATH .. "/*.json"
  local files = file.Find(searchPath, "GAME")

  for _, fileName in ipairs(files) do
    local fullPath = LOCALE_PATH .. "/" .. fileName
    local id = string.Split(fileName, ".")[1]
    local json = file.Read(fullPath, "GAME")
    local localeTbl = util.JSONToTable(json)

    locale.locales[id] = localeTbl
  end
end

function locale.GetCurrentLanguage()
  return locale.locales[languageCvar:GetString()] or locale.Get("en")
end

function locale.Get(id)
  return locale.locales[id]
end

function locale.GetLocalized(id, ...)
  local lang = locale.GetCurrentLanguage()
  if !lang or !lang.localeKeys then return id end

  local entry = lang.localeKeys[id]
  if !entry then return id end

  local args = {...}

  return string.format(entry, unpack(args))
end

function locale.GetLocaleNativeNames()
  local names = {}

  for id, localeTbl in pairs(locale.locales) do
    names[id] = (localeTbl.metadata and (localeTbl.metadata.nativeName or localeTbl.metadata.name)) or id
  end
  
  return names
end

function string.Localize(str, ...)
  return locale.GetLocalized(str, ...)
end

locale.LoadAll()
