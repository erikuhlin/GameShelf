
import SwiftUI

public extension Color {
    struct ds {
        public static var background: Color { named("Neutral_Background", fallbackLight: .white, fallbackDark: Color(hex: "#0B0B0C")) }
        public static var surface: Color    { named("Neutral_Surface", fallbackLight: Color(white: 0.96), fallbackDark: Color(hex: "#1C1C1E")) }
        public static var brandRed: Color   { named("Brand_Red", fallbackLight: Color(red: 0.90, green: 0.22, blue: 0.21), fallbackDark: Color(hex: "#D32F2F")) }
        public static var brandRedPressed: Color { named("Brand_RedPressed", fallbackLight: Color(red: 0.78, green: 0.16, blue: 0.16), fallbackDark: Color(hex: "#B71C1C")) }
        public static var accentIndigo: Color { named("Accent_Indigo", fallbackLight: Color(red: 0.22, green: 0.29, blue: 0.67), fallbackDark: Color(hex: "#303F9F")) }
        public static var accentIndigoLight: Color { named("Accent_IndigoLight", fallbackLight: Color(red: 0.36, green: 0.42, blue: 0.75), fallbackDark: Color(red: 0.33, green: 0.38, blue: 0.73)) }
        public static var textPrimary: Color { named("Text_Primary", fallbackLight: Color(red: 0.13, green: 0.13, blue: 0.13), fallbackDark: .white) }
        public static var textSecondary: Color { named("Text_Secondary", fallbackLight: Color(red: 0.38, green: 0.38, blue: 0.38), fallbackDark: Color(hex: "#B3B3B3")) }
        public static var success: Color { named("Feedback_Success", fallbackLight: Color(red: 0.26, green: 0.63, blue: 0.28), fallbackDark: Color(hex: "#34C759")) }
        public static var warning: Color { named("Feedback_Warning", fallbackLight: Color(red: 0.98, green: 0.75, blue: 0.18), fallbackDark: Color(hex: "#F9A825")) }

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
