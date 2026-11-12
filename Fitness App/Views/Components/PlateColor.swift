import SwiftUI

/// Plate colours loosely following competition colours.
func plateColor(_ plate: Double) -> Color {
    switch plate {
    case 25...: .red
    case 20..<25: .blue
    case 15..<20: .yellow
    case 10..<15: .green
    case 5..<10: Color(white: 0.92)
    case 2.5..<5: Color(white: 0.3)
    default: Color(white: 0.7)
    }
}
