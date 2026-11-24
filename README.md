# Arbit

Lossless, arbitrary precision decimal numbers for Swift.

`Arbit` stores a number as decimal digit strings, so `0.1 + 0.2` is exactly `0.3`, and a number can have
as many digits as the memory allows. No dependencies, only Foundation.

```swift
import Arbit

let a: Arbit = "0.1"
let b: Arbit = "0.2"
print(a + b)                                   // 0.3

let big = Arbit("123456789012345678901234567890") * 1_000_000_007
print(big)                                     // 123456789876543201987654320198641975230

print(Arbit(2).sqrRoot(.digits(50)))           // 1.41421356237309504880168872420969807856967187537694
print(Arbit(1000).factorial().count)           // 2568 digits
```

## Install

Swift 5.9 or newer.

```swift
dependencies: [
    .package(url: "https://github.com/metatronsw/Arbit.git", branch: "main")
]
```

## Creating numbers

```swift
let fromInt = Arbit(42)
let literal: Arbit = 42
let text = Arbit("12.5")            // string literal: forgiving, "1 000" and "0xFF" work too
let parsed = Arbit(userInput)       // String variable: strict, nil if it is not a number
let hex = Arbit(hex: "FF")          // also bin: and oct:, or Arbit("ff", radix: 16)
```

Mind the difference: with a literal `Arbit("12.5")` is not optional, with a `String` variable it is.

The strict init accepts a sign, a decimal point, an exponent and the special values:
`"-1.5"`, `".5"`, `"5."`, `"1.5e-10"`, `"nan"`, `"inf"`, `"-inf"`.

**Floating point values are taken exactly.** A `Double` cannot hold 0.1, only the nearest binary fraction,
and Arbit keeps that value in full length:

```swift
Arbit(0.1)      // 0.1000000000000000055511151231257827021181583404541015625
Arbit("0.1")   // 0.1
```

Use a string when you mean the decimal value.

## Exact operations

`+`, `-`, `*`, `%`, the integer power and the comparisons are always exact.

```swift
Arbit("7.5") % 2                                    // 1.5   (the sign follows the dividend, like at Int)
Arbit(-7).quotientAndRemainder(dividingBy: 2)        // (-3, -1)
Arbit(2).power(200)                                  // 1606938044258990275541962092341162602522202993782792835301376
Arbit(2) ** 10                                       // 1024
```

## Precision: the context

Division, roots, logarithms and trigonometry cannot be exact, so they take an `Arbit.Context`:
the count of the fraction digits and the rounding of the last one. There is no global setting.

```swift
let ctx = Arbit.Context(digits: 50, rounding: .halfUp)

a.divided(by: b, ctx)
a.sqrRoot(ctx)
a.ln(.digits(30))            // short form: 30 digits, truncated
```

Without the parameter, and at the `/` operator, the standard context is used: **16 digits, truncated**.

```swift
Arbit(2) / 3                               // 0.6666666666666666
Arbit(2).divided(by: 3, .digits(4))        // 0.6666
Arbit(2).divided(by: 3, Arbit.Context(digits: 4, rounding: .halfUp))   // 0.6667
```

Rounding modes: `.truncate`, `.halfUp` (half away from zero), `.halfEven` (banker's rounding).

## Functions

| | |
|---|---|
| Rounding | `rounded(_:)`, `clamp(fraction:)`, `truncated()`, `floor()`, `ceil()` |
| Powers and roots | `power(_:)`, `**`, `sqrRoot()`, `root(_:)`, `pow2()`, `pow10()` |
| Exponential | `exp()`, `ln()`, `log10()`, `log2()`, `log(base:)` |
| Trigonometry (radians) | `sin()`, `cos()`, `tan()`, `asin()`, `acos()`, `atan()`, `Arbit.atan2(y, x)` |
| Hyperbolic | `sinh()`, `cosh()`, `tanh()` |
| Angles | `toRadians()`, `toDegrees()` |
| Integers | `factorial()`, `Arbit.gcd(_:_:)`, `Arbit.lcm(_:_:)`, `isMultiple(of:)`, `isOdd`, `isEven` |
| Statistics | `Arbit.geoMean(_:)`, `digitalRoot()` |
| Constants | `Arbit.pi`, `.e`, `.ln2`, `.phi`, `.sqr2` ... about 1000 digits each |

The usual global forms exist too: `sqrt(x)`, `exp(x)`, `log(x)`, `sin(x)`, `pow(x, y)`, `floor(x)` ...

`power` takes any exponent: an integer is exact, `1/n` (like `0.5`) is the n-th root,
anything else is `exp(n × ln(x))` for a positive base.

## Bits and number systems

Integers only; a number with fraction gives `nan`. Negative numbers behave as two's complement, like `Int`.

```swift
Arbit(5) ^ 3                 // 6
~Arbit(5)                    // -6
Arbit(1) << 100              // 1267650600228229401496703205376
Arbit(255).asHexadecimal()   // "FF"      also asBinary(), asOctal()
Arbit(1234).asBinaryCodedDecimal()   // [0x12, 0x34]
Int(clamping: Arbit("1e30"))        // Int.max
```

## Error values

Nothing traps and nothing throws: an impossible operation gives an error value, which spreads through
the next operations, like at the floating point types.

```swift
Arbit(1) / 0                 // nan
Arbit(-4).sqrRoot()          // nan
Arbit(0).ln()                // -inf
Arbit.nan + 1                // nan
Arbit.inf * -2               // -inf
```

Check with `isNaN`, `isInfinite`, `isError`; `errorDescription` gives a readable text.

## Output

```swift
let n = Arbit("-1234567.891")

n.description                                              // "-1234567.891"
n.formatted(groupingSeparator: " ", decimalSeparator: ",") // "-1 234 567,891"
n.scientific()                                             // "-1.234567891e6"
n.scientific(significant: 3)                               // "-1.23e6"
n.asDouble                                                 // -1234567.891
```

`formatted()` without parameters uses the separators of the current locale.

## Protocols

`SignedNumeric`, `Comparable`, `Hashable`, `Strideable`, `Codable`, `Sendable`,
`LosslessStringConvertible`, and the integer, float and string literals.

`Codable` writes a single string (`"-12.5"`), so the value survives JSON without any loss.

Arbit is **not** a `BinaryInteger`: it has fractions and its `/` is not an integer division.
The integer tools of that protocol (`words`, `bitWidth`, shifts, conversions) are available as plain functions.
A range of Arbit cannot be walked with `for`, use `stride(from:through:by:)`.

## How it works

The integer and the fraction part are decimal digit strings. Every operation brings the two sides to a common
decimal scale, calculates on the unsigned digits, then puts the decimal point back and normalizes the result
(no leading or trailing zeros, no negative zero). Long multiplication and division work on 9 digit slices,
so a 5000 × 5000 digit product takes less than a millisecond.

## Tests

```bash
swift test
```
