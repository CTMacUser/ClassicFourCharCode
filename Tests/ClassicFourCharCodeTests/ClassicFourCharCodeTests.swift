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

/// Test sequence support.
@Test(
  "Sequence support",
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
func sequencing(_ rawCode: FourCharCode, `as` octets: [UInt8]) async throws {
  let code = ClassicFourCharCode(rawValue: rawCode)
  let match = try #require(
    code.withContiguousStorageIfAvailable { octets.elementsEqual($0) } as Bool?
  )
  #expect(match)
  #expect(code.underestimatedCount == 4)
  #expect(code.elementsEqual(octets))
  #expect(!octets.map { code.contains($0) }.contains(false))
}

/// Test repeating-value initializer.
@Test("Repeating single octet initializer")
func repeating() async throws {
  for i in UInt8.min...UInt8.max {
    let code = ClassicFourCharCode(repeating: i)
    let expectedRawValue = stride(from: 24, through: 0, by: -8).map {
      FourCharCode(i) << $0
    }.reduce(0, |)
    #expect(code.elementsEqual(repeatElement(i, count: 4)))
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

/// Test subsequence type.
@Test(
  "SubSequence type",
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
func subsequencing(_ rawCode: FourCharCode, `as` octets: [UInt8]) async throws {
  // Build the subsequence as a 100% slice of a base code.
  let code = ClassicFourCharCode(rawValue: rawCode)
  let subCode = code[code.startIndex..<code.endIndex]

  // Direct memory support
  #expect(subCode.withUnsafeBytes { $0.elementsEqual(octets) })

  // Sequence-level memory support
  let match = try #require(
    subCode.withContiguousStorageIfAvailable { octets.elementsEqual($0) }
      as Bool?
  )
  #expect(match)

  // General support (but no `contains`, since it isn't specialized)
  #expect(subCode.underestimatedCount == 4)
  #expect(subCode.elementsEqual(octets))

  // Index values
  #expect(subCode.indices.elementsEqual([-24, -16, -8, 0]))
  #expect(subCode.endIndex == 8)
  #expect(subCode.indices.map { subCode[$0] }.elementsEqual(octets))

  // Reversing
  #expect(subCode.reversed().elementsEqual(octets.reversed()))

  // Single-step indexing
  var forward = subCode.startIndex
  var forwardIndices = [Int]()
  while forward < subCode.endIndex {
    forwardIndices.append(forward)
    forward = subCode.index(after: forward)
  }
  #expect(forwardIndices.elementsEqual(subCode.indices))

  var backward = subCode.endIndex
  var backwardIndices = [Int]()
  repeat {
    backward = subCode.index(before: backward)
    backwardIndices.append(backward)
  } while backward > subCode.startIndex
  #expect(backwardIndices.reversed().elementsEqual(subCode.indices))

  // Multi-step indexing
  #expect(
    subCode.index(forwardIndices[1], offsetBy: +2, limitedBy: subCode.endIndex)
      == forwardIndices[3]
  )
  #expect(
    subCode.index(forwardIndices[1], offsetBy: +3, limitedBy: subCode.endIndex)
      == subCode.endIndex
  )
  #expect(
    subCode.index(forwardIndices[1], offsetBy: +4, limitedBy: subCode.endIndex)
      == nil
  )
  #expect(
    subCode.index(
      forwardIndices[1],
      offsetBy: -1,
      limitedBy: subCode.startIndex
    ) == subCode.startIndex
  )
  #expect(
    subCode.index(forwardIndices[2], offsetBy: -1, limitedBy: forwardIndices[1])
      == forwardIndices[1]
  )
  #expect(
    subCode.index(forwardIndices[2], offsetBy: -2, limitedBy: forwardIndices[1])
      == nil
  )
  #expect(
    subCode.index(forwardIndices[2], offsetBy: -2, limitedBy: subCode.endIndex)
      == subCode.startIndex
  )
  #expect(
    subCode.index(
      forwardIndices[2],
      offsetBy: -3,
      limitedBy: subCode.startIndex
    ) == nil
  )
}

/// Test the mutating operations of a subsequence.
@Test("SubSequence Mutations")
func mutatingSubsequence() async throws {
  // Start with swapping
  let code = ClassicFourCharCode(rawValue: 0xE1D2_C3B4)
  var subCode = code[code.startIndex..<code.endIndex]
  subCode.swapAt(
    subCode.index(after: subCode.startIndex),
    subCode.index(before: subCode.endIndex)
  )
  try #require(
    subCode.elementsEqual(ClassicFourCharCode(rawValue: 0xE1B4_C3D2))
  )

  // No change
  let thirdIndex = subCode.index(subCode.startIndex, offsetBy: +2)
  subCode.swapAt(thirdIndex, thirdIndex)
  try #require(
    subCode.elementsEqual(ClassicFourCharCode(rawValue: 0xE1B4_C3D2))
  )

  // Direct memory access, now mutable
  subCode.withContiguousMutableStorageIfAvailable { buffer in
    buffer[0] = 0xF0
  }
  try #require(
    subCode.elementsEqual(ClassicFourCharCode(rawValue: 0xF0B4_C3D2))
  )

  // Subscripting
  let validIndices = Array(subCode.indices)
  #expect([0xF0, 0xB4, 0xC3, 0xD2] == validIndices.map { subCode[$0] })
  subCode[validIndices.first!] += 1
  try #require(
    subCode.elementsEqual(ClassicFourCharCode(rawValue: 0xF1B4_C3D2))
  )

  subCode[subCode.startIndex..<thirdIndex] = code[thirdIndex..<code.endIndex]
  try #require(
    subCode.elementsEqual(ClassicFourCharCode(rawValue: 0xC3B4_C3D2))
  )
}

/// Testing index shifting.
@Test("Index manipulations")
func indexing() async throws {
  // Most of the indexing functions have been tested in `subsequencing` and
  // `mutatingSubsequence`.
  // The major thing left is the limited arbitrary-amount index-shift function.
  let code = ClassicFourCharCode(rawValue: 0xF8E7_D6C5)
  let indices = code.indices
  let allIndices = Array(indices) + [indices.endIndex]
  for (n, i) in allIndices.enumerated() {
    let overLimited = (-n - 1)...(-n + indices.count + 1)
    let shiftedIndices = overLimited.map {
      indices.index(
        i,
        offsetBy: $0,
        limitedBy: $0 < 0 ? indices.startIndex : indices.endIndex
      )
    }
    #expect(shiftedIndices.first == .some(.none))
    #expect(shiftedIndices.last == .some(.none))
    #expect(shiftedIndices.compactMap(\.self) == allIndices)
  }
  #expect(
    indices.index(
      indices.startIndex,
      offsetBy: .max,
      limitedBy: indices.endIndex
    ) == nil
  )
  #expect(
    indices.index(allIndices[1], offsetBy: +2, limitedBy: indices.startIndex)
      == allIndices[3]
  )

  // Self-reflection
  #expect(indices.indices == indices)

  // Index finding, which is trival
  #expect(indices.firstIndex(of: allIndices[2]) == allIndices[2])
  #expect(indices.lastIndex(of: allIndices[2]) == allIndices[2])
  #expect(indices.firstIndex(of: allIndices[2] + 500) == nil)
  #expect(indices.lastIndex(of: allIndices[2] + 500) == nil)

  // Blocks
  #expect(
    indices[allIndices[0]..<allIndices[3]].elementsEqual(allIndices[0..<3])
  )
}

/// Test the collection directly.
@Test("Collection")
func collection() async throws {
  // Length
  var code = ClassicFourCharCode(rawOctets: 0xFE, 0xDC, 0xBA, 0x98)
  #expect(code.count == 4)

  // Single-step index update
  var index1 = code.startIndex
  #expect(code[index1] == 0xFE)
  code.formIndex(after: &index1)
  #expect(code[index1] == 0xDC)
  code.formIndex(after: &index1)
  #expect(code[index1] == 0xBA)
  code.formIndex(after: &index1)
  #expect(code[index1] == 0x98)
  code.formIndex(after: &index1)
  #expect(index1 == code.endIndex)
  code.formIndex(before: &index1)
  #expect(code[index1] == 0x98)
  code.formIndex(before: &index1)
  #expect(code[index1] == 0xBA)
  code.formIndex(before: &index1)
  #expect(code[index1] == 0xDC)
  code.formIndex(before: &index1)
  #expect(code[index1] == 0xFE)
  #expect(index1 == code.startIndex)

  // Single-element change through subscript
  code[index1] = 0x76
  #expect(code.rawValue == 0x76DC_BA98)

  // Multiple-element change through subscript, and swapping
  let index3 = code.index(index1, offsetBy: +2)
  let index2 = code.index(before: index3)
  let index4 = code.index(after: index3)
  code.swapAt(index2, index4)
  #expect(code.rawValue == 0x7698_BADC)
  code[index1..<index3] = code[index3..<code.endIndex]
  #expect(code.rawValue == 0xBADC_BADC)

  // Multi-step index update
  #expect(code.index(index2, offsetBy: +2, limitedBy: code.endIndex) == index4)
  #expect(
    code.index(index2, offsetBy: +3, limitedBy: code.endIndex) == code.endIndex
  )
  #expect(
    code.index(index2, offsetBy: -1, limitedBy: code.startIndex)
      == code.startIndex
  )
  #expect(code.index(index2, offsetBy: -2, limitedBy: code.startIndex) == nil)

  // Mutating through direct memory access
  let result = code.withContiguousMutableStorageIfAvailable { buffer in
    buffer[0] += 1
    buffer[1] += 2
    buffer[2] += 3
    buffer[3] += 4
    return buffer.map { $0 % 3 }.reduce(0, +)
  }
  #expect(result == .some(3))
  #expect(code.rawValue == 0xBBDE_BDE0)
}
