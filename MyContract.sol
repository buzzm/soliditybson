pragma solidity ^0.7.0;

// Apparently wherever MyControl.col is found from solc, if you say 
//     import "./file.sol"
// then file.sol will be found...
import {BsonUtils} from "./BsonUtils.sol" ;


// SPDX-License-Identifier: MIT

contract mortal {
    /* Define variable owner of the type address*/
    address payable owner;

    /* this function is executed at initialization and sets the owner of the contract */
    constructor() { owner = msg.sender; }

    /* Function to recover the funds on the contract */
    function kill() public { if (msg.sender == owner) selfdestruct(owner); }
}

contract MyContract is mortal {

    // Some contract-specific data.
    struct Loan {
	bytes cparty;
        uint32 amount;
    }

    Loan loan;  // "autoconstructed"

    bytes state1; // held as BSON bytestream
    
    BsonUtils.BsonValue penny_precise_value;
	
    
    constructor(bytes memory cparty, uint32 amount) {
	loan.cparty = cparty;
	loan.amount = amount;
    }

    uint32 qqq;

    event Modified(bytes wrap);


    /*
     * This is The Official Creator of Externalized State for state "FOO".
     * FOO is whatever is important and
     * appropriate to represent in externalized form to a set of parties.
     * You can have any number of externalized states; you just need to have
     * an agreement on what they mean from an info arch standpoint.
     *
     * The ORDER OF ASSEMBLY of the BSON objects here determines the official
     * ordering of elements in the BSON.  This is vital for hashing!
     * The ultimate BSON decoder (e.g. Java:  Document BsonUtils.fromBytes(b) )
     * creates maps and things and cannot provide reliable roundtripping.
     *
     * Note that it is of type "view"; clearly, to represent state, we must view
     * the contract state.  But it is also internal!  This allows us to sling
     * around our custom structs and functions.  Also note that everything is
     * memory scoped here.
     * Remember, solidity does not permit dynamic mappings and we probably
     * would not want them anyway because we need to VERY clearly control the
     * order of assembly.  There's also no push() and append() and things like
     * that so you have to "preallocate" the BsonMap and BsonValue arrays.
     * Alternatively, you can use appendBsonMap() to extend a document and 
     * appendBsonValue() to extend an array but these are semi-expensive 
     * functions.
     *
     * Watch out for int vs. uint.  solidity loves uints; most languages do not
     * and BSON is only int32 and int64.  If you have uints, you must convert
     * on the fly to int; see loan.amount below.
     */
    function makeStateFOODocument(uint32 numPeeps) view internal returns (BsonUtils.BsonDocument memory doc) {
	BsonUtils.BsonMap[] memory aa = new BsonUtils.BsonMap[](19);

	aa[0] = BsonUtils.BsonMap('cparty', BsonUtils.createBsonString(loan.cparty));
	aa[1] = BsonUtils.BsonMap('amt', BsonUtils.createBsonInt32(int32(loan.amount)));

	BsonUtils.BsonValue[] memory faves = new BsonUtils.BsonValue[](5);
	faves[0] = BsonUtils.createBsonInt32(3);
	faves[1] = BsonUtils.createBsonString("FOO");
	faves[2] = BsonUtils.createBsonInt64(-323423424343211); // negative!
	faves[3] = BsonUtils.createBsonInt32(888);
	aa[2] = BsonUtils.BsonMap('faves', BsonUtils.createBsonArray(faves));

	/*
	 *  This makes the following shape:
	 *  peeps: [
	 *    {name: {first: "Buzz", last: "Moschett"}, num: 0},
	 *    {name: {first: "Buzz", last: "Moschett"}, num: 1},
	 *    ....
	 */
	BsonUtils.BsonValue[] memory peeps = new BsonUtils.BsonValue[](numPeeps);
	for(uint8 j = 0; j < numPeeps; j++) {
	    BsonUtils.BsonMap[] memory peep = new BsonUtils.BsonMap[](2);

	    BsonUtils.BsonMap[] memory name = new BsonUtils.BsonMap[](2);
	    name[0] = BsonUtils.BsonMap('first', BsonUtils.createBsonString('Buzz'));
	    name[1] = BsonUtils.BsonMap('last', BsonUtils.createBsonString('Moschetti'));
	    peep[0] = BsonUtils.BsonMap('name', BsonUtils.createBsonDocument(name));

	    peep[1] = BsonUtils.BsonMap('num', BsonUtils.createBsonInt32(j * 5)); // fun

	    peeps[j] = BsonUtils.createBsonDocument(peep);
	}
	aa[3] = BsonUtils.BsonMap('peeps', BsonUtils.createBsonArray(peeps));

	
	bytes memory binData = new bytes(3);
	binData[0] = 0x04;
	binData[1] = 0x07;
	binData[2] = 0x65;
	// Set aa[6] "ahead" of aa[4,5] below!  You can -- because the memory
	// is preallocated!
	aa[6] = BsonUtils.BsonMap('binData', BsonUtils.createBsonBinary(binData));

	BsonUtils.BsonDocument memory dd = BsonUtils.BsonDocument(aa);


	// You can even set more maps and things AFTER the main document is
	// created above -- because the memory is preallocated!
	// Looks a little weird though...

	// Since solidity has no date time, we provide some options.
	// You can of course set your native implementation e.g. 
	//    solidity                          Call
	//    uint64  timestampInMS;            createBsonInt64
	//    string  timestamp2asYYYYMMDD;     createBsonString
	//
	// But we offer a real BSON datetime which can be constructed
	// from an int64, (y,m,d), (y,m,d,hr,min,sec,ms), or a string.
	// YYYYMMDD, YYYY-MM-DD, and ISO8601 w/opt. millis are recognized.
	// This allows the consumer to do something intelligent with the
	// date without having to convert it -- especially if it was in
	// string form.  "myDate":"20220825" in BSON is not very useful.

	int64 theDate = 1661443994000; // 2022-08-25T16:13:14Z in millis
	aa[4] = BsonUtils.BsonMap('hireDate', BsonUtils.createBsonDatetime(theDate));
	aa[5] = BsonUtils.BsonMap('otherDate', BsonUtils.createBsonDatetime(2022,8,25));
	// jump over 6....
	aa[7] = BsonUtils.BsonMap('d3', BsonUtils.createBsonDatetime("20220825"));
	aa[8] = BsonUtils.BsonMap('d4', BsonUtils.createBsonDatetime("2022-08-25T13:14:15"));
	aa[9] = BsonUtils.BsonMap('d5', BsonUtils.createBsonDatetime("2022-08-25T13:14:15.777"));

	aa[10] = BsonUtils.BsonMap('dec1', BsonUtils.createBsonDecimal128(-131377));

	aa[11] = BsonUtils.BsonMap('dec3', BsonUtils.createBsonDecimal128(9221,0,0));
	aa[12] = BsonUtils.BsonMap('dec4', BsonUtils.createBsonDecimal128(9221,0,4));
	aa[13] = BsonUtils.BsonMap('dec5', BsonUtils.createBsonDecimal128(9221,17,4));

	aa[14] = BsonUtils.BsonMap('dec6', BsonUtils.createBsonDecimal128(131377,123));

	// This is very likely how you will use decimal128 in solidity.  The
	// shifted value (as a pure int) will be manipulated by logic and the shift
	// count "known" to the logic.   For example, in dollars and cents, the
	// value in solidity would be in cents (e.g. uint) or maybe int if
	// negative is OK.  WHen expressing state as decimal128, the logic
	// "knows" to left shift by -2.
	aa[15] = BsonUtils.BsonMap('dec7', BsonUtils.createBsonDecimal128(922177,-2));
	aa[16] = BsonUtils.BsonMap('dec8', BsonUtils.createBsonDecimal128(9221770,-1));
	aa[17] = BsonUtils.BsonMap('dec9', BsonUtils.createBsonDecimal128(9221770,-2));
	aa[18] = BsonUtils.BsonMap('deca', BsonUtils.createBsonDecimal128(-8722177,-2));

	// aa[11] = BsonUtils.BsonMap('dec2', BsonUtils.createBsonDecimal128(77777,-2));
	
	return dd;
    }


    function makeStateSMALLDocument(int val) public pure returns (bytes memory) {
	BsonUtils.BsonMap[] memory aa = new BsonUtils.BsonMap[](1);

	aa[0] = BsonUtils.BsonMap('dec1', BsonUtils.createBsonDecimal128(int128(val)));

	BsonUtils.BsonDocument memory dd = BsonUtils.BsonDocument(aa);

	bytes memory payload;

	payload = BsonUtils.toBytes(dd);

	return payload;
    }


    // start-end   10 
    // bstr       13
    // bstr and big false      25
    // actual conv of 7       459
    // actual conv of 9       459
    // actual conv of 10      684   +225
    // actual conv of 99      684
    // actual conv of 100     909   +225
    function XX2(uint _i) public view returns (bytes memory, uint) {
	uint startgas = gasleft();

        bytes memory bstr;

        uint number = _i;

        uint j = number;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        //bytes memory bstr = new bytes(len);
        bstr = new bytes(len);
        uint k = len - 1;
        while (number != 0) {
            bstr[k--] = byte(uint8(48 + number % 10));
            number /= 10;
	}

	uint gasused = startgas - gasleft();

	return (bstr, gasused);
    }


    /*
     * At last!  The way we actually ASK for this state info from an 
     * external caller!
     *
     * This function is clearly public but fortunately is also just a view
     * because nothing it calls changes state; this saves on gas.
     */
    function getStateOneBSON() public view returns (bytes memory,  uint256) {
	//  Call The Official Function of externalized state for state FOO:
	BsonUtils.BsonDocument memory doc = makeStateFOODocument(4);
	// version = 2 for fun
	(bytes memory complete, uint256 gasused) = BsonUtils.wrapForTransmit(doc, 2);
	return 	(complete, gasused);
    }



    function getStateVAR(uint32 numPeeps, bool doWrap) public view returns (bytes memory, uint256) {
	//  Call The Official Function of externalized state for state FOO:
	BsonUtils.BsonDocument memory doc = makeStateFOODocument(numPeeps);

	if(true == doWrap) {
	    // version = 2 for fun
	    (bytes memory complete, uint256 gasused) = BsonUtils.wrapForTransmit(doc, 2);
	    return 	(complete, gasused);

	} else {
	    uint256 startgas = gasleft();
	    bytes memory complete = BsonUtils.toBytes(doc);
	    uint256 gasused = startgas - gasleft();

	    return 	(complete, gasused);
	}
    }



    // Things that generate state change cannot return data.  They only return
    // a TransactionReceipt object.  Only view or pure functions will be
    // wrapped with nice type specific return values.
    //
    // If notify = false, NO wrapping or event emission!
    //
    function changeCounterparty(string calldata newCpty, bool notify) public {
	loan.cparty = bytes(newCpty);

	if(notify == true) {
	    BsonUtils.BsonDocument memory doc = makeStateFOODocument(4);

	    // var,   means drop second return to avoid unused warning
	    (bytes memory wrap, ) = BsonUtils.wrapForTransmit(doc, 2);

	    emit Modified(wrap);
	}
    }


    /*
     *  This is here just to show how two variables can be returned.
     */
    function getInfo() public view returns (bytes memory, uint amount) {
        return (loan.cparty, loan.amount);
    }


    function fun1(bytes memory bsonbytes) public pure returns (bytes memory) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);

	BsonUtils.BsonValue memory v2 = BsonUtils.getBsonMapValue(dd, "age");
	if(false == BsonUtils.isUnset(v2)) {

	    // Make a NEW map from this one:
	    BsonUtils.BsonMap memory q4 = BsonUtils.BsonMap("foo", v2);

	    // Add it to the main document struct:
	    BsonUtils.appendBsonMap(dd, q4);

	    // ... and add it to the array; a little cheeky and dangerous...
	    BsonUtils.BsonValue memory v3 = BsonUtils.getBsonMapValue(dd, "someThings");
	    // As a convenience, we permit adding a single BsonMap
	    // instead of BsonDocument which is array:
	    BsonUtils.appendBsonValue(v3.v_arr, q4);


	} else {
	    BsonUtils.appendBsonMap(dd, BsonUtils.BsonMap("foo", BsonUtils.createBsonString("UNSERT")));
	}

	bytes memory buf = BsonUtils.toBytes(dd);
	return buf;
    }


    function roundTrip(bytes memory bsonbytes) public pure returns (bytes memory) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	bytes memory buf = BsonUtils.toBytes(dd);
	return buf;
    }
    function oneWay(bytes memory bsonbytes) public pure returns (uint tlen) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	return dd.items.length;
    }



    function setState(bytes memory bsonbytes, bool doDecode) public {
	state1 = bsonbytes;
	if(doDecode == true) {
	    BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	}
    }
    function getState() public view returns (bytes memory) {
	return state1;
    }


    function decomposeMillisDate(bytes memory bsonbytes) public pure returns (uint16 yr, uint8 m, uint8 d, uint8 hr, uint8 min, uint8 sec, uint16 ms) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	BsonUtils.BsonValue memory val = BsonUtils.getBsonMapValue(dd, "td");

	BsonUtils.DateTime memory dtx = BsonUtils.millisToStruct(BsonUtils.getBsonDatetime(val));

	return (dtx.v_year,dtx.v_month,dtx.v_day,dtx.v_hour,dtx.v_minute,dtx.v_second,dtx.v_ms);
    }

    function testDate(bytes memory bsonbytes) public pure returns (int64) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	BsonUtils.BsonValue memory val = BsonUtils.getBsonMapValue(dd, "td");

	BsonUtils.DateTime memory dtx = BsonUtils.millisToStruct(BsonUtils.getBsonDatetime(val));
	return BsonUtils.mdyhmsToMillis(dtx.v_year, dtx.v_month, dtx.v_day, dtx.v_hour, dtx.v_minute, dtx.v_second, dtx.v_ms);
    }
    

    function getDecimal(bytes memory bsonbytes) public pure returns (int128,int8) {
	BsonUtils.BsonDocument memory dd = BsonUtils.fromBytes(bsonbytes);
	BsonUtils.BsonValue memory val = BsonUtils.getBsonMapValue(dd, "dec2");
	
	(int128 qq, int8 shift) = BsonUtils.getDecimal128RawValue(val);

	return (qq,shift);
    }



    function allocBytes(uint32 size, bool writeThem) public {
	qqq = 3; // FORCE a write to state.
	bytes memory qq = new bytes(size);
	if(writeThem) {
	    for(uint32 i = 0; i < size; i++) {
		qq[i] = 0x01;
	    }
	}
    }

}
