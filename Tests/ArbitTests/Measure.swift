import XCTest
@testable import Arbit


final class Time_Measure: XCTestCase {
	
	func test_Measure_Long_Add() throws {

		measure {
			for _ in 1...10 {
				try? Test_Math_Long().test_Long_Add()
			}
		}
		
		///  Substring+Sufix 0.154 sec
	}
	
	func test_Measure_Long_Sub() throws {
		
		measure {
			for _ in 1...10 {
				try? Test_Math_Long().test_Long_Sub()
			}
		}
		
		/// Array+ArrayRevChunked 0.282 sec / (3.106)
		/// StringFormat 0.402 sec / (4.295) seconds
		
	}
	
	func test_Measure_Long_Mul() throws {
		
		measure {
			for _ in 1...10 {
				try? Test_Math_Long().test_Long_Mul()
			}
		}
		
		/// StringFormat  0.272 sec  (3.060) seconds
		/// StringFill0  0.209 sec  (2.366) seconds
		
	}
	
	func test_Measure_Quo() throws {
		
		/// _  0.362 sec
		/// m  0.137 sec [15]
		
		let s = "12345678901234567890"
//		let s = "1523456776261231789015234567762612317890152345677626123178901523456776261231789015234567762612317890152345677626123178901523456776261231789015234567762612317890"
		
		measure {
			for _ in 1...1000 {
				_ = Arbit.quoAndRem(string: s, by: 1234567890)
			}
		}
	}
}
