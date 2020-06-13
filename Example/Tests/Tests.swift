import XCTest
import CoreDataStackEx
import CoreData
@testable import CoreDataStackEx_Example

class Tests: XCTestCase {
    
    var coreDataService: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        let bundle = Bundle(for: type(of: self))
        coreDataService = CoreDataStack(configuration: CoreDataStackConfig(storeType: NSInMemoryStoreType, bundle: bundle, modelName: "testmodel", accessGroup: nil))
        try! coreDataService.prepare()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        _ = coreDataService.makeRequest().deleteAll(type: User.self)
        _ = coreDataService.makeRequest().deleteAll(type: Post.self)
    }

    func testRequest() {
        let createResult = coreDataService.makeRequest().create { (user: User, context) in
            user.email = "paco89lol@gmail.com"
            user.name = "paco"
        }
        print(createResult.object.first)
        if createResult.error != nil {
            XCTAssertTrue(false)
        }
    }
    
    func testTransaction() {
        let transaction = coreDataService.makeTransaction()
        transaction.transactionBlock { (context, observer) in
            let createUserResult = context.create { (user: User, _) in
                user.email = "paco89lol@gmail.com"
                user.name = "paco"
            }
            let createPostResult = context.create { (post: Post, _) in
                post.desc = "nice weather"
                post.owners = createUserResult.object.first
            }
            
            if createPostResult.error == nil || createUserResult.error == nil {
                observer.onSuccess()
            } else {
                observer.onAbort(error: nil)
            }
        }
        transaction.run { (error) in
            print(error)
            if error != nil {
                XCTAssertTrue(false)
            }
        }
    }
    
}
