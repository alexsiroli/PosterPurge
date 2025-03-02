import SwiftUI

enum AppColor {
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let backgroundGradient = Gradient(colors: [Color("GradientStart"), Color("GradientEnd")])
    static let cardBackground = Color(.systemBackground).opacity(0.8)
}

enum AppFont {
    static let title = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
}

enum AppStyle {
    static let cornerRadius: CGFloat = 16
    static let shadowRadius: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let buttonPadding: CGFloat = 14
}

extension View {
    func appCardStyle() -> some View {
        self
            .padding(AppStyle.cardPadding)
            .background(AppColor.cardBackground)
            .cornerRadius(AppStyle.cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: AppStyle.shadowRadius, x:0,y:4)
    }
    func appButtonStyle() -> some View {
        self
            .padding(AppStyle.buttonPadding)
            .background(AppColor.primary)
            .foregroundColor(.white)
            .font(AppFont.headline)
            .cornerRadius(AppStyle.cornerRadius)
            .shadow(color: AppColor.primary.opacity(0.3), radius:8,x:0,y:4)
    }
}
