//
//  CoreDataStackEx.swift
//  CoreDataStackEx
//
//  Created by Pakho Yeung on 6/3/20.
//

import Foundation
import CoreData

enum CoreDataError: Int {
    case momdFileNotFound
    case momdFileLoadFailure
}

public class CoreDataStackEx {
    
    let configuration:CoreDataStackConfig
    
    private var readOnlyContext: NSManagedObjectContext!
    
//    private var readWriteContext: NSManagedObjectContext!
    
    private var model: NSManagedObjectModel!
    
    private var storeCoordinator: NSPersistentStoreCoordinator!
    
    static let shared: CoreDataStackEx = {
        let obj = CoreDataStackEx(configuration: CoreDataStackConfig(storeType: NSInMemoryStoreType, modelName: "AmbiClimate", accessGroup: nil))
        try! obj.prepare()
        return obj
    }()
    
    required public init(configuration: CoreDataStackConfig) {
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
        
//        let readWriteContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
//        readWriteContext.parent = readOnlyContext
//
//        self.readWriteContext = readWriteContext
        
        // 3. Add notification for data changes
        
        NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextDidSave(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    public func deleteAllFromDatabase() -> Error? {
        var retError: Error?
        return inTransaction({ context in
            var shouldCommit = false
            for entity in model.entities {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
                fetchRequest.entity = entity
                fetchRequest.includesSubentities = false
                do {
                   let result = try context.fetch(fetchRequest)
                    for obj in result {
                        context.delete(obj as! NSManagedObject)
                    }
                    shouldCommit = true
                } catch {
                    #warning("this error has no handling")
                    shouldCommit = false
                }
            }
            return shouldCommit
        })
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
    
    // end: Listener
    
    // MARK: - ManagedObjectContext
    
    public func getReadOnlyContext() -> NSManagedObjectContext {
        return readOnlyContext
    }
    
    public func getMutableContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = readOnlyContext
        return context
//        return readWriteContext
    }
    
    // end: ManagedObjectContext
    
    // MARK: - Immutable Operation
    
    public func fetchAll<ManagedObject: NSManagedObject>(type: ManagedObject.Type) -> (mainContextObjects: [ManagedObject], error: Error?) {
        var retError: Error?
        var result: [ManagedObject] = []
        let fetchRequest = ManagedObject.fetchRequest()
        let context = getReadOnlyContext()
        context.performAndWait {
            do {
                result = try context.fetch(fetchRequest) as! [ManagedObject]
            } catch {
                retError = error
            }
        }
        return (result, retError)
    }
    
//    public func fetch<ManagedObject: NSManagedObject>(byID id: String,
//                                                      type: ManagedObject.Type) -> (mainContextObject: ManagedObject?, error: Error?) {
//        var retError: Error?
//        var result: [ManagedObject] = []
//        let fetchRequest = {() -> NSFetchRequest<NSFetchRequestResult> in
//            let fetchRequest = ManagedObject.fetchRequest()
//            fetchRequest.predicate = NSPredicate(format:"id LIKE[c] \"\(id)\"")
//            fetchRequest.fetchLimit = 1
//            let sorter: NSSortDescriptor = NSSortDescriptor(key: "id" , ascending: true)
//            fetchRequest.sortDescriptors = [sorter]
//            return fetchRequest
//        }()
//        let context = getReadOnlyContext()
//        context.performAndWait {
//            do {
//                result = try context.fetch(fetchRequest) as! [ManagedObject]
//            } catch {
//                retError = error
//            }
//        }
//        return (result.first, retError)
//    }
    
    public func fetch<ManagedObject: NSManagedObject>(byObject object: ManagedObject, dedicatedContext: NSManagedObjectContext? = nil) -> ManagedObject {
        var readOnlyObject: ManagedObject?
        let context = dedicatedContext ?? getReadOnlyContext()
        context.performAndWait {
            readOnlyObject = context.object(with: object.objectID) as? ManagedObject
        }
        return readOnlyObject!
    }
    
//    public func fetchForReadOnly<ManagedObject: NSManagedObject>(byObject object: ManagedObject) -> ManagedObject {
//        var readOnlyObject: ManagedObject?
//        let context = getReadOnlyContext()
//        context.performAndWait {
//            readOnlyObject = context.object(with: object.objectID) as? ManagedObject
//        }
//        return readOnlyObject!
//    }
    
    /* Flexible Fetch Request */
    public func fetch<ManagedObject: NSManagedObject>(request: NSFetchRequest<NSFetchRequestResult>,
                                                      type: ManagedObject.Type) -> (managedObjects: [ManagedObject], error: Error?)
    {
        var retError: Error?
        var result: [ManagedObject] = []
        let context = getReadOnlyContext()
        context.performAndWait {
            do {
                result = try context.fetch(request) as! [ManagedObject]
            } catch {
                retError = error
            }
        }
        return (result, retError)
    }
    
    public func fetch<ManagedObject: NSManagedObject>(request: NSFetchRequest<ManagedObject>) -> (managedObjects: [ManagedObject], error: Error?)
    {
        var retError: Error?
        var result: [ManagedObject] = []
        let context = getReadOnlyContext()
        context.performAndWait {
            do {
                result = try context.fetch(request)
            } catch {
                retError = error
            }
        }
        return (result, retError)
    }
    
    // end: Immutable Operation
    
    // MARK: - Mutable Operation
    
    public func create<ManagedObject: NSManagedObject>(dedicatedContext: NSManagedObjectContext? = nil,
                                                       handler: ((ManagedObject, NSManagedObjectContext) -> Void)) -> (managedObject: ManagedObject?, error: Error?) {
        var retError: Error?
        guard let entityName = ManagedObject.entity().name else {
            return nil!
        }
        let shouldAutoSave = dedicatedContext == nil
        var managedObject: ManagedObject?
        let context = dedicatedContext ?? getMutableContext()
        
        context.performAndWait {
            let object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! ManagedObject
            handler(object, context)
            managedObject = object
            if shouldAutoSave {
                do {
                    try context.save()
                    context.refresh(context.object(with: object.objectID), mergeChanges: true)
                } catch {
                    retError = error
                    context.rollback()
                }
                if managedObject != nil {
                    managedObject = fetch(byObject: managedObject!)
                }
            }
        }
        return (managedObject, retError)
    }
    
    public func update<ManagedObject: NSManagedObject>(byObject object: ManagedObject,
                                                       dedicatedContext: NSManagedObjectContext? = nil,
                                                       handler: ((ManagedObject, NSManagedObjectContext) -> Void)) -> (managedObject: ManagedObject?, error: Error?) {
        var retError: Error?
        let shouldAutoSave = dedicatedContext == nil
        var managedObject: ManagedObject?
        let context = dedicatedContext ?? getMutableContext()
        context.performAndWait {
            let object = context.object(with: object.objectID) as! ManagedObject
            handler(object, context)
            managedObject = object
            if shouldAutoSave {
                do {
                    try context.save()
                    context.refresh(context.object(with: object.objectID), mergeChanges: true)
                } catch {
                    retError = error
                    context.rollback()
                }
                if managedObject != nil {
                    managedObject = fetch(byObject: managedObject!)
                }
            }
        }
        return (managedObject, retError)
    }
    
//    public func update<ManagedObject: NSManagedObject>(byID id: String,
//                                                       dedicatedContext: NSManagedObjectContext? = nil,
//                                                       handler: ((ManagedObject) -> Void)) -> (managedObject: ManagedObject?, error: Error?) {
//        var retError: Error?
//        let (object, error) = fetch(byID: id, type: ManagedObject.self)
//        retError = error
//
//        if retError != nil {
//            return (object, retError)
//        }
//
//        if object == nil {
//            return (object, retError)
//        }
//
//        return update(byObject: object!, dedicatedContext: dedicatedContext, handler: handler)
//    }
    
//    public func updateOrCreate<ManagedObject: NSManagedObject>(byID id: String,
//                                                               dedicatedContext: NSManagedObjectContext? = nil,
//                                                               type: ManagedObject.Type,
//                                                               handler: ((ManagedObject) -> Void)) -> (managedObject: ManagedObject?, error: Error?) {
//        var (object, retError) = fetch(byID: id, type: ManagedObject.self) as (ManagedObject?, Error?)
//        if retError != nil {
//            return (object, retError)
//        }
//        if object == nil {
//            (object, retError) = create(dedicatedContext: dedicatedContext, handler: handler)
//        } else {
//            (object, retError) = update(byObject: object!, dedicatedContext: dedicatedContext, handler: handler)
//        }
//        return (object, retError)
//    }
    
    public func delete<ManagedObject: NSManagedObject>(byObject object: ManagedObject,
                                                       dedicatedContext: NSManagedObjectContext? = nil) -> Error? {
        var ret: Error?
        let shouldAutoSave = dedicatedContext == nil
        let context = dedicatedContext ?? getMutableContext()
        context.performAndWait {
            let matchedObject = context.object(with: object.objectID) as! ManagedObject
            context.delete(matchedObject)
            if shouldAutoSave {
                do {
                    try context.save()
                    context.refresh(context.object(with: object.objectID), mergeChanges: true)
                } catch {
                    ret = error
                    if shouldAutoSave {
                        context.rollback()
                    }
                }
            }
        }
        return ret
    }
    
//    public func delete<ManagedObject: NSManagedObject>(byID id: String ,
//                                                       type: ManagedObject.Type,
//                                                       dedicatedContext: NSManagedObjectContext? = nil) -> Error? {
//        var retError: Error?
//        let (object, error) = fetch(byID: id, type: ManagedObject.self)
//        retError = error
//
//        if retError != nil {
//            return retError
//        }
//
//        if object == nil {
//            return nil
//        }
//
//        return delete(byObject: object!, dedicatedContext: dedicatedContext)
//    }
//
//    public func deletes<ManagedObject: NSManagedObject>(byIDs ids: [String] ,
//                                                        type: ManagedObject.Type,
//                                                        dedicatedContext: NSManagedObjectContext? = nil) -> Error? {
//        var ret: Error?
//        let shouldAutoSave = dedicatedContext == nil
//        let context = dedicatedContext ?? getMutableContext()
//        context.performAndWait {
//            for id in ids {
//                if let error = delete(byID: id, type: type, dedicatedContext: dedicatedContext) {
//                    ret = error
//                    break
//                }
//            }
//
//            if ret != nil {
//                return
//            }
//
//            if shouldAutoSave {
//                do {
//                    try context.save()
//                    context.refreshAllObjects()
//                } catch {
//                    ret = error
//                    context.rollback()
//                }
//            }
//        }
//        return ret
//    }
    
    public func deletes<ManagedObject: NSManagedObject>(byObjects objects: [ManagedObject],
                                                        dedicatedContext: NSManagedObjectContext? = nil) -> Error? {
        var ret: Error?
        let shouldAutoSave = dedicatedContext == nil
        let context = dedicatedContext ?? getMutableContext()
        context.performAndWait {
            for object in objects {
                if let error = delete(byObject: object, dedicatedContext: dedicatedContext) {
                    ret = error
                    break
                }
            }
            
            if ret != nil {
                return
            }
            
            if shouldAutoSave {
                do {
                    try context.save()
                    context.refreshAllObjects()
                } catch {
                    ret = error
                    context.rollback()
                }
            }
        }
        return ret
    }
    
    public func deleteAll<ManagedObject: NSManagedObject>(dedicatedContext: NSManagedObjectContext? = nil,
                                                          type: ManagedObject.Type) -> Error? {
        var ret: Error?
        let shouldAutoSave = dedicatedContext == nil
        let (objects, error) = fetchAll(type: ManagedObject.self)
        ret = error
        if ret != nil {
            return ret
        }
        let context = dedicatedContext ?? getMutableContext()
        context.performAndWait {
            for object in objects {
                context.delete(context.object(with: object.objectID))
            }
            if shouldAutoSave {
                do {
                    try context.save()
                    context.refreshAllObjects()
                } catch {
                    ret = error
                    context.rollback()
                }
            }
        }
        return ret
    }
    
    // end: Mutable Operation
    
    // MARK: - Transaction
    
    func inTransaction(_ block: (NSManagedObjectContext) throws -> Bool) -> Error? {
        let context = getMutableContext()
        var retError: Error?
        context.performAndWait {
            var shouldSave = false
            do {
                shouldSave = try block(context)
            } catch {
                retError = error
            }
            
            if retError != nil || !shouldSave {
                context.rollback()
                context.refreshAllObjects()
                return
            }
            
            do {
                try context.save()
                context.refreshAllObjects()
            } catch {
                retError = error
                context.rollback()
            }
        }
        return retError
    }
    
}
