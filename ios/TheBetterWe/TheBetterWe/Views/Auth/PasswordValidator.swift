import Foundation

enum PasswordValidator {
    static func hasLength(_ password: String) -> Bool { password.count >= 6 }
    static func hasLetter(_ password: String) -> Bool { password.rangeOfCharacter(from: .letters) != nil }
    static func hasNumber(_ password: String) -> Bool { password.rangeOfCharacter(from: .decimalDigits) != nil }
    static func isValid(_ password: String) -> Bool {
        hasLength(password) && hasLetter(password) && hasNumber(password)
    }
}
