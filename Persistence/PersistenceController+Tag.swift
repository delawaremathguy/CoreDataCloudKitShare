/*
 <samplecode>
 <abstract>
 Extensions that wrap the methods related to the Tag entity.
 </abstract>
 </samplecode>
 */

import Foundation
import CoreData
import CloudKit

// MARK: - Convenient methods for managing tags.
//
extension PersistenceController {
    func numberOfTags(with tagName: String) -> Int {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "\(Tag.Schema.name.rawValue) == %@", tagName)
        
        let number = try? persistentContainer.viewContext.count(for: fetchRequest)
        return number ?? 0
    }

    func addTag(name: String, relateTo photo: Photo) {
        if let context = photo.managedObjectContext {
            context.performAndWait {
                let tag = Tag(context: context)
                tag.name = name
                tag.uuid = UUID()
                tag.addToPhotos(photo)
                context.save(with: .addTag)
            }
        }
    }
    
    func deleteTag(_ tag: Tag) {
        if let context = tag.managedObjectContext {
            context.performAndWait {
                context.delete(tag)
                context.save(with: .deleteTag)
            }
        }
    }
    
    func toggleTagging(photo: Photo, tag: Tag) {
        if let context = photo.managedObjectContext {
            context.performAndWait {
                if let photoTags = photo.tags, photoTags.contains(tag) {
                    photo.removeFromTags(tag)
                } else {
                    photo.addToTags(tag)
                }
                context.save(with: .toggleTagging)
            }
        }
    }
    /**
     Return the tags that the app can use to tag the specified photo (or in the same CloudKit zone as the photo).
     */
    func filterTags(from tags: [Tag], forTagging photo: Photo) -> [Tag] {
        guard let context = photo.managedObjectContext else {
            print("\(#function): Tagging a photo that isn't in a context is unsupported.")
            return []
        }
        /**
         Fetch the share for the photo
         */
        var photoShare: CKShare?
        if let result = try? persistentContainer.fetchShares(matching: [photo.objectID]) {
            photoShare = result[photo.objectID]
        }
        /**
         Gather the object IDs of the tags that are valid for tagging the photo.
         - Tags that are already in photo.tags are valid.
         - Tags that have the same share as photoShare is valid.
         */
        var filteredTags = [Tag]()
        context.performAndWait {
            for tag in tags {
                if let photoTags = photo.tags, photoTags.contains(tag) {
                    filteredTags.append(tag)
                    continue
                }
                let tagShare = existingShare(tag: tag)
                if photoShare?.recordID.zoneID == tagShare?.recordID.zoneID {
                    filteredTags.append(tag)
                }
            }
        }
        return filteredTags
    }
    
    /**
     Fetch and return the share of the tag and its related photos.
     Consider the related photos as well.
     */
    private func existingShare(tag: Tag) -> CKShare? {
        var objectIDs = [tag.objectID]
        if let photoSet = tag.photos, let photos = Array(photoSet) as? [Photo] {
            objectIDs += photos.map { $0.objectID }
        }
        let result = try? persistentContainer.fetchShares(matching: objectIDs)
        return result?.values.first
    }
}

// MARK: - An extension for Tag.
//
extension Tag {
    /**
     The name of relevant tag attributes.
     */
    enum Schema: String {
        case name, uuid
    }
    
    class func tagIfExists(with name: String, context: NSManagedObjectContext) -> Tag? {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "\(Schema.name.rawValue) == %@", name)
        let tags = try? context.fetch(fetchRequest)
        return tags?.first
    }
}
