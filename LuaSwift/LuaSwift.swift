//
//  LuaSwift.swift
//  acroplia
//
//  Created by Roman Petrov on 23/08/2017.
//  Copyright © 2017-2019
//

import Foundation

public enum LuaError: Error {
    case errString(String)
    case errDict([String:String])
    case unknown
    case libraryNotFound(String)
}

fileprivate var luaSwiftInstances: [OpaquePointer: LuaSwift] = [:]

fileprivate func luaLoader(_ state: OpaquePointer!) -> Int32 {
    guard let instance = luaSwiftInstances[state] else { return 0 }
    guard lua_type(state, -1) == LUA_TSTRING else { return 0 }
    let module = String(cString: lua_tolstring(state, -1, nil))
    guard let moduleCode = instance.moduleLoader(module) else { return 0 }

    let moduleCString = moduleCode.cString(using: .utf8)
    let moduleLength = moduleCString!.count - 1
    let err = luaL_loadbufferx(state, moduleCString, moduleLength, module, nil)
    return err == 0 ? 1 : 0
}

public class LuaSwift {
    let state: OpaquePointer
    let moduleLoader: (String) -> String?

    init(moduleLoader: @escaping (String) -> String?) {
        state = luaL_newstate() // It would be correct to add a check for a result here
        // Construct default loader
        self.moduleLoader = moduleLoader
        
        luaL_openlibs(state)
        
        // Set global var swift_lua_loader
        lua_pushcclosure(state, luaLoader, 0)
        lua_setglobal(state, "swift_lua_loader")
        // Insert custom loader to package.searchers
        pushSymbol("table.insert")
        pushSymbol("package.searchers")
        lua_getglobal(state, "swift_lua_loader")
        lua_pcallk(state, 2, 0, 0, 0, nil)
        
        luaSwiftInstances[state] = self
    }
    
    convenience init(path: String) {
        self.init(moduleLoader: {(module: String) -> String? in
            let moduleFile = module.replacingOccurrences(of: ".", with: "/")
            let modulePath = "\(path)/\(moduleFile).lua"
        
            return try? String(contentsOfFile: modulePath, encoding: .utf8)
        })
    }
    
    deinit {
        luaSwiftInstances[state] = nil
    }

    static func instance(_ luaState: OpaquePointer?) -> LuaSwift? {
        guard let luaState = luaState else { return nil }
        return luaSwiftInstances[luaState]
    }

    func loadGlobalModule(_ name: String, to: String) throws {
        push(name)
        let error = luaLoader(state)
        if error == 0 {
            throw LuaError.libraryNotFound(name)
        }
        remove(at: -2)
        lua_pcallk(state, 0, 1, 0, 0, nil)
        lua_setglobal(state, to)
    }

    func pushCLibrary(_ functions: [String: lua_CFunction]) {
        lua_createtable(state, 0, Int32(functions.count))
        for (key, fn) in functions {
            lua_pushstring(state, key)
            lua_pushcclosure(state, fn, 0)
            lua_settable(state, -3)
        }
    }

    func call0(_ name: String, _ params: [ToLuaValue] = []) throws {
        _ = try call(name, params, 0)
    }

    func call1(_ name: String, _ params: [ToLuaValue] = []) throws -> LuaValue {
        let output = try call(name, params, 1)
        return output[0]
    }

    func call(_ name: String, _ params: [ToLuaValue] = [], _ outCount: Int) throws -> [LuaValue] {
        pushSymbol(name)
        params.forEach { push($0) }

        if lua_pcallk(state, Int32(params.count), Int32(outCount), 0, 0, nil) != 0 {
            let type = lua_type(state, -1)
            var error: LuaError
            switch type {
            case LUA_TSTRING:
                error = LuaError.errString(peek().stringValue)
            case LUA_TTABLE:
                var errData: [String: String] = [:]
                lua_pushnil(state)
                while lua_next(state, -2) != 0 {
                    lua_pushvalue(state, -2)
                    let key = peek().stringValue
                    let value = peek(at: -2).stringValue
                    errData[key] = value
                    drop(2)
                }
                drop()
                error = LuaError.errDict(errData)
            default:
                error = LuaError.unknown
            }
            drop()
            throw error
        }

        var output: [LuaValue] = []
        if outCount > 0 {
            for _ in 0..<outCount {
                output.append(pop())
            }
            output.reverse()
        }

        return output
    }

    func push(_ value: LuaValue) {
        switch value {
        case .LNil:
            lua_pushnil(state)
        case .LInt(let number):
            lua_pushinteger(state, Int64(number))
        case .LInt64(let number):
            lua_pushinteger(state, Int64(number))
        case .LDouble(let number):
            lua_pushnumber(state, number)
        case .LString(let str):
            lua_pushstring(state, str)
        case .LBool(let bool):
            lua_pushboolean(state, bool ? 1 : 0)
        case .LArray(let array):
            lua_createtable(state, Int32(array.count), 0)
            for (i, value) in array.enumerated() {
                push(value)
                lua_seti(state, -2, Int64(i + 1))
            }
        case .LDictionary(let dict):
            lua_createtable(state, 0, Int32(dict.count))
            dict.forEach({ (key, value) in
                lua_pushstring(state, key)
                push(value)
                lua_settable(state, -3)
            })
        case .LCFunction(let function):
            lua_pushcclosure(state, function, 0)
        }
    }

    func push(_ value: ToLuaValue) {
        push(value.luaValue)
    }

    func pushSymbol(_ name: String) {
        let names = name.split(separator: ".")
        guard names.count > 0 else { return }

        lua_getglobal(state, String(names[0]))
        if names.count > 1 {
            for i in 1..<names.count {
                lua_getfield(state, -1, String(names[i]))
                remove(at: -2)
            }
        }
    }

    func peek(at index: Int = -1) -> LuaValue {
        let idx = Int32(index)
        let type = lua_type(state, idx)
        var value: LuaValue
        switch type {
        case LUA_TNIL:
            value = .LNil
        case LUA_TNUMBER:
            value = .LDouble(lua_tonumberx(state, idx, nil))
        case LUA_TSTRING:
            value = .LString(String(cString: lua_tolstring(state, idx, nil), encoding: .utf8)!)
        case LUA_TBOOLEAN:
            value = .LBool(lua_toboolean(state, idx) == 1)
        case LUA_TTABLE:
            let count = luaL_len(state, idx)
            if count > 0 {
                var array: [LuaValue] = []
                for i in 1...count {
                    lua_rawgeti(state, idx, i)
                    array.append(pop())
                }
                value = .LArray(array)
                // Array
            } else {
                // Dictionary
                var dict: [String: LuaValue] = [:]
                lua_pushnil(state)
                while lua_next(state, idx < 0 ? idx - 1 : idx) != 0 {
                    lua_pushvalue(state, -2)
                    let key = pop().stringValue
                    let value = pop()
                    dict[key] = value
                }
                //drop()
                value = .LDictionary(dict)
            }
        default:
            value = .LNil
        }
        return value
    }

    func pop() -> LuaValue {
        let value = peek()
        drop()
        return value
    }

    func remove(at index: Int) {
        lua_rotate(state, Int32(index), -1)
        drop()
    }

    func drop(_ count: Int = 1) {
        lua_settop(state, Int32(-count - 1))
    }

    func dump() {
        let top = lua_gettop(state)
        print("--- Lua stack dump: \(top) items ---")
        guard top >= 1 else { return }

        for i in 1...top {
            let t = lua_type(state, i)
            switch t {
            case LUA_TSTRING:
                print(String(cString: lua_tolstring(state, i, nil)))
            case LUA_TBOOLEAN:
                let bstr = lua_toboolean(state, i) == 1 ? "true" : "false"
                print(bstr)
            case LUA_TNUMBER:
                let num = lua_tonumberx(state, i, nil)
                print(num)
            default:
                print(String(cString: lua_typename(state, t)))
            }
        }
        print("---")
    }
}
