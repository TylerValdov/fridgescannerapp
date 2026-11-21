//
//  ScannerView.swift
//  fridgescannerapp
//
//  The grocery scanner, opened from the Fridge tab: point the camera at a
//  barcode, look the product up on Open Food Facts (free, no key), and put a
//  simple ingredient name in the Add field. Needs a device with a camera.
//

import SwiftUI
import Vision     // The barcode types (.ean13, …)
import VisionKit  // The live camera scanner

struct ScannerView: View {
    /// False on the simulator, on devices without a camera, and when camera
    /// access is denied. The Fridge tab hides its Scan button then.
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    /// Called with the ingredient name to put in the Add field.
    let onFound: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLookingUp = false
    /// Shown when a barcode can't be looked up.
    @State private var message: String?

    var body: some View {
        NavigationStack {
            BarcodeScanner(isPaused: isLookingUp || message != nil) { code in
                Task { await lookUp(code) }
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) { statusPanel }
            .navigationTitle("Scan a Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var statusPanel: some View {
        VStack(spacing: 12) {
            if isLookingUp {
                ProgressView("Looking up product…")
            } else if let message {
                Text(message)
                    .multilineTextAlignment(.center)
                // Error prevention: an unknown product never blocks adding the item by hand.
                HStack {
                    Button("Scan Again") { self.message = nil }
                        .buttonStyle(.bordered)
                    Button("Type It Instead") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Point the camera at a grocery barcode.")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func lookUp(_ code: String) async {
        // The camera can report the same barcode several times; handle it once.
        guard !isLookingUp, message == nil else { return }
        isLookingUp = true
        defer { isLookingUp = false }

        do {
            if let product = try await productName(forBarcode: code) {
                onFound(ingredientName(fromProduct: product))
                dismiss()
            } else {
                message = "Barcode \(code) isn't in Open Food Facts. Type the item's name instead."
            }
        } catch {
            message = "Couldn't look up the barcode. Check your connection, or type the name instead."
        }
    }
}

// MARK: - Camera

/// VisionKit's live barcode scanner, wrapped for SwiftUI.
private struct BarcodeScanner: UIViewControllerRepresentable {
    /// Paused while a barcode is being looked up or a message is showing.
    let isPaused: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // EAN-13 also covers UPC-A, the usual US grocery barcode.
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if isPaused {
            scanner.stopScanning()
        } else if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    // OOP: VisionKit reports scans to a delegate object, so this class adopts its protocol.
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue {
                    onScan(code)
                    return
                }
            }
        }
    }
}

// MARK: - Open Food Facts

private struct ProductResponse: Decodable {
    struct Product: Decodable {
        let productName: String?
    }

    let status: Int
    let product: Product?
}

/// The product's name from Open Food Facts, or nil if it doesn't know the barcode.
func productName(forBarcode code: String) async throws -> String? {
    guard
        let safeCode = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(safeCode).json?fields=product_name")
    else { return nil }

    // Open Food Facts asks apps to say who they are.
    var request = URLRequest(url: url)
    request.setValue("FridgeScanner/1.0 (CS 3714 class project)", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)
    // Unknown barcodes come back as 404.
    if (response as? HTTPURLResponse)?.statusCode == 404 {
        return nil
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let result = try decoder.decode(ProductResponse.self, from: data)
    let name = result.product?.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return result.status == 1 && !name.isEmpty ? name : nil
}

// Procedural: turns a product name into the kind of name the fridge uses.

/// "Great Value Whole Milk" → "milk", "Large Brown Eggs" → "eggs". Uses the
/// longest common ingredient whose words appear in the name, or else the
/// whole name, which the user can edit before tapping Add.
func ingredientName(fromProduct product: String) -> String {
    let name = normalizedIngredientName(product)
    let words = wordsForMatching(name)

    // Functional: keep the common ingredients found in the name, then pick the
    // most specific one, so "green onions" wins over "onion".
    let matches = MockRecipeProvider.commonIngredients.filter { ingredient in
        words.contains(wordsForMatching(ingredient))
    }
    return matches.max { $0.count < $1.count } ?? name
}

/// " whole milk " → " whole milk ", "Eggs" → " egg ": singular words with spaces
/// around them, so "ham" doesn't match inside "graham".
private func wordsForMatching(_ text: String) -> String {
    let words = text.lowercased()
        .split { !$0.isLetter }
        .map { $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
    return " " + words.joined(separator: " ") + " "
}

#Preview {
    // The camera doesn't run in previews or the simulator; this shows the layout.
    ScannerView { _ in }
}
