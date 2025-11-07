import SwiftUI

extension Color {
    /// Card/section surface
    static let adaptiveCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
    })

    /// List row background
    static let adaptiveRow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiarySystemBackground : .white
    })

    /// Screen background when you want a plain fill
    static let adaptiveScreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemBackground : .systemGroupedBackground
    })

    /// A subtle shadow that scales for dark mode
    static let adaptiveShadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.45)
                                           : UIColor.black.withAlphaComponent(0.10)
    })

    /// Status colors that are a little friendlier in dark mode
    static let statusInStock    = Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGreen  : .systemGreen  })
    static let statusAllocated  = Color(UIColor { $0.userInterfaceStyle == .dark ? .systemOrange : .systemOrange })
    static let statusOutOfStock = Color(UIColor { $0.userInterfaceStyle == .dark ? .systemRed    : .systemRed    })
}