//
//  Post+CoreDataProperties.swift
//  
//
//  Created by Pakho Yeung on 6/13/20.
//
//

import Foundation
import CoreData


extension Post {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Post> {
        return NSFetchRequest<Post>(entityName: "Post")
    }

    @NSManaged public var desc: String?
    @NSManaged public var create_data: Date?
    @NSManaged public var viewers: User?
    @NSManaged public var owners: User?

}
