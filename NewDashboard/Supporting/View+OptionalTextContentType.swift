import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    @ViewBuilder
    func applyTextContentType(_ contentType: UITextContentType?) -> some View {
        #if canImport(UIKit)
        if let contentType {
            textContentType(contentType)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
