//
//  CoreDataStackConfig.swift
//  CoreDataStackEx
//
//  Created by Pakho Yeung on 6/3/20.
//

import Foundation
import CoreData

public enum CoreDataStoreType {
    case sqlite
    case memory
    case binary
    
    func string() -> String {
        switch self {
        case .sqlite:
            return NSSQLiteStoreType
        case .memory:
            return NSInMemoryStoreType
        case .binary:
            return NSBinaryStoreType
        }
    }
    
}

public final class CoreDataStackConfig: CustomStringConvertible {
    
    public let bundle: Bundle
    public let storeType: CoreDataStoreType
    public let modelName: String
    public let accessGroup: String?
    
    public init(storeType:CoreDataStoreType = .sqlite, bundle: Bundle, modelName: String, accessGroup: String?) {
        self.storeType = storeType
        self.bundle = bundle
        self.modelName = modelName
        self.accessGroup = accessGroup
    }
    
    public var description: String {
        return "StoreType: \(self.storeType.string()) ModelName: \(self.modelName) AccessGroup:\(String(describing: self.accessGroup))"
    }
}

