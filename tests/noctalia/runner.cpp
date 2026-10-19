#include <Luau/Compiler.h>
#include <lua.h>
#include <lualib.h>
#include <nlohmann/json.hpp>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_map>
#include <ctime>

// Extracted from the pinned host by build-runner.py, not a mock JSON codec.
#include "host-json.inc"
#include "host-props.inc"
#include "scripting/ui_prelude.h"

namespace fs = std::filesystem;
static std::unordered_map<std::string, int> modules;
static double deadline = 0;

static double cpuMilliseconds() {
    timespec time{};
    clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time);
    return time.tv_sec * 1000.0 + time.tv_nsec / 1000000.0;
}

static void interrupt(lua_State* L, int) {
    if (deadline && cpuMilliseconds() > deadline) {
        deadline = 0;
        luaL_error(L, "callback exceeded the pinned host CPU budget");
    }
}

static int withBudget(lua_State* L) {
    const double budget = luaL_checknumber(L, 2);
    lua_pushvalue(L, 1);
    const double started = cpuMilliseconds();
    deadline = started + budget;
    const int result = lua_pcall(L, 0, 0, 0);
    const double elapsed = cpuMilliseconds() - started;
    deadline = 0;
    if (result) luaL_error(L, "%s", lua_tostring(L, -1));
    lua_pushnumber(L, elapsed);
    return 1;
}

static void validateTree(const nlohmann::json& node) {
    static const auto schema = nlohmann::json::parse(hostProps);
    const std::string type = node.at("type");
    if (!schema.contains(type)) throw std::runtime_error("unrecognized control " + type);
    for (const auto& [key, value] : node.at("props").items()) {
        if (std::find(schema[type].begin(), schema[type].end(), key) == schema[type].end())
            throw std::runtime_error("unsupported " + type + " prop " + key);
    }
    for (const auto& child : node.at("children")) validateTree(child);
}

static int checkTree(lua_State* L) {
    try { validateTree(luaToJson(L, 1)); return 0; }
    catch (const std::exception& error) { luaL_error(L, "%s", error.what()); }
}

static std::string read(const fs::path& path) {
    std::ifstream file(path);
    if (!file) throw std::runtime_error("cannot read " + path.string());
    std::stringstream contents;
    contents << file.rdbuf();
    return contents.str();
}

static void execute(lua_State* L, const fs::path& path, int results) {
    auto bytecode = Luau::compile(read(path));
    if (luau_load(L, ("@" + path.string()).c_str(), bytecode.data(), bytecode.size(), 0)
        || lua_pcall(L, 0, results, 0)) {
        throw std::runtime_error(lua_tostring(L, -1));
    }
}

static int requireModule(lua_State* L);

static void installRequire(lua_State* L, const fs::path& directory) {
    lua_pushstring(L, directory.c_str());
    lua_pushcclosure(L, requireModule, "require", 1);
    lua_setglobal(L, "require");
}

static int requireModule(lua_State* L) {
    try {
        const std::string name = luaL_checkstring(L, 1);
        if ((!name.starts_with("./") && !name.starts_with("../")) || !name.ends_with(".luau"))
            throw std::runtime_error("require must use an explicit relative .luau path");
        const auto path = fs::weakly_canonical(fs::path(lua_tostring(L, lua_upvalueindex(1))) / name);
        if (auto found = modules.find(path.string()); found != modules.end()) {
            lua_getref(L, found->second);
            return 1;
        }
        lua_State* module = lua_newthread(L);
        luaL_sandboxthread(module);
        installRequire(module, path.parent_path());
        execute(module, path, 1);
        if (lua_isnil(module, -1)) throw std::runtime_error("module returned nil");
        lua_xmove(module, L, 1);
        modules[path.string()] = lua_ref(L, -1);
        return 1;
    } catch (const std::exception& error) {
        luaL_error(L, "%s", error.what());
    }
}

static int loadEntry(lua_State* L) {
    try {
        const auto path = fs::absolute(luaL_checkstring(L, 1));
        lua_State* entry = lua_newthread(L);
        luaL_sandboxthread(entry);
        installRequire(entry, path.parent_path());
        execute(entry, path, 0);
        lua_pushvalue(entry, LUA_GLOBALSINDEX);
        lua_xmove(entry, L, 1);
        return 1;
    } catch (const std::exception& error) {
        luaL_error(L, "%s", error.what());
    }
}

static int encode(lua_State* L) {
    try {
        const auto value = luaToJson(L, 1).dump();
        lua_pushlstring(L, value.data(), value.size());
        return 1;
    } catch (const nlohmann::json::exception& error) {
        lua_pushnil(L); lua_pushstring(L, error.what()); return 2;
    }
}

static int decode(lua_State* L) {
    try {
        size_t length;
        const char* value = luaL_checklstring(L, 1, &length);
        jsonToLua(L, nlohmann::json::parse(value, value + length));
        return 1;
    } catch (const nlohmann::json::exception& error) {
        lua_pushnil(L); lua_pushstring(L, error.what()); return 2;
    }
}

int main(int argc, char** argv) {
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    lua_callbacks(L)->interrupt = interrupt;
    try {
        lua_pushcfunction(L, encode, "encode"); lua_setglobal(L, "encode");
        lua_pushcfunction(L, decode, "decode"); lua_setglobal(L, "decode");
        lua_pushcfunction(L, loadEntry, "loadEntry"); lua_setglobal(L, "loadEntry");
        lua_pushcfunction(L, withBudget, "withBudget"); lua_setglobal(L, "withBudget");
        lua_pushcfunction(L, checkTree, "checkTree"); lua_setglobal(L, "checkTree");
        auto prelude = Luau::compile(scripting::kUiPrelude);
        if (luau_load(L, "ui", prelude.data(), prelude.size(), 0) || lua_pcall(L, 0, 0, 0))
            throw std::runtime_error(lua_tostring(L, -1));
        const bool check = argc > 1 && std::string(argv[1]) == "--check";
        for (int i = check ? 2 : 1; i < argc; ++i) {
            const auto path = fs::absolute(argv[i]);
            if (check) {
                const auto bytes = Luau::compile(read(path));
                if (luau_load(L, argv[i], bytes.data(), bytes.size(), 0))
                    throw std::runtime_error(lua_tostring(L, -1));
                lua_pop(L, 1);
            } else {
                installRequire(L, path.parent_path());
                execute(L, path, 0);
            }
        }
        lua_close(L);
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        lua_close(L);
        return 1;
    }
}
