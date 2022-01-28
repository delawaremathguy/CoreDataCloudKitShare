/*
 <samplecode>
 <abstract>
 A SwiftUI view that picks an existing share.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

struct SharePickerView<ActionView: View>: View {
    @Binding private var isPresented: ActiveSheet?
    @Binding private var selection: String?
    
    private let actionView: ActionView
    @State private var shareTitles = PersistenceController.shared.shareTitles()

    init(isPresented: Binding<ActiveSheet?>, selection: Binding<String?>, @ViewBuilder actionView: () -> ActionView) {
        _isPresented = isPresented
        _selection = selection
        self.actionView = actionView()
    }

    var body: some View {
        NavigationView {
            VStack {
               if shareTitles.isEmpty {
                   Text("No share exists. Please create a new share for a photo, then try again.").padding()
                   Spacer()
               } else {
                   Form {
                       Section(header: Text("Pick a share")) {
                           ShareListView(selection: $selection, shareTitles: $shareTitles)
                       }
                       Section {
                           actionView
                       }
                   }
               }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Dismiss", action: { isPresented = nil })
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Shares")
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    /**
     Update the share list if necessary. Ignore the notification in the following cases:
     - The notification is not relevant to the private database.
     - The notification transaction is not empty. When a share changes, Core Data triggers a store remote change notification with no transaction.
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
        shareTitles = PersistenceController.shared.shareTitles()
    }

}

private struct ShareListView: View {
    @Binding var selection: String?
    @Binding var shareTitles: [String]

    var body: some View {
        List(shareTitles, id: \.self) { shareTitle in
            HStack {
                Text(shareTitle)
                Spacer()
                if selection == shareTitle {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selection = (selection == shareTitle) ? nil : shareTitle
            }
        }
    }
}

