/*
 <samplecode>
 <abstract>
 The SwiftUI app for iOS.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData

@main
struct CoreDataCloudKitShareApp: App {
    // swiftlint:disable weak_delegate
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    // swiftlint:enable weak_delegate
    private let persistentContainer = PersistenceController.shared.persistentContainer

    var body: some Scene {
        #if InitializeCloudKitSchema
        WindowGroup {
            Text("Initializing CloudKit Schema...").font(.title)
            Text("Stop after Xcode says 'no more requests to execute', " +
                 "then check with CloudKit Console if the schema is created correctly.").padding()
        }
        #else
        WindowGroup {
            PhotoGridView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
        #endif
    }
}
