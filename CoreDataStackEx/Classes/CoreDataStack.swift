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

public class CoreDataStack {
        
    private(set) var readOnlyContext: NSManagedObjectContext!
        
    private(set) var readWriteContext: NSManagedObjectContext!
    
    private(set) var readWriteTransactionContext: NSManagedObjectContext!
    
    private var model: NSManagedObjectModel!
    
    private var storeCoordinator: NSPersistentStoreCoordinator!
    
    let configuration: CoreDataStackConfig
    
    public init(configuration: CoreDataStackConfig) {
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
        guard let modelURL = configuration.bundle.url(forResource: configuration.modelName, withExtension: "momd") else {
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
        
        let readWriteTransactionContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        readWriteTransactionContext.parent = readOnlyContext

        self.readWriteTransactionContext = readWriteTransactionContext
        
        // 3. Add notification for data changes
        
        NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextDidSave(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    public func deleteAllDataFromCoreData(completion: @escaping ((CDError?) -> Void)) {
        let transaction = makeTransaction()
        transaction.transactionBlock { [weak self] context, observer in
            guard let weakSelf = self else {
                observer.onAbort(error: nil)
                return
            }
            for entity in weakSelf.model.entities {
                let fetchRequest = NSFetchRequest<NSManagedObject>()
                fetchRequest.entity = entity
                fetchRequest.includesSubentities = false
                let fetchResult = context.fetch(fetchRequest: fetchRequest)
                guard fetchResult.error == nil else {
                    observer.onAbort(error: fetchResult.error)
                    return
                }
                for obj in fetchResult.object {
                    let error = context.delete(byObject: obj)
                    guard error == nil else {
                        observer.onAbort(error: error)
                        return
                    }
                }
            }
            observer.onSuccess()
        }
        
        transaction.run(completion: completion)
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
    
    public func makeRequest() -> CDRequset {
        return CDContext(service: self, isTransaction: false)
    }
    
    public func makeTransaction() -> CDTransaction {
        return CDTransaction(context: CDContext(service: self, isTransaction: true))
    }
    
}

public class FetchResult<MObject> {
    public var object: [MObject] = []
    public var error: CDError?
}

public typealias CDRequset = CDContext

public class CDContext {
    
    weak var service: CoreDataStack?
    
    let isTransaction: Bool
    
    fileprivate init(service: CoreDataStack, isTransaction: Bool = false) {
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
        
        guard let contextWritable = (!isTransaction) ? service?.readWriteContext: service?.readWriteTransactionContext else {
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
    
    public func update<MObject: NSManagedObject>(byObject object: MObject, updateBlock: ((MObject, CDContext) -> Void)) -> FetchResult<MObject> {
        var fetchResult = FetchResult<MObject>()
        guard let contextReadable = service?.readOnlyContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        
        guard let contextWritable = (!isTransaction) ? service?.readWriteContext: service?.readWriteTransactionContext else {
            fetchResult.error = .invalid
            return fetchResult
        }
        
        contextWritable.performAndWait {
            let object = contextWritable.object(with: object.objectID) as! MObject
            updateBlock(object, self)
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
    
    public func delete<MObject: NSManagedObject>(byObject object: MObject) -> CDError? {
        var retError: CDError?
        guard let contextWritable = (!isTransaction) ? service?.readWriteContext: service?.readWriteTransactionContext else {
            retError = .invalid
            return retError
        }
        
        contextWritable.performAndWait {
            contextWritable.delete(contextWritable.object(with: object.objectID) as! MObject)
            if !isTransaction {
                do {
                    try contextWritable.save()
                    contextWritable.refresh(contextWritable.object(with: object.objectID), mergeChanges: true)
                } catch {
                    retError = .systemError(error)
                    contextWritable.rollback()
                }
            }
        }
        return retError
    }
    
    public func deleteAll<MObject: NSManagedObject>(type: MObject.Type) -> Error? {
        var retError: CDError?
        guard let contextWritable = (!isTransaction) ? service?.readWriteContext: service?.readWriteTransactionContext else {
            retError = .invalid
            return retError
        }
        
        let fetchResult = fetchAll(type: type)
        
        guard fetchResult.error == nil else {
            return fetchResult.error
        }
        
        contextWritable.performAndWait {
            
            for object in fetchResult.object {
                contextWritable.delete(contextWritable.object(with: object.objectID))
            }
            if !isTransaction {
                do {
                    try contextWritable.save()
                    contextWritable.refreshAllObjects()
                } catch {
                    retError = .systemError(error)
                    contextWritable.rollback()
                }
            }
        }
        return retError
    }
}

class CDServiceConfiguration {
    
    static let shared: CDServiceConfiguration = CDServiceConfiguration()
    
    let dispatchQueue: DispatchQueue = DispatchQueue(label: "CDService")
    
    private init() {}
    
}

public protocol CDTransactionResultObserver {
    
    func onSuccess()
    
    func onAbort(error: Error?)
}

public class CDTransaction: CDTransactionResultObserver {
    
    let lock = NSLock()
    
    var isComplete: Bool = false

    var retainSelf: CDTransaction?
    
    var block: ((CDContext, CDTransactionResultObserver) -> Void)?
    
    var completion: ((CDError?) -> Void)?
    
    let context: CDContext
    
    init(context: CDContext) {
        self.context = context
    }
    
    public func transactionBlock(_ block: @escaping ((CDContext, CDTransactionResultObserver) -> Void)) {
        self.block = block
    }
    
    public func run(completion: @escaping ((CDError?) -> Void)) {
        retainSelf = self
        self.completion = completion
        CDServiceConfiguration.shared.dispatchQueue.async { [weak self] in
            guard let weakSelf = self else {
                completion(.invalid)
                return
            }
            weakSelf.block?(weakSelf.context, weakSelf)
        }
    }
    
    // CDTransactionResultObservable
    public func onSuccess() {
        var retError: CDError?
        
        guard isComplete == false else {
            fatalError("CDTransaction onSuccess() invokes twice.")
        }
        
        isComplete = true
        
        let completionRunInMainThread = { (block: @escaping (()-> Void)) in
            DispatchQueue.main.async { [weak self] in
                block()
                self?.retainSelf = nil
            }
        }
        
        guard let contextWritable = context.service?.readWriteTransactionContext else {
            completionRunInMainThread { [weak self] in
                self?.completion?(CDError.invalid)
            }
            return
        }
        
        contextWritable.performAndWait {
            do {
                try contextWritable.save()
                contextWritable.refreshAllObjects()
            } catch {
                retError = .systemError(error)
                contextWritable.rollback()
            }
        }
        completionRunInMainThread { [weak self] in
            self?.completion?(retError)
        }
    }
    
    public  func onAbort(error: Error?) {
        guard isComplete == false else {
            fatalError("CDTransaction onAbort(error:) invokes twice.")
        }
        
        isComplete = true
        
        let completionRunInMainThread = { (block: @escaping (()-> Void)) in
            DispatchQueue.main.async { [weak self] in
                block()
                self?.retainSelf = nil
            }
        }
        
        guard let contextWritable = context.service?.readWriteTransactionContext else {
            completionRunInMainThread { [weak self] in
                self?.completion?(CDError.invalid)
            }
            return
        }
        
        contextWritable.performAndWait {
            contextWritable.rollback()
            contextWritable.refreshAllObjects()
        }
        completionRunInMainThread { [weak self] in
            self?.completion?(CDError.customError(error))
        }
    }
    
}




