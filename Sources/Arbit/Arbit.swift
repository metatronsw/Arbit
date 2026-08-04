import Foundation

/// Lossless, arbitrary precision number structure supporting decimal fractions
///
public struct Arbit {
	
	public var integer: String
	public var fraction: String?
	public var negative: Bool
	public var error: Errors?
	
	
	
	// TODO: DidSet
	public static var precision = 16 { // TODO: ellenőrizni ..
		didSet { precisionZeros = String(repeating: "0", count: precision) }
	}
	public static var precisionZeros = String(repeating: "0", count: precision)
	
	
	public static var decSep = Locale.current.decimalSeparator ?? "."
	public static var groupSep = Locale.current.groupingSeparator ?? "\u{2008}"
	
	
	
	
	// MARK: Init
	
	/// Copy: Init from self & override
	public init(_ arbit: Arbit, negative: Bool? = nil, error: Errors? = nil) {
		self.integer = arbit.integer
		self.fraction = arbit.fraction
		
		self.negative = negative ?? arbit.negative
		self.error = error ?? arbit.error
	}
	
	/// Fast raw init from string parts, use with care
	public init(raw intPart: String = "0", _ frcPart: String? = nil, negative: Bool = false, error: Errors? = nil) {
		self.integer = intPart
		self.fraction = frcPart
		self.negative = negative
		self.error = error
	}
	
	
	
	
	// MARK: Computed
	
	public var count: Int { integer.count + (fraction?.count ?? 0) }
	
	public var isZero: Bool { integer == "0" && (fraction == nil || fraction?.isEmpty == true) }
	
	public var isEmpty: Bool { integer == "" || error == .empty }
	
	public var isBignum: Bool { integer.count + (fraction?.count ?? 0) >= Self.sliceLen }
	
	public var isError: Bool { error != nil }
	
}



// MARK: Errors & static values
extension Arbit {

	/// Arbit error cases
	public enum Errors: CustomStringConvertible, Comparable {
		
		case empty
		case infinity
		case nan
		case calcError(String) // FIXME: csak Debughoz ! !
		
		
		public var description: String {
			switch self {
				case .empty: "Not initialised!"
				case .infinity: "Infinity number!"
				case .nan: "Not a number!"
				case let .calcError(error): "≠ \(error)"
			}
		}
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
	
	
	
	public func errorHandle(_ error: Errors) -> String {
		
		if case let .calcError(e) = error { return "ERROR ≠ \nArbit  : \(self.whole) \nDecimal: \(e)"}
		else { return error.description }
	}
	
}



// MARK: Computed varriables
extension Arbit: CustomStringConvertible, CustomDebugStringConvertible {
	
	public var description: String {
		if let error { return errorHandle(error) }
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
	
	public var asDouble: Double? { Double("\(sign)\(integer).\(fraction ?? "0")") }
	
	public var asInt: Int? { Int("\(sign)\(integer)") }
	
	public var asDecimal: Decimal? { Decimal.init(string: description) }
	
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
	
	public init(floatLiteral value: Double) {
		
		guard !value.isNaN, !value.isSignalingNaN else {
			self.init(negative: value.sign == .minus ? true : false, error: .nan)
			return
		}
		
		guard !value.isInfinite else {
			self.init(negative: value.sign == .minus ? true : false, error: .infinity)
			return
		}
		
		guard !value.isZero else {
			self.init()
			return
		}
		
		
		if value < Double(Int.max) && value > Double(Int.min) {
			
			self.init(stringLiteral: value.description )
			
		} else {
			
			let parts = value.magnitude.description.components(separatedBy: "e+")
			let num = parts.first!.replacingOccurrences(of: ".", with: "")
			let exp = Int(parts[1]) ?? 0
			
			let int = num + String(repeating: "0", count: exp - num.count + 1)
			
			self.init(raw: int, negative: (value.sign == .minus) ? true : false )
		}
		
	}
	
	public init(_ value: Double) { self.init(floatLiteral: value) }
	
	public init(_ value: Float) { self.init(floatLiteral: Double(value)) }
	
}



// MARK: String
extension Arbit: ExpressibleByStringLiteral, LosslessStringConvertible {
	
	public typealias StringLiteralType = String

	
	
	public init(stringLiteral value: String) {
		
		fix: if value.count > 2 {
				switch value.prefix(2) {
					case "0b": self.init(bin: value)
					case "0o": self.init(oct: value)
					case "0x": self.init(hex: value)
					default: break fix
				}
			return
		}
				
		let string = value.filter { "0123456789.-".contains($0) }
		self.init(dec: string)
	}
	
	
	public init?(_ raw: String, radix: Int = 10) {
		
		switch radix {
			case  2: self.init(bin: raw)
			case  8: self.init(oct: raw)
			case 10: self.init(dec: raw)
			case 16: self.init(hex: raw)
			default: return nil
		}
	}
	
	
	
	public init(_ description: String) { self.init(dec: description) }
	
	
	
	public init(dec: String) {
		
		var string = dec
		
		if string.hasPrefix("-") { self.negative = true ; string.removeFirst() }
		else                     { self.negative = false }
		
		guard !string.isEmpty else {
			self.error = .empty
			self.integer = ""
			return
		}
		
		guard let frcPartIndex = string.firstIndex(of: ".") else {
			self.integer = string
			if self.integer == "0" { self.negative = false }
			return
		}
		
		
		self.integer  = String(string[string.startIndex ..< frcPartIndex])
		self.fraction = String(string[string.index(after: frcPartIndex) ..< string.endIndex])
		
		
		self.fraction.cleanToNil()
		
		if self.fraction == nil, self.integer == "0" {
			self.negative = false
		}
	}
	
	
	public init(bin: String) {
		
		var bin = bin
		var negative: Bool
		
		if bin.hasSuffix("-") {
			negative = true
			bin.removeFirst()
		} else {
			negative = false
		}
		
		let dec = bin.binToDec()
		
		self.init(raw: dec, negative: negative)
		
	}
	
	
	public init(oct: String) { fatalError() } // TODO: Implement...
	
	
	public init(hex: String) {
		
		var hex = hex
		var negative: Bool
		
		if hex.hasSuffix("-") {
			negative = true
			hex.removeFirst()
		} else {
			negative = false
		}
		
		let dec = hex.hexToDec()
		
		self.init(raw: dec, negative: negative)
		
	}
	
}

extension Arbit: UnsignedInteger {
	
	public typealias Magnitude = Arbit
	
	public var magnitude: Arbit {
		var abs = self
		abs.negative = false
		return abs
	}
	
}

// FIXME: NEM MŰKÖDIK A STRIDE !!!
extension Arbit: Strideable {

	public typealias Stride = Arbit
	
	public func distance(to other: Arbit) -> Arbit {
		let o = (other - self)
//		print("other", other, other - self, o)
		return o
	}
	
	public func advanced(by n: Arbit) -> Arbit {
//		print("advanced", n )
		return self + n
	}
}



// MARK: #FA0123
extension Arbit: Hashable {
	public func hash(into hasher: inout Hasher) { fatalError() }
}



// MARK: >=
extension Arbit: Comparable {
	
	public static func == (lhs: Arbit, rhs: Arbit) -> Bool { // TODO: Error == error ?
		
		guard lhs.error == nil, rhs.error == nil else { return false }
		
		guard lhs.negative == rhs.negative else { return false }
		
		guard lhs.isDecimal == rhs.isDecimal else { return false }
		guard lhs.integer == rhs.integer else { return false }
		
		if let lhsf = lhs.fraction, let rhfs = rhs.fraction {
			guard lhsf == rhfs else { return false }
		}
		
		return true
	}
	
	public static func <(lhs: Arbit, rhs: Arbit) -> Bool {
		
		/// Negative lhs case
		///
		if lhs.negative == true {
			if rhs.negative == false { return true } // - < +
			
			if lhs.integer.count > rhs.integer.count { return true } else if lhs.integer.count < rhs.integer.count { return false }
			
			if lhs.integer > rhs.integer { return true } else if lhs.integer < rhs.integer { return false }
			
			if lhs.fraction != nil {
				if rhs.fraction == nil { return true } //  -0.01 < 0
				
				if lhs.fraction! > rhs.fraction! { return true } // 001 < 0003
			}
		}
		
		/// Positive lhs case
		///
		if rhs.negative == true { return false } // + > -
		
		if lhs.integer < rhs.integer { return true } else if lhs.integer > rhs.integer { return false }
		
		if lhs.fraction != nil {
			if rhs.fraction == nil { return false } // 0.01 > 0
			
			if lhs.fraction! < rhs.fraction! { return true } // 001 < 0003
		}
		
		return true
	}
	
	public static func >(lhs: Arbit, rhs: Arbit) -> Bool { return rhs < lhs }
	
	public static func <=(lhs: Arbit, rhs: Arbit) -> Bool { return lhs == rhs || lhs < rhs }
	
	public static func >=(lhs: Arbit, rhs: Arbit) -> Bool { return lhs == rhs || lhs > rhs }
	
}



// MARK: Subscript
extension Arbit {
	
	public subscript(_ index: Int) -> Character {
		
		get {
			let whole = self.integer + (self.fraction ?? "")
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
		
		if let error { return errorHandle(error) }
		
		let int = sign + integer.getFormated(groupingSize: groupingSize, groupingSeparator: groupingSeparator)
		
		if let fraction {
			return int + decimalSeparator + fraction
		}
		
		return int
	}
	
	
	public func limited(_ limit: Int = 8) -> String {
		
		if let error { return errorHandle(error) }
		
		let int = sign + Self.getLimited(integer, limit: limit)
		
		guard let fraction else { return int }
		return int + Self.decSep + Self.getLimited(fraction, limit: limit)
		
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
}


