//
//  LuaSwiftTests.swift
//  LuaSwiftTests
//
//  Created by Roman Petrov on 08/03/2019.
//  Copyright © 2019 Roman Petrov. All rights reserved.
//

import XCTest

import LuaSwift

fileprivate let testModules = [
    "test": """
    local M = {}
    function M.hello()
        print("Hello world")
    end
    
    function M.sum(a, b)
        return a + b
    end
    
    function M.intDivide(a, b)
        local remainder = a % b
        local intResult = (a - remainder) / b
        print(remainder)
        print(intResult)
        return intResult, remainder
    end
    
    return M
    """,
]

class LuaSwiftTests: XCTestCase {
    var lua: LuaSwift!

    override func setUp() {
        lua = LuaSwift(moduleLoader: { (module) -> String? in
            return testModules[module]
        })
        XCTAssertNoThrow(try lua.loadGlobalModule("test", to: "test"))
    }

    override func tearDown() {
        lua = nil
    }

    func testSimplefunctionCall() {
        XCTAssertNoThrow(try lua.call0("test.hello"))
    }
    
    func testSingleReturnFromLuaFunction() {
        do {
            let sum = try lua.call1("test.sum", [2, 3])
            XCTAssert(sum.intValue == 5)
        } catch {
            XCTAssert(false)
        }
    }
    
    func testMultipleReturnFromLuaFunction() {
        do {
            let results = try lua.call("test.intDivide", [5, 2], 2)
            XCTAssert(results.count == 2)
            XCTAssert(results[0].intValue == 2)
            XCTAssert(results[1].intValue == 1)
        } catch {
            XCTAssert(false)
        }
    }

    /*func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }*/
}
