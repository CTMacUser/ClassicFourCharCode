import Foundation

/// A wrapper of the `FourCharCode` (a.k.a. `OSType`) string/number type,
/// dating from the pre-NeXT Mac OS era,
/// with Swift compatibility in mind.
///
/// These strings are made of exactly four characters of
/// the Mac OS Roman character set, which was an 8-bit extension of ASCII.
/// These strings represented a 32-bit number with a value of the characters'
/// (Mac OS Roman) code points mashed together.
/// The first character in the string maps to the highest order byte,
/// down to the string's last character mapping to the lowest-order byte.
public struct ClassicFourCharCode: RawRepresentable {
  public let rawValue: FourCharCode

  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }
}

// MARK: Basic Behaviors

extension ClassicFourCharCode: BitwiseCopyable, Equatable, Hashable, Sendable {}

// MARK: Serialization

extension ClassicFourCharCode: Decodable, Encodable {}

extension ClassicFourCharCode: CustomDebugStringConvertible {
  public var debugDescription: String {
    .init(format: "%.8X", rawValue)
  }
}

extension ClassicFourCharCode: CustomStringConvertible {
  public var description: String {
    // Adapted from <https://stackoverflow.com/a/60367676/1010226>.
    withUnsafeBytes { buffer in
      return .init(bytes: buffer, encoding: .macOSRoman)!
    }
  }
}

extension ClassicFourCharCode: LosslessStringConvertible {
  public init?(_ description: String) {
    // Valid representations are either four or eight characters exactly.
    guard
      let fourthIndex = description.index(
        description.startIndex,
        offsetBy: +4,
        limitedBy: description.endIndex
      )
    else {
      // String is too short.
      return nil
    }

    if fourthIndex == description.endIndex {
      // Look for the four-character non-debug representation.
      guard
        let roman = description.data(
          using: .macOSRoman,
          allowLossyConversion: false
        )
      else {
        // String isn't in Mac OS Roman encoding.
        return nil
      }

      self.init(
        rawValue: roman.withUnsafeBytes({
          return RawValue(
            bigEndian: $0.withMemoryRebound(to: RawValue.self, \.first)!
          )
        })
      )
    } else {
      // Look for the eight-character debug representation.
      guard
        let eighthIndex = description.index(
          fourthIndex,
          offsetBy: +4,
          limitedBy: description.endIndex
        ), eighthIndex == description.endIndex,
        let code = RawValue(description, radix: 16)
      else {
        // String isn't exactly eight characters long,
        // or isn't a hexadecimal numeral.
        return nil
      }

      self.init(rawValue: code)
    }
  }
}

extension ClassicFourCharCode {
  /// Determines if at least one stored octet is less than the given value.
  ///
  /// - Precondition: `limit < 0x80`.
  ///
  /// - Parameter limit: The minimum value that can't trigger `true`.
  /// - Returns: `false` if every stored octet is at least `limit`;
  ///   otherwise, `true`.
  @usableFromInline
  func haveOctetsUnder(_ limit: UInt8) -> Bool {
    // Adapted from "Bit Twiddling Hacks" at
    // <https://graphics.stanford.edu/~seander/bithacks.html>.
    //
    // Specifically, the "Determine if a word has a byte less than n" chapter.
    let spreadLimit = FourCharCode(limit) &* 0x0101_0101
    return (rawValue &- spreadLimit) & ~rawValue & 0x8080_8080 != 0
  }
  /// Determines if the given value is stored in any of this code's octets.
  ///
  /// - Parameter match: The value to search for.
  /// - Returns: `false` if `match` isn't anywhere in the code;
  ///   otherwise, `true`.
  @usableFromInline
  func hasOctet(of match: UInt8) -> Bool {
    // Adapted from "Bit Twiddling Hacks" at
    // <https://graphics.stanford.edu/~seander/bithacks.html>.
    //
    // Specifically, the "Determine if a word has a byte equal to n" chapter.
    // (Plus reusing code from the chapter `haveOctetsUnder(_:)` uses.)
    let zeroOutMask = FourCharCode(match) &* 0x0101_0101
    return Self(rawValue: rawValue ^ zeroOutMask).haveOctetsUnder(1)
  }
  /// Whether this value's string rendition can be properly printed out.
  ///
  /// The string will be printable unless it contains at
  /// least one unprintable coded character.
  /// For the Mac OS Roman character set,
  /// the unprintable characters are the ASCII control characters,
  /// which are the DEL character and the sub-Space characters.
  /// Note that the traditional space and non-breaking space characters are not
  /// considered control characters.
  @inlinable
  public var isPrintable: Bool { !haveOctetsUnder(0x20) && !hasOctet(of: 0x7F) }
}

// MARK: Element Access

extension ClassicFourCharCode: ContiguousBytes {
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R)
    rethrows -> R
  {
    var bigRawValue = rawValue.bigEndian
    return try Swift.withUnsafeBytes(of: &bigRawValue, body)
  }
}

@available(macOS 26.0, *)
extension ClassicFourCharCode {
  /// The four character codes, separated.
  ///
  /// The first element is the string value's first character and
  /// the numeric value's highest-order code.
  /// Later elements correspond to later characters and lower-order codes.
  public var octets: [4 of UInt8] {
    .init({ index in
      return .init(truncatingIfNeeded: rawValue >> (8 * (3 - index)))
    })
  }

  /// Creates a code from the given quartet of byte values.
  ///
  /// - Parameter octets: The four separated character codes,
  ///   starting from the string value's first character,
  ///   which is also the numeric value's highest-order octet.
  ///   Subsequent elements map to later characters in the string view and
  ///   lower-order octets in the numeric value.
  /// - Postcondition: `self.rawValue ==`
  ///   `octets[0] << 24 | octets[1] << 16 | octets[2] << 8 | octets[3]`
  public init(octets: [4 of UInt8]) {
    self.init(
      rawValue: octets.span.withUnsafeBufferPointer({ buffer in
        return buffer.lazy.map(FourCharCode.init(truncatingIfNeeded:)).reduce(
          into: 0
        ) {
          $0 <<= 8
          $0 |= $1
        }
      })
    )
  }
}
