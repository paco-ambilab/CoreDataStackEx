//
//  CoreDataStackConfig.swift
//  CoreDataStackEx
//
//  Created by Pakho Yeung on 6/3/20.
//

import Foundation
import CoreData

public final class CoreDataStackConfig: CustomStringConvertible {
    
    public let persistentStoreType:String
    public let modelName: String
    public let accessGroup: String?
    
    public init(storeType:String = NSSQLiteStoreType, modelName: String, accessGroup: String?) {
        self.persistentStoreType = storeType
        self.modelName = modelName
        self.accessGroup = accessGroup
    }
    public var description: String {
        return "StoreType: \(self.persistentStoreType) ModelName: \(self.modelName) AccessGroup:\(String(describing: self.accessGroup))"
    }
}

