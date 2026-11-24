# Arbit

Swift csomag: veszteségmentes, tetszőleges pontosságú decimális szám (`Arbit` struct), tizedes törtekkel.
Függőség nincs, csak Foundation. **Szándékosan String-alapú** – ne javasolj számjegytömböt vagy külső könyvtárat.

## Parancsok

```bash
swift build
swift test
swift test --filter Test_Functions/test_Against_References
swift run Run          # Run/main.swift – kézi próbálgató, nem része a könyvtárnak
```

Swift 5.9+ kell. Állapot (2026-11-24): 110 teszt, mind zöld, fordítási figyelmeztetés nincs.

## Felépítés

| Fájl | Tartalom |
|---|---|
| `Sources/Arbit/Arbit.swift` | A struct, `Context`, `RoundingMode`, `normalize`, `scaled`/`fromScaled`, initek, `Comparable`, `Hashable`, `Codable`, formázás, `scientific()` |
| `Arbit_Numeric.swift` | Hibaterjedés, `+ - * /`, `divided(by:_:)`, `quotientAndRemainder`, a `mag…` függvények, szeletelés, hosszú osztás, `applyRounding` |
| `Arbit_Binary.swift` | Bitműveletek, `words`, `%`, vegyes összehasonlítás, `FixedWidthInteger` konverziók, `shift(decimals:)`, bin/oct/hex |
| `Arbit_Math.swift` | `power`, `**`, `sqrRoot` (írásbeli), `root` (Newton), `rounded`, `clamp`, `floor`, `ceil`, `factorial`, `gcd`, `lcm`, `geoMean` |
| `Arbit_Functions.swift` | `exp`, `ln`, `log…`, trigonometria, inverz, hiperbolikus, fok–radián; π és ln 2 tetszőleges hosszban |
| `Arbit_Const.swift` | Matematikai állandók (~1000 jegy), `pow2`, `pow10` |
| `Arbit_Extensions.swift` | `Int`/`String` segédek |
| `Arbit_UnusedFunc.swift` | Régi kísérletek, referenciának megtartva. A `Package.swift` kizárja a buildből. |
| `Tests/ArbitTests/ArbitTests.swift` | Eredeti tesztek (init, kiírás, alapműveletek, hosszú műveletek) |
| `Tests/ArbitTests/ArbitBehaviourTests.swift` | Viselkedés-tesztek területenként, rögzített seedű véletlengenerátorral |
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
teszi vissza a tizedesvesszőt és normalizál. Az előjel egyetlen helyen dől el, a művelet végén.

**Szeletek:** a hosszú szorzás és osztás a stringet 9 jegyes szeletekre (`[UInt64]`) bontja, mert két szelet
szorzata belefér egy `UInt64`-be. Az osztás Knuth D algoritmusa. A bináris/hex átváltás 32 bites limbeken megy.

**Pontosság:** nincs globális beállítás. Ami nem lehet pontos, az `Arbit.Context` paramétert kap
(`digits` + `rounding`), alapértéke `.standard` (16 jegy, csonkolás). Rövid alak: `.digits(50)`.
A `/` operátor és a paraméter nélküli hívás a `.standard`-et használja.

**Kerekítés:** az osztás és a gyökök egy jeggyel többet számolnak, az `applyRounding(_:exact:mode:)` dönt.
Az `exact` jelzi, hogy az őrjegy után nincs több (a banker's kerekítés döntetlenjéhez kell).

**Sorfejtéses függvények** (`Arbit_Functions.swift`): fixpontosan számolnak néhány őrjeggyel
(`times`, `over`, `cut` segédek), a sor addig megy, amíg a következő tag nulla a munkapontosságon.
A végén a `finished(_:)` előbb az őrjegyeket kerekíti le (így az `1.9999…` pontos `2` lesz), utána jön a
kontextus kerekítése. Új függvényt ugyanebben a mintában írj.

**Sebesség-szabály:** forró úton `utf8.count` és `utf8` indexek kellenek. A `String.count`, `prefix`,
`dropLast`, `index(_:offsetBy:)` karakterenként lépked, ezek 1000 jegynél 40-szeres lassulást okoztak.

## Viselkedési szabályok (a tulajdonos döntései, 2026-11-24)

Ezeket ne változtasd meg kérdezés nélkül.

| Téma | Szabály |
|---|---|
| Ábrázolás | String-alapú marad. |
| Pontosság | Nincs globális állapot; `Arbit.Context` paraméter. `/` és az alapérték: 16 jegy, csonkolás. |
| Hibaértékek | Terjednek, mint a `Double`-nél: `nan + 1 = nan`, `inf * 2 = inf`, `inf - inf = nan`. Nincs `throws`, nincs trap. |
| Nullával osztás | `x / 0` és `x % 0` → `nan` (nem `inf`). `ln(0)` → `-inf`. |
| `description` hibára | `nan`, `inf`, `-inf`. A hosszú szöveg az `errorDescription`-ben van. |
| `Arbit(String)` futásidőben | `init?` – érvénytelenre `nil`. Elfogad: előjel, `.5`, `5.`, `1.5e-10`, `nan`, `inf`. |
| String **literál** | Megengedő és nem opcionális: `T("1 000")`, `T("0x1F")`. Számjegy nélkül `.empty` hibaérték. |
| `Float` / `Double` init | **Pontos bináris érték**: `Arbit(0.1)` = `0.1000000000000000055511151231257827…`. Pontos tizedeshez `"0.1"` kell. |
| Protokollok | `SignedNumeric`, `Comparable`, `Hashable`, `Strideable`, `Codable`, `Sendable`. **Nem** `BinaryInteger` – a hozzá tartozó funkciók sima függvényként megmaradtak. |
| Bitműveletek | Csak egészre, törtre `nan`. Negatív szám kettes komplemensként: `~5 = -6`. `>>` lefelé kerekít. |
| `%` | Mint az `Int`: a maradék az osztandó előjelét örökli. Törtre is: `7.5 % 2 = 1.5`. |
| `power` | Nem opcionális. Egész kitevő pontos; `1/n` gyökként; más tört `exp(n·ln x)`, csak pozitív alapra, különben `nan`. |
| `**` | Erősebb a szorzásnál, jobbról köt. A prefix mínusz erősebb: `-x ** 2 = (-x)²`. |
| Szögek | Radiánban. |
| `pow2` / `pow10` negatívra | Pontos tört: `pow2(-1) = 0.5`. |
| `exp` határa | 10⁶ feletti kitevő `inf` (negatívra `0`), mert az eredmény százezer jegyű lenne. |

## Buktatók

- **Literál vs. változó:** `T("12")` literállal nem opcionális és megengedő, `T(valtozo)` szigorú `init?`.
  A `T("12")!` ezért fordítási hiba. Tesztben a futásidejű úthoz ott az `A(_:)` segéd.
- **Lebegőpontos literál a tesztben:** `XCTAssertEqual(x, 0.8)` a 0.8 bináris értékével hasonlít – `"0.8"` kell.
- **`description` nem tartja a záró nullát:** `1.4142135623730950` → `"1.414213562373095"`.
- **Csonkolt értéket ne szorozz tesztben:** `atan(1, 50 jegy) × 4` nem egyenlő a 50 jegyre csonkolt π-vel.
  Számolj több jeggyel, és utána vágj.
- **Globális matematikai függvények neve ütközik** az `Arbit` metódusaival az extensionön belül:
  ott `Foundation.log10(…)`, `Foundation.pow(…)`, `Swift.max(…)` kell.
- **Tartomány nem járható be:** `for i in T(1)...T(5)` nem fordul, `stride(from:through:by:)` kell.
- **Fájlszerkesztés szkriptből:** a forrásfájlok üres sorai vegyesen tabosak és üresek; pontos szövegegyezés
  helyett szóköz-tűrő illesztés kell.
- **Referenciaértékek:** a `Decimal` 38 jegyig pontos. A sorfejtéses függvények referenciái a
  `Test_Functions.references` táblában vannak, Python `decimal` modullal számolva; hosszabb eredményt
  azonossággal ellenőrizz (`ln(exp(x)) == x`, `sin² + cos² == 1`, `√(n²) == n`).

## Ami még nincs kész

- **`stride` szélső esetei** (TODO az `Arbit.swift`-ben a `Strideable` felett): `nan` kezdő- vagy végponttal
  a sorozat soha nem ér véget, nulla lépésközzel a program megáll. A standard könyvtár viselkedése;
  saját `Arbit.stride(...)` kellene, ami hibát dob vagy üres sorozatot ad. A tulajdonos későbbre tette.
- A `karatsuba` megvan és tesztelt, de a `*` nem használja (a tulajdonos szerint most nem fontos).
- A sorfejtéses függvények 1000 jegy felett lassulnak (`sin` 1000 jegyre ~0,1–0,3 s), mert π-t az
  állandó hosszán túl Machin-képlettel újraszámolják, gyorsítótár nélkül (nincs megosztott állapot).
- `exp`/`ln` argumentum-csökkentése egyszerű; nagy pontosságra AGM vagy bináris hasítás gyorsabb volna.
- `asinh`, `acosh`, `atanh`, gamma-függvény, binomiális együttható nincs.
- A `formatted()` nem ismer mérnöki vagy pénznem formátumot.
