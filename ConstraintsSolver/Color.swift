import Foundation

struct Color {
    let rgb: simd_float3
    
    init(_ red: Float, _ green: Float, _ blue: Float) {
        rgb = .init(red, green, blue)
    }
    
    init(_ grey: Float) {
        rgb = .init(repeating: grey)
    }
    
    static let red = Color(1, 0, 0)
    static let green = Color(0, 1, 0)
    static let blue = Color(0, 0, 1)
    static let yellow = Color(1, 1, 0)
    static let cyan = Color(0, 1, 1)
    static let magenta = Color(1, 0, 1)
    static let white = Color(1)
    static let black = Color(0)
}
