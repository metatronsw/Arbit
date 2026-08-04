import Foundation

extension Arbit {
	
	static func __intLongAddAsync(lhs: Arbit, rhs: Arbit) async -> Arbit {
		
		
		let negative = lhs.isNegative
		var carry = 0
		var string = ""
		var i = 0
		
		//		let lRanges = makeRanges(from: lhs.integer.count-1, through: 0, by: sliceLen)
		//		let lInts = lhs.integer.slicerizeInts(by: lRanges)
		
		//		let rRanges = makeRanges(from: rhs.integer.count-1, through: 0, by: sliceLen)
		//		let rInts = rhs.integer.slicerizeInts(by: rRanges)
		
		let lInts = lhs.integer.slicerizeInts(by: makeRanges(from: lhs.integer.count-1, through: 0, by: sliceLen) )
		let rInts = rhs.integer.slicerizeInts(by: makeRanges(from: lhs.integer.count-1, through: 0, by: sliceLen) )
		
#if DEBUG
		print("lhs:", lhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), "#", lhs.integer.count , lInts, "№", lInts.count )
		print("rhs:", rhs.formatted(groupingSize: sliceLen, groupingSeparator: " "), "#", rhs.integer.count , rInts, "№", rInts.count )
#endif
		
		var long: [Int]?
		var len: Int
		
		if      lInts.count > rInts.count { len = rInts.count ; long = lInts }
		else if lInts.count < rInts.count { len = lInts.count ; long = rInts }
		else                              { len = lInts.count - 1 }
		
		
		/// Two part adding
		repeat {
			summing( lInts[i] + rInts[i] + carry, with: "0")
			i += 1
		} while i < len
		
		
		/// Longest part & carry
		if let long {
			//			print("»» LONG", i, long.count, long[i])
			
			/// Carry addition, as long as there is except the last
			if carry == 1 {
				repeat {
					summing( long[i] + carry, with: "0")
					i += 1
				} while carry != 0 || i < long.count - 1
			}
			
			
			/// Final writeout part, if there is any left
			if i < long.count {
				//				print("»»WANMÉG", i, long.count)
				summing(long.last!)
			}
			
			/// Write out last string without zeros
			if i < len { string = String(long.last!) + string }
		}
		
		/// Equal length, adding without zero fill
		else {
			summing( lInts.last! + rInts.last! + carry )
		}
		
		/// Increased length of the number, no more on parts
		if carry == 1 { string = "1" + string }
		
		
		
		
		
		func summing(_ int: Int, with zero: String = "") {
			
			var part = String(int)
			carry = 0
			
			if part.count < sliceLen {
				part = String(repeating: zero, count: sliceLen-part.count) + part
			}
			else if part.count > sliceLen {
				part.removeFirst()
				carry = 1
			}
			string = part + string
		}
		
		
		let number = Arbit(raw: string, negative: negative)
		//		print("\n=", number.formatted(groupingSize: sliceLen, groupingSeparator: " "), "\n")
		return number
	}
	
	
	static func __intLongMul_Slices(lhs: Arbit, rhs: Arbit) -> Arbit {
		
		let negative = (lhs.isNegative && !rhs.isNegative) || (!lhs.isNegative && rhs.isNegative)
		
		let slice = 17
//		let limit = slice.raise // (fast pow^2)
		let limit = Int(pow(Double(slice), 2))
		
		let slices = makeRanges(from: lhs.integer.count-1, through: 0, by: slice)
		let left = lhs.integer.slicerize(by: slices).map { Int(String($0))! }
		let right = rhs.integer.reversed().map { Int(String($0))! }
		
		var act = [Int]()
		var subsum = [String]()
		
		var carry = 0
		var part = 0
		var c = 0
		var r = 0
		
#if DEBUG
		print("\n", lhs.formatted(groupingSize: sliceLen, groupingSeparator: ""), "×",
				rhs.formatted(groupingSize: sliceLen, groupingSeparator: ""), " › ", left, "×", right)
#endif
		
		repeat {
			repeat {
				
				part = left[c] * right[r] + carry // + prev[c]
				//				print("\(c)] \(left[c]) * \(right[r]) (\(left[c]*right[r])) + '\(carry) = ", terminator: "")
				
				carry = 0
				
				if part >= limit { (carry, part) = part.quotientAndRemainder(dividingBy: limit) }
				//				print("(\(carry))\(String(format: "%\(slice)ld", part))")
				act.append(part)
				part = 0
				
				c += 1
				
			} while c < left.count /// Left
			
			
			if carry != 0 { act.append(carry) ; carry = 0 }
			
			subsum.append(
				act.reversed()
					.map { $0.description.fillWithZeros(len: slice) }
					.joined() + String(repeating: "0", count: r)
			)
			
			//			print(" ", act, subsum.last! )
			
			act = []
			c = 0
			r += 1
			
		} while r < right.count /// Right
		
		
		
		
#if DEBUG
		subsum.forEach { print($0.getFormated(groupingSize: 3, groupingSeparator: " ")) }
#endif
		
		var string = ""
		
		let subslice = 16
//		let subsliceRaise = subslice.raise
		let subsliceRaise = Int(pow(Double(subslice), 2))
		var col = 0
		var colCarry = 0
		
		repeat {
			
			for i in subsum.indices {
				let bl = subsum[i].suffix(subslice)
				col += Int(bl) ?? 0
				//				print(":", Int(bl) ?? 0)
				subsum[i] = String(subsum[i].dropLast(subslice))
			}
			
			//			print("-»", col, "+", colCarry, "=", col+colCarry, terminator: " ")
			col += colCarry
			colCarry = 0
			
			if col >= subsliceRaise { (colCarry, col) = col.quotientAndRemainder(dividingBy: subsliceRaise) }
			
			//			print("»", col, colCarry )
			
			string = String(col).fillWithZeros(len: subslice) + string
			//			print("s", string)
			col = 0
			
		} while !subsum.last!.isEmpty
		
		string.removeAllFirst(charater: "0")
		
		return Arbit(raw: string, negative: negative)
	}
	
	
	static func multiplycpp(_ num1: String, _ num2: String) -> String {
		
		let len1 = num1.count
		let len2 = num2.count
		if len1 == 0 || len2 == 0 {
			return "0"
		}
		
		let arr1 = Array(num1)
		let arr2 = Array(num2)
		
		var result = Array(repeating: 0, count: len1 + len2)
		
		var i_n1 = 0
		var i_n2 = 0
		
		for i in (0..<len1).reversed() {
			var carry = 0
			//		let n1 = Int(num1[num1.index(num1.startIndex, offsetBy: i)].asciiValue! - Character("0").asciiValue!)
			//		let n1 = Int( String(num1[num1.index(num1.startIndex, offsetBy: i)]))!
			let n1 = Int( String(arr1[i]) )!
			
			// To shift position to left after every
			// multiplication of a digit in num2
			i_n2 = 0
			
			// Go from right to left in num2
			for j in (0..<len2).reversed() {
				// Take current digit of second number
				//			let n2 = Int(num2[num2.index(num2.startIndex, offsetBy: j)].asciiValue! - Character("0").asciiValue!)
				//			let n2 = Int( String(num2[num2.index(num2.startIndex, offsetBy: j)] ))!
				let n2 = Int( String(arr2[j]) )!
				
				// Multiply with current digit of first number
				// and add result to previously stored result
				// at current position.
				let sum = n1 * n2 + result[i_n1 + i_n2] + carry
				carry = sum / 10
				result[i_n1 + i_n2] = sum % 10
				i_n2 += 1
			}
			
			// store carry in next cell
			if carry > 0 {
				result[i_n1 + i_n2] += carry
			}
			
			// To shift position to left after every
			// multiplication of a digit in num1.
			i_n1 += 1
		}
		
		// ignore '0's from the right
		var i = result.count - 1
		while i >= 0 && result[i] == 0 {
			i -= 1
		}
		
		// If all were '0's - means either both or
		// one of num1 or num2 were '0'
		if i == -1 {
			return "0"
		}
		
		// generate the result string
		var s = ""
		while i >= 0 {
			s += String(result[i])
			i -= 1
		}
		
		return s
	}
	
	
}


extension String {
	
	func chunkedReverse(_ size: Int) -> [Substring] {
		return stride(from: count, to: 0, by: -size).map {
			return self[ Swift.max($0 - size, 0) ..< $0 ]
		}
	}
	
	func chunked(into size: Int) -> [String] {
		return stride(from: 0, to: count, by: size).map {
			return String( self[ $0 ..< Swift.min($0 + size, count) ] )
		}
	}
	
	func getSlice(_ range: ClosedRange<Int> ) -> Substring {
		let l = self.index(self.startIndex, offsetBy: range.lowerBound )
		let r = self.index(self.startIndex, offsetBy: range.upperBound )
		return self[ l...r ]
	}
	
	func slicerize(by ranges: [ClosedRange<Int>]) -> [Substring] {
		var slices = [Substring]()
		for range in ranges { slices.append(self.getSlice(range)) }
		return slices
	}
	
	func slicerizeInts(by ranges: [ClosedRange<Int>]) -> [Int] {
		var slices = [Int]()
		for range in ranges {
			let int = Int(String(self.getSlice(range)))!
			slices.append(int)
		}
		return slices
	}

}



/*
public func newtonsRoot() -> Double {
	
	func fnc(_ x: Double) -> Double { x*x*x - x*x + 2.0 }
	
	func deriv( _ x: Double ) -> Double { 3.0*x*x - 2.0*x }
	
	var x = self.asDouble!
	var h = fnc(x) / deriv(x)
	
	while abs(h) > 0.001 {
		h = fnc(x) / deriv(x)
		x = x - h
		
	}
	
	return x
}

*/
