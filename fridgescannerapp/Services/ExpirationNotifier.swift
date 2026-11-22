//
//  ExpirationNotifier.swift
//  fridgescannerapp
//
//  Created by lending on 11/19/26.
//
//  Expiration reminders: a local notification at 9 AM on the day a fridge
//  item expires. Reminders are scheduled when an item is added (through
//  ModelLinks) and canceled when it's removed. Permission is asked the
//  first time someone sets an expiration date, not at launch.
//

import Foundation
import UserNotifications

final class ExpirationNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ExpirationNotifier()

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "expiry-"
    private let notifyHour = 9          // Notify at 9 AM on the expiration day
    private let maxPending = 60         // iOS keeps at most 64 pending notifications

    /// Called at launch. Only sets the delegate; it doesn't ask for permission.
    func setup() {
        center.delegate = self
    }

    /// HIG: ask for permission in context, the first time it's useful. iOS
    /// shows the prompt only once, so later calls do nothing.
    func requestPermissionIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func schedule(for item: FridgeItem) {
        let id = identifier(for: item)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let fireDate = fireDate(for: item) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Item expired"
        content.body = "\(item.name.capitalized) has reached its expiration date."
        content.sound = .default

        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(for item: FridgeItem) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: item)])
    }

    /// Rebuilds every reminder from the given items, soonest first.
    func sync(_ items: [FridgeItem]) {
        // Clear everything first, right away. (These are the app's only
        // notifications.) Clearing after scheduling would delete the new ones.
        center.removeAllPendingNotificationRequests()

        // Functional: keep items with a future reminder, sort by date, take the soonest
        items
            .compactMap { item in fireDate(for: item).map { (item, $0) } }
            .sorted { $0.1 < $1.1 }
            .prefix(maxPending)
            .forEach { schedule(for: $0.0) }
    }

    private func identifier(for item: FridgeItem) -> String {
        idPrefix + item.id.uuidString
    }

    /// 9 AM on the expiration day, or nil if there's no date or it has passed.
    private func fireDate(for item: FridgeItem) -> Date? {
        guard let expiry = item.expirationDate else { return nil }
        let day = Calendar.current.startOfDay(for: expiry)
        guard let fire = Calendar.current.date(bySettingHour: notifyHour, minute: 0, second: 0, of: day),
              fire > .now else { return nil }
        return fire
    }

    // Show the banner even when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
