//
//  ScannerSheet.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI

/// Present this in a .sheet, e.g.
/// .sheet(isPresented: $showScanner) {
///     ScannerSheet(title: "Scan Barcode") { code in
///         // handle scanned code
///     }
/// }
struct ScannerSheet: View {
    var title: String = "Scan"
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    // Explicit NavigationPath avoids "generic T" inference issues in Playgrounds
    @State private var navPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color.black.ignoresSafeArea()
                BarcodeScannerUIKit { code in
                    onCode(code)
                    dismiss()
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
  
