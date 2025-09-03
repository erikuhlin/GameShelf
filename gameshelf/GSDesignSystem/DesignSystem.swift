
import SwiftUI

public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs:  CGFloat = 8
    public static let s:   CGFloat = 12
    public static let m:   CGFloat = 16
    public static let l:   CGFloat = 20
    public static let xl:  CGFloat = 24
    public static let xxl: CGFloat = 32
}

public enum Radius {
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let pill: CGFloat = 999
}

public enum Shadow {
    public static let card = ShadowStyle(radius: 10, y: 4, opacity: 0.08)
    public struct ShadowStyle {
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
        public let opacity: Double
        public init(radius: CGFloat, x: CGFloat = 0, y: CGFloat, opacity: Double) {
            self.radius = radius; self.x = x; self.y = y; self.opacity = opacity
        }
    }
}

public enum Typography {
    public static let h1 = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let h2 = Font.system(size: 28, weight: .semibold, design: .rounded)
    public static let h3 = Font.system(size: 22, weight: .semibold, design: .rounded)
    public static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    public static let callout = Font.system(size: 16, weight: .regular, design: .rounded)
    public static let footnote = Font.system(size: 13, weight: .regular, design: .rounded)
    public static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
}
