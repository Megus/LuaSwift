//
//  LuaSwift2.swift
//  LuaSwift
//
//  Created by Roman Petrov on 08/03/2019.
//  Copyright © 2019 Roman Petrov. All rights reserved.
//

import Foundation

fileprivate var luaSwiftInstances: [OpaquePointer: LuaSwift2] = [:]

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

class LuaSwift2 {
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
    
    static func instance(_ luaState: OpaquePointer?) -> LuaSwift2? {
        guard let luaState = luaState else { return nil }
        return luaSwiftInstances[luaState]
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
    
    func pop<T: Decodable>() -> T? {
        drop()
        return nil
    }
    
    func remove(at index: Int) {
        lua_rotate(state, Int32(index), -1)
        drop()
    }
    
    func drop(_ count: Int = 1) {
        lua_settop(state, Int32(-count - 1))
    }
}
