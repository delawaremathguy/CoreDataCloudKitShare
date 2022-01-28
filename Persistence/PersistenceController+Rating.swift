/*
 <samplecode>
 <abstract>
 An extension that wraps the methods related to the Rating entity.
 </abstract>
 </samplecode>
 */

import Foundation
import CoreData

// MARK: - Convenient methods for managing tags.
//
extension PersistenceController {
   
     func addRating(value: Int16, relateTo photo: Photo) {
        if let context = photo.managedObjectContext {
            context.performAndWait {
                let rating = Rating(context: context)
                rating.value = value
                rating.photo = photo
                context.save(with: .addRating)
            }
        }
    }
    
    func deleteRating(_ rating: Rating) {
        if let context = rating.managedObjectContext {
            context.performAndWait {
                context.delete(rating)
                context.save(with: .deleteRating)
            }
        }
    }
}
