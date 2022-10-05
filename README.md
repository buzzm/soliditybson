# soliditybson

A native Solidity codec for BSON

## Introduction and Purpose

Solidity is the smart contract language for Ethereum.  It is powerful and
expressive but with a nod to its "parsimonious processing" roots, it has several
major issues which make "real world" sending and receiving of non-trivial data
difficult.  These issues are mirrored in the popular web3 code generator
framework:

 *  There is no concept of a C/C++ struct that can be defined and shared
    *between the smart contract and a client program*.  You can define structs in
    the contract only.  This means that contract function signatures are limited
    to lists of scalars going in and n-sized `Tuple` objects coming out:
    ```
    MyContract ct2 = MyContract.load(contractAddr, ...);
    // Suppose we wish to set just name, age, and phone on a "customer" record
    // which contains additional fields like address and region.  We must set
    // up each scalar discretely:
    TransactionReceipt r1 = ct2.setNameAgePhone(name, age, phone).send();
    
    // If we only wanted to set name and age, we need a different function:
    TransactionReceipt r1 = ct2.setJustNameAge(name, age).send();

    // Getting things out is equally clunky -- especially since web3 vends
    // strings as byte[], not String!
    Tuple3<byte[],BigInteger,byte[]> items = ct2.getNameAgePhone().send();
    System.out.println("name: " + new String(items.getValue1())); // have to construct String from byte[]

    Tuple2<byte[],BigInteger> items2 = ct2.getNameAge().send();
    System.out.println("age: " + items2.getValue2());
    ```
    Indeed, the maximum number of arguments that can be retrieved without
    special changes to web3j is 20 (`Tuple20<>` is "biggest" pre-canned
    return type).  Even with just a few data items, the combinations can
    get very large.  And you will want to code them *all* in advance because
    changing smart contracts (as a result of adding new functions) is a
    non-trivial procedure involving migrations, call forwarding, etc.
 *  Solidity has a great deal of flexibility over bitsize and sign of
    integers but in web3j, everything is converted to `BigInteger` which
    confounds use of simpler `int` and `long` types
 *  Solidity has no native datetime or penny-precise decimal types.  These are
    critical types to have in modern non-trivial data structures (esp. where
    monies are involved) and combined with the inability to share structs, the
    fidelity of data moving in and out of the contracts is severely reduced.
 *  Solidity arrays have no append(), making construction of rich array data tedious.
 

## Enter BSON

BSON is a data SDK.  It "feels" like JSON
(and indeed the name means binary JSON) but is much more powerful in
two vitally important ways:

  *  BSON has a larger and important scalar data type suite:
     *  32 and 64 bit integers, doubles, and decimal128
        numbers are all discrete types whereas JSON only has "number"
     *  Native datetime so it avoids issues with ISO8601 strings and
        other perils of dealing with dates as strings or, for example,
        integer milliseconds since the epoch in a plain integer field
     *  Native byte[] so it avoids string encoding issues
  *  BSON has a bytestream specification [(here is the official site)](https://bsonspec.org)
     with codecs in at least 20 
     languages.  For example, the Java codec is rich with classes and methods
     which can be used to create arbitrarily complex structures, upon which the
     "toBytes()" method can be called to create a bytestream which can be
     sent to a python program with the python BSON codec that can call
     "fromBytes()" to yield dicts, native `datetime.datetime` objects, etc.
     There is no "parsing" in BSON but rather encode/decode.  As a result, it does
     not suffer from the issues that can cause problems in JSON -- which is just
     a string -- like escaping quotes, pretty-format vs. CR-delimited, lossy
     roundtripping with whitespace (e.g. tabs become spaces)
     
BSON was developed by MongoDB and is actively maintained.  As the #5 database
in the world and growing, it stands to reason that BSON will be around as long
as MongoDB is around which at this time seems to be some time.  It is important
to note that the BSON spec and codecs are code-independent of MongoDB i.e. the
C driver `libbson.1.so` has no references to the database product at all.  It
is also worth noting that the Java, C, and python codecs have *zero depedencies*.


## BSON in Solidity
The `BsonUtils.sol` library of methods implements a to- and from-`byte[]`
codec plus the necessary set of functions to create new BSON structures.
The value of the ability to precisely work with name:value pairs of high-fidelity
value types is readily apparent in the following example:
```
    // On the Java side:
    import org.bson.*;
    Document d = new Document();
    d.setString("name", "buzz");
    d.setInteger("age", -1);
    d.setDateTime("hireDate", new Date(2022,4,4));
    d.setDecimal128("balance", new BigDecimal("107.78")); // string rep protects from floating point issues
    
    // This is the Java BsonUtils, not the BSON Solidity library here!
    byte[] p2 = BsonUtils.toBytes(d, Document.class);

    // MyContract.class is generated by web3j epirus util from abi and bin files:
    MyContract ct2 = MyContract.load(contractAddr, web3j, ...);
    TransactionReceipt r1 = ct2.setData(p2);
    ...


    // On the Solidity side:
    function setData(bytes memory bsonbytes) public {
        // Decode bytestream into useable material:
        BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);

        // The type-generic functions yield BsonValue types that are polymorphic:
        BsonUtils.BsonValue memory name = BsonUtils.getBsonMapValue(dd, "name");
        // ... and there are additional functions that extract Solidity-friedly types
        // from the BsonValue type:
        bytes memory solidity_string = BsonUtils.getBsonString(name); 

        BsonUtils.BsonValue memory hireDate = BsonUtils.getBsonMapValue(dd, "hireDate");
        (uint m, uint d, uint y) = BsonUtils.getBsonDatetimeMDY(hireDate);
	
        BsonUtils.BsonValue memory balance = BsonUtils.getBsonMapValue(dd, "balance");
        (int128 shifted_value, int8 shifts) = BsonUtils.getDecimal128(balance);
        ...
```
There is much more utility in this approach than if we implemented a JSON parser
in Solidity (which would be difficult) because the high-fidelity scalar types can
actually be used in a Solidity contract.  Similarly, it is unclear into what we would want (or could) parse JSON into.

This also means that any variety of contract state can be easily encoded
and returned in a rich way:
```
    function vendState1() view internal returns (BsonUtils.BsonDocument memory doc) {
        BsonUtils.BsonMap[] memory aa = new BsonUtils.BsonMap[](4);

        // We are hardcoding constants here but they could come from struct data
        // (which DOES exist on the Solidity side) or discrete scalar state vars.
        // In any case, there is no loss fidelity between the Solidity/client
        // when BSON is the carrier:
        aa[0] = BsonUtils.BsonMap('name', BsonUtils.createBsonString(someString));
        aa[1] = BsonUtils.BsonMap('age', BsonUtils.createBsonInt32(-1));
        aa[2] = BsonUtils.BsonMap('hireDate', BsonUtils.createBsonDateTime(2022,4,4));
        aa[3] = BsonUtils.BsonMap('balance', BsonUtils.createBsonDecimal128(10778,-2));

        BsonUtils.BsonDocument memory dd = BsonUtils.BsonDocument(aa);

        return BsonUtils.toBytes(dd);
    }

    // On the Java side:
    byte[] p3 = ct2.vendState1().send();
    Document d6 = BsonUtils.fromBytes(p3, Document.class);

    String s = d5.getString("name");

    // Remember: No datetimes in native Solidity.  Without BSON, the best you
    // can do is get a byte[] of (likely) an ISO8601 string which you have to
    // convert to a real date at your peril.  But here, we can easily and
    // safely extract a java.util.Date:
    java.util.Date hdt = d5.getDatetime("hireDate"); // typesafe datetime

    // Same applies to penny-precision types.  Interesting:
    // The java BigDecimal spec does not include -NaN which is in the 
    // decimal128 spec so we have to go through this:
    BsonDecimal128 zzx = d5.getDecimal128("balance");
    org.bson.types.Decimal128 d128 = zzx.decimal128Value();
    BigDecimal bb = d128.bigDecimalValue();

...    
```
BSON also makes it very easy to emit high fidelity structures on the
transaction log:
```
    contract MyContract {
        event ThingModified(bytes wrap); // BSON bytes!

        function changeSomething(string calldata newName) public {
            // Change field in storage struct:
            mystoragestruct.name = bytes(newName);

            // Construct a rich BSON doc :
            BsonUtils.BsonDocument memory doc = makeEmitStateDocument();

            bytes memory msg = BsonUtils.toBytes(dd);

            emit ThingModified(msg);
        }
    }
```




Although Ethereum is not the most cost effective data storage environment,
nevertheless with BSON it becomes possible for the blockchain to
store arbitrarily complex, compile-time independent high fidelity data. The
implementation is almost laughably simple:
```
    import {BsonUtils} from "./BsonUtils.sol" ;
    
    contract MyContract {
        bytes arbitrary_data; // held as BSON bytestream
    
        function setData(bytes memory bsonbytes) public {
            arbitrary_data = bsonbytes;
        }
        function getData() public view returns (bytes memory) {
            return arbitrary_data;
        }
    }
```
It could be argued that the same thing could be done for JSON string (or XML or AVRO
or CBOR [RFC 7049]) but BSON as a carrier has several major advantages:

  1.  JSON is a string, is poorly roundtrippable due to whitespace and other issues, and has limited types.
  2.  XML is a string, is poorly roundtrippable due to whitespace and other issues, and has NO types.
  3.  AVRO is a decent data carrier but also lacks decimal and datetime types.
  4.  CBOR is an extensible data carrier which opens the possibility of types encoded
on one side cannot be decoded on the other.  It also does not have nearly the
client-side driver language support of BSON.

Roundtrippability is an extra value when the data exists in the blockchain paradigm
of immutability (via hashes such as SHA3) and signatures.  Because there is no
variability of whitespace or encoding and BSON maintains a stable order of items
in key:value maps (in addition to arrays, obviously), it is "cryptofriendly" as
the bytestream is sent through a message bus, stored to disk, and along the way
rehashed to verify integrity.


## Using advanced BSON types in Solidity

### double
Solidity cannot do anything with IEEE doubles.  Our approach is to treat
them as 8 byte opaque binary data.  BSON doubles encountered in `fromBytes`
will be properly roundtripped by `toBytes`.   At some point we could
add some helper functions to pick apart the bytes and return integer and
shift components much like decimal128.


### decimal128
Besides being able to create and carry a decimal128 field in BSON, there is not
much else you can do with it inside Solidity.  Mostly you would use
getDecimal128() to get at the integer and fractional portions of the number (both
as Solidity-friendly ints) and then do comparisons.

TBD:  Some nice compare functions, e.g.
```
    BsonUtils.BsonValue v1 = BsonUtils.createBsonDecimal128(107,78,2);
    BsonUtils.BsonValue v2 = BsonUtils.createBsonDecimal128(211,78,2);    
    
    int x = BsonUtils.compareDecimal128(v1,v2);
```

```
function createBsonDecimal128(int128 val, uint128 dec, int8 ndigits) internal pure returns (BsonValue memory) 
    // (integer portion, fractional portion, positive decimal point shift)
    //     (222, 0, 0)   becomes  222
    //     (222, 0, 1)   becomes  222.0
    //     (222, 11, 2)  becomes  222.11
    //     (222, 11, 4)  becomes  222.0011
    //

// TBD...
function getDecimal128(BsonValue memory val) internal pure returns (int128, uint128 frac, int8 shift);

// Exists and probably the way you would have to use it...
function getDecimal128RawValue(BsonValue memory val) internal pure returns (int128 shiftedValue, int8 shift)

Together:
function test_decimal128() internal pure {

    // Experiment with number $107.78:
    BsonUtils.BsonValue amt = BsonUtils.createBsonDecimal128(107,78,2);

    (integerPortion, fractionPortion, shifts) = BsonUtils.getDecimal128(amt);
    // integerPortion = 107
    // fractionalPortion = 78
    // shifts = 2
    
    (unshiftedAmount, shifts) = BsonUtils.getDecimal128RawValue(amt);
    // unshiftedAmount = 10778
    // shifts = 2
}
```

### datetime
An important type.  The internal representation of datetime is milliseconds
(NOT seconds) since the epoch without timezone (e.g. Z), stored in an int64.
This is easily handled by Solidity -- but going from 5-Sep-2022 to millis is
non-trivial.  Thus, `BsonUtils.sol` offers a number of convenience functions
to create datetimes, and
of course `toBytes` will yield a BSON bytestream will an appropriately typed
datetime field for consumption by a client.
```
    function createBsonDatetime(uint16 yr, uint8 m, uint8 d, uint8 hr, uint8 min, uint8 sec, uint16 ms)

    function createBsonDatetime(uint16 yr, uint8 m, uint8 d)

    function createBsonDatetime(bytes memory strRepresentation)
    // Recognized string formats:
    // YYYYMMDD
    // YYYY-MM-DD
    // YYYY-MM-DDThh:mm:ss
    // YYYY-MM-DDThh:mm:ss.sss    
```
Independent of BSON itself, BsonUtils.sol provides two very handy date functions
for converting to and from number of milliseconds since the epoch, negative numbers
included, for the long integer (int64) representation:
```
    // For years >1582 (Gregorian calendar)
    function mdyhmsToMillis(uint16 yr, uint8 m, uint8 d, uint8 hr, uint8 min, uint8 sec, uint16 ms) internal pure returns (int64)

    // From -12219278400000 (15-Oct-1582) to 253402232400000 (9999-12-31)
    function millisToStruct(int64 millis) internal pure returns (DateTime memory)
    // DateTime is a struct defined in BsonUtils.sol:
    //   struct DateTime {
    //	   uint16  v_year;  // 1582 to 9999
    //	   uint8   v_month; // 1 to 12  (NOT 0 - 11)
    //	   uint8   v_day;   // 1 to 31
    //	   uint8   v_hour;  // 0 to 24
    //	   uint8   v_minute;  // 0 to 60
    //	   uint8   v_second;  // 0 to 60
    //	   uint16  v_ms;     // 0 to 999
    //  }
```
We return a struct because returning the 7 discrete scalars is slightly unwieldy and
also tends to provoke a "stack too deep" error from the `solc` compiler.


## Unsupported BSON types
| Type      | BSON Status | Comment |
| -- | --- | -------------- |
| ObjectID | valid |  ObjectId is a 12 byte value specific to MongoDB |
| RegEx   | valid |  Could be added later; not a lot of demand for this |
| DBPointer   | deprecated |  No supported for deprecated types |
| JavaScript   | valid |  Just a string.  Use string |
| Symbol   | deprecated |  No supported for deprecated types |
| Timestamp   | valid |  Specific to MongoDB |
| MinKey   | valid |  Specific to MongoDB |
| MaxKey   | valid |  Specific to MongoDB |


## Drawbacks and Considerations

Ethereum and Solidity were not designed for large scale data transfer and manipulation.
Almost all material on Solidity advises to minimize loops, array expansion (double hit
because of realloc AND a loop to copy data to new array), and storage of large datums --
all things that BSON Solidity will do.  It thus becomes a tradeoff of cost vs. utility
when considering BSON vs. native types especially for storage.
Initial quick tests show that capturing BSON bytestreams is only *slightly* more
expensive than an equivalent JSON structure (mostly because in smaller structures,
the type and length bits in BSON are a greater percentage of the overall bytestream
than JSON (which has none although JSON has lots of double quotes).  There is no
doubt, however, that calling `fromBytes` to hydrate a set of `BsonUtils.BsonValue`
objects is relatively expensive.

## Examples
`MyContract.sol` is included in this repo along with 4 Java client apps:

  *  bsondeploy.java.  Calls the `deploy()` method on the smart contract and
  prints the new contract address.
  *  bsonfetch.java.  Contains examples of non-state changing function calls
  to `MyContract`.
  *  bsonupdate.java.  A few examples of state changing function calls.
  *  bsonlisten.java.  An example of an event listener that will wake up and
  decode a BSON payload in an emitted event.

Building and running these examples is beyond the scope of what can be done here
due the wide variety of both web3j development environments and the set up of the
ethereum node to which the contract is deployed and engaged.  The author used
`geth` running in `--dev` mode and an improvised set of scripts plus `ant` to build
and test the Java programs.  The concepts behind each step of development and
deployment can be learned [(at this URL on moschetti.org)](https://moschetti.org/rants/geth1.html).
     
  

