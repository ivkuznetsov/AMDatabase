//
//  AMDatabaseTests.swift
//  AMDatabaseTests
//
//  Created by Ilya Kuznetsov on 11/20/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import XCTest
import CoreData
@testable import AMDatabase

class AMDatabaseTests: XCTestCase {
    
    var database: AMDatabase!
    
    override func setUp() {
        super.setUp()
        database = AMDatabase()
        database.storeDescriptions.first?.removeStoreFiles()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testViewContext() {
        _ = database.viewContext()
    }
    
    func testPrivateContext() {
        _ = database.createPrivateContext()
    }
    
    func expect(_ descrition: String, performing: @escaping (NSManagedObjectContext)->(), check: @escaping ()->()) {
        let test = expectation(description: descrition)
        
        database.perform { (ctx) in
            performing(ctx)
            ctx.saveAll()
            
            DispatchQueue.main.async {
                check()
                test.fulfill()
            }
        }
        wait(for: [test], timeout: 1.0)
    }
    
    func testCreatingAndSavingObject() {
        expect("Object created", performing: { (ctx) in
            
            let entity = ctx.create(type: TestEntity.self)
            entity.uid = 0
        }) {
            XCTAssertNotNil(self.database.viewContext().findFirst(type: TestEntity.self, \.uid, 0))
            
            let database = AMDatabase()
            XCTAssertNotNil(database.viewContext().findFirst(type: TestEntity.self, \.uid, 0))
        }
    }
    
    func testFetchingAllObjects() {
        expect("Fetched all Objects", performing: { (ctx) in
            
            _ = ctx.create(type: TestEntity.self)
            _ = ctx.create(type: TestEntity.self)
            _ = ctx.create(type: TestEntity.self)
            _ = ctx.create(type: TestEntity.self)
        }) {
            XCTAssert(self.database.viewContext().allObjects(TestEntity.self).count == 4)
        }
    }
    
    func createTestData(_ ctx: NSManagedObjectContext) {
        var object = ctx.create(type: TestEntity.self)
        object.uidString = "0"
        object.uid = 3
        object = ctx.create(type: TestEntity.self)
        object.uidString = "1"
        object.uid = 2
        object = ctx.create(type: TestEntity.self)
        object.uidString = "2"
        object.uid = 1
        object = ctx.create(type: TestEntity.self)
        object.uidString = "3"
        object.uid = 0
        object = ctx.create(type: TestEntity.self)
        object.uidString = "0"
        object.uid = 3
    }
    
    func testFetchingAllObjectsSortedByInt() {
        expect("Fetched all Objects Sorted By Int Key", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let sorted = self.database.viewContext().allObjectsSortedBy(key: \.uid, type: TestEntity.self)
            let uids = sorted.flatMap { $0.uid }
            XCTAssert(uids == [ 0, 1, 2, 3, 3])
        }
    }
    
    
    
    func testFetchingAllObjectsSortedByString() {
        expect("Fetched all Objects Sorted By String Key", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let sorted = self.database.viewContext().allObjectsSortedBy(key: \.uidString, type: TestEntity.self)
            let uids = sorted.flatMap { $0.uidString }
            XCTAssert(uids == [ "0", "0", "1", "2", "3"])
        }
    }
    
    func testFetchingAllObjectsDescendingSort() {
        expect("Fetched all Objects Descending Sorted", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let sorted = self.database.viewContext().allObjectsSortedBy(key: \.uid, ascending: false, type: TestEntity.self)
            let uids = sorted.flatMap { $0.uid }
            XCTAssert(uids == [ 3, 3, 2, 1, 0])
        }
    }
    
    func testFindObjects() {
        expect("Fetched Objects for each case", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let ctx = self.database.viewContext()
            
            XCTAssert(ctx.find(type: TestEntity.self, \.uid, 3).count == 2)
            
            XCTAssert(ctx.find(type: TestEntity.self, \.uidString, "0").count == 2)
            
            XCTAssert(ctx.find(type: TestEntity.self, "uid == 3 || uid == 1").count == 3)
            
            let value = 3
            XCTAssert(ctx.find(type: TestEntity.self, "uid == \(value)").count == 2)
            XCTAssert(ctx.find(type: TestEntity.self, "uid == %d", value).count == 2)
            
            XCTAssertNotNil(ctx.findFirst(type: TestEntity.self, \.uid, 0))
            XCTAssertNil(ctx.findFirst(type: TestEntity.self, \.uid, -1))
            
            XCTAssertNotNil(ctx.findFirst(type: TestEntity.self, "uid == \(value)"))
        }
    }
    
    func testObjectIds() {
        expect("Fetched Objects for each case", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let ctx = self.database.viewContext()
            
            let objects = ctx.allObjects(TestEntity.self)
            let ids = TestEntity.ids(objects: objects)
            
            XCTAssert(ids.count == objects.count)
            
            XCTAssert(ctx.objects(ids: ids).count == ids.count)
            
            XCTAssert(ctx.objectsWith(ids: ids, type: TestEntity.self).count == ids.count)
            
            XCTAssertNotNil(ctx.find(type: TestEntity.self, objectId: ids.first!))
        }
    }
    
    func testUriRepresentation() {
        expect("Uri Representation", performing: { (ctx) in
            
            self.createTestData(ctx)
        }) {
            let ctx = self.database.viewContext()
            
            let object = ctx.allObjects(TestEntity.self).first!
            let uri = object.objectID.uriRepresentation()
            
            let newId = self.database.idFor(uriRepresentation: uri)
            XCTAssertNotNil(newId)
            XCTAssertNotNil(ctx.find(type: TestEntity.self, objectId: newId!))
            
            let ids = ctx.allObjects(TestEntity.self).flatMap { $0.objectID }
            XCTAssert(TestEntity.uriWith(ids: ids).count == ids.count)
        }
    }
    
    func testPermanentObjectID() {
        var tempObjectId: NSManagedObjectID?
        var objectId: NSManagedObjectID?
        
        expect("Uri Representation", performing: { (ctx) in
            
            let object = ctx.create(type: TestEntity.self)
            tempObjectId = object.objectID
            objectId = object.permanentObjectID()
        }) {
            XCTAssertNotNil(objectId)
            XCTAssertNotNil(tempObjectId)
            XCTAssert(objectId!.isTemporaryID == false)
            XCTAssert(tempObjectId!.isTemporaryID == true)
            XCTAssertNotNil(self.database.viewContext().find(objectId: objectId!))
        }
    }
    
    func testDeleting() {
        let test = expectation(description: "All objects deleted")
        
        database.perform { (ctx) in
            
            self.createTestData(ctx)
            ctx.saveAll()
            
            DispatchQueue.main.async {
                
                let mainThreadObjects = self.database.viewContext().allObjects(TestEntity.self)
                XCTAssert(mainThreadObjects.count > 0)
                
                self.database.perform { (ctx) in
                    
                    ctx.allObjects(TestEntity.self).forEach { $0.delete() }
                    ctx.saveAll()
                    
                    DispatchQueue.main.async {
                        
                        XCTAssert(self.database.viewContext().allObjects(TestEntity.self).count == 0)
                        mainThreadObjects.forEach { XCTAssert($0.isObjectDeleted()) }
                        
                        test.fulfill()
                    }
                }
            }
        }
        wait(for: [test], timeout: 1.0)
    }
    
    func testMultithreadingObjectsCreating() {
        let test = expectation(description: "No duplicates after creating")
        
        var processed: Int = 0
        for _ in 0..<100 {
            database.perform { (ctx) in
                
                for index: Int64 in 0..<100 {
                    var entity = ctx.findFirst(type: TestEntity.self, \.uid, index)
                    if entity == nil {
                        entity = ctx.create(type: TestEntity.self)
                        entity!.uid = index
                    }
                }
                ctx.saveAll()
                
                DispatchQueue.main.async {
                    processed += 1
                    
                    if processed == 100 {
                        XCTAssert(self.database.viewContext().allObjects(TestEntity.self).count == 100)
                        test.fulfill()
                    }
                }
            }
        }
        wait(for: [test], timeout: 10.0)
    }
    
    func testMultithreadingDataUpdating() {
        let test = expectation(description: "Updated data on main thread")
        
        var mainThreadEntity: TestEntity!
        database.perform { (ctx) in
            
            let entity = ctx.create(type: TestEntity.self)
            entity.uidString = "BeforeUpdate"
            ctx.saveAll()
            let objectId = entity.permanentObjectID()
            
            DispatchQueue.main.async {
                
                mainThreadEntity = self.database.viewContext().find(type: TestEntity.self, objectId: objectId)
                XCTAssert(mainThreadEntity.uidString == "BeforeUpdate")
                
                self.database.perform { (ctx) in
                    
                    let entity = ctx.find(type: TestEntity.self, objectId: objectId)
                    entity!.uidString = "AfterUpdate"
                    ctx.saveAll()
                    
                    DispatchQueue.main.async {
                        
                        XCTAssert(mainThreadEntity.uidString == "AfterUpdate")
                        test.fulfill()
                    }
                }
            }
        }
        wait(for: [test], timeout: 1.0)
    }
}
