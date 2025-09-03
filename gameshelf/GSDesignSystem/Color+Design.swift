
import SwiftUI

public extension Color {
    struct ds {
        public static var background: Color { named("Neutral_Background", fallbackLight: .white, fallbackDark: Color(red: 0.04, green: 0.04, blue: 0.05)) }
        public static var surface: Color    { named("Neutral_Surface", fallbackLight: Color(white: 0.96), fallbackDark: Color(red: 0.11, green: 0.11, blue: 0.12)) }
        public static var brandRed: Color   { named("Brand_Red", fallbackLight: Color(red: 0.90, green: 0.22, blue: 0.21), fallbackDark: Color(red: 0.83, green: 0.18, blue: 0.18)) }
        public static var brandRedPressed: Color { named("Brand_RedPressed", fallbackLight: Color(red: 0.78, green: 0.16, blue: 0.16), fallbackDark: Color(red: 0.72, green: 0.11, blue: 0.11)) }
        public static var accentIndigo: Color { named("Accent_Indigo", fallbackLight: Color(red: 0.22, green: 0.29, blue: 0.67), fallbackDark: Color(red: 0.19, green: 0.25, blue: 0.62)) }
        public static var accentIndigoLight: Color { named("Accent_IndigoLight", fallbackLight: Color(red: 0.36, green: 0.42, blue: 0.75), fallbackDark: Color(red: 0.33, green: 0.38, blue: 0.73)) }
        public static var textPrimary: Color { named("Text_Primary", fallbackLight: Color(red: 0.13, green: 0.13, blue: 0.13), fallbackDark: .white) }
        public static var textSecondary: Color { named("Text_Secondary", fallbackLight: Color(red: 0.38, green: 0.38, blue: 0.38), fallbackDark: Color(white: 0.70)) }
        public static var success: Color { named("Feedback_Success", fallbackLight: Color(red: 0.26, green: 0.63, blue: 0.28), fallbackDark: Color(red: 0.18, green: 0.49, blue: 0.20)) }
        public static var warning: Color { named("Feedback_Warning", fallbackLight: Color(red: 0.98, green: 0.75, blue: 0.18), fallbackDark: Color(red: 0.98, green: 0.66, blue: 0.15)) }

        private static func named(_ name: String, fallbackLight: Color, fallbackDark: Color) -> Color {
            #if os(iOS)
            if let uiColor = UIColor(named: name) {
                return Color(uiColor)
            }
            #endif
            return Color(UIColor { trait in
                (trait.userInterfaceStyle == .dark) ? UIColor(fallbackDark) : UIColor(fallbackLight)
            })
        }
    }
}
