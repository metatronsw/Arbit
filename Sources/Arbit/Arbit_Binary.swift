import Foundation

// MARK: Binary << & | ~ ^
///
/// The bitwise operations work on integers only, a fraction or an error value gives `nan`.
/// Negative numbers behave as two's complement with endless sign bits, like at `Int`: `~5 == -6`, `-1 & 255 == 255`.
///
extension Arbit: BinaryInteger {
	
	public typealias Words = [UInt]
	
	/// The two's complement words of the integer part, from the least significant one
	public var words: [UInt] {
		
		guard error == nil else { return [0] }
		
		let wordBits = UInt.bitWidth
		let width = ((magnitudeBits.count + 1 + wordBits - 1) / wordBits) * wordBits
		let bits = twosComplement(width: width)
		
		return stride(from: 0, to: width, by: wordBits).map { base in
			var word: UInt = 0
			for i in 0..<wordBits where bits[base + i] { word |= 1 << UInt(i) }
			return word
		}
	}
	
	
	
	// MARK: Init
	
	public init?<T>(exactly source: T) where T : BinaryInteger { self.init(source) }
	
	public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger { self.init(source) }
	
	public init<T>(clamping source: T) where T : BinaryInteger { self.init(source) }
	
	public init<T>(_ source: T) where T : BinaryInteger {
		
		if let arbit = source as? Arbit {
			self = arbit
			return
		}
		self.integer = String(source.magnitude)
		self.negative = source < 0
	}
	
	
	public init?<T>(exactly source: T) where T : BinaryFloatingPoint {
		guard source.isFinite else { return nil }
		self.init(floatLiteral: Double(source))
	}
	
	public init<T>(_ source: T) where T : BinaryFloatingPoint {
		self.init(floatLiteral: Double(source))
	}
	
	
	
	// MARK: Bits
	
	/// The binary digits of the absolute integer part, the most significant first
	var magnitudeBits: String { integer.decToBin() }
	
	var isInteger: Bool { error == nil && fraction == nil }
	
	
	/// Two's complement bits of the integer part on the given width, the least significant first.
	/// The width must be bigger than the count of the magnitude bits.
	func twosComplement(width: Int) -> [Bool] {
		
		var bits = magnitudeBits.reversed().map { $0 == "1" }
		
		if bits.count < width {
			bits += Array(repeating: false, count: width - bits.count)
		}
		
		if negative { Self.negateBits(&bits) }
		
		return bits
	}
	
	/// Builds an integer from two's complement bits, the least significant first, the last one is the sign
	static func fromTwosComplement(_ bits: [Bool]) -> Arbit {
		
		var bits = bits
		let negative = bits.last == true
		
		if negative { negateBits(&bits) }
		
		let string = String(bits.reversed().map { $0 ? "1" as Character : "0" })
		
		return fromScaled(string.binToDec(), scale: 0, negative: negative)
	}
	
	/// Two's complement negation: invert and add one
	private static func negateBits(_ bits: inout [Bool]) {
		
		var carry = true
		
		for i in bits.indices {
			let inverted = !bits[i]
			bits[i] = inverted != carry
			carry = inverted && carry
		}
	}
	
	private static func bitwise(_ lhs: Arbit, _ rhs: Arbit, _ operation: (Bool, Bool) -> Bool) -> Arbit {
		
		guard lhs.isInteger, rhs.isInteger else { return .nan }
		
		let width = Swift.max(lhs.magnitudeBits.count, rhs.magnitudeBits.count) + 2
		let left = lhs.twosComplement(width: width)
		let right = rhs.twosComplement(width: width)
		
		return fromTwosComplement(zip(left, right).map(operation))
	}
	
	
	
	// MARK: Arithmetic
	
	/// Bitwise not, in two's complement: `~x == -x - 1`
	public static prefix func ~ (x: Arbit) -> Arbit {
		
		guard x.isInteger else { return .nan }
		
		return -x - 1
	}
	
	
	/// Remainder with the sign of the dividend, like at `Int`: `-7 % 3 == -1`. Works with fractions: `7.5 % 2 == 1.5`
	public static func %  (lhs: Arbit, rhs: Arbit) -> Arbit {
		let (_ , rem) = lhs.quotientAndRemainder(dividingBy: rhs)
		return rem
	}
	
	public static func %= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs % rhs  }
	
	
	
	public static func &  (lhs: Arbit, rhs: Arbit) -> Arbit { bitwise(lhs, rhs) { $0 && $1 } }
	
	public static func &= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs & rhs }
	
	
	public static func |  (lhs: Arbit, rhs: Arbit) -> Arbit { bitwise(lhs, rhs) { $0 || $1 } }
	
	public static func |= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs | rhs }
	
	
	public static func ^  (lhs: Arbit, rhs: Arbit) -> Arbit { bitwise(lhs, rhs) { $0 != $1 } }
	
	public static func ^= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs ^ rhs }
	
	
	public static func <<= <RHS>(lhs: inout Arbit, rhs: RHS) where RHS : BinaryInteger {
		lhs = lhs.shifted(left: Int(clamping: rhs))
	}
	
	public static func >>= <RHS>(lhs: inout Arbit, rhs: RHS) where RHS : BinaryInteger {
		lhs = lhs.shifted(left: -Int(clamping: rhs))
	}
	
	/// Bit shift: left is a multiplication by 2^n, right is a division rounded down (toward negative infinity)
	private func shifted(left bits: Int) -> Arbit {
		
		guard isInteger else { return .nan }
		
		if bits == 0 || isZero { return self }
		
		let power = Arbit(raw: Self.magPow("2", abs(bits)))
		
		if bits > 0 { return self * power }
		
		let (quotient, remainder) = self.quotientAndRemainder(dividingBy: power)
		
		return (negative && !remainder.isZero) ? quotient - 1 : quotient
	}
	
	
	
	// MARK: Mixed comparison
	///
	/// Without these the standard library compares by `words`, which knows only the integer part.
	
	public static func == <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { lhs == Arbit(rhs) }
	public static func != <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { !(lhs == Arbit(rhs)) }
	public static func <  <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { lhs <  Arbit(rhs) }
	public static func <= <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { lhs <= Arbit(rhs) }
	public static func >  <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { lhs >  Arbit(rhs) }
	public static func >= <Other: BinaryInteger>(lhs: Arbit, rhs: Other) -> Bool { lhs >= Arbit(rhs) }
	
	
	
	// MARK: Questions

	public static var isSigned: Bool { true }
	
	public var signumInt: Int { negative ? -1 : 1 }
	
	public var sign: String { negative ? "-" : "" }
	
	public var fullsign: String { negative ? "-" : "+" }
	
	public var isDecimal: Bool { fraction != nil }
	
	public var isNegative: Bool { negative }
	
	/// The bit count of the two's complement form (`words`), with the sign bit
	public var bitWidth: Int { words.count * UInt.bitWidth }
	
	public var trailingZeroBitCount: Int {
		
		guard isInteger, !isZero else { return bitWidth }
		
		return magnitudeBits.reversed().prefix(while: { $0 == "0" }).count
	}
	
	/// The count of the 1 bits in the absolute integer part
	public var oneBitCount: Int { magnitudeBits.filter { $0 == "1" }.count }
	
	public var isOdd: Bool {
		guard isInteger, let last = integer.last?.wholeNumberValue else { return false }
		return last % 2 == 1
	}
	
	public var isEven: Bool { isInteger && !isOdd }
}




// MARK: Convert & Export
extension Arbit {
	
	/// Moves the decimal point: multiplies by 10^decimals
	public mutating func shift(decimals: Int) {
		
		guard decimals != 0, error == nil else { return }
		
		let frc = fraction ?? ""
		
		if decimals > 0 {
			
			let padded = frc.count < decimals ? frc + String(repeating: "0", count: decimals - frc.count) : frc
			
			integer += padded.prefix(decimals)
			fraction = String(padded.dropFirst(decimals))
			
		} else {
			
			let shift = -decimals
			let padded = integer.count < shift ? String(repeating: "0", count: shift - integer.count) + integer : integer
			
			fraction = String(padded.suffix(shift)) + frc
			integer = String(padded.dropLast(shift))
		}
		
		normalize()
	}
	
	
	public func asBinary(withPrefix: Bool = false) -> String {
		
		guard !self.isEmpty else { return "0b?" }
		guard !self.isError else { return self.description }
		
		let bin = self.integer.decToBin()
		
		return self.sign + (withPrefix ? "0b" + bin : bin)
	}
	
	
	public func asOctal(withPrefix: Bool = false) -> String {
		
		guard !self.isEmpty else { return "0o?" }
		guard !self.isError else { return self.description }
		
		let oct = self.integer.decToBin()
			.chunkedReverse(by: 3)
			.reversed()
			.map { String(Int($0, radix: 2) ?? 0) }
			.joined()
		
		return self.sign + (withPrefix ? "0o" + oct : oct)
	}
	
	
	public func asHexadecimal(withPrefix: Bool = false) -> String {
		
		guard !self.isEmpty else { return "0x?" }
		guard !self.isError else { return self.description }
		
		let hex = self.integer.decToHex()
	
		return self.sign + (withPrefix ? "0x" + hex : hex)
	}
	
	
	/// The digits of the integer part as binary coded decimals.
	/// Packed: two digits in a byte (`1234` → `[0x12, 0x34]`, `123` → `[0x01, 0x23]`), else one digit in a byte.
	public func asBinaryCodedDecimal(packed: Bool = true) -> [UInt8] {
		
		/// https://en.wikipedia.org/wiki/Binary-coded_decimal
		
		var digits = self.integer.utf8.map { $0 - 48 }
		
		guard packed else { return digits }
		
		if digits.count % 2 == 1 { digits.insert(0, at: 0) }
		
		return stride(from: 0, to: digits.count, by: 2).map { digits[$0] << 4 | digits[$0 + 1] }
	}
	
}


// MARK: Conversion Bin, Dec, Oct, Hex
extension String {
	
	public func binToDec() -> String {
		
		func carryng(_ array: inout Array<Int>, _ index: Int) {
			if array[index] > 9 {
				array[index + 1] += 1
				array[index] -= 10
			}
		}
		
		var ints = [0]
		var temps = [1]
		var intsLen = 1
		var indeX = 0
		
		
		for bin in self.reversed() {
			
			//		print(intsLen, temps.count, ints)
			
			if bin == "1" {
				
				for t in 0..<temps.count {
					ints[t] += temps[t]
					carryng(&ints, t)
				}
				
				intsLen = indeX
				
				if ints[indeX] != 0 { intsLen += 1 }
			}
			
			for c in 0..<temps.count { temps[c] += temps[c] }
			for b in 0..<temps.count { carryng(&temps, b) }
			
			indeX = temps.count - 1
			if temps[indeX] != 0 { temps.append(0) ; ints.append(0)}
		}
		
		var decimal = ""
		for p in stride(from: intsLen-1, through: 0, by: -1) {
			decimal += String(ints[p])
		}
		
		return decimal
	}
	
	public func binToHex() -> String {
		
		let binLut = [
			"0":"0", "00":"0", "000":"0", "0000":"0",
			"1":"1", "01":"1", "001":"1", "0001":"1",
			"10":"2", "010":"2", "0010":"2",
			"11":"3", "011":"3", "0011":"3",
			"100":"4", "0100":"4",
			"101":"5", "0101":"5",
			"110":"6", "0110":"6",
			"111":"7", "0111":"7",
			"1000":"8",
			"1001":"9",
			"1010":"A",
			"1011":"B",
			"1100":"C",
			"1101":"D",
			"1110":"E",
			"1111":"F",
		]
		
		var hex = ""
		let parts = self.chunkedReverse(by: 4)
		
		for part in parts.reversed() {
			guard let h = binLut[String(part)] else { return "0x?" }
			hex += h
		}
		
		return hex
	}
	
	public func decToHex() -> String {
		
		let hexLut = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" ]
		
		
		var result = [UInt8]()
		result.append(0)
		
		for c in self {
			
			var val = Int(String(c))!
			
			for i in 0 ..< result.count {
				let digit = Int(result[i]) * 10 + val
				result[i] = UInt8( digit & 0x0F )
				val = digit >> 4
			}
			
			if val != 0 { result.append(UInt8(val)) }
		}
		
		
		var hex = ""
		for b in result {
			hex = hexLut[Int(b)] + hex
		}
		
		
		return hex
	}
	
	public func decToBin() -> String {
		
		
		func oddsToOne(_ str: String) -> Int {
			
			guard let last = str.last else { return 0 }
			
			switch last {
				case "1", "3", "5", "7", "9": return 1
				default: return 0
			}
		}
		
		func divByTwo(_ str: String) -> String {
			
			var string = ""
			var add = 0
			
			for chr in str {
				let newDgt = Int(chr) / 2 + add
				string += "\(newDgt)"
				add = oddsToOne(String(chr)) * 5
			}
			
			if string != "0" && string.hasPrefix("0") {
				string.removeFirst()
			}
			
			return string
		}
		
		var num = self
		var string: String
		
		if num == "0" { string = "0" }
		else {
			string = ""
			while num != "0" {
				string = oddsToOne(num).description + string
				num = divByTwo(num)
			}
		}
		return string
	}
	
	public func hexToDec() -> String { hexToBin().binToDec() }
	
	/// Four bits for every hexadecimal digit, "0x?" for an invalid digit
	public func hexToBin() -> String { digitsToBin(bitsPerDigit: 4) }
	
	public func octToDec() -> String { octToBin().binToDec() }
	
	/// Three bits for every octal digit, "0o?" for an invalid digit
	public func octToBin() -> String { digitsToBin(bitsPerDigit: 3) }
	
	private func digitsToBin(bitsPerDigit: Int) -> String {
		
		var bits = ""
		
		for chr in self {
			guard let value = chr.hexDigitValue, value < (1 << bitsPerDigit) else {
				return bitsPerDigit == 4 ? "0x?" : "0o?"
			}
			let bin = String(value, radix: 2)
			bits += String(repeating: "0", count: bitsPerDigit - bin.count) + bin
		}
		
		return bits
	}
	
}

