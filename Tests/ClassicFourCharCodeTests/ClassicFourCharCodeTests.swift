import Foundation
import Testing

@testable import ClassicFourCharCode

/// Test translation from a code to non-debug text.
@Test(
  "Non-debug printing",
  arguments: zip(
    [
      0,
      0x4162_4344,
    ],
    [
      String(repeating: "\u{0}" as Character, count: 4),
      "AbCD",
    ]
  )
)
func regularPrint(out input: FourCharCode, as output: String) async throws {
  #expect(String(describing: ClassicFourCharCode(rawValue: input)) == output)
}

/// Test translation from a code to debugging text.
@Test(
  "Debug printing",
  arguments: zip(
    [
      0,
      0x4162_4344,
    ],
    [
      String(repeating: "0" as Character, count: 8),
      "41624344",
    ]
  )
)
func debugPrint(out input: FourCharCode, as output: String) async throws {
  #expect(String(reflecting: ClassicFourCharCode(rawValue: input)) == output)
}

/// Test translation from text to a code.
@Test(
  "Reading",
  arguments: zip(
    [
      String(repeating: "\u{0}" as Character, count: 4),
      String(repeating: "0" as Character, count: 8),
      "",  // Too short
      "AbCD",
      "41624344",
      "ThE",  // Too short, but not empty
      "E5+¼",  // Contains a character outside of Mac OS Roman
      "Abov3",  // In-between improper length
      "01B02y4c",  // Contains a character that isn't a hexadecimal digit
      "012345678",  // Too long
    ],
    [
      0,
      0,
      nil,
      0x4162_4344,
      0x4162_4344,
      nil,
      nil,
      nil,
      nil,
      nil,
    ]
  )
)
func read(in input: String, as expected: FourCharCode?) async throws {
  #expect(ClassicFourCharCode(input)?.rawValue == expected)
}

/// Test `Codable` translation.
@Test(
  "Codable support",
  arguments: [
    0,
    0x4162_4344,
  ]
)
func codable(_ value: FourCharCode) async throws {
  let valueString = String(describing: value)
  let jsonData = valueString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()
  let directCode = ClassicFourCharCode(rawValue: value)
  let jsonCode = try decoder.decode(ClassicFourCharCode.self, from: jsonData)
  #expect(directCode == jsonCode)

  let codedDirect = try encoder.encode(directCode)
  let coded = String(data: codedDirect, encoding: .utf8)
  #expect(coded == valueString)
}

/// Test if `String` conversion results are actually printable.
@Test(
  "Printable checks",
  arguments: zip(
    [
      0,
      0x4142_4344,
      0x4501_4650,
      0x527F_5354,
      0x7F55_1356,
      0x5782_C2DD,
    ],
    [
      false,
      true,
      false,
      false,
      false,
      true,
    ]
  )
)
func printable(code: FourCharCode, expecting: Bool) async throws {
  #expect(ClassicFourCharCode(rawValue: code).isPrintable == expecting)
}

/// Test assignment to the code pack all at once.
@Test("Assignment through one value")
func wholesaleAssignment() async throws {
  var code = ClassicFourCharCode(rawValue: 0x4142_4344)
  #expect(String(describing: code) == "ABCD")
  code = ClassicFourCharCode(rawValue: 0x4167_4344)
  #expect(String(describing: code) == "AgCD")
}

/// Test collection access via raw memory access.
@Test(
  "Immutable raw memory access",
  arguments: zip(
    [
      0,
      0x4142_4344,
    ],
    [
      [0, 0, 0, 0],
      [0x41, 0x42, 0x43, 0x44],
    ]
  )
)
func memoryRead(_ rawCode: FourCharCode, _ octets: [UInt8]) async throws {
  let code = ClassicFourCharCode(rawValue: rawCode)
  #expect(code.withUnsafeBytes { $0.elementsEqual(octets) })
}

/// Test repeating-value initializer.
@Test("Repeating single octet initializer")
func repeating() async throws {
  for i in UInt8.min...UInt8.max {
    let code = ClassicFourCharCode(repeating: i)
    let expectedRawValue = stride(from: 24, through: 0, by: -8).map {
      FourCharCode(i) << $0
    }.reduce(0, |)
    #expect(code.withUnsafeBytes({ bufferPointer in
      return bufferPointer.elementsEqual(repeatElement(i, count: 4))
    }))
    #expect(code.rawValue == expectedRawValue)
  }
}

/// Test seperate-bytes initializer.
@Test(
  "Individual byte initializer",
  arguments: zip(
    [
      [0, 0, 0, 0],
      [0x41, 0x42, 0x43, 0x44],
    ],
    [
      0,
      0x4142_4344,
    ]
  )
)
func seperateBytes(_ octets: [UInt8], `as` rawCode: FourCharCode) async throws {
  #expect(
    ClassicFourCharCode(rawOctets: octets[0], octets[1], octets[2], octets[3])
      == ClassicFourCharCode(rawValue: rawCode)
  )
}

/// Test reading from iterators and sequences.
@Test("Initialize from iterator/sequence")
func initializeFromSequence() async throws {
  let source2 = [0x41 as UInt8, 0x42, 0x43, 0x44, 0x61, 0x62, 0x63, 0x64]
  do {
    var iterator = source2.makeIterator()
    let code1 = ClassicFourCharCode(extractingFrom: &iterator)
    let code2 = ClassicFourCharCode(extractingFrom: &iterator)
    #expect(code1 == .some(.init(rawValue: 0x4142_4344)))
    #expect(code2 == .some(.init(rawValue: 0x6162_6364)))
    #expect(iterator.next() == nil)
  }
  do {
    var iterator = source2.prefix(3).makeIterator()
    let code1 = ClassicFourCharCode(extractingFrom: &iterator)
    #expect(code1 == .none)
  }
  do {
    let code1 = ClassicFourCharCode(reading: source2.prefix(4))
    #expect(code1 == .some(.init(rawValue: 0x4142_4344)))

    let code2 = ClassicFourCharCode(reading: source2.prefix(4), totally: true)
    #expect(code2 == .some(.init(rawValue: 0x4142_4344)))

    let code3 = ClassicFourCharCode(reading: source2.prefix(4), totally: false)
    #expect(code3 == .some(.init(rawValue: 0x4142_4344)))
  }
  do {
    let code1 = ClassicFourCharCode(reading: source2.suffix(4))
    #expect(code1 == .some(.init(rawValue: 0x6162_6364)))

    let code2 = ClassicFourCharCode(reading: source2.suffix(4), totally: true)
    #expect(code2 == .some(.init(rawValue: 0x6162_6364)))

    let code3 = ClassicFourCharCode(reading: source2.suffix(4), totally: false)
    #expect(code3 == .some(.init(rawValue: 0x6162_6364)))
  }
  do {
    let code1 = ClassicFourCharCode(reading: source2)
    #expect(code1 == .none)

    let code2 = ClassicFourCharCode(reading: source2, totally: true)
    #expect(code2 == .none)

    let code3 = ClassicFourCharCode(reading: source2, totally: false)
    #expect(code3 == .some(.init(rawValue: 0x4142_4344)))
  }
}
