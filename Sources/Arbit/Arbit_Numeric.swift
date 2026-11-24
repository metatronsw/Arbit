import Foundation

// MARK: Numeric (+) (-) (*) (/)

extension Arbit: SignedNumeric {

	static let sliceLen = 18
	static let bigString = "1" + String(repeating: "0", count: sliceLen)
	static let bigInt = Int(bigString)!

	public mutating func negate() {

		if isNaN || isZero { return } // No negative zero, no negative nan

		self.negative.toggle()
	}

}

// MARK: Error values
///
/// The error values spread like at the floating point types:
/// `nan` with anything is `nan`, infinity keeps itself, except the undefined cases (`inf - inf`, `inf * 0`, `inf / inf`).
///
extension Arbit {

	/// The error result of an addition, nil if both sides are valid numbers
	static func errorOfSum(_ lhs: Arbit, _ rhs: Arbit) -> Arbit? {

		guard lhs.error != nil || rhs.error != nil else { return nil }

		if lhs.isNaN || rhs.isNaN { return .nan }

		if lhs.isInfinite, rhs.isInfinite {
			return lhs.negative == rhs.negative ? lhs : .nan // inf - inf
		}

		return lhs.isInfinite ? lhs : rhs
	}

	/// The error result of a multiplication, nil if both sides are valid numbers
	static func errorOfProduct(_ lhs: Arbit, _ rhs: Arbit) -> Arbit? {

		guard lhs.error != nil || rhs.error != nil else { return nil }

		if lhs.isNaN || rhs.isNaN { return .nan }
		if lhs.isZero || rhs.isZero { return .nan } // inf * 0

		return Arbit(negative: lhs.negative != rhs.negative, error: .infinity)
	}

	/// The error result of a division, nil if both sides are valid numbers and the divisor is not zero
	static func errorOfQuotient(_ lhs: Arbit, _ rhs: Arbit) -> Arbit? {

		if lhs.isNaN || rhs.isNaN { return .nan }
		if rhs.isZero { return .nan } // x / 0

		guard lhs.error != nil || rhs.error != nil else { return nil }

		if lhs.isInfinite, rhs.isInfinite { return .nan } // inf / inf
		if rhs.isInfinite { return .zero } // x / inf

		return Arbit(negative: lhs.negative != rhs.negative, error: .infinity)
	}

}

// MARK: Addition & Subtraction ( + - )

extension Arbit {

	public static func + (lhs: Arbit, rhs: Arbit) -> Arbit {

		if let error = errorOfSum(lhs, rhs) { return error }

		/// Try simple basic integer sum
		///
		if lhs.fraction == nil, rhs.fraction == nil,
			let left = lhs.asInt, let right = rhs.asInt {
			let (result, over) = left.addingReportingOverflow(right)
			if !over { return Arbit(result) }
		}

		/// Long sum: both sides as integers on the same decimal scale, the sign is decided here only
		///
		let scale = Swift.max(lhs.fraction?.count ?? 0, rhs.fraction?.count ?? 0)
		let left = lhs.scaled(to: scale)
		let right = rhs.scaled(to: scale)

		if lhs.negative == rhs.negative {
			return fromScaled(magAdd(left, right), scale: scale, negative: lhs.negative)
		}

		/// Different signs: the bigger absolute value gives the sign
		let (difference, rightIsBigger) = subtraction(lhs: left, rhs: right)

		return fromScaled(difference, scale: scale, negative: rightIsBigger ? rhs.negative : lhs.negative)
	}

	public static func += (lhs: inout Arbit, rhs: Arbit) { lhs = lhs + rhs }

	public static func - (lhs: Arbit, rhs: Arbit) -> Arbit { lhs + (-rhs) }

	public static func -= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs + (-rhs) }

	/// String

	/// Sum of two integer digit strings without leading zeros
	static func magAdd(_ lhs: String, _ rhs: String) -> String {

		var (sum, carry) = adding(lhs: lhs, rhs: rhs)
		if carry == 1 { sum = "1" + sum }

		return trimZeros(sum)
	}

	public static func adding(lhs: String, rhs: String, carry: Int = 0) -> (sum: String, carry: Int) {
		var left = Substring(lhs)
		var right = Substring(rhs)

		var (lInt, rInt): (Int, Int)
		var notEmpty = true
		var carry = carry
		var sum = ""

		repeat {
			lInt = Int(left.suffix(sliceLen)) ?? 0
			left = left.dropLast(sliceLen)

			rInt = Int(right.suffix(sliceLen)) ?? 0
			right = right.dropLast(sliceLen)

			notEmpty = !(left.isEmpty && right.isEmpty)

			var add = String(lInt + rInt + carry)
			carry = 0

			if add.count < sliceLen, notEmpty {
				add = String(repeating: "0", count: sliceLen - add.count) + add
			}

			else if add.count > sliceLen {
				add = String(add.dropFirst())
				carry = 1
			}

			sum = add + sum

		} while notEmpty // TODO: Kilépni ha egyik oldal elfogyott ?

		return (sum, carry)
	}

	/// The absolute difference of two integer digit strings without leading zeros.
	/// `negative` is true if the right side is the bigger one.
	public static func subtraction(lhs: String, rhs: String, carry: Int = 0) -> (sum: String, negative: Bool) {
		var negative: Bool

		if lhs.count > rhs.count { negative = false }
		else if lhs.count < rhs.count { negative = true }
		else {
			if lhs > rhs { negative = false }
			else if lhs < rhs { negative = true }
			else { return ("0", false) }
		}

		var left = Substring(lhs)
		var right = Substring(rhs)

		var (lInt, rInt, xInt): (Int, Int, Int)
		var subs = [Int]()
		var carry = carry

		repeat {
			lInt = Int(left.suffix(sliceLen)) ?? 0
			left = left.dropLast(sliceLen)

			rInt = Int(right.suffix(sliceLen)) ?? 0
			right = right.dropLast(sliceLen)

			if negative { xInt = rInt - lInt - carry }
			else { xInt = lInt - rInt - carry }

			if xInt < 0 { xInt += bigInt; carry = 1 }
			else { carry = 0 }

			subs.append(xInt)

		} while !(left.isEmpty && right.isEmpty)

		var sum = ""

		while subs.last == 0 { subs.removeLast() } /// Zero trim

		if subs.count > 0 {
			sum.append(String(subs.removeLast())) /// First without zeros

			for i in stride(from: subs.count - 1, to: -1, by: -1) { /// Zero fill
				var part = String(subs[i])
				if part.count < sliceLen {
					part = String(repeating: "0", count: sliceLen - part.count) + part
				}
				sum.append(part)
			}
		} else {
			sum = "0"
		}

		return (sum, negative)
	}

}

// MARK: Multiply ( * )

extension Arbit {

	public static func * (lhs: Arbit, rhs: Arbit) -> Arbit {

		if let error = errorOfProduct(lhs, rhs) { return error }

		guard !lhs.isZero && !rhs.isZero else { return Arbit.zero }

		/// Both sides as integers, the decimal point is placed back at the end
		let lScale = lhs.fraction?.count ?? 0
		let rScale = rhs.fraction?.count ?? 0

		let product = magMul(lhs.scaled(to: lScale), rhs.scaled(to: rScale))

		return fromScaled(product, scale: lScale + rScale, negative: lhs.negative != rhs.negative)
	}

	public static func *= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs * rhs }

	/// Product of two integer digit strings
	static func magMul(_ lhs: String, _ rhs: String) -> String {
		/// Try basic mul, if fall, jump to long multiplication.
		///
		if let lInt = Int(lhs),
			let rInt = Int(rhs) {
			let (result, overflow) = lInt.multipliedReportingOverflow(by: rInt)
			if !overflow { return String(result) }
		}

		return trimZeros(multiply(string: lhs, by: rhs))
	}

	/// Integer power of an integer digit string, by squaring
	static func magPow(_ base: String, _ exponent: Int) -> String {

		var result = "1"
		var base = base
		var exp = exponent

		while exp > 0 {
			if exp & 1 == 1 { result = magMul(result, base) }
			exp >>= 1
			if exp > 0 { base = magMul(base, base) }
		}

		return result
	}

	static func multiply(string lhs: String, by rhs: String) -> String {
		let left = lhs.reversed().map { UInt8(String($0))! }
		let right = rhs.map { UInt8(String($0))! }
		var prev = Array(repeating: 0 as UInt8, count: left.count)
		var act = [UInt8]()

		var carry: UInt8 = 0
		var part: UInt8 = 0
		var c = 0
		var r = 0

		let limit: UInt8 = 10

		repeat {
			repeat {
				part = left[c] * right[r] + carry + prev[c]
				carry = 0

				if part >= limit { (carry, part) = part.quotientAndRemainder(dividingBy: limit) }
				act.append(part)
				part = 0

				c += 1

			} while c < left.count /// Left

			while c < prev.count {
				part = prev[c] + carry
				carry = 0

				if part >= limit { (carry, part) = part.quotientAndRemainder(dividingBy: limit) }

				act.append(part)
				c += 1
			}

			if carry != 0 { act.append(carry); carry = 0 }

			prev = [0] + act
			act = []
			c = 0
			r += 1

		} while r < right.count /// Right

		prev.removeFirst()

		let string = prev
			.reversed()
			.map { String($0) }
			.joined(separator: "")

		return string
	}

	/// Karatsuba multiplication of integers. Fractions and short numbers go to the basic multiplication.
	public static func karatsuba(_ num1: Arbit, _ num2: Arbit) -> Arbit {

		guard !num1.isError, !num2.isError, !num1.isDecimal, !num2.isDecimal else { return num1 * num2 }

		let product = karatsubaMagnitude(num1.magnitude, num2.magnitude)

		return Arbit(product, negative: !product.isZero && num1.negative != num2.negative)
	}

	private static func karatsubaMagnitude(_ num1: Arbit, _ num2: Arbit) -> Arbit {

		let (n1Count, n2Count) = (num1.count, num2.count)

		guard n1Count > 1 && n2Count > 1 else { return num1 * num2 }

		let n = Swift.max(n1Count, n2Count)
		let nBy2 = n / 2
		let nBy2Pow = Arbit(nBy2).pow10()

		let (a, b) = num1.quotientAndRemainder(dividingBy: nBy2Pow)
		let (c, d) = num2.quotientAndRemainder(dividingBy: nBy2Pow)

		let ac = karatsubaMagnitude(a, c)
		let bd = karatsubaMagnitude(b, d)
		let adPlusbc = karatsubaMagnitude(a + b, c + d) - ac - bd

		let nBy2mul2pow = Arbit(2 * nBy2).pow10()
		let product = ac * nBy2mul2pow + adPlusbc * nBy2Pow + bd

		return product
	}

}

// MARK: Division ( / )

extension Arbit {

	/// Division with `Arbit.precision` fraction digits, the last digit is handled by `Arbit.rounding`.
	/// Division by zero is `nan`.
	public static func / (lhs: Arbit, rhs: Arbit) -> Arbit {

		if let error = errorOfQuotient(lhs, rhs) { return error }

		guard !lhs.isZero else { return Arbit.zero }

		let scale = Swift.max(lhs.fraction?.count ?? 0, rhs.fraction?.count ?? 0)
		let digits = Swift.max(0, precision)

		/// One more digit is calculated for the rounding
		let dividend = lhs.scaled(to: scale) + String(repeating: "0", count: digits + 1)
		let divisor = rhs.scaled(to: scale)

		let (quotient, remainder) = magDivMod(dividend, divisor)
		let rounded = applyRounding(quotient, exact: remainder == "0")

		return fromScaled(rounded, scale: digits, negative: lhs.negative != rhs.negative)
	}

	public static func /= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs / rhs }

	/// Truncating division: the quotient is an integer rounded toward zero,
	/// the remainder has the sign of the dividend, like at `Int`. Works with fractions too: `7.5 / 2` is `3` and `1.5`.
	/// Division by zero or an error value gives `nan` for both.
	public func quotientAndRemainder(dividingBy div: Arbit) -> (quotient: Arbit, remainder: Arbit) {

		guard self.error == nil, div.error == nil, !div.isZero else { return (.nan, .nan) }

		let scale = Swift.max(self.fraction?.count ?? 0, div.fraction?.count ?? 0)

		let (quotient, remainder) = Self.magDivMod(self.scaled(to: scale), div.scaled(to: scale))

		return (Self.fromScaled(quotient, scale: 0, negative: self.negative != div.negative),
				  Self.fromScaled(remainder, scale: scale, negative: self.negative))
	}


	/// Written long division of two integer digit strings without leading zeros. The divisor must not be zero.
	static func magDivMod(_ lhs: String, _ rhs: String) -> (quotient: String, remainder: String) {

		if magCompare(lhs, rhs) < 0 { return ("0", lhs) }

		/// Short divisor: the steps fit into Int
		///
		if let divisor = Int(rhs), divisor < Int.max / 10 {

			if let dividend = Int(lhs) {
				let (quotient, remainder) = dividend.quotientAndRemainder(dividingBy: divisor)
				return (String(quotient), String(remainder))
			}

			let (quotient, remainder) = quoAndRem(string: lhs, by: divisor)
			return (quotient, String(remainder))
		}

		/// Long divisor: the digits of the dividend are taken down one by one,
		/// the quotient digit is the biggest multiple of the divisor that fits into the partial remainder.
		///
		var multiples = ["0", rhs]
		for i in 2...9 { multiples.append(magAdd(multiples[i-1], rhs)) }

		var quotient = ""
		var remainder = "0"

		for digit in lhs {

			if remainder == "0" { remainder = String(digit) }
			else { remainder.append(digit) }

			var times = 0

			if magCompare(remainder, rhs) >= 0 {
				times = 9
				while magCompare(multiples[times], remainder) > 0 { times -= 1 }
				remainder = subtraction(lhs: remainder, rhs: multiples[times]).sum
			}

			quotient.append(Character(String(times)))
		}

		return (trimZeros(quotient), remainder)
	}

	/// Long division of an integer digit string by an Int
	public static func quoAndRem(string lhs: String, by rhs: Int) -> (quotient: String, remainder: Int) {

		/// The partial remainder × 10 must fit into Int
		guard rhs < Int.max / 10 else {
			let (quotient, remainder) = magDivMod(trimZeros(lhs), String(rhs))
			return (quotient, Int(remainder)!)
		}

		var quotient = [UInt8]()
		var remainder = 0

		for digit in lhs.utf8 {
			let part = remainder * 10 + Int(digit) - 48
			quotient.append(UInt8(48 + part / rhs))
			remainder = part % rhs
		}

		return (trimZeros(String(decoding: quotient, as: UTF8.self)), remainder)
	}


	/// Drops the last (guard) digit of an integer digit string, and rounds the rest by the rounding mode.
	/// `exact` tells that there is nothing after the guard digit.
	static func applyRounding(_ digits: String, exact: Bool, mode: RoundingMode = Arbit.rounding) -> String {

		let guardDigit = digits.last?.wholeNumberValue ?? 0
		var body = String(digits.dropLast())
		if body.isEmpty { body = "0" }

		let roundUp: Bool

		switch mode {
			case .truncate:
				roundUp = false

			case .halfUp:
				roundUp = guardDigit >= 5

			case .halfEven:
				if guardDigit != 5 || !exact { roundUp = guardDigit >= 5 }
				else { roundUp = (body.last?.wholeNumberValue ?? 0) % 2 == 1 } // Exactly half: to the even one
		}

		return roundUp ? magAdd(body, "1") : body
	}

}

// MARK: Necessary Functions

extension Arbit {

	@inline(__always)
	static func equalize(lhs: String, rhs: String) -> (lhs: String, rhs: String) {
		if lhs.count < rhs.count {
			return (lhs + String(repeating: "0", count: rhs.count - lhs.count), rhs)
		}

		else if lhs.count > rhs.count {
			return (lhs, rhs + String(repeating: "0", count: lhs.count - rhs.count))
		}

		else {
			return (lhs, rhs)
		}
	}

	static func div10(_ input: String, exp: Int) -> (int: String, frc: String?) {
		var whole = input
		var int: String
		var frc: String?

		frc = String(whole.suffix(exp))
		whole.removeLast(Swift.min(whole.count, exp))

		if whole.isEmpty {
			int = "0"
			frc = String(repeating: "0", count: abs(input.count - exp)) + input
		} else {
			int = whole
		}

		frc.cleanToNil()

		return (int, frc)
	}

	public static func shifter(_ input: String, decimals: Int) -> (int: String, frc: String?) {
		guard decimals != 0 else { return (int: input, frc: nil) }

		if decimals > 0 { // Mul: input * 10^d

			return (int: input + String(repeating: "0", count: decimals), frc: nil)

		} else { // Div: input * 10^-d

			return div10(input, exp: abs(decimals))
		}
	}

}
