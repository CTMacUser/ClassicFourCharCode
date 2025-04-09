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
  code.rawValue = 0x4167_4344
  #expect(String(describing: code) == "AgCD")
}
