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

// MARK: More Initializers

extension ClassicFourCharCode {
  /// Creates a new code repeating the given byte value.
  ///
  /// - Parameter value: The octet to repeat.
  /// - Postcondition: `self.elementsEqual(repeatElement(value, count: 4))`
  @inlinable
  public init(repeating value: Element) {
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
    rawOctets first: Element,
    _ second: Element,
    _ third: Element,
    _ fourth: Element
  ) {
    self.init(
      rawValue: FourCharCode(first) &* 0x0100_0000 | FourCharCode(second)
        &* 0x0001_0000 | FourCharCode(third) &* 0x0000_0100
        | FourCharCode(fourth)
    )
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

  public typealias Element = Iterator.Element

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
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    return try .some(
      self.withUnsafeBytes {
        return try $0.withMemoryRebound(to: Element.self, body)
      }
    )
  }
}

extension ClassicFourCharCode: RandomAccessCollection, MutableCollection {
  public typealias Indices = ClassicFourCharCodeIndices
  public typealias Index = Indices.Index

  // The elements are the octets embedded within the code.
  // Each one can be extracted by using the
  // appropriate (right) bit shifting then keeping only the lowest-order byte.
  //
  // Instead of a user-understandable `0..<4` for the index values,
  // the index values are the direct bit-shift amounts.
  // This saves doing a translation step every time an indexing is done.
  // Note that the octet formed by the down-shift by 24 is the first element,
  // since the embedded bytes are read in big endian order.
  // The `Index` type needs to be `Comparable`,
  // but we cannot override how that type does comparisons.
  // Since we need the highest down-shift to go first,
  // we instead store the negatives.
  @inlinable
  public var startIndex: Index { -24 }
  @inlinable
  public var endIndex: Index { 8 }

  @inlinable
  public var indices: ClassicFourCharCodeIndices {
    .init(startIndex..<endIndex)
  }

  /// Generates a sub-sequence that encompasses the entire code.
  @usableFromInline
  var subsequence: SubSequence {
    .init(base: rawValue, range: startIndex..<endIndex)
  }

  @inlinable
  public subscript(position: Index) -> Element {
    get { subsequence[position] }
    set {
      var copy = subsequence
      copy[position] = newValue
      rawValue = copy.base
    }
  }
  @inlinable
  public subscript(bounds: Range<Index>) -> ClassicFourCharCodeSubSequence {
    get { subsequence[bounds] }
    set {
      var copy = subsequence
      copy[bounds] = newValue
      rawValue = copy.base
    }
  }

  @inlinable
  public func index(after i: Index) -> Index {
    return indices.index(after: i)
  }
  public func formIndex(after i: inout Index) {
    indices.formIndex(after: &i)
  }

  @inlinable
  public func index(before i: Index) -> Index {
    return indices.index(before: i)
  }
  @inlinable
  public func formIndex(before i: inout Index) {
    indices.formIndex(before: &i)
  }

  @inlinable
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return indices.index(i, offsetBy: distance)
  }
  @inlinable
  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index)
    -> Index?
  {
    return indices.index(i, offsetBy: distance, limitedBy: limit)
  }
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return indices.distance(from: start, to: end)
  }

  @inlinable
  public mutating func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    var copy = subsequence
    let result = try copy.withContiguousMutableStorageIfAvailable(body)
    rawValue = copy.base
    return result
  }

  @inlinable
  public mutating func swapAt(_ i: Index, _ j: Index) {
    var copy = subsequence
    copy.swapAt(i, j)
    rawValue = copy.base
  }
}

extension ClassicFourCharCode: DataProtocol {
  @inlinable
  public var regions: SubSequence.Regions { subsequence.regions }
}

// MARK: Auxillary Types

/// The index-block type for `ClassicFourCharCode`.
public struct ClassicFourCharCodeIndices: RandomAccessCollection, Equatable {
  /// The spacing between consecutive octets in terms of bits.
  @usableFromInline
  static let spacing = 8

  /// Create an index block with the given bounds.
  @usableFromInline
  init(_ bounds: Range<Index>) {
    startIndex = bounds.lowerBound
    endIndex = bounds.upperBound
    precondition(startIndex.isMultiple(of: Self.spacing))
    precondition(endIndex.isMultiple(of: Self.spacing))
  }

  public typealias Element = Int
  public typealias Index = Element

  public let startIndex: Index
  public let endIndex: Index

  @inlinable
  public func makeIterator() -> StrideToIterator<Element> {
    return stride(from: startIndex, to: endIndex, by: Self.spacing)
      .makeIterator()
  }

  public func _customContainsEquatableElement(_ element: Index) -> Bool? {
    return .some(
      startIndex..<endIndex ~= element
        && (element - startIndex).isMultiple(of: Self.spacing)
    )
  }

  public subscript(position: Index) -> Index {
    precondition(self.contains(position))
    return position
  }
  public subscript(bounds: Range<Index>) -> Self {
    precondition(
      bounds.isEmpty
        || self.contains(bounds.lowerBound)
          && (startIndex..<endIndex).contains(bounds)
    )
    return .init(bounds)
  }

  @inlinable
  public var indices: Self { self }

  @inlinable
  public func index(after i: Index) -> Index {
    return i + Self.spacing
  }
  @inlinable
  public func formIndex(after i: inout Index) {
    i += Self.spacing
  }

  @inlinable
  public func _customIndexOfEquatableElement(_ element: Index) -> Index?? {
    return .some(self.contains(element) ? .some(element) : .none)
  }
  @inlinable
  public func _customLastIndexOfEquatableElement(_ element: Index) -> Index?? {
    // All elements are unique.
    return self._customIndexOfEquatableElement(element)
  }

  @inlinable
  public func index(before i: Index) -> Index {
    return i - Self.spacing
  }
  @inlinable
  public func formIndex(before i: inout Index) {
    i -= Self.spacing
  }

  @inlinable
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return i + distance * Self.spacing
  }
  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index)
    -> Index?
  {
    // The next two guards make the last one easier.
    guard distance != 0 else { return i }
    guard limit != i else { return nil }
    // Do `i + distance * Self.spacing` in a way that doesn't trap overflow.
    guard
      case let (bitDistance, overflow1) = distance.multipliedReportingOverflow(
        by: Self.spacing
      ),
      case let (rawResult, overflow2) = i.addingReportingOverflow(bitDistance),
      !overflow1 && !overflow2
    else {
      // The magnitude of `distance` is WAY too big.
      return nil
    }
    // The `limit` does not apply if traversal went in the opposite direction.
    guard (distance < 0) == (limit < i) else { return rawResult }

    // Return the result if it doesn't blow past `limit`.
    if distance < 0 {
      return rawResult < limit ? nil : rawResult
    } else {
      return limit < rawResult ? nil : rawResult
    }
  }
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return (end - start) / Self.spacing
  }
}

/// The sub-sequence type for `ClassicFourCharCode`.
public struct ClassicFourCharCodeSubSequence: RandomAccessCollection,
  MutableCollection, ContiguousBytes, DataProtocol
{
  /// The source of the octets.
  @usableFromInline
  var base: FourCharCode

  /// `indices` as a `Range`, because that's needed sometimes.
  @inlinable
  var indexRange: Range<Index> { indices.startIndex..<indices.endIndex }

  /// Create a collection of the octets of the given base value,
  /// restricted to the octets within the range of the given bit offsets.
  @inlinable
  init(base: FourCharCode, range: Range<Int>) {
    self.base = base
    self.indices = .init(range)
  }

  public typealias Element = UInt8
  public typealias Index = Indices.Index
  public typealias Indices = ClassicFourCharCodeIndices

  public let indices: Indices

  @inlinable
  public var startIndex: Index { indices.startIndex }
  @inlinable
  public var endIndex: Index { indices.endIndex }

  public subscript(position: Index) -> Element {
    get {
      precondition(indices.contains(position))
      return Element(truncatingIfNeeded: base >> -position)
    }
    set {
      let flipMask = self[position] ^ newValue
      base ^= FourCharCode(flipMask) << -position
    }
  }
  public subscript(bounds: Range<Index>) -> Self {
    get {
      precondition(indexRange.contains(bounds))
      precondition(bounds.isEmpty || indices.contains(bounds.lowerBound))
      // The last test above checks for misaligned indices.
      return .init(base: base, range: bounds)
    }
    set {
      precondition(indexRange.contains(bounds))
      precondition(bounds.isEmpty || indices.contains(bounds.lowerBound))
      precondition(
        distance(from: bounds.lowerBound, to: bounds.upperBound)
          == newValue.count
      )
      for (si, ni) in zip(indices, newValue.indices) {
        self[si] = newValue[ni]
      }
    }
  }

  @inlinable
  public func index(after i: Index) -> Index {
    return indices.index(after: i)
  }
  @inlinable
  public func formIndex(after i: inout Index) {
    indices.formIndex(after: &i)
  }

  @inlinable
  public func index(before i: Index) -> Index {
    indices.index(before: i)
  }
  @inlinable
  public func formIndex(before i: inout Index) {
    indices.formIndex(before: &i)
  }

  @inlinable
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    return indices.index(i, offsetBy: distance)
  }
  @inlinable
  public func index(_ i: Index, offsetBy distance: Int, limitedBy limit: Index)
    -> Index?
  {
    return indices.index(i, offsetBy: distance, limitedBy: limit)
  }
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    return indices.distance(from: start, to: end)
  }

  public func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    let start = startIndex / Indices.spacing + 3
    let end = endIndex / Indices.spacing + 3
    return .some(
      try withUnsafePointer(to: base.bigEndian) { fccPointer in
        return try fccPointer.withMemoryRebound(to: UInt8.self, capacity: 4) {
          let byteBuffer = UnsafeBufferPointer(start: $0, count: 4)
          let byteSlice = UnsafeBufferPointer(rebasing: byteBuffer[start..<end])
          return try body(byteSlice)
        }
      }
    )
  }
  mutating public func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    let start = startIndex / Indices.spacing + 3
    let end = endIndex / Indices.spacing + 3
    var bigBase = base.bigEndian
    defer {
      base = FourCharCode(bigEndian: bigBase)
    }
    return .some(
      try withUnsafeMutablePointer(to: &bigBase) { fccPointer in
        return try fccPointer.withMemoryRebound(to: UInt8.self, capacity: 4) {
          let byteBuffer = UnsafeMutableBufferPointer(start: $0, count: 4)
          var byteSlice = UnsafeMutableBufferPointer(
            rebasing: byteBuffer[start..<end]
          )
          return try body(&byteSlice)
        }
      }
    )
  }

  mutating public func swapAt(_ i: Index, _ j: Index) {
    let flipMask = FourCharCode(truncatingIfNeeded: self[i] ^ self[j])
    base ^= flipMask << -i | flipMask << -j
  }

  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R)
    rethrows -> R
  {
    return try self.withContiguousStorageIfAvailable {
      return try body(UnsafeRawBufferPointer($0))
    }!
  }

  @inlinable
  public var regions: CollectionOfOne<Self> { .init(self) }
}
