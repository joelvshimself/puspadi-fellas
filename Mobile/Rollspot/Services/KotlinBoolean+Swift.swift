import Foundation
import Shared

extension Optional where Wrapped == Bool {
    /// Maps Swift `Bool?` to SKIE's boxed `KotlinBoolean?` for shared DTO constructors.
    func asKotlinBoolean() -> KotlinBoolean? {
        guard let value = self else { return nil }
        return KotlinBoolean(bool: value)
    }
}
