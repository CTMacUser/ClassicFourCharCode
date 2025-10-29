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

// MARK: More Initializers

extension ClassicFourCharCode {
  /// Creates a new code repeating the given byte value.
  ///
  /// - Parameter value: The octet to repeat.
  /// - Postcondition: `self.elementsEqual(repeatElement(value, count: 4))`
  @inlinable
  public init(repeating value: UInt8) {
    self.init(rawValue: FourCharCode(value) &* 0x0101_0101)
  }

  /// Creates a code from the given byte values, in order.
  ///
  /// - Parameters
  ///   - first: The most-significant byte stored in the code.
  ///   - second: The second-most significant byte stored in the code.
  ///   - third: The second-lowest significant byte stored in the code.
  ///   - fourth: The least-significant byte stored in the code.
  /// - Postcondition: `self.elementsEqual([first, second, third, fourth])`
  @inlinable
  public init(
    rawOctets first: UInt8,
    _ second: UInt8,
    _ third: UInt8,
    _ fourth: UInt8
  ) {
    self.init(
      rawValue: FourCharCode(first) &* 0x0100_0000 | FourCharCode(second)
        &* 0x0001_0000 | FourCharCode(third) &* 0x0000_0100
        | FourCharCode(fourth)
    )
  }

  /// Creates a code from combining bytes extracted from the given iterator.
  ///
  /// - Parameter iterator: The source of the bytes to extract.
  /// - Postcondition: `self.elementsEqual([A, B, C, D])`,
  ///   where `A`, `B`, `C`, and `D` are the first four bytes extracted from
  ///   `iterator` (in that order).
  ///   Any later elements are untouched.
  ///   If `iterator` doesn't have at least four elements available,
  ///   this initializer fails.
  public init?(extractingFrom iterator: inout some IteratorProtocol<UInt8>) {
    guard let first = iterator.next(), let second = iterator.next(),
      let third = iterator.next(), let fourth = iterator.next()
    else { return nil }
    self.init(rawOctets: first, second, third, fourth)
  }

  /// Creates a code from combining bytes read from the given sequence.
  ///
  /// - Parameters:
  ///   - sequence: The source of the bytes to read.
  ///   - useAllBytes: Whether every element from `sequence` needs to be read
  ///     from.
  ///     If not given,
  ///     defaults to `true`,
  ///     meaning the entire `sequence` needs to be read in.
  /// - Postcondition: `self.elementsEqual(sequence.prefix(4))`.
  ///   If the `sequence` either has less than four elements,
  ///   or it has more than four elements while `useAllBytes` is `true`,
  ///   this initializer fails.
  public init?(
    reading sequence: some Sequence<UInt8>,
    totally useAllBytes: Bool = true
  ) {
    var iterator = sequence.makeIterator()
    self.init(extractingFrom: &iterator)
    guard !useAllBytes || iterator.next() == nil else { return nil }
  }
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
