import Foundation



// MARK: Exponential, logarithm, trigonometry
///
/// These functions cannot be exact, so every one has a context parameter:
/// the count of the fraction digits and the rounding of the last one.
/// The angles are in radians.
///
/// Inside they work in fixed point with some more (guard) digits: after every multiplication
/// the fraction is cut to the working digits, and the series go until the next member is zero there.
///

extension Arbit {

	// MARK: Fixed point helpers

	/// Cut to the working digits
	private func cut(_ digits: Int) -> Arbit {
		var value = self
		value.clamp(fraction: digits)
		return value
	}

	/// Product, cut to the working digits
	private func times(_ other: Arbit, _ digits: Int) -> Arbit { (self * other).cut(digits) }

	/// Quotient on the working digits
	private func over(_ other: Arbit, _ digits: Int) -> Arbit { self.divided(by: other, .digits(digits)) }

	/// Quotient by a small integer on the working digits
	private func over(_ number: Int, _ digits: Int) -> Arbit { self.divided(by: Arbit(number), .digits(digits)) }

	/// The last step of the inexact functions: the result is calculated with at least 6 guard digits.
	/// First the guard digits are rounded away (so `1.99999999…` of an exact `2` becomes `2`), then comes the rounding of the context.
	func finished(_ context: Context) -> Arbit {

		let digits = Swift.max(0, context.digits)

		return self
			.rounded(Context(digits: digits + 5, rounding: .halfUp))
			.rounded(Context(digits: digits, rounding: context.rounding))
	}



	// MARK: Constants on any precision

	/// π on the given fraction digits: from the stored constant, or over its length by Machin's formula
	static func pi(digits: Int) -> Arbit {

		if digits + 5 <= (Arbit.pi.fraction?.count ?? 0) { return Arbit.pi.cut(digits) }

		/// π = 16 atan(1/5) - 4 atan(1/239)
		let working = digits + 10

		return (inverseAtan(5, working) * 16 - inverseAtan(239, working) * 4).cut(digits)
	}

	/// atan(1/n) = 1/n - 1/(3n³) + 1/(5n⁵) - ...
	private static func inverseAtan(_ number: Int, _ digits: Int) -> Arbit {

		let square = number * number

		var power = Arbit.one.over(number, digits)
		var sum = power
		var index = 1

		while true {
			power = power.over(square, digits)
			let member = power.over(2 * index + 1, digits)
			if member.isZero { break }
			sum = index % 2 == 1 ? sum - member : sum + member
			index += 1
		}

		return sum
	}

	/// ln(2) on the given fraction digits: from the stored constant, or over its length by series
	static func ln2(digits: Int) -> Arbit {

		if digits + 5 <= (Arbit.ln2.fraction?.count ?? 0) { return Arbit.ln2.cut(digits) }

		/// ln(2) = 2 atanh(1/3)
		let working = digits + 10

		return (atanhSeries(Arbit.one.over(3, working), working) * 2).cut(digits)
	}

	/// ln(10) = 3 ln(2) + ln(1.25) = 3 ln(2) + 2 atanh(1/9)
	static func ln10(digits: Int) -> Arbit {

		let working = digits + 10

		return (ln2(digits: working) * 3 + atanhSeries(Arbit.one.over(9, working), working) * 2).cut(digits)
	}



	// MARK: Series

	/// atanh(z) = z + z³/3 + z⁵/5 + ...   for a small z
	private static func atanhSeries(_ z: Arbit, _ digits: Int) -> Arbit {

		let square = z.times(z, digits)

		var power = z
		var sum = z
		var divisor = 3

		while true {
			power = power.times(square, digits)
			let member = power.over(divisor, digits)
			if member.isZero { break }
			sum += member
			divisor += 2
		}

		return sum
	}

	/// atan(z) = z - z³/3 + z⁵/5 - ...   for a small z
	private static func atanSeries(_ z: Arbit, _ digits: Int) -> Arbit {

		let square = z.times(z, digits)

		var power = z
		var sum = z
		var divisor = 3
		var subtract = true

		while true {
			power = power.times(square, digits)
			let member = power.over(divisor, digits)
			if member.isZero { break }
			sum = subtract ? sum - member : sum + member
			subtract.toggle()
			divisor += 2
		}

		return sum
	}

	/// sin(x) = x - x³/3! + x⁵/5! - ...   for |x| ≤ π/2
	private static func sinSeries(_ x: Arbit, _ digits: Int) -> Arbit {

		let square = x.times(x, digits)

		var member = x
		var sum = x
		var index = 1

		while true {
			member = member.times(square, digits).over(2 * index * (2 * index + 1), digits)
			if member.isZero { break }
			sum = index % 2 == 1 ? sum - member : sum + member
			index += 1
		}

		return sum
	}

	/// cos(x) = 1 - x²/2! + x⁴/4! - ...   for |x| ≤ π/2
	private static func cosSeries(_ x: Arbit, _ digits: Int) -> Arbit {

		let square = x.times(x, digits)

		var member = Arbit.one
		var sum = Arbit.one
		var index = 1

		while true {
			member = member.times(square, digits).over((2 * index - 1) * (2 * index), digits)
			if member.isZero { break }
			sum = index % 2 == 1 ? sum - member : sum + member
			index += 1
		}

		return sum
	}



	// MARK: Exponential

	/// e on the power of self.
	///
	/// The result of an exponent over a million would have hundreds of thousands of digits: that is `inf` (or zero for a negative one).
	public func exp(_ context: Context = .standard) -> Arbit {

		if let error {
			if error == .infinity { return negative ? .zero : self }
			return .nan
		}

		guard !isZero else { return .one }
		guard integer.count <= 6 else { return negative ? .zero : .inf }

		let digits = Swift.max(0, context.digits)
		let whole = Int(integer) ?? 0

		/// The count of the integer digits of e^|x|
		let size = Int(Double(whole) * 0.4343) + 1

		/// A big negative exponent is zero on the asked digits
		if negative, size > digits + 6 { return .zero }

		/// e^x = (e^(x / 2^k))^(2^k) : the series is fast for a small exponent, every squaring doubles the error
		let halvings = (Int.bitWidth - whole.leadingZeroBitCount) + 8
		let working = digits + size + halvings + 10

		let reduced = self.magnitude.over(Arbit(raw: Self.magPow("2", halvings)), working)

		/// e^r = 1 + r + r²/2! + r³/3! + ...
		var member = reduced
		var sum = Arbit.one + reduced
		var index = 2

		while true {
			member = member.times(reduced, working).over(index, working)
			if member.isZero { break }
			sum += member
			index += 1
		}

		for _ in 0..<halvings { sum = sum.times(sum, working) }

		let result = negative ? Arbit.one.over(sum, digits + 6) : sum

		return result.finished(context)
	}



	// MARK: Logarithm

	/// Natural logarithm. Zero gives `-inf`, a negative number gives `nan`.
	public func ln(_ context: Context = .standard) -> Arbit {

		if let error { return (error == .infinity && !negative) ? self : .nan }

		guard !isZero else { return Arbit(negative: true, error: .infinity) }
		guard !negative else { return .nan }

		let digits = Swift.max(0, context.digits)

		/// self = y × 10^e, where 1 ≤ y < 10
		let exponent: Int

		if integer != "0" { exponent = integer.count - 1 }
		else              { exponent = -((fraction ?? "").prefix(while: { $0 == "0" }).count + 1) }

		var y = self
		y.shift(decimals: -exponent)

		/// y = z × 2^k, where 2/3 < z ≤ 4/3
		let half = Arbit(raw: "0", "5")
		let limit = Arbit(raw: "1", "334")
		var halvings = 0

		while y > limit {
			y = y * half
			halvings += 1
		}

		let working = digits + String(exponent.magnitude).count + 10

		/// ln(z) = 2 atanh( (z - 1) / (z + 1) )
		let argument = (y - 1).over(y + 1, working)
		var result = Self.atanhSeries(argument, working) * 2

		if halvings != 0 { result += Self.ln2(digits: working) * Arbit(halvings) }
		if exponent != 0 { result += Self.ln10(digits: working) * Arbit(exponent) }

		return result.finished(context)
	}

	/// Logarithm with the base 10
	public func log10(_ context: Context = .standard) -> Arbit { logarithm(over: { Self.ln10(digits: $0) }, context) }

	/// Logarithm with the base 2
	public func log2(_ context: Context = .standard) -> Arbit { logarithm(over: { Self.ln2(digits: $0) }, context) }

	/// Logarithm with any positive base, except 1
	public func log(base: Arbit, _ context: Context = .standard) -> Arbit {

		guard base.error == nil, !base.negative, !base.isZero, base != .one else { return .nan }

		return logarithm(over: { base.ln(.digits($0)) }, context)
	}

	/// ln(self) / ln(base), where the logarithm of the base comes on the asked working digits
	private func logarithm(over lnBase: (Int) -> Arbit, _ context: Context) -> Arbit {

		let working = Swift.max(0, context.digits) + self.integer.count + 15
		let numerator = self.ln(.digits(working))

		guard numerator.error == nil else { return numerator }

		return numerator.over(lnBase(working), working).finished(context)
	}



	// MARK: Trigonometry

	/// The angle turned into -π ... π, and π on the working digits
	private func reducedAngle(_ digits: Int) -> (angle: Arbit, pi: Arbit) {

		/// A big angle needs as many more digits of π, as many integer digits it has
		let pi = Self.pi(digits: digits + integer.count)
		let turn = pi * 2

		var angle = self.quotientAndRemainder(dividingBy: turn).remainder

		if angle > pi { angle -= turn }
		else if angle < -pi { angle += turn }

		return (angle.cut(digits), pi.cut(digits))
	}

	/// Sine and cosine together, on the working digits
	private func sinCos(_ digits: Int) -> (sin: Arbit, cos: Arbit) {

		let (reduced, pi) = reducedAngle(digits)
		let half = pi.over(2, digits)

		/// Fold into -π/2 ... π/2 :  sin(π - x) = sin(x),  cos(π - x) = -cos(x)
		var angle = reduced
		var flipped = false

		if angle > half { angle = pi - angle ; flipped = true }
		else if angle < -half { angle = -pi - angle ; flipped = true }

		let sin = Self.sinSeries(angle, digits)
		let cos = Self.cosSeries(angle, digits)

		return (sin, flipped ? -cos : cos)
	}

	/// Sine of the angle in radians
	public func sin(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return .nan }

		return sinCos(Swift.max(0, context.digits) + 10).sin.finished(context)
	}

	/// Cosine of the angle in radians
	public func cos(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return .nan }

		return sinCos(Swift.max(0, context.digits) + 10).cos.finished(context)
	}

	/// Tangent of the angle in radians
	public func tan(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return .nan }

		/// Near π/2 the cosine is small, the quotient needs more digits
		let working = 2 * Swift.max(0, context.digits) + 20
		let (sin, cos) = sinCos(working)

		return sin.over(cos, working).finished(context)
	}


	/// Arc tangent, the result is between -π/2 and π/2
	public func atan(_ context: Context = .standard) -> Arbit {

		let digits = Swift.max(0, context.digits)
		let working = digits + 15

		if let error {
			guard error == .infinity else { return .nan }
			let half = Self.pi(digits: working).over(2, working)
			return (negative ? -half : half).finished(context)
		}

		guard !isZero else { return .zero }

		var x = self.magnitude
		var inverted = false

		/// atan(x) = π/2 - atan(1/x)
		if x > .one {
			x = Arbit.one.over(x, working)
			inverted = true
		}

		/// atan(x) = 2 atan( x / (1 + √(1 + x²)) ) : halve the angle, until the series is fast
		let small = Arbit(raw: "0", "1")
		var doublings = 0

		while x > small {
			let root = (x.times(x, working) + 1).sqrRoot(.digits(working))
			x = x.over(root + 1, working)
			doublings += 1
		}

		var result = Self.atanSeries(x, working) * Arbit(1 << doublings)

		if inverted { result = Self.pi(digits: working).over(2, working) - result }

		return (negative ? -result : result).finished(context)
	}

	/// Arc sine, the result is between -π/2 and π/2. Out of -1 ... 1 it is `nan`.
	public func asin(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return .nan }

		let digits = Swift.max(0, context.digits)
		let working = 2 * digits + 20

		let order = Self.compareMagnitude(self, .one)

		if order > 0 { return .nan }

		if order == 0 {
			let half = Self.pi(digits: working).over(2, working)
			return (negative ? -half : half).finished(context)
		}

		/// asin(x) = atan( x / √(1 - x²) )
		let root = (Arbit.one - self * self).sqrRoot(.digits(working))

		return self.over(root, working).atan(.digits(digits + 6)).finished(context)
	}

	/// Arc cosine, the result is between 0 and π. Out of -1 ... 1 it is `nan`.
	public func acos(_ context: Context = .standard) -> Arbit {

		let working = Swift.max(0, context.digits) + 10
		let asin = self.asin(.digits(working))

		guard asin.error == nil else { return .nan }

		return (Self.pi(digits: working).over(2, working) - asin).finished(context)
	}

	/// The angle of the point (x, y) from the x axis, between -π and π
	public static func atan2(_ y: Arbit, _ x: Arbit, _ context: Context = .standard) -> Arbit {

		guard y.error == nil, x.error == nil else { return .nan }

		let working = Swift.max(0, context.digits) + 10
		let pi = Self.pi(digits: working)

		if x.isZero {
			if y.isZero { return .zero }
			let half = pi.over(2, working)
			return (y.negative ? -half : half).finished(context)
		}

		let angle = y.over(x, 2 * working + y.integer.count).atan(.digits(working))

		if !x.negative { return angle.finished(context) }

		return (y.negative ? angle - pi : angle + pi).finished(context)
	}



	// MARK: Hyperbolic

	/// Hyperbolic sine: (e^x - e^-x) / 2
	public func sinh(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return isInfinite ? self : .nan }

		let working = Swift.max(0, context.digits) + 10

		return (self.exp(.digits(working)) - (-self).exp(.digits(working))).over(2, working).finished(context)
	}

	/// Hyperbolic cosine: (e^x + e^-x) / 2
	public func cosh(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return isInfinite ? .inf : .nan }

		let working = Swift.max(0, context.digits) + 10

		return (self.exp(.digits(working)) + (-self).exp(.digits(working))).over(2, working).finished(context)
	}

	/// Hyperbolic tangent: (e^2x - 1) / (e^2x + 1)
	public func tanh(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return isInfinite ? (negative ? -Arbit.one : .one) : .nan }

		let working = Swift.max(0, context.digits) + 10
		let power = (self * 2).exp(.digits(working))

		guard power.error == nil else { return negative ? -Arbit.one : .one }

		return (power - 1).over(power + 1, working).finished(context)
	}



	// MARK: Degrees

	/// Degrees to radians: × π / 180
	public func toRadians(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return self }

		let working = Swift.max(0, context.digits) + integer.count + 10

		return (self * Self.pi(digits: working)).over(180, working).finished(context)
	}

	/// Radians to degrees: × 180 / π
	public func toDegrees(_ context: Context = .standard) -> Arbit {

		guard error == nil else { return self }

		let working = Swift.max(0, context.digits) + integer.count + 10

		return (self * 180).over(Self.pi(digits: working), working).finished(context)
	}

}



// MARK: Global functions

public func exp(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.exp(context) }

public func log(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.ln(context) }

public func log10(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.log10(context) }

public func log2(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.log2(context) }

public func sin(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.sin(context) }

public func cos(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.cos(context) }

public func tan(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.tan(context) }

public func asin(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.asin(context) }

public func acos(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.acos(context) }

public func atan(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.atan(context) }

public func atan2(_ y: Arbit, _ x: Arbit, _ context: Arbit.Context = .standard) -> Arbit { Arbit.atan2(y, x, context) }

public func sinh(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.sinh(context) }

public func cosh(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.cosh(context) }

public func tanh(_ value: Arbit, _ context: Arbit.Context = .standard) -> Arbit { value.tanh(context) }
