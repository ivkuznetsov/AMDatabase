//
//  AMStoreDescription.swift
//  AMDatabase
//
//  Created by Ilya Kuznetsov on 11/20/17.
//  Copyright © 2017 Ilya Kuznetsov. All rights reserved.
//

import Foundation
import CoreData

@objc public class AMStoreDescription: NSObject {
    
    public var url: URL
    public var storeType = NSSQLiteStoreType
    public var configuration = "PF_DEFAULT_CONFIGURATION_NAME"
    public var readOnly = false
    public var deleteOnError = true
    public var options: [String:Any]?
    
    @objc public init(url: URL) {
        self.url = url
        super.init()
    }
    
    public static func appDataStore() -> AMStoreDescription {
        let url = URL(fileURLWithPath: applicationCacheDirectory() + "/" + self.databaseFileName())
        return AMStoreDescription(url: url)
    }
    
    public static func userDataStore() -> AMStoreDescription {
        let url = URL(fileURLWithPath: applicationSupportDirectory() + "/" + self.databaseFileName())
        let description = AMStoreDescription(url: url)
        description.deleteOnError = false
        return description
    }
    
    public static func transientStore() -> AMStoreDescription {
        let description = AMStoreDescription(url: URL(string: "memory://")!)
        description.storeType = NSInMemoryStoreType
        return description
    }
    
    private static func applicationSupportDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let appSupportDirectory = paths.first!
        
        if !FileManager.default.fileExists(atPath: appSupportDirectory) {
            try! FileManager.default.createDirectory(atPath: appSupportDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        
        let fullDirectory = appSupportDirectory + "/" + Bundle.main.bundleIdentifier!
        
        if !FileManager.default.fileExists(atPath: fullDirectory) {
            try! FileManager.default.createDirectory(atPath: fullDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        return fullDirectory
    }
    
    private static func applicationCacheDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let appSupportDirectory = paths.first!
        
        let fullDirectory = appSupportDirectory + "/" + Bundle.main.bundleIdentifier!
        
        if !FileManager.default.fileExists(atPath: fullDirectory) {
            try! FileManager.default.createDirectory(atPath: fullDirectory, withIntermediateDirectories: false, attributes: nil)
        }
        return fullDirectory
    }
    
    fileprivate static func databaseFileName() -> String {
        let appName = ProcessInfo.processInfo.processName
        return appName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) + ".sqlite"
    }
}

public extension AMStoreDescription {
    
    func copyStoreFileFrom(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.copyItem(at: url, to: self.url)
        }
    }
    
    func removeStoreFiles() {
        let dataBaseDirectory = url.deletingLastPathComponent()
        
        if let filePathes = try? FileManager.default.contentsOfDirectory(atPath: dataBaseDirectory.path) {
            for fileName in filePathes {
                if fileName.contains(type(of: self).databaseFileName()) {
                    try? FileManager.default.removeItem(at: dataBaseDirectory.appendingPathComponent(fileName))
                }
            }
        }
    }
}
