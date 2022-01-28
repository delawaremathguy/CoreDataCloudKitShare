/*
 <samplecode>
 <abstract>
 An extension that wraps the methods related to deduplicating tags.
 </abstract>
 </samplecode>
 */

import CoreData
import CloudKit

// MARK: - Deduplicate tags
//
extension PersistenceController {
    /**
     Deduplicate tags that have a same name and are in the same CloudKit record zone, one tag at a time, on the historyQueue.
     All peers should eventually reach the same result with no coordination or communication.
     */

    //#-code-listing(deduplicateAndWait)
    func deduplicateAndWait(tagObjectIDs: [NSManagedObjectID])
    //#-end-code-listing
    {
        /**
         Make any store changes on a background context with the transaction author name of this app.
         Use performAndWait to serialize the steps. historyQueue runs in the background so this won’t block the main queue.
         */
        let taskContext = persistentContainer.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.performAndWait {
            tagObjectIDs.forEach { tagObjectID in
                deduplicate(tagObjectID: tagObjectID, performingContext: taskContext)
            }
            taskContext.save(with: .deduplicateAndWait)
        }
    }

    /**
     Deduplicate one single tag.
     */
    private func deduplicate(tagObjectID: NSManagedObjectID, performingContext: NSManagedObjectContext) {
        /**
         tag.name can be nil when the app inserts a tag and then ( before processing the insertion ) delete it.
         In that case, silently ignore the deleted tag.
         */
        guard let tag = performingContext.object(with: tagObjectID) as? Tag,
              let tagName = tag.name else {
            print("\(#function): Ignore a tag that was deleted: \(tagObjectID)")
            return
        }
        /**
         Fetch all tags with the same name, sorted by uuid, and return if there are no duplicates.
         */
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Tag.Schema.uuid.rawValue, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "\(Tag.Schema.name.rawValue) == %@", tagName)
        guard var duplicatedTags = try? performingContext.fetch(fetchRequest), duplicatedTags.count > 1 else {
            return
        }
        
        /**
         Filter out the tags that are not in the same CloudKit record zone.
         Only tags that have the same name and are in the same record zone are duplicates.
         The tag zone ID can be nil, which means it isn't a shared tag. The filter rule is still valid in that case.
         */
        let tagZoneID = persistentContainer.recordID(for: tag.objectID)?.zoneID
        duplicatedTags = duplicatedTags.filter {
            self.persistentContainer.recordID(for: $0.objectID)?.zoneID == tagZoneID
        }
        
        guard duplicatedTags.count > 1 else {
            return
        }
        /**
         Pick the first tag as the winner.
         */
        print("\(#function): Deduplicating tag with name: \(tagName), count: \(duplicatedTags.count)")
        let winner = duplicatedTags.first!
        duplicatedTags.removeFirst()
        remove(duplicatedTags: duplicatedTags, winner: winner, performingContext: performingContext)
    }
    
    /**
     Remove duplicate tags from their respective photos, replacing them with the winner.
     */
    private func remove(duplicatedTags: [Tag], winner: Tag, performingContext: NSManagedObjectContext) {
        duplicatedTags.forEach { tag in
            if let photoSet = tag.photos {
                for case let photo as Photo in photoSet {
                    photo.removeFromTags(tag)
                    photo.addToTags(winner)
                }
            }
            performingContext.delete(tag)
        }
    }
}
