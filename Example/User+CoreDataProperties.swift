//
//  User+CoreDataProperties.swift
//  
//
//  Created by Pakho Yeung on 6/13/20.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var name: String?
    @NSManaged public var email: String?
    @NSManaged public var owned_posts: Post?
    @NSManaged public var viewed_posts: Post?

}
