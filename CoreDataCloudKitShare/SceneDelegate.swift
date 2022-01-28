/*
 <samplecode>
 <abstract>
 The scene delegate class.
 </abstract>
 </samplecode>
 */

import UIKit
import CloudKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    /**
     To be able to accept a share, add a CKSharingSupported entry in the info.plist file and set it to true.
     */
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
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
