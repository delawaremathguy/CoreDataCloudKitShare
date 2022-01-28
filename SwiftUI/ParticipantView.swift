/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages the participants of a share.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

/**
 Managing a participant only makes sense when the share exists and is a private share.
 A private share is a share whose publicPermission equals to .none.
 A public share means a share whose publicPermission is more permissive. Any person who has the share link can
 self-add themselves to a public share.
 */
struct ParticipantView: View {
    @Binding var isPresented: ActiveSheet?
    private let share: CKShare

    @State private var toggleProgress: Bool = false
    @State private var participants: [Participant]
    @State private var wasShareDeleted = false
    
    private let canUpdateParticipants: Bool
    
    init(isPresented: Binding<ActiveSheet?>, share: CKShare) {
        _isPresented = isPresented
        self.share = share
        participants = share.participants.filter { $0.role != .owner }.map { Participant($0) }
        
        let privateStore = PersistenceController.shared.privatePersistentStore
        canUpdateParticipants = (share.persistentStore == privateStore)
    }

    var body: some View {
        NavigationView {
            VStack {
                if wasShareDeleted {
                    Text("The share was deleted remotely.").padding()
                    Spacer()
                } else {
                    participantListView()
                }
            }
            .toolbar { toolbarItems() }
            .listStyle(PlainListStyle())
            .navigationTitle("Participants")
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    /**
     List -> Section header + section content triggers a strange animation when deleting an item.
     Moving the header out (like below) fixes the animation issue, but the toolbar item doesn't work on watchOS.
     ParticipantListHeader(participants: $participants, share: share)
         .padding(EdgeInsets(top: 5, leading: 10, bottom: 0, trailing: 0))
     List {
         SectionContent()
     }
     */
    @ViewBuilder
    private func participantListView() -> some View {
        ZStack {
            List {
                Section(header: sectionHeader()) {
                    sectionContent()
                }
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader() -> some View {
        if canUpdateParticipants {
            ParticipantListHeader(toggleProgress: $toggleProgress,
                                  participants: $participants, share: share)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func sectionContent() -> some View {
        ForEach(participants, id: \.self) { participant in
            HStack {
                Text(participant.ckShareParticipant.userIdentity.lookupInfo?.emailAddress ?? "")
                Spacer()
                Text(participant.ckShareParticipant.acceptanceStatus.stringValue)
            }
        }
        .onDelete(perform: canUpdateParticipants ? deleteParticipant : nil)
    }
    
    @ToolbarContentBuilder
    private func toolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(action: { isPresented = nil }) {
                Text("Dismiss")
            }
        }
        /**
         "Copy Link" is only available for iOS because watchOS doesn't support UIPasteboard.s
         */
        #if os(iOS)
        ToolbarItem(placement: .bottomBar) {
            Button(action: { UIPasteboard.general.url = share.url }) {
                Text("Copy Link")
            }
        }
        #endif
    }
    
    private func deleteParticipant(offsets: IndexSet) {
        withAnimation {
            let ckShareParticipants = offsets.map { participants[$0].ckShareParticipant }
            PersistenceController.shared.deleteParticipant(ckShareParticipants, share: share) { share, error in
                if error == nil, let updatedShare = share {
                    participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
                }
            }
        }
    }
    
    /**
     Ignore the notification in the following cases:
     - The notification is not relevant to the private database.
     - The notification transaction is not empty. When a share changes, Core Data triggers a store remote change notification with no transaction.
     In that case, grab the share with the same title, and use it to update the UI.
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
        if let updatedShare = PersistenceController.shared.share(with: share.title) {
            participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
            
        } else {
            wasShareDeleted = true
        }
    }
}

private struct ParticipantListHeader: View {
    @Binding var toggleProgress: Bool
    @Binding var participants: [Participant]
    var share: CKShare
    @State private var emailAddress: String = ""

    var body: some View {
        HStack {
            TextField( "Email", text: $emailAddress)
            Button(action: addParticipant) {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
                    .font(.system(size: 18))
            }
            .frame(width: 20)
            .buttonStyle(.plain)
        }
        .frame(height: 30)
        .padding(5)
        .background(Color.listHeaderBackground)
    }
    
    /**
     If the participant already exists, no need to do anything.
     */
    private func addParticipant() {
        let isExistingParticipant = share.participants.contains {
            $0.userIdentity.lookupInfo?.emailAddress == emailAddress
        }
        if isExistingParticipant {
            return
        }
        
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            PersistenceController.shared.addParticipant(emailAddress: emailAddress, share: share) { share, error in
                if error == nil, let updatedShare = share {
                    DispatchQueue.main.async {
                        participants = updatedShare.participants.filter { $0.role != .owner }.map { Participant($0) }
                        emailAddress = ""
                        toggleProgress.toggle()
                    }
                }
            }
        }
    }
}

/**
 A struct that wraps CKShare.Participant and implements Equatable to trigger SwiftUI update when any of the following state changes:
 - userIdentity
 - acceptanceStatus
 - permission
 - role.
 */
private struct Participant: Hashable, Equatable {
    let ckShareParticipant: CKShare.Participant

    init(_ ckShareParticipant: CKShare.Participant) {
        self.ckShareParticipant = ckShareParticipant
    }

    static func == (lhs: Participant, rhs: Participant) -> Bool {
        let lhsElement = lhs.ckShareParticipant
        let rhsElement = rhs.ckShareParticipant
        
        if lhsElement.userIdentity != rhsElement.userIdentity ||
            lhsElement.acceptanceStatus != rhsElement.acceptanceStatus ||
            lhsElement.permission != rhsElement.permission ||
            lhsElement.role != rhsElement.role {
            return false
        }
        return true
    }
}
