//
//  NSManagedObjectContext+AMDatabase.swift
//  AMDatabase
//
//  Created by Ilya Kuznetsov on 11/22/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData
import os.log

extension NSManagedObjectContext {
    
    private func logError(error: Error) {
        os_log("error @", error.localizedDescription)
        
        // lof detailed
    }
    
    public func create<T: NSManagedObject>(type: T.Type) -> T {
        return NSEntityDescription.insertNewObject(forEntityName: NSStringFromClass(type), into: self) as! T
    }
    
    // todo this later
    /*public func create<T: NSManagedObject>(type: T.Type, configuration: String) -> T {
        //let object = self.create(type: type)
        //let store = AMDatabase.persistentStoreFor(configuration: configuration)
        //self.assign(object, to: store!)
        return object
    }*/
    
    private func entityDescription<T: NSManagedObject>(type: T.Type) -> NSEntityDescription {
        return NSEntityDescription.entity(forEntityName: NSStringFromClass(type), in: self)!
    }
    
    public func execute<T: NSManagedObject>(request: NSFetchRequest<T>, type: T.Type) throws -> [T] {
        request.entity = self.entityDescription(type: type)
        return try self.fetch(request)
    }
    
    public func allObjects<T: NSManagedObject>(type: T.Type) -> [T] {
        let request = NSFetchRequest<T>()
        
        do {
            return try execute(request: request, type:type)
        } catch {
            logError(error: error)
        }
        return []
    }
    
    public func allObjectsSorted<T: NSManagedObject>(type: T.Type) -> [T] {
        return allObjectsSortedBy(key: \T.objectID.description, type: type)
    }
    
    public func allObjectsSortedBy<T: NSManagedObject, U>(key: KeyPath<T, U>, type: T.Type) -> [T] where U: Comparable {
        return allObjectsSortedBy(key: key, ascending: true, type: type)
    }
    
    public func allObjectsSortedBy<T: NSManagedObject, U>(key: ReferenceWritableKeyPath<T, U?>, type: T.Type) -> [T] where U: Comparable {
        return allObjectsSortedBy(key: key, ascending: true, type: type)
    }
    
    public func allObjectsSortedBy<T: NSManagedObject, U>(key: ReferenceWritableKeyPath<T, U?>, ascending: Bool, type: T.Type) -> [T] where U: Comparable {
        let request = NSFetchRequest<T>()
        request.sortDescriptors = [NSSortDescriptor(keyPath: key, ascending: ascending)]
        
        do {
            return try execute(request: request, type: type)
        } catch {
            logError(error: error)
        }
        return []
    }
    
    public func allObjectsSortedBy<T: NSManagedObject, U>(key: KeyPath<T, U>, ascending: Bool, type: T.Type) -> [T] where U: Comparable {
        let request = NSFetchRequest<T>()
        request.sortDescriptors = [NSSortDescriptor(keyPath: key, ascending: ascending)]
        
        do {
            return try execute(request: request, type: type)
        } catch {
            logError(error: error)
        }
        return []
    }
    
    public func find<T: NSManagedObject>(type: T.Type, block: @escaping (T)->Bool) -> [T] {
        let predicate = NSPredicate { (object, _) in return block(object as! T) }
        return find(type: type, predicate: predicate)
    }
    
    public func find<T: NSManagedObject>(type: T.Type, predicate: NSPredicate) -> [T] {
        let request = NSFetchRequest<T>()
        request.predicate = predicate
        
        do {
            return try execute(request: request, type: type)
        } catch {
            logError(error: error)
        }
        return []
    }
    
    public func findFirst<T: NSManagedObject>(type: T.Type, block: @escaping (T)->Bool) -> T? {
        let predicate = NSPredicate { (object, _) in return block(object as! T) }
        return findFirst(type: type, predicate: predicate)
    }
    
    public func findFirst<T: NSManagedObject>(type: T.Type, predicate: NSPredicate) -> T? {
        let request = NSFetchRequest<T>()
        request.fetchLimit = 1
        request.predicate = predicate
        
        do {
            return try execute(request: request, type: type).first
        } catch {
            logError(error: error)
        }
        return nil
    }
    
    public func objectsWith<T: Sequence>(ids: T) -> [NSManagedObject] where T.Element: NSManagedObjectID {
        return ids.flatMap { return find(type: NSManagedObject.self, objectId: $0) }
    }
    
    public func objectsWith<T: Sequence, U: NSManagedObject>(ids: T, type: U.Type) -> [U] where T.Element: NSManagedObjectID {
        return ids.flatMap { return find(type: type, objectId: $0) }
    }
    
    public func find<T: NSManagedObject>(type: T.Type, objectId: NSManagedObjectID) -> T? {
        do {
            return try self.existingObject(with: objectId) as? T
        } catch {
            logError(error: error)
        }
        return nil
    }
}
