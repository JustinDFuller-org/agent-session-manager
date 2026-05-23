---
name: usernotifications-documentation
description: UserNotifications official doc index — load when building notification features, requesting authorization, scheduling local notifications, handling notification actions, or any UserNotifications framework behavior.
user-invocable: false
allowed-tools:
  - WebFetch(domain:developer.apple.com)
---

# User Notifications Documentation Index

Fetch from this index before implementing any UserNotifications feature — do not guess at behavior. One URL per topic — read the most specific one first.

## Discovery

- `https://developer.apple.com/documentation/usernotifications` — Main UserNotifications framework page; overview of push and local notifications, all topic sections.

## Essentials & Permissions

- `https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications` — Requesting notification authorization: explicit vs provisional, checking settings.
- `https://developer.apple.com/documentation/usernotifications/UNUserNotificationCenter` — Central object for managing all notification-related activities. Methods: `current()`, `requestAuthorization`, `add(_:)`, `removePendingNotificationRequests`, `setNotificationCategories`, `getDeliveredNotifications`, `setBadgeCount`.
- `https://developer.apple.com/documentation/usernotifications/UNUserNotificationCenterDelegate` — Protocol for processing incoming notifications and responding to notification actions. Methods: `userNotificationCenter(_:willPresent:withCompletionHandler:)`, `userNotificationCenter(_:didReceive:withCompletionHandler:)`, `userNotificationCenter(_:openSettingsFor:)`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationSettings` — Current authorization status and notification-related settings (`authorizationStatus`, `alertSetting`, `badgeSetting`, `soundSetting`, `notificationCenterSetting`, `criticalAlertSetting`, etc.).

## Scheduling & Requests

- `https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app` — Creating content, specifying triggers, registering and canceling local notification requests.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationRequest` — A request to schedule a local notification; combines `UNNotificationContent` and `UNNotificationTrigger` with a unique `identifier`.
- `https://developer.apple.com/documentation/usernotifications/UNNotification` — Data for a delivered notification; contains the `request` and `date` of delivery.

## Notification Content

- `https://developer.apple.com/documentation/usernotifications/UNMutableNotificationContent` — Editable content for a local notification payload (`title`, `subtitle`, `body`, `badge`, `sound`, `userInfo`, `categoryIdentifier`, `attachments`, `threadIdentifier`, `interruptionLevel`, `relevanceScore`).
- `https://developer.apple.com/documentation/usernotifications/UNNotificationContent` — Uneditable content of a delivered notification; read-only properties accessed through `UNNotificationRequest.content`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationSound` — Sound played upon delivery; `default`, `init(named:)`, critical alert sounds (`defaultCritical`, `criticalSoundNamed(_:)`), `defaultRingtone`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationAttachment` — Media file (image/audio/video) attached to a notification; `init(identifier:url:options:)`, attachment options keys (`UNNotificationAttachmentOptionsTypeHintKey`, `UNNotificationAttachmentOptionsThumbnailHiddenKey`, `UNNotificationAttachmentOptionsThumbnailClippingRectKey`, `UNNotificationAttachmentOptionsThumbnailTimeKey`).
- `https://developer.apple.com/documentation/usernotifications/UNNotificationInterruptionLevel` — Importance and delivery timing: `active`, `critical`, `passive`, `timeSensitive`.

## Triggers

- `https://developer.apple.com/documentation/usernotifications/UNNotificationTrigger` — Abstract base class for trigger conditions; `repeats` property.
- `https://developer.apple.com/documentation/usernotifications/UNTimeIntervalNotificationTrigger` — Deliver after a specified time interval (`init(timeInterval:repeats:)`, `timeInterval`).
- `https://developer.apple.com/documentation/usernotifications/UNCalendarNotificationTrigger` — Deliver at a specific date/time using `DateComponents` (`init(dateMatching:repeats:)`, `dateComponents`).
- `https://developer.apple.com/documentation/usernotifications/UNLocationNotificationTrigger` — Deliver when entering/exiting a geographic region; requires Core Location authorization.
- `https://developer.apple.com/documentation/usernotifications/UNPushNotificationTrigger` — System-created trigger indicating APNs delivered a remote notification.

## Categories & Actions

- `https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types` — How to declare categories and action buttons; registering with `setNotificationCategories(_:)`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationCategory` — A notification type with associated custom actions (`init(identifier:actions:intentIdentifiers:options:)`, `identifier`, `actions`, `options`).
- `https://developer.apple.com/documentation/usernotifications/UNNotificationCategoryOptions` — Category handling options: `customDismissAction`, `allowInCarPlay`, `hiddenPreviewsShowTitle`, `hiddenPreviewsShowSubtitle`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationAction` — A task/button the user can invoke from a notification (`init(identifier:title:options:)`, `init(identifier:title:options:icon:)`, `identifier`, `title`, `options`).
- `https://developer.apple.com/documentation/usernotifications/UNNotificationActionOptions` — Action behavior options: `authenticationRequired`, `destructive`, `foreground`.
- `https://developer.apple.com/documentation/usernotifications/UNTextInputNotificationAction` — An action that accepts user-typed text (`init(identifier:title:options:textInputButtonTitle:textInputPlaceholder:)`, `textInputButtonTitle`, `textInputPlaceholder`).
- `https://developer.apple.com/documentation/usernotifications/UNNotificationActionIcon` — Icon for action buttons; `init(systemImageName:)`, `init(templateImageName:)`.

## Responses & Handling

- `https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions` — Responding to user-selected actions, foreground delivery, and PushKit notifications.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationResponse` — User's response to an actionable notification (`actionIdentifier`, `notification`, `targetScene`). System constants: `UNNotificationDefaultActionIdentifier`, `UNNotificationDismissActionIdentifier`.
- `https://developer.apple.com/documentation/usernotifications/UNTextInputNotificationResponse` — Response including custom user-typed text (`userText` property).

## Foreground Presentation

- `https://developer.apple.com/documentation/usernotifications/UNNotificationPresentationOptions` — Constants for presenting a notification when the app is in the foreground: `banner`, `badge`, `list`, `sound`, `alert`.

## Authorization & Settings Types

- `https://developer.apple.com/documentation/usernotifications/UNAuthorizationOptions` — Authorized features: `badge`, `sound`, `alert`, `carPlay`, `criticalAlert`, `providesAppNotificationSettings`, `provisional`.
- `https://developer.apple.com/documentation/usernotifications/UNAuthorizationStatus` — Authorization status: `notDetermined`, `denied`, `authorized`, `provisional`, `ephemeral`.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationSetting` — Current status of a notification setting: `notSupported`, `disabled`, `enabled`.

## Error Handling

- `https://developer.apple.com/documentation/usernotifications/UNError` — Notification error structure; codes: `notificationsNotAllowed`, `attachmentInvalidURL`, `attachmentUnrecognizedType`, `attachmentInvalidFileSize`, `attachmentNotInDataStore`, `attachmentMoveIntoDataStoreFailed`, `attachmentCorrupt`, `notificationInvalidNoDate`, `notificationInvalidNoContent`.
- `https://developer.apple.com/documentation/usernotifications/UNError/Code` — Error code constants for all notification errors.
- `https://developer.apple.com/documentation/usernotifications/UNErrorDomain` — The error domain string for notification errors (`"UNErrorDomain"`).

## Notification Service Extension

- `https://developer.apple.com/documentation/usernotifications/modifying-content-in-newly-delivered-notifications` — Modifying remote notification payloads via a service app extension before display.
- `https://developer.apple.com/documentation/usernotifications/UNNotificationServiceExtension` — Object that modifies remote notification content before delivery; `didReceive(_:withContentHandler:)`, `serviceExtensionTimeWillExpire()`.

## Supporting Types

- `https://developer.apple.com/documentation/usernotifications/UNNotificationContentProviding` — Protocol for providing notification context (Apple SDK only).

## Remote Notifications

- `https://developer.apple.com/documentation/usernotifications/setting-up-a-remote-notification-server` — Setting up a server to generate and push remote notifications via APNs.
- `https://developer.apple.com/documentation/usernotifications/sending-push-notifications-using-command-line-tools` — Sending push notifications via macOS command-line tools.
- `https://developer.apple.com/documentation/usernotifications/testing-notifications-using-the-push-notification-console` — Testing push notifications via the Push Notification Console.
- `https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications` — Configuring and displaying communication notifications using intents.

## Sample Code

- `https://developer.apple.com/documentation/usernotifications/handling-communication-notifications-and-focus-status-updates` — Creating a richer calling and messaging experience.
- `https://developer.apple.com/documentation/usernotifications/implementing-alert-push-notifications` — Adding visible alert notifications.
- `https://developer.apple.com/documentation/usernotifications/implementing-background-push-notifications` — Adding background notifications.

## Entitlements

- `https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment` — APS environment entitlement for push notifications.
- `https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.aps-environment` — com.apple.developer.aps-environment entitlement.

## Updates

- `https://developer.apple.com/documentation/updates/usernotifications` — Latest changes and additions to the UserNotifications framework.
