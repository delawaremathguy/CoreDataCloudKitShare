/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages a grid item.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData

struct PhotoGridItemView: View {
    /**
     This sample doesn't use editButton and editMode because they are unavalable on watchOS.
     It uses the delete button in the action list to handle the deletion.
     */
    @ObservedObject var photo: Photo
    var itemSize: CGSize
    private let persistenceController = PersistenceController.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            /**
             Show the thumbnail image, or a place holder if the thumbnail data doesn't exist.
             */
            if let data = photo.thumbnail?.data, let thumbnail = UIImage(data: data) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: itemSize.width, height: itemSize.height)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 30))
                    .frame(width: itemSize.width, height: itemSize.height)
            }
            topLeftButton()
        }
        .frame(width: itemSize.width, height: itemSize.height)
        .background(Color.gridItemBackground)
    }
    
    @ViewBuilder
    private func topLeftButton() -> some View {
        if persistenceController.sharedPersistentStore.contains(manageObject: photo) {
            Image(systemName: "person.2.circle")
                .foregroundColor(.gray)
        }
    }
}
