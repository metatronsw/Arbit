import Foundation



// MARK: Math functions

infix operator **
infix operator **=

extension Arbit {
	
	
	/// Multiplies by 10^by: moves the decimal point to the right
	public mutating func raise(by: Int) {
		shift(decimals: by)
	}
	
	
	/// Cuts the fraction to the given count of digits, without rounding
	public mutating func clamp(fraction digits: Int = Self.precision) {
		
		guard self.fraction != nil else { return }
		
		if digits > 0 { self.fraction = String(self.fraction!.prefix(digits)) }
		else          { self.fraction = nil }
		
		normalize()
	}
	
	
	/// Rounds the fraction to the given count of digits
	public func rounded(fraction digits: Int = Self.precision, mode: RoundingMode = Self.rounding) -> Arbit {
		
		guard error == nil, let fraction, digits >= 0, fraction.count > digits else { return self }
		
		/// Keep one more digit for the rounding
		let dropped = fraction.count - digits - 1
		let kept = String(scaled(to: fraction.count).dropLast(dropped))
		
		let rounded = Self.applyRounding(kept.isEmpty ? "0" : kept, exact: dropped == 0, mode: mode)
		
		return Self.fromScaled(rounded, scale: digits, negative: negative)
	}
	
	
	/// Power with an integer exponent, or with an `1/n` exponent (`0.5`, `0.25`, `0.2` ...) as the n-th root.
	/// Other fraction exponents are not supported: `nil`.
	/// Negative exponent is a division, calculated with `Arbit.precision` digits.
	public func power( _ n: Arbit ) -> Arbit? {
		
		guard self.error == nil, n.error == nil else { return .nan }
		
		if !n.isDecimal {
			guard let exponent = n.asInt else { return nil }
			return power(exponent)
		}
		
		/// Is it 1/n ?
		let (degree, remainder) = Arbit.one.quotientAndRemainder(dividingBy: n.magnitude)
		
		guard remainder.isZero, let degree = degree.asInt else { return nil }
		
		let root = self.root(degree)
		
		return n.negative ? Arbit.one / root : root
	}
	
	/// Power with an integer exponent, by squaring
	public func power( _ exponent: Int ) -> Arbit {
		
		guard self.error == nil else { return .nan }
		
		var result = Arbit.one
		var base = self
		var exp = exponent.magnitude
		
		while exp > 0 {
			if exp & 1 == 1 { result *= base }
			exp >>= 1
			if exp > 0 { base *= base }
		}
		
		return exponent < 0 ? Arbit.one / result : result
	}
	
//	public static func ** (lhs: Arbit, rhs: Arbit) -> Arbit { lhs.power(rhs) }
//	public static func **= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs.power(rhs) }
	
	
	/// Square root of self with the given count of fraction digits, calculated digit by digit.
	/// Exact for square numbers, the last digit is handled by `Arbit.rounding`. Negative number gives `nan`.
	public func sqrRoot(digits: Int = Self.precision) -> Arbit {
		
		if let error { return (error == .infinity && !negative) ? self : .nan }
		
		guard !self.negative else { return .nan }
		guard !self.isZero else { return .zero }
		
		/// √(whole / 10^scale) × 10^count = √(whole × 10^(2×count - scale)), one more digit for the rounding
		let count = Swift.max(0, digits) + 1
		let scale = fraction?.count ?? 0
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
		let rounded = Self.applyRounding(root, exact: exact && remainder == "0")
		
		return Self.fromScaled(rounded, scale: count - 1, negative: false)
	}
	
	
	/// The n-th root of self with the given count of fraction digits.
	/// Even root of a negative number is `nan`, negative degree is the reciprocal of the root.
	public func root(_ degree: Int, digits: Int = Self.precision) -> Arbit {
		
		guard error == nil, degree != 0 else { return .nan }
		
		if degree < 0 { return Arbit.one / root(-degree, digits: digits) }
		if degree == 1 { return self }
		if degree == 2 { return sqrRoot(digits: digits) }
		
		if negative, degree % 2 == 0 { return .nan }
		
		guard !isZero else { return .zero }
		
		/// ⁿ√(whole / 10^scale) × 10^count = ⁿ√(whole × 10^(n×count - scale)), one more digit for the rounding
		let count = Swift.max(0, digits) + 1
		let scale = fraction?.count ?? 0
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
		
		if exact, Self.rounding == .halfEven { exact = Self.magPow(root, degree) == whole }
		
		let rounded = Self.applyRounding(root, exact: exact)
		
		return Self.fromScaled(rounded, scale: count - 1, negative: negative)
	}
	
	
	/// Integer square root of a digit string, with the written method:
	/// https://hu.wikipedia.org/wiki/Írásbeli_gyökvonás
	static func magSqrt(_ number: String) -> (root: String, remainder: String) {
		
		let digits = Array(number.count % 2 == 1 ? "0" + number : number)
		
		var root = "0"
		var remainder = "0"
		
		for i in stride(from: 0, to: digits.count, by: 2) {
			
			/// Take down the next two digits
			remainder = trimZeros((remainder == "0" ? "" : remainder) + String(digits[i]) + String(digits[i+1]))
			
			/// Find the biggest digit x, where (20 × root + x) × x fits into the remainder
			let doubled = root == "0" ? "" : magAdd(root, root)
			var digit = 9
			var product = "0"
			
			while digit > 0 {
				product = magMul(doubled + String(digit), String(digit))
				if magCompare(product, remainder) <= 0 { break }
				digit -= 1
			}
			
			if digit > 0 { remainder = subtraction(lhs: remainder, rhs: product).sum }
			
			root = root == "0" ? String(digit) : root + String(digit)
		}
		
		return (root, remainder)
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
		
		let log = (log10(lead) + Double(length - Swift.min(length, 15))) / Double(degree)
		let exponent = Int(log.rounded(.down))
		let mantissa = pow(10, log - Double(exponent)) // 1 ..< 10
		
		/// 12 digits, rounded up
		let head = Int((mantissa * 1e11).rounded(.up)) + 2
		
		if exponent >= 11 { return String(head) + String(repeating: "0", count: exponent - 11) }
		
		let small = Int((Double(head) / pow(10, Double(11 - exponent))).rounded(.up)) + 1
		
		return String(small)
	}
	
	
	/// The sum of decimals
	public func digitalRoot() -> Arbit {
		
		return Arbit(digitalRoot(of: self.integer))
		
		func digitalRoot(of num: String) -> Int {
			
			guard num != "0" else { return 0 }
			
			// Count sum of digits under mod 9
			var ans = 0
			for char in num {
				guard let int = Int(String(char)) else { return 0 }
				ans = (ans + int) % 9
			}
			
			// If digit sum is multiple of 9, 9, else remainder with 9.
			return (ans == 0) ? 9 : ans % 9
		}
		
	}
	
	
	/// Geometric avarage: the n-th root of the product of n numbers
	public static func geoMean(_ array: [Arbit]) -> Arbit {
		
		guard let first = array.first else { return zero }
		
		let product = array.dropFirst().reduce(first, *)
		
		return product.root(array.count)
	}
	
}



// MARK: Global math functions

public func sqrt(_ value: Arbit) -> Arbit { value.sqrRoot() }

public func pow(_ lhs: Arbit, _ rhs: Arbit) -> Arbit? { lhs.power(rhs) }


