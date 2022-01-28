/*
 <samplecode>
 <abstract>
 A SwiftUI view that adds a photo to an existing share.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData
import CloudKit

struct AddToExistingShareView: View {
    @Binding var isPresented: ActiveSheet?
    var photo: Photo
    
    @State private var toggleProgress: Bool = false
    @State private var selection: String?

    var body: some View {
        ZStack {
            SharePickerView(isPresented: $isPresented, selection: $selection) {
                Button("Add", action: {
                    sharePhoto(photo, shareTitle: selection)
                })
                .disabled(selection == nil)
            }
            if toggleProgress {
                ProgressView()
            }
        }
    }
    
    private func sharePhoto(_ unsharedPhoto: Photo, shareTitle: String?) {
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let persistenceController = PersistenceController.shared
            if let shareTitle = shareTitle, let share = persistenceController.share(with: shareTitle) {
                persistenceController.shareObject(unsharedPhoto, to: share)
            }
            toggleProgress.toggle()
            isPresented = nil
        }
    }
}
