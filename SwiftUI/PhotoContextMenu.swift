/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages the actions on a photo.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

struct PhotoContextMenu: View {
    @Binding var activeSheet: ActiveSheet?
    @Binding var nextSheet: ActiveSheet?
    private let photo: Photo

    @State private var isPhotoShared: Bool
    @State private var hasAnyShare: Bool
    @State private var toggleProgress: Bool = false
    
    init(activeSheet: Binding<ActiveSheet?>, nextSheet: Binding<ActiveSheet?>, photo: Photo) {
        _activeSheet = activeSheet
        _nextSheet = nextSheet
        self.photo = photo
        isPhotoShared = (PersistenceController.shared.existingShare(photo: photo) != nil)
        hasAnyShare = PersistenceController.shared.shareTitles().isEmpty ? false : true
    }

    var body: some View {
        /**
         CloudKit has a limit on how many zones a database can have. To avoid hitting the limit,
         apps use the existing share if possible.
         */
        ZStack {
            ScrollView {
                menuButtons()
            }
            if toggleProgress {
                ProgressView()
            }
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    @ViewBuilder
    private func menuButtons() -> some View {
        /**
         For photos in the private database, allow creating a new share or adding to an existing share.
         For photos in the shared database, allow managing participation.
         */
        if PersistenceController.shared.privatePersistentStore.contains(manageObject: photo) {
            Button("Create New Share", action: {
                createNewShare(photo: photo)
            })
            .disabled(isPhotoShared)
            
            Button("Add to Existing Share", action: {
                activeSheet = .sharePicker(photo)
            })
            .disabled(isPhotoShared || !hasAnyShare)
        } else {
            Button("Manage Participation", action: {
                manageParticipation(photo: photo)
            })
        }
        /**
        Tagging and rating.
         */
        Divider()
        Button("Tag", action: {
            activeSheet = .taggingView(photo)
        })
        Button("Rate", action: {
            activeSheet = .ratingView(photo)
        })
        /**
         Show the delete button if the user is editing photos and has the permission to delete.
         */
        if PersistenceController.shared.persistentContainer.canDeleteRecord(forManagedObjectWith: photo.objectID) {
            Divider()
            Button("Delete", role: .destructive, action: {
                PersistenceController.shared.delete(photo: photo)
                activeSheet = nil
            })
        }
    }

    /**
     Use UICloudSharingController to manage the share on iOS.
     On watchOS, UICloudSharingController is unavailable, so create the share using Core Data API.
     */
    #if os(iOS)
    private func createNewShare(photo: Photo) {
         PersistenceController.shared.presentCloudSharingController(photo: photo)
    }
    
    private func manageParticipation(photo: Photo) {
        PersistenceController.shared.presentCloudSharingController(photo: photo)
    }
    
    #elseif os(watchOS)
    /**
     Sharing a photo can take a while so dispatch to a global queue so SwiftUI has a chance to show the progress view.
     @State variables are thread-safe, so don't need to dispatch back the main queue.
     */
    private func createNewShare(photo: Photo) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.shareObject(photo, to: nil) { share, error in
                toggleProgress.toggle()
                if let share = share {
                    nextSheet = .participantView(share)
                    activeSheet = nil
                }
            }
        }
    }
    
    private func manageParticipation(photo: Photo) {
        nextSheet = .managingSharesView
        activeSheet = nil
    }
    #endif
    
    /**
     Ignore the notification in the following cases:
     - It is not relevant to the private database.
     - It doesn't have any transaction. When a share changes, Core Data triggers a store remote change notification with no transaction.
     */
    private func processStoreChangeNotification(_ notification: Notification) {
        guard let storeUUID = notification.userInfo?[UserInfoKey.storeUUID] as? String,
              storeUUID == PersistenceController.shared.privatePersistentStore.identifier else {
            return
        }
        guard let transactions = notification.userInfo?[UserInfoKey.transactions] as? [NSPersistentHistoryTransaction],
              transactions.isEmpty else {
            return
        }
        isPhotoShared = (PersistenceController.shared.existingShare(photo: photo) != nil)
        hasAnyShare = PersistenceController.shared.shareTitles().isEmpty ? false : true
    }
}
