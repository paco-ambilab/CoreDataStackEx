//
//  User+CoreDataProperties.swift
//  
//
//  Created by Pakho Yeung on 6/14/20.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var email: String?
    @NSManaged public var name: String?
    @NSManaged public var id: String?
    @NSManaged public var owned_posts: NSSet?
    @NSManaged public var viewed_posts: NSSet?

}

// MARK: Generated accessors for owned_posts
extension User {

    @objc(addOwned_postsObject:)
    @NSManaged public func addToOwned_posts(_ value: Post)

    @objc(removeOwned_postsObject:)
    @NSManaged public func removeFromOwned_posts(_ value: Post)

    @objc(addOwned_posts:)
    @NSManaged public func addToOwned_posts(_ values: NSSet)

    @objc(removeOwned_posts:)
    @NSManaged public func removeFromOwned_posts(_ values: NSSet)

}

// MARK: Generated accessors for viewed_posts
extension User {

    @objc(addViewed_postsObject:)
    @NSManaged public func addToViewed_posts(_ value: Post)

    @objc(removeViewed_postsObject:)
    @NSManaged public func removeFromViewed_posts(_ value: Post)

    @objc(addViewed_posts:)
    @NSManaged public func addToViewed_posts(_ values: NSSet)

    @objc(removeViewed_posts:)
    @NSManaged public func removeFromViewed_posts(_ values: NSSet)

}
