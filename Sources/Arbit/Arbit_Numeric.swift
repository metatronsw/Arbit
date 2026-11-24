import Foundation

// MARK: Numeric (+) (-) (*) (/)

extension Arbit: SignedNumeric {

	static let sliceLen = 18
	static let bigString = "1" + String(repeating: "0", count: sliceLen)
	static let bigInt = Int(bigString)!

	public typealias Magnitude = Arbit

	public var magnitude: Arbit {
		var abs = self
		abs.negative = false
		return abs
	}

	public mutating func negate() {

		if isNaN || isZero { return } // No negative zero, no negative nan

		self.negative.toggle()
	}

	/// -1, 0 or 1 by the sign, `nan` for `nan`
	public func signum() -> Arbit {

		if isNaN { return .nan }
		if isZero { return .zero }

		return negative ? Arbit(raw: "1", negative: true) : .one
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
		let scale = Swift.max(lhs.scale, rhs.scale)
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

	/// The sum of two digit strings, digit by digit. The result is as long as the longer one, the overflow is in the carry.
	public static func adding(lhs: String, rhs: String, carry: Int = 0) -> (sum: String, carry: Int) {

		let left = Array(lhs.utf8)
		let right = Array(rhs.utf8)
		let count = Swift.max(left.count, right.count)

		guard count > 0 else { return (String(carry), 0) }

		var sum = [UInt8](repeating: 48, count: count)
		var carry = UInt8(truncatingIfNeeded: carry)
		var (l, r) = (left.count - 1, right.count - 1)

		for i in stride(from: count - 1, through: 0, by: -1) {

			var digit = carry
			if l >= 0 { digit += left[l] &- 48 ; l -= 1 }
			if r >= 0 { digit += right[r] &- 48 ; r -= 1 }

			if digit >= 10 { digit -= 10 ; carry = 1 }
			else           { carry = 0 }

			sum[i] = 48 + digit
		}

		return (String(decoding: sum, as: UTF8.self), Int(carry))
	}

	/// The absolute difference of two integer digit strings without leading zeros.
	/// `negative` is true if the right side is the bigger one.
	public static func subtraction(lhs: String, rhs: String, carry: Int = 0) -> (sum: String, negative: Bool) {

		let order = magCompare(lhs, rhs)

		guard order != 0 else { return ("0", false) }

		let big = Array((order > 0 ? lhs : rhs).utf8)
		let small = Array((order > 0 ? rhs : lhs).utf8)

		var difference = [UInt8](repeating: 48, count: big.count)
		var borrow = Int8(truncatingIfNeeded: carry)
		var s = small.count - 1

		for i in stride(from: big.count - 1, through: 0, by: -1) {

			var digit = Int8(big[i] &- 48) - borrow
			if s >= 0 { digit -= Int8(small[s] &- 48) ; s -= 1 }

			if digit < 0 { digit += 10 ; borrow = 1 }
			else         { borrow = 0 }

			difference[i] = 48 + UInt8(digit)
		}

		return (trimZeros(String(decoding: difference, as: UTF8.self)), order < 0)
	}

}

// MARK: Multiply ( * )

extension Arbit {

	public static func * (lhs: Arbit, rhs: Arbit) -> Arbit {

		if let error = errorOfProduct(lhs, rhs) { return error }

		guard !lhs.isZero && !rhs.isZero else { return Arbit.zero }

		/// Both sides as integers, the decimal point is placed back at the end
		let lScale = lhs.scale
		let rScale = rhs.scale

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

	/// Long multiplication of two integer digit strings, calculated in 9 digit slices
	static func multiply(string lhs: String, by rhs: String) -> String {

		let left = chunks(lhs)
		let right = chunks(rhs)
		var result = [UInt64](repeating: 0, count: left.count + right.count)

		for l in left.indices where left[l] != 0 {

			var carry: UInt64 = 0

			for r in right.indices {
				let part = result[l + r] + left[l] * right[r] + carry
				result[l + r] = part % chunkBase
				carry = part / chunkBase
			}

			result[l + right.count] += carry
		}

		return string(fromChunks: result)
	}

	// MARK: Slices
	///
	/// The long multiplication and division cut the digit strings to 9 digit slices,
	/// so the product of two slices fits into UInt64. The least significant slice is the first.

	static let chunkLen = 9
	static let chunkBase: UInt64 = 1_000_000_000

	static func chunks(_ digits: String) -> [UInt64] {

		let bytes = Array(digits.utf8)
		var result = [UInt64]()
		result.reserveCapacity(bytes.count / chunkLen + 1)

		var end = bytes.count

		while end > 0 {
			let start = Swift.max(0, end - chunkLen)
			var value: UInt64 = 0
			for i in start..<end { value = value * 10 + UInt64(bytes[i] &- 48) }
			result.append(value)
			end = start
		}

		return result.isEmpty ? [0] : result
	}

	static func string(fromChunks chunks: [UInt64]) -> String {

		var top = chunks.count - 1
		while top > 0, chunks[top] == 0 { top -= 1 }

		guard top >= 0 else { return "0" }

		var bytes = Array(String(chunks[top]).utf8)
		bytes.reserveCapacity(bytes.count + top * chunkLen)

		var slice = [UInt8](repeating: 48, count: chunkLen)

		for i in stride(from: top - 1, through: 0, by: -1) {
			var value = chunks[i]
			for k in stride(from: chunkLen - 1, through: 0, by: -1) {
				slice[k] = 48 + UInt8(value % 10)
				value /= 10
			}
			bytes += slice
		}

		return String(decoding: bytes, as: UTF8.self)
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

	/// Division with the standard context: 16 fraction digits, truncated. Division by zero is `nan`.
	/// For other precision use `divided(by:_:)`.
	public static func / (lhs: Arbit, rhs: Arbit) -> Arbit { lhs.divided(by: rhs) }

	/// Division with the fraction digits and the rounding of the context. Division by zero is `nan`.
	public func divided(by rhs: Arbit, _ context: Context = .standard) -> Arbit {

		if let error = Self.errorOfQuotient(self, rhs) { return error }

		guard !self.isZero else { return Arbit.zero }

		let digits = Swift.max(0, context.digits)
		let lScale = self.scale
		let rScale = rhs.scale

		/// (L / 10^l) / (R / 10^r) × 10^(digits+1) = L × 10^(digits + 1 + r - l) / R
		/// One more digit is calculated for the rounding
		var dividend = self.scaled(to: lScale)
		var divisor = rhs.scaled(to: rScale)
		let shift = digits + 1 + rScale - lScale

		if shift >= 0 { dividend += String(repeating: "0", count: shift) }
		else          { divisor  += String(repeating: "0", count: -shift) }

		let (quotient, remainder) = Self.magDivMod(dividend, divisor)
		let rounded = Self.applyRounding(quotient, exact: remainder == "0", mode: context.rounding)

		return Self.fromScaled(rounded, scale: digits, negative: self.negative != rhs.negative)
	}

	public static func /= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs / rhs }

	/// Truncating division: the quotient is an integer rounded toward zero,
	/// the remainder has the sign of the dividend, like at `Int`. Works with fractions too: `7.5 / 2` is `3` and `1.5`.
	/// Division by zero or an error value gives `nan` for both.
	public func quotientAndRemainder(dividingBy div: Arbit) -> (quotient: Arbit, remainder: Arbit) {

		guard self.error == nil, div.error == nil, !div.isZero else { return (.nan, .nan) }

		let scale = Swift.max(self.scale, div.scale)

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

		/// Long divisor: written division on 9 digit slices
		///
		let (quotient, remainder) = divide(chunks: chunks(lhs), by: chunks(rhs))

		return (string(fromChunks: quotient), string(fromChunks: remainder))
	}

	/// Written long division of slices (Knuth: The Art of Computer Programming, 4.3.1 D).
	/// The quotient slice is estimated from the two leading slices, the estimation is at most two bigger.
	/// The divisor must have at least two slices and its last slice must not be zero.
	private static func divide(chunks dividend: [UInt64], by divisor: [UInt64]) -> (quotient: [UInt64], remainder: [UInt64]) {

		let base = chunkBase
		let n = divisor.count
		let m = dividend.count - n

		guard m >= 0 else { return ([0], dividend) }

		/// Scale both, so the leading slice of the divisor is at least the half of the base
		let scale = base / (divisor[n - 1] + 1)

		func multiplied(_ slices: [UInt64], by factor: UInt64) -> [UInt64] {
			var result = [UInt64]()
			result.reserveCapacity(slices.count + 1)
			var carry: UInt64 = 0
			for slice in slices {
				let part = slice * factor + carry
				result.append(part % base)
				carry = part / base
			}
			result.append(carry)
			return result
		}

		var rem = multiplied(dividend, by: scale) // one slice longer
		let div = Array(multiplied(divisor, by: scale).prefix(n))
		var quotient = [UInt64](repeating: 0, count: m + 1)

		for j in stride(from: m, through: 0, by: -1) {

			/// Estimate
			let leading = rem[j + n] * base + rem[j + n - 1]
			var estimate = leading / div[n - 1]
			var rest = leading % div[n - 1]

			while estimate >= base || estimate * div[n - 2] > rest * base + rem[j + n - 2] {
				estimate -= 1
				rest += div[n - 1]
				if rest >= base { break }
			}

			/// Multiply and subtract
			var carry: UInt64 = 0
			var borrow: Int64 = 0

			for i in 0..<n {
				let part = estimate * div[i] + carry
				carry = part / base
				let difference = Int64(rem[i + j]) - Int64(part % base) - borrow
				if difference < 0 { rem[i + j] = UInt64(difference + Int64(base)) ; borrow = 1 }
				else              { rem[i + j] = UInt64(difference) ; borrow = 0 }
			}

			let difference = Int64(rem[j + n]) - Int64(carry) - borrow

			if difference < 0 {
				/// The estimation was one too big: add back
				rem[j + n] = UInt64(difference + Int64(base))
				estimate -= 1

				var carry: UInt64 = 0
				for i in 0..<n {
					let sum = rem[i + j] + div[i] + carry
					rem[i + j] = sum % base
					carry = sum / base
				}
				rem[j + n] = (rem[j + n] + carry) % base
			} else {
				rem[j + n] = UInt64(difference)
			}

			quotient[j] = estimate
		}

		/// Scale back the remainder
		var remainder = [UInt64](repeating: 0, count: n)
		var carry: UInt64 = 0

		for i in stride(from: n - 1, through: 0, by: -1) {
			let part = carry * base + rem[i]
			remainder[i] = part / scale
			carry = part % scale
		}

		return (quotient, remainder)
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
	static func applyRounding(_ digits: String, exact: Bool, mode: RoundingMode) -> String {

		let bytes = digits.utf8

		guard let last = bytes.last else { return "0" }

		let guardDigit = Int(last) - 48
		var body = String(digits[..<bytes.index(before: bytes.endIndex)])
		if body.isEmpty { body = "0" }

		let roundUp: Bool

		switch mode {
			case .truncate:
				roundUp = false

			case .halfUp:
				roundUp = guardDigit >= 5

			case .halfEven:
				if guardDigit != 5 || !exact { roundUp = guardDigit >= 5 }
				else { roundUp = (Int(body.utf8.last ?? 48) - 48) % 2 == 1 } // Exactly half: to the even one
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
