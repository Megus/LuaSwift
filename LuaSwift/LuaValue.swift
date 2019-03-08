//
//  LuaValue.swift
//  acroplia
//
//  Created by Roman Petrov on 23/08/2017.
//  Copyright © 2017 gxb. All rights reserved.
//

import Foundation

// MARK: LuaValue enum and protocols definition

enum LuaValue: ToLuaValue, CustomStringConvertible, CustomDebugStringConvertible {
    case LNil
    case LBool(Bool)
    case LInt(Int)
    case LInt64(Int64)
    case LDouble(Double)
    case LString(String)
    case LArray([LuaValue])
    case LDictionary([String:LuaValue])
    case LCFunction(lua_CFunction)
    // TODO:
    //case LTable([LuaType:LuaType])
    //case LUserData
    //case LThread
    //case LFunction

    var stringValue: String {
        get {
            switch self {
            case .LNil:
                return "nil"
            case .LDouble(let num):
                return String(num)
            case .LInt(let num):
                return String(num)
            case .LInt64(let num):
                return String(num)
            case .LString(let str):
                return str
            case .LBool(let bool):
                return bool ? "True" : "False"
            default:
                return ""
            }
        }
    }

    var intValue: Int {
        get {
            switch self {
            case .LDouble(let num):
                return Int(num)
            case .LInt(let num):
                return num
            case .LBool(let bool):
                return bool ? 1 : 0
            default:
                return 0
            }
        }
    }

    var int64Value: Int64 {
        get {
            switch self {
            case .LDouble(let num):
                return Int64(num)
            case .LInt64(let num):
                return num
            case .LInt(let num):
                return Int64(num)
            case .LBool(let bool):
                return bool ? 1 : 0
            default:
                return 0
            }
        }
    }

    var doubleValue: Double {
        get {
            switch self {
            case .LDouble(let num):
                return num
            case .LInt(let num):
                return Double(num)
            case .LInt64(let num):
                return Double(num)
            case .LBool(let bool):
                return bool ? 1.0 : 0.0
            default:
                return 0.0
            }
        }
    }

    var boolValue: Bool {
        get {
            switch self {
            case .LDouble(let num):
                return num != 0
            case .LInt(let num):
                return num != 0
            case .LInt64(let num):
                return num != 0
            case .LBool(let bool):
                return bool
            default:
                return false
            }
        }
    }

    var description: String {
        get { return stringValue }
    }

    var debugDescription: String {
        get { return stringValue }
    }

    var luaValue: LuaValue {
        get { return self }
    }
}

protocol ToLuaValue {
    var luaValue: LuaValue { get }
}

protocol FromLuaValue {
    static func fromLuaValue(_ value: LuaValue) -> Self?
}

// MARK: - Extensions for standard types

extension Int: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return LuaValue.LInt(self) }
    }

    static func fromLuaValue(_ luaValue: LuaValue) -> Int? {
        switch luaValue {
        case .LInt(let value):
            return Int(value)
        default:
            return nil
        }
    }
}

extension Int32: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return LuaValue.LInt(Int(self)) }
    }

    static func fromLuaValue(_ value: LuaValue) -> Int32? {
        switch value {
        case .LInt(let value):
            return Int32(value)
        default:
            return nil
        }
    }
}

extension Int64: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return .LInt64(self) }
    }

    static func fromLuaValue(_ value: LuaValue) -> Int64? {
        switch value {
        case .LInt64(let value):
            return Int64(value)
        default:
            return nil
        }
    }
}

extension Double: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return .LDouble(self) }
    }

    static func fromLuaValue(_ luaValue: LuaValue) -> Double? {
        switch luaValue {
        case .LDouble(let value):
            return Double(value)
        case .LInt(let value):
            return Double(value)
        default:
            return nil
        }
    }
}

extension Float: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return .LDouble(Double(self)) }
    }

    static func fromLuaValue(_ luaValue: LuaValue) -> Float? {
        switch luaValue {
        case .LDouble(let value):
            return Float(value)
        case .LInt(let value):
            return Float(value)
        default:
            return nil
        }
    }
}

extension Bool: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return .LBool(self) }
    }

    static func fromLuaValue(_ luaValue: LuaValue) -> Bool? {
        switch luaValue {
        case .LBool(let value):
            return Bool(value)
        default:
            return nil
        }
    }
}

extension String: ToLuaValue, FromLuaValue {
    var luaValue: LuaValue {
        get { return .LString(self) }
    }

    static func fromLuaValue(_ luaValue: LuaValue) -> String? {
        switch luaValue {
        case .LString(let value):
            return String(value)
        default:
            return nil
        }
    }
}
