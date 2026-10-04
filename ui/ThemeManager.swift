import SwiftUI
import Combine

enum AppTheme {
    case miniLEDBlack
    case liquidGlass
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .miniLEDBlack
    
    var baseColor: Color {
        switch currentTheme {
        case .miniLEDBlack:
            return Color.black
        case .liquidGlass:
            return Color.black.opacity(0.4)
        }
    }
    
    var accentColor: Color {
        switch currentTheme {
        case .miniLEDBlack:
            return .white
        case .liquidGlass:
            return .blue
        }
    }
    
    func glassEffect(view: AnyView) -> some View {
        view
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

let sharedTheme = ThemeManager()
