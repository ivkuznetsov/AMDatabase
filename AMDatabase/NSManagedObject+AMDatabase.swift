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
    
    public func delete() {
        self.managedObjectContext?.delete(self)
    }
    
    public func isObjectDeleted() -> Bool {
        return self.managedObjectContext == nil || self.isDeleted
    }
    
    public func permanentObjectID() -> NSManagedObjectID {
        var objectId = self.objectID
        
        if objectId.isTemporaryID {
            try? managedObjectContext?.obtainPermanentIDs(for: [self])
            objectId = self.objectID
        }
        return objectId
    }
    
    public class func idsWith<T: Sequence>(objects: T) -> [NSManagedObjectID] where T.Element: NSManagedObject {
        return objects.map { return $0.permanentObjectID() }
    }
    
    public class func uriWith<T: Sequence>(ids: T) -> [URL] where T.Element: NSManagedObjectID {
        return ids.map { return $0.uriRepresentation() }
    }    
}
