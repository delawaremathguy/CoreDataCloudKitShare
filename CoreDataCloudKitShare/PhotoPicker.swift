/*
 <samplecode>
 <abstract>
 A UIViewControllerRepresentable that wraps PHPickerViewController.
 </abstract>
 </samplecode>
 */

import SwiftUI
import PhotosUI
import CoreData

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var isPresented: ActiveSheet?
    let persistenceController = PersistenceController.shared
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        let configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> PhotoPickerCoordinator {
        PhotoPickerCoordinator(photoPicker: self)
    }
}

/**
 The coordinator class that saves the picked image to the Core Data store.
 */
class PhotoPickerCoordinator: PHPickerViewControllerDelegate {
    private var photoPicker: PhotoPicker
    
    init(photoPicker: PhotoPicker) {
        self.photoPicker = photoPicker
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                guard let image = object as? UIImage else {
                    print("Failed to load UIImage from the picker reuslt.")
                    return
                }
                self.saveImage(image)
            }
        }
        // The system doesn’t automatically dismiss the picker so toggle isPresented to do that.
        photoPicker.isPresented = nil
    }
    
    private func saveImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 1) else {
            print("\(#function): Failed to retrieve JPG data and URL of the picked image.")
            return
        }
        guard let thumbnailData = thumbnail(with: imageData)?.jpegData(compressionQuality: 1) else {
            print("\(#function): Failed to create a thumbnail for the picked image.")
            return
        }
        let controller = photoPicker.persistenceController
        let taskContext = controller.persistentContainer.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        controller.addPhoto(photoData: imageData, thumbnailData: thumbnailData, context: taskContext)
    }
    
    private func thumbnail(with imageData: Data, pixelSize: Int = 120) -> UIImage? {
        let options = [kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceThumbnailMaxPixelSize: pixelSize] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        let imageReference = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)!
        return UIImage(cgImage: imageReference)
    }
}
