import Foundation



// MARK: Math functions

infix operator **
infix operator **=

extension Arbit {
	
	
	public mutating func raise(by: Int) {
		guard by != 0 else { self = Arbit.zero ; return }
		let zeros = String(repeating: "0", count: by)
		self.integer = self.integer + zeros
	}
	
	
	// TODO: átalakítani roundra...
	public mutating func clamp(fraction digits: Int = Self.precision) {
		
		guard self.fraction != nil else { return }
		
		guard digits > 0 else {
			self.fraction = nil
			return
		}
		
		self.fraction = String(self.fraction!.prefix(digits))
	}
	
	
	// TODO: tizedes (n) implementálni
	public func power( _ n: Arbit ) -> Arbit? {

		guard let to = n.asInt else { return nil }
		guard to < 9999 else { return nil }
		
		if n >= 0 {
			var r: Arbit = 1
			for _ in 0..<to { r *= self }
			return r
		} 
		
		else {
			var r: Arbit = 1
			for _ in 0..<(-to) { r *= self }
			return 1 / r
		}
		
	}
	
//	public static func ** (lhs: Arbit, rhs: Arbit) -> Arbit { lhs.power(rhs) }
//	public static func **= (lhs: inout Arbit, rhs: Arbit) { lhs = lhs.power(rhs) }
	
	/// Square root of self
	public func sqrRoot(precision: Double = 0.0000001, iterationLimit: Int = 100 ) -> Arbit {
		
		//FIXME: majd arra figyelni hogy x√y esetén lehetséges negativ gyök, és köbgyöknél is
		guard !self.negative else { return .nan }
		
		
		let num = self.asDouble!
		var prev = num
		var root = 0.0
		var count = 0
		
		while count < iterationLimit {
			
			root = (prev + (num / prev)) * 0.5
			
			if abs(root-prev) < precision { break }
			
			prev = root
			count += 1
		}
		
		let rounded = root.rounded()
		//		if num == rounded*rounded  { print(count, "R!", num, root, String(format: "%g", rounded) ) ; return rounded }
		if num == rounded*rounded  { return Arbit(rounded) }
		
		return Arbit(root)
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
		
		func digitalRoot(ofNSquare NxN: String) -> Int {
			
			let NDigRoot = digitalRoot(of: NxN)
			
			if NDigRoot == 1 || NDigRoot == 8 { return 1 }
			if NDigRoot == 2 || NDigRoot == 7 { return 4 }
			if NDigRoot == 3 || NDigRoot == 6 { return 9 }
			if NDigRoot == 4 || NDigRoot == 5 { return 7 }
			
			return 0 // Added return statement to handle all paths
		}
		
	}
	
	
	/// Geometric avarage
	public static func geoMean(_ array: [Arbit]) -> Arbit {
		
		guard var sum = array.first else { return zero }
		
		for i in 1 ..< array.count {
			print (sum, array[i])
			sum = sum * array[i]
		}
		
		return sum.sqrRoot()
		
	}
	
}



// MARK: Global math functions

public func sqrt(_ value: Arbit) -> Arbit { value.sqrRoot() }

public func pow(_ lhs: Arbit, _ rhs: Arbit) -> Arbit? { lhs.power(rhs) }


