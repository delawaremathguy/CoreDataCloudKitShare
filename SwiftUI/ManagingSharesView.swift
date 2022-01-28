/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages existing shares.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

struct ManagingSharesView: View {
    @Binding var isPresented: ActiveSheet?
    @Binding var nextSheet: ActiveSheet?

    @State private var toggleProgress: Bool = false
    @State private var selection: String?

    var body: some View {
        ZStack {
            SharePickerView(isPresented: $isPresented, selection: $selection) {
                if  let shareTitle = selection, let share = PersistenceController.shared.share(with: shareTitle) {
                    actionButtons(for: share)
                }
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }
    
    @ViewBuilder
    private func actionButtons(for share: CKShare) -> some View {
        let persistentStore = share.persistentStore
        let isPrivateStore = (persistentStore == PersistenceController.shared.privatePersistentStore)
        
        Button(isPrivateStore ? "Manage Participants" : "View Participants", action: {
            if let share = PersistenceController.shared.share(with: selection!) {
                nextSheet = .participantView(share)
                isPresented = nil
            }
        })
        .disabled(selection == nil)
        
        Button(isPrivateStore ? "Stop Sharing" : "Remove Me", action: {
            if let share = PersistenceController.shared.share(with: selection!) {
                purgeShare(share, in: persistentStore)
            }
        })
        .disabled(selection == nil)

        #if os(iOS)
        Button("Manage With UICloudSharingController", action: {
            if let share = PersistenceController.shared.share(with: selection!) {
                nextSheet = .cloudSharingSheet(share)
                isPresented = nil
            }
        })
        .disabled(selection == nil)
        #endif
    }
    
    private func purgeShare(_ share: CKShare, in persistentStore: NSPersistentStore?) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.purgeObjectsAndRecords(with: share, in: persistentStore)
            toggleProgress.toggle()
            isPresented = nil
        }
    }
}
