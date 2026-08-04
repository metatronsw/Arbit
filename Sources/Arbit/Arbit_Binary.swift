import Foundation

// MARK: Binary << & | ~ ^
extension Arbit: BinaryInteger {
	
	public typealias Words = [UInt]
	public var words: [UInt] {
		fatalError()
	}
	
	
	
	// MARK: Init
	
	public init?<T>(exactly source: T) where T : BinaryInteger {
		self.integer = String(source.magnitude)
		self.negative = source < 0
	}
	
	public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
		self.integer = String(source.magnitude)
		self.negative = source < 0
	}
	
	public init<T>(clamping source: T) where T : BinaryInteger {
		self.integer = String(source.magnitude)
		self.negative = source < 0
	}
	
	public init<T>(_ source: T) where T : BinaryInteger {
		self.integer = String(source.magnitude)
		self.negative = source < 0
	}
	
	
	public init?<T>(exactly source: T) where T : BinaryFloatingPoint {
		self.init(floatLiteral: Double(source))
	}
	
	public init<T>(_ source: T) where T : BinaryFloatingPoint {
		self.init(floatLiteral: Double(source))
	}
	
	
	
	// MARK: Arithmetic
	
	public static prefix func ~ (x: Arbit) -> Arbit {
		
		let bit = x.asBinary()
		
		let new = bit.map { b in
			return b == "1" ? "0" : "1"
		}
		
		return Arbit(raw: new.joined(), negative: x.negative )

	}
	
	
	public static func %  (lhs: Arbit, rhs: Arbit) -> Arbit {
		let (_ , rem) = lhs.quotientAndRemainder(dividingBy: rhs)
		return rem
	}
	
	public static func %= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs % rhs  }
	
	
	
	public static func &  (lhs: Arbit, rhs: Arbit) -> Arbit {
		
		func mask(_ l: Character, _ r: Character) -> Character {
			if l == "1" && r == "1" { return "1" }
			else                    { return "0" }
		}
		
		let lhsw = Array(lhs.asBinary().reversed())
		let rhsw = Array(rhs.asBinary().reversed())

		var (short, long) : ([ReversedCollection<String>.Element], [ReversedCollection<String>.Element])
		
		if      lhsw.count > rhsw.count { short = rhsw ; long = lhsw }
		else if lhsw.count < rhsw.count { short = lhsw ; long = rhsw }
		else                            { short = lhsw ; long = rhsw }
		
		var new = [Character]()
		
		for i in 0..<short.count {
			new.append( mask( short[i], long[i]) )
		}
		
		return Arbit(bin: String(new.reversed()) )
	}
	
	public static func &= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs & rhs }
	
	
	
	public static func |  (lhs: Arbit, rhs: Arbit) -> Arbit {
		
		func mask(_ l: Character, _ r: Character) -> Character {
			if l == "0" && r == "0" { return "0" }
			else                    { return "1" }
		}
		
		let lhsw = Array(lhs.asBinary().reversed())
		let rhsw = Array(rhs.asBinary().reversed())
		
		var (short, long) : ([ReversedCollection<String>.Element], [ReversedCollection<String>.Element])
		
		if      lhsw.count > rhsw.count { short = rhsw ; long = lhsw }
		else if lhsw.count < rhsw.count { short = lhsw ; long = rhsw }
		else                            { short = lhsw ; long = rhsw }
		
		var new = [Character]()
		
		for i in 0..<short.count {
			new.append( mask( short[i], long[i]) )
		}
		
		if short.count < long.count {
			for i in short.count..<long.count {
				new += String( long[i] )
			}
		}
		
		return Arbit(bin: String(new.reversed()) )
	}
	
	public static func |= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs | rhs }
	
	
	
	public static func ^= (lhs: inout Arbit, rhs: Arbit) { fatalError() }
	
	
	public static func <<= <RHS>(lhs: inout Arbit, rhs: RHS) where RHS : BinaryInteger { fatalError() }
	public static func >>= <RHS>(lhs: inout Arbit, rhs: RHS) where RHS : BinaryInteger { fatalError() }
	
	
	
	// MARK: Questions

	public static var isSigned: Bool { true }
	
	public var signumInt: Int { negative ? -1 : 1 }
	
	public var sign: String { negative ? "-" : "" }
	
	public var fullsign: String { negative ? "-" : "+" }
	
	public var isDecimal: Bool { fraction != nil }
	
	public var isNegative: Bool { negative }
	
	public var bitWidth: Int { self.integer.decToBin().count }
	
	public var trailingZeroBitCount: Int { fatalError() }
	
	public var oneBitCount: Int { fatalError() }
	
	// TODO: !!!
	//	public func isMultiple(of other: Self) { fatalError() }
	//	public func isOdd() -> Bool { (self % 2) == 0 }
	//	public func isEven() -> Bool { !isOdd() }
}




// MARK: Convert & Export
extension Arbit {
	
	public mutating func shift(decimals: Int) {
		
		guard decimals != 0, !isZero else { return }
		
		var int: Substring
		var frc: Substring?
		
		if decimals > 0 {
			
			int = fraction?.prefix(decimals) ?? ""
			if int.count < decimals { int += Substring(repeating: "0", count: decimals-int.count) }
			if integer == "0" { integer = "" }
			integer += String(int)
			
			frc = fraction?.dropFirst(decimals)
			fraction = String(frc ?? "")
			
		} else {
			
			let shift = abs(decimals)
			
			frc = integer.suffix(shift)
			if frc!.count < shift { frc = Substring(repeating: "0", count: shift) + frc! }
			
			fraction = String(frc!) + (fraction ?? "")
			
			fraction.cleanToNil()
			
			int = integer.dropLast(shift)
			if int.isEmpty { integer = "0" } else { integer = String(int) }
			
		}
		
		if fraction?.isEmpty == true { fraction = nil }
		
	}
	
	
	public func asBinary(withPrefix: Bool = false) -> String {
		
		guard !self.isEmpty else { return "0b?" }
		guard !self.isError else { return self.description }
		
		let bin = self.integer.decToBin()
		
		return self.sign + (withPrefix ? "0b" + bin : bin)
	}
	
	
	public func asHexadecimal(withPrefix: Bool = false) -> String {
		
		guard !self.isEmpty else { return "0x?" }
		guard !self.isError else { return self.description }
		
		let hex = self.integer.decToHex()
	
		return self.sign + (withPrefix ? "0x" + hex : hex)
	}
	
	
	public func asBinaryCodedDecimal(packed: Bool = true) -> [UInt8] {
		
		/// https://en.wikipedia.org/wiki/Double_dabble
		
		return self.integer
			.chunked(by: packed ? 2 : 1)
			.map { UInt8($0)! }
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
	
	public func hexToDec() -> String { fatalError() } // TODO: Implement
	
	public func hexToBin() -> String { fatalError() } // TODO: Implement
	
}

