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

//  Do any changes only by 'perform()' function, they will be performend on background queue, do not forget to save by 'ctx.saveAll()'
//  Use 'viewContext' for getting objects to the main thread and presenting in UI
//  You can't use 'viewContext' for changing objects, it's read only.
//
//  sample Implementation:
//
//  let database = AMDatabase()
//
//  database.perform { (ctx) in
//
//      let object = ctx.create(type: SampleObject.self)
//
//      ctx.saveAll()
//  }
//
//  let objects = database.viewContext().allObjects(SampleObject.self)
//

class AMWeakContext: NSObject {
    weak var context: NSManagedObjectContext?
}

open class AMDatabase: NSObject {
    
    private var notifCenter: NotificationCenter
    
    fileprivate var storeCoordinator: NSPersistentStoreCoordinator!
    fileprivate var serialQueue = DispatchQueue(label: "database.serialqueue")
    fileprivate var innerViewContext: NSManagedObjectContext?
    fileprivate var innerWriterContext: NSManagedObjectContext?
    fileprivate var privateContextsForMerge: [AMWeakContext] = []
    
    @objc public lazy var storeDescriptions = [AMStoreDescription.userDataStore()]
    public var customModelBundle: Bundle?

    @objc public init(notifCenter: NotificationCenter = NotificationCenter.default) {
        self.notifCenter = notifCenter
        super.init()
        notifCenter.addObserver(self, selector: #selector(contextChanged(notification:)), name: Notification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    @objc open func viewContext() -> NSManagedObjectContext {
        if innerViewContext == nil {
            setupPersistentStore()
        }
        return innerViewContext!
    }
    
    private func writerContext() -> NSManagedObjectContext {
        if innerWriterContext == nil {
            setupPersistentStore()
        }
        return innerWriterContext!
    }
    
    @objc open func perform(_ closure: @escaping (NSManagedObjectContext) -> ()) {
        let context = self.createPrivateContext()
        
        let run = {
            context.performAndWait {
                closure(context)
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
    
    @objc open func reset() {
        setupPersistentStore()
    }
    
    @objc open func idFor(uriRepresentation: URL) -> NSManagedObjectID? {
        if storeCoordinator == nil {
            setupPersistentStore()
        }
        return storeCoordinator.managedObjectID(forURIRepresentation: uriRepresentation)
    }
    
    @objc open func persistentStoreFor(configuration: String) -> NSPersistentStore? {
        return persistentStoreAt(url: storeDescriptionFor(configuration: configuration).url)
    }
    
    @objc open func createPrivateContext(mergeChanges: Bool) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = writerContext()
        if mergeChanges {
            let weakContext = AMWeakContext()
            weakContext.context = context
            serialQueue.async {
                self.privateContextsForMerge.append(weakContext)
            }
        }
        return context
    }
    
    @objc open func createPrivateContext() -> NSManagedObjectContext {
        return createPrivateContext(mergeChanges: false)
    }
    
    func log(message: String) {
        if #available(iOS 10.0, *) {
            os_log("%@", message)
        } else {
            print(message)
        }
    }
    
    deinit {
        notifCenter.removeObserver(self)
    }
}

fileprivate extension AMDatabase {
    
    @objc fileprivate func contextChanged(notification: Notification) {
        if let context = notification.object as? NSManagedObjectContext, context == innerWriterContext {
            DispatchQueue.main.async {
                self.innerViewContext?.mergeChanges(fromContextDidSave: notification)
            }
            serialQueue.async {
                self.privateContextsForMerge.forEach { (context) in
                    if let context = context.context {
                        context.performAndWait {
                            context.mergeChanges(fromContextDidSave: notification)
                        }
                    } else {
                        self.privateContextsForMerge.remove(at: self.privateContextsForMerge.index(of: context)!)
                    }
                }
            }
        }
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
            
            log(message: "Store has been added: \(description.url.path)")
        } catch {
            log(message: "Error while creating persistent store: \(error.localizedDescription) for configuration \(configuration)")
            if description.deleteOnError {
                description.removeStoreFiles()
                addStoreWith(configuration: configuration, toCoordinator: coordinator)
            }
        }
    }
}
