//
//  NSManagedObject+AMDatabase.swift
//  AMDatabase
//
//  Created by Ilya Kuznetsov on 11/20/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData
import os.log

public extension NSManagedObject {
    
    @objc func delete() {
        self.managedObjectContext?.delete(self)
    }
    
    @objc func isObjectDeleted() -> Bool {
        return self.managedObjectContext == nil || self.isDeleted
    }
    
    @objc func permanentObjectID() -> NSManagedObjectID {
        var objectId = self.objectID
        
        if objectId.isTemporaryID {
            try? managedObjectContext?.obtainPermanentIDs(for: [self])
            objectId = self.objectID
        }
        return objectId
    }
    
    class func idsWith<T: Sequence>(objects: T) -> [NSManagedObjectID] where T.Element: NSManagedObject {
        return objects.map { return $0.permanentObjectID() }
    }
    
    class func uriWith<T: Sequence>(ids: T) -> [URL] where T.Element: NSManagedObjectID {
        return ids.map { return $0.uriRepresentation() }
    }    
}

//ObjC support
@available(swift, obsoleted: 1.0)
public extension NSManagedObject {
    
    @objc class func ids(objects: [NSManagedObject]) -> [NSManagedObjectID] {
        return idsWith(objects: objects)
    }
    
    @objc class func ids(objectsSet: Set<NSManagedObject>) -> [NSManagedObjectID] {
        return idsWith(objects: objectsSet)
    }
    
    @objc class func uri(ids: [NSManagedObjectID]) -> [URL] {
        return uriWith(ids: ids)
    }
    
    @objc class func uri(idsSet: Set<NSManagedObjectID>) -> [URL] {
        return uriWith(ids: idsSet)
    }
}
