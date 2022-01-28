/*
 <samplecode>
 <abstract>
 A SwiftUI view that manages photo tagging.
 </abstract>
 </samplecode>
 */

import SwiftUI
import CoreData

struct TaggingView: View {
    @Binding var isPresented: ActiveSheet?
    
    @State private var filterTagName = ""
    @State private var wasPhotoDeleted: Bool

    private let photo: Photo
    /**
     Retrieving the photo's persistent store (photo.persistentStore) is expensive, so cache it with a member varible
     and provide it to FilteredTagList, as FilteredTagList refreshes frequently when the user inputs.
     */
    private let affectedStore: NSPersistentStore?

    init(isPresented: Binding<ActiveSheet?>, photo: Photo) {
        _isPresented = isPresented
        self.photo = photo
        wasPhotoDeleted = photo.isDeleted
        affectedStore = photo.persistentStore
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if wasPhotoDeleted {
                    Text("The photo was deleted remotely.").padding()
                    Spacer()
                } else {
                    FilteredTagList(filterTagName: $filterTagName, photo: photo, affectedStore: affectedStore)
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Dismiss", action: { isPresented = nil })
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Tags")
        }
        .onReceive(NotificationCenter.default.storeDidChangePublisher) { _ in
            wasPhotoDeleted = photo.isDeleted
        }
    }
}

struct FilteredTagList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var filterTagName: String

    private let photo: Photo
    private let canUpdate: Bool
    private let affectedStore: NSPersistentStore?

    @State private var toggleProgress: Bool = false

    private let fetchRequest: FetchRequest<Tag>
    private var tags: [Tag] {
        let allTags = Array(fetchRequest.wrappedValue)
        return PersistenceController.shared.filterTags(from: allTags, forTagging: photo)
    }
    
    /**
     Retrieving the photo's persistent store (photo.persistentStore) is expensive, so relies on the parent view to provide it.
     */
    init(filterTagName: Binding<String>, photo: Photo, affectedStore: NSPersistentStore?) {
        _filterTagName = filterTagName
        self.photo = photo
        self.affectedStore = affectedStore
        /**
         Use a fetch request with a predicate based on the specified filtered tag name, and specify its affected store.
         */
        var predicate = NSPredicate(value: true)
        if !filterTagName.wrappedValue.isEmpty {
            predicate = NSPredicate(format: "name CONTAINS[cd] %@", filterTagName.wrappedValue)
        }
        let nsFetchRequest = Tag.fetchRequest()
        nsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        nsFetchRequest.predicate = predicate
        if let affectedStore = affectedStore {
            nsFetchRequest.affectedStores = [affectedStore]
        }
        
        fetchRequest = FetchRequest(fetchRequest: nsFetchRequest, animation: .default)
        
        let container = PersistenceController.shared.persistentContainer
        canUpdate = container.canUpdateRecord(forManagedObjectWith: photo.objectID)
    }
    
    var body: some View {
        ZStack {
            /**
             List -> Section header + section content triggers a strange animation when deleting an item.
             Moving the header out (like below) fixes the animation issue, but the toolbar item doesn't work on watchOS.
             SectionHeader().padding(EdgeInsets(top: 5, leading: 10, bottom: 0, trailing: 0))
             List {
                 SectionContent()
             }
             */
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
        if canUpdate {
            TagListHeader(toggleProgress: $toggleProgress, filterTagName: $filterTagName, tags: tags, photo: photo)
        }
    }
    
    @ViewBuilder
    private func sectionContent() -> some View {
        ForEach(tags) { tag in
            HStack {
                Text("\(tag.name!)")
                Spacer()
                if let photoTags = photo.tags, photoTags.contains(tag) {
                    Image(systemName: "checkmark")
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggleTagging(tag: tag) }
        }
        .onDelete(perform: deleteTags)
    }
    
    private func deleteTags(offsets: IndexSet) {
        if canUpdate {
            withAnimation {
                let tagsToBeDeleted = offsets.map { tags[$0] }
                for tag in tagsToBeDeleted {
                    PersistenceController.shared.deleteTag(tag)
                }
            }
        }
    }
    
    private func toggleTagging(tag: Tag) {
        if canUpdate {
            PersistenceController.shared.toggleTagging(photo: photo, tag: tag)
        }
    }
}

struct TagListHeader: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var toggleProgress: Bool
    @Binding var filterTagName: String
    
    private let photo: Photo
    private let tags: [Tag]
    
    init(toggleProgress: Binding<Bool>, filterTagName: Binding<String>, tags: [Tag], photo: Photo) {
        _toggleProgress = toggleProgress
        _filterTagName = filterTagName
        self.tags = tags
        self.photo = photo
    }

    var body: some View {
        HStack {
            TextField( "Name", text: $filterTagName)
            
            Button(action: addTag) {
                Image(systemName: "plus.circle")
                    .imageScale(.large)
                    .font(.system(size: 18))
            }
            .frame(width: 20)
            .buttonStyle(.plain)
            .disabled(filterTagName.isEmpty || tags.map { $0.name }.contains(filterTagName))
        }
        .frame(height: 30)
        .padding(5)
        .background(Color.listHeaderBackground)
    }
    
    private func addTag() {
        guard !filterTagName.isEmpty else {
            return
        }
        toggleProgress.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                PersistenceController.shared.addTag(name: filterTagName, relateTo: photo)
                toggleProgress.toggle()
                filterTagName = ""
            }
        }
    }
}
