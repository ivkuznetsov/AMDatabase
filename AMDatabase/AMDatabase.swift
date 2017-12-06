//
//  AMDatabase.swift
//  AMDatabase
//
//  Created by Ilya Kuznetsov on 11/20/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData
import os.log

open class AMDatabase {
    
    fileprivate var storeCoordinator: NSPersistentStoreCoordinator!
    fileprivate var serialQueue = DispatchQueue(label: "database.serialqueue")
    fileprivate var innerViewContext: NSManagedObjectContext?
    fileprivate var innerWriterContext: NSManagedObjectContext?
    
    public lazy var storeDescriptions = [AMStoreDescription.userDataStore()]
    public var customModelBundle: Bundle?

    public init() {
        NotificationCenter.default.addObserver(self, selector: #selector(contextChanged(notification:)), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    open func reset() {
        setupPersistentStore()
    }
    
    open func viewContext() -> NSManagedObjectContext {
        if innerViewContext == nil {
            setupPersistentStore()
        }
        return innerViewContext!
    }
    
    open func writerContext() -> NSManagedObjectContext {
        if innerWriterContext == nil {
            setupPersistentStore()
        }
        return innerWriterContext!
    }
    
    open func perform(block: @escaping (NSManagedObjectContext) -> ()) {
        let context = self.createPrivateContext()
        
        let run = {
            context.performAndWait {
                block(context)
            }
        }
        
        if Thread.isMainThread {
            DispatchQueue.global(qos: .default).async {
                self.serialQueue.sync(execute: run)
            }
        } else {
            self.serialQueue.sync(execute: run)
        }
    }
    
    open func idFor(uriRepresentation: URL) -> NSManagedObjectID? {
        return storeCoordinator.managedObjectID(forURIRepresentation: uriRepresentation)
    }
    
    open func persistentStoreFor(configuration: String) -> NSPersistentStore? {
        return persistentStoreAt(url: storeDescriptionFor(configuration: configuration).url)
    }
    
    open func save(context: NSManagedObjectContext) {
        assert(context != innerViewContext, "View context cannot be saved")
        
        if context.hasChanges {
            context.performAndWait {
                
                do {
                    try context.save()
                } catch {
                    os_log("%@", error.localizedDescription)
                    os_log("%@", (error as NSError).userInfo)
                    return
                }
                if context.parent == innerWriterContext && context.parent!.hasChanges == true {
                    context.parent!.performAndWait {
                        do {
                            try context.parent?.save()
                        } catch {
                            os_log("%@", error.localizedDescription)
                            os_log("%@", (error as NSError).userInfo)
                            return
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

fileprivate extension AMDatabase {
    
    @objc fileprivate func contextChanged(notification: Notification) {
        if let context = notification.object as? NSManagedObjectContext, context == innerWriterContext {
            innerViewContext?.mergeChanges(fromContextDidSave: notification)
        }
    }
    
    fileprivate func createPrivateContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = writerContext()
        return context
    }
    
    private func persistentStoreAt(url: URL) -> NSPersistentStore? {
        return storeCoordinator.persistentStore(for: url)
    }
    
    private func storeDescriptionFor(configuration: String) -> AMStoreDescription {
        return storeDescriptions.filter { $0.configuration == configuration }.first!
    }
    
    fileprivate func setupPersistentStore() {
        serialQueue.sync {
            var bundles = [Bundle.main]
            
            if let bundle = customModelBundle {
                bundles.append(bundle)
            }
            
            let objectModel = NSManagedObjectModel.mergedModel(from: bundles)!
            storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
            
            addStoresTo(coordinator: storeCoordinator)
            
            innerWriterContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            innerWriterContext?.persistentStoreCoordinator = storeCoordinator
            innerWriterContext?.mergePolicy = NSOverwriteMergePolicy
            
            innerViewContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            innerViewContext?.parent = innerWriterContext
            innerViewContext?.mergePolicy = NSRollbackMergePolicy
        }
    }
    
    private func addStoresTo(coordinator: NSPersistentStoreCoordinator) {
        for identifier in coordinator.managedObjectModel.configurations {
            addStoreWith(configuration: identifier, toCoordinator: coordinator)
        }
    }
    
    private func addStoreWith(configuration: String, toCoordinator coordinator: NSPersistentStoreCoordinator) {
        let description = storeDescriptionFor(configuration: configuration)
        
        var options: [String : Any] = [ NSMigratePersistentStoresAutomaticallyOption : true, NSInferMappingModelAutomaticallyOption : true ]
        
        if description.readOnly {
            options[NSReadOnlyPersistentStoreOption] = true
        }
        
        if let storeOptions = description.options {
            storeOptions.forEach({ options[$0.key] = $0.value })
        }
        
        do {
            try coordinator.addPersistentStore(ofType: description.storeType, configurationName: configuration, at: description.url, options: options)
            
            os_log("Store has been added: %@", description.url.path)
        } catch {
            os_log("Error while creating persistent store: %@ for configuration %@", error.localizedDescription, configuration)
            
            if description.deleteOnError {
                description.removeStoreFiles()
                addStoreWith(configuration: configuration, toCoordinator: coordinator)
            }
        }
    }
}
