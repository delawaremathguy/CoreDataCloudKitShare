/*
 <samplecode>
 <abstract>
 Extensions that wraps the methods related to sharing.
 </abstract>
 </samplecode>
 */

import Foundation
import CoreData
import UIKit
import CloudKit

#if os(iOS) // UICloudSharingController is only available on iOS
// MARK: - Convenient methods for managing sharing.
//
extension PersistenceController {
    func presentCloudSharingController(photo: Photo) {
        /**
         Grab the share if the photo is already shared.
         */
        var photoShare: CKShare?
        if let shareSet = try? persistentContainer.fetchShares(matching: [photo.objectID]),
           let (_, share) = shareSet.first {
            photoShare = share
        }

        let sharingController: UICloudSharingController
        if photoShare == nil {
            sharingController = newSharingController(unsharedPhoto: photo, persistenceController: self)
        } else {
            sharingController = UICloudSharingController(share: photoShare!, container: cloudKitContainer)
        }
        sharingController.delegate = self
        /**
         Setting the presentation style to .formSheet so no need to specify sourceView, sourceItem or sourceRect.
         */
        if let viewController = rootViewController {
            sharingController.modalPresentationStyle = .formSheet
            viewController.present(sharingController, animated: true)
        }
    }
    
    func presentCloudSharingController(share: CKShare) {
        let sharingController = UICloudSharingController(share: share, container: cloudKitContainer)
        sharingController.delegate = self
        /**
         Setting the presentation style to .formSheet so no need to specify sourceView, sourceItem or sourceRect.
         */
        if let viewController = rootViewController {
            sharingController.modalPresentationStyle = .formSheet
            viewController.present(sharingController, animated: true)
        }
    }
    
    private func newSharingController(unsharedPhoto: Photo, persistenceController: PersistenceController) -> UICloudSharingController {
        return UICloudSharingController { (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
            /**
             Doesn't specify a share intentionally so Core Data creates a new share (zone).
             CloudKit has a limit on how many zones a database can have, so apps should use existing shares if possible to avoid hitting the limit,

             If the share's publicPermission is CKShareParticipantPermissionNone, only private participants can accept the share.
             ( Private participants mean the participants an app adds to a share by calling CKShare.addParticipant.)
             If the share is more permissive (hence is a public share), anyone with the shareURL can accept (or "self-add" themselves to) it.
             The default value of publicPermission is CKShare.ParticipantPermission.none
             */
            self.persistentContainer.share([unsharedPhoto], to: nil) { objectIDs, share, container, error in
                if let share = share {
                    self.configure(share: share)
                }
                completion(share, container, error)
            }
        }
    }

    private var rootViewController: UIViewController? {
        for scene in UIApplication.shared.connectedScenes {
            if scene.activationState == .foregroundActive,
               let sceneDeleate = (scene as? UIWindowScene)?.delegate as? UIWindowSceneDelegate,
               let window = sceneDeleate.window {
                return window?.rootViewController
            }
        }
        print("\(#function): Failed to retrieve the window's root view controller.")
        return nil
    }
}

extension PersistenceController: UICloudSharingControllerDelegate {
    /**
     CloudKit triggers the delegate method in two cases:
     - A owner stops sharing a share.
     - A participant removes themselves from a share by tapping the "Remove Me" button in UICloudSharingController.
     
     After stopping the sharing,  purge the zone or just wait for an import to update the local store.
     This sample chooses to purge the zone to avoid stale UI. That triggers a "zone not found" error because UICloudSharingController
     has deleted the zone, but doesn't really matter in this context.
     
     Purging the zone has a caveat:
     - When sharing an object from the owner side, Core Data moves the object to the shared zone;
     - When calling purgeObjectsAndRecordsInZone, Core Data removes all the objects and records in the zone.
     To keep the objects, deep copy the object graph you would like to keep and relate it to an unshared object (relationship).
     
     The purge API posts an NSPersistentStoreRemoteChange notification after finishing its job, so observe the notification to update
     the UI if necessary.
     */
    //#-code-listing(cloudSharingControllerDidStopSharing)
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let share = csc.share {
            purgeObjectsAndRecords(with: share)
        }
    }
    //#-end-code-listing

    //#-code-listing(cloudSharingControllerDidSaveShare)
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let share = csc.share, let persistentStore = share.persistentStore {
            persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
                if let error = error {
                    print("\(#function): Failed to persist updated share: \(error)")
                }
            }
        }
    }
    //#-end-code-listing

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("\(#function): Failed to save a share: \(error)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return csc.share?.title ?? "A cool photo"
    }
}
#endif

#if os(watchOS)
extension PersistenceController {
    func presentCloudSharingController(share: CKShare) {
        print("\(#function): Cloud sharing controller is unavailable on watchOS.")
    }
}
#endif

extension PersistenceController {
    
    //#-code-listing(shareObject)
    func shareObject(_ unsharedObject: NSManagedObject, to existingShare: CKShare?,
                     completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
    //#-end-code-listing
    {
        persistentContainer.share([unsharedObject], to: existingShare) { (objectIDs, share, container, error) in
            guard error == nil, let share = share else {
                print("\(#function): Failed to share an object: \(error!))")
                completionHandler?(share, error)
                return
            }
            /**
             Deduplicate tags if necessary because adding a photo to an existing share moves the whole object graph to the associated
             record zone, which can lead to duplicated tags.
             */
            if existingShare != nil {
                if let tagObjectIDs = objectIDs?.filter({ $0.entity.name == "Tag" }), !tagObjectIDs.isEmpty {
                    self.deduplicateAndWait(tagObjectIDs: Array(tagObjectIDs))
                }
            } else {
                self.configure(share: share)
            }
            /**
             Synchronize the changes on the share to the private persistent store.
             */
            self.persistentContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
                if let error = error {
                    print("\(#function): Failed to persist updated share: \(error)")
                }
                completionHandler?(share, error)
            }
        }
    }
    
    /**
     Delete the Core Data objects and the records in the CloudKit record zone associcated with the share.
     */
    func purgeObjectsAndRecords(with share: CKShare, in persistentStore: NSPersistentStore? = nil) {
        guard let store = (persistentStore ?? share.persistentStore) else {
            print("\(#function): Failed to find the persistent store for share. \(share))")
            return
        }
        persistentContainer.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { (zoneID, error) in
            if let error = error {
                print("\(#function): Failed to purge objects and records: \(error)")
            }
        }
    }

    func existingShare(photo: Photo) -> CKShare? {
        if let shareSet = try? persistentContainer.fetchShares(matching: [photo.objectID]),
           let (_, share) = shareSet.first {
            return share
        }
        return nil
    }
    
    func share(with title: String) -> CKShare? {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentContainer.fetchShares(in: stores)
        let share = shares?.first(where: { $0.title == title })
        return share
    }
    
    func shareTitles() -> [String] {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentContainer.fetchShares(in: stores)
        return shares?.map { $0.title } ?? []
    }
    
    private func configure(share: CKShare, with photo: Photo? = nil) {
        share[CKShare.SystemFieldKey.title] = "A cool photo"
    }
}

extension PersistenceController {
    func addParticipant(emailAddress: String, permission: CKShare.ParticipantPermission = .readWrite, share: CKShare,
                        completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)?) {
        /**
         Use the email address to look up the participant from the private store. Return  if the participant doesn't exist.
         Use privatePersistentStore directly because only owner may add participants to a share.
         */
        let lookupInfo = CKUserIdentity.LookupInfo(emailAddress: emailAddress)
        let persistentStore = privatePersistentStore //share.persistentStore!

        persistentContainer.fetchParticipants(matching: [lookupInfo], into: persistentStore) { (results, error) in
            guard let participants = results, let participant = participants.first, error == nil else {
                completionHandler?(share, error)
                return
            }
                  
            //#-code-listing(addParticipant)
            participant.permission = permission
            participant.role = .privateUser
            share.addParticipant(participant)
            
            self.persistentContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
                if let error = error {
                    print("\(#function): Failed to persist updated share: \(error)")
                }
                completionHandler?(share, error)
            }
            //#-end-code-listing
        }
    }
    
    func deleteParticipant(_ participants: [CKShare.Participant], share: CKShare,
                           completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)?) {
        for participant in participants {
            share.removeParticipant(participant)
        }
        /**
         Use privatePersistentStore directly because only owner may delete participants to a share.
         */
        persistentContainer.persistUpdatedShare(share, in: privatePersistentStore) { (share, error) in
            if let error = error {
                print("\(#function): Failed to persist updated share: \(error)")
            }
            completionHandler?(share, error)
        }
    }
}

extension CKShare.ParticipantAcceptanceStatus {
    var stringValue: String {
        return ["Unknown", "Pending", "Accepted", "Removed"][rawValue]
    }
}

extension CKShare {
    var title: String {
        guard let date = creationDate else {
            return "Share-\(UUID().uuidString)"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Share-" + formatter.string(from: date)
    }
    
    var persistentStore: NSPersistentStore? {
        let persistentContainer = PersistenceController.shared.persistentContainer
        let privatePersistentStore = PersistenceController.shared.privatePersistentStore
        if let shares = try? persistentContainer.fetchShares(in: privatePersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return privatePersistentStore
            }
        }
        let sharedPersistentStore = PersistenceController.shared.sharedPersistentStore
        if let shares = try? persistentContainer.fetchShares(in: sharedPersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return sharedPersistentStore
            }
        }
        return nil
    }
}
