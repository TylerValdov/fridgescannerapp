//
//  ExpirationNotifier.swift
//  fridgescannerapp
//
//  Created by lending on 11/19/26.
//

import Foundation
import UserNotifications

final class ExpirationNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ExpirationNotifier()

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "expiry-"
    private let notifyHour = 9          // notify at 9 AM on the expiration day
    private let maxPending = 60         // iOS allows 64 pending notifications

    func setup() {
        center.delegate = self
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

    /// Rebuilds all expiration notifications from the given items.
    func sync(_ items: [FridgeItem]) {
        center.getPendingNotificationRequests { [center, idPrefix] requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
        }

        items
            .compactMap { item in fireDate(for: item).map { (item, $0) } }
            .sorted { $0.1 < $1.1 }
            .prefix(maxPending)
            .forEach { schedule(for: $0.0) }
    }

    private func identifier(for item: FridgeItem) -> String {
        idPrefix + item.id.uuidString
    }

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

