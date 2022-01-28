/*
 <samplecode>
 <abstract>
 The WatchKit extension delegate class.
 </abstract>
 </samplecode>
 */

import WatchKit
import CloudKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    /**
     To be able to accept a share, add a CKSharingSupported entry in the info.plist file of the WatchKit app and set it to true.
     */
    func userDidAcceptCloudKitShare(with cloudKitShareMetadata: CKShare.Metadata) {
        let persistenceController = PersistenceController.shared
        let sharedStore = persistenceController.sharedPersistentStore
        let container = persistenceController.persistentContainer
        container.acceptShareInvitations(from: [cloudKitShareMetadata], into: sharedStore) { (_, error) in
            if let error = error {
                print("\(#function): Failed to accept share invitations: \(error)")
            }
        }
    }
}
