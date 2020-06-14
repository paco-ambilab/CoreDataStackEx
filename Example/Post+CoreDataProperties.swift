//
//  Post+CoreDataProperties.swift
//  
//
//  Created by Pakho Yeung on 6/14/20.
//
//

import Foundation
import CoreData


extension Post {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Post> {
        return NSFetchRequest<Post>(entityName: "Post")
    }

    @NSManaged public var create_data: Date?
    @NSManaged public var desc: String?
    @NSManaged public var id: String?
    @NSManaged public var owner: User?
    @NSManaged public var viewers: NSSet?

}

// MARK: Generated accessors for viewers
extension Post {

    @objc(addViewersObject:)
    @NSManaged public func addToViewers(_ value: User)

    @objc(removeViewersObject:)
    @NSManaged public func removeFromViewers(_ value: User)

    @objc(addViewers:)
    @NSManaged public func addToViewers(_ values: NSSet)

    @objc(removeViewers:)
    @NSManaged public func removeFromViewers(_ values: NSSet)

}
