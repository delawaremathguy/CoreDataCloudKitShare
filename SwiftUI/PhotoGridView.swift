/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages a photo collection.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

enum ActiveSheet: Identifiable, Equatable {
    #if os(iOS)
    case photoPicker // Unavailable on watchOS
    #elseif os(watchOS)
    case photoContextMenu(Photo) // .contextMenu is deprecated on watchOS so use action list instead.
    #endif
    case cloudSharingSheet(CKShare)
    case managingSharesView
    case sharePicker(Photo)
    case taggingView(Photo)
    case ratingView(Photo)
    case participantView(CKShare)
    /**
     Use the enum member name string as the id for Identifiable.
     In the case where an enum has an associated value, use the label, which is equal to the member name string.
     */
    var id: String {
        let mirror = Mirror(reflecting: self)
        if let label = mirror.children.first?.label {
            return label
        } else {
            return "\(self)"
        }
    }
}

enum ActiveCover: Identifiable, Equatable {
    case fullImageView(Photo)
    /**
     Use the enum member name string as the id for Identifiable.
     In the case where an enum has an associated value, use the label, which is equal to the member name string.
     */
    var id: String {
        let mirror = Mirror(reflecting: self)
        if let label = mirror.children.first?.label {
            return label
        } else {
            return "\(self)"
        }
    }
}

struct PhotoGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [SortDescriptor(\.uniqueName)],
                  animation: .default
    ) private var photos: FetchedResults<Photo>

    @State private var activeSheet: ActiveSheet?
    @State private var activeCover: ActiveCover?

    /**
     The next active sheet to present after dismissing the current sheet.
     ManagingSharesView uses this variable to switch to UICloudSharingController or participant view.
     */
    @State private var nextSheet: ActiveSheet?

    private let persistenceController = PersistenceController.shared
    private let kGridCellSize = CGSize(width: 118, height: 118)

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    if photos.isEmpty {
                        Text("Tap the add (+) button on the iOS app to add a photo.").padding()
                        Spacer()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: kGridCellSize.width))]) {
                            ForEach(photos, id: \.self) { photo in
                                gridItemView(photo: photo, itemSize: kGridCellSize)
                            }
                        }
                    }
                }
            }
            .toolbar { toolbarItems() }
            .navigationTitle("Photos")
            .sheet(item: $activeSheet, onDismiss: sheetOnDismiss) { item in
                sheetView(with: item)
            }
            .fullScreenCover(item: $activeCover) { item in
                coverView(with: item)
            }

        }
        .navigationViewStyle(.stack)
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { notification in
            processStoreChangeNotification(notification)
        }
    }
    
    @ViewBuilder
    private func gridItemView(photo: Photo, itemSize: CGSize) -> some View {
        #if os(iOS)
        PhotoGridItemView(photo: photo, itemSize: kGridCellSize)
            .contextMenu {
                PhotoContextMenu(activeSheet: $activeSheet, nextSheet: $nextSheet, photo: photo)
            }
            .onTapGesture {
                activeCover = .fullImageView(photo)
            }
        #elseif os(watchOS)
        PhotoGridItemView(photo: photo, itemSize: kGridCellSize)
            .onTapGesture {
                activeSheet = .photoContextMenu(photo)
            }
        #endif
    }

    @ToolbarContentBuilder
    private func toolbarItems() -> some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { activeSheet = .photoPicker }) {
                Label("Add Item", systemImage: "plus").labelStyle(.iconOnly)
            }
        }
        ToolbarItem(placement: .bottomBar) {
            Button("Manage Shares", action: {
                activeSheet = .managingSharesView
            })
        }
        #elseif os(watchOS)
        ToolbarItem(placement: .automatic) {
            Button("Manage Shares", action: { activeSheet = .managingSharesView })
        }
        #endif
    }

    @ViewBuilder
    private func sheetView(with item: ActiveSheet) -> some View {
        switch item {
        #if os(iOS)
        case .photoPicker:
            PhotoPicker(isPresented: $activeSheet)
        #elseif os(watchOS)
        case .photoContextMenu(let photo):
            PhotoContextMenu(activeSheet: $activeSheet, nextSheet: $nextSheet, photo: photo)
        #endif
            
        case .cloudSharingSheet(_):
            // CloudSharingSheet(isPresented: $activeSheet, share: share) // Not used due to Rdar://83684057.
            EmptyView()
        case .managingSharesView:
            ManagingSharesView(isPresented: $activeSheet, nextSheet: $nextSheet)

        case .sharePicker(let photo):
            AddToExistingShareView(isPresented: $activeSheet, photo: photo)

        case .taggingView(let photo):
            TaggingView(isPresented: $activeSheet, photo: photo)

        case .ratingView(let photo):
            RatingView(isPresented: $activeSheet, photo: photo)

        case .participantView(let share):
            ParticipantView(isPresented: $activeSheet, share: share)
        }
    }
    
    /**
     Present the next active sheet if necessary.
     Dispatch asynchronously to the next run loop so the presentation occurs after the current sheet's dismissal.
     */
    private func sheetOnDismiss() {
        guard let nextActiveSheet = nextSheet else {
            return
        }
        switch nextActiveSheet {
        case .cloudSharingSheet(let share):
            DispatchQueue.main.async {
                persistenceController.presentCloudSharingController(share: share)
            }
        default:
            DispatchQueue.main.async {
                activeSheet = nextActiveSheet
            }
        }
        nextSheet = nil
    }
    
    @ViewBuilder
    private func coverView(with item: ActiveCover) -> some View {
        switch item {
        case .fullImageView(let photo):
            FullImageView(isPresented: $activeCover, photo: photo)
        }
    }
    
    /**
     Merge the transactions if any.
     */
    private func processStoreChangeNotification(_ notification: Notification) {
        let transactions = persistenceController.photoTransactions(from: notification)
        if !transactions.isEmpty {
            persistenceController.mergeTransactions(transactions, to: viewContext)
        }
    }
}
