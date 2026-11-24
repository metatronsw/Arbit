import Foundation



// MARK: Math functions

precedencegroup ExponentiationPrecedence {
	associativity: right
	higherThan: MultiplicationPrecedence
}

infix operator ** : ExponentiationPrecedence
infix operator **= : AssignmentPrecedence

extension Arbit {
	
	
	/// Multiplies by 10^by: moves the decimal point to the right
	public mutating func raise(by: Int) {
		shift(decimals: by)
	}
	
	
	/// Cuts the fraction to the given count of digits, without rounding
	public mutating func clamp(fraction digits: Int = Context.standard.digits) {
		
		guard let frc = self.fraction else { return }
		
		guard digits > 0 else {
			self.fraction = nil
			normalize()
			return
		}
		
		let bytes = frc.utf8
		
		guard bytes.count > digits else { return }
		
		self.fraction = String(frc[..<bytes.index(bytes.startIndex, offsetBy: digits)])
		normalize()
	}
	
	
	/// Rounds the fraction to the digits of the context, by its rounding mode
	public func rounded(_ context: Context = .standard) -> Arbit {
		
		let digits = context.digits
		
		guard error == nil, let fraction, digits >= 0, fraction.utf8.count > digits else { return self }
		
		/// Keep one more digit for the rounding
		let count = fraction.utf8.count
		let dropped = count - digits - 1
		let whole = scaled(to: count)
		let bytes = whole.utf8
		
		var kept = "0"
		if bytes.count > dropped {
			kept = String(whole[..<bytes.index(bytes.endIndex, offsetBy: -dropped)])
		}
		
		let rounded = Self.applyRounding(kept, exact: dropped == 0, mode: context.rounding)
		
		return Self.fromScaled(rounded, scale: digits, negative: negative)
	}
	
	
	/// The integer part: rounded toward zero
	public func truncated() -> Arbit {
		
		guard error == nil, fraction != nil else { return self }
		
		var result = Arbit(raw: integer, negative: negative)
		result.normalize()
		return result
	}
	
	/// The biggest integer that is not bigger than self: rounded toward negative infinity
	public func floor() -> Arbit {
		
		guard error == nil, fraction != nil else { return self }
		
		return negative ? truncated() - 1 : truncated()
	}
	
	/// The smallest integer that is not smaller than self: rounded toward positive infinity
	public func ceil() -> Arbit {
		
		guard error == nil, fraction != nil else { return self }
		
		return negative ? truncated() : truncated() + 1
	}
	
	
	
	// MARK: Power
	
	/// Power with any exponent.
	///
	/// - integer exponent: exact, by squaring (a negative one is a division by the context)
	/// - `1/n` exponent (`0.5`, `0.25`, `0.2` ...): the n-th root
	/// - other fraction: `exp(n × ln(self))`, for a positive base only
	///
	/// A negative base with a fraction exponent is `nan`.
	public func power( _ n: Arbit, _ context: Context = .standard ) -> Arbit {
		
		guard self.error == nil, n.error == nil else { return .nan }
		
		if !n.isDecimal {
			guard let exponent = n.asInt else { return .nan }
			return power(exponent, context)
		}
		
		/// Is it 1/n ?
		let (degree, remainder) = Arbit.one.quotientAndRemainder(dividingBy: n.magnitude)
		
		if remainder.isZero, let degree = degree.asInt {
			return root(n.negative ? -degree : degree, context)
		}
		
		if self.isZero { return n.negative ? .nan : .zero }
		
		guard !self.negative else { return .nan }
		
		/// The logarithm needs as many more digits, as long the result and the exponent are
		let digits = Swift.max(0, context.digits)
		let size = n.integer.count + n.integer.count * self.integer.count
		let logarithm = self.ln(.digits(digits + size + 10))
		
		return (n * logarithm).exp(.digits(digits + 6)).finished(context)
	}
	
	/// Power with an integer exponent, by squaring. A negative exponent is a division by the context.
	public func power( _ exponent: Int, _ context: Context = .standard ) -> Arbit {
		
		guard self.error == nil else { return .nan }
		
		var result = Arbit.one
		var base = self
		var exp = exponent.magnitude
		
		while exp > 0 {
			if exp & 1 == 1 { result *= base }
			exp >>= 1
			if exp > 0 { base *= base }
		}
		
		return exponent < 0 ? Arbit.one.divided(by: result, context) : result
	}
	
	/// Power with the standard context. It binds stronger than the multiplication, and from the right: `2 ** 3 ** 2 == 512`.
	/// The prefix minus is stronger: `-x ** 2` is `(-x) ** 2`.
	public static func ** (lhs: Arbit, rhs: Arbit) -> Arbit { lhs.power(rhs) }
	
	public static func ** (lhs: Arbit, rhs: Int) -> Arbit { lhs.power(rhs) }
	
	public static func **= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs.power(rhs) }
	
	
	
	// MARK: Roots
	
	/// Square root of self with the fraction digits of the context, calculated digit by digit.
	/// Exact for square numbers. A negative number gives `nan`.
	public func sqrRoot(_ context: Context = .standard) -> Arbit {
		
		if let error { return (error == .infinity && !negative) ? self : .nan }
		
		guard !self.negative else { return .nan }
		guard !self.isZero else { return .zero }
		
		/// √(whole / 10^scale) × 10^count = √(whole × 10^(2×count - scale)), one more digit for the rounding
		let count = Swift.max(0, context.digits) + 1
		let scale = self.scale
		let shift = 2 * count - scale
		
		var whole = scaled(to: scale)
		var exact = true
		
		if shift >= 0 {
			whole += String(repeating: "0", count: shift)
		} else {
			whole = String(whole.dropLast(-shift))
			if whole.isEmpty { whole = "0" }
			exact = false
		}
		
		let (root, remainder) = Self.magSqrt(whole)
		let rounded = Self.applyRounding(root, exact: exact && remainder == "0", mode: context.rounding)
		
		return Self.fromScaled(rounded, scale: count - 1, negative: false)
	}
	
	
	/// The n-th root of self with the fraction digits of the context.
	/// Even root of a negative number is `nan`, negative degree is the reciprocal of the root.
	public func root(_ degree: Int, _ context: Context = .standard) -> Arbit {
		
		guard error == nil, degree != 0 else { return .nan }
		
		if degree < 0 {
			let root = self.root(-degree, .digits(Swift.max(0, context.digits) + self.integer.count + 5))
			return Arbit.one.divided(by: root, context)
		}
		
		if degree == 1 { return self }
		if degree == 2 { return sqrRoot(context) }
		
		if negative, degree % 2 == 0 { return .nan }
		
		guard !isZero else { return .zero }
		
		/// ⁿ√(whole / 10^scale) × 10^count = ⁿ√(whole × 10^(n×count - scale)), one more digit for the rounding
		let count = Swift.max(0, context.digits) + 1
		let scale = self.scale
		let shift = degree * count - scale
		
		var whole = scaled(to: scale)
		var exact = true
		
		if shift >= 0 {
			whole += String(repeating: "0", count: shift)
		} else {
			whole = String(whole.dropLast(-shift))
			if whole.isEmpty { whole = "0" }
			exact = false
		}
		
		let root = Self.magRoot(whole, degree)
		
		if exact, context.rounding == .halfEven { exact = Self.magPow(root, degree) == whole }
		
		let rounded = Self.applyRounding(root, exact: exact, mode: context.rounding)
		
		return Self.fromScaled(rounded, scale: count - 1, negative: negative)
	}
	
	
	/// Integer square root of a digit string, with the written method:
	/// https://hu.wikipedia.org/wiki/Írásbeli_gyökvonás
	///
	/// The digits are taken down in pairs. In every step the next digit of the root is the biggest x,
	/// where (20 × root + x) × x fits into the remainder. The x is guessed from the leading digits, then checked.
	static func magSqrt(_ number: String) -> (root: String, remainder: String) {
		
		var digits = Array(number.utf8).map { $0 &- 48 }
		if digits.count % 2 == 1 { digits.insert(0, at: 0) }
		
		var root = [UInt8]()       // the digits of the root, without leading zero
		var remainder = [UInt8]()  // the digits of the remainder, without leading zero
		
		/// (the digits followed by `digit`) × `digit`
		func product(_ doubled: [UInt8], _ digit: UInt8) -> [UInt8] {
			var result = [UInt8](repeating: 0, count: doubled.count + 2)
			var carry = digit * digit
			result[doubled.count + 1] = carry % 10
			carry /= 10
			for i in stride(from: doubled.count - 1, through: 0, by: -1) {
				let part = doubled[i] * digit + carry
				result[i + 1] = part % 10
				carry = part / 10
			}
			result[0] = carry
			let zeros = result.prefix(while: { $0 == 0 }).count
			return zeros == 0 ? result : Array(result.dropFirst(zeros))
		}
		
		func compare(_ lhs: [UInt8], _ rhs: [UInt8]) -> Int {
			if lhs.count != rhs.count { return lhs.count < rhs.count ? -1 : 1 }
			for i in lhs.indices where lhs[i] != rhs[i] { return lhs[i] < rhs[i] ? -1 : 1 }
			return 0
		}
		
		/// The leading digits as a floating point number, and the count of the left out digits
		func leading(_ digits: [UInt8]) -> (value: Double, rest: Int) {
			var value = 0.0
			let count = Swift.min(digits.count, 16)
			for i in 0..<count { value = value * 10 + Double(digits[i]) }
			return (value, digits.count - count)
		}
		
		for i in stride(from: 0, to: digits.count, by: 2) {
			
			/// Take down the next two digits
			if !remainder.isEmpty || digits[i] != 0 { remainder.append(digits[i]) }
			if !remainder.isEmpty || digits[i+1] != 0 { remainder.append(digits[i+1]) }
			
			/// 2 × root
			var doubled = [UInt8](repeating: 0, count: root.count + 1)
			var carry: UInt8 = 0
			for k in stride(from: root.count - 1, through: 0, by: -1) {
				let part = root[k] * 2 + carry
				doubled[k + 1] = part % 10
				carry = part / 10
			}
			doubled[0] = carry
			if doubled.first == 0 { doubled.removeFirst() }
			
			/// Guess: remainder / (20 × root)
			var digit: UInt8 = 9
			
			if !doubled.isEmpty {
				let (top, topRest) = leading(remainder)
				let (bottom, bottomRest) = leading(doubled)
				let guess = top / bottom * Foundation.pow(10, Double(topRest - bottomRest - 1))
				digit = UInt8(Swift.max(0, Swift.min(9, guess.rounded(.down))))
			}
			
			/// Check: down while it is too big, then up while the next one fits too
			var candidate = digit == 0 ? [] : product(doubled, digit)
			
			while digit > 0, compare(candidate, remainder) > 0 {
				digit -= 1
				candidate = digit == 0 ? [] : product(doubled, digit)
			}
			
			while digit < 9 {
				let next = product(doubled, digit + 1)
				if compare(next, remainder) > 0 { break }
				digit += 1
				candidate = next
			}
			
			/// remainder -= candidate
			if digit > 0 {
				var borrow: Int8 = 0
				var c = candidate.count - 1
				for k in stride(from: remainder.count - 1, through: 0, by: -1) {
					var part = Int8(remainder[k]) - borrow
					if c >= 0 { part -= Int8(candidate[c]) ; c -= 1 }
					if part < 0 { part += 10 ; borrow = 1 } else { borrow = 0 }
					remainder[k] = UInt8(part)
				}
				let zeros = remainder.prefix(while: { $0 == 0 }).count
				if zeros > 0 { remainder.removeFirst(zeros) }
			}
			
			if !root.isEmpty || digit != 0 { root.append(digit) }
		}
		
		func string(_ digits: [UInt8]) -> String {
			digits.isEmpty ? "0" : String(decoding: digits.map { $0 + 48 }, as: UTF8.self)
		}
		
		return (string(root), string(remainder))
	}
	
	
	/// Integer n-th root of a digit string (rounded down), with Newton iteration
	static func magRoot(_ number: String, _ degree: Int) -> String {
		
		guard number != "0" else { return "0" }
		
		let degreeString = String(degree)
		let degreeLess = String(degree - 1)
		
		/// The start must not be smaller than the root, from there the steps go down to it
		var root = rootEstimate(number, degree)
		
		while true {
			let (quotient, _) = magDivMod(number, magPow(root, degree - 1))
			let (next, _) = magDivMod(magAdd(magMul(degreeLess, root), quotient), degreeString)
			
			if magCompare(next, root) >= 0 { break }
			root = next
		}
		
		return root
	}
	
	/// A close upper estimate of the n-th root, from the leading digits
	private static func rootEstimate(_ number: String, _ degree: Int) -> String {
		
		let length = number.count
		let lead = Double(number.prefix(15)) ?? 1
		
		let log = (Foundation.log10(lead) + Double(length - Swift.min(length, 15))) / Double(degree)
		let exponent = Int(log.rounded(.down))
		let mantissa = Foundation.pow(10, log - Double(exponent)) // 1 ..< 10
		
		/// 12 digits, rounded up
		let head = Int((mantissa * 1e11).rounded(.up)) + 2
		
		if exponent >= 11 { return String(head) + String(repeating: "0", count: exponent - 11) }
		
		let small = Int((Double(head) / Foundation.pow(10, Double(11 - exponent))).rounded(.up)) + 1
		
		return String(small)
	}
	
	

	
	// MARK: Number theory
	
	/// The product of the integers from 1 to self. Only for not negative integers, else `nan`.
	public func factorial() -> Arbit {
		
		guard isInteger, !negative, let count = asInt else { return .nan }
		
		var product = "1"
		
		if count > 1 {
			for i in 2...count { product = Self.magMul(product, String(i)) }
		}
		
		return Arbit(raw: product)
	}
	
	/// Greatest common divisor of two integers, never negative. A fraction gives `nan`.
	public static func gcd(_ lhs: Arbit, _ rhs: Arbit) -> Arbit {
		
		guard lhs.isInteger, rhs.isInteger else { return .nan }
		
		var (a, b) = (lhs.magnitude, rhs.magnitude)
		
		while !b.isZero { (a, b) = (b, a % b) }
		
		return a
	}
	
	/// Least common multiple of two integers, never negative. A fraction gives `nan`.
	public static func lcm(_ lhs: Arbit, _ rhs: Arbit) -> Arbit {
		
		guard lhs.isInteger, rhs.isInteger else { return .nan }
		guard !lhs.isZero, !rhs.isZero else { return .zero }
		
		let product = (lhs * rhs).magnitude
		
		return product.quotientAndRemainder(dividingBy: gcd(lhs, rhs)).quotient
	}
	
	
	/// The repeated sum of every digit (the fraction digits too), until one digit remains
	public func digitalRoot() -> Arbit {
		
		guard error == nil else { return .nan }
		
		// Count sum of digits under mod 9
		var sum = 0
		for digit in (integer + (fraction ?? "")).utf8 {
			sum = (sum + Int(digit) - 48) % 9
		}
		
		// If digit sum is multiple of 9, 9, else remainder with 9.
		if isZero { return .zero }
		return Arbit(sum == 0 ? 9 : sum)
	}
	
	
	/// Geometric avarage: the n-th root of the product of n numbers
	public static func geoMean(_ array: [Arbit], _ context: Context = .standard) -> Arbit {
		
		guard let first = array.first else { return zero }
		
		let product = array.dropFirst().reduce(first, *)
		
		return product.root(array.count, context)
	}
	
}



// MARK: Global math functions

public func sqrt(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.sqrRoot(context) }

public func pow(_ lhs: Arbit, _ rhs: Arbit, _ context: Arbit.Context = .standard) -> Arbit { lhs.power(rhs, context) }

public func floor(_ value: Arbit) -> Arbit { value.floor() }

public func ceil(_ value: Arbit) -> Arbit { value.ceil() }

