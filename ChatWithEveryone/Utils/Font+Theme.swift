import SwiftUI

extension Font {
    static func songtiTimes(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Songti SC", size: size).weight(weight)
    }
}
