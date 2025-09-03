
import SwiftUI

public struct GSTag: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(Typography.caption)
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.ds.accentIndigo)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
    }
}
