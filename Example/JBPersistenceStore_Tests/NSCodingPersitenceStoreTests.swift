//
//  NSCodingPersitenceStoreTests.swift
//  JBPersistenceStore
//
//  Created by Jan Bartel on 08.05.17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import JBPersistenceStore
import JBPersistenceStore_Protocols
import YapDatabase

class NSCodingPersitenceStoreTests: XCTestCase {

    func createStore() -> NSCodingPersistenceStore{
        let uuid = NSUUID.init().uuidString
        let codingStore = NSCodingPersistenceStore(databaseFilename: uuid)
        return codingStore
    }
    
    
    func testcreateStoreCreatesNewFile(){
        let uuid = UUID.init().uuidString
        let store = NSCodingPersistenceStore(databaseFilename: uuid)
        let fullName = store.database.databasePath
        XCTAssert(fileExists(atURL: fullName))
    }
    
    func testVersionChangedHandlerDoesTriggerOnForgottenVersion(){
        let exp = expectation(description: "wait for versionChangeHandler")
        let uuid = UUID().uuidString
        let expectedNewVersion = 3
        let _ = NSCodingPersistenceStore(databaseFilename: uuid)
        self.forgetVersion(ofDatabaseFilename: uuid)
        
        _ = NSCodingPersistenceStore(databaseFilename: uuid,version: expectedNewVersion,changeVersionHandler: {(oldVersion: Int, newVersion: Int) in
            XCTAssert(oldVersion == -1)
            XCTAssert(newVersion == expectedNewVersion)
            exp.fulfill()
        })
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    
    func testVersion() {
        let uuid = NSUUID.init().uuidString
        let codingStore = NSCodingPersistenceStore(databaseFilename: uuid, version: 2) { (old:Int,new:Int) -> Void in }
        XCTAssert(codingStore.version() == 2)
    }
    
    func testAsynchVersionChangedHandlerHasToCallSuccesToSeeVersionchange(){
        let uuid = UUID().uuidString
        let exp = expectation(description: "wait for version change")
        let oldVersion = 0
        let newVersion = 1
        let _ = NSCodingPersistenceStore(databaseFilename: uuid, version: oldVersion)
        
        
        let newStore = NSCodingPersistenceStore(databaseFilename: uuid, version: newVersion) { (updateMe,from, to, success) in
            XCTAssert(updateMe.version() == oldVersion)
            XCTAssert(from == oldVersion)
            XCTAssert(to == newVersion)
            success()
        }
        DispatchQueue.main.async {
            XCTAssert(newStore.version() == newVersion)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testVersionChangeHandlerDoesntTriggerOnDatabaseCreation(){
        let uuid = UUID().uuidString
        _ = NSCodingPersistenceStore(databaseFilename: uuid, version : 2, changeVersionHandler: {
            (from: Int, to: Int)in
            XCTFail("Should not fire on creation")
        })
    }
    
    func testVersionChangedHandlerDoesTriggerOnDatabaseVersionChange(){
        let oldVersion = 2
        let newVersion = 3
        let dbname = NSUUID.init().uuidString
        let exp = expectation(description: "wait for versionchangehandler")
        
        _ = NSCodingPersistenceStore(databaseFilename: dbname, version: oldVersion) { (old:Int,new:Int) -> Void in }
        
        _ = NSCodingPersistenceStore(databaseFilename: dbname, version: newVersion) { (old:Int,new:Int) -> Void in
            XCTAssert(old == oldVersion)
            XCTAssert(new == newVersion)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testVersionChangedHandlerDoesNotTriggerOnStableDatabaseVersion(){
        let uuid = UUID().uuidString
        let version = 2
        
        _ = NSCodingPersistenceStore(databaseFilename: uuid, version : version, changeVersionHandler: {
            (from: Int, to: Int)in
            XCTFail("Should not fire on creation")
        })
        _ = NSCodingPersistenceStore(databaseFilename: uuid, version : version, changeVersionHandler: {
            (from: Int, to: Int)in
            XCTFail("Should not fire on unchangedVersion")
        })
        
    }
    
    
    
    func testIsResponsible() {
        let store = self.createStore()
        
        let persistable = TestPersistable(id: "666",
                                          title: "Das müsste schon mit dem Teufel zugehen wenn das fehlschlägt")
        
        let responsible = store.isResponsible(for: persistable)
        XCTAssert(responsible)
    }
    
    func testIsNotResponsible() {
        let store = self.createStore()
        
        let responsible = store.isResponsible(for: "TestString")
        XCTAssertFalse(responsible)
    }
    
    func testIsResponsibleForType() {
        let store = self.createStore()
        
        
        let responsible = store.isResponsible(forType: TestPersistable.self)
        XCTAssert(responsible)
    }
    
    func testIsNotResponsibleForType() {
        let store = self.createStore()
        
        
        let responsible = store.isResponsible(forType: String.self)
        XCTAssertFalse(responsible)
    }
    
    func testPersistence(){
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            _ = try store.persist(persistable)
            
            let persistable2 : TestPersistable? = try store.get("666")
            
            XCTAssertNotNil(persistable2)
            XCTAssert(persistable2!.title == "Testtitel")
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    
    func testAsyncPersistence(){
    
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            
            let expect = expectation(description: "It should persist it")
            
            try store.persist(persistable, completion: {
                let persistable2 : TestPersistable? = try! store.get("666")
                
                XCTAssertNotNil(persistable2)
                XCTAssert(persistable2!.title == "Testtitel")
                expect.fulfill()
                
            })
            
            
            waitForExpectations(timeout: 3) { (error: Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    
    func testDelete(){
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 : TestPersistable? = try store.get("666")
            
            XCTAssertNotNil(persistable2)
            XCTAssert(persistable2!.title == "Testtitel")
            
            try store.delete(persistable)
            
            let persistable3 : TestPersistable? = try store.get("666")
            
            XCTAssertNil(persistable3)
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    
    }
    
    func testAsyncDelete(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 : TestPersistable? = try store.get("666")
            
            XCTAssertNotNil(persistable2)
            XCTAssert(persistable2!.title == "Testtitel")
            
            
            let expect = expectation(description: "It should delete it")

            
            try store.delete(persistable2, completion: {
                let persistable3 : TestPersistable? = try! store.get("666")
                XCTAssertNil(persistable3)
                expect.fulfill()
            })
            
            
            waitForExpectations(timeout: 3) { (error: Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    func testGetByIdentifier(){
        
        do {
        
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 : TestPersistable? = try store.get("666")
            XCTAssertNotNil(persistable2)
            XCTAssert(persistable2!.title == "Testtitel")
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    
    func testAsyncGetByIdentifier(){
        
        do {
        
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let expect = expectation(description: "get async")
            
            try store.get("666", completion: { (item: TestPersistable?) in
                XCTAssertNotNil(item)
                XCTAssert(item!.title == "Testtitel")
                expect.fulfill()
            })
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
            
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    func testGetByIdentifierAndType(){
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = try store.get("666", type: TestPersistable.self)
            XCTAssertNotNil(persistable2)
            XCTAssert(persistable2!.title == "Testtitel")
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    func testAsyncGetByIdentifierAndType(){
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let expect = expectation(description: "get async")
            
            try store.get("666", type: TestPersistable.self, completion: { (item: TestPersistable?) in
                XCTAssertNotNil(item)
                XCTAssert(item!.title == "Testtitel")
                expect.fulfill()
            })
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    func testGetAllByType(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                              title: "Testtitel2")
            try store.persist(persistable2)
            
            let items = try store.getAll(TestPersistable.self)
            
            XCTAssert(items.count == 2)
            
            let item667 = items.filter { (item:TestPersistable) -> Bool in
                return item.id == "667"
            }.first
            
            XCTAssertNotNil(item667)
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    
        
    }
    
    func testAsyncGetAllByType(){
        
        do {
    
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                               title: "Testtitel2")
            try store.persist(persistable2)

            
            let expect = expectation(description: "get all async")
            
            try store.getAll(TestPersistable.self, completion: { (items: [TestPersistable]) in
                
                XCTAssert(items.count == 2)
                
                let item667 = items.filter { (item:TestPersistable) -> Bool in
                    return item.id == "667"
                    }.first
                
                XCTAssertNotNil(item667)
                expect.fulfill()
            })
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }

    
    func testExists(){
        
        do {
            
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let exists = try store.exists(persistable)
            XCTAssertTrue(exists)
            
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    
    func testAsyncExists(){
        do {
            
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let expect = expectation(description: "exists async")
            
            try store.exists(persistable, completion: { (exists: Bool) in
                XCTAssertTrue(exists)
                expect.fulfill()
            })
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
        
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }

    func testExistsByIdentifier(){
        
        do {
        
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let exists = try store.exists("666",type:TestPersistable.self)
            XCTAssertTrue(exists)
            
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    
    func testFilter(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                               title: "Testtitel2")
            try store.persist(persistable2)
            
            
            let item667 = try store.filter(TestPersistable.self, includeElement: { (item:TestPersistable) -> Bool in

                return item.id == "667"
            }).first
            
            XCTAssertNotNil(item667)
            
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    func testAsyncFiler(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                               title: "Testtitel2")
            try store.persist(persistable2)
            
            
            let expect = expectation(description: "get all async")
            
            try store.filter(TestPersistable.self,
                              includeElement: { (item:TestPersistable) -> Bool in
                
                                return item.id == "667"
                }, completion: { (items: [TestPersistable]) in
                
                let item667 = items.first
                XCTAssertNotNil(item667)
                expect.fulfill()
            })
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
            
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }

    
    func addView(store: NSCodingPersistenceStore) throws {
        do {
            try store.addView("TestPersistablesByIdType",
                                groupingBlock: { (collection:String, key:String,
                                                      object: TestPersistable) -> String? in
                            
                                if Int(object.id) != nil{
                                    return "isInt"
                                }else if (object.id == "isNotInView"){
                                    return nil
                                }else{
                                    return "isNotInt"
                                }
                            
                            
            }) { (group: String,
            collection1: String,
                   key1: String,
                object1: TestPersistable,
            collection2: String,
                   key2: String,
                object2: TestPersistable) -> ComparisonResult in
                
                return key1.compare(key2)
                
            }
        }  catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    func testAddView() {
    
        let store = self.createStore()
        do {
            try self.addView(store: store)
        }   catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
    }
    
    
    func testGetAllFromView(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                               title: "Testtitel2")
            try store.persist(persistable2)
            
            let persistable3 = TestPersistable(id: "Das ist keine Zahl",
                                               title: "Testtitel3")
            try store.persist(persistable3)
            
            let persistable4 = TestPersistable(id: "isNotInView",
                                               title: "Testtitel4")
            try store.persist(persistable4)
            try self.addView(store: store)
            
            let items: [TestPersistable] = try store.getAll("TestPersistablesByIdType")
            XCTAssert(items.count == 3)
            
        }   catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }

    }
    
    func testAsyncGetAllFromView(){
        
        do {
            let store = self.createStore()
            
            let persistable = TestPersistable(id: "666",
                                              title: "Testtitel")
            
            try store.persist(persistable)
            
            let persistable2 = TestPersistable(id: "667",
                                               title: "Testtitel2")
            try store.persist(persistable2)
            
            let persistable3 = TestPersistable(id: "Das ist keine Zahl",
                                               title: "Testtitel3")
            try store.persist(persistable3)
            
            let persistable4 = TestPersistable(id: "isNotInView",
                                               title: "Testtitel4")
            try store.persist(persistable4)
            try self.addView(store: store)
            
            let expect = expectation(description: "filter async")
            
            try store.getAll("TestPersistablesByIdType", completion: { (items: [TestPersistable]) in
                XCTAssert(items.count == 3)
                expect.fulfill()
            })
            
            
            
            waitForExpectations(timeout: 3) { (error:Error?) in
                if let error = error {
                    XCTFail("complete callback not called: \(error)")
                }
            }
            
            
        }   catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    
    
    func testTransaction() {
        
        do {
            let store = self.createStore()
            
            try store.transaction(transaction: { (store) in
                
                let persistable = TestPersistable(id: "666",
                                                  title: "Testtitel")
                try store.persist(persistable)
            })
            
            let persistable : TestPersistable? = try store.get("666")
            XCTAssertEqual(persistable?.title, "Testtitel")
            
        }   catch let error {
            XCTFail("FAIL: \(#file) \(#line) \(error)")
        }
        
    }
    
    func testTransactionRollback() {
        
        let store = self.createStore()
        let expected = self.expectation(description: "errorExpect")
        
        do {
            
            try store.transaction(transaction: { (store) in
                
                let persistable = TestPersistable(id: "666",
                                                  title: "Testtitel")
                try store.persist(persistable)
                
                throw NSError(domain: "testDomain", code: 42, userInfo: nil)
            })
            
        }   catch {
            
            do {
                let persistable : TestPersistable? = try store.get("666")
                XCTAssertNil(persistable)
                expected.fulfill()
            } catch let error {
                XCTFail("FAIL: \(#file) \(#line) \(error)")
            }
            
        }
        
        self.wait(for: [expected], timeout: 2)
    }
    
    func fileExists(atURL: String) -> Bool{
        guard let url = URL(string: atURL) else{return false}
        do{
            let available = try url.checkResourceIsReachable()
            return available
        }catch{
            print("file:\(atURL) missing:\(error)")
            return false
        }
    }
    
    func forgetVersion(ofDatabaseFilename databaseFilename: String){
        let userDefaultsKey = "\(databaseFilename)_JB_PERSISTENCE_STORE_DB_VERSION"
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: userDefaultsKey)
    }

    
}
