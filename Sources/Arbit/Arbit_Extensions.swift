import Foundation


extension Int {
	
	public var pow10: Int {
		switch self {
			case 0:  return 1
			case 1:  return 10
			case 2:  return 100
			case 3:  return 1000
			case 4:  return 10000
			case 5:  return 100000
			case 6:  return 1000000
			case 7:  return 10000000
			case 8:  return 100000000
			case 9:  return 1000000000
			case 10: return 10000000000
			case 11: return 100000000000
			case 12: return 1000000000000
			case 13: return 10000000000000
			case 14: return 100000000000000
			case 15: return 1000000000000000
			case 16: return 10000000000000000
			case 17: return 100000000000000000
			case 18: return 1000000000000000000
			default: fatalError("Raise \(self) is too big")
		}
	}
	
	
	public var pow2: Int {
		switch self {
			case 0: return 1
			case 1: return 2
			case 2: return 4
			case 3: return 8
			case 4: return 16
			case 5: return 32
			case 6: return 64
			case 7: return 128
			case 8: return 256
			case 9: return 512
			case 10: return 1024
			case 11: return 2048
			case 12: return 4096
			case 13: return 8192
			case 14: return 16384
			case 15: return 32768
			case 16: return 65536
			case 17: return 131072
			case 18: return 262144
			case 19: return 524288
			case 20: return 1048576
			case 21: return 2097152
			case 22: return 4194304
			case 23: return 8388608
			case 24: return 16777216
			case 25: return 33554432
			case 26: return 67108864
			case 27: return 134217728
			case 28: return 268435456
			case 29: return 536870912
			case 30: return 1073741824
			case 31: return 2147483648
			case 32: return 4294967296
			case 33: return 8589934592
			case 34: return 17179869184
			case 35: return 34359738368
			case 36: return 68719476736
			case 37: return 137438953472
			case 38: return 274877906944
			case 39: return 549755813888
			case 40: return 1099511627776
			case 41: return 2199023255552
			case 42: return 4398046511104
			case 43: return 8796093022208
			case 44: return 17592186044416
			case 45: return 35184372088832
			case 46: return 70368744177664
			case 47: return 140737488355328
			case 48: return 281474976710656
			case 49: return 562949953421312
			case 50: return 1125899906842624
			case 51: return 2251799813685248
			case 52: return 4503599627370496
			case 53: return 9007199254740992
			case 54: return 18014398509481984
			case 55: return 36028797018963968
			case 56: return 72057594037927936
			case 57: return 144115188075855872
			case 58: return 288230376151711744
			case 59: return 576460752303423488
			case 60: return 1152921504606846976
			case 61: return 2305843009213693952
			case 62: return 4611686018427387904
			default: fatalError("Power of 2^\(self) is too big for Int")
		}
	}
	
	
	public func pow( _ x: Int ) -> Int {
		
		let mul = self
		var sum = self
		
		for _ in stride(from: 1, to: x, by: 1) {
			sum *= mul
		}
		
		return sum
	}
	
	
	public init(_ char: Character) {
		self.init( char.unicodeScalars.first!.value - 48 ) // TODO: Lassú ?
	}
	
}

extension UInt {
	public init(_ char: Character) {
		self.init( char.unicodeScalars.first!.value - 48 ) // TODO: Lassú ?
	}
}




extension String {
	
	@inlinable
	public static func random(numbers n: Int) -> String {
		
		guard n > 0 else { return "0" }
		
		var randomString = [Character]()
		
		randomString.append("123456789".randomElement()!)
		
		for _ in 1..<n {
			randomString.append("1234567890".randomElement()!)
		}
		
		return String(randomString)
	}
	
	
	public func getFormated(groupingSize: Int = 3, groupingSeparator: String = " ") -> String {
		
		var gapPoint = self.count % groupingSize
		
		if groupingSize >= self.count { gapPoint = self.count + 2 }
		else if gapPoint == 0 { gapPoint = groupingSize }
		
		var index = 1
		var string = ""
		
		for chr in self {
			
			if index > gapPoint {
				string.append( groupingSeparator + String(chr) )
				gapPoint += groupingSize - 1
				continue
			}
			
			string.append(chr)
			index += 1
		}
		
		return string
	}
	
}

extension String {
	
	@discardableResult
	mutating func removeAllLast(charater chr: String) -> String {
		while self.hasSuffix(chr) { self.removeLast() }
		return self
	}
	
	
	@discardableResult
	mutating func removeAllFirst(charater chr: String) -> String {
		while self.hasPrefix(chr) { self.removeFirst() }
		return self
	}
	
	
	
	func fillWithZeros(len: Int) -> String {
		guard self.count < len else { return self }
		return String(repeating: "0", count: len - self.count) + self
	}
	
	
	mutating func cleanToZero() {
		if self.isEmpty { self = "0" }
	}
	
}

extension String? {
	// TODO: optimalizálni .. keressen indexpontot és csak a végén vágjon 
	mutating func cleanToNil() {
		self?.removeAllLast(charater: "0")
		if self?.isEmpty == true { self = nil }
	}
}



extension String {
	
	subscript (i: Int) -> Character { self[index(startIndex, offsetBy: i)] }
	
	subscript (r: Range<Int>) -> Substring {
		
//		let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)),
//														upper: min(count, max(0, r.upperBound))))

		let range = Range(uncheckedBounds: (lower: r.lowerBound, upper: r.upperBound) )
		
		let start = index(startIndex, offsetBy: range.lowerBound)
		let end = index(start, offsetBy: range.upperBound - range.lowerBound)
		
		return self[start ..< end]
	}
	
	func chunkedReverse(by size: Int) -> [Substring] {
		return stride(from: count, to: 0, by: -size).map {
			return self[ Swift.max($0 - size, 0) ..< $0 ]
		}
	}

	func chunked(by size: Int) -> [String] {
		return stride(from: 0, to: count, by: size).map {
			return String( self[ $0 ..< Swift.min($0 + size, count) ] )
		}
	}
}

 





#if DEBUG
extension [[Int]] { /// Matrix print
	
	internal func debugPrint(_ slicelen: Int) {
		print("\n")
		
		var shift = String(repeating: " ", count: self.count)
		
		self.forEach { row in
			print(shift, terminator: "")
			
			let line = row.map { $0.description }.joined()
			print( line)
			shift.removeLast()
		}
	}
}
#endif





// MARK: Global functions

/// Stride function with limiter.
/// The 'by' varriable is always positive...
///
func makeRanges(from: Int, through: Int , by: Int) -> [ClosedRange<Int>] {
	
	var ranges: [ClosedRange<Int>]
	var (low, upp) : (Int, Int)
	
	/// Foward
	///
	if from < through {
		
		let stepp = abs(by) - 1
		low = from + stepp
		ranges = [from ... low]
		
		for _ in 0 ..< (through-from)/stepp {
			low += 1
			upp = low + stepp
			ranges.append( low ... upp )
			low = upp
		}
		
		let end = through-1
		if ranges.last!.lowerBound > end { ranges.removeLast() }
		if ranges.last!.upperBound > end {
			ranges[ranges.count-1] = ranges.last!.lowerBound ... end
		}
	}
	
	/// Reverse
	///
	else {
		let stepp = abs(by)
		low = from - stepp + 1
		ranges = [low ... from]
		
		for _ in 0 ..< (from-through)/stepp {
			upp = low - 1
			low = upp - stepp + 1
			ranges.append( low ... upp )
		}
		
		//		print(ranges)
		if ranges.last!.upperBound < through { ranges.removeLast() }
		if ranges.last!.lowerBound < through {
			
			//			print("paprika!!!")
			ranges[ranges.count-1] = through ... ranges.last!.upperBound
		}
	}
	
	
	//		print(ranges)
	return ranges
}




