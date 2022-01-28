# Sharing Core Data Objects Between iCloud Users
Implement the flow to share data between iCloud users using Core Data CloudKit.

## Overview
More and more people own multiple devices and use them to share digital assets or collaborate work. They expect seamless data synchronization across their devices and an easy way to share data with privacy and security in mind. Apps can support such use cases by moving user data to CloudKit and implementing a data sharing flow that includes features like share management and access control. 

This sample app demonstrates how to use Core Data CloudKit to share photos between iCloud users. Users who share photos, called _owners_, can create a share, send out an invitation, manage the permissions, and stop the sharing. Users who accept the share, called _participants_, can view or edit the photos, or stop participating the share.

## Configure the Sample Code Project
Before building the sample app, perform the following steps in Xcode:
1. In the General pane of the `CoreDataCloudKitShare` target, update the Bundle Identifier field with a new identifier.
2. In the Signing & Capabilities pane, select the applicable team from the Team drop-down menu to let Xcode automatically manage the provisioning profile. See [Assign a project to a team](https://help.apple.com/xcode/mac/current/#/dev23aab79b4) for details.
3. Make sure the iCloud capability is present and the CloudKit option is in a selected state, then select the iCloud container with your bundle identifier from step 1 from the Containers list. If the container doesn’t exist, click the Add button (+), enter the container name (iCloud.<*bundle identifier*>), and click OK to let Xcode create the container and associate it with the app.
4. If you prefer using an existing container, select it from the Containers list. 
5. Specify your iCloud container for the `gCloudKitContainerIdentifier` variable in PersistenceController.swift. An iCloud container identifier is case-sensitive and must begin with "`iCloud.`".
6. Similar to step 1, change the bundle identifiers and the developer team for the WatchKit app and WatchKit Extension targets. The bundle identifiers must be `<The iOS app bundle ID>.watchkitapp` and `<The iOS app bundle ID>.watchkitapp.watchkitextension` respectively.
7. Similar to step 2, specify the iCloud container for the WatchKit Extension target. To synchronize data across iCloud, the iOS app and WatchKit extension must share the same iCloud container.
8. Open the Info.plist file of the WatchKit app target, then change the value of WKCompanionAppBundleIdentifier key to `<The iOS app bundle ID>`.
9. Open the Info.plist file of the WatchKit Extension target, then change the value of NSExtension > NSExtensionAttributes > WKAppBundleIdentifier key to `<The iOS app bundle ID>.watchkitapp`.

To run the sample app on a device, configure the device as follows:
1. Log in with an Apple ID. For the CloudKit private database to synchronize, the Apple ID must be the same on the devices. (For an Apple Watch, log in at the Watch app on the paired iPhone, then make sure the Apple ID shows up on the Settings app on the watch.)
2. For an iOS device, choose Settings > Apple ID > iCloud, and turn on iCloud Drive, if it is off.
3. After running the sample app on the device, go to Settings > Notifications, and make sure “Allow Notifications” is on. For an Apple Watch, use the Watch app on the paired iPhone to make sure that notifications are on for the app.

To create and configure a new project that uses Core Data CloudKit, see [Setting Up Core Data with CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/setting_up_core_data_with_cloudkit?changes=__3).

## Create the CloudKit Schema for Apps
CloudKit apps must have a schema to declare the data types they use. When apps create a record in the CloudKit development environment, CloudKit automatically creates the record type if it doesn't exist. In the production environment, CloudKit doesn't have that capability, nor does it allow removing an existing record type or field, so after finalizing the schema, be sure to deploy it to the production environment. Without doing that, apps that work in the production environment, like the App Store or TestFlight ones, would not work. For more information, see [Deploying an iCloud Container’s Schema](https://developer.apple.com/documentation/cloudkit/managing_icloud_containers_with_the_cloudkit_database_app/deploying_an_icloud_container_s_schema).

Core Data CloudKit apps can use [`initializeCloudKitSchema(options:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3343548-initializecloudkitschema) to create the CloudKit schema that matches their Core Data model, or keep it up to date every time their model changes. The method works by creating fake data for the record types and then delete it, which can take some time and blocks the other CloudKit operations. Apps must not call it in the production environment, or in the normal development process that doesn't include model changes.

To create the CloudKit schema for this sample app, pick the "InitializeCloudKitSchema" target from Xcode's target menu, and run it. Having a target dedicated on CloudKit schema creation separates the `initializeCloudKitSchema(options:)` call from the normal flow. After running the target, be sure to check with [CloudKit Console](http://icloud.developer.apple.com/dashboard/) if every Core Data entity and attribute has a CloudKit counterpart. See [Reading CloudKit Records for Core Data](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/reading_cloudkit_records_for_core_data) for the detailed mapping rules.

For apps that use CloudKit public database, manually add a `Queryable` index for the `recordName` and `modifiedAt` fields of all record types, including the `CDMR` type that Core Data generates to manage many-to-many relationships.

For more information on this topic, see [Creating a Core Data Model for CloudKit](https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit/creating_a_core_data_model_for_cloudkit)

## Try out the Sharing Flow With the Sample App
To create and share a photo using the sample app, follow these steps:
1. Prepare two iOS devices, A and B, and log in with a different Apple ID.
2. Use Xcode to build and run the sample app on the devices.
3. On device A, tap the Add(+) button to show the photo picker, then pick a photo and add it to the Core Data store.
4. Long press the photo to show the action menu, then tap the "Create New Share" button to present the CloudKit sharing UI.
5. Follow the UI to send a link to the Apple ID on device B. Try to use iMessage because it's easier to set up.
6. After receiving the link on device B, tap it to accept and open the share, which launches the sample app and shows the photo.

To discover more features of the sample app:
- On device A, add another photo, long press it and tap the "Add to Existing Share" button, then pick a share and tap the "Add" button. See the photo soon appears on Device B.
- On device B, long press the photo, tap the "Manage Participation" button to present the CloudKit sharing UI, then pick the Apple ID that has "(Me)" suffix and tap "Remove Me" to remove the participation. See the photo disappears.
- Tap the "Manage Shares" button, then pick the share, and try to manage its participants using [`UICloudSharingController`](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller) or the app UI.

It may take some time (minutes or longer) for one user to see the changes from the others. Core Data CloudKit is not for real-time synchronization. When users change the store on their device, it is up to the system to determine when to synchronize the change. There is no API for apps to speed up, slow down, or choose the timing for the synchronization.

## Set up the Core Data Stack
Every CloudKit container has a [private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/1399205-privateclouddatabase) and a [shared database](https://developer.apple.com/documentation/cloudkit/ckcontainer/1640408-sharedclouddatabase). To mirror these databases, set up a Core Data stack with two stores, and set the store's [database scope](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontaineroptions/3580372-databasescope?changes=__3) to `.private` and `.shared`  respectively. 

When setting up the store description, enable [persistent history](https://developer.apple.com/documentation/coredata/persistent_history) tracking and turn on remote change notifications by setting the `NSPersistentHistoryTrackingKey` and `NSPersistentStoreRemoteChangeNotificationPostOptionKey` options to `true`. Core Data relies on the persistent history to track the store changes, and apps need to update their UI when remote changes occur.

- CodeListing: setOption

For apps (under the same developer team) to synchronize data through CloudKit, they must use the same CloudKit container. This sample app explicitly specifies the same container for its iOS and watchOS apps when setting up the CloudKit container options:

- CodeListing: NSPersistentCloudKitContainerOptions

## Share a Core Data object
Sharing a Core Data object between iCloud users includes the following tasks:
1. On the owner side, create a share with an appropriate permission.
2. Invite participants by making the share link available to them.
3. On the participant side, accept the share.
4. On both sides, manage shares. Owners can stop sharing the object, change the share permission for a participant. Participants can stop their participation.

[`NSPersistentCloudKitContainer`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer?changes=__3) provides methods for creating a share ([`CKShare`](https://developer.apple.com/documentation/cloudkit/ckshare)) for Core Data objects and managing the interaction between the share and the associated objects. `UICloudSharingController` implements the share invitation and management. Apps can implement a sharing flow using these two APIs.

To create a share for Core Data objects, call [`share(_:to:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746834-share?changes=__3). Apps can choose creating a new share, or adding the objects to an existing share. Core Data uses CloudKit zone sharing so each share has its own record zone on the CloudKit server. (For more details, see [WWDC21 session 10015: Build Apps that Share Data Through CloudKit and Core Data](https://developer.apple.com/videos/play/wwdc2021/10015/) and [WWDC21 session 10086: What's new in CloudKit](https://developer.apple.com/videos/play/wwdc2021/10086).) CloudKit has a limit on how many record zones a database can have. To avoid hitting the limit, consider using an existing share if appropriate. 

See the following method for how this sample app shares a photo:
- CodeListing: shareObject

`NSPersistentCloudKitContainer` doesn't automatically handle the changes `UICloudSharingController` (or other CloudKit APIs) makes on a share. When the kind of changes happen, apps must update the Core Data store by calling [`persistUpdatedShare(_:in:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746832-persistupdatedshare?changes=__3). The sample app implements the following [`UICloudSharingControllerDelegate`](https://developer.apple.com/documentation/uikit/uicloudsharingcontrollerdelegate) method to persist a updated share.

- CodeListing: cloudSharingControllerDidSaveShare

Similarly, when owners tap the "Stop Sharing" button or participants tap the "Remove Me" button in the CloudKit sharing UI, `NSPersistentCloudKitContainer` doesn't immediately know the change. To avoid stale UI in this case, implement the following delegate method to purge the Core Data objects and CloudKit records associated with the share using [`purgeObjectsAndRecordsInZone(with:in:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746833-purgeobjectsandrecordsinzone?changes=__3).

- CodeListing: cloudSharingControllerDidStopSharing

Core Data doesn't support cross-share relationships. That is, it doesn't allow relating objects associated with different shares. When sharing an object, Core Data moves the whole object graph (including the object and all its relationships) to the share's record zone. When users stop a share, Core Data deletes the object graph. In the case where apps need to reserve the data when users stopping a share, make a deep copy of the object graph and make sure no object in the graph is associated with any share.

## Detect Relevant Changes by Consuming Store Persistent History
When importing data from CloudKit, `NSPersistentCloudKitContainer` records the changes on Core Data objects in the store's persistent history, and triggers remote change notifications (`.NSPersistentStoreRemoteChange`) so apps can keep their state up to date if necessary. The sample app observes the notification and does the followings in the notification handler:

- Gather the relevant history transactions ([`NSPersistentHistoryTransaction`](https://developer.apple.com/documentation/coredata/nspersistenthistorytransaction)), and notify the views that remote changes happen. Note that the changes on shares don't generate any transactions.
- The views that present photos merge the transactions to the `viewContext` of the persistent container, which triggers a SwiftUI update. Views relevant to shares fetch the shares from the stores, and update with them.
- Detect the new tags from CloudKit, and remove duplicate tags if necessary.

To process the persistent history more effectively, the app:
- Maintains the token of the last transaction it consumes for each store, and uses it as the starting point of next run.
- Maintains a transaction author, and uses it to filter the transactions irrelevant to Core Data CloudKit.
- Only fetches and consumes the history of the relevant persistent store.

This is the code that sets up the history fetch request (`NSPersistentHistoryChangeRequest`):
- CodeListing: fetchHistory

For more information about persistent history processing, see [Consuming Relevant Store Changes](https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes).

## Remove Duplicate Data
In the CloudKit environment, duplicate data is sometimes inevitable:
- Different peers can create same data. In this sample app, owners can share a photo with a permission that allows participants to tag it. When owners and participants simultaneously create a same tag, a duplicate occurs.
- Apps rely on some initial data and there is no way to allow only one peer to preload it. Duplicates occur when multiple peers preload the data at the same time.

To remove duplicate data (or _deduplicate_), implement a way that allows all peers to eventually reserve the same winner and remove others. The sample app removes duplicate tags in the following way:

1. Give every tag a universally unique identifier (UUID). Tags that meet the following criteria are duplicates and only one should exist:
- They have a same tag name. (Their UUIDs are still different.)
- They are associated with a same share, and so are in the same CloudKit record zone.
2. Detect new tags from CloudKit by looking into the persistent history every time a remote change notification occurs.
3. For each new tag, fetch the duplicates from the same persistent store, and sort them with their UUID so the tag with the smallest UUID goes first.
4. Pick the first tag as the winner and remove the others. Because UUID is globally unique and every peer picks the first tag, all peers eventually reach to the same winner, which is the tag that has the globally smallest UUID.
 
The sample app only detects and removes duplicate tags from the owner side because participants may not have write permission. That is, deduplication only applies to the private persistent store.
 
See the following method for the code that deduplicate tags:

- CodeListing: deduplicateAndWait

## Implement a Custom Sharing Flow
When `UICloudSharingController` is unavailable or doesn't fit the app UI, consider implementing a custom sharing flow if necessary. (`UICloudSharingController` is unavailabe on watchOS. On macOS, use [`NSSharingService`](https://developer.apple.com/documentation/appkit/nssharingservice) with the [`.cloudSharing`](https://developer.apple.com/documentation/appkit/nssharingservice/name/1644670-cloudsharing) service.) To do that, here are the steps and relevant APIs:

1. On the owner side, pick the Core Data objects to share, and create a share with them using `share(_:to:completion:)`. 
2. Configure the share with appropriate permissions, and add participants if it's a private share.
A share is private if its [`publicPermission`](https://developer.apple.com/documentation/cloudkit/ckshare/1640494-publicpermission) is more permissive than [`.none`](https://developer.apple.com/documentation/cloudkit/ckshare/participantpermission/none). For shares that have `.none` public permission (called _public shares_), users can participate by tapping the share link, hence no need to add participants beforehand. Look up the participants using [`fetchParticipants(matching:into:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746829-fetchparticipants) or [`CKFetchShareParticipantsOperation`](https://developer.apple.com/documentation/cloudkit/ckfetchshareparticipantsoperation), then add them to the share by calling [`addParticipant(_:)`](https://developer.apple.com/documentation/cloudkit/ckshare/1640443-addparticipant). Configure the participant permission using [`CKShare.ParticipantPermission`](https://developer.apple.com/documentation/cloudkit/ckshare/participant/1640433-permission).
3. Implement a mechanism for the owner to deliver the share link ([`CKShare.url`](https://developer.apple.com/documentation/cloudkit/ckshare/1640465-url)).
4. On the participant side, accept the share.
After receiving the share link, participants tap it to accept the share and open the app. The system calls [`windowScene(_:userDidAcceptCloudKitShareWith:)`](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/3238089-windowscene) (or [`userDidAcceptCloudKitShare(with:)`](https://developer.apple.com/documentation/watchkit/wkextensiondelegate/3612144-userdidacceptcloudkitshare) on watchOS) when launching the app in this context, and the app accepts the share using [`acceptShareInvitations(from:into:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746828-acceptshareinvitations) or [`CKAcceptSharesOperation`](https://developer.apple.com/documentation/cloudkit/ckacceptsharesoperation). After the acceptance synchronizes, the objects the owner shares are available in the participant's store that mirrors the CloudKit shared database.
5. On the owner side, manage the participants of the share using `addParticipant(_:)` and `removeParticipant(_:)`, or stop the sharing by calling `purgeObjectsAndRecordsInZone(with:in:completion:)`.
6. On the participant side, stop the participation by calling `purgeObjectsAndRecordsInZone(with:in:completion:)`.

In the whole process, whenever changing a share using CloudKit APIs, call `persistUpdatedShare(_:in:completion:)` so Core Data persists the change to the store and synchronize it with CloudKit. As an example, this sample uses the following code to add a participant 

- CodeListing: addParticipant

- Note: To be able to accept a share when users tap a share link, the app's `info.plist` file must contain the `CKSharingSupported` key and its value must be `true`.
