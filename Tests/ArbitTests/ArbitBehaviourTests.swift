import XCTest
@testable import Arbit


// MARK: Helpers

/// Reproducible random numbers (SplitMix64): a failing case can be run again with the same seed
struct SeededGenerator: RandomNumberGenerator {

	var state: UInt64

	init(seed: UInt64) { self.state = seed }

	mutating func next() -> UInt64 {
		state &+= 0x9E3779B97F4A7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
		z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
		return z ^ (z >> 31)
	}
}

/// Random decimal number as string: "-123.045"
func randomNumber(_ generator: inout SeededGenerator,
						int intDigits: ClosedRange<Int>,
						frc frcDigits: ClosedRange<Int> = 0...0,
						signed: Bool = true) -> String {

	func digits(_ count: Int, first: String) -> String {
		guard count > 0 else { return "" }
		var string = String(first.randomElement(using: &generator)!)
		for _ in 1..<count { string.append("0123456789".randomElement(using: &generator)!) }
		return string
	}

	var number = digits(Int.random(in: intDigits, using: &generator), first: "123456789")
	if number.isEmpty { number = "0" }

	let fraction = digits(Int.random(in: frcDigits, using: &generator), first: "0123456789")
	if !fraction.isEmpty { number += "." + fraction }

	if signed, Bool.random(using: &generator) { number = "-" + number }

	return number
}

/// The canonical form: no leading zeros, no trailing fraction zeros, no negative zero, digits only
func assertCanonical(_ value: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {

	guard !value.isError else { return }

	let isDigits: (String) -> Bool = { $0.utf8.allSatisfy { $0 >= 48 && $0 <= 57 } }

	XCTAssertFalse(value.integer.isEmpty, "empty integer: \(message)", file: file, line: line)
	XCTAssertTrue(isDigits(value.integer), "not digits '\(value.integer)': \(message)", file: file, line: line)
	XCTAssertTrue(value.integer == "0" || value.integer.first != "0", "leading zero '\(value)': \(message)", file: file, line: line)

	if let fraction = value.fraction {
		XCTAssertFalse(fraction.isEmpty, "empty fraction: \(message)", file: file, line: line)
		XCTAssertTrue(isDigits(fraction), "not digits '\(fraction)': \(message)", file: file, line: line)
		XCTAssertNotEqual(fraction.last, "0", "trailing zero '\(value)': \(message)", file: file, line: line)
	}

	if value.integer == "0", value.fraction == nil {
		XCTAssertFalse(value.negative, "negative zero: \(message)", file: file, line: line)
	}
}

/// Saves and restores the global settings around every test
class ArbitTestCase: XCTestCase {

	private var savedPrecision = 16
	private var savedRounding = Arbit.RoundingMode.truncate

	override func setUp() {
		super.setUp()
		savedPrecision = Arbit.precision
		savedRounding = Arbit.rounding
		Arbit.precision = 16
		Arbit.rounding = .truncate
	}

	override func tearDown() {
		Arbit.precision = savedPrecision
		Arbit.rounding = savedRounding
		super.tearDown()
	}
}



// MARK: Compare

final class Test_Compare: ArbitTestCase {

	func test_Smaller_Both_Directions() throws {

		/// (smaller, bigger)
		let pairs: [(String, String)] = [
			("9", "10"), ("99", "100"), ("5", "50"), ("19", "20"), ("123", "1000"),
			("1.2", "1.5"), ("0.25", "0.5"), ("1.05", "1.5"), ("0.2", "0.25"), ("1", "1.5"), ("1.5", "2"),
			("0.001", "0.01"), ("9.99", "10"), ("0", "0.001"),
			("-10", "-9"), ("-100", "-99"), ("-1.5", "-1.2"), ("-1.5", "-1"), ("-2", "-1.5"),
			("-0.001", "0"), ("-0.5", "-0.25"), ("-1", "1"), ("-1000", "0.1"),
			("99999999999999999999", "100000000000000000000"),
			("-100000000000000000000", "-99999999999999999999"),
			("12345678901234567890.1", "12345678901234567890.11"),
		]

		for (small, big) in pairs {
			let (a, b) = (A(small), A(big))

			XCTAssertTrue ( a <  b, "\(small) < \(big)")
			XCTAssertTrue ( a <= b, "\(small) <= \(big)")
			XCTAssertFalse( a >  b, "\(small) > \(big)")
			XCTAssertFalse( a >= b, "\(small) >= \(big)")
			XCTAssertFalse( a == b, "\(small) == \(big)")

			XCTAssertFalse( b <  a, "\(big) < \(small)")
			XCTAssertFalse( b <= a, "\(big) <= \(small)")
			XCTAssertTrue ( b >  a, "\(big) > \(small)")
			XCTAssertTrue ( b >= a, "\(big) >= \(small)")

			XCTAssertEqual( max(a, b), b )
			XCTAssertEqual( min(a, b), a )
		}
	}

	func test_Equal_Is_Not_Smaller() throws {

		for string in ["0", "5", "-5", "1.5", "-1.5", "100", "0.001", "123456789012345678901234567890.5"] {
			let (a, b) = (A(string), A(string))

			XCTAssertFalse( a < b, string)
			XCTAssertFalse( a > b, string)
			XCTAssertTrue ( a <= b, string)
			XCTAssertTrue ( a >= b, string)
			XCTAssertTrue ( a == b, string)
		}
	}

	func test_Sorted() throws {

		let numbers = ["10", "9", "100", "1.5", "-3", "0", "-3.5", "0.25", "0.5", "-100", "99", "1.05"].map(A)
		let sorted = ["-100", "-3.5", "-3", "0", "0.25", "0.5", "1.05", "1.5", "9", "10", "99", "100"]

		XCTAssertEqual( numbers.sorted().map(\.description), sorted )
		XCTAssertEqual( numbers.max()?.description, "100" )
		XCTAssertEqual( numbers.min()?.description, "-100" )
	}

	func test_Random_Against_Decimal() throws {

		var generator = SeededGenerator(seed: 1)

		for _ in 1...500 {
			let l = randomNumber(&generator, int: 0...12, frc: 0...6)
			let r = randomNumber(&generator, int: 0...12, frc: 0...6)

			let (lT, rT) = (A(l), A(r))
			let (lDec, rDec) = (Decimal(string: l)!, Decimal(string: r)!)

			XCTAssertEqual( lT <  rT, lDec <  rDec, "\(l) < \(r)")
			XCTAssertEqual( lT >  rT, lDec >  rDec, "\(l) > \(r)")
			XCTAssertEqual( lT == rT, lDec == rDec, "\(l) == \(r)")
			XCTAssertEqual( lT <= rT, lDec <= rDec, "\(l) <= \(r)")
		}
	}

	func test_Mixed_With_Int() throws {

		let five: Int = 5

		XCTAssertTrue ( T(5) == five )
		XCTAssertFalse( T(5) != five )
		XCTAssertFalse( A("5.5") == five )
		XCTAssertTrue ( A("5.5") != five )
		XCTAssertTrue ( A("5.5") > five )
		XCTAssertTrue ( A("5.5") >= five )
		XCTAssertTrue ( A("4.5") < five )
		XCTAssertTrue ( A("-4.5") <= five )
	}
}



// MARK: Signs

final class Test_Signs: ArbitTestCase {

	func test_Mixed_Sign_Add_Sub() throws {

		/// (lhs, rhs, sum, difference)
		let cases: [(String, String, String, String)] = [
			("-5", "8.2", "3.2", "-13.2"),
			("8.2", "-5", "3.2", "13.2"),
			("-1.5", "0.5", "-1", "-2"),
			("0.5", "-1.5", "-1", "2"),
			("-5.5", "3.2", "-2.3", "-8.7"),
			("-5.5", "-3.7", "-9.2", "-1.8"),
			("5.5", "3.7", "9.2", "1.8"),
			("-0.5", "0.5", "0", "-1"),
			("-3", "-2.5", "-5.5", "-0.5"),
			("-30000000000000000000", "1", "-29999999999999999999", "-30000000000000000001"),
			("1", "-30000000000000000000", "-29999999999999999999", "30000000000000000001"),
			("-12319823986912836981236986", "98126398612398612938612989", "85806574625485775957376003", "-110446222599311449919849975"),
			("9223372036854775807.5", "0.5", "9223372036854775808", "9223372036854775807"),
			("-9223372036854775807.5", "-0.5", "-9223372036854775808", "-9223372036854775807"),
			("99999999999999999999.5", "0.5", "100000000000000000000", "99999999999999999999"),
			("100000000000000000000", "0.1", "100000000000000000000.1", "99999999999999999999.9"),
			("0.1000000000000000000000001", "0.2000000000000000000000001", "0.3000000000000000000000002", "-0.1"),
		]

		for (l, r, sum, difference) in cases {
			XCTAssertEqual( (A(l) + A(r)).description, sum, "\(l) + \(r)")
			XCTAssertEqual( (A(l) - A(r)).description, difference, "\(l) - \(r)")
		}
	}

	func test_Negate() throws {

		var a = T(5)
		a.negate()
		XCTAssertEqual( a.description, "-5")
		a.negate()
		XCTAssertEqual( a.description, "5")

		XCTAssertEqual( (-A("1.5")).description, "-1.5")
		XCTAssertEqual( (-A("-1.5")).description, "1.5")

		/// No negative zero
		var zero = T(0)
		zero.negate()
		XCTAssertFalse( zero.isNegative )
		XCTAssertEqual( (-T(0)).description, "0")

		XCTAssertEqual( abs(T(-5)), 5 )
		XCTAssertEqual( T(-5).magnitude, 5 )
		XCTAssertEqual( A("-0.5").signum(), -1 )
		XCTAssertEqual( T(0).signum(), 0 )
	}

	func test_Random_Against_Decimal() throws {

		var generator = SeededGenerator(seed: 2)

		for _ in 1...300 {
			let l = randomNumber(&generator, int: 0...12, frc: 0...6)
			let r = randomNumber(&generator, int: 0...12, frc: 0...6)

			let (lT, rT) = (A(l), A(r))
			let (lDec, rDec) = (Decimal(string: l)!, Decimal(string: r)!)

			XCTAssertEqual( (lT + rT).description, (lDec + rDec).description, "\(l) + \(r)")
			XCTAssertEqual( (lT - rT).description, (lDec - rDec).description, "\(l) - \(r)")
			XCTAssertEqual( (lT * rT).description, (lDec * rDec).description, "\(l) * \(r)")
		}
	}

	func test_Long_Random_Against_Decimal() throws {

		/// Longer than Int, but the results still fit into the 38 digits of the Decimal
		var generator = SeededGenerator(seed: 3)

		for _ in 1...300 {
			let l = randomNumber(&generator, int: 18...28, frc: 0...8)
			let r = randomNumber(&generator, int: 1...28, frc: 0...8)

			let (lT, rT) = (A(l), A(r))
			let (lDec, rDec) = (Decimal(string: l)!, Decimal(string: r)!)

			XCTAssertEqual( (lT + rT).description, (lDec + rDec).description, "\(l) + \(r)")
			XCTAssertEqual( (lT - rT).description, (lDec - rDec).description, "\(l) - \(r)")
		}
	}
}



// MARK: Algebraic properties

final class Test_Properties: ArbitTestCase {

	func test_Add_Mul_Identities() throws {

		var generator = SeededGenerator(seed: 4)

		for _ in 1...200 {
			let a = A(randomNumber(&generator, int: 0...40, frc: 0...25))
			let b = A(randomNumber(&generator, int: 0...40, frc: 0...25))

			XCTAssertEqual( a + b, b + a, "\(a) + \(b)")
			XCTAssertEqual( a * b, b * a, "\(a) * \(b)")
			XCTAssertEqual( (a + b) - b, a, "(\(a) + \(b)) - \(b)")
			XCTAssertEqual( (a - b) + b, a, "(\(a) - \(b)) + \(b)")
			XCTAssertEqual( a - a, 0, "\(a) - \(a)")
			XCTAssertEqual( a + 0, a )
			XCTAssertEqual( a * 1, a )
			XCTAssertEqual( a * 0, 0 )
			XCTAssertEqual( a * -1, -a )
			XCTAssertEqual( a * (b + 1), a * b + a, "\(a) * (\(b) + 1)")

			for result in [a + b, a - b, a * b, a - a, -a] {
				assertCanonical(result, "\(a) ? \(b)")
			}
		}
	}

	func test_Quotient_And_Remainder() throws {

		var generator = SeededGenerator(seed: 5)

		for i in 1...300 {

			/// Every third round is with fractions, and every fourth is with a long divisor
			let frc = i % 3 == 0 ? 0...6 : 0...0
			let a = A(randomNumber(&generator, int: 0...45, frc: frc))
			let b = A(randomNumber(&generator, int: (i % 4 == 0 ? 20...30 : 1...18), frc: frc))

			guard !b.isZero else { continue }

			let (q, r) = a.quotientAndRemainder(dividingBy: b)

			XCTAssertEqual( q * b + r, a, "\(a) = \(q) * \(b) + \(r)")
			XCTAssertTrue( r.magnitude < b.magnitude, "|\(r)| < |\(b)|")
			XCTAssertTrue( r.isZero || r.isNegative == a.isNegative, "the sign of \(r) for \(a) / \(b)")
			XCTAssertFalse( q.isDecimal, "\(q)")
			XCTAssertEqual( a % b, r )

			assertCanonical(q, "\(a) / \(b)")
			assertCanonical(r, "\(a) % \(b)")
		}
	}

	func test_Mul_Div_Round_Trip() throws {

		var generator = SeededGenerator(seed: 6)

		for _ in 1...150 {
			let a = A(randomNumber(&generator, int: 1...40))
			let b = A(randomNumber(&generator, int: 1...40))

			let quotient = (a * b) / b

			XCTAssertEqual( quotient, a, "(\(a) * \(b)) / \(b)")
			assertCanonical(quotient)
		}
	}

	func test_Karatsuba() throws {

		var generator = SeededGenerator(seed: 7)

		for _ in 1...40 {
			let a = A(randomNumber(&generator, int: 1...60))
			let b = A(randomNumber(&generator, int: 1...60))

			XCTAssertEqual( T.karatsuba(a, b), a * b, "\(a) * \(b)")
		}

		XCTAssertEqual( T.karatsuba(1234, 5), 6170 )
		XCTAssertEqual( T.karatsuba(0, 5), 0 )
		XCTAssertEqual( T.karatsuba(A("1.5"), 4), 6 )
	}

	func test_Normalized_Results() throws {

		/// These gave leading zeros or negative zero
		XCTAssertEqual( (A("0.00000000000000000001") * A("123456789012345678901234567890")).description, "1234567890.1234567890123456789")
		XCTAssertEqual( (A("100000000000000000000") / A("900000000000000000")).description, "111.1111111111111111")
		XCTAssertEqual( (A("0.3") - A("0.3")).description, "0")
		XCTAssertEqual( (T(-1) * A("0.0")).description, "0")
		XCTAssertEqual( (T(0) / T(-5)).description, "0")
		XCTAssertEqual( (A("-0.5") + A("0.5")).description, "0")
		XCTAssertEqual( (A("0.5") * A("0.2")).description, "0.1")

		var clamped = A("1.2001")
		clamped.clamp(fraction: 2)
		XCTAssertEqual( clamped, A("1.2") )
		XCTAssertEqual( clamped.description, "1.2" )
	}
}



// MARK: Parsing

final class Test_Parsing: ArbitTestCase {

	func test_Runtime_String_Valid() throws {

		let cases: [(String, String)] = [
			("0", "0"), ("-0", "0"), ("+0", "0"), ("0.0", "0"), ("-0.000", "0"),
			("7", "7"), ("007", "7"), ("-007", "-7"), ("+5", "5"),
			("1.50", "1.5"), ("001.500", "1.5"), (".5", "0.5"), ("-.5", "-0.5"), ("5.", "5"),
			("1e5", "100000"), ("1E5", "100000"), ("1.5e-10", "0.00000000015"), ("-2.5e3", "-2500"),
			("12.345e2", "1234.5"), ("12.345e+1", "123.45"), ("1e0", "1"), ("0e5", "0"),
			("123456789012345678901234567890.000000000000000000001", "123456789012345678901234567890.000000000000000000001"),
			("nan", "nan"), ("inf", "inf"), ("-inf", "-inf"), ("Infinity", "inf"),
		]

		for (input, expected) in cases {
			let value = T(input)
			XCTAssertNotNil(value, input)
			XCTAssertEqual(value?.description, expected, input)
			if let value { assertCanonical(value, input) }
		}
	}

	func test_Runtime_String_Invalid() throws {

		let cases = ["", " ", "abc", "1.2.3", "--1", "+-1", "1,5", "1 000", "1_000", "e5", "1e", "1e1.5",
						 "-", "+", ".", "-.", "0x1F", "12a", "a12", " 12", "12 ", "½", "1e99999999999"]

		for input in cases {
			XCTAssertNil( T(input), "'\(input)'")
		}
	}

	func test_Literal_Is_Forgiving() throws {

		XCTAssertEqual( T("1 000").description, "1000")
		XCTAssertEqual( T("1_000.50").description, "1000.5")
		XCTAssertEqual( T("-0.9a2233720x3685477 580_8").description, "-0.9223372036854775808")
		XCTAssertEqual( T("1.2.3").description, "1.23")
		XCTAssertEqual( T("007").description, "7")
		XCTAssertEqual( T("1e3").description, "1000")

		XCTAssertTrue( T("abc").isEmpty )
		XCTAssertTrue( T("").isEmpty )

		let literal: Arbit = "12.50"
		XCTAssertEqual( literal.description, "12.5" )
	}

	func test_Round_Trip() throws {

		var generator = SeededGenerator(seed: 8)

		for _ in 1...200 {
			let value = A(randomNumber(&generator, int: 0...50, frc: 0...50))
			XCTAssertEqual( T(value.description), value )
		}

		XCTAssertEqual( T(T.inf.description), T.inf )
		XCTAssertEqual( T((-T.inf).description)?.description, "-inf" )
		XCTAssertEqual( T(T.nan.description)?.isNaN, true )
	}

	func test_Radix() throws {

		XCTAssertEqual( T(bin: "1111"), 15 )
		XCTAssertEqual( T(bin: "0b1111"), 15 )
		XCTAssertEqual( T(bin: "-101"), -5 )
		XCTAssertEqual( T(bin: "-0b101"), -5 )
		XCTAssertEqual( T(bin: "0000"), 0 )
		XCTAssertTrue ( T(bin: "102").isNaN )
		XCTAssertTrue ( T(bin: "101-").isNaN )
		XCTAssertTrue ( T(bin: "").isNaN )

		XCTAssertEqual( T(oct: "17"), 15 )
		XCTAssertEqual( T(oct: "0o777"), 511 )
		XCTAssertEqual( T(oct: "-10"), -8 )
		XCTAssertTrue ( T(oct: "8").isNaN )

		XCTAssertEqual( T(hex: "FF"), 255 )
		XCTAssertEqual( T(hex: "ff"), 255 )
		XCTAssertEqual( T(hex: "0x1F"), 31 )
		XCTAssertEqual( T(hex: "-0x10"), -16 )
		XCTAssertEqual( T(hex: "FFFFFFFFFFFFFFFF"), T(UInt64.max) )
		XCTAssertEqual( T(hex: "10000000000000000").description, "18446744073709551616" )
		XCTAssertTrue ( T(hex: "XYZ").isNaN )

		/// Literal prefixes
		XCTAssertEqual( T("0x1F"), 31 )
		XCTAssertEqual( T("0o17"), 15 )
		XCTAssertEqual( T("0b101"), 5 )
		XCTAssertEqual( T("-0xFF"), -255 )

		/// Failable radix init
		let (bin, oct, hex, dec, big) = ("1010", "777", "ff", "-12.5", "123456789ABCDEF")
		XCTAssertEqual( T(bin, radix: 2), 10 )
		XCTAssertEqual( T(oct, radix: 8), 511 )
		XCTAssertEqual( T(hex, radix: 16), 255 )
		XCTAssertEqual( T(dec, radix: 10)?.description, "-12.5" )
		XCTAssertEqual( T(big, radix: 16)?.description, "81985529216486895" )
		XCTAssertNil( T("12", radix: 2) )
		XCTAssertNil( T("9", radix: 8) )
		XCTAssertNil( T("G", radix: 16) )
		XCTAssertNil( T("10", radix: 7) )
		XCTAssertNil( T("", radix: 16) )

		XCTAssertEqual( "FF".hexToDec(), "255" )
		XCTAssertEqual( "FF".hexToBin(), "11111111" )
		XCTAssertEqual( "17".octToDec(), "15" )
	}

	func test_Radix_Round_Trip() throws {

		var generator = SeededGenerator(seed: 9)

		for _ in 1...40 {
			let value = A(randomNumber(&generator, int: 1...80))

			XCTAssertEqual( T(bin: value.asBinary()), value, "bin \(value)")
			XCTAssertEqual( T(oct: value.asOctal()), value, "oct \(value)")
			XCTAssertEqual( T(hex: value.asHexadecimal()), value, "hex \(value)")

			XCTAssertEqual( T(bin: value.asBinary(withPrefix: true)), value, "0b \(value)")
			XCTAssertEqual( T(oct: value.asOctal(withPrefix: true)), value, "0o \(value)")
			XCTAssertEqual( T(hex: value.asHexadecimal(withPrefix: true)), value, "0x \(value)")
		}

		XCTAssertEqual( T(511).asOctal(), "777" )
		XCTAssertEqual( T(8).asOctal(), "10" )
		XCTAssertEqual( T(0).asOctal(), "0" )
		XCTAssertEqual( T(-8).asOctal(withPrefix: true), "-0o10" )
	}
}



// MARK: Division

final class Test_Division: ArbitTestCase {

	func test_Precision() throws {

		Arbit.precision = 0
		XCTAssertEqual( (T(7) / T(2)).description, "3" )
		XCTAssertEqual( (T(-7) / T(2)).description, "-3" )
		XCTAssertEqual( (T(1) / T(3)).description, "0" )

		Arbit.precision = 1
		XCTAssertEqual( (T(7) / T(2)).description, "3.5" )
		XCTAssertEqual( (T(1) / T(3)).description, "0.3" )

		Arbit.precision = 16
		XCTAssertEqual( (T(1) / T(3)).description, "0.3333333333333333" )
		XCTAssertEqual( (T(2) / T(3)).description, "0.6666666666666666" )
		XCTAssertEqual( (T(1) / T(7)).description, "0.1428571428571428" )
		XCTAssertEqual( (T(1) / T(8)).description, "0.125" )

		Arbit.precision = 50
		XCTAssertEqual( (T(1) / T(7)).description, "0.14285714285714285714285714285714285714285714285714" )
		XCTAssertEqual( (T(22) / T(7)).description, "3.14285714285714285714285714285714285714285714285714" )
	}

	func test_Rounding_Modes() throws {

		func divide(_ l: T, _ r: T, _ digits: Int, _ mode: T.RoundingMode) -> String {
			Arbit.precision = digits
			Arbit.rounding = mode
			return (l / r).description
		}

		/// 2/3 = 0.6666…
		XCTAssertEqual( divide(2, 3, 4, .truncate), "0.6666" )
		XCTAssertEqual( divide(2, 3, 4, .halfUp),   "0.6667" )
		XCTAssertEqual( divide(2, 3, 4, .halfEven), "0.6667" )

		/// 1/3 = 0.3333…
		XCTAssertEqual( divide(1, 3, 4, .halfUp),   "0.3333" )
		XCTAssertEqual( divide(1, 3, 4, .halfEven), "0.3333" )

		/// 1/8 = 0.125 exactly half at two digits
		XCTAssertEqual( divide(1, 8, 2, .truncate), "0.12" )
		XCTAssertEqual( divide(1, 8, 2, .halfUp),   "0.13" )
		XCTAssertEqual( divide(1, 8, 2, .halfEven), "0.12" )
		XCTAssertEqual( divide(-1, 8, 2, .halfUp),   "-0.13" )
		XCTAssertEqual( divide(-1, 8, 2, .halfEven), "-0.12" )

		/// 3/8 = 0.375
		XCTAssertEqual( divide(3, 8, 2, .halfUp),   "0.38" )
		XCTAssertEqual( divide(3, 8, 2, .halfEven), "0.38" )

		/// Halves to integer
		XCTAssertEqual( divide(5, 2, 0, .truncate), "2" )
		XCTAssertEqual( divide(5, 2, 0, .halfUp),   "3" )
		XCTAssertEqual( divide(5, 2, 0, .halfEven), "2" )
		XCTAssertEqual( divide(7, 2, 0, .halfEven), "4" )

		/// A bit over the half is not a tie: 0.1250001
		XCTAssertEqual( divide("1.250001", 10, 2, .halfEven), "0.13" )

		/// Carry through the nines
		XCTAssertEqual( divide("19.999", 2, 2, .halfUp), "10" )
		XCTAssertEqual( divide("0.0999", 1, 2, .halfUp), "0.1" )
	}

	func test_Rounded() throws {

		XCTAssertEqual( A("2.5").rounded(fraction: 0, mode: .truncate).description, "2" )
		XCTAssertEqual( A("2.5").rounded(fraction: 0, mode: .halfUp).description, "3" )
		XCTAssertEqual( A("2.5").rounded(fraction: 0, mode: .halfEven).description, "2" )
		XCTAssertEqual( A("3.5").rounded(fraction: 0, mode: .halfEven).description, "4" )
		XCTAssertEqual( A("2.51").rounded(fraction: 0, mode: .halfEven).description, "3" )
		XCTAssertEqual( A("-2.5").rounded(fraction: 0, mode: .halfUp).description, "-3" )

		XCTAssertEqual( A("2.45").rounded(fraction: 1, mode: .halfUp).description, "2.5" )
		XCTAssertEqual( A("2.449").rounded(fraction: 1, mode: .halfUp).description, "2.4" )
		XCTAssertEqual( A("9.99").rounded(fraction: 1, mode: .halfUp).description, "10" )
		XCTAssertEqual( A("-9.99").rounded(fraction: 1, mode: .halfUp).description, "-10" )
		XCTAssertEqual( A("0.0004").rounded(fraction: 1, mode: .halfUp).description, "0" )
		XCTAssertEqual( A("0.0005").rounded(fraction: 3, mode: .halfUp).description, "0.001" )

		/// Nothing to do
		XCTAssertEqual( A("1.5").rounded(fraction: 3, mode: .halfUp).description, "1.5" )
		XCTAssertEqual( T(15).rounded(fraction: 0, mode: .halfUp).description, "15" )

		/// Default mode is the global one
		Arbit.rounding = .halfUp
		XCTAssertEqual( A("1.2345").rounded(fraction: 3).description, "1.235" )
		Arbit.rounding = .truncate
		XCTAssertEqual( A("1.2345").rounded(fraction: 3).description, "1.234" )
	}

	func test_By_Zero() throws {

		XCTAssertTrue( (T(1) / T(0)).isNaN )
		XCTAssertTrue( (T(0) / T(0)).isNaN )
		XCTAssertTrue( (A("1.5") / A("0.0")).isNaN )
		XCTAssertTrue( (T(5) % T(0)).isNaN )

		let (q, r) = T(5).quotientAndRemainder(dividingBy: 0)
		XCTAssertTrue( q.isNaN )
		XCTAssertTrue( r.isNaN )
	}

	func test_Remainder() throws {

		/// (dividend, divisor, quotient, remainder) – like at Int: the remainder has the sign of the dividend
		let cases: [(String, String, String, String)] = [
			("7", "3", "2", "1"),
			("-7", "3", "-2", "-1"),
			("7", "-3", "-2", "1"),
			("-7", "-3", "2", "-1"),
			("6", "3", "2", "0"),
			("-6", "3", "-2", "0"),
			("2", "5", "0", "2"),
			("-2", "5", "0", "-2"),
			("7.5", "2", "3", "1.5"),
			("-7.5", "2", "-3", "-1.5"),
			("7.5", "0.2", "37", "0.1"),
			("1", "0.3", "3", "0.1"),
			("0.75", "0.5", "1", "0.25"),
			("1234567890123456789012345678901234567890", "12345678901234567890", "100000000000000000001", "0"),
			("1234567890123456789012345678901234567891", "12345678901234567890", "100000000000000000001", "1"),
			("100000000000000000000", "900000000000000000", "111", "100000000000000000"),
			("-100000000000000000000000000000000000001", "100000000000000000000000000000", "-1000000000", "-1"),
		]

		for (a, b, quotient, remainder) in cases {
			let (q, r) = A(a).quotientAndRemainder(dividingBy: A(b))

			XCTAssertEqual( q.description, quotient, "\(a) / \(b)")
			XCTAssertEqual( r.description, remainder, "\(a) % \(b)")
			XCTAssertEqual( (A(a) % A(b)).description, remainder, "\(a) % \(b)")
		}

		/// The same as Int
		for a in -12...12 {
			for b in [-5, -3, -1, 1, 2, 7] {
				XCTAssertEqual( T(a) % T(b), T(a % b), "\(a) % \(b)")
				XCTAssertEqual( T(a).quotientAndRemainder(dividingBy: T(b)).quotient, T(a / b), "\(a) / \(b)")
			}
		}

		var value = T(17)
		value %= 5
		XCTAssertEqual( value, 2 )

		XCTAssertTrue ( T(10).isMultiple(of: 5) )
		XCTAssertFalse( T(10).isMultiple(of: 3) )
		XCTAssertTrue ( T(0).isMultiple(of: 0) )
		XCTAssertFalse( T(10).isMultiple(of: 0) )
	}

	func test_QuoAndRem_Int() throws {

		XCTAssertEqual( T.quoAndRem(string: "12345678901234567890", by: 1234567890).quotient, "10000000001" )
		XCTAssertEqual( T.quoAndRem(string: "12345678901234567890", by: 1234567890).remainder, 0 )
		XCTAssertEqual( T.quoAndRem(string: "100", by: 7).quotient, "14" )
		XCTAssertEqual( T.quoAndRem(string: "100", by: 7).remainder, 2 )
		XCTAssertEqual( T.quoAndRem(string: "5", by: 7).quotient, "0" )
		XCTAssertEqual( T.quoAndRem(string: "100000000000000000000", by: 900000000000000000).quotient, "111" )
		XCTAssertEqual( T.quoAndRem(string: "100000000000000000000", by: Int.max).quotient, "10" )
		XCTAssertEqual( T.quoAndRem(string: "100000000000000000000", by: Int.max).remainder, 7766279631452241930 )
	}
}



// MARK: Error values

final class Test_Errors: ArbitTestCase {

	func test_Description() throws {

		XCTAssertEqual( T.nan.description, "nan" )
		XCTAssertEqual( T.inf.description, "inf" )
		XCTAssertEqual( (-T.inf).description, "-inf" )
		XCTAssertEqual( (-T.nan).description, "nan" )

		XCTAssertEqual( T.nan.errorDescription, "Not a number!" )
		XCTAssertEqual( T.inf.errorDescription, "Infinity number!" )
		XCTAssertNil( T(5).errorDescription )

		XCTAssertEqual( T.inf.formatted(), "inf" )
		XCTAssertEqual( T.nan.limited(), "nan" )

		XCTAssertTrue ( T.nan.isNaN )
		XCTAssertFalse( T.nan.isInfinite )
		XCTAssertTrue ( T.inf.isInfinite )
		XCTAssertFalse( T.inf.isNaN )
		XCTAssertFalse( T.inf.isZero )
		XCTAssertFalse( T(5).isError )
	}

	func test_Propagation() throws {

		let (nan, inf, one) = (T.nan, T.inf, T(1))

		/// nan wins everything
		for result in [nan + one, one + nan, nan - one, one - nan, nan * one, one * nan, nan / one, one / nan,
							nan % one, one % nan, nan + inf, inf * nan, nan * 0, -nan] {
			XCTAssertTrue( result.isNaN, result.description )
		}

		/// Infinity
		XCTAssertEqual( (inf + one).description, "inf" )
		XCTAssertEqual( (one + inf).description, "inf" )
		XCTAssertEqual( (one - inf).description, "-inf" )
		XCTAssertEqual( (inf - one).description, "inf" )
		XCTAssertEqual( (inf + inf).description, "inf" )
		XCTAssertEqual( (-inf - inf).description, "-inf" )
		XCTAssertEqual( (inf * 2).description, "inf" )
		XCTAssertEqual( (inf * -2).description, "-inf" )
		XCTAssertEqual( (-inf * -2).description, "inf" )
		XCTAssertEqual( (inf * inf).description, "inf" )
		XCTAssertEqual( (inf / 2).description, "inf" )
		XCTAssertEqual( (inf / -2).description, "-inf" )
		XCTAssertEqual( (one / inf).description, "0" )

		/// Undefined cases
		XCTAssertTrue( (inf - inf).isNaN )
		XCTAssertTrue( (inf * 0).isNaN )
		XCTAssertTrue( (inf / inf).isNaN )
		XCTAssertTrue( (inf / 0).isNaN )
		XCTAssertTrue( (inf % 2).isNaN )

		/// Math functions
		XCTAssertTrue( sqrt(nan).isNaN )
		XCTAssertTrue( sqrt(-inf).isNaN )
		XCTAssertEqual( sqrt(inf).description, "inf" )
		XCTAssertTrue( nan.root(3).isNaN )
		XCTAssertTrue( nan.power(2).isNaN )
		XCTAssertTrue( nan.pow2().isNaN )
		XCTAssertTrue( (nan & 1).isNaN )
		XCTAssertTrue( (~nan).isNaN )
	}

	func test_Compare() throws {

		let (nan, inf, one) = (T.nan, T.inf, T(1))

		XCTAssertFalse( nan == nan )
		XCTAssertTrue ( nan != nan )
		XCTAssertFalse( nan < one )
		XCTAssertFalse( nan > one )
		XCTAssertFalse( one < nan )
		XCTAssertFalse( nan <= nan )

		XCTAssertTrue ( inf == inf )
		XCTAssertFalse( inf == -inf )
		XCTAssertTrue ( one < inf )
		XCTAssertTrue ( -inf < one )
		XCTAssertTrue ( -inf < inf )
		XCTAssertFalse( inf < inf )
		XCTAssertTrue ( inf > A("99999999999999999999999999999") )
	}

	func test_Casting() throws {

		XCTAssertEqual( T.nan.asDouble?.isNaN, true )
		XCTAssertEqual( T.inf.asDouble, Double.infinity )
		XCTAssertEqual( (-T.inf).asDouble, -Double.infinity )
		XCTAssertNil( T.nan.asInt )
		XCTAssertNil( T.inf.asDecimal )

		XCTAssertEqual( A("1.9").asInt, 1 )
		XCTAssertEqual( A("-1.9").asInt, -1 )
		XCTAssertEqual( A("-0.5").asInt, 0 )
		XCTAssertNil( A("9223372036854775808").asInt )
		XCTAssertEqual( A("1.5").asDecimal, Decimal(string: "1.5") )
	}
}



// MARK: Hashable

final class Test_Hash: ArbitTestCase {

	func test_Set_And_Dictionary() throws {

		let set: Set<T> = [A("1.0"), A("1"), A("01"), A("1.50"), A("1.5"), A("-1"), A("0"), A("-0")]
		XCTAssertEqual( set.count, 4 )
		XCTAssertTrue( set.contains(1) )
		XCTAssertTrue( set.contains(A("1.5")) )
		XCTAssertFalse( set.contains(2) )

		var dictionary = [T: String]()
		dictionary[A("0.5")] = "half"
		dictionary[A("0.50")] = "still half"
		dictionary[T(1) / T(2)] = "divided half"
		XCTAssertEqual( dictionary.count, 1 )
		XCTAssertEqual( dictionary[A(".5")], "divided half" )
	}

	func test_Equal_Means_Equal_Hash() throws {

		var generator = SeededGenerator(seed: 10)

		for _ in 1...100 {
			let a = A(randomNumber(&generator, int: 0...30, frc: 0...10))
			let b = (a + 1) - 1

			XCTAssertEqual( a, b )
			XCTAssertEqual( a.hashValue, b.hashValue, "\(a)")
		}
	}
}



// MARK: Math functions

final class Test_MathFunctions: ArbitTestCase {

	func test_Square_Root() throws {

		XCTAssertEqual( sqrt(T(0)).description, "0" )
		XCTAssertEqual( sqrt(T(1)).description, "1" )
		XCTAssertEqual( sqrt(T(16)).description, "4" )
		XCTAssertEqual( sqrt(T(1_000_000)).description, "1000" )
		XCTAssertEqual( sqrt(A("0.25")).description, "0.5" )
		XCTAssertEqual( sqrt(A("0.0001")).description, "0.01" )
		XCTAssertEqual( sqrt(A("152.2756")).description, "12.34" )
		XCTAssertEqual( sqrt(A("10000000000000000000000000000000000000000")).description, "100000000000000000000" )
		XCTAssertTrue ( sqrt(T(-4)).isNaN )

		XCTAssertEqual( sqrt(T(2)).description, "1.414213562373095" )
		XCTAssertEqual( T(2).sqrRoot(digits: 0).description, "1" )
		XCTAssertEqual( T(17).sqrRoot(digits: 0).description, "4" )
		XCTAssertEqual( T(2).sqrRoot(digits: 5).description, "1.41421" )

		/// Against the constants
		XCTAssertEqual( T(2).sqrRoot(digits: 100), T.const(truncated: .sqr2, digits: 100) )
		XCTAssertEqual( T(3).sqrRoot(digits: 100), T.const(truncated: .sqr3, digits: 100) )
		XCTAssertEqual( T(5).sqrRoot(digits: 100), T.const(truncated: .sqr5, digits: 100) )

		/// More fraction digits than what is asked for
		XCTAssertEqual( A("2.0000000000000000000000000000001").sqrRoot(digits: 5).description, "1.41421" )
	}

	func test_Square_Root_Of_Squares() throws {

		var generator = SeededGenerator(seed: 11)

		for _ in 1...30 {
			let n = A(randomNumber(&generator, int: 1...40, frc: 0...8, signed: false))
			XCTAssertEqual( sqrt(n * n), n, "√(\(n)²)")
		}

		XCTAssertEqual( sqrt(A("152415787532388367501905199875019052100")).description, "12345678901234567890" )
	}

	func test_Square_Root_Rounding() throws {

		/// √2 = 1.41421356…  √3 = 1.7320508…  √8 = 2.8284271…
		Arbit.rounding = .halfUp
		XCTAssertEqual( T(2).sqrRoot(digits: 3).description, "1.414" )
		XCTAssertEqual( T(2).sqrRoot(digits: 4).description, "1.4142" )
		XCTAssertEqual( T(2).sqrRoot(digits: 7).description, "1.4142136" )
		XCTAssertEqual( T(3).sqrRoot(digits: 2).description, "1.73" )
		XCTAssertEqual( T(8).sqrRoot(digits: 2).description, "2.83" )
		XCTAssertEqual( T(8).sqrRoot(digits: 0).description, "3" )

		/// Exactly half: √6.25 = 2.5
		XCTAssertEqual( A("6.25").sqrRoot(digits: 0).description, "3" )
		Arbit.rounding = .halfEven
		XCTAssertEqual( A("6.25").sqrRoot(digits: 0).description, "2" )
		XCTAssertEqual( A("12.25").sqrRoot(digits: 0).description, "4" )
		Arbit.rounding = .truncate
		XCTAssertEqual( A("6.25").sqrRoot(digits: 0).description, "2" )
	}

	func test_Root() throws {

		XCTAssertEqual( T(27).root(3).description, "3" )
		XCTAssertEqual( T(-27).root(3).description, "-3" )
		XCTAssertEqual( T(1024).root(10).description, "2" )
		XCTAssertEqual( T(16).root(4).description, "2" )
		XCTAssertEqual( A("0.001").root(3).description, "0.1" )
		XCTAssertEqual( A("3.375").root(3).description, "1.5" )
		XCTAssertEqual( T(0).root(5).description, "0" )
		XCTAssertEqual( T(1).root(99).description, "1" )
		XCTAssertEqual( T(7).root(1).description, "7" )
		XCTAssertEqual( T(16).root(2).description, "4" )
		XCTAssertEqual( T(16).root(-2).description, "0.25" )
		XCTAssertEqual( T(10).root(3, digits: 0).description, "2" )
		XCTAssertEqual( T(2).root(100, digits: 12).description, "1.006955550056" )

		XCTAssertTrue( T(-16).root(4).isNaN )
		XCTAssertTrue( T(16).root(0).isNaN )

		/// Against the constants
		XCTAssertEqual( T(2).root(3, digits: 20), T.const(truncated: .cubeRoot2, digits: 20) )
		XCTAssertEqual( T(3).root(3, digits: 60), T.const(truncated: .cubeRoot3, digits: 60) )

		/// Rounding: ∛10 = 2.15443469…
		Arbit.rounding = .halfUp
		XCTAssertEqual( T(10).root(3, digits: 2).description, "2.15" )
		XCTAssertEqual( T(10).root(3, digits: 3).description, "2.154" )
		XCTAssertEqual( T(10).root(3, digits: 5).description, "2.15443" )
		XCTAssertEqual( T(10).root(3, digits: 6).description, "2.154435" )
	}

	func test_Root_Of_Powers() throws {

		var generator = SeededGenerator(seed: 12)

		for degree in [3, 4, 5, 7, 12] {
			for _ in 1...6 {
				let n = A(randomNumber(&generator, int: 1...20, signed: false))
				XCTAssertEqual( n.power(degree).root(degree), n, "\(degree)√(\(n)^\(degree))")
			}
		}

		/// With fraction
		let n = A("12345.678")
		XCTAssertEqual( n.power(5).root(5), n )
	}

	func test_Power() throws {

		XCTAssertEqual( T(2).power(10).description, "1024" )
		XCTAssertEqual( T(2).power(0).description, "1" )
		XCTAssertEqual( T(0).power(0).description, "1" )
		XCTAssertEqual( T(0).power(5).description, "0" )
		XCTAssertEqual( T(2).power(-2).description, "0.25" )
		XCTAssertEqual( T(-2).power(3).description, "-8" )
		XCTAssertEqual( T(-2).power(4).description, "16" )
		XCTAssertEqual( A("1.5").power(2).description, "2.25" )
		XCTAssertEqual( A("0.1").power(20).description, "0.00000000000000000001" )
		XCTAssertEqual( T(10).power(30).description, "1" + String(repeating: "0", count: 30) )
		XCTAssertEqual( T(2).power(200), T(200).pow2() )
		XCTAssertEqual( T(3).power(100).description, "515377520732011331036461129765621272702107522001" )
		XCTAssertTrue ( T(0).power(-1).isNaN )

		/// Arbit exponent
		XCTAssertEqual( T(2).power(T(10))?.description, "1024" )
		XCTAssertEqual( pow(T(2), T(-1))?.description, "0.5" )

		/// 1/n exponent is the n-th root
		XCTAssertEqual( T(2).power(A("0.5")), sqrt(T(2)) )
		XCTAssertEqual( T(16).power(A("0.25"))?.description, "2" )
		XCTAssertEqual( T(32).power(A("0.2"))?.description, "2" )
		XCTAssertEqual( T(4).power(A("-0.5"))?.description, "0.5" )

		/// Other fractions are not supported
		XCTAssertNil( T(2).power(A("0.3")) )
		XCTAssertNil( T(2).power(A("1.5")) )
		XCTAssertNil( T(2).power(A("99999999999999999999")) )
	}

	func test_Pow2_Pow10() throws {

		XCTAssertEqual( T(0).pow2().description, "1" )
		XCTAssertEqual( T(1).pow2().description, "2" )
		XCTAssertEqual( T(10).pow2().description, "1024" )
		XCTAssertEqual( T(64).pow2().description, "18446744073709551616" )
		XCTAssertEqual( T(128).pow2().description, "340282366920938463463374607431768211456" )
		XCTAssertEqual( T(130).pow2().description, "1361129467683753853853498429727072845824" )
		XCTAssertEqual( T(-1).pow2().description, "0.5" )
		XCTAssertEqual( T(-3).pow2().description, "0.125" )
		XCTAssertEqual( T(-10).pow2() * T(10).pow2(), 1 )
		XCTAssertTrue ( A("1.5").pow2().isNaN )

		/// The cached table is right
		var power = T(1)
		for i in 1...128 {
			power *= 2
			XCTAssertEqual( T(i).pow2(), power, "2^\(i)")
		}

		XCTAssertEqual( T(0).pow10().description, "1" )
		XCTAssertEqual( T(3).pow10().description, "1000" )
		XCTAssertEqual( T(-1).pow10().description, "0.1" )
		XCTAssertEqual( T(-5).pow10().description, "0.00001" )
		XCTAssertTrue ( A("1.5").pow10().isNaN )
	}

	func test_Raise_Shift_Clamp() throws {

		var a = T(7)
		a.raise(by: 0)
		XCTAssertEqual( a.description, "7" )
		a.raise(by: 3)
		XCTAssertEqual( a.description, "7000" )
		a.raise(by: -4)
		XCTAssertEqual( a.description, "0.7" )

		var b = A("1.5")
		b.raise(by: 2)
		XCTAssertEqual( b.description, "150" )

		var c = A("-0.05")
		c.shift(decimals: 2)
		XCTAssertEqual( c.description, "-5" )
		c.shift(decimals: -3)
		XCTAssertEqual( c.description, "-0.005" )

		var zero = T(0)
		zero.shift(decimals: 5)
		XCTAssertEqual( zero.description, "0" )

		var d = A("1.999")
		d.clamp(fraction: 2)
		XCTAssertEqual( d.description, "1.99" )
		d.clamp(fraction: 0)
		XCTAssertEqual( d.description, "1" )

		var e = A("-0.001")
		e.clamp(fraction: 2)
		XCTAssertEqual( e.description, "0" )
		XCTAssertFalse( e.isNegative )
	}

	func test_GeoMean_DigitalRoot() throws {

		XCTAssertEqual( T.geoMean([2, 8]).description, "4" )
		XCTAssertEqual( T.geoMean([1, 2, 4]).description, "2" )
		XCTAssertEqual( T.geoMean([5]).description, "5" )
		XCTAssertEqual( T.geoMean([]).description, "0" )
		XCTAssertEqual( T.geoMean([1, 10, 100, 1000]).description, "31.6227766016837933" )

		XCTAssertEqual( T(0).digitalRoot(), 0 )
		XCTAssertEqual( T(9).digitalRoot(), 9 )
		XCTAssertEqual( T(18).digitalRoot(), 9 )
		XCTAssertEqual( T(12345).digitalRoot(), 6 )
		XCTAssertEqual( A("99999999999999999999999999999999999999").digitalRoot(), 9 )
	}

	func test_Constants() throws {

		/// The long literals against each other: a typo would break the identity
		Arbit.precision = 995

		func cut(_ value: T, _ digits: Int) -> T { var v = value ; v.clamp(fraction: digits) ; return v }

		let pi = T.const(truncated: .pi, digits: 1000)
		let tau = T.const(truncated: .tau, digits: 1000)
		XCTAssertEqual( cut(pi * 2, 990), cut(tau, 990) )

		let sqr5 = T.const(truncated: .sqr5, digits: 1000)
		let phi = T.const(truncated: .phi, digits: 1000)
		XCTAssertEqual( cut((sqr5 + 1) / 2, 990), cut(phi, 990) )

		let sqr2 = T.const(truncated: .sqr2, digits: 1000)
		let silver = T.const(truncated: .silver, digits: 1000)
		XCTAssertEqual( cut(sqr2 + 1, 90), cut(silver, 90) )

		XCTAssertEqual( cut(sqr2 * sqr2, 990).description, "1." + String(repeating: "9", count: 990) )

		XCTAssertEqual( T.const(truncated: .pi, digits: 5).description, "3.14159" )
		XCTAssertEqual( T.const(truncated: .pi, digits: 0).description, "3" )
		XCTAssertEqual( T.const(truncated: .e, digits: 10).description, "2.7182818284" )
	}

	func test_Scientific_And_Subscript() throws {

		XCTAssertEqual( A("12345.678").getSientific().numbers, "1.2345678" )
		XCTAssertEqual( A("12345.678").getSientific().e, 4 )
		XCTAssertEqual( A("0.00123").getSientific().numbers, "1.23" )
		XCTAssertEqual( A("0.00123").getSientific().e, -3 )
		XCTAssertEqual( A("-0.00123").getSientific().numbers, "-1.23" )
		XCTAssertEqual( T(5).getSientific().numbers, "5" )
		XCTAssertEqual( T(5).getSientific().e, 0 )
		XCTAssertEqual( T(0).getSientific().numbers, "0" )
		XCTAssertEqual( T(0).getSientific().e, 0 )

		var value = A("12.34")
		XCTAssertEqual( value[0], "1" )
		XCTAssertEqual( value[1], "2" )
		XCTAssertEqual( value[3], "4" )
		value[1] = "9"
		value[2] = "0"
		XCTAssertEqual( value.description, "19.04" )
		XCTAssertEqual( value.count, 4 )
	}
}



// MARK: Binary

final class Test_Binary: ArbitTestCase {

	func test_Bitwise_Against_Int() throws {

		var generator = SeededGenerator(seed: 13)

		var pairs: [(Int, Int)] = [(5, 3), (0, 0), (-1, 255), (-255, 15), (-1, -1), (Int.max, Int.min), (Int.min, -1), (0, -1)]

		for _ in 1...100 {
			pairs.append( (Int.random(in: -1_000_000...1_000_000, using: &generator), Int.random(in: Int.min...Int.max, using: &generator)) )
		}

		for (a, b) in pairs {
			XCTAssertEqual( T(a) & T(b), T(a & b), "\(a) & \(b)")
			XCTAssertEqual( T(a) | T(b), T(a | b), "\(a) | \(b)")
			XCTAssertEqual( T(a) ^ T(b), T(a ^ b), "\(a) ^ \(b)")
			XCTAssertEqual( ~T(a), T(~a), "~\(a)")
		}

		var value = T(0b1100)
		value &= 0b1010
		XCTAssertEqual( value, 0b1000 )
		value |= 0b0001
		XCTAssertEqual( value, 0b1001 )
		value ^= 0b1111
		XCTAssertEqual( value, 0b0110 )
	}

	func test_Bitwise_Long() throws {

		let big = T(100).pow2()

		XCTAssertEqual( (big | 1) & 1, 1 )
		XCTAssertEqual( big & (big - 1), 0 )
		XCTAssertEqual( big ^ big, 0 )
		XCTAssertEqual( (big - 1) & 255, 255 )
		XCTAssertEqual( ~big, -big - 1 )
		XCTAssertEqual( ~(~big), big )
		XCTAssertEqual( (-big) & (big | 1), big )

		/// Fractions have no bits
		XCTAssertTrue( (A("1.5") & 1).isNaN )
		XCTAssertTrue( (T(1) | A("1.5")).isNaN )
		XCTAssertTrue( (~A("1.5")).isNaN )
		XCTAssertTrue( (A("1.5") << 1).isNaN )
	}

	func test_Shifts() throws {

		XCTAssertEqual( T(1) << 4, 16 )
		XCTAssertEqual( T(256) >> 4, 16 )
		XCTAssertEqual( T(5) >> 1, 2 )
		XCTAssertEqual( T(-5) >> 1, -3 )
		XCTAssertEqual( T(-5) << 1, -10 )
		XCTAssertEqual( T(-1) >> 10, -1 )
		XCTAssertEqual( T(1) >> 10, 0 )
		XCTAssertEqual( T(0) << 100, 0 )
		XCTAssertEqual( T(3) << 0, 3 )
		XCTAssertEqual( T(1) << 100, T(100).pow2() )
		XCTAssertEqual( T(100).pow2() >> 99, 2 )
		XCTAssertEqual( T(8) << -1, 4 )
		XCTAssertEqual( T(8) >> -1, 16 )

		for a in [-1000, -17, -1, 0, 1, 17, 1000, 123456789] {
			for n in 0...8 {
				XCTAssertEqual( T(a) << n, T(a << n), "\(a) << \(n)")
				XCTAssertEqual( T(a) >> n, T(a >> n), "\(a) >> \(n)")
			}
		}

		var value = T(1)
		value <<= 10
		XCTAssertEqual( value, 1024 )
		value >>= 3
		XCTAssertEqual( value, 128 )
	}

	func test_Words_And_Conversion() throws {

		XCTAssertEqual( T(0).words, [0] )
		XCTAssertEqual( T(5).words, [5] )
		XCTAssertEqual( T(-1).words, [UInt.max] )
		XCTAssertEqual( T(-2).words, [UInt.max - 1] )
		XCTAssertEqual( T(Int.max).words, [UInt(Int.max)] )
		XCTAssertEqual( T(Int.min).words.first, UInt(1) << 63 )
		XCTAssertEqual( T(UInt64.max).words, [UInt.max, 0] )
		XCTAssertEqual( T("18446744073709551616").words, [0, 1] )
		XCTAssertEqual( T("-18446744073709551616").words, [0, UInt.max] )

		XCTAssertEqual( T(5).bitWidth, 64 )
		XCTAssertEqual( T(UInt64.max).bitWidth, 128 )

		/// The standard library converts by the words
		XCTAssertEqual( Int(T(-42)), -42 )
		XCTAssertEqual( Int(T(Int.min)), Int.min )
		XCTAssertEqual( UInt64(T(UInt64.max)), UInt64.max )
		XCTAssertEqual( Int8(clamping: T(1000)), 127 )
		XCTAssertEqual( Int8(clamping: T(-1000)), -128 )
		XCTAssertEqual( UInt8(truncatingIfNeeded: T(257)), 1 )
		XCTAssertEqual( Int(exactly: T("99999999999999999999")), nil )
		XCTAssertEqual( Int(exactly: T(77)), 77 )

		XCTAssertEqual( T(exactly: 77 as Int8), 77 )
		XCTAssertEqual( T(truncatingIfNeeded: -77 as Int16), -77 )
		XCTAssertEqual( T(clamping: UInt64.max).description, "18446744073709551615" )

		XCTAssertEqual( T(8).trailingZeroBitCount, 3 )
		XCTAssertEqual( T(-8).trailingZeroBitCount, 3 )
		XCTAssertEqual( T(1).trailingZeroBitCount, 0 )
		XCTAssertEqual( T(100).pow2().trailingZeroBitCount, 100 )
		XCTAssertEqual( T(255).oneBitCount, 8 )
		XCTAssertEqual( T(0).oneBitCount, 0 )

		XCTAssertTrue ( T(7).isOdd )
		XCTAssertFalse( T(7).isEven )
		XCTAssertTrue ( T(-8).isEven )
		XCTAssertTrue ( T(0).isEven )
		XCTAssertFalse( A("7.5").isOdd )
		XCTAssertFalse( A("7.5").isEven )
	}

	func test_Stride_And_Range() throws {

		XCTAssertEqual( Array(stride(from: T(1), through: T(5), by: T(1))), [1, 2, 3, 4, 5] )
		XCTAssertEqual( Array(stride(from: T(10), to: T(0), by: T(-5))), [10, 5] )
		XCTAssertEqual( stride(from: A("0"), to: A("1"), by: A("0.25")).map(\.description), ["0", "0.25", "0.5", "0.75"] )

		var sum = T(0)
		for i in T(1)...T(100) { sum += i }
		XCTAssertEqual( sum, 5050 )

		XCTAssertEqual( Array(T(9)..<T(12)), [9, 10, 11] )
		XCTAssertTrue ( (T(9)...T(11)).contains(10) )
		XCTAssertTrue ( (T(9)...T(11)).contains(A("10.5")) )
		XCTAssertFalse( (T(9)...T(11)).contains(A("11.5")) )

		XCTAssertEqual( T(3).distance(to: 10), 7 )
		XCTAssertEqual( T(3).advanced(by: -5), -2 )
		XCTAssertEqual( [T(1), T(2), T(3)].reduce(0, +), 6 )
	}

	func test_Binary_Coded_Decimal() throws {

		XCTAssertEqual( T(1234).asBinaryCodedDecimal(), [0x12, 0x34] )
		XCTAssertEqual( T(123).asBinaryCodedDecimal(), [0x01, 0x23] )
		XCTAssertEqual( T(0).asBinaryCodedDecimal(), [0x00] )
		XCTAssertEqual( T(9).asBinaryCodedDecimal(), [0x09] )
		XCTAssertEqual( T(1234).asBinaryCodedDecimal(packed: false), [1, 2, 3, 4] )
	}
}
