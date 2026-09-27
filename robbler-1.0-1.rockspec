package = "robbler"
version = "1.0-1"
source = { url = "git://github.com/MicasiO/robbler" }
dependencies = { 
        "lua >= 5.4",
        "http",
        "dkjson",
        "md5",
        "luafilesystem",
}
build = {
        type = "builtin",
        modules = {
                ["scrobble"] = "src/scrobble.lua",
                ["files"] = "src/files.lua",
                ["setup"] = "src/setup.lua",
                ["requests"] = "src/requests.lua",
        },
        install = {
                bin = { "bin/robbler" }
        }
}
