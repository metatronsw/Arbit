import Foundation

// MARK: Numeric (+) (-) (*) (/)

extension Arbit: SignedNumeric {

	static let sliceLen = 18
	static let bigString = "1" + String(repeating: "0", count: sliceLen)
	static let bigInt = Int(bigString)!

	public mutating func negate() { self.negative.toggle() }

}

// MARK: Addition & Subtraction ( + - )

extension Arbit {

	public static func + (lhs: Arbit, rhs: Arbit) -> Arbit {
		/// Decimal fractional addition, if any has it
		///
		if lhs.isDecimal || rhs.isDecimal {
			if lhs.isNegative == rhs.isNegative { return frcAdd(lhs: lhs, rhs: rhs) }
			else { return frcSub(lhs: lhs, rhs: rhs) }
		}

		/// Try simple basic integer sum, if failure, do with longSum
		///
		return intSum(lhs: lhs, rhs: rhs)
	}

	public static func += (lhs: inout Arbit, rhs: Arbit) { lhs = lhs + rhs }

	public static func - (lhs: Arbit, rhs: Arbit) -> Arbit { lhs + (-rhs) }

	public static func -= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs + (-rhs) }

	/// String

	public static func adding(lhs: String, rhs: String, carry: Int = 0) -> (sum: String, carry: Int) {
		var left = Substring(lhs)
		var right = Substring(rhs)

		var (lInt, rInt): (Int, Int)
		var notEmpty = true
		var carry = carry
		var sum = ""

		#if DEBUG
			//		 print(lhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), left )
			//		 print(rhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), right)
		#endif

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

			#if DEBUG
				// print(lInt, "+", left.isEmpty ? "✓" : " ", rInt, right.isEmpty ? "✓" : " ", carry != 0 ? "±" : " " )
			#endif

		} while notEmpty // TODO: Kilépni ha egyik oldal elfogyott ?

		return (sum, carry)
	}

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

		#if DEBUG
			//		print("lhs:", lhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), "#", lhs.integer.count)
			//		print("rhs:", rhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), "#", rhs.integer.count)
		#endif

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

			#if DEBUG
				// print(lInt, left.isEmpty ? "✓" : " ", "- ", rInt, right.isEmpty ? "✓" : " ", dept != 0 ? "±" : " ", positive ? " " : "⊖", parts )
			#endif

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

	/// Integer

	public static func intSum(lhs: Arbit, rhs: Arbit) -> Arbit {
		/// Sort sum
		///
		if let left = lhs.asInt, let right = rhs.asInt {
			let (result, over) = left.addingReportingOverflow(right)
			if !over { return Arbit(result) }
		}

		/// Long sum
		///
		if lhs.isNegative == rhs.isNegative {
			var (int, carry) = adding(lhs: lhs.integer, rhs: rhs.integer)
			if carry == 1 { int = "1" + int }
			return Arbit(raw: int, negative: lhs.negative)
		}

		else {
			let (int, negative) = subtraction(lhs: lhs.integer, rhs: rhs.integer)
			return Arbit(raw: int, negative: negative)
		}
	}

	/// Fraction

	public static func frcAdd(lhs: Arbit, rhs: Arbit) -> Arbit {
		guard lhs.fraction != nil else { return frcQuickAdd(int: lhs, intWithFrc: rhs) }

		guard rhs.fraction != nil else { return frcQuickAdd(int: rhs, intWithFrc: lhs) }

		func frcQuickAdd(int: Arbit, intWithFrc: Arbit) -> Arbit {
			var sum = intSum(lhs: intWithFrc, rhs: int)
			sum.fraction = intWithFrc.fraction
			return sum
		}

		let (left, right) = equalize(lhs: lhs.fraction!, rhs: rhs.fraction!)

		var frc: String?
		var carry: Int = 0

		/// Basic fraction adding
		///
		if let lInt = UInt("1" + left),
			let rInt = UInt("1" + right) {
			frc = String(lInt + rInt)
		}

		/// Long fraction adding
		///
		else {
			(frc, carry) = adding(lhs: "1" + left, rhs: "1" + right)
		}

		let first = frc?.removeFirst()
		carry = (first == "3") ? 1 : 0
		frc.cleanToNil()

		/// Basic Int adding
		///
		if let left = lhs.asInt,
			let right = rhs.asInt {
			let (result, over1) = left.addingReportingOverflow(right)
			let (int, over2) = result.addingReportingOverflow(carry)

			if !(over1 && over2) {
				return Arbit(raw: String(int), frc, negative: lhs.negative)
			}
		}

		/// Long Int Adding
		///
		var (int, carry2) = adding(lhs: lhs.integer, rhs: rhs.integer, carry: carry)
		if carry2 == 1 { int = "1" + int }

		return Arbit(raw: int, frc, negative: lhs.negative)
	}

	public static func frcSub(lhs: Arbit, rhs: Arbit) -> Arbit {
		var int: String
		var frc: String?
		var sum: String
		var negative: Bool

		let (leftFrc, rightFrc) = equalize(lhs: lhs.fraction ?? "0", rhs: rhs.fraction ?? "0")

		let left = lhs.integer + leftFrc
		let right = rhs.integer + rightFrc

		//		print("(-)", lhs, rhs, "›\n", lhs.integer + leftFrc, left, "\n", rhs.integer + rightFrc, right)

		/// Basic fraction subtraction
		///
		if let lhsInt = Int(left),
			let rhsInt = Int(right) {
			sum = String(lhsInt - rhsInt)

			if sum.first == "-" {
				sum.removeFirst()
				negative = true
			} else {
				negative = false
			}
		}

		/// Long fraction subtraction
		///
		else {
			(sum, negative) = subtraction(lhs: left, rhs: right)
		}

		sum = sum.fillWithZeros(len: leftFrc.count)
		(int, frc) = split(sum, center: sum.count - leftFrc.count)

		int.cleanToZero()
		frc.cleanToNil()

		return Arbit(raw: int, frc, negative: negative)
	}

}

// MARK: Multiply ( * )

extension Arbit {

	public static func * (lhs: Arbit, rhs: Arbit) -> Arbit {
		guard !lhs.isZero && !rhs.isZero else { return Arbit.zero }

		var int: String
		var frc: String? = nil

		/// Fraction multiplication
		if lhs.isDecimal || rhs.isDecimal {
			let result = mulBasicOrLong(lhs: lhs.whole, rhs: rhs.whole)
			let shift = (lhs.fraction?.count ?? 0) + (rhs.fraction?.count ?? 0)

			(int, frc) = div10(result, exp: shift)
		}

		/// Basic integer multiplication
		else {
			int = mulBasicOrLong(lhs: lhs.integer, rhs: rhs.integer)
		}

		return Arbit(raw: int, frc, negative: getNegative(lhs: lhs, rhs: rhs))
	}

	public static func *= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs * rhs }

	static func mulBasicOrLong(lhs: String, rhs: String) -> String {
		/// Try basic mul, if fall, jump to long multiplication.
		///
		if let lInt = Int(lhs),
			let rInt = Int(rhs) {
			let (result, overflow) = lInt.multipliedReportingOverflow(by: rInt)
			if !overflow { return String(result) }
		}

		return multiply(string: lhs, by: rhs)
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
				// print("c\(c) \(left[c]) * \(right[r]) (\(left[c]*right[r])) + '\(carry) + [\(prev[c])]  = ", terminator: "")
				carry = 0

				if part >= limit { (carry, part) = part.quotientAndRemainder(dividingBy: limit) }
				// print("(\(carry))\(part)")
				act.append(part)
				part = 0

				c += 1

			} while c < left.count /// Left

			while c < prev.count {
				part = prev[c] + carry
				// print("c\(c)              '\(carry) + [\(prev[c])]  = ", terminator: "")
				carry = 0

				if part >= limit { (carry, part) = part.quotientAndRemainder(dividingBy: limit) }
				// print("(\(carry))\(part)")

				act.append(part)
				c += 1
			}

			if carry != 0 { act.append(carry); carry = 0 }
			// print(" ", act )

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

	public static func karatsuba(_ num1: Arbit, _ num2: Arbit) -> Arbit {
		// FIXME: fract kezelése . jobb lenne String bementetet használni ?

		let (n1Count, n2Count) = (num1.count, num2.count)

		guard n1Count > 1 && n2Count > 1 else {
			return Arbit(num1.asInt! * num2.asInt!)
		}

		let n = Swift.max(n1Count, n2Count)
		let nBy2 = n / 2
		let nBy2Pow = Arbit(nBy2).pow10()

		let (a, b) = num1.quotientAndRemainder(dividingBy: nBy2Pow)
		let (c, d) = num2.quotientAndRemainder(dividingBy: nBy2Pow)

		let ac = karatsuba(a, c)
		let bd = karatsuba(b, d)
		let adPlusbc = karatsuba(a + b, c + d) - ac - bd

		let nBy2mul2pow = Arbit(2 * nBy2).pow10()
		let product = ac * nBy2mul2pow + adPlusbc * nBy2Pow + bd

		return product
	}

}

// MARK: Division ( / )

extension Arbit {

	public static func / (lhs: Arbit, rhs: Arbit) -> Arbit {
		guard !rhs.isZero else { return Arbit.nan }

		guard !lhs.isZero else { return Arbit.zero }

		var (left, right) = equalize(lhs: lhs.fraction ?? "", rhs: rhs.fraction ?? "")
		(left, right) = (lhs.integer + left, rhs.integer + right)

		let (int, frc) = divideFraction(string: left, by: right)

		return Arbit(raw: int, frc, negative: getNegative(lhs: lhs, rhs: rhs))
	}

	public static func /= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs / rhs }

	public func quotientAndRemainder(dividingBy div: Arbit) -> (quotient: Arbit, remainder: Arbit) { // TODO: Megcsinálni törtekre is !!!

		var (left, right) = Self.equalize(lhs: self.fraction ?? "", rhs: div.fraction ?? "")
		(left, right) = (self.integer + left, div.integer + right)

		let (quotient, remainder) = Self.quotientAndRemainder(string: left, by: right)

		return (Arbit(quotient), Arbit(remainder))
	}

	public static func quotientAndRemainder(string: String, by div: String) -> (quotient: String, remainder: Int) {
		/// Big quo&rem
		///
		guard let rInt = Int(div), rInt < Int.max / 10 else {
			return quoAndRem(string: string, by: div)
		}

		/// Mid quo&rem
		///
		guard let lInt = Int(string) else {
			return quoAndRem(string: string, by: rInt)
		}

		/// Quick quo&rem
		///
		let (quotient, remainder) = lInt.quotientAndRemainder(dividingBy: rInt)
		return (String(quotient), remainder)
	}

	public static func quoAndRem(string lhs: String, by rhs: Int) -> (quotient: String, remainder: Int) {
		/// Mid quo&rem
		///
		let first = lhs.prefix(18)
		var temp = Int(first)!
		var i = first.count
		var result = ""
		var (quo, rem) = (Int(0), Int(0))

//		while temp < rhs && i < lhs.count {
//			temp = (temp * 10) + Int(lhs[i])
//			i += 1
//		}

		while i < lhs.count {
			(quo, rem) = temp.quotientAndRemainder(dividingBy: rhs)
			result += String(quo)
			temp = (rem * 10) + Int(lhs[i])
			// print(":", rem, rem*10, temp)
			i += 1
		}

		(quo, rem) = temp.quotientAndRemainder(dividingBy: rhs)
		result += String(quo)

		return (result, rem)
	}

	public static func quoAndRem__(string lhs: String, by rhs: Int) -> (quotient: String, remainder: Int) {
		/// Mid quo&rem
		///
		let first = lhs.prefix(18)
		var temp = Int(first)!
		var i = first.count
		var result = ""
		var (quo, rem) = (0, 0)

//		print(":",temp)

		while i < lhs.count {
			(quo, rem) = temp.quotientAndRemainder(dividingBy: rhs)
			result += String(quo)
//			if rem < 100 { result += "0" }

			let remStr = String(rem)
			let chunk = lhs[i..<Swift.min(i + (18 - remStr.count), lhs.count)]

//			print(quo, rem, "   ", chunk, String(rem) + chunk)

			temp = Int(remStr + chunk)!
			i += chunk.count
		}

		(quo, rem) = temp.quotientAndRemainder(dividingBy: rhs)
		result += String(quo)

		return (result, rem)
	}

	/// Big quo&rem
	public static func quoAndRem(string lhs: String, by rhs: String) -> (quotient: String, remainder: Int) {
//		var temp = Arbit(raw: String(lhs.prefix(rhs.count)))
		var temp = Arbit(raw: lhs)
		let div = Arbit(raw: rhs)
		var i = rhs.count
		var result = ""
		var (quo, rem) = (0, "")

//		while temp < div && i < lhs.count {
//			temp.integer += String(lhs[i])
//			i += 1
//		}

		while i < lhs.count {
			(quo, rem) = divForce(num: temp.integer, div: div.integer)
			result += String(quo)
			temp = Arbit(raw: rem + String(lhs[i]))
			i += 1
		}

//		print("i", i - lhs.count)

		(quo, rem) = divForce(num: temp.integer, div: div.integer)
		result += String(quo)

		guard let intRem = Int(rem) else { fatalError("intRem: \(rem)") }
		
		return (result, intRem) // FIXME: !!! force unwrap !!!
	}

	static func divForce(num: String, div: String) -> (quo: Int, rem: String) {
		var rem = num
		var quo: Int = 0

		while rem != "0" {
			let (r, negative) = subtraction(lhs: rem, rhs: div)
			if negative { break }
			rem = r
			quo += 1
		}

		return (quo, rem)
	}

	static func divPrec_(lhs: String, rhs: String) -> (int: String, frc: String?) {
		/// Try basic division, if fall, jump to long div.
		///
		if let rInt = Int(rhs),
			let lInt = Int(lhs + precisionZeros) {
			let (result, overflow) = lInt.dividedReportingOverflow(by: rInt)

			if !overflow {
				return div10(String(result), exp: precision)
			}
		}

		fatalError()
	}

	public static func divideFraction(string lhs: String, by rhs: String) -> (int: String, frc: String?) {
		let (quo, remainder) = quotientAndRemainder(string: lhs, by: rhs)

		guard remainder > 0 else { return (quo, nil) }

		guard let rInt = Int(rhs) else { return ("Long Div Error", nil) }

		var (frc, rem) = (0, 1)
		var temp: Int
		var overflow = false
		var fraction = ""
		var i = 0

		(temp, overflow) = remainder.multipliedReportingOverflow(by: 10)

		while rem > 0 && Self.precision > i {
			(frc, rem) = temp.quotientAndRemainder(dividingBy: rInt)

			fraction += String(frc)

			(temp, overflow) = rem.multipliedReportingOverflow(by: 10)

			guard !overflow else { return ("Long Div Error", nil) }

			// FIXME: Arbit lesz ..

			i += 1
		}

		return (quo, fraction)
	}

}

// MARK: Necessary Functions

extension Arbit {

	@inline(__always)
	static func getNegative(lhs: Arbit, rhs: Arbit) -> Bool {
		(lhs.isNegative && !rhs.isNegative) || (!lhs.isNegative && rhs.isNegative)
	}

//	@inline(__always)
//	static func getError(lhs: Arbit, rhs: Arbit) -> Errors? {
//		fatalError()
		// TODO: miez a baromság ?
//		let xerror = Swift.max(lhs.error?.rawValue ?? 0, rhs.error?.rawValue ?? 0)
//		return xerror > 0 ? Errors(rawValue: xerror) : nil
		
//		return nil
//	}

	@inline(__always)
	static func split(_ result: String, center: Int) -> (lhs: String, rhs: String) {
		//		print("split:", result, result.count, center)

		let left = String(result[Range(uncheckedBounds: (0, center))])
		let right = String(result[Range(uncheckedBounds: (center, result.count))])

		return (left, right)
	}

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

	@inline(__always)
	static func difference(lhs: String, rhs: String) -> Int {
		return abs(lhs.count - rhs.count)
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

		print("(D:\(decimals))", input)

		if decimals > 0 { // Mul: input * 10^d

			return (int: input + String(repeating: "0", count: decimals), frc: nil)

		} else { // Div: input * 10^-d

			return div10(input, exp: abs(decimals))
		}
	}

}
