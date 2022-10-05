pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

library BsonUtils {

    // Sizes in bytes:
    uint32 private constant INT32_SIZE = 4;
    uint32 private constant INT64_SIZE = 8;
    uint32 private constant DATETIME_SIZE = 8;   
    uint32 private constant DOUBLE_SIZE = 8;
    uint32 private constant DEC128_SIZE = 16;

    int64 private constant SECONDS_PER_DAY = int64(24 * 60 * 60);
    int64 private constant MILLIS_PER_DAY  = SECONDS_PER_DAY * 1000;
    int64 private constant MILLIS_PER_HOUR = int64(60 * 60 * 1000);
    int64 private constant MILLIS_PER_MIN  = int64(60 * 1000);
    int64 private constant MILLIS_PER_SEC  = int64(1000);    

    int64 private constant NANOS_PER_SECOND = int64(1000_000_000);

    // The number of days in a 400 year cycle.
    int64 private constant DAYS_PER_CYCLE = int64(146097);

    // The number of days from year zero to year 1970.
    // There are five 400 year cycles from year zero to 2000.
    // There are 7 leap years from 1970 to 2000.

    int64 private constant DAYS_0000_TO_1970 = (DAYS_PER_CYCLE * 5) - (30 * 365 + 7);	
    int64 private constant SECONDS_PER_MINUTE = int64(60);
    int64 private constant MINUTES_PER_HOUR = int64(60);
    int64 private constant NANOS_PER_MINUTE = NANOS_PER_SECOND * SECONDS_PER_MINUTE;
    int64 private constant NANOS_PER_HOUR = NANOS_PER_MINUTE * MINUTES_PER_HOUR;

	
    

    byte private constant BSON_CODE_UNSET = 0x00;

    byte private constant BSON_CODE_DOUBLE = 0x01;
    byte private constant BSON_CODE_STRING = 0x02;
    byte private constant BSON_CODE_DOCUMENT = 0x03;
    byte private constant BSON_CODE_ARRAY = 0x04;
    byte private constant BSON_CODE_BINARY = 0x05;
    byte private constant BSON_CODE_DATETIME = 0x09;
    byte private constant BSON_CODE_INT32 = 0x10;
    byte private constant BSON_CODE_INT64 = 0x12;
    byte private constant BSON_CODE_DEC128 = 0x13;

    byte private constant BSON_CODE_UNKNOWN = 0xFF;


    // subtypes
    byte private constant BSON_CODE_BINARY_GENERIC = 0x00; 


    /* BSON! */
    struct BsonValue {
        // "internal" type to this lib.  Essentially is the small
	// int version of the same code used in the BSON spec but
	// it is good to keep the two domains separate...
	// typ = 0 means unset.   Note that an empty struct e.g.
	//    BsonValue memory vv;
	// sets all members to default value which for uint8 will be zero
	// so we are good.
	uint8 typ;

	// All ints are uint256 under the covers.  Fortunately, that will
	// cover BSON 32 and 64 bit ints for numbers and date reps.
        int256 v_int;

        // string and binary varying length types go here AS WELL as 
	// decimal128 which is 16 structured bytes.  We also stick
	// the 8 bytes of IEEE double in here.
        bytes v_str;

	BsonArray v_arr;
	BsonDocument v_doc;
    }

    struct BsonMap {
	bytes name;
	BsonValue value;
    }

    struct BsonDocument {
        BsonMap[] items;
    }

    struct BsonArray {
        BsonValue[] items;
    }


    struct DateTime {
	uint16	v_year;
	uint8   v_month;
	uint8   v_day;
	uint8   v_hour;
	uint8   v_minute;
	uint8   v_second;
	uint16   v_ms;
    }


    function floorDiv(int64 a, int64 b) public pure returns (int64) {
	int64 r = a / b;
	if ((a ^ b) < 0 && (r * b != a)) r--;
	return r;
    }

    /**
     *  In solidity,  +a % +b works as expected.
     *  But when a is negative, it differs from floorMod in Java so
     *  we must mimic behavior here:
     *
     *   2 % 1000   = 2
     *   1 % 1000   = 1
     *  -1 % 1000   = 999
     *  -2 % 1000   = 998
     *  -999 % 1000   = 1
     *  -1000 % 1000   = 0
     *  -1001 % 1000   = 999
     *  -1002 % 1000   = 998
     *  -2000 % 1000   = 0
     *  -2001 % 1000   = 999
     */
    function floorMod(int64 a, int64 b) public pure returns (int64) {
	int64 r = a - floorDiv(a, b) * b;
	return r;
    }



    function isUnset(BsonMap memory mm) internal pure returns (bool) {
	return isUnset(mm.value);
    }

    function isUnset(BsonValue memory val) internal pure returns (bool) {
	if(val.typ == 0) {
	    return true;
	} else {
	    return false;
	}
    }

    
    /*
     *  T H E    B A S I C    T Y P E S
     *
     */

    /*
     *  There are no uint in BSON, only int32 and int64.
     *  If you have uint in your code, you must use the int32() function
     *  to convert them, e.g.
     *    BsonUtils.createBsonInt32(int32(loan.amount)));
     *
     *  create* functions return BsonValue, which are the equiv of a
     *  discriminated union in solidity.
     */
    function createBsonInt32(int32 val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 10;
	bv.v_int = int(val);
	return bv;
    }
    function getBsonInt32(BsonValue memory bv) internal pure returns (int32) {
	return int32(bv.v_int);
    }
	
    function createBsonInt64(int64 val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 12;
	bv.v_int = int(val);
	return bv;
    }
    function getBsonInt64(BsonValue memory bv) internal pure returns (int64) {
	return int64(bv.v_int);
    }
    
    function createBsonString(bytes memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 2;
	bv.v_str = val;
	return bv;
    }
    function getBsonString(BsonValue memory bv) internal pure returns (bytes memory) {
	return bv.v_str;
    } 
    
    // We can capture the 8 bytes of IEEE but there's really nothing we
    // can do with them here in Solidity...
    function createBsonDouble(bytes memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 1;
	bv.v_str = val;
	return bv;
    }

    function createBsonBinary(bytes memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 5;
	bv.v_str = val;
	return bv;
    }    
    //  Handy function to turn addresses into binary:
    function createBsonBinary(bytes32 val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 5;
	bv.v_str = abi.encodePacked(val);
	return bv;
    }






    //  The decimal128 Family!


    // Two modes:
    // 1.  (int portion, dec portion, positive decimal point shift)
    //     (222, 0, 0)   becomes  222
    //     (222, 0, 1)   becomes  222.0
    //     (222, 11, 2)  becomes  222.11
    //     (222, 11, 4)  becomes  222.0011
    //
    // 2.  Pre-shifted: dec portion ignored
    //     (int portion, 0, negative decimal point shift)
    //     (222,   0, -1)   becomes  22.2
    //     (22233, 0, -1)   becomes  2223.3
    //     (22233, 0, -2)   becomes  222.33

    function createBsonDecimal128(int128 val, uint128 dec, int8 ndigits) internal pure returns (BsonValue memory) {
	BsonValue memory bv = createBsonBASEDecimal128();

	// OK if ndigits >=0, bad if neg -- but we fix it up later if so!
	uint8 shiftpts = uint8(ndigits);

	// No decimal starts at 0x40 and goes BACKWARDS * 2 * ndigits
	bv.v_str[14] = 0x40;
	if(ndigits != 0) {
	    if(ndigits < 0) {
		shiftpts = uint8(ndigits * -1); // turn neg into pos THEN make uint!
	    }  
	    bv.v_str[14] = byte(uint8(64 - (2*shiftpts)));
	}

	if(val >= 0) {
	    bv.v_str[15] = 0x30; 
	} else {
	    bv.v_str[15] = 0xb0; 
	    val = val * -1; // ! Make it positive!
	}

	uint128 encval = uint128(val);

	// Now X10 for ndigits!
	if(ndigits > 0) {
	    encval = (encval * uint128(10**shiftpts)) + dec;
	}

	bytes memory bb = abi.encodePacked(encval);	
	// ONLY take first 14 bytes!
	for(uint32 n = 0; n < 14; n++) {
	    bv.v_str[n] = bb[15 - n];
	}

	return bv;
    }


    // An optimization!
    function createBsonDecimal128(bytes memory rawbuf, uint32 idx) private pure returns (BsonValue memory) {
	BsonValue memory bv = createBsonBASEDecimal128();
	copyBytes(bv.v_str, 0, rawbuf, idx, DEC128_SIZE);
	return bv;
    }

    function createBsonBASEDecimal128() private pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 13;
	bv.v_str = new bytes(DEC128_SIZE);
	return bv;
    }


    // This is the pure big integer mode:
    function createBsonDecimal128(int128 val) internal pure returns (BsonValue memory) {
	return createBsonDecimal128(val, 0, 0);
    }

    // integer part, fractional (decimal) part
    // if fractional part < 0
    //     integer part, shift left digits in integer part.
    //
    // This is a convenience function when the decimal part does not begin with
    // 0.  You can call (223,77) to get 223.77 but you cannot call (223,077) to
    // get 223.077; the 077 is interpreted as octal.
    //
    // If fractional is < 0, it is signal that mn is already in the form of 
    //    integer * (10^ndigits) + decimal
    // so (23377,-2) means 233.77
    function createBsonDecimal128(int128 mn, int128 dec) internal pure returns (BsonValue memory) {
	int8 len;

	if(dec >= 0) { // 223,56
	    int j = dec;
	    while (j != 0) {
		len++;
		j /= 10;
	    }
	} else {
	    len = int8(dec); // will be a smallish negative len
	    dec = 0;
	}

	return createBsonDecimal128(mn, uint128(dec), len);
    }


    // Quickly return the basic components:
    function getDecimal128RawValue(BsonValue memory val) internal pure returns (int128, int8 shift) {
	// The val is always positive and in shifted state:
	int128 qq = int128(LEbytesToInt(val.v_str, 0, 14));

	// Grab the shift from bsonbytes[14]
	// e.g.   3c  (60)
	// (64 - 60)/2 = n shifts
	// This is positive number.   We have to make it negative
	// because val is already shifted
	int8 shifts = int8((64 - uint8(val.v_str[14]))/2) * -1;

	// Grab the sign from bsonbytes[15]
	if(val.v_str[15] == 0xb0) {
	    qq = qq * -1;
	} 

	return (qq, shifts);
    }





    function createBsonDocument(BsonMap[] memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 3;
	bv.v_doc = BsonDocument(val);
	return bv;
    }

    /* Handy special case for single item: */
    function createBsonDocument(BsonMap memory val) internal pure returns (BsonValue memory) {
	BsonMap[] memory mm = new BsonMap[](1);
	mm[0] = val;
	return createBsonDocument(mm);
    }

    function createBsonArray(BsonValue[] memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 4;
	bv.v_arr = BsonArray(val);
	return bv;
    }



    function wrapForTransmit(BsonDocument memory doc) internal view returns (bytes memory, uint256) {
	(bytes memory complete, uint256 gasused) = wrapForTransmit(doc, 0);
	return (complete, gasused);
    }

    function wrapForTransmit(BsonDocument memory doc, uint32 version) internal view returns (bytes memory, uint256) {
	uint256 startgas = gasleft();

	bytes memory payload = BsonUtils.toBytes(doc);
	bytes32 dgst = sha256(payload);

	BsonMap[] memory aa;
	if(version > 0) {
	    aa = new BsonMap[](5);
	    aa[4] = BsonMap('version', createBsonInt32(int32(version)));
	} else {
	    aa = new BsonMap[](4);
	}
	aa[0] = BsonMap('payload', createBsonBinary(payload));
	aa[1] = BsonMap('sha256', createBsonBinary(dgst));
	aa[2] = BsonMap('blockNum', createBsonInt64(int64(block.number)));
	aa[3] = BsonMap('blockTimestamp', createBsonInt64(int64(block.timestamp)));

	BsonDocument memory wrapper = BsonDocument(aa);

	// So this will run writeBinary() *again*, which means another big
	// loop and those are expensive.
	// We should come up with a special optimization that makes a bigger buf
	//   uint32 len = BsonUtils.sizeDocument(doc);
	//   len += sizeof(SHA256) + stuff
	//   [---------------------------------------]
	//
        // then sets up the wrapper map:
	//   [payload:-------sha256:--------version:1]
	//
        // and then sets the payload and SHA byte[] "into" that buf, e.g.:
	//   [payload:BBBBBB-sha256:BBBBBB--version:1]
	bytes memory complete = BsonUtils.toBytes(wrapper);

	uint256 gasused = startgas - gasleft();

	return (complete, gasused);
    }




    function isLeap(uint16 yr) internal pure returns (bool) {
	if( yr % 4 == 0) {
	    if( yr % 100 == 0 ) {
		if( yr % 400 == 0) {
                    return true;
		} else {
                    return false;
		}
	    } else {
                return true;
	    }
	} else {
            return false;
	}
    }


    // Only for the Gregorian calendar (>1582)
    // yr   absolute >1582
    // m    1 - 12  not  1 - 11
    // d    1 - 31  not  0 - 30
    function mdyhmsToMillis(uint16 yr, uint8 m, uint8 d, uint8 hr, uint8 min, uint8 sec, uint16 ms) internal pure returns (int64) {
	uint32 totdays = 0;

	int64 totms = 0; // mdyhms are all uint -- but millis out could be negative.
	
	uint8[12] memory dpm = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

	if(isLeap(yr)) {
	    dpm[1] = 29;
	}
	
	// There are probably a few ways to optimize the maths for <1970
	// vs. >=1970 by messing with loop variables and such but we will
	// leave that for later.  For now, keep it *very clear* because
	// we don't want to waste more time with integer bitsize truncation
	// issues and whatnot....

	if(yr >= 1970) {
	    
	    for(uint16 n = 1970; n < yr; n++) { // don't include THIS year
		totdays += 365;
		if(isLeap(n)) {
		    totdays += 1;
		}
	    }


	    for(uint8 n = 0; n < (m-1); n++) {
		totdays += dpm[n];
	    }

	    totdays += (d-1);

	    // Assign ms to midnight on that date.
	    // Remember to cast constants to int64 otherwise
	    // they drag the thing down to uint32 or something....
	    //totms = int64(totdays) * int64(24 * 60 * 60 * 1000);
	    totms = int64(totdays) * MILLIS_PER_DAY;

	    // Now add ms going forward:
	    totms += (hr  * MILLIS_PER_HOUR);
	    totms += (min * MILLIS_PER_MIN);
	    totms += (sec * MILLIS_PER_SEC);
	    totms += ms;

	} else { // <1970 but before 1582

	    for(uint16 n = 1969; n > yr; n--) {
		totdays += 365;
		if(isLeap(n)) {
		    totdays += 1;
		}
	    }

	    for(uint8 n = 11; n > (m-1); n--) {
		totdays += dpm[n];
	    }

	    totdays += (dpm[m-1] - d);

	    // Assign ms to midnight on that date and make it NEGATIVE:
	    totms = int64(-1) * int64(totdays) * MILLIS_PER_DAY;

	    // Accumulate a *positive* amount of millis to continue to
	    // back up...
	    int64 accum_ms = int64((23 - int64(hr)) * MILLIS_PER_HOUR);
	    accum_ms += int64((59 - int64(min)) * MILLIS_PER_MIN);
	    accum_ms += int64((59 - int64(sec)) * MILLIS_PER_SEC);
	    accum_ms += int64(1000 - int64(ms));

	    // ... and back up by that amount:
	    totms -= accum_ms;	    	    
	}

	return totms;
    }


    /**
     *  It is too easy to produce the "Stack too deep" error when trying to
     *  move around 7 scalars (YYYY,MM,DD,HH,MM,SS,SSS) so our core function
     *  will move around a struct as recommended by the Solidity docs.
     */
    function millisToStruct(int64 millis) internal pure returns (DateTime memory) {
	int64 inSec = floorDiv(millis, 1000);
	int64 inNanos = floorMod(millis, 1000) * 1000000;

        int64 epochDay = floorDiv(inSec, SECONDS_PER_DAY);
        int64 secsOfDay = floorMod(inSec, SECONDS_PER_DAY);
	int64 zeroDay = epochDay + DAYS_0000_TO_1970;

        // find the march-based year
        zeroDay -= 60;  // adjust to 0000-03-01 so leap day is at end of four year cycle
        int64 adjust = 0;
        if (zeroDay < 0) {
            // adjust negative years to positive for calculation
            int64 adjustCycles = (zeroDay + 1) / DAYS_PER_CYCLE - 1;
            adjust = adjustCycles * 400;
            zeroDay += -adjustCycles * DAYS_PER_CYCLE;
        }
        int64 yearEst = (400 * zeroDay + 591) / DAYS_PER_CYCLE;
        int64 doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400);
        if (doyEst < 0) {
            // fix estimate
            yearEst--;
            doyEst = zeroDay - (365 * yearEst + yearEst / 4 - yearEst / 100 + yearEst / 400);
        }

	// reset any negative year:
        yearEst += adjust;   
				    
	DateTime memory dtx;  
	
        // convert march-based values back to january-based
        int64 marchMonth0 = (doyEst * 5 + 2) / 153;
        dtx.v_month = uint8((marchMonth0 + 2) % 12 + 1);
        dtx.v_day   = uint8(doyEst - (marchMonth0 * 306 + 5) / 10 + 1);
        yearEst += marchMonth0 / 10;
	dtx.v_year  = uint16(yearEst);

	int64 nanoOfDay = (secsOfDay * NANOS_PER_SECOND) + inNanos;
	dtx.v_hour = uint8(nanoOfDay / NANOS_PER_HOUR);
	nanoOfDay -= dtx.v_hour * NANOS_PER_HOUR;
	dtx.v_minute = uint8(nanoOfDay / NANOS_PER_MINUTE);
        nanoOfDay -= dtx.v_minute * NANOS_PER_MINUTE;
	dtx.v_second = uint8(nanoOfDay / NANOS_PER_SECOND);
        nanoOfDay -= dtx.v_second * NANOS_PER_SECOND;
	dtx.v_ms = uint16(nanoOfDay / 1000000);

	return dtx;
    }

    
    function createBsonDatetime(uint16 yr, uint8 m, uint8 d, uint8 hr, uint8 min, uint8 sec, uint16 ms) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 9;
	bv.v_int = int256(mdyhmsToMillis(yr, m, d, hr, min, sec, ms));
	return bv;
    }
    function createBsonDatetime(uint16 yr, uint8 m, uint8 d) internal pure returns (BsonValue memory) {
	return createBsonDatetime(yr, m, d, 0, 0, 0, 0);
    }

    function createBsonDatetime(bytes memory s) internal pure returns (BsonValue memory) {
	uint16 yr = 1970; // TBD
	uint8 m = 0;
	uint8 d = 0;
	uint8 hr = 0;
	uint8 min = 0;
	uint8 sec = 0;
	uint16 ms = 0;

	if(s.length == 8) { // YYYYMMDD
	    yr = uint16(extractInt(s, 0, 4));
	    m = uint8(extractInt(s, 4, 2));
	    d = uint8(extractInt(s, 6, 2));
	} else if(s.length == 10) { // YYYY-MM-DD
	    yr = uint16(extractInt(s, 0, 4));
	    m = uint8(extractInt(s, 5, 2));
	    d = uint8(extractInt(s, 8, 2));

	} else if(s.length == 19 || s.length == 23) { // YYYY-MM-DDThh:mm:ss  or  YYYY-MM-DDThh:mm:ss.sss
	    yr = uint16(extractInt(s, 0, 4));
	    m = uint8(extractInt(s, 5, 2));
	    d = uint8(extractInt(s, 8, 2));
	    hr = uint8(extractInt(s, 11, 2));
	    min = uint8(extractInt(s, 14, 2));
	    sec = uint8(extractInt(s, 17, 2));
	    if(s.length == 23) {
		ms = uint16(extractInt(s, 20, 3));
	    }
	}

	return createBsonDatetime(yr, m, d, hr, min, sec, ms);
    }

    // val is milliseconds (NOT seconds) since epoch
    function createBsonDatetime(int64 val) internal pure returns (BsonValue memory) {
	BsonValue memory bv;
	bv.typ = 9;
	bv.v_int = int(val);
	return bv;
    }

    // Hides implementation....
    function getBsonDatetime(BsonValue memory bv) internal pure returns (int64) {
	return int64(bv.v_int);
    }

    // A convenience since MDY is much more handy to work with...
    function getBsonDatetimeMDY(BsonValue memory bv) internal pure returns (uint yr, uint mon, uint day) {
	BsonUtils.DateTime memory dtx = BsonUtils.millisToStruct(int64(bv.v_int));
	return (dtx.v_year, dtx.v_month, dtx.v_day);
    }
    function getBsonDatetimeMDYHMS(BsonValue memory bv) internal pure returns (uint yr, uint mon, uint day, uint hour, uint min, uint sec, uint millis) {
	BsonUtils.DateTime memory dtx = BsonUtils.millisToStruct(int64(bv.v_int));
	return (dtx.v_year, dtx.v_month, dtx.v_day, dtx.v_hour, dtx.v_minute, dtx.v_second, dtx.v_ms);
    }
    


    /**
     *  If fldname is found in the doc, then the
     *  BsonValue.typ will be NOT 0.  You cannot check for null in solidity
     *  but a newly hatched BsonValue will have a typ of 0.
     * 
     */
    function getBsonMapValue(BsonDocument memory dd, bytes memory fldname) internal pure returns (BsonValue memory) {
	BsonValue memory vv;
	for(uint32 i = 0; i < dd.items.length; i++) {
	    if(true == compareStrings(dd.items[i].name, fldname)) {
		vv = dd.items[i].value;
		break;
	    }
	} 
	return vv;
    }

    function appendBsonMap(BsonDocument memory dd, BsonMap memory newItem) internal pure returns (uint32 newLen) {
	uint32 dlen = uint32(dd.items.length);

	BsonMap[] memory newArr = new BsonUtils.BsonMap[](dlen + 1); // +1 !!!
	uint32 i;
	for(i = 0; i < dlen; i++) {
	    newArr[i] = dd.items[i];
	}
	newArr[i] = newItem; // thanks to i++, i is already at proper place

	dd.items = newArr; // ah HA!  Substitute in place!

	return dlen + 1;
    }


    function appendBsonValue(BsonArray memory aa, BsonValue memory newItem) internal pure returns (uint32 newLen) {
	uint32 dlen = uint32(aa.items.length);

	BsonValue[] memory newArr = new BsonValue[](dlen + 1); // +1 !!!
	uint32 i;
	for(i = 0; i < dlen; i++) {
	    newArr[i] = aa.items[i];
	}
	newArr[i] = newItem; // thanks to i++, i is already at proper place
	
	aa.items = newArr; // ah HA!  Substitute in place!

	return dlen + 1;
    }


    function appendBsonValue(BsonArray memory aa, BsonMap memory newItem) internal pure returns (uint32 newLen) {
	BsonValue memory val = createBsonDocument(newItem);
	return appendBsonValue(aa, val);
    }



    function sizeDocument(BsonDocument memory doc) internal pure returns (uint32) {
	bytes memory dummy = new bytes(0);

	uint32 n = processDocument(false, dummy, 0, doc, "");
	n += (INT32_SIZE + 1);  // 4 bytes for total length + 1 trailing null

	return n;
    }


    function toBytes(BsonDocument memory doc) internal pure returns (bytes memory) {
	uint32 n = sizeDocument(doc);

	bytes memory realbuf = new bytes(n);
	
	writeUInt32(realbuf, 0, n);
	// Start at IDX 4 to jump over the initial length:
	processDocument(true, realbuf, 4, doc, "");

	return realbuf;
    }


    function fromBytes(bytes memory bsonbytes) internal pure returns (BsonDocument memory) {
	uint32 idx = 4;  // jump over length header; we won't need it
	BsonMap[] memory mm = unprocessDoc(bsonbytes, idx);
	return BsonDocument(mm);
    }







    //
    //  P R I V A T E    F U N C T I O N S
    //
    //
    function unprocessDoc(bytes memory bsonbytes, uint32 idx) private pure returns (BsonMap[] memory) {
	BsonMap[] memory dummy; // len 0
	uint32 num = unprocessOpDoc(bsonbytes, idx, dummy);

	BsonMap[] memory mm = new BsonUtils.BsonMap[](num);
	num = unprocessOpDoc(bsonbytes, idx, mm);

	return mm;
    }

    function unprocessArray(bytes memory bsonbytes, uint32 idx) private pure returns (BsonValue[] memory) {
	BsonValue[] memory dummy; // len 0
	uint32 num = unprocessOpArray(bsonbytes, idx, dummy);

	BsonValue[] memory vv = new BsonUtils.BsonValue[](num);
	num = unprocessOpArray(bsonbytes, idx, vv);

	return vv;
    }



    // Little endian buf to int:
    // 0x07 0x00 0x00 0x00  is 7, not 117440512

    function LEbytesToInt(bytes memory buf, uint32 idx, uint32 n) private pure returns (int) {
        int number;
        for(uint32 i=0; i < n; i++){
	    // expo function REQUIRES unsigned int
	    number = number + int(uint8(buf[idx+i]) * (2**(8*i)) );
        }
        return number;
    }

    function LEbytesToInt32(bytes memory buf, uint32 idx) private pure returns (int32) {
	return int32(LEbytesToInt(buf, idx, 4));
    }
    function LEbytesToInt64(bytes memory buf, uint32 idx) private pure returns (int64) {
	return int64(LEbytesToInt(buf, idx, 8));
    }


    function extractString(bytes memory buf, uint32 idx) private pure returns (bytes memory) {
	uint32 n;
	for(n = 0; buf[idx+n] != 0; n++) {
	}
	bytes memory ns = new bytes(n);
	for(uint32 i = 0; i < n; i++) {
	    ns[i] = buf[idx + i];
	}
	return ns;
    }

    function copyBytes(bytes memory target, uint32 target_idx, bytes memory source, uint32 source_idx, uint32 n) private pure {
	for(uint32 i = 0; i < n; i++) {
	    target[target_idx + i] = source[source_idx + i];
	}
    }


    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
	bytes memory tempEmptyStringTest = bytes(source);
	if (tempEmptyStringTest.length == 0) {
	    return 0x0;
	}
	assembly {
        result := mload(add(source, 32))
		}
    }


    // Small helper function to help construct 
	   function concat(string memory a, string memory b, string memory c)
	   private pure returns (string memory) {
	return string(abi.encodePacked(a, b, c));
    }

    function unprocessOpCommon(bytes memory bsonbytes, uint32 idx) private pure returns (uint32, bytes memory, BsonValue memory) {
	byte op = bsonbytes[idx];
	    
	idx += 1; // ADVANCE BEYOND OPCODE
	
	bytes memory fldname = extractString(bsonbytes, idx);
	idx += (uint32(fldname.length) + 1);
	    
	BsonValue memory val;

	if(BSON_CODE_INT32 == op) {
	    int32 qq = LEbytesToInt32(bsonbytes, idx);
	    val = createBsonInt32(qq);
	    idx = idx + 4;
	    
	} else if(BSON_CODE_STRING == op) {
	    int32 slen = LEbytesToInt32(bsonbytes, idx);
	    idx += 4;
	    val = createBsonString(extractString(bsonbytes, idx));
	    idx = idx + uint32(slen);
	    
	} else if(BSON_CODE_DOCUMENT == op) {
	    int32 ll = LEbytesToInt32(bsonbytes, idx);
	    idx += 4;
	    val = createBsonDocument(unprocessDoc(bsonbytes, idx));
	    idx = idx + (uint32(ll) - 4);

	} else if(BSON_CODE_ARRAY == op) {
	    int32 ll = LEbytesToInt32(bsonbytes, idx);
	    idx += 4;
	    val = createBsonArray(unprocessArray(bsonbytes, idx));
	    idx = idx + (uint32(ll) - 4);
	    
	} else if(BSON_CODE_INT64 == op) {
	    int64 qq = LEbytesToInt64(bsonbytes, idx);
	    val = createBsonInt64(qq);
	    idx = idx + INT64_SIZE;

	} else if(BSON_CODE_DATETIME == op) {
	    int64 qq = LEbytesToInt64(bsonbytes, idx);
	    val = createBsonDatetime(qq);
	    idx = idx + 8;

	} else if(BSON_CODE_BINARY == op) {
	    uint32 blen = uint32(LEbytesToInt32(bsonbytes, idx));
            idx = idx + 4 + 1; // Jump over len AND the 1 subtype code!
	    bytes memory frag = new bytes(blen);
	    copyBytes(frag, 0, bsonbytes, idx, blen);
	    val = createBsonBinary(frag);
	    idx = idx + blen;

	} else if(BSON_CODE_DOUBLE == op) {
	    // Treat like opaque binary data!
	    bytes memory frag = new bytes(DOUBLE_SIZE);
	    copyBytes(frag, 0, bsonbytes, idx, DOUBLE_SIZE);
	    val = createBsonDouble(frag);
	    idx = idx + DOUBLE_SIZE;	    


	} else if(BSON_CODE_DEC128 == op) {
	    // Optimization!  Copy bytes right into the val...
	    val = createBsonDecimal128(bsonbytes, idx);
	    idx = idx + DEC128_SIZE;
	} 

	return(idx, fldname, val);
    }

    /*
      bytes memory frag = new bytes(16);
      // Only take 14!
      copyBytes(frag, 0, bsonbytes, idx, 14); 
      // frag is now 16 with two extra null bytes:
      // b b b b b b b b b b b b b b 00 00

      // The val is always positive and in shifted state:
      int128 qq = LEbytesToInt128(frag, 0);

      // Grab the shift from bsonbytes[idx + 14]
      // e.g.   3c  (60)
      // (64 - 60)/2 = n shifts
      // This is positive number.   We have to make it negative
      // because val is already shifted
      int8 shifts = int8((64 - uint8(bsonbytes[idx + 14]))/2) * -1;

      // Grab the sign from bsonbytes[idx + 15]
      if(bsonbytes[idx + 15] == 0xb0) {
      qq = qq * -1;
      } // ignore 0x30 (positive) and the NaN/Inf stuff for the moment.
    */

    function unprocessOpDoc(bytes memory bsonbytes, uint32 idx, BsonMap[] memory maps) private pure returns (uint32) {
	uint32 n = 0;

	while(bsonbytes[idx] != 0x00) {
	    bytes memory fldname;
	    BsonValue memory val;
	    (idx, fldname, val) = unprocessOpCommon(bsonbytes, idx);
	    if(maps.length > 0) {
		maps[n] = BsonMap(fldname, val);
	    }
	    n = n + 1;
	}

	return n;
    }


    function unprocessOpArray(bytes memory bsonbytes, uint32 idx, BsonValue[] memory vals) private pure returns (uint32) {
	uint32 n = 0;

	while(bsonbytes[idx] != 0x00) {
	    bytes memory fldname;
	    BsonValue memory val;
	    (idx, fldname, val) = unprocessOpCommon(bsonbytes, idx);
	    if(vals.length > 0) {
		vals[n] = val;
	    }
	    n = n + 1;
	}

	return n;
    }



    function uintToString(uint _i) public pure returns (bytes memory) {
        uint number = _i;
        if (number == 0) { return "0"; }
        if (number == 1) { return "1"; }

        uint j = number;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (number != 0) {
            bstr[k--] = byte(uint8(48 + number % 10));
            number /= 10;
        }
        return bstr;
    }


    function writeString(bytes memory buf, uint32 idx, bytes memory x) private pure returns (uint32) {
        uint32 len = uint32(x.length); // ah HA!

        for(uint32 i = 0; i < len; i++) {
            buf[idx] = x[i];
            idx++;
        }
        buf[idx] = 0x00;  // write that null!                                                          
				 return len + 1;
    }


    function writeBinary(bytes memory buf, uint32 idx, bytes memory x) private pure returns (uint32) {
        uint32 len = uint32(x.length);

        for(uint32 i = 0; i < len; i++) {
            buf[idx] = x[i];
            idx++;
        }
        return len;
    }


    // Pluck out len bytes at buf[idx] and turn into a number.
    // The next biggest is millis (3).   Everything else is 2 digits max.
    function extractInt(bytes memory s, uint8 idx, uint8 len) private pure returns (uint32) {
	uint32 item = 0;

        for(uint8 k = 0; k < len; k++) {
            uint8 nx = idx + (len-1) - k;
	    uint8 c = uint8(s[nx]); // Ah!  turn a byte into 8bit *number*
	    item = item + (uint8(c - 48) * uint32(10**k));
        }

	return item;
    }


    function littleEndianWriter(bytes memory buf, uint32 idx, bytes memory qq, uint32 len) private pure  {
	for(uint32 n = 1; n <= len; n++) {
	    buf[idx++] = qq[len - n];
	}
    }

    function writeUInt32(bytes memory buf, uint32 idx, uint32 x) private pure returns (uint32) {
	bytes memory qq = abi.encodePacked(x);
	littleEndianWriter(buf, idx, qq, INT32_SIZE);
	return INT32_SIZE;
    }
    function writeInt32(bytes memory buf, uint32 idx, int32 x) private pure returns (uint32) {
	bytes memory qq = abi.encodePacked(x);
	littleEndianWriter(buf, idx, qq, INT32_SIZE);
	return INT32_SIZE;
    }
    function writeInt64(bytes memory buf, uint32 idx, int64 x) private pure returns (uint32) {
	bytes memory qq = abi.encodePacked(x);
	littleEndianWriter(buf, idx, qq, INT64_SIZE);
	return INT64_SIZE;
    }


    function processString(bool doWrite, bytes memory buf, uint32 idx, bytes memory s, bytes memory name) pure private returns (uint32) {
        uint32 len = uint32(s.length);
        uint32 nlen = uint32(name.length);

	//          code   name+null         intlen   sizeofstring+plus null
	uint32 totlen = 1 +   nlen+1   +   INT32_SIZE   +   len+1 ;

        if(doWrite) {
            buf[idx++] = BSON_CODE_STRING;
            idx += writeString(buf, idx, name);
            idx += writeUInt32(buf, idx, len + 1); // +1 for NULL!
            idx += writeString(buf, idx, s);
        }
        return totlen;
    }


    function processBinary(bool doWrite, bytes memory buf, uint32 idx, bytes memory s, bytes memory name) pure private returns (uint32) {
        uint32 len = uint32(s.length);
        uint32 nlen = uint32(name.length);

	//          code   name+null        intlen   subtype  sizeofbinary
	uint32 totlen = 1 +   nlen+1   +  INT32_SIZE   + 1 +     len ;

        if(doWrite) {
            buf[idx++] = BSON_CODE_BINARY;
            idx += writeString(buf, idx, name);
            idx += writeUInt32(buf, idx, len);
            buf[idx++] = BSON_CODE_BINARY_GENERIC;
            idx += writeBinary(buf, idx, s);
        }
        return totlen;
    }


    function processDouble(bool doWrite, bytes memory buf, uint32 idx, bytes memory s, bytes memory name) pure private returns (uint32) {
        uint32 nlen = uint32(name.length);

        if(doWrite) {
            buf[idx++] = BSON_CODE_DOUBLE;
            idx += writeString(buf, idx, name);
            idx += writeBinary(buf, idx, s);
        }
        return 1 + (nlen+1) + DOUBLE_SIZE;
    }    


    function processDecimal128(bool doWrite, bytes memory buf, uint32 idx, bytes memory s, bytes memory name) pure private returns (uint32) {
        uint32 nlen = uint32(name.length);

	//          code   name+null        dec128len   
			uint32 totlen = 1 +   nlen+1   +  DEC128_SIZE;

        if(doWrite) {
            buf[idx++] = BSON_CODE_DEC128;
            idx += writeString(buf, idx, name);
            idx += writeBinary(buf, idx, s);
        }
        return totlen;
    }

    function processInt32(bool doWrite, bytes memory buf, uint32 idx, int32 x, bytes memory name) pure private returns (uint32) {
        uint32 nlen = uint32(name.length);

        if(doWrite) {
            buf[idx++] = BSON_CODE_INT32;
	    idx += writeString(buf, idx, name);
            writeInt32(buf, idx, x);
        }
        return 1 + (nlen+1) + INT32_SIZE; // code + namelen+null  +  int32-size
    }

    function processInt64(bool doWrite, bytes memory buf, uint32 idx, int64 x, byte code, bytes memory name) pure private returns (uint32) {
        uint32 nlen = uint32(name.length);

        if(doWrite) {
            buf[idx++] = code;
	    idx += writeString(buf, idx, name);
            writeInt64(buf, idx, x);
        }
        return 1 + (nlen+1) + INT64_SIZE;  // code + namelen+null  +  int64-size
    }



    function processSomething(bool doWrite, bytes memory buf, uint32 idx, BsonValue memory value, bytes memory name) pure private returns (uint32) {
        uint32 nbytes = 0;
        if(value.typ == 10) {
            nbytes += processInt32(doWrite, buf, idx, int32(value.v_int), name);
        } else if(value.typ == 9) { // UTC datetime
            nbytes += processInt64(doWrite, buf, idx, int64(value.v_int), BSON_CODE_DATETIME, name);
        } else if(value.typ == 12) { // long int
            nbytes += processInt64(doWrite, buf, idx, int64(value.v_int), BSON_CODE_INT64, name);
        } else if(value.typ == 2) {
            nbytes += processString(doWrite, buf, idx, value.v_str, name);

        } else if(value.typ == 5) {
            nbytes += processBinary(doWrite, buf, idx, value.v_str, name);

        } else if(value.typ == 1) {
            nbytes += processDouble(doWrite, buf, idx, value.v_str, name);

        } else if(value.typ == 3 || value.typ == 4) {
	    // We cannot be "dynamically polymorphic" or use generics because
	    // solidity doesn't have them.  Oh well.
            nbytes += processDocOrArray(doWrite, buf, idx, value, name);

        } else if(value.typ == 13) {
            nbytes += processDecimal128(doWrite, buf, idx, value.v_str, name);
        }
        return nbytes;
    }


    function processDocument(bool doWrite, bytes memory buf, uint32 idx, BsonDocument  memory doc, bytes memory name) pure private returns (uint32) {
	BsonValue memory vv;
	vv.typ = 3;
	vv.v_doc = doc;
	return processDocOrArray(doWrite, buf, idx, vv, name);
    }

    function processDocOrArray(bool doWrite, bytes memory buf, uint32 idx, BsonValue  memory val, bytes memory name) pure private returns (uint32) {
        uint32 nbytes = 0;

	byte code;
	if(val.typ == 3) {
	    code = BSON_CODE_DOCUMENT;
	} else {
	    code = BSON_CODE_ARRAY;
	}

        // This is the special top level case!      
        // We do not write code 0x3 and the name at the top level!   
        if(name.length != 0) {
            //     code    name        null   intsize of components   the
            //     trailing NULL!             
            nbytes = 1 // code
		+ uint32(name.length)  // without the null
                + 1  // 1 more for the null
		+ INT32_SIZE  // 4 bytes to hold int size
		+ 1  // 1 byte for trailing NULL (see bsonspec!)
		;

            if(doWrite) {
                uint32 n;
		buf[idx++] = code; 
                n = writeString(buf, idx, name);
                idx += n;
                // cannot write size yet -- we don't know it.
            }
        }

        // doc size INCLUDES "size of the size int" plus the trailing null!
        uint32 docComponentsSizeOnly = (INT32_SIZE + 1);
        uint32 priorPos = idx;

        if(doWrite && name.length != 0) {
            idx += INT32_SIZE; // BUMP!
	}
	
	// Set up the vars:
	uint32 mlen;
	if(code == BSON_CODE_DOCUMENT) {
	    mlen = uint32(val.v_doc.items.length);
	} else {
	    mlen = uint32(val.v_arr.items.length);
	}

        for(uint32 i = 0; i < mlen; i++) {
            bytes memory subname;
            BsonValue memory v;

	    if(code == BSON_CODE_DOCUMENT) {
		BsonMap memory m = val.v_doc.items[i];
		subname = m.name;
		v = m.value;
	    } else {
		subname = uintToString(i);
		v = val.v_arr.items[i];
	    }

            uint32 n = processSomething(doWrite, buf, idx, v, subname);
            idx += n;
            nbytes += n;
            docComponentsSizeOnly += n;
        }

        if(doWrite && name.length != 0) {
            writeUInt32(buf, priorPos, docComponentsSizeOnly);
            // Write the trailing NULL!  This is a doc!
            buf[idx++] = 0x00;
        }

	return nbytes;
    }



    //
    //  U T I L S
    //
    //  Could live in another lib, frankly.
    //
    function compareStrings(bytes memory a, bytes memory b) private pure returns (bool) {
	return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

}

/*

The Closet.

//     * Another solidity gem.  You must initialize ALL members of struct upon
//     * construction because there is no null.

    function XXcreateBsonBASE() private pure returns (BsonValue memory) {
	//BsonArray memory empty_arr = BsonArray(new BsonValue[](0));
	//BsonDocument memory empty_doc = BsonDocument(new BsonMap[](0));

	BsonArray memory empty_arr ;
	BsonDocument memory empty_doc ;
	return BsonValue({typ:0, v_int:0, 
		    v_str:'', v_arr:empty_arr, v_doc:empty_doc});

	BsonValue memory bv;
	return bv;
    }

    function OLDcreateBsonArray(BsonValue[] memory val) internal pure returns (BsonValue memory) {
	BsonValue memory bv = createBsonBASE();
	bv.v_arr = BsonArray(val);
	return bv;


	// BSON arrays are at the encoding level are docs with
	// with integer indexes.
	BsonMap[] memory cvtmaps = new BsonMap[](val.length);
	for(uint32 i = 0; i < val.length; i++) {
	    cvtmaps[i] = BsonMap(uintToString(i), val[i]);
	}
	//return createInternalBsonDocument(cvtmaps, 4);
    }


 */
