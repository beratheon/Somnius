import SwiftUI
import Combine


enum AppTheme: String, CaseIterable, Identifiable {
    case oled = "OLED Black"
    case current = "Somnius Zinc"
    case navyBlue = "Navy Blue"
    
    // Backward compatibility aliases
    static var miniLEDBlack: AppTheme { .oled }
    static var liquidGlass: AppTheme { .current }
    
    var id: String { rawValue }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("selectedAppThemeName") private var storedThemeName: String = AppTheme.current.rawValue
    @Published var currentTheme: AppTheme = .current {
        didSet {
            storedThemeName = currentTheme.rawValue
        }
    }
    
    @AppStorage("enableExternalAudioInjection") var enableExternalAudioInjection: Bool = true
    @AppStorage("preferredAudioLanguage") var preferredAudioLanguage: String = "tr"
    @AppStorage("enablePALSpeedupCorrection") var enablePALSpeedupCorrection: Bool = true
    
    init() {
        if let matched = AppTheme.allCases.first(where: { $0.rawValue == storedThemeName }) {
            self.currentTheme = matched
        } else {
            self.currentTheme = .current
        }
    }
    
    var baseColor: Color {
        switch currentTheme {
        case .oled:
            return Color.black
        case .current:
            return Color(red: 0.07, green: 0.07, blue: 0.08)
        case .navyBlue:
            return Color(red: 0.04, green: 0.06, blue: 0.10)
        }
    }
    
    var surfaceColor: Color {
        switch currentTheme {
        case .oled:
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .current:
            return Color(red: 0.11, green: 0.11, blue: 0.13)
        case .navyBlue:
            return Color(red: 0.07, green: 0.10, blue: 0.17)
        }
    }
    
    var cardBackground: Color {
        switch currentTheme {
        case .oled:
            return Color(red: 0.05, green: 0.05, blue: 0.05)
        case .current:
            return Color(red: 0.09, green: 0.09, blue: 0.11)
        case .navyBlue:
            return Color(red: 0.06, green: 0.09, blue: 0.14)
        }
    }
    
    var borderColor: Color {
        switch currentTheme {
        case .oled:
            return Color.white.opacity(0.14)
        case .current:
            return Color.white.opacity(0.10)
        case .navyBlue:
            return Color(red: 0.35, green: 0.55, blue: 0.85).opacity(0.20)
        }
    }
    
    var accentColor: Color {
        switch currentTheme {
        case .oled:
            return .white
        case .current:
            return SoftTone.mist.color
        case .navyBlue:
            return Color(red: 0.45, green: 0.70, blue: 1.0)
        }
    }
    
    // This helper handles the "Liquid Glass" look for UI components
    func glassEffect(view: AnyView) -> some View {
        view
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

let sharedTheme = ThemeManager.shared

