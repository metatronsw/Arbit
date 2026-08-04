import XCTest
@testable import Arbit

typealias T = Arbit

let iteration = 100


func randInt(digits: ClosedRange<Int>) -> Int {
	Int.random(in: digits.lowerBound.pow10 ... Int.random(in: digits.lowerBound.pow10 + 1 ... digits.upperBound.pow10 ) )
}

func rndStr(_ n: Int) -> String {
	return String.random(numbers: n)
}

func randPair(_ lhs: ClosedRange<Int>, _ rhs: ClosedRange<Int>) -> (lStr: String, rStr: String) {
	
	let lStr = rndStr(Int.random(in: lhs))
	let rStr = rndStr(Int.random(in: rhs))
	
	return (lStr, rStr)
}






final class Test_Arbit: XCTestCase {
	
	func test_Init_Literal_Int() throws {
		
		XCTAssertEqual( T(0), 0)
		XCTAssertEqual( T(integerLiteral: 0), 0)
		
		XCTAssertEqual( T(12345),   12345 )
		XCTAssertEqual( T(integerLiteral: 12345), 12345)
		
		XCTAssertEqual( T(-12345),   -12345 )
		XCTAssertEqual( T(integerLiteral: -12345), -12345)
		
		XCTAssertEqual( T(1_000), 1000)
		XCTAssertEqual( T(integerLiteral: 1_000), 1000)
		
		XCTAssertEqual( T(1000_000), 1000000)
		XCTAssertEqual( T(integerLiteral: 1000_000), 1000000)
		
		XCTAssertEqual( T(922_337_203_685_475), 922337203685475)
		XCTAssertEqual( T(integerLiteral: 922_337_203_685_475), 922337203685475)
		
		let intA:Arbit = 922_337_203_685_475
		let intB = 922_337_203_685_475 as Arbit
		XCTAssertEqual( intA, 922337203685475)
		XCTAssertEqual( intB, 922337203685475)
		
	}
	
	func test_Init_Literal_Float() throws {
		
		XCTAssertEqual( T(0.1),    0.1 )
		XCTAssertEqual( T(-0.1),  -0.1 )
		XCTAssertEqual( T(0.001),   0.001)
		XCTAssertEqual( T(-0.001), -0.001)
		
		XCTAssertEqual( T(32.12),    32.12 )
		XCTAssertEqual( T(-32.12),  -32.12 )
		
		XCTAssertEqual( T(12345.6789),   12345.6789 )
		XCTAssertEqual( T(-12345.6789), -12345.6789 )
		
	}
	
	func test_Init_Integer() throws {
		
		var int: Int
		
		int = 0
		XCTAssertEqual( T(int), "0")
		
		int = -0
		XCTAssertEqual( T(int), "0")
		
		int = 12345
		XCTAssertEqual( T(int),  "12345" )
		
		int = -12345
		XCTAssertEqual( T(int), "-12345" )
		
		XCTAssertEqual( T(UInt8.max),  "255" )
		XCTAssertEqual( T(Int8.min),   "-128" )
		
		XCTAssertEqual( T(UInt16.max),  "65535" )
		XCTAssertEqual( T(Int16.min),  "-32768" )
		
		XCTAssertEqual( T(UInt32.max),  "4294967295" )
		XCTAssertEqual( T(Int32.min),  "-2147483648" )
		
		XCTAssertEqual( T(Int64.max),   "9223372036854775807" )
		XCTAssertEqual( T(Int64.min),  "-9223372036854775808" )
		
		XCTAssertEqual( T(UInt64.max),  "18446744073709551615" )
		XCTAssertEqual( T(UInt64.min),  "0" )
		
	}
	
	func test_Init_Double() throws {
		
		XCTAssertEqual( T(Double(1)), "1.0")
		XCTAssertEqual( T(Double(1)), "1.0")
		XCTAssertEqual( T(Double(10)), "10.0")
		XCTAssertEqual( T(Double(0.1)), "0.1")
		XCTAssertEqual( T(Double(10.01)), "10.01")
		XCTAssertEqual( T(Double(11.222)), "11.222")
		XCTAssertEqual( T(Double(12345.6789)), "12345.6789")
		
		XCTAssertEqual( T(Double(123456789012345.123456789)), "123456789012345.12") // Rounded...
		
		XCTAssertEqual( T(Double(9999999999999.99)), "9999999999999.99")
		XCTAssertEqual( T(Double(999999999999999.999999999)), "1000000000000000") // Rounded...
		
		XCTAssertEqual( T(Double(UInt8.max)),  "255")
		XCTAssertEqual( T(Double(UInt16.max)), "65535")
		XCTAssertEqual( T(Double(UInt32.max)), "4294967295")
		
		XCTAssertEqual( T(Double(Int8.min)),  "-128")
		XCTAssertEqual( T(Double(Int16.min)), "-32768")
		XCTAssertEqual( T(Double(Int32.min)), "-2147483648")
		
		XCTAssertEqual( T(Double(Int64.max)),  "9223372036854776000")  // Rounded from 9223372036854775807
		XCTAssertEqual( T(Double(Int64.min)), "-9223372036854776000") // Rounded from -9223372036854775808
		
		XCTAssertEqual( T(Double(UInt64.max)), "18446744073709552000") // Rounded from 18446744073709551615
		
		
		// let inf = pow(9999999999999.0, 99.0)
		let inf = Double.infinity
		XCTAssertEqual( T(inf).description, "infinity")
		
		// let nan = 0.0 / 0.0
		let nan = Double.nan
		XCTAssertEqual( T(nan).description, "nan")
		
	}
	
	func test_Init_String() throws {
		
		XCTAssertEqual( T("0"),  "0")
		XCTAssertEqual( T("-0"), "0")
		
		/// Negatives
		XCTAssertEqual( T("-0").isNegative, false)
		XCTAssertEqual( T("-0.0").isNegative, false)
		XCTAssertEqual( T("-1").isNegative, true)
		XCTAssertEqual( T("-1235").isNegative, true)
		XCTAssertEqual( T("-1235.0001").isNegative, true)
		XCTAssertEqual( T("-0.0001").isNegative, true)
		
		XCTAssertEqual( T("1235"),   "1235")
		XCTAssertEqual( T("-1235"), "-1235")
		
		XCTAssertEqual( T("1_000"), "1000")
		XCTAssertEqual( T("1000_000"), "1000000")
		XCTAssertEqual( T("1_000_000"), "1000000")
		
		XCTAssertEqual( T("0.1"),   "0.1")
		XCTAssertEqual( T("-0.1"), "-0.1")
		XCTAssertEqual( T("-0.001"), "-0.001")
		XCTAssertEqual( T("12345.6789"),   "12345.6789")
		XCTAssertEqual( T("-12345.6789"), "-12345.6789")
		
		XCTAssertEqual( T("92233720368547758"), "92233720368547758")
		XCTAssertEqual( T("-0.9223372036854775808"), "-0.9223372036854775808")
		
		let long = "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
		XCTAssertEqual( T(long), T("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000") )
		
		/// Last Zeros
		XCTAssertEqual( T("1.999000"), "1.999")
		
		
		/// Dirty string
		XCTAssertEqual( T("-0.9a2233720x3685477 580_8"), "-0.9223372036854775808")
	}
	
	func test_Init_Binary() throws {
		
		XCTAssertEqual( T(bin: "1111"), 15)
		XCTAssertEqual( T(bin: "11111111"), 255)
		
		XCTAssertEqual( T("0b11111111"), 255)
		XCTAssertEqual( T("0b11111111", radix: 2), 255)
		
		
	}
	
	
	func test_Output_String() throws {
		
		XCTAssertEqual( T(0), "0")
		XCTAssertEqual( T(0).description, "0")
		
		XCTAssertEqual( T(1), "1")
		XCTAssertEqual( T(1).description, "1")
		
		XCTAssertEqual( T(1_000), "1000")
		XCTAssertEqual( T(1_000).description, "1000")
		
		XCTAssertEqual( T(1000000), "1000000")
		XCTAssertEqual( T(1_000_000), "1000000")
		XCTAssertEqual( T("1 000 000"), "1000000")
		
		XCTAssertEqual( T(922337203685475), "922337203685475")
		XCTAssertEqual( T(922_337_203_685_475), "922337203685475")
		XCTAssertEqual( T("922 337 203 685 475"), "922337203685475")
	}
	
	func test_Output_Formatted() throws {
		
		XCTAssertEqual( T(0).formatted(), "0")
		XCTAssertEqual( T(1_000).formatted(), "1 000")
		XCTAssertEqual( T(1_000_000).formatted(), "1 000 000")
		XCTAssertEqual( T(922_337_203_685_475).formatted(), "922 337 203 685 475")
		
		XCTAssertEqual( T("1_000.1").formatted(), "1 000.1")
		XCTAssertEqual( T("1_000.001").formatted(), "1 000.001")
		XCTAssertEqual( T("0.0000001").formatted(),   "0.0000001")
		XCTAssertEqual( T("-0.0000001").formatted(), "-0.0000001")
	}
	
	func test_Output_Limited() throws {
		
		XCTAssertEqual( T(0).limited(), "0")
		XCTAssertEqual( T(1_000).limited(), "1000")
		XCTAssertEqual( T(922_337_203_685_475).limited(), "9223_(7)_5475")
		XCTAssertEqual( T("1_000.001").limited(), "1000.001")
		XCTAssertEqual( T("1_000_000_000_000_000_000_000_000.000000000000000000001").limited(), "1000_(17)_0000.0000_(13)_0001")
		
		XCTAssertEqual( T(1000).limited(3), "10_(1)_0")
		XCTAssertEqual( T(12345_67890_12345).limited(4), "12_(11)_45")
		XCTAssertEqual( T(12345_67890_12345).limited(10), "12345_(5)_12345")
		XCTAssertEqual( T("1_000_000_000_000_000_000_000_000").limited(2), "1_(23)_0")
		XCTAssertEqual( T("1_00000_00000").limited(0), "10000000000")
	}
	
	func test_Casting_Double() throws {
		
		XCTAssertEqual( (T("0").asDouble!),   0.0 )
		XCTAssertEqual( (T("1").asDouble!),   1.0 )
		XCTAssertEqual( (T("0.001").asDouble!),   0.001 )
		XCTAssertEqual( (T("-0.001").asDouble!), -0.001 )
		XCTAssertEqual( T("12345.6789").asDouble!,   12345.6789)
		XCTAssertEqual( T("-12345.6789").asDouble!, -12345.6789)
	}
	
	func test_Casting_Bin() throws {
		
		XCTAssertEqual( T(UInt8.max).asBinary(),  "11111111" )
		XCTAssertEqual( T(UInt16.max).asBinary(), "1111111111111111" )
		XCTAssertEqual( T(UInt32.max).asBinary(), "11111111111111111111111111111111" )
		XCTAssertEqual( T(UInt64.max).asBinary(), "1111111111111111111111111111111111111111111111111111111111111111" )
		
		XCTAssertEqual( T("").asBinary(withPrefix: true), "0b?")
		XCTAssertEqual( T(Int8.min).asBinary(withPrefix: true), "-0b10000000")
		
		XCTAssertEqual( T("18446744073709551616").asBinary(), "10000000000000000000000000000000000000000000000000000000000000000")
		XCTAssertEqual( T("18446744073709551617").asBinary(), "10000000000000000000000000000000000000000000000000000000000000001")
		
		XCTAssertEqual( T("12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890").asBinary(), "101010000011011100110111110110000010111110100111001001111110000101000111011101010100001001010111000110000010000000101111110101110001000110100110111000101100011100111101001100100110000111001110011101010000111000100111100011000100011101111111110001101001001000101100001111011110111101111110001010010111010110011001111111100011001011011001110001111110000101011010010")
		
	}
	
	func test_Casting_Hex() throws {
		
		XCTAssertEqual( T(UInt8.max).asHexadecimal(),  "FF" )
		XCTAssertEqual( T(UInt16.max).asHexadecimal(), "FFFF" )
		XCTAssertEqual( T(UInt32.max).asHexadecimal(), "FFFFFFFF" )
		XCTAssertEqual( T(UInt64.max).asHexadecimal(), "FFFFFFFFFFFFFFFF" )
		
		XCTAssertEqual( T("").asHexadecimal(withPrefix: true), "0x?")
		XCTAssertEqual( T("-128").asHexadecimal(withPrefix: true), "-0x80")
		XCTAssertEqual( T("255").asHexadecimal(withPrefix: true), "0xFF")
		XCTAssertEqual( T("18446744073709551615").asHexadecimal(withPrefix: true), "0xFFFFFFFFFFFFFFFF")
		
		XCTAssertEqual( T("18446744073709551616").asHexadecimal(), "10000000000000000")
		XCTAssertEqual( T("81985529216486895").asHexadecimal(), "123456789ABCDEF")
		
		XCTAssertEqual( T("12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890").asHexadecimal(), "541B9BEC17D393F0A3BAA12B8C1017EB88D371639E9930E73A8713C623BFE349161EF7BF14BACCFF196CE3F0AD2")
		
	}
	
	
	func test_Compare_Equal() throws {
		
		let a = T(1)
		let b = T(1)
		let c = T(3)
		let d = T(-3)
		let o = T(0)
		XCTAssertTrue(a == b)
		XCTAssertFalse(a == c)
		XCTAssertFalse(c == d)
		
		let x = T(1.1)
		let y = T(1.1)
		let z = T(3.3)
		let u = T(-3.3)
		XCTAssertTrue(x == y)
		XCTAssertFalse(x == z)
		XCTAssertFalse(z == u)
		
		let ox = T(0.1)
		let oxx = T(0.1)
		let oy = T(0.01)
		let oo = T(0.0)
		XCTAssertTrue(ox == oxx)
		XCTAssertFalse(oy == ox)
		XCTAssertFalse(oy == oo)
		XCTAssertFalse(oy == oo)
		
		XCTAssertFalse(a == x)
		XCTAssertFalse(d == u)
		XCTAssertTrue(o == o)
		XCTAssertTrue(o == oo)
	}
	
	func test_Compare_Smaller() throws {
		
		XCTAssertTrue( T("0") < T("1") )
		XCTAssertTrue( T("1") < T("2") )
		XCTAssertTrue( T("100") < T("200") )
		XCTAssertTrue( T("100") < T("1000") )
		
		XCTAssertTrue( T("-1") < T("1") )
		XCTAssertTrue( T("-2") < T("-1") )
		XCTAssertTrue( T("-20") < T("20") )
		XCTAssertTrue( T("21") < T("22") )
		XCTAssertTrue( T("-20") < T("-10") )
		XCTAssertTrue( T("-100") < T("-99") )
		XCTAssertTrue( T("-123") < T("-121") )
		XCTAssertTrue( T("-100") < T("1000") )
		
		XCTAssertTrue( T("0") < T("0.1") )
		XCTAssertTrue( T("0") < T("0.001") )
		XCTAssertTrue( T("0.001") < T("0.1") )
		
		XCTAssertTrue( T("-0.1") < T("0") )
		XCTAssertTrue( T("-0.1") < T("0.1") )
		XCTAssertTrue( T("-0.2") < T("-0.1") )
		XCTAssertTrue( T("-0.22") < T("-0.1") )
		XCTAssertTrue( T("-0.22") < T("0.11") )
		XCTAssertTrue( T("-0.22") < T("0.22") )
		XCTAssertTrue( T("-0.222") < T("-0.22") )
		XCTAssertTrue( T("-0.2221") < T("-0.222") )
		XCTAssertTrue( T("-0.2221") < T("-0.222001") )
		
		XCTAssertTrue( T("0") < T("0.001") )
		XCTAssertTrue( T("0.001") < T("0.1") )
	}
	
	
	func test_Basic_Negate() throws {
		
		let a = T(1)
		let b = T(2)
		
		XCTAssertEqual( a + b,  3)
		XCTAssertEqual( a + (-b),  -1)
	}
	
	func test_Shift() throws {
		
		var a = Arbit("123.9")
		
		a.shift(decimals: -3)
		XCTAssertEqual( a , "0.1239" )
		
		a.shift(decimals: 3)
		XCTAssertEqual( a , "123.9" )
		
		a.shift(decimals: 3)
		XCTAssertEqual( a , "123900" )
		
		a.shift(decimals: -6)
		XCTAssertEqual( a , "0.1239" )
		
		
		var b = Arbit(10)
		
		b.shift(decimals: 1)
		XCTAssertEqual( b , "100" )
		
		b.shift(decimals: -2)
		XCTAssertEqual( b , "1" )
		
		b.shift(decimals: -1)
		XCTAssertEqual( b , "0.1" )
		
		
	}
	
	
	func test_BitWise_And() throws {
		
		var (x,y,z) : (Int,Int,Int)
		var (xT,yT,zT) : (T,T,T)
		
		 x = 129
		 y = 123
		 z = x & y
		
		 xT = T(x)
		 yT = T(y)
		 zT = xT & yT
		
		XCTAssertEqual( String(z, radix: 2), zT.asBinary() )
		
		
		
		x = Int.max
		y = 0b11111111
		z = x & y
		
		xT = T(x)
		yT = T(y)
		zT = xT & yT
		
		XCTAssertEqual( String(z, radix: 2), zT.asBinary() )
		
	}
	
	func test_BitWise_Or() throws {
		
		var (x,y,z) : (Int,Int,Int)
		var (xT,yT,zT) : (T,T,T)
		
		 x = 129
		 y = 123
		 z = x | y
		
		 xT = T(x)
		 yT = T(y)
		 zT = xT | yT
		
		XCTAssertEqual( String(z, radix: 2), zT.asBinary() )
		
		
		
		x = Int.max
		y = 0b11111111
		z = x | y
		
		xT = T(x)
		yT = T(y)
		zT = xT | yT
		
		XCTAssertEqual( String(z, radix: 2), zT.asBinary() )
		
	}
}


final class Test_Math_Basic: XCTestCase {
	
	func test_Basic_Add_Sub() throws{
		
		XCTAssertEqual( T(0) + T(0),  0)
		XCTAssertEqual( T(0) + T(1),  1)
		XCTAssertEqual( T(1) + T(0),  1)
		XCTAssertEqual( T(1) + T(1),  2)
		
		XCTAssertEqual( T(0) - T(0),  0)
		XCTAssertEqual( T(0) - T(1), -1)
		XCTAssertEqual( T(1) - T(0),  1)
		XCTAssertEqual( T(1) - T(1),  0)
		
		XCTAssertEqual( T(2) - T(1),  1)
		XCTAssertEqual( T(2) - T(2),  0)
		XCTAssertEqual( T(2) - T(3), -1)
		XCTAssertEqual( T(2) - T(4), -2)
		
		XCTAssertEqual( T(-3) + T(1), -2)
		XCTAssertEqual( T(-3) + T(2), -1)
		XCTAssertEqual( T(-3) + T(3),  0)
		XCTAssertEqual( T(-3) + T(4),  1)
		
		XCTAssertEqual( T(-3) + T(1),  -2)
		XCTAssertEqual( T(-3) + T(-1), -4)
		XCTAssertEqual( T(-3) - T(1),  -4)
		XCTAssertEqual( T(-3) - T(-1), -2)
		
		XCTAssertEqual( T(-3) - T(-3),  0)
		
		XCTAssertEqual( T(1000) + T(1000),  2000)
		XCTAssertEqual( T(1000) - T(1000),  0)
		XCTAssertEqual( T(1000) - T(2000),  -1000)
	}
	
	func test_Basic_OpEqual() throws {
		
		var a = T(1)
		
		XCTAssertEqual( (a + 1), 2)
		XCTAssertEqual( (a + 99), 100)
		XCTAssertEqual( (a - 1), 0)
		XCTAssertEqual( (a - 2), -1)
		XCTAssertEqual( (a - 100), -99)
		
		a += 1
		XCTAssertEqual( a.description, "2")
		a += 1
		XCTAssertEqual( a.description, "3")
		
		
		a -= 3
		XCTAssertEqual( a.description, "0")
		
		a -= 3
		XCTAssertEqual( a.description, "-3")
		
		a += 5
		XCTAssertEqual( a.description, "2")
		
		a += (-1)
		XCTAssertEqual( a.description, "1")
		
		a *= 2
		XCTAssertEqual( a.description, "2")
		
		a *= (-10)
		XCTAssertEqual( a.description, "-20")
		
		a *= ("1.5")
		XCTAssertEqual( a.description, "-30")
		
		a /= 2
		XCTAssertEqual( a.description, "-15")
		
		a /= "-0.5"
		XCTAssertEqual( a.description, "30")
		
	}
	
	func test_Basic_Mul() throws{
		
		XCTAssertEqual( T(0)  * T(0),  0)
		XCTAssertEqual( T(0)  * T(-0), 0)
		XCTAssertEqual( T(-0) * T(0),  0)
		XCTAssertEqual( T(-0) * T(-0), 0)
		
		XCTAssertEqual( T(0) * T(1),  0)
		XCTAssertEqual( T(0) * T(-1), 0)
		XCTAssertEqual( T(1) * T(0),  0)
		XCTAssertEqual( T(-1) * T(0), 0)
		
		XCTAssertEqual( T(1) * T(1),    1)
		XCTAssertEqual( T(1) * T(-1),  -1)
		XCTAssertEqual( T(-1) * T(1),  -1)
		XCTAssertEqual( T(-1) * T(-1),  1)
		
		XCTAssertEqual( T(3) * T(1), 3)
		XCTAssertEqual( T(1) * T(3), 3)
		XCTAssertEqual( T(3) * T(-1), -3)
		XCTAssertEqual( T(-1) * T(3), -3)
		
		XCTAssertEqual( T(3) * T(3), 9)
		XCTAssertEqual( T(33) * T(33), 1089)
		
		XCTAssertEqual( T(100) * T(100), 10_000)
		
	}
	
	func test_Basic_Div() throws{
		
		let old = Arbit.precision
		Arbit.precision = 10
		defer { Arbit.precision = old }
		
		
		XCTAssertEqual( (T(0) / T(0)).description,  Arbit.nan.description)
		XCTAssertEqual( (T(1) / T(0)).description,  Arbit.nan.description)
		
		XCTAssertEqual( T(0) / T(1),  .zero)
		XCTAssertEqual( T(0) / T(-1), .zero)
		
		XCTAssertEqual( T(1) / T(1),    1)
		XCTAssertEqual( T(1) / T(-1),  -1)
		XCTAssertEqual( T(-1) / T(1),  -1)
		XCTAssertEqual( T(-1) / T(-1),  1)
		
		XCTAssertEqual( T(3) / T(3), 1)
		XCTAssertEqual( T(9) / T(9), 1)
		
		XCTAssertEqual( T(100) / T(1),   "100")
		XCTAssertEqual( T(100) / T(10),   "10")
		XCTAssertEqual( T(100) / T(100),   "1")
		XCTAssertEqual( T(100) / T(1000),  "0.1")
		XCTAssertEqual( T(100) / T(10000), "0.01")
		
		XCTAssertEqual( T(56) / T(7), 8)
		XCTAssertEqual( T(279_591) / T(871), 321)
		
		XCTAssertEqual( T(4) / T(5),  0.8)
		
		XCTAssertEqual( T(4) / T(3),  "1.3333333333")
		XCTAssertEqual( T(16) / T(9), "1.7777777777")
	}
	
	func test_Basic_Random() throws {
		
		let old = Arbit.precision
		Arbit.precision = 10
		defer { Arbit.precision = old }
		
		for _ in 1...iteration {
			
			let lInt = randInt(digits: 2...8)
			let rInt = randInt(digits: 2...8)
			let nSign = Bool.random() ? 1 : -1
			
			let lhsT = T( lInt * nSign )
			let rhsT = T( rInt )
			
			let lhsDec = Decimal( lInt * nSign )
			let rhsDec = Decimal( rInt )
			
			
			let tAdd   = (lhsT   + rhsT  ).description
			let decAdd = (lhsDec + rhsDec).description
			XCTAssertEqual( tAdd, decAdd )
			
			let tSub   = (lhsT   - rhsT  ).description
			let decSub = (lhsDec - rhsDec).description
			XCTAssertEqual( tSub, decSub )
			
			let tMul   = (lhsT   * rhsT  ).description
			let decMul = (lhsDec * rhsDec).description
			XCTAssertEqual( tMul, decMul )
			
			let tDiv   = (lhsT   / rhsT  ).description
			let decDiv = (lhsDec / rhsDec).description
			XCTAssertEqual( tDiv, String(decDiv.prefix(tDiv.count)) )
			
//			print("RND»", lhsDec, ":", rhsDec,"(+-*/)", decAdd, decSub, decMul, decDiv)
//			print("RND»", lhsT, ":", rhsT,"(+-*/)", tAdd, tSub, tMul, tDiv)
		}
	}
	
}


final class Test_Math_Fraction: XCTestCase {
	
	func test_Fract_Add() throws {
		
		XCTAssertEqual( T("0") + T("0.0"), "0")
		
		XCTAssertEqual( T("0") + T("0.1"), "0.1")
		XCTAssertEqual( T("0.1") + T("0"), "0.1")
		
		XCTAssertEqual( T("1") + T("0.1"), "1.1")
		XCTAssertEqual( T("0.1") + T("1"), "1.1")
		
		XCTAssertEqual( T("0.1") + T("0.1"),  "0.2")
		XCTAssertEqual( T("0.1") + T("0.02"), "0.12")
		XCTAssertEqual( T("0.1") + T("0.9"),  "1")
		XCTAssertEqual( T("0.1") + T("0.91"), "1.01")
		
		XCTAssertEqual( T("0.0001") + T("0.1"), "0.1001")
		XCTAssertEqual( T("0.1") + T("0.0001"), "0.1001")
		
		XCTAssertEqual( T("1.0001") + T("0.1"), "1.1001")
		XCTAssertEqual( T("1.1") + T("0.0001"), "1.1001")
		
		XCTAssertEqual( T("0.99") + T("0.01"),  "1")
		XCTAssertEqual( T("0.99") + T("0.02"),  "1.01")
		
		XCTAssertEqual( T("1.99") + T("0.01"),  "2")
		XCTAssertEqual( T("100.99") + T("0.01"),  "101")
		XCTAssertEqual( T("1") + T("1000.10001"), "1001.10001")
		XCTAssertEqual( T("999") + T("2.10001"), "1001.10001")
		XCTAssertEqual( T("1230.1") + T("5.10009"), "1235.20009")
		XCTAssertEqual( T("9.99999") + T("1.1"), "11.09999")
		XCTAssertEqual( T("9.99999") + T("1.00001"), "11")
		XCTAssertEqual( T("0.0000009") + T("0.0000001"), "0.000001")
		
	}
	
	func test_Fract_Sub() throws {
		
		XCTAssertEqual( T("0")   - T("0.0"),    "0")
		XCTAssertEqual( T("0")   - T("0.1"), "-0.1")
		XCTAssertEqual( T("0.1") - T("0"),    "0.1")
		XCTAssertEqual( T("0.1") - T("0.1"),    "0")
		
		XCTAssertEqual( T("0")   + T("-0.0"),    "0")
		XCTAssertEqual( T("0")   + T("-0.1"), "-0.1")
		XCTAssertEqual( T("0.1") + T("-0"),    "0.1")
		XCTAssertEqual( T("0.1") + T("-0.1"),    "0")
		
		
		XCTAssertEqual( T("0.1") - T("0.2"),   "-0.1")
		XCTAssertEqual( T("0.1") - T("0.02"),   "0.08")
		XCTAssertEqual( T("0.1") - T("0.999"), "-0.899")
		XCTAssertEqual( T("0.1") - T("0.19"),  "-0.09")
		
		XCTAssertEqual( T("0.1") + T("-0.2"),   "-0.1")
		XCTAssertEqual( T("0.1") + T("-0.02"),   "0.08")
		XCTAssertEqual( T("0.1") + T("-0.999"), "-0.899")
		XCTAssertEqual( T("0.1") + T("-0.19"),  "-0.09")

		
		XCTAssertEqual( T("0.3") - T("0.01"), "0.29")
		XCTAssertEqual( T("0.3") - T("0.32"), "-0.02")
		XCTAssertEqual( T("0.3") - T("0.4"), "-0.1")
		XCTAssertEqual( T("0.3") - T("1.0"), "-0.7")
		XCTAssertEqual( T("0.3") - T("1.872"), "-1.572")
		
		XCTAssertEqual( T("1.3") - T("0.01"), "1.29")
		XCTAssertEqual( T("10.3") - T("0.32"), "9.98")
		XCTAssertEqual( T("100.3") - T("0.4"), "99.9")
		
		XCTAssertEqual( T("1.3") - T("10.01"), "-8.71")
		XCTAssertEqual( T("10.3") - T("10.32"), "-0.02")
		XCTAssertEqual( T("100.3") - T("10.4"), "89.9")
		
		XCTAssertEqual( T("101.731001") - T("1.872"), "99.859001")
		XCTAssertEqual( T("1230.1") - T("5.10009"), "1224.99991")
		
	}
	
	func test_Fract_Mul() throws {
		
		XCTAssertEqual( T("0") * T("0.0"),   "0")
		XCTAssertEqual( T("0") * T("0.001"), "0")
		XCTAssertEqual( T("0") * T("1.001"), "0")
		XCTAssertEqual( T("0.001") * T("0"), "0")
		XCTAssertEqual( T("1.001") * T("0"), "0")
		
		XCTAssertEqual( T("1") * T("0.1"),    "0.1")
		XCTAssertEqual( T("1") * T("0.01"),   "0.01")
		XCTAssertEqual( T("1") * T("0.001"),  "0.001")
		XCTAssertEqual( T("10") * T("0.1"),   "1")
		XCTAssertEqual( T("10") * T("0.01"),  "0.1")
		XCTAssertEqual( T("10") * T("0.001"), "0.01")
		
		XCTAssertEqual( T("1")  * T("-0.1"),   "-0.1")
		XCTAssertEqual( T("1")  * T("-0.01"),  "-0.01")
		XCTAssertEqual( T("-1") * T("0.1"),    "-0.1")
		XCTAssertEqual( T("-1") * T("0.01"),   "-0.01")
		XCTAssertEqual( T("-1") * T("-0.1"),    "0.1")
		XCTAssertEqual( T("-1") * T("-0.01"),   "0.01")
		
		XCTAssertEqual( T("0.1") * T("0.1"),   "0.01")
		XCTAssertEqual( T("0.1") * T("0.01"),  "0.001")
		XCTAssertEqual( T("0.1") * T("0.001"), "0.0001")
		
		XCTAssertEqual( T("0.001") * T("0.001"), "0.000001")
		XCTAssertEqual( T("0.00001") * T("0.00001"), "0.0000000001")

		XCTAssertEqual( T("111.001") * T("0.1"), "11.1001")
		XCTAssertEqual( T("111.001") * T("0.01"), "1.11001")
		XCTAssertEqual( T("111.001") * T("0.001"), "0.111001")

		XCTAssertEqual( T("12345.12345") * T("2.1"), "25924.759245")
		XCTAssertEqual( T("12345.12345") * T("2.2"), "27159.27159")
		XCTAssertEqual( T("12345.12345") * T("2.3"), "28393.783935")
		
		XCTAssertEqual( T("12345.98765") * T("12345.98765"), "152423411.0539525225")
		XCTAssertEqual( T("12345.98765") * T("12345.12345"), "152412741.6514253925")
		XCTAssertEqual( T("12345.12345") * T("12345.98765"), "152412741.6514253925")
		XCTAssertEqual( T("12345.12345") * T("12345.12345"), "152402072.9957399025")
		
		XCTAssertEqual( T("2.3")         * T("2.6"), "5.98")
		XCTAssertEqual( T("18.84")       * T("32.13"), "605.3292")
		XCTAssertEqual( T("318.845")     * T("451.623"), "143997.735435")
		XCTAssertEqual( T("5318.7844")   * T("2139.8126"), "11381201.87580344")
		
		XCTAssertEqual( T("21.3")        * T("2.26"), "48.138")
		XCTAssertEqual( T("1834.84")     * T("3.339"), "6126.53076")
		XCTAssertEqual( T("31812.845")   * T("45.5676"), "1449634.995822")
		XCTAssertEqual( T("531898.7844") * T("213.12381"), "113360295.465696564")

	}
	
	func test_Fract_Div() throws {
		
		let old = T.precision
		T.precision = 10
		defer { T.precision = old }
		
		XCTAssertEqual( (T("1.0") / T("0")).description, T.nan.description)
		XCTAssertEqual( (T("1.1") / T("0")).description, T.nan.description)
		
		XCTAssertEqual( T("0") / T("0.001"), "0")
		XCTAssertEqual( T("0") / T("1.001"), "0")
		
		XCTAssertEqual( T("2.6") / T("1.3"),   "2")
		XCTAssertEqual( T("2.6") / T("-1.3"), "-2")
		XCTAssertEqual( T("-2.6") / T("1.3"), "-2")
		XCTAssertEqual( T("-2.6") / T("-1.3"), "2")
	
		XCTAssertEqual( T("1")  / T("0.1"),    "10")
		XCTAssertEqual( T("1")  / T("0.01"),   "100")
		XCTAssertEqual( T("1")  / T("0.001"),  "1000")
		
		XCTAssertEqual( T("10") / T("0.1"),    "100")
		XCTAssertEqual( T("10") / T("0.01"),   "1000")
		XCTAssertEqual( T("10") / T("0.001"),  "10000")
		
		XCTAssertEqual( T("1234") / T("0.1234"), "10000")
		XCTAssertEqual( T("1234") / T("1.234"),  "1000")
		XCTAssertEqual( T("1234") / T("12.34"),  "100")
		XCTAssertEqual( T("1234") / T("123.4"),  "10")
		
		XCTAssertEqual( T("0.1234") / T("1234"), "0.0001")
		XCTAssertEqual( T("1.234")  / T("1234"), "0.001")
		XCTAssertEqual( T("12.34")  / T("1234"), "0.01")
		XCTAssertEqual( T("123.4")  / T("1234"), "0.1")
		
		
		XCTAssertEqual( T("7.2") / T("24"), "0.3")
		XCTAssertEqual( T("72") / T("2.4"), "30")
		
		XCTAssertEqual( T("14.2") / T("4"), "3.55")
		XCTAssertEqual( T("14.4") / T("4"), "3.6")
		XCTAssertEqual( T("524.8") / T("4"), "131.2")
		XCTAssertEqual( T("2818.8") / T("8"), "352.35")
		
		XCTAssertEqual( T("8") / T("2.5"), "3.2")
		XCTAssertEqual( T("18") / T("2.5"), "7.2")
		XCTAssertEqual( T("782") / T("8.5"), "92")
		XCTAssertEqual( T("8448") / T("4.8"), "1760")
		
		XCTAssertEqual( T("8.84") / T("2.6"), "3.4")
		XCTAssertEqual( T("1236.82") / T("3.2"), "386.50625")
		XCTAssertEqual( T("2453.4638") / T("43.21"), "56.78")
		
	}
	
	func test_Fract_Random() throws {
		
		let old = Arbit.precision
		Arbit.precision = 3
		defer { Arbit.precision = old }
		
		
		for _ in 1...iteration {
			
			let (lStrI, lStrF) = randPair(1...5, 1...3)
			let (rStrI, rStrF) = randPair(1...5, 1...3)
			let nSign = Bool.random() ? "" : "-"
			
			let lStr = nSign + lStrI + "." + lStrF
			let rStr =         rStrI + "." + rStrF
			
			let lhsDec = Decimal(string: lStr )!
			let rhsDec = Decimal(string: rStr )!
			
			let lhsT = T(lStr)
			let rhsT = T(rStr)
			
			
			let tAdd   = (lhsT   + rhsT  ).description
			let decAdd = (lhsDec + rhsDec).description
			XCTAssertEqual( tAdd, decAdd )

			let tSub   = (lhsT   - rhsT  ).description
			let decSub = (lhsDec - rhsDec).description
			XCTAssertEqual( tSub, decSub )

			let tMul   = (lhsT   * rhsT  ).description
			let decMul = (lhsDec * rhsDec).description
			XCTAssertEqual( tMul, decMul )
//
			let tDiv   = (lhsT   / rhsT  ).description
			let decDiv = (lhsDec / rhsDec).description
			XCTAssertEqual( tDiv, String(decDiv.prefix(tDiv.count)),
								 String("'\(lhsT)/\(rhsT)=\(tDiv) : \(lhsDec)/\(rhsDec)=\(decDiv)'") )
			
		}
	}
	
}


final class Test_Math_Long: XCTestCase {
	
	func test_Long_Add() throws {
		
		var (l, r, x): (String, String, String)
//		var sum : (sum: String, carry: Int)
		var t : T
		
		
		/// Overflow
		l = "1"
		r = "9223372036854775807"
		x = "9223372036854775808"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		
		
		l =  "44444444443333333333222222222211111111110000000000"
		r =  "99999999998888888888777777777766666666665555555555"
		x = "144444444442222222221999999999977777777775555555555"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		r =                               "1"
		l = "6777777777788888888889999999999"
		x = "6777777777788888888890000000000"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		l = "10000000000000000000001000000000000000000000"
		r = "20000000000000000000002000000000000000000000"
		x = "30000000000000000000003000000000000000000000"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		l =  "111222333444555666777888999"
		r =  "888777666555444333222111001"
		x = "1000000000000000000000000000"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		l = "1234567890123456789012345678901234567890"
		r = "1234567890123456789012345678901234567890"
		x = "2469135780246913578024691357802469135780"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		l =  "666666666777777777888888888999999999"
		r =  "333333333222222222111111111000000001"
		x = "1000000000000000000000000000000000000"
		XCTAssertEqual( T(l) + T(r) , T(x) )
		
		
		XCTAssertEqual( T("0.9999999999999999999999999999999") + T("0.0000000000000000000000000000001"), "1")
		
		l = "0.99999999999999999999"
		r = "0.00000000000000000001"
		x = "1"
		XCTAssertEqual( T(l) + T(r), T(x) )
		
		l =  "99999999999999999999.99999999999999999999"
		r =                     "0.00000000000000000001"
		x = "100000000000000000000"
		XCTAssertEqual( T(l) + T(r), T(x) )
		
		l = "1234567890123456789.01234567890123456789"
		r = "1234567890123456789.01234567890123456789"
		x = "2469135780246913578.02469135780246913578"
		XCTAssertEqual( T(l) + T(r), T(x) )
		
	}
	
	func test_Long_Sub() throws {
		
		var ( l, r, x ) : ( String, String, String )
		var sum : (sum: String, negative: Bool)
		
		
		l = "3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
		r = "2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
		x = "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
		XCTAssertEqual(T.subtraction(lhs: l, rhs: r).sum, x)
		XCTAssertEqual( T(raw: l) - T(raw: r), T(x) )
		
		sum = T.subtraction(lhs: r, rhs: l)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( sum.negative, true )
		XCTAssertEqual( T(raw: r) - T(raw: l), T(raw: x, negative: true) )
		
		
		l = "19999999999888888888877777777776666666666555555555544444444443333333333222222222211111111110000000000"
		r = "19999999999888888888877777777776666666666555555555544444444443333333333222222222211111111110000000000"
		x = "0"
		XCTAssertEqual(T.subtraction(lhs: l, rhs: r).sum, x)
		
		
		l = "19999999999888888888877777777776666666666555555555544444444443333333333222222222211111111110000000000"
		r = "19999999999888888888877777777776666666666555555555544444444443333333333222222222211111111110000000001"
		x = "1"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( sum.negative, true )
		XCTAssertEqual( T(raw: l) - T(raw: r), T(raw: x, negative: true) )
		
		
		l =  "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
		r =  "999999999988888888887777777777666666666655555555554444444444333333333322222222221111111111"
		x =            "11111111112222222222333333333344444444445555555555666666666677777777778888888888"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( T(raw: l) - T(raw: r), T(raw: x) )
		
		
		r =           "188888888887777777777666666666655555555554444444444333333333322222222221111111111"
		x =  "999999999811111111112222222222333333333344444444445555555555666666666677777777778888888888"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( T(raw: l) - T(raw: r), T(raw: x) )
		
		
		l = "1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
		r =  "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
		x = "1"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( T(raw: l) - T(raw: r), T(raw: x) )
		
		
		l = "4444444444333333333322222222221111111111"
		r = "9999999999888888888877777777776666666666"
		x = "5555555555555555555555555555555555555555"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( sum.negative, true )
		XCTAssertEqual( T(raw: l) - T(raw: r), T(raw: x, negative: true) )
		
		
		l = "1234567890123456789012345678901234567890"
		r = "1234567890123456789012345678901234567890"
		x = "0"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( T(raw: l) - T(raw: r), T.zero )
		
		
		
		/// Negative +
		
		l = "-12319823986912836981236986"
		r =  "98126398612398612938612989"
		x =  "85806574625485775957376003"
		XCTAssertEqual( T(l) + T(r), T(x) )
		
		
		
		
		XCTAssertEqual( T("1000000000000.0000001") - T("9999999999999.0000009"), T("-8999999999999.0000008") )
		
		
		l = "1234567890123456789012345678901234567890"
		r = "1234567890123456789012345678901234567890.001"
		x = "-0.001"
		XCTAssertEqual( T(l) - T(r), T(x) )
		
		
		l = "1234567890123456789.012345678901234567890"
		r = "1234567890123456789.012345678901234567890"
		x = "0"
		sum = T.subtraction(lhs: l, rhs: r)
		XCTAssertEqual( sum.sum, x )
		XCTAssertEqual( T(l) - T(r), T.zero )
		
		
	}
	
	func test_Long_Mul() throws {
		
		var ( l, r, x ) : ( String, String, String )
		
		/// Overflow
		
		l = "2"
		r = "4611686018427387904"
		x = "9223372036854775808"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		
		
		/// 19 + 19 = 38
		l = "1234567890123456789"
		r = "9876543210987654321"
		x = "12193263113702179522374638011112635269"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		/// 19 + 20 = 39
		l = "1234567890123456789"
		r = "98765432109876543210"
		x = "121932631137021795223746380111126352690"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		/// 20 + 19 = 39
		l = "12345678901234567890"
		r = "9876543210987654321"
		x = "121932631137021795223746380111126352690"
		XCTAssertEqual( T(l) * T(r), T(x) )

		/// 20 + 20 = 40
		l = "12345678901234567890"
		r = "98765432109876543210"
		x = "1219326311370217952237463801111263526900"
		XCTAssertEqual( T(l) * T(r), T(x) )
												  
		/// 21 + 20 = 41
		l = "123456789012345678901"
		r = "98765432109876543210"
		x = "12193263113702179522473403443222511812210"
		XCTAssertEqual( T(l) * T(r), T(x) )
																		
		/// 20 + 21 = 41
		l = "12345678901234567890"
		r = "987654321098765432101"
		x = "12193263113702179522386983690013869836890"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		/// 21 + 21 = 42
		l = "123456789012345678901"
		r = "987654321098765432101"
		x = "121932631137021795224857491221237463801001"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		/// 23 + 20 = 43
		l = "99999999999999999999111"
		r = "99999999999999999999"
		x = "9999999999999999999811100000000000000000889"
		XCTAssertEqual( T(l) * T(r), T(x) )
		
		
		
		/// Fraction
 
		l = "1234567890123456789"
		r = "1.234567890123456789"
		x = "1524157875323883675.019051998750190521"
		XCTAssertEqual( T(l) * T(r), T(x) )
		XCTAssertEqual( T(r) * T(l), T(x) )
		
		l = "1234567890123456789"
		r = "0.000005"
		x = "6172839450617.283945"
		XCTAssertEqual( T(l) * T(r), T(x) )
		XCTAssertEqual( T(r) * T(l), T(x) )
		
		l = "123456789.0123456789"
		r = "9875.4321"
		x = "1219189137175.44581370535269"
		XCTAssertEqual( T(l) * T(r), T(x) )
		XCTAssertEqual( T(r) * T(l), T(x) )
		
		l = "-81274142132163.29831231230123"
		r = "981312312475.4323123123131"
		x = "-79755316360170129153494868.143356608601962366725275113"
		XCTAssertEqual( T(l) * T(r), T(x) )
		XCTAssertEqual( T(r) * T(l), T(x) )
		
	}
	
	func test_Long_Div() throws {
		
		let old = Arbit.precision
		Arbit.precision = 10
		defer { Arbit.precision = old }
		
		XCTAssertEqual( T("1234567890123456789012345678901234567890") / T("12"),   "102880657510288065751028806575102880657.5")
		XCTAssertEqual( T("1234567890123456789012345678901234567890") / T("-12"), "-102880657510288065751028806575102880657.5")

		XCTAssertEqual( T("1234567890123456789012345678901234567890") / T("1234567890"),  "1000000000100000000010000000001")
		
		XCTAssertEqual( T("1234567890123456789") / T("12.5"),  "98765431209876543.12")
		XCTAssertEqual( T("1.234567890123456789") / T("12.5"),  "0.09876543120987654312")
		XCTAssertEqual( T("123456789.0123456789") / T("12.5"),  "9876543.120987654312")
		XCTAssertEqual( T("123456789012345678.9") / T("12.5"),  "9876543120987654.312")
		
		
		
		/// Long - Long div

		//		XCTAssertEqual( T("1234567890123456789012345678901234567890") / T("12345678901234567890"),  "100000000000000000001")
		
		//		XCTAssertEqual( T("12") / T("1234567890123456789012345678901234567890"),  "0.00000000000000000000000000000000000000972000008748")
		
		
	}
	
	func test_Long_Random() throws {
		
		let old = Arbit.precision
		Arbit.precision = 10
		defer { Arbit.precision = old }
		
		
		for _ in 1...iteration {
			
			let (lStrI, lStrF) = randPair(9...14, 0...9)
			let (rStrI, rStrF) = randPair(9...14, 0...9)
			
			let lStr = lStrI + "." + lStrF
			let rStr = rStrI + "." + rStrF
			
			let nSign = Bool.random() ? "" : "-"
			
			let lhsDec = Decimal(string: nSign + lStr )!
			let rhsDec = Decimal(string: rStr )!
			
			let lhsT = T( nSign + lStr )
			let rhsT = T( rStr )
			
			
			
			let tAdd   = (lhsT   + rhsT  ).description
			let decAdd = (lhsDec + rhsDec).description
			XCTAssertEqual( tAdd, decAdd )
			
			let tSub   = (lhsT   - rhsT  ).description
			let decSub = (lhsDec - rhsDec).description
			XCTAssertEqual( tSub, decSub )
			
			let tMul   = (lhsT   * rhsT  ).description
			let decMul = (lhsDec * rhsDec).description
			XCTAssertEqual( String(tMul.prefix(decMul.count-1)), String(decMul.dropLast()) )
			
//			let tDiv   = (lhsT   / rhsT  ).description
//			let decDiv = (lhsDec / rhsDec).description
//			XCTAssertEqual( tDiv, String(decDiv.prefix(tDiv.count)) )
			
		}
	}
}
