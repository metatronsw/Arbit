import Foundation

/// Lossless, arbitrary precision number structure supporting decimal fractions
///
public struct Arbit: Sendable {

	public var integer: String
	public var fraction: String?
	public var negative: Bool
	public var error: Errors?


	/// The decimal separator of the current locale
	public static var decSep: String { Locale.current.decimalSeparator ?? "." }

	/// The grouping separator of the current locale
	public static var groupSep: String { Locale.current.groupingSeparator ?? "\u{2008}" }




	// MARK: Init

	/// Copy: Init from self & override
	public init(_ arbit: Arbit, negative: Bool? = nil, error: Errors? = nil) {
		self.integer = arbit.integer
		self.fraction = arbit.fraction

		self.negative = negative ?? arbit.negative
		self.error = error ?? arbit.error
	}

	/// Fast raw init from string parts, use with care: the parts are not validated and not normalized
	public init(raw intPart: String = "0", _ frcPart: String? = nil, negative: Bool = false, error: Errors? = nil) {
		self.integer = intPart
		self.fraction = frcPart
		self.negative = negative
		self.error = error
	}




	// MARK: Computed

	public var count: Int { integer.count + (fraction?.count ?? 0) }

	public var isZero: Bool { error == nil && integer == "0" && (fraction == nil || fraction?.isEmpty == true) }

	public var isEmpty: Bool { integer == "" || error == .empty }

	public var isBignum: Bool { integer.count + (fraction?.count ?? 0) >= Self.sliceLen }

	public var isError: Bool { error != nil }

	/// Infinity, positive or negative
	public var isInfinite: Bool { error == .infinity }

	/// Any error value except infinity
	public var isNaN: Bool { error != nil && error != .infinity }

}



// MARK: Errors & static values
extension Arbit {

	/// Arbit error cases
	public enum Errors: CustomStringConvertible, Comparable, Hashable, Sendable {

		case empty
		case infinity
		case nan


		public var description: String {
			switch self {
				case .empty: "Not initialised!"
				case .infinity: "Infinity number!"
				case .nan: "Not a number!"
			}
		}
	}

	/// The settings of the operations that cannot be exact: division, roots, logarithm, trigonometry...
	///
	/// There is no global setting, the context travels as a parameter:
	/// ```
	/// a.divided(by: b, .digits(50))
	/// a.sqrRoot(Arbit.Context(digits: 50, rounding: .halfUp))
	/// ```
	/// Without the parameter (and at the `/` operator) the `standard` context is used: 16 digits, truncated.
	public struct Context: Hashable, Sendable {

		/// The count of the calculated fraction digits
		public var digits: Int

		/// The handling of the last digit
		public var rounding: RoundingMode

		public init(digits: Int = 16, rounding: RoundingMode = .truncate) {
			self.digits = digits
			self.rounding = rounding
		}

		/// 16 fraction digits, truncated
		public static let standard = Context()

		/// The given count of fraction digits, truncated
		public static func digits(_ digits: Int) -> Context { Context(digits: digits) }
	}

	/// The handling of the last kept fraction digit
	public enum RoundingMode: Hashable, Sendable {
		/// Cut the remaining digits: 0.666… → 0.66
		case truncate
		/// Round half away from zero: 0.666… → 0.67, 0.125 → 0.13
		case halfUp
		/// Banker's rounding, half goes to the even neighbour: 0.125 → 0.12, 0.135 → 0.14
		case halfEven
	}

	/// Zero value
	public static let zero = Arbit()
	/// One value
	public static let one = Arbit(raw: "1")
	/// Empty, not initialised value
	public static let empty = Arbit(error: .empty)
	/// Infinity value, at overflow
	public static let inf = Arbit(error: .infinity)
	/// Not a number value
	public static let nan = Arbit(error: .nan)



	/// Human readable explanation of the error value, nil for a valid number
	public var errorDescription: String? { error?.description }

}



// MARK: Normalization
extension Arbit {

	/// Brings the number to its canonical form:
	/// no leading zeros in the integer, no trailing zeros in the fraction, no negative zero.
	public mutating func normalize() {

		guard error == nil else { return }

		integer = Self.trimZeros(integer)

		if let frc = fraction {
			/// Cut the trailing zeros
			let bytes = frc.utf8
			if let last = bytes.lastIndex(where: { $0 != 48 }) {
				let end = bytes.index(after: last)
				if end != bytes.endIndex { fraction = String(frc[..<end]) }
			} else {
				fraction = nil
			}
		}

		if fraction == nil, integer == "0" { negative = false }
	}


	/// The number as an integer digit string multiplied by 10^scale, without sign.
	/// The scale must be at least the count of the fraction digits.
	func scaled(to scale: Int) -> String {

		let frc = fraction ?? ""
		let padding = scale - frc.utf8.count

		var whole = integer == "0" ? frc : integer + frc
		if padding > 0 { whole += String(repeating: "0", count: padding) }

		return Self.trimZeros(whole)
	}


	/// Builds a number from an integer digit string divided by 10^scale
	static func fromScaled(_ magnitude: String, scale: Int, negative: Bool) -> Arbit {

		var result: Arbit

		if scale <= 0 {
			result = Arbit(raw: magnitude, negative: negative)
		} else {
			var digits = magnitude
			let count = digits.utf8.count
			if count <= scale {
				digits = String(repeating: "0", count: scale - count + 1) + digits
			}
			let cut = digits.utf8.index(digits.utf8.endIndex, offsetBy: -scale)
			result = Arbit(raw: String(digits[..<cut]), String(digits[cut...]), negative: negative)
		}

		result.normalize()
		return result
	}


	/// Removes the leading zeros of a digit string, "0" at least
	static func trimZeros(_ digits: String) -> String {

		let bytes = digits.utf8

		guard bytes.first == 48 else { return digits.isEmpty ? "0" : digits }

		guard let first = bytes.firstIndex(where: { $0 != 48 }) else { return "0" }

		return String(digits[first...])
	}

	/// The count of the fraction digits
	var scale: Int { fraction?.utf8.count ?? 0 }

}



// MARK: Computed varriables
extension Arbit: CustomStringConvertible, CustomDebugStringConvertible {

	public var description: String {

		if let error {
			switch error {
				case .nan: return "nan"
				case .infinity: return negative ? "-inf" : "inf"
				case .empty: return "empty"
			}
		}
		return "\(sign)\(absolute)"
	}

	public var debugDescription: String {
		return description
//		return "\(description) (\(integer.count),\(fraction?.count ?? 0):\(count))"
	}

	public var absolute: String {
		if let fraction { return "\(integer).\(fraction)" }
		return "\(integer)"
	}

	public var whole: String {
		if let fraction {
			let int = (integer == "0") ? "" : integer
			return "\(int)\(fraction)"
		}
		return integer
	}

	// MARK: Convert to...

	public var asDouble: Double? {

		if let error {
			if error == .infinity { return negative ? -Double.infinity : Double.infinity }
			return Double.nan
		}
		return Double("\(sign)\(integer).\(fraction ?? "0")")
	}

	/// The integer part, if it fits into Int
	public var asInt: Int? {
		guard error == nil, integer.utf8.count <= 19 else { return nil }
		return Int("\(sign)\(integer)")
	}

	public var asDecimal: Decimal? {
		guard error == nil else { return nil }
		return Decimal(string: description, locale: Locale(identifier: "en_US_POSIX"))
	}

}



// MARK: Integer
extension Arbit: ExpressibleByIntegerLiteral {

	public typealias IntegerLiteralType = Int


	public init(integerLiteral value: Int) {
		self.integer = String(value.magnitude)
		self.negative = value < 0
	}

	public init(_ value: UInt) {
		self.integer = String(value)
		self.negative = false
	}

	public init(_ value: Int, error: Errors? = nil) {

		self.init(integerLiteral: value)
		self.error = error
	}

	public init(_ value: Int8) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt8) { self.init(integerLiteral: Int(value)) }
	public init(_ value: Int16) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt16) { self.init(integerLiteral: Int(value)) }
	public init(_ value: Int32) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt32) { self.init(integerLiteral: Int(value)) }
	public init(_ value: Int64) { self.init(integerLiteral: Int(value)) }
	public init(_ value: UInt64) { self.init(UInt(value)) }

}



// MARK: Float
extension Arbit: ExpressibleByFloatLiteral {

	public typealias FloatLiteralType = Double

	/// The exact binary value of the floating point number, in full length:
	/// `0.1` becomes `0.1000000000000000055511151231257827021181583404541015625`.
	/// Use a string literal (`"0.1"`) for an exact decimal value.
	public init(floatLiteral value: Double) {

		guard !value.isNaN else {
			self.init(error: .nan)
			return
		}

		guard !value.isInfinite else {
			self.init(negative: value.sign == .minus, error: .infinity)
			return
		}

		guard !value.isZero else {
			self.init()
			return
		}

		/// value = mantissa × 2^exponent, with integer mantissa
		var mantissa: UInt64
		var exponent: Int

		if value.isSubnormal {
			mantissa = value.significandBitPattern
			exponent = -1074
		} else {
			mantissa = value.significandBitPattern | (1 << 52)
			exponent = Int(value.exponent) - 52
		}

		while mantissa & 1 == 0, exponent < 0 {
			mantissa >>= 1
			exponent += 1
		}

		let negative = value.sign == .minus
		let digits = String(mantissa)

		if exponent >= 0 {
			let magnitude = Self.magMul(digits, Self.magPow("2", exponent))
			self = Self.fromScaled(magnitude, scale: 0, negative: negative)
		} else {
			/// 2^-k = 5^k / 10^k
			let magnitude = Self.magMul(digits, Self.magPow("5", -exponent))
			self = Self.fromScaled(magnitude, scale: -exponent, negative: negative)
		}
	}

	public init(_ value: Double) { self.init(floatLiteral: value) }

	public init(_ value: Float) { self.init(floatLiteral: Double(value)) }

}



// MARK: String
extension Arbit: ExpressibleByStringLiteral, LosslessStringConvertible {

	public typealias StringLiteralType = String


	/// Forgiving init for literals: a valid number is parsed as is,
	/// otherwise the `0b` `0o` `0x` prefixes are handled, and at last every unknown character is dropped.
	public init(stringLiteral value: String) {

		if let parsed = Arbit(value) {
			self = parsed
			return
		}

		let body = value.hasPrefix("-") ? String(value.dropFirst()) : value

		if body.count > 2 {
			switch body.prefix(2).lowercased() {
				case "0b": self.init(bin: value) ; return
				case "0o": self.init(oct: value) ; return
				case "0x": self.init(hex: value) ; return
				default: break
			}
		}

		self.init(dec: value)
	}


	/// Strict init: `nil` for anything that is not a number.
	///
	/// Accepted: optional sign, digits with an optional decimal point (`"12"`, `"-1.5"`, `".5"`, `"5."`),
	/// optional exponent (`"1.5e-10"`), and `"nan"`, `"inf"`, `"-inf"`.
	public init?(_ description: String) {

		switch description.lowercased() {
			case "nan": self.init(error: .nan) ; return
			case "empty": self.init(error: .empty) ; return
			case "inf", "+inf", "infinity", "+infinity": self.init(error: .infinity) ; return
			case "-inf", "-infinity": self.init(negative: true, error: .infinity) ; return
			default: break
		}

		var text = Substring(description)
		var negative = false

		if text.first == "-" { negative = true ; text = text.dropFirst() }
		else if text.first == "+" { text = text.dropFirst() }

		var exponent = 0

		if let eIndex = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
			guard let exp = Int(text[text.index(after: eIndex)...]), abs(exp) <= 1_000_000 else { return nil }
			exponent = exp
			text = text[..<eIndex]
		}

		let parts = text.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
		let intPart = parts.first ?? ""
		let frcPart = parts.count == 2 ? parts[1] : ""

		func isDigits(_ string: Substring) -> Bool { string.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }

		guard !(intPart.isEmpty && frcPart.isEmpty), isDigits(intPart), isDigits(frcPart) else { return nil }

		self.init(raw: intPart.isEmpty ? "0" : String(intPart),
					 frcPart.isEmpty ? nil : String(frcPart),
					 negative: negative)

		if exponent != 0 { self.shift(decimals: exponent) }

		self.normalize()
	}


	/// Init with a number system: 2, 8, 10 or 16. `nil` for invalid digits or unknown radix.
	public init?(_ text: String, radix: Int) {

		if radix == 10 {
			guard let parsed = Arbit(text) else { return nil }
			self = parsed
			return
		}

		guard let (magnitude, negative) = Self.parse(text, radix: radix) else { return nil }

		self = Self.fromScaled(magnitude, scale: 0, negative: negative)
	}


	/// Forgiving decimal init: every character except digits, the first decimal point and a leading minus is dropped.
	/// A string without any digit gives the `empty` error value.
	public init(dec: String) {

		let filtered = dec.filter { "0123456789.-".contains($0) }
		let negative = filtered.hasPrefix("-")
		let body = filtered.filter { $0 != "-" }

		guard body.contains(where: { $0 != "." }) else {
			self.init(raw: "", negative: false, error: .empty)
			return
		}

		let parts = body.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
		let intPart = String(parts[0])
		let frcPart = parts.count == 2 ? parts[1].filter { $0 != "." } : ""

		self.init(raw: intPart, frcPart.isEmpty ? nil : frcPart, negative: negative)
		self.normalize()
	}


	/// Binary init, with optional sign and `0b` prefix. Invalid digits give `nan`.
	public init(bin: String) { self.init(digits: bin, radix: 2) }

	/// Octal init, with optional sign and `0o` prefix. Invalid digits give `nan`.
	public init(oct: String) { self.init(digits: oct, radix: 8) }

	/// Hexadecimal init, with optional sign and `0x` prefix. Invalid digits give `nan`.
	public init(hex: String) { self.init(digits: hex, radix: 16) }


	private init(digits: String, radix: Int) {

		guard let (magnitude, negative) = Self.parse(digits, radix: radix) else {
			self.init(error: .nan)
			return
		}
		self = Self.fromScaled(magnitude, scale: 0, negative: negative)
	}


	/// Parses a binary, octal or hexadecimal integer to a decimal digit string
	private static func parse(_ text: String, radix: Int) -> (magnitude: String, negative: Bool)? {

		let prefix: String
		let bitsPerDigit: Int

		switch radix {
			case  2: prefix = "0b" ; bitsPerDigit = 1
			case  8: prefix = "0o" ; bitsPerDigit = 3
			case 16: prefix = "0x" ; bitsPerDigit = 4
			default: return nil
		}

		var body = Substring(text)
		var negative = false

		if body.first == "-" { negative = true ; body = body.dropFirst() }
		else if body.first == "+" { body = body.dropFirst() }

		if body.lowercased().hasPrefix(prefix) { body = body.dropFirst(2) }

		guard !body.isEmpty else { return nil }

		var bits = ""

		for chr in body {
			guard let value = chr.hexDigitValue, value < radix else { return nil }
			let bin = String(value, radix: 2)
			bits += String(repeating: "0", count: bitsPerDigit - bin.count) + bin
		}

		return (bits.binToDec(), negative)
	}

}

// TODO: stride szélső esetek – vigyázni kell, később foglalkozni vele !
//
// A `stride(from:to:by:)` a Swift standard könyvtáráé, két esetben nem tudunk beleszólni:
//  - `nan` kezdő- vagy végpont: a sorozat SOHA nem ér véget (minden összehasonlítás hamis)
//  - nulla lépésköz: a program megáll ("Stride size must not be zero")
// A `Double` ugyanígy viselkedik. Megoldás lehet egy saját `Arbit.stride(...)`,
// ami ilyenkor hibát dob vagy üres sorozatot ad. Az `inf` végpont szándékosan végtelen sorozat.
//
extension Arbit: Strideable {

	public typealias Stride = Arbit

	public func distance(to other: Arbit) -> Arbit { other - self }

	public func advanced(by n: Arbit) -> Arbit { self + n }
}



// MARK: #FA0123
extension Arbit: Hashable {

	/// Equal numbers have equal hashes, as long as they are normalized (everything except `init(raw:)` is)
	public func hash(into hasher: inout Hasher) {
		hasher.combine(negative)
		hasher.combine(integer)
		hasher.combine(fraction ?? "")
		hasher.combine(error)
	}
}



// MARK: >=
extension Arbit: Comparable {

	/// Like the floating point types: `nan` is not equal to anything, not even to itself.
	public static func == (lhs: Arbit, rhs: Arbit) -> Bool {

		guard lhs.error == nil, rhs.error == nil else {
			if lhs.isInfinite, rhs.isInfinite { return lhs.negative == rhs.negative }
			return false
		}

		return lhs.negative == rhs.negative
			&& lhs.integer == rhs.integer
			&& (lhs.fraction ?? "") == (rhs.fraction ?? "")
	}

	public static func < (lhs: Arbit, rhs: Arbit) -> Bool {

		guard lhs.error == nil, rhs.error == nil else {

			if lhs.isNaN || rhs.isNaN { return false }

			/// At least one of them is infinity
			let left  = lhs.isInfinite ? (lhs.negative ? -1 : 1) : 0
			let right = rhs.isInfinite ? (rhs.negative ? -1 : 1) : 0
			return left < right
		}

		if lhs.negative != rhs.negative { return lhs.negative } // - < +

		let order = compareMagnitude(lhs, rhs)

		return lhs.negative ? order > 0 : order < 0
	}

	public static func > (lhs: Arbit, rhs: Arbit) -> Bool { return rhs < lhs }

	public static func <= (lhs: Arbit, rhs: Arbit) -> Bool { return lhs == rhs || lhs < rhs }

	public static func >= (lhs: Arbit, rhs: Arbit) -> Bool { return lhs == rhs || lhs > rhs }


	/// Compares the absolute values: -1 if lhs is smaller, 0 if equal, 1 if lhs is bigger
	static func compareMagnitude(_ lhs: Arbit, _ rhs: Arbit) -> Int {

		let order = magCompare(lhs.integer, rhs.integer)
		if order != 0 { return order }

		/// The fraction digits are left aligned, so the plain string order is the numeric order: "5" > "25", "2" < "25"
		let (left, right) = (lhs.fraction ?? "", rhs.fraction ?? "")

		if left == right { return 0 }
		return left < right ? -1 : 1
	}


	/// Compares two integer digit strings without leading zeros
	static func magCompare(_ lhs: String, _ rhs: String) -> Int {

		let (lCount, rCount) = (lhs.utf8.count, rhs.utf8.count)

		if lCount != rCount { return lCount < rCount ? -1 : 1 }
		if lhs == rhs { return 0 }
		return lhs < rhs ? -1 : 1
	}

}



// MARK: Subscript
extension Arbit {

	/// The digit at the index, counted through the integer and the fraction digits
	public subscript(_ index: Int) -> Character {

		get {
			let whole = self.integer + (self.fraction ?? "")
			precondition(index >= 0 && index < whole.count, "Arbit digit index \(index) is out of range 0..<\(whole.count)")
			let i = whole.index(whole.startIndex, offsetBy: index)
			return whole[i]
		}

		set(chr) {

			if index < self.integer.count {
				let i = self.integer.index(self.integer.startIndex, offsetBy: index)
				self.integer = self.integer.replacingCharacters(in: i...i, with: String(chr) )
			}

			else if self.fraction != nil, index - self.integer.count < self.fraction!.count {
				let i = self.fraction!.index(self.fraction!.startIndex, offsetBy: index - self.integer.count)
				self.fraction = self.fraction!.replacingCharacters(in: i...i, with: String(chr) )
			}
		}
	}

}



// MARK: Formated
extension Arbit {

	public func formatted(groupingSize: Int = 3,
								 groupingSeparator: String = Self.groupSep,
								 decimalSeparator: String = Self.decSep) -> String {

		if error != nil { return description }

		let int = sign + integer.getFormated(groupingSize: groupingSize, groupingSeparator: groupingSeparator)

		if let fraction {
			return int + decimalSeparator + fraction
		}

		return int
	}


	public func limited(_ limit: Int = 8, decimalSeparator: String = Self.decSep) -> String {

		if error != nil { return description }

		let int = sign + Self.getLimited(integer, limit: limit)

		guard let fraction else { return int }
		return int + decimalSeparator + Self.getLimited(fraction, limit: limit)

	}


	private static func getLimited(_ number: String, limit: Int) -> String {

		guard number.count > limit, limit > 0 else { return number }

		let (q, r) = limit.quotientAndRemainder(dividingBy: 2)
		let left =  number.startIndex...number.index(number.startIndex, offsetBy: q + r - 1)
		let right = number.index(number.endIndex, offsetBy: -q)..<number.endIndex

		return String(number[left]) + "_(\(number.count - limit))_" + String(number[right])
	}


	public func getSientific() -> (numbers: String, e: Int) {

		var first: String
		var after: String
		var n: Int

		if self.integer.count == 1 {

			first = integer

			if let fraction {

				var decimals = fraction.drop(while: { $0 == "0" })

				if first == "0", !decimals.isEmpty {
					first = String(decimals.removeFirst())
				}

				n = -(abs(fraction.count - decimals.count))
				after = if decimals.isEmpty { "" } else { "." + decimals }

			} else {
				after = ""
				n = 0
			}

		} else {

			first = String(integer.first ?? "0")
			after = "." + String(integer.dropFirst())

			if let fraction { after += fraction }
			n = integer.count - 1
		}


		return (numbers: sign + first + after, e: n)
	}


	/// Scientific notation: one digit before the decimal point and the power of ten, like `1.2345e4` or `-1.23e-3`.
	/// The significant digits can be limited (rounded by the mode). The result can be parsed back by `Arbit(String)`.
	public func scientific(significant: Int? = nil, rounding: RoundingMode = .truncate) -> String {

		guard error == nil else { return description }
		guard !isZero else { return "0e0" }

		/// The exponent of the first significant digit
		var exponent: Int

		if integer != "0" {
			exponent = integer.count - 1
		} else {
			exponent = -((fraction ?? "").prefix(while: { $0 == "0" }).count + 1)
		}

		var mantissa = self.magnitude
		mantissa.shift(decimals: -exponent)

		if let significant, significant > 0 {
			mantissa = mantissa.rounded(Context(digits: significant - 1, rounding: rounding))

			if mantissa.integer.count > 1 { // 9.99 → 10.0
				mantissa.shift(decimals: -1)
				exponent += 1
			}
		}

		return "\(sign)\(mantissa.absolute)e\(exponent)"
	}
}



// MARK: Codable
///
/// Coded as a single string, the same as the `description`: "-12.5", "nan", "inf"
///
extension Arbit: Codable {

	public init(from decoder: Decoder) throws {

		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)

		guard let value = Arbit(string) else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "'\(string)' is not an Arbit number")
		}
		self = value
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(description)
	}
}
