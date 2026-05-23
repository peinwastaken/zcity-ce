local languageCvar = CreateClientConVar("zc_language", "en", true, false, "Changes the language (after changing type \"retry\" in console)")

local locale = {}
zb.locale = locale or {}

local LOCALE_PATH = "gamemodes/zcity_ce/gamemode/locales"

/*
{
  "metadata": {
    "id": "en",
    "name": "English",
    "nativeName": "English"
  },
  "localeKeys": {
    "locale_key1": "locale entry",
    "locale_key2": "locale entry",
    "locale_key3": "locale entry",
  }
}
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

function locale.GetLocale(id)
  local lang = locale.GetCurrentLanguage()
  return lang.localeKeys[id] or id
end

function locale.GetLocaleNativeNames()
  local names = {}

  for id, locale in pairs(locale.locales) do
    names[id] = locale.metadata.nativeName
  end
  
  return names
end

function string.Localize(str)
  return 
end

locale.LoadAll()