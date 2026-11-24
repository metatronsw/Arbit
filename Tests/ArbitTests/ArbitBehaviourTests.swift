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

/// There are no global settings any more, the precision travels as a parameter
class ArbitTestCase: XCTestCase {}

/// Shorthands for the contexts
func halfUp(_ digits: Int) -> T.Context { T.Context(digits: digits, rounding: .halfUp) }
func halfEven(_ digits: Int) -> T.Context { T.Context(digits: digits, rounding: .halfEven) }



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
		
		/// The integer on the left side
		XCTAssertTrue ( five == T(5) )
		XCTAssertFalse( five == A("5.5") )
		XCTAssertTrue ( five != A("5.5") )
		XCTAssertTrue ( five < A("5.5") )
		XCTAssertTrue ( five <= T(5) )
		XCTAssertTrue ( five > A("4.5") )
		XCTAssertTrue ( five >= A("-4.5") )
		XCTAssertTrue ( UInt8(200) < A("200.5") )
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
		XCTAssertEqual( A("0.5").signum(), 1 )
		XCTAssertEqual( T(0).signum(), 0 )
		XCTAssertTrue ( T.nan.signum().isNaN )
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
		
		func divide(_ l: T, _ r: T, _ digits: Int) -> String { l.divided(by: r, .digits(digits)).description }
		
		XCTAssertEqual( divide(7, 2, 0), "3" )
		XCTAssertEqual( divide(-7, 2, 0), "-3" )
		XCTAssertEqual( divide(1, 3, 0), "0" )
		
		XCTAssertEqual( divide(7, 2, 1), "3.5" )
		XCTAssertEqual( divide(1, 3, 1), "0.3" )
		
		/// The operator and the missing parameter is the standard context: 16 digits, truncated
		XCTAssertEqual( (T(1) / T(3)).description, "0.3333333333333333" )
		XCTAssertEqual( (T(2) / T(3)).description, "0.6666666666666666" )
		XCTAssertEqual( T(1).divided(by: 7).description, "0.1428571428571428" )
		XCTAssertEqual( (T(1) / T(8)).description, "0.125" )
		XCTAssertEqual( T.Context.standard, T.Context(digits: 16, rounding: .truncate) )
		
		XCTAssertEqual( divide(1, 7, 50), "0.14285714285714285714285714285714285714285714285714" )
		XCTAssertEqual( divide(22, 7, 50), "3.14285714285714285714285714285714285714285714285714" )
		
		/// Fractions on both sides, different lengths
		XCTAssertEqual( divide("0.000001", "0.3", 10), "0.0000033333" )
		XCTAssertEqual( divide("1", "0.0000000000000000000003", 2), "3333333333333333333333.33" )
		XCTAssertEqual( divide("123.456789", "0.001", 3), "123456.789" )
		XCTAssertEqual( divide("0.00000000000000000000000001", "1000", 30), "0.00000000000000000000000000001" )
	}
	
	func test_Rounding_Modes() throws {
		
		func divide(_ l: T, _ r: T, _ digits: Int, _ mode: T.RoundingMode) -> String {
			l.divided(by: r, T.Context(digits: digits, rounding: mode)).description
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

		XCTAssertEqual( A("2.5").rounded(T.Context(digits: 0, rounding: .truncate)).description, "2" )
		XCTAssertEqual( A("2.5").rounded(T.Context(digits: 0, rounding: .halfUp)).description, "3" )
		XCTAssertEqual( A("2.5").rounded(T.Context(digits: 0, rounding: .halfEven)).description, "2" )
		XCTAssertEqual( A("3.5").rounded(T.Context(digits: 0, rounding: .halfEven)).description, "4" )
		XCTAssertEqual( A("2.51").rounded(T.Context(digits: 0, rounding: .halfEven)).description, "3" )
		XCTAssertEqual( A("-2.5").rounded(T.Context(digits: 0, rounding: .halfUp)).description, "-3" )

		XCTAssertEqual( A("2.45").rounded(T.Context(digits: 1, rounding: .halfUp)).description, "2.5" )
		XCTAssertEqual( A("2.449").rounded(T.Context(digits: 1, rounding: .halfUp)).description, "2.4" )
		XCTAssertEqual( A("9.99").rounded(T.Context(digits: 1, rounding: .halfUp)).description, "10" )
		XCTAssertEqual( A("-9.99").rounded(T.Context(digits: 1, rounding: .halfUp)).description, "-10" )
		XCTAssertEqual( A("0.0004").rounded(T.Context(digits: 1, rounding: .halfUp)).description, "0" )
		XCTAssertEqual( A("0.0005").rounded(T.Context(digits: 3, rounding: .halfUp)).description, "0.001" )

		/// Nothing to do
		XCTAssertEqual( A("1.5").rounded(T.Context(digits: 3, rounding: .halfUp)).description, "1.5" )
		XCTAssertEqual( T(15).rounded(T.Context(digits: 0, rounding: .halfUp)).description, "15" )

		/// The short forms
		XCTAssertEqual( A("1.2345").rounded(halfUp(3)).description, "1.235" )
		XCTAssertEqual( A("1.2345").rounded(.digits(3)).description, "1.234" )
		XCTAssertEqual( A("1.23456789012345678").rounded().description, "1.2345678901234567" )
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
		XCTAssertEqual( T(2).sqrRoot(.digits(0)).description, "1" )
		XCTAssertEqual( T(17).sqrRoot(.digits(0)).description, "4" )
		XCTAssertEqual( T(2).sqrRoot(.digits(5)).description, "1.41421" )

		/// Against the constants
		XCTAssertEqual( T(2).sqrRoot(.digits(100)), T.const(truncated: .sqr2, digits: 100) )
		XCTAssertEqual( T(3).sqrRoot(.digits(100)), T.const(truncated: .sqr3, digits: 100) )
		XCTAssertEqual( T(5).sqrRoot(.digits(100)), T.const(truncated: .sqr5, digits: 100) )

		/// More fraction digits than what is asked for
		XCTAssertEqual( A("2.0000000000000000000000000000001").sqrRoot(.digits(5)).description, "1.41421" )
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
		XCTAssertEqual( T(2).sqrRoot(halfUp(3)).description, "1.414" )
		XCTAssertEqual( T(2).sqrRoot(halfUp(4)).description, "1.4142" )
		XCTAssertEqual( T(2).sqrRoot(halfUp(7)).description, "1.4142136" )
		XCTAssertEqual( T(3).sqrRoot(halfUp(2)).description, "1.73" )
		XCTAssertEqual( T(8).sqrRoot(halfUp(2)).description, "2.83" )
		XCTAssertEqual( T(8).sqrRoot(halfUp(0)).description, "3" )
		
		/// Exactly half: √6.25 = 2.5
		XCTAssertEqual( A("6.25").sqrRoot(halfUp(0)).description, "3" )
		XCTAssertEqual( A("6.25").sqrRoot(halfEven(0)).description, "2" )
		XCTAssertEqual( A("12.25").sqrRoot(halfEven(0)).description, "4" )
		XCTAssertEqual( A("6.25").sqrRoot(.digits(0)).description, "2" )
		
		XCTAssertEqual( sqrt(T(2), halfUp(7)).description, "1.4142136" )
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
		XCTAssertEqual( T(10).root(3, .digits(0)).description, "2" )
		XCTAssertEqual( T(2).root(100, .digits(12)).description, "1.006955550056" )

		XCTAssertTrue( T(-16).root(4).isNaN )
		XCTAssertTrue( T(16).root(0).isNaN )

		/// Against the constants
		XCTAssertEqual( T(2).root(3, .digits(20)), T.const(truncated: .cubeRoot2, digits: 20) )
		XCTAssertEqual( T(3).root(3, .digits(60)), T.const(truncated: .cubeRoot3, digits: 60) )

		/// Rounding: ∛10 = 2.15443469…
		XCTAssertEqual( T(10).root(3, halfUp(2)).description, "2.15" )
		XCTAssertEqual( T(10).root(3, halfUp(3)).description, "2.154" )
		XCTAssertEqual( T(10).root(3, halfUp(5)).description, "2.15443" )
		XCTAssertEqual( T(10).root(3, halfUp(6)).description, "2.154435" )
		XCTAssertEqual( T(10).root(3, .digits(6)).description, "2.154434" )
		
		/// Exactly half: ∛3.375 = 1.5
		XCTAssertEqual( A("3.375").root(3, halfUp(0)).description, "2" )
		XCTAssertEqual( A("3.375").root(3, halfEven(0)).description, "2" )
		XCTAssertEqual( A("15.625").root(3, halfEven(0)).description, "2" )
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
		XCTAssertEqual( T(2).power(T(10)).description, "1024" )
		XCTAssertEqual( pow(T(2), T(-1)).description, "0.5" )
		XCTAssertEqual( T(3).power(-2, .digits(5)).description, "0.11111" )
		XCTAssertEqual( T(3).power(-2, halfUp(3)).description, "0.111" )
		XCTAssertEqual( T(3).power(-1, halfUp(3)).description, "0.333" )
		XCTAssertEqual( T(6).power(-1, halfUp(3)).description, "0.167" )

		/// 1/n exponent is the n-th root
		XCTAssertEqual( T(2).power(A("0.5")), sqrt(T(2)) )
		XCTAssertEqual( T(16).power(A("0.25")).description, "2" )
		XCTAssertEqual( T(32).power(A("0.2")).description, "2" )
		XCTAssertEqual( T(4).power(A("-0.5")).description, "0.5" )
		XCTAssertEqual( T(2).power(A("0.5"), .digits(30)).description, "1.414213562373095048801688724209" )

		/// Too big exponent
		XCTAssertTrue( T(2).power(A("99999999999999999999")).isNaN )
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
		
		/// The fraction digits count too
		XCTAssertEqual( A("1.5").digitalRoot(), 6 )
		XCTAssertEqual( A("0.9").digitalRoot(), 9 )
		XCTAssertEqual( A("123.456").digitalRoot(), 3 )
	}

	func test_Constants() throws {

		/// The long literals against each other: a typo would break the identity

		func cut(_ value: T, _ digits: Int) -> T { var v = value ; v.clamp(fraction: digits) ; return v }

		let pi = T.const(truncated: .pi, digits: 1000)
		let tau = T.const(truncated: .tau, digits: 1000)
		XCTAssertEqual( cut(pi * 2, 990), cut(tau, 990) )

		let sqr5 = T.const(truncated: .sqr5, digits: 1000)
		let phi = T.const(truncated: .phi, digits: 1000)
		XCTAssertEqual( cut((sqr5 + 1).divided(by: 2, .digits(995)), 990), cut(phi, 990) )

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

		/// To the integer types
		XCTAssertEqual( Int(T(-42)), -42 )
		XCTAssertEqual( Int(A("-42.9")), -42 )
		XCTAssertEqual( Int(exactly: A("42.5")), nil )
		XCTAssertEqual( Int(clamping: A("42.5")), 42 )
		XCTAssertEqual( Int(clamping: T.nan), 0 )
		XCTAssertEqual( Int(clamping: T.inf), Int.max )
		XCTAssertEqual( Int(clamping: -T.inf), Int.min )
		XCTAssertEqual( Int(clamping: A("-99999999999999999999999")), Int.min )
		XCTAssertEqual( UInt(clamping: T(-5)), 0 )
		XCTAssertEqual( Int8(truncatingIfNeeded: T(-1)), -1 )
		XCTAssertEqual( Int8(truncatingIfNeeded: T(255)), -1 )
		XCTAssertEqual( Int64(truncatingIfNeeded: T("18446744073709551617")), 1 )
		XCTAssertEqual( Int64(truncatingIfNeeded: T(-2)), -2 )
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

		/// Arbit is not an integer type, so a range of it cannot be walked: stride does it
		var sum = T(0)
		for i in stride(from: T(1), through: T(100), by: 1) { sum += i }
		XCTAssertEqual( sum, 5050 )

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



// MARK: Exponential, logarithm, trigonometry

final class Test_Functions: ArbitTestCase {
	
	/// (function, argument, fraction digits, the value cut to the digits) – calculated with an independent tool
	static let references: [(String, String, Int, String)] = [
		("exp", "1", 50, "2.71828182845904523536028747135266249775724709369995"),
		("exp", "-1", 30, "0.367879441171442321595523770161"),
		("exp", "0.5", 40, "1.6487212707001281468486507878141635716537"),
		("exp", "10", 25, "22026.4657948067165169579006452"),
		("exp", "-10", 30, "0.000045399929762484851535591515"),
		("exp", "100", 10, "26881171418161354484126255515800135873611118.7737419224"),
		("exp", "0.000001", 30, "1.000001000000500000166666708333"),
		("exp", "2.5", 16, "12.1824939607034734"),
		("exp", "-0.3", 16, "0.7408182206817178"),
		("exp", "123.456", 5, "413294435277809344957685441227343146614594393746575438.72529"),
		("ln", "2", 50, "0.69314718055994530941723212145817656807550013436025"),
		("ln", "10", 40, "2.3025850929940456840179914546843642076011"),
		("ln", "0.5", 30, "-0.693147180559945309417232121458"),
		("ln", "1.0001", 30, "0.00009999500033330833533316668"),
		("ln", "123456789", 25, "18.6314017661680180331939333"),
		("ln", "0.000123", 25, "-9.0033262025918566088459401"),
		("ln", "3", 16, "1.0986122886681096"),
		("ln", "7.389", 16, "1.9999924078065105"),
		("ln", "99999999999999999999999999", 20, "59.86721241784518778446"),
		("log10", "2", 40, "0.3010299956639811952137388947244930267681"),
		("log10", "50", 30, "1.698970004336018804786261105275"),
		("log10", "0.3", 25, "-0.522878745280337562704972"),
		("log2", "10", 30, "3.321928094887362347870319429489"),
		("log2", "3", 16, "1.5849625007211561"),
		("sin", "1", 50, "0.84147098480789650665250232163029899962256306079837"),
		("sin", "0.5", 30, "0.479425538604203000273287935215"),
		("sin", "-2", 30, "-0.909297426825681695396019865911"),
		("sin", "3", 30, "0.141120008059867222100744802808"),
		("sin", "100", 30, "-0.506365641109758793656557610459"),
		("sin", "1000000", 25, "-0.3499935021712929521176524"),
		("sin", "0.0001", 30, "0.000099999999833333333416666666"),
		("sin", "4", 16, "-0.7568024953079282"),
		("cos", "1", 50, "0.54030230586813971740093660744297660373231042061792"),
		("cos", "0.5", 30, "0.877582561890372716116281582603"),
		("cos", "-2", 30, "-0.4161468365471423869975682295"),
		("cos", "3", 30, "-0.989992496600445457271572794731"),
		("cos", "100", 30, "0.86231887228768393410193851395"),
		("cos", "1000000", 25, "0.9367521275331447869385325"),
		("cos", "4", 16, "-0.6536436208636119"),
		("tan", "1", 40, "1.5574077246549022305069748074583601730872"),
		("tan", "0.5", 30, "0.54630248984379051325517946578"),
		("tan", "-2", 25, "2.1850398632615189916433061"),
		("tan", "1.5", 25, "14.1014199471717193876460836"),
		("tan", "100", 20, "-0.58721391515692907667"),
		("atan", "1", 50, "0.78539816339744830961566084581987572104929234984377"),
		("atan", "0.5", 40, "0.4636476090008061162142562314612144020285"),
		("atan", "-3", 30, "-1.249045772398254425829917077281"),
		("atan", "0.01", 30, "0.009999666686665238206340116209"),
		("atan", "1000", 30, "1.569796327128229752564797882004"),
		("atan", "0.9", 16, "0.7328151017865065"),
		("asin", "0.5", 40, "0.5235987755982988730771072305465838140328"),
		("asin", "-0.9", 30, "-1.119769514998634186686677055845"),
		("asin", "0.1", 25, "0.1001674211615597963455231"),
		("acos", "0.5", 40, "1.0471975511965977461542144610931676280657"),
		("acos", "-0.9", 30, "2.690565841793530805917998747485"),
		("acos", "0.1", 25, "1.4706289056333368228857985"),
		("sinh", "1", 40, "1.1752011936438014568823818505956008151557"),
		("sinh", "-2.5", 30, "-6.05020448103978732145032363835"),
		("cosh", "1", 40, "1.5430806348152437784779056207570616826015"),
		("cosh", "-2.5", 30, "6.132289479663686116619852312817"),
		("tanh", "1", 40, "0.7615941559557648881194582826047935904127"),
		("tanh", "-0.3", 30, "-0.291312612451590905818221272823"),
		("tanh", "5", 25, "0.9999092042625951312109904"),
		("toRadians", "180", 40, "3.1415926535897932384626433832795028841971"),
		("toRadians", "45", 30, "0.785398163397448309615660845819"),
		("toDegrees", "1", 30, "57.295779513082320876798154814105"),
		("toDegrees", "3.14159", 20, "179.99984796050428844334"),
	]
	
	static func call(_ name: String, _ x: T, _ context: T.Context) -> T {
		switch name {
			case "exp": return x.exp(context)
			case "ln": return x.ln(context)
			case "log10": return x.log10(context)
			case "log2": return x.log2(context)
			case "sin": return x.sin(context)
			case "cos": return x.cos(context)
			case "tan": return x.tan(context)
			case "atan": return x.atan(context)
			case "asin": return x.asin(context)
			case "acos": return x.acos(context)
			case "sinh": return x.sinh(context)
			case "cosh": return x.cosh(context)
			case "tanh": return x.tanh(context)
			case "toRadians": return x.toRadians(context)
			case "toDegrees": return x.toDegrees(context)
			default: return .nan
		}
	}
	
	func test_Against_References() throws {
		
		for (name, argument, digits, expected) in Self.references {
			let result = Self.call(name, A(argument), .digits(digits))
			
			XCTAssertEqual( result.description, expected, "\(name)(\(argument)) on \(digits) digits")
			assertCanonical(result, "\(name)(\(argument))")
		}
	}
	
	func test_Rounding_Is_Not_More_Than_One_Unit() throws {
		
		/// The rounded value is the truncated one, or one unit of the last digit bigger in absolute value
		for (name, argument, digits, expected) in Self.references where digits >= 10 {
			
			let cut = digits - 5
			var truncated = A(expected)
			truncated.clamp(fraction: cut)
			
			let unit = T(-cut).pow10()
			
			for context in [halfUp(cut), halfEven(cut)] {
				let result = Self.call(name, A(argument), context)
				let difference = (result - truncated).magnitude
				
				XCTAssertTrue( difference == 0 || difference == unit, "\(name)(\(argument)): \(result) vs \(truncated)")
			}
		}
	}
	
	func test_Exp_Ln_Special() throws {
		
		XCTAssertEqual( T(0).exp().description, "1" )
		XCTAssertEqual( T(1).exp(.digits(30)), T.const(truncated: .e, digits: 30) )
		XCTAssertEqual( T(1).exp(.digits(500)), T.const(truncated: .e, digits: 500) )
		XCTAssertEqual( exp(T(1)).description, "2.7182818284590452" )
		XCTAssertEqual( T(-1000).exp().description, "0" )
		XCTAssertEqual( T(10_000_000).exp().description, "inf" )
		XCTAssertEqual( T(-10_000_000).exp().description, "0" )
		XCTAssertEqual( T.inf.exp().description, "inf" )
		XCTAssertEqual( (-T.inf).exp().description, "0" )
		XCTAssertTrue ( T.nan.exp().isNaN )
		
		XCTAssertEqual( T(1).ln().description, "0" )
		XCTAssertEqual( T(0).ln().description, "-inf" )
		XCTAssertTrue ( T(-1).ln().isNaN )
		XCTAssertEqual( T.inf.ln().description, "inf" )
		XCTAssertEqual( T(2).ln(.digits(500)), T.const(truncated: .ln2, digits: 500) )
		XCTAssertEqual( log(T(2)).description, "0.6931471805599453" )
		
		/// Exact results stay exact
		XCTAssertEqual( T(100).log10().description, "2" )
		XCTAssertEqual( T(1000).log10(.digits(40)).description, "3" )
		XCTAssertEqual( A("0.001").log10().description, "-3" )
		XCTAssertEqual( T(1).log10().description, "0" )
		XCTAssertEqual( T(1024).log2().description, "10" )
		XCTAssertEqual( A("0.125").log2().description, "-3" )
		XCTAssertEqual( T(81).log(base: 3).description, "4" )
		XCTAssertEqual( T(8).log(base: A("0.5")).description, "-3" )
		XCTAssertEqual( T(2).log(base: 10, .digits(20)), T(2).log10(.digits(20)) )
		
		XCTAssertTrue( T(8).log(base: 1).isNaN )
		XCTAssertTrue( T(8).log(base: 0).isNaN )
		XCTAssertTrue( T(8).log(base: -2).isNaN )
		XCTAssertTrue( T(-8).log10().isNaN )
	}
	
	func test_Exp_Ln_Inverse() throws {
		
		var generator = SeededGenerator(seed: 21)
		
		for _ in 1...25 {
			let x = A(randomNumber(&generator, int: 0...3, frc: 1...8, signed: false)) + A("0.001")
			
			/// ln(e^x) = x  and  e^ln(x) = x , with some guard digits between
			XCTAssertEqual( x.exp(.digits(40)).ln(.digits(25)), x, "ln(exp(\(x)))")
			XCTAssertEqual( x.ln(.digits(40)).exp(.digits(25)), x, "exp(ln(\(x)))")
		}
		
		/// e^(a+b) = e^a × e^b
		let (a, b) = (A("1.25"), A("2.5"))
		XCTAssertEqual( (a + b).exp(.digits(30)), (a.exp(.digits(40)) * b.exp(.digits(40))).rounded(.digits(30)) )
		
		/// ln(a × b) = ln(a) + ln(b)
		XCTAssertEqual( (a * b).ln(.digits(30)), (a.ln(.digits(40)) + b.ln(.digits(40))).rounded(.digits(30)) )
	}
	
	func test_Trigonometry_Special() throws {
		
		XCTAssertEqual( T(0).sin().description, "0" )
		XCTAssertEqual( T(0).cos().description, "1" )
		XCTAssertEqual( T(0).tan().description, "0" )
		XCTAssertEqual( T(0).atan().description, "0" )
		XCTAssertEqual( T(0).asin().description, "0" )
		
		let pi = T.const(truncated: .pi, digits: 60)
		
		/// The angle is not exactly π (it is cut), so the result is not exactly zero, only on the asked digits
		XCTAssertEqual( pi.sin(.digits(40)).description, "0" )
		XCTAssertEqual( pi.cos(.digits(40)).description, "-1" )
		XCTAssertEqual( (pi / 2).sin().description, "1" )
		XCTAssertEqual( pi.divided(by: 6, .digits(60)).sin(.digits(40)).description, "0.5" )
		XCTAssertEqual( pi.divided(by: 3, .digits(60)).cos(.digits(40)).description, "0.5" )
		XCTAssertEqual( pi.divided(by: 4, .digits(60)).tan(.digits(40)).description, "1" )
		
		/// Inverses of the known values
		/// (the multiplication makes the cut bigger, so it is calculated with more digits and cut after)
		XCTAssertEqual( (T(1).atan(.digits(55)) * 4).rounded(.digits(50)), T.const(truncated: .pi, digits: 50) )
		XCTAssertEqual( (T(1).asin(.digits(55)) * 2).rounded(.digits(50)), T.const(truncated: .pi, digits: 50) )
		XCTAssertEqual( T(-1).acos(.digits(50)), T.const(truncated: .pi, digits: 50) )
		XCTAssertEqual( T(1).acos().description, "0" )
		XCTAssertEqual( (A("0.5").asin(.digits(45)) * 6).rounded(.digits(40)), T.const(truncated: .pi, digits: 40) )
		
		XCTAssertTrue( A("1.0001").asin().isNaN )
		XCTAssertTrue( T(-2).acos().isNaN )
		XCTAssertTrue( T.nan.sin().isNaN )
		XCTAssertTrue( T.inf.cos().isNaN )
		XCTAssertEqual( (T.inf.atan(.digits(35)) * 2).rounded(.digits(30)), T.const(truncated: .pi, digits: 30) )
		
		/// Global forms
		XCTAssertEqual( sin(T(1)).description, "0.8414709848078965" )
		XCTAssertEqual( cos(T(1)).description, "0.5403023058681397" )
		XCTAssertEqual( atan(T(1), .digits(10)).description, "0.7853981633" )
		
		/// Degrees
		XCTAssertEqual( T(180).toRadians(.digits(50)), T.const(truncated: .pi, digits: 50) )
		XCTAssertEqual( T(90).toRadians(.digits(30)).sin(.digits(20)).description, "1" )
		XCTAssertEqual( T.const(truncated: .pi, digits: 60).toDegrees(.digits(40)).description, "180" )
	}
	
	func test_Trigonometry_Identities() throws {
		
		var generator = SeededGenerator(seed: 22)
		let ctx = T.Context.digits(40)
		
		for _ in 1...20 {
			let x = A(randomNumber(&generator, int: 0...2, frc: 1...6))
			let (sin, cos) = (x.sin(ctx), x.cos(ctx))
			
			/// sin² + cos² = 1
			XCTAssertEqual( (sin * sin + cos * cos).rounded(halfUp(30)), 1, "sin² + cos² of \(x)")
			
			/// Odd and even
			XCTAssertEqual( (-x).sin(ctx), -sin )
			XCTAssertEqual( (-x).cos(ctx), cos )
			
			/// tan = sin / cos
			XCTAssertEqual( x.tan(.digits(20)), sin.divided(by: cos, .digits(30)).rounded(.digits(20)), "tan(\(x))" )
		}
		
		/// Inverse on the main range
		for string in ["0.1", "-0.5", "0.9", "1.2", "-1.5"] {
			let x = A(string)
			XCTAssertEqual( x.tan(.digits(50)).atan(.digits(30)), x, "atan(tan(\(x)))")
			XCTAssertEqual( x.sin(.digits(50)).asin(.digits(20)), x, "asin(sin(\(x)))")
		}
		
		/// atan2 by the quadrants: n × π / 4
		let pi = T.const(truncated: .pi, digits: 60)
		func quarters(_ count: Int) -> T { (pi * T(count)).divided(by: 4, .digits(30)) }
		
		XCTAssertEqual( T.atan2(1, 1, .digits(30)), quarters(1) )
		XCTAssertEqual( T.atan2(1, -1, .digits(30)), quarters(3) )
		XCTAssertEqual( T.atan2(-1, -1, .digits(30)), quarters(-3) )
		XCTAssertEqual( T.atan2(-1, 1, .digits(30)), quarters(-1) )
		XCTAssertEqual( T.atan2(1, 0, .digits(30)), quarters(2) )
		XCTAssertEqual( T.atan2(-1, 0, .digits(30)), quarters(-2) )
		XCTAssertEqual( T.atan2(0, 0).description, "0" )
		XCTAssertEqual( T.atan2(0, 5).description, "0" )
		XCTAssertEqual( atan2(T(0), T(-5), .digits(30)), T.const(truncated: .pi, digits: 30) )
		
		/// cosh² - sinh² = 1
		let x = A("1.75")
		let (sinh, cosh) = (x.sinh(ctx), x.cosh(ctx))
		XCTAssertEqual( (cosh * cosh - sinh * sinh).rounded(halfUp(30)), 1 )
		XCTAssertEqual( x.tanh(.digits(20)), sinh.divided(by: cosh, .digits(30)).rounded(.digits(20)) )
		XCTAssertEqual( T(0).sinh().description, "0" )
		XCTAssertEqual( T(0).cosh().description, "1" )
		XCTAssertEqual( T(0).tanh().description, "0" )
		XCTAssertEqual( T(1000).tanh().description, "1" )
	}
	
	func test_Constants_Over_The_Stored_Length() throws {
		
		/// Over the stored length the constants are calculated; the stored and the calculated one must meet
		let stored = T.const(truncated: .pi, digits: 990)
		var calculated = T.pi(digits: 1200)
		XCTAssertTrue( calculated.description.hasSuffix("889075098381754637464939319255060400927701671139009848824012") )
		calculated.clamp(fraction: 990)
		XCTAssertEqual( calculated, stored )
		
		XCTAssertTrue( T.ln2(digits: 1200).description.hasSuffix("948793067865158870900605203468429736193841289652556539686022") )
		
		var ln10 = T.ln10(digits: 60)
		ln10.clamp(fraction: 50)
		XCTAssertEqual( ln10.description, "2.30258509299404568401799145468436420760110148862877" )
	}
	
	func test_General_Power() throws {
		
		/// (base, exponent, fraction digits, value)
		let cases: [(String, String, Int, String)] = [
		("2", "0.3", 16, "1.2311444133449162"),
		("2", "1.5", 16, "2.82842712474619"),
		("10", "0.3010299956639812", 12, "2"),
		("2.5", "3.7", 30, "29.674132536420854480852221606697"),
		("0.5", "2.25", 25, "0.2102241038134286357577813"),
		("123.456", "-1.5", 20, "0.00072900699845598761"),
		("2", "-0.3", 20, "0.8122523963562355226"),
		("7", "0.3333333333", 20, "1.9129311826483093611"),
			("9", "1.5", 20, "27"),
			("4", "2.5", 20, "32"),
			("0.25", "1.5", 20, "0.125"),
		]
		
		for (base, exponent, digits, expected) in cases {
			XCTAssertEqual( A(base).power(A(exponent), .digits(digits)).description, expected, "\(base) ^ \(exponent)")
		}
		
		XCTAssertEqual( T(0).power(A("1.5")).description, "0" )
		XCTAssertTrue ( T(0).power(A("-1.5")).isNaN )
		XCTAssertTrue ( T(-2).power(A("1.5")).isNaN )
		XCTAssertEqual( T(-8).power(A("0.2")).description, "-1.515716566510398" )
		
		/// The operator: stronger than the multiplication, and from the right
		XCTAssertEqual( T(2) ** 10, 1024 )
		XCTAssertEqual( T(2) ** T(10), 1024 )
		XCTAssertEqual( T(2) ** -1, A("0.5") )
		XCTAssertEqual( T(2) * T(3) ** 2, 18 )
		XCTAssertEqual( T(2) ** 3 ** 2, 512 )
		XCTAssertEqual( T(1) + T(2) ** 3, 9 )
		XCTAssertEqual( T(16) ** A("0.5"), 4 )
		XCTAssertEqual( (T(2) ** A("0.3")).description, "1.2311444133449162" )
		
		var value = T(3)
		value **= 4
		XCTAssertEqual( value, 81 )
	}
}



// MARK: Integer functions

final class Test_IntegerFunctions: ArbitTestCase {
	
	func test_Floor_Ceil_Truncated() throws {
		
		/// (number, floor, ceil, truncated)
		let cases: [(String, String, String, String)] = [
			("2.5", "2", "3", "2"),
			("-2.5", "-3", "-2", "-2"),
			("2", "2", "2", "2"),
			("-2", "-2", "-2", "-2"),
			("0.001", "0", "1", "0"),
			("-0.001", "-1", "0", "0"),
			("0", "0", "0", "0"),
			("99999999999999999999.9", "99999999999999999999", "100000000000000000000", "99999999999999999999"),
			("-99999999999999999999.9", "-100000000000000000000", "-99999999999999999999", "-99999999999999999999"),
		]
		
		for (number, floored, ceiled, truncated) in cases {
			XCTAssertEqual( A(number).floor().description, floored, "floor \(number)")
			XCTAssertEqual( A(number).ceil().description, ceiled, "ceil \(number)")
			XCTAssertEqual( A(number).truncated().description, truncated, "truncated \(number)")
			
			assertCanonical(A(number).ceil())
			assertCanonical(A(number).truncated())
		}
		
		XCTAssertEqual( floor(A("-0.5")), -1 )
		XCTAssertEqual( ceil(A("0.5")), 1 )
		XCTAssertTrue ( T.nan.floor().isNaN )
		XCTAssertEqual( T.inf.ceil().description, "inf" )
	}
	
	func test_Factorial() throws {
		
		XCTAssertEqual( T(0).factorial(), 1 )
		XCTAssertEqual( T(1).factorial(), 1 )
		XCTAssertEqual( T(5).factorial(), 120 )
		XCTAssertEqual( T(20).factorial().description, "2432902008176640000" )
		XCTAssertEqual( T(30).factorial().description, "265252859812191058636308480000000" )
		XCTAssertEqual( T(100).factorial().description, "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000" )
		XCTAssertEqual( T(1000).factorial().count, 2568 )
		
		XCTAssertTrue( T(-1).factorial().isNaN )
		XCTAssertTrue( A("2.5").factorial().isNaN )
		XCTAssertTrue( T.nan.factorial().isNaN )
	}
	
	func test_Gcd_Lcm() throws {
		
		XCTAssertEqual( T.gcd(12, 18), 6 )
		XCTAssertEqual( T.gcd(-12, 18), 6 )
		XCTAssertEqual( T.gcd(12, -18), 6 )
		XCTAssertEqual( T.gcd(17, 5), 1 )
		XCTAssertEqual( T.gcd(0, 5), 5 )
		XCTAssertEqual( T.gcd(5, 0), 5 )
		XCTAssertEqual( T.gcd(0, 0), 0 )
		XCTAssertEqual( T.gcd(A("123456789012345678901234567890"), A("987654321098765432109876543210")).description, "9000000000900000000090" )
		
		XCTAssertEqual( T.lcm(4, 6), 12 )
		XCTAssertEqual( T.lcm(-4, 6), 12 )
		XCTAssertEqual( T.lcm(0, 6), 0 )
		XCTAssertEqual( T.lcm(7, 13), 91 )
		XCTAssertEqual( T.lcm(A("123456789012345678901234567890"), A("987654321098765432109876543210")).description, "13548070124980948012498094801236261410" )
		
		XCTAssertTrue( T.gcd(A("1.5"), 3).isNaN )
		XCTAssertTrue( T.lcm(3, A("1.5")).isNaN )
		XCTAssertTrue( T.gcd(T.nan, 3).isNaN )
		
		/// gcd × lcm = |a × b|
		var generator = SeededGenerator(seed: 23)
		for _ in 1...30 {
			let a = A(randomNumber(&generator, int: 1...30))
			let b = A(randomNumber(&generator, int: 1...30))
			XCTAssertEqual( T.gcd(a, b) * T.lcm(a, b), (a * b).magnitude, "\(a), \(b)")
			XCTAssertTrue( a.isMultiple(of: T.gcd(a, b)) )
		}
	}
}



// MARK: Text forms

final class Test_Text: ArbitTestCase {
	
	func test_Scientific() throws {
		
		let cases: [(String, String)] = [
			("0", "0e0"), ("5", "5e0"), ("-5", "-5e0"), ("10", "1e1"), ("100", "1e2"), ("12345.678", "1.2345678e4"),
			("0.00123", "1.23e-3"), ("-0.00123", "-1.23e-3"), ("0.5", "5e-1"), ("1.5", "1.5e0"),
			("123456789012345678901234567890", "1.2345678901234567890123456789e29"),
		]
		
		for (number, expected) in cases {
			let text = A(number).scientific()
			
			XCTAssertEqual( text, expected, number)
			XCTAssertEqual( T(text), A(number), "round trip of \(number)")
		}
		
		/// Limited significant digits
		XCTAssertEqual( A("12345.678").scientific(significant: 3), "1.23e4" )
		XCTAssertEqual( A("12355.678").scientific(significant: 3, rounding: .halfUp), "1.24e4" )
		XCTAssertEqual( A("9999").scientific(significant: 2, rounding: .halfUp), "1e4" )
		XCTAssertEqual( A("0.000999").scientific(significant: 1, rounding: .halfUp), "1e-3" )
		XCTAssertEqual( A("1.5").scientific(significant: 5), "1.5e0" )
		
		XCTAssertEqual( T.nan.scientific(), "nan" )
		XCTAssertEqual( (-T.inf).scientific(), "-inf" )
	}
	
	func test_Codable() throws {
		
		struct Invoice: Codable, Equatable {
			var total: Arbit
			var items: [Arbit]
		}
		
		let invoice = Invoice(total: A("-123456789012345678901234567890.000000000000000000001"),
									 items: [0, A("0.1"), T(1) / T(3), .inf])
		
		let data = try JSONEncoder().encode(invoice)
		let json = String(decoding: data, as: UTF8.self)
		
		XCTAssertTrue( json.contains("\"-123456789012345678901234567890.000000000000000000001\"") )
		XCTAssertTrue( json.contains("\"0.3333333333333333\"") )
		
		XCTAssertEqual( try JSONDecoder().decode(Invoice.self, from: data), invoice )
		
		/// nan is not equal to itself, so it is checked alone
		let nan = try JSONDecoder().decode([Arbit].self, from: try JSONEncoder().encode([T.nan]))
		XCTAssertEqual( nan.first?.isNaN, true )
		
		XCTAssertEqual( try JSONDecoder().decode([Arbit].self, from: Data("[\"1.50\", \"1e3\"]".utf8)), [A("1.5"), 1000] )
		XCTAssertThrowsError( try JSONDecoder().decode([Arbit].self, from: Data("[\"abc\"]".utf8)) )
	}
	
	func test_Sendable_And_Threads() throws {
		
		/// No shared mutable state: the same calculation on many threads gives the same result
		let expected = T(2).sqrRoot(.digits(200))
		let results = UnsafeMutablePointer<Bool>.allocate(capacity: 16)
		results.initialize(repeating: false, count: 16)
		defer { results.deallocate() }
		
		DispatchQueue.concurrentPerform(iterations: 16) { index in
			let digits = index % 2 == 0 ? 200 : 50
			let value = T(2).sqrRoot(.digits(digits)) + T(1).divided(by: 3, .digits(digits)) - T(1).divided(by: 3, .digits(digits))
			results[index] = digits == 200 ? value == expected : value == expected.rounded(.digits(50))
		}
		
		XCTAssertTrue( (0..<16).allSatisfy { results[$0] } )
		
		func send<Value: Sendable>(_ value: Value) -> Value { value }
		XCTAssertEqual( send(T(5)), 5 )
		XCTAssertEqual( send(T.Context.digits(3)).digits, 3 )
	}
}



// MARK: Long numbers

final class Test_Long: ArbitTestCase {
	
	func test_Long_Mul_Div_Round_Trip() throws {
		
		var generator = SeededGenerator(seed: 31)
		
		for digits in [19, 27, 36, 100, 500, 2000] {
			for _ in 1...4 {
				let a = A(randomNumber(&generator, int: digits...digits))
				let b = A(randomNumber(&generator, int: (digits / 2)...digits))
				let c = A(randomNumber(&generator, int: 1...(digits / 2), signed: false))
				
				let product = a * b
				let (q, r) = (product + c).quotientAndRemainder(dividingBy: b)
				
				/// c is shorter than b, so the quotient is a and the remainder is c (with the sign of the dividend)
				XCTAssertEqual( product / b, a, "\(digits) digits")
				XCTAssertEqual( q * b + r, product + c, "\(digits) digits")
				XCTAssertTrue( r.magnitude < b.magnitude )
				
				if digits <= 100 { XCTAssertEqual( T.karatsuba(a, b), product, "\(digits) digits") }
			}
		}
	}
	
	func test_Long_Slices() throws {
		
		/// The edges of the 9 digit slices
		let nines = A(String(repeating: "9", count: 27))
		
		XCTAssertEqual( (nines * nines).description, String(repeating: "9", count: 26) + "8" + String(repeating: "0", count: 26) + "1" )
		XCTAssertEqual( (nines + 1).description, "1" + String(repeating: "0", count: 27) )
		XCTAssertEqual( (nines * nines) / nines, nines )
		XCTAssertEqual( ((nines + 1) * (nines + 1)) / (nines + 1), nines + 1 )
		
		let big = A("1" + String(repeating: "0", count: 45))
		XCTAssertEqual( (big - 1).quotientAndRemainder(dividingBy: A("1" + String(repeating: "0", count: 27))).quotient.description,
							 String(repeating: "9", count: 18) )
		XCTAssertEqual( (big - 1).quotientAndRemainder(dividingBy: A("1" + String(repeating: "0", count: 27))).remainder.description,
							 String(repeating: "9", count: 27) )
		
		/// The estimation of the quotient slice needs correction here
		let a = A("999999999999999999999999999000000000000000000000000000")
		let b = A("999999999999999999999999999")
		XCTAssertEqual( (a / b).description, "1000000000000000000000000000" )
		XCTAssertEqual( (A("500000000000000000000000000") * 2 - 1).quotientAndRemainder(dividingBy: A("500000000000000000000000000")).quotient, 1 )
	}
	
	func test_Long_Conversions() throws {
		
		var generator = SeededGenerator(seed: 32)
		
		for digits in [1, 9, 10, 19, 100, 1000] {
			let value = A(randomNumber(&generator, int: digits...digits, signed: false))
			
			XCTAssertEqual( T(bin: value.asBinary()), value, "\(digits) digits")
			XCTAssertEqual( T(hex: value.asHexadecimal()), value, "\(digits) digits")
			XCTAssertEqual( value.asBinary().count, value.asHexadecimal().binToDec().isEmpty ? 0 : value.asBinary().count )
		}
		
		XCTAssertEqual( T(4096).pow2().asHexadecimal(), "1" + String(repeating: "0", count: 1024) )
		XCTAssertEqual( T(4096).pow2().asBinary().count, 4097 )
		XCTAssertEqual( (T(64).pow2() - 1).asBinary(), String(repeating: "1", count: 64) )
		XCTAssertEqual( T(32).pow2().asBinary(), "1" + String(repeating: "0", count: 32) )
		XCTAssertEqual( T(32).pow2().asHexadecimal(), "100000000" )
		XCTAssertEqual( (T(32).pow2() - 1).asHexadecimal(), "FFFFFFFF" )
		XCTAssertEqual( "100000000000000000000000000000000".binToDec(), "4294967296" )
		XCTAssertEqual( "".binToDec(), "0" )
	}
}
