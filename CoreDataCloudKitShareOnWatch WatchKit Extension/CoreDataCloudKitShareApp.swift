/*
 <samplecode>
 <abstract>
 The SwiftUI app for watchOS.
 </abstract>
 </samplecode>
 */

import SwiftUI

@main
struct CoreDataCloudKitShareApp: App {
    @WKExtensionDelegateAdaptor var delegateOfExtension: ExtensionDelegate

    let persistenceController = PersistenceController.shared

    @SceneBuilder var body: some Scene {
        WindowGroup {
            PhotoGridView()
                .environment(\.managedObjectContext, persistenceController.persistentContainer.viewContext)
        }
    }
}
