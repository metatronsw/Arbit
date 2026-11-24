# Arbit

Swift csomag: veszteségmentes, tetszőleges pontosságú decimális szám (`Arbit` struct), tizedes törtekkel.
Függőség nincs, csak Foundation. **Szándékosan String-alapú** – ne javasolj számjegytömböt vagy külső könyvtárat.

## Parancsok

```bash
swift build
swift test
swift test --filter Test_Division/test_Rounding_Modes
swift run Run          # Run/main.swift – kézi próbálgató, nem része a könyvtárnak
```

Swift 5.9+ kell. Állapot (2026-11-24): 86 teszt, mind zöld, fordítási figyelmeztetés nincs.

## Felépítés

| Fájl | Tartalom |
|---|---|
| `Sources/Arbit/Arbit.swift` | A struct, `normalize`, `scaled`/`fromScaled`, initek (Int/Double/String/radix), `Comparable`, `Hashable`, formázás |
| `Arbit_Numeric.swift` | Hibaterjedés, `+ - * /`, `quotientAndRemainder`, `magAdd`/`magMul`/`magPow`/`magDivMod`, `applyRounding` |
| `Arbit_Binary.swift` | `BinaryInteger` konformancia: `words`, `& \| ^ ~ << >> %`, vegyes összehasonlítás; `shift(decimals:)`; bin/oct/hex |
| `Arbit_Math.swift` | `power`, `sqrRoot` (írásbeli), `root` (Newton), `rounded`, `clamp`, `raise`, `geoMean`, `digitalRoot` |
| `Arbit_Const.swift` | Matematikai állandók (~1000 jegy), `pow2`, `pow10` |
| `Arbit_Extensions.swift` | `Int`/`String` segédek (`pow10`, `chunked`, `cleanToNil`, `getFormated`) |
| `Arbit_UnusedFunc.swift` | Régi kísérletek, referenciának megtartva. A `Package.swift` kizárja a buildből. |
| `Tests/ArbitTests/ArbitTests.swift` | Eredeti tesztek (init, kiírás, alapműveletek, hosszú műveletek) |
| `Tests/ArbitTests/ArbitBehaviourTests.swift` | Viselkedés-tesztek: összehasonlítás, előjelek, algebrai tulajdonságok, beolvasás, osztás, hibaértékek, matek, bitek |
| `Tests/ArbitTests/Measure.swift` | Sebességmérések |

### Belső működés

**Ábrázolás:** `integer: String` + `fraction: String?` + `negative: Bool` + `error: Errors?`.

**Kanonikus alak** (a `normalize()` állítja elő, minden init és művelet végén lefut):
- `integer` nem üres, nincs vezető nulla, csak számjegy
- `fraction` vagy `nil`, vagy nem üres és nem végződik `0`-ra
- nulla esetén `negative == false`

Az `==` és a `hash` erre az alakra épít. Egyedül az `init(raw:)` nem normalizál (gyors út, „use with care").

**Aritmetika mintája:** minden művelet a két operandust közös tizedes skálára hozza (`scaled(to:)` → előjel
nélküli egész számjegy-string), a `mag…` függvényekkel számol, majd a `fromScaled(_:scale:negative:)`
teszi vissza a tizedesvesszőt és normalizál. Az előjel mindig egyetlen helyen dől el, a művelet végén.
Új műveletet ugyanígy érdemes írni.

**Kerekítés:** az osztás és a gyökök egy jeggyel többet számolnak, az `applyRounding(_:exact:)` dönt.
Az `exact` jelzi, hogy az őrjegy után nincs több (a banker's kerekítés döntetlenjéhez kell).

**Globális állapot:** `Arbit.precision` (alap 16), `Arbit.rounding` (alap `.truncate`), `decSep`, `groupSep` –
statikus `var`-ok, nem szálbiztosak. Tesztben az `ArbitTestCase` ősosztály menti és állítja vissza őket.

## Viselkedési szabályok (a tulajdonos döntései, 2026-11-24)

Ezeket ne változtasd meg kérdezés nélkül.

| Téma | Szabály |
|---|---|
| Hibaértékek | Terjednek, mint a `Double`-nél: `nan + 1 = nan`, `inf * 2 = inf`, `inf - inf = nan`. Nincs `throws`, nincs trap. |
| Nullával osztás | `x / 0` és `x % 0` → `nan` (nem `inf`; a meglévő tesztek így várják). |
| `description` hibára | `nan`, `inf`, `-inf`. A hosszú szöveg az `errorDescription`-ben van. |
| `Arbit(String)` futásidőben | `init?` – érvénytelenre `nil`. Elfogad: előjel, `.5`, `5.`, `1.5e-10`, `nan`, `inf`. |
| String **literál** | Megengedő: `T("1 000")`, `T("0x1F")`, a szemetet kiszűri. Számjegy nélkül `.empty` hibaérték. |
| Osztás kerekítése | `Arbit.rounding`: `.truncate` (alap) / `.halfUp` / `.halfEven`. |
| `Float` / `Double` init | **Pontos bináris érték**: `Arbit(0.1)` = `0.1000000000000000055511151231257827…`. A `let a: Arbit = 0.1` literál is ilyen; pontos tizedeshez `"0.1"` kell. |
| Protokollok | `SignedInteger` (ezzel `BinaryInteger`), `Strideable`, `Hashable`, `SignedNumeric`. |
| Bitműveletek | Csak egészre, törtre `nan`. Negatív szám kettes komplemensként: `~5 = -6`, `-1 & 255 = 255`. `>>` lefelé kerekít. |
| `%` | Mint az `Int`: a maradék az osztandó előjelét örökli. Törtre is: `7.5 % 2 = 1.5`. |
| Gyökök | `sqrRoot(digits:)` írásbeli gyökvonás, `root(_:digits:)` Newton. Négyzetszámra/hatványra pontos. |
| `power` | Egész kitevő gyorshatványozással; `1/n` alakú tört kitevő gyökként; más törtre `nil`. |
| `pow2` / `pow10` negatívra | Pontos tört: `pow2(-1) = 0.5`, `pow10(-1) = 0.1`. |

## Buktatók

- **Literál vs. változó:** `T("12")` literállal az `init(stringLiteral:)`-t hívja (nem opcionális, megengedő),
  `T(valtozo)` a szigorú `init?`-et. Tesztben a futásidejű úthoz ott az `A(_:)` segéd (`T(string)!`).
- **Lebegőpontos literál a tesztben:** `XCTAssertEqual(x, 0.8)` a 0.8 bináris értékével hasonlít – `"0.8"` kell.
- **`description` nem tartja a záró nullát:** `1.4142135623730950` → `"1.414213562373095"`.
- **`/` törtet ad**, pedig a típus `BinaryInteger`. Generikus egész-algoritmus, ami csonkoló osztást vár, rosszul fog számolni.
- **Vegyes összehasonlítás:** `arbit == int` a saját operátorainkat használja (tört is jó);
  fordítva (`int == arbit`) a standard könyvtár a `words` alapján hasonlít, azaz csak az egészrészt látja.
- **Negatív kitevő és gyök** a `precision`-től függ (osztást végez).
- **A véletlen tesztek** a `Decimal`-t használják referenciának (38 jegy); ennél hosszabb eredményt
  algebrai azonossággal ellenőrizz (`a == q*b + r`, `√(n²) == n`), ne `Decimal`-lal.

## Ami még nincs kész

- `exp`, `ln`, `log10`, trigonometria (az állandók megvannak hozzá), `factorial`, `gcd`, `lcm`
- `**` operátor (deklarálva, implementáció kikommentelve); általános tört kitevő
- `floor`, `ceil`; tudományos jelölés kiírása Stringként (`getSientific` csak tuple-t ad)
- `Codable`, `Sendable`; szálbiztos beállítások
- `digitalRoot` a törtrészt figyelmen kívül hagyja
- Teljesítmény: a szorzás jegyenkénti O(n·m), a hosszú osztás lépésenként string-műveleteket végez,
  a `decToBin` O(n²). A `karatsuba` megvan, de a `*` nem használja.
- A `README.md` még a régi jegyzeteket tartalmazza.
- `Errors.calcError(String)` debug-maradvány.
