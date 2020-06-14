import XCTest
import CoreDataStackEx
import CoreData
@testable import CoreDataStackEx_Example

class Tests: XCTestCase {
    
    var coreDataService: CoreDataStack!
    static var retainSelf: CoreDataStack!
    static var connected = false
    
    override func setUp() {
        super.setUp()
        
        if !Tests.connected {
            Tests.connected = true
            
            coreDataService = {
                let bundle = Bundle(for: type(of: self))
                let instance = CoreDataStack(configuration: CoreDataStackConfig(storeType: .memory, bundle: bundle, modelName: "testmodel", accessGroup: nil))
                try! instance.prepare()
                Tests.retainSelf = instance
                return instance
            }()
        }

    }
    
    override func tearDown() {
        super.tearDown()
        coreDataService = Tests.retainSelf
        _ = coreDataService.makeRequest().deleteAll(type: User.self)
        _ = coreDataService.makeRequest().deleteAll(type: Post.self)
    }

    func testMakeRequestAndCreateUser0001() {
        coreDataService = Tests.retainSelf
        let createResult0001 = coreDataService.makeRequest().create { (user: User, context) in
            user.id = "0001"
            user.email = "alex@gmail.com"
            user.name = "alex"
        }
        print(createResult0001.object.first)
        if createResult0001.error != nil {
            XCTAssertTrue(false)
        }
    }
    
    func testMakeRequestAndCreateUser0002() {
        coreDataService = Tests.retainSelf
        let createResult0002 = coreDataService.makeRequest().create { (user: User, context) in
            user.id = "0002"
            user.email = "alex@gmail.com"
            user.name = "alex"
        }
        print(createResult0002.object.first)
        if createResult0002.error != nil {
            XCTAssertTrue(false)
        }
    }
    
    func testPerformanceMakeRequestAndCreateUser() {
        self.measure {
            testMakeRequestAndCreateUser0001()
            testMakeRequestAndCreateUser0002()
        }
    }
    
    func testMakeRequestAndUpdateUser0002() {
        coreDataService = Tests.retainSelf
        let createResult0002 = coreDataService.makeRequest().create { (user: User, context) in
            user.id = "0002"
            user.email = "alex@gmail.com"
            user.name = "alex"
        }
        
        XCTAssertNil(createResult0002.error)
        
        let fetchRequest = User.fetchRequest() as NSFetchRequest<User>
        fetchRequest.predicate = NSPredicate(format:"id = %@","0002")
        let fetchResult = coreDataService.makeRequest().fetch(fetchRequest: fetchRequest)
        
        XCTAssertNil(fetchResult.error)
        XCTAssertNotNil(fetchResult.object.first)
        
        let updateResult = coreDataService.makeRequest().update(byObject: fetchResult.object.first!) { (user, _) in
            user.email = "paco@gmail.com"
        }
        
        XCTAssertNil(updateResult.error)
        XCTAssertNotNil(updateResult.object.first)
        
        XCTAssertEqual(updateResult.object.first!.email, "paco@gmail.com")
        
    }

    func testTransaction() {
        coreDataService = Tests.retainSelf
        let transaction = coreDataService.makeTransaction()
        transaction.transactionBlock { (context, observer) in
            let createUserResult = context.create { (user: User, _) in
                user.email = "paco89lol@gmail.com"
                user.name = "paco"
            }

            guard let user = createUserResult.object.first else {
                observer.onAbort(error: nil)
                return
            }

            let createPostResult = context.create { (post: Post, _) in
                post.desc = "nice weather"
                post.owner = user
                post.viewers = post.viewers?.adding(user) as NSSet?
            }

            if createPostResult.error == nil || createUserResult.error == nil {
                observer.onSuccess()
            } else {
                observer.onAbort(error: nil)
            }
        }
        transaction.run { [weak self] (error) in
            if error != nil {
                print(error!)
                XCTAssertTrue(false)
            }
            guard let weakSelf = self else { return }
            let fetchResult = weakSelf.coreDataService.makeRequest().fetchAll(type: Post.self)

            guard let post = fetchResult.object.first else {
                XCTAssertTrue(false)
                return
            }

            let updateResult = weakSelf.coreDataService.makeRequest().update(byObject: post) { (newPost, _) in
                newPost.id = "0001"
            }

            if updateResult.error != nil {
                print(updateResult.error!)
                XCTAssertTrue(false)
            }
            print(updateResult.object.first)
        }
    }
    
    func testPerformanceTransaction() {
        self.measure {
            testTransaction()
        }
    }
    
}
