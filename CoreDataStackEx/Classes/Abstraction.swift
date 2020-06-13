//
//  Abstraction.swift
//  CoreDataStackEx
//
//  Created by Pakho Yeung on 6/13/20.
//

import Foundation
import CoreData

public enum CDError: Error {
    case initError
    case invalid
    case fetchError
    case updateError
    case createError
    case deleteError
    case customError(_ error: Error?)
    case systemError(_ error: Error?)
}

//class CoreDataConnection {
//
//}
//
//class Mutation {
//
//    func update(context: CDContext) {}
//    func create(context: CDContext) {}
//    func delete(context: CDContext) {}
//}
//
//class Immutation {
//
//    func fetch(context: CDContext) {}
//}


//class Storage {
//
//    var m: Mutation! = nil
//    var i: Immutation! = nil
//
//    func fetch(context: CDContext) {}
//
//    func update(context: CDContext) {}
//    func create(context: CDContext) {}
//    func delete(context: CDContext) {}
//}

class CoreDataStack {
    
    private(set) var readOnlyContext: NSManagedObjectContext!
        
    private(set) var readWriteContext: NSManagedObjectContext!
    
    private var model: NSManagedObjectModel!
    
    private var storeCoordinator: NSPersistentStoreCoordinator!
    
    let configuration: CoreDataStackConfig
    
    init(configuration: CoreDataStackConfig) {
        self.configuration = configuration
    }
    
    private func getFilePathForSqlite() -> URL {
        var url: URL
        
        let fileName = "\(configuration.modelName).sqlite"
        
        if let groupName = self.configuration.accessGroup {
            guard let groupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupName) else {
                fatalError("Unable to find App Group Container")
            }
            url = groupContainerURL.appendingPathComponent(fileName)
        } else {
            let applicationDocumentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            url = applicationDocumentsDirectoryURL.appendingPathComponent(fileName)
        }
        return url
    }
        
    public func prepare() throws {
        
        // 1. Get model from file, xxxxxx.momd
        let bundle = Bundle(for: type(of: self))
        guard let modelURL = bundle.url(forResource: configuration.modelName, withExtension: "momd") else {
            throw NSError(domain: "CoreDataService", code: CoreDataError.momdFileNotFound.rawValue, userInfo: ["momdFileName": configuration.modelName])
        }
        
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw NSError(domain: "CoreDataService", code: CoreDataError.momdFileLoadFailure.rawValue, userInfo: ["Path": modelURL.path])
        }
        
        self.model = model
        
        // 2. Create a coordinator
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        do {
            try storeCoordinator.addPersistentStore(ofType: configuration.persistentStoreType,
            configurationName: nil,
            at: getFilePathForSqlite(),
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        } catch {
            throw error
        }
        
        self.storeCoordinator = storeCoordinator
        
        let readOnlyContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        readOnlyContext.persistentStoreCoordinator = storeCoordinator
        
        self.readOnlyContext = readOnlyContext
        
        let readWriteContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        readWriteContext.parent = readOnlyContext

        self.readWriteContext = readWriteContext
        
        // 3. Add notification for data changes
        
        NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextDidSave(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    public func deleteAllFromDatabase() -> Error? {
        var retError: Error?
//        return inTransaction({ context in
//            var shouldCommit = false
//            for entity in model.entities {
//                let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
//                fetchRequest.entity = entity
//                fetchRequest.includesSubentities = false
//                do {
//                   let result = try context.fetch(fetchRequest)
//                    for obj in result {
//                        context.delete(obj as! NSManagedObject)
//                    }
//                    shouldCommit = true
//                } catch {
//                    #warning("this error has no handling")
//                    shouldCommit = false
//                }
//            }
//            return shouldCommit
//        })
        return retError
    }
    
    public func removeDatabaseFiles() {
        do {
            let directory = try FileManager.default.contentsOfDirectory(at: getFilePathForSqlite().deletingLastPathComponent(),
                                                                        includingPropertiesForKeys: nil,
                                                                        options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)
            
            let filteredArray = directory.filter { $0.absoluteString.range(of: "\(configuration.modelName).sqlite") != nil }
            filteredArray.forEach { (url) in
                do {
                    try FileManager.default.removeItem(at: url)
                    print("Remove item at: \(url.absoluteString)")
                } catch let error {
                    print("Failed to remove item at : \(url.absoluteString) with Error: \(error)")
                }
            }
        } catch let error {
             print("Failed to cleanup Database Files with Error: \(error)")
        }
    }
    
    // MARK: - Lister
    
    @objc func managedObjectContextDidSave(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
            print("[Inserts:]")
            print(inserts)
        }

        if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, updates.count > 0 {
            print("[Updates:]")
            print(updates)
        }

        if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, deletes.count > 0 {
            print("[Deletes:]")
            print(deletes)
        }
    }
    
    
}

class FetchResult<MObject> {
    var object: [MObject] = []
    var error: CDError?
}

class CDContext {
    
    weak var service: CoreDataStack?
    
//    var contextForRead: NSManagedObjectContext
    
    let isTransaction: Bool
    
//    var context: NSManagedObjectContext
    
    private init(service: CoreDataStack, isTransaction: Bool = false) {
        self.service = service
        
        self.isTransaction = isTransaction
    }
    
    public func fetchAll<MObject: NSManagedObject>(type: MObject.Type) -> FetchResult<MObject> {
        let fetchResult = FetchResult<MObject>()
        guard let context = service?.readOnlyContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        let fetchRequest = MObject.fetchRequest()
        context.performAndWait {
            do {
                fetchResult.object = try context.fetch(fetchRequest) as! [MObject]
                
            } catch {
                fetchResult.error = .systemError(error)
            }
        }
        return fetchResult
    }
    
    public func fetch<MObject: NSManagedObject>(byObject object: MObject) -> FetchResult<MObject> {
        let fetchResult = FetchResult<MObject>()
        guard let context = service?.readOnlyContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        context.performAndWait {
            if let _object = context.object(with: object.objectID) as? MObject {
                fetchResult.object.append(_object)
            }
        }
        return fetchResult
    }
    
    private func fetch<MObject: NSManagedObject>(byObject object: MObject, inContext context: NSManagedObjectContext) -> FetchResult<MObject> {
        let fetchResult = FetchResult<MObject>()
        context.performAndWait {
            if let _object = context.object(with: object.objectID) as? MObject {
                fetchResult.object.append(_object)
            }
        }
        return fetchResult
    }
    
    public func fetch<MObject: NSManagedObject>(fetchRequest: NSFetchRequest<NSFetchRequestResult>,
    type: MObject.Type) -> FetchResult<MObject> {
        let fetchResult = FetchResult<MObject>()
        guard let context = service?.readOnlyContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        context.performAndWait {
            do {
                fetchResult.object = try context.fetch(fetchRequest) as! [MObject]
                
            } catch {
                fetchResult.error = .systemError(error)
            }
        }
        return fetchResult
    }
    
    public func fetch<MObject: NSManagedObject>(fetchRequest: NSFetchRequest<MObject>) -> FetchResult<MObject> {
        return fetch(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>, type: MObject.self)
    }
    
    public func create<MObject: NSManagedObject>(createBlock: ((MObject, CDContext) -> Void)) -> FetchResult<MObject> {
        var fetchResult = FetchResult<MObject>()
        guard let entityName = MObject.entity().name else {
            fetchResult.error = .invalid
            return fetchResult
        }
        
        guard let contextReadable = service?.readOnlyContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        
        guard let contextWritable = service?.readWriteContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        
        contextWritable.performAndWait {
            let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: contextWritable) as! MObject
            createBlock(object, self)
            fetchResult.object.append(object)
            if !isTransaction {
                do {
                    try contextWritable.save()
                    contextWritable.refresh(contextWritable.object(with: object.objectID), mergeChanges: true)
                } catch {
                    fetchResult.error = .systemError(error)
                    contextWritable.rollback()
                }
                fetchResult = fetch(byObject: fetchResult.object.first!, inContext: contextReadable)
            }
        }
        return fetchResult
    }
    
    public func update<MObject: NSManagedObject>(byObject object: MObject, updateBlock: ((MObject, CDContext) -> Void)) -> FetchResult<MObject> { return nil! }
    
    public func delete<MObject: NSManagedObject>(byObject object: MObject,
                                                 dedicatedContext: CDContext? = nil) -> CDError? { return nil! }
}

class CoreDataService {
    
    
}

class TransactionResult {
    
    func onSuccess() {
        
    }
    
    func onAbort(error: Error?) {
        
    }
}


class CDServiceConfiguration {
    
    static let shared: CDServiceConfiguration = CDServiceConfiguration()
    
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "CDService")
    
    private init() {}
    
}


class Transaction {
    
    let lock = NSLock()
    var isComplete: Bool = false
    var result: TransactionResult = TransactionResult()
    var block: ((CDContext, TransactionResult) -> Void)?
    
    func transaction(_ block: @escaping ((CDContext, TransactionResult) -> Void)) {
        
    }
    
    func run(completion: ((CDError?) -> Void)) {
        CDServiceConfiguration.shared.dispatchQueue.async {
            
        }
    }
    
}




