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
  public var rawValue: FourCharCode

  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }
}

// MARK: Basic Behaviors

extension ClassicFourCharCode: BitwiseCopyable, Equatable, Hashable, Sendable {}

// MARK: Serialization

extension ClassicFourCharCode: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension ClassicFourCharCode: CustomDebugStringConvertible {
  public var debugDescription: String {
    .init(format: "%.8X", rawValue)
  }
}

extension ClassicFourCharCode: CustomStringConvertible {
  public var description: String {
    // Adapted from <https://stackoverflow.com/a/60367676/1010226>.
    withUnsafePointer(to: rawValue.bigEndian) { wordPointer in
      let wordBuffer = UnsafeBufferPointer(start: wordPointer, count: 1)
      return wordBuffer.withMemoryRebound(to: UInt8.self) { byteBuffer in
        return String.init(bytes: byteBuffer, encoding: .macOSRoman)!
      }
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

extension ClassicFourCharCode: Decodable {
  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer()
    self.init(rawValue: try value.decode(RawValue.self))
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

extension ClassicFourCharCode: Sequence {
  public struct Iterator: IteratorProtocol {
    /// The remaining octets to vend.
    var remaining = 4
    /// The embedded octets to vend.
    var octets: UInt32

    /// Creates a vended sequence of the octets of the given value,
    /// but with that value's highest octet first.
    ///
    /// - Parameter codes: The value with all the vended octets embedded in it.
    @usableFromInline
    init(_ codes: FourCharCode) {
      octets = codes.byteSwapped
    }

    mutating public func next() -> UInt8? {
      guard remaining > 0 else { return nil }
      defer { octets >>= 8 }

      remaining -= 1
      return UInt8(truncatingIfNeeded: octets)
    }
  }

  @inlinable
  public func makeIterator() -> Iterator {
    return .init(rawValue)
  }

  @inlinable
  public var underestimatedCount: Int { MemoryLayout.size(ofValue: rawValue) }

  @inlinable
  public func _customContainsEquatableElement(_ element: Element) -> Bool? {
    return .some(self.hasOctet(of: element))
  }
  @inlinable
  public func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Iterator.Element>) throws -> R
  ) rethrows -> R? {
    return try .some(
      self.withUnsafeBytes {
        return try $0.withMemoryRebound(to: Element.self, body)
      }
    )
  }
}
