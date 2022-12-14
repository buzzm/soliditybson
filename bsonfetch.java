/*
Copyright (C) 2022 Paul "Buzz" Moschetti
    
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

package com.foo.web3.apps;

import com.foo.web3.providers.HttpFix;
import com.foo.web3.providers.Provider;

import com.foo.web3.generated.MyContract;

import org.web3j.crypto.Keys;
import org.web3j.crypto.Credentials;
import org.web3j.crypto.WalletUtils;
import org.web3j.protocol.Web3j;
import org.web3j.tx.Contract;

import org.web3j.tuples.generated.Tuple2;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import java.util.Map;
import java.util.List;
import java.util.Arrays;
import java.math.BigDecimal;
import java.math.BigInteger;

import java.util.TimeZone;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// Not for BSON Solidity; this is so we can rehash material ourselves:
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import org.bson.*;


public class bsonfetch {

    private static final Logger log = LoggerFactory.getLogger(bsonfetch.class);

    public static void main(String[] args) throws Exception {
        new bsonfetch().run(args);
    }

    private void run(String[] args) throws Exception {
	String contractAddr = args[0];

	Provider pp = ProviderFactory.create(); // default!

	HttpFix hf = pp.vendHttpFix();
	Web3j web3j = hf.getweb3j();
	log.info("Connected to Ethereum client version: "
		 + web3j.web3ClientVersion().send().getWeb3ClientVersion());
	Credentials credentials = pp.vendCredentials();

        log.info("Credentials loaded; wallet address: " + credentials.getAddress());
        log.info("Gas price: " + pp.vendGasPrice());

	//BigInteger gas_limit = Contract.GAS_LIMIT;
	BigInteger gas_limit = BigInteger.valueOf(8_000_000);

	MyContract ct2 = MyContract.load(contractAddr, web3j, credentials,
					 pp.vendGasPrice(), gas_limit);
        log.info("Contract loaded; valid " + ct2.isValid());

        if(!ct2.isValid()) {
	    log.info("? Contract is not valid");
	    System.exit(1);
	}

	// Getting rich state: a basic valuable capability:
	{
	    byte[] p1 = ct2.getStateFOO().send();
	    Document d6 = Utils.fromBytes(p1, Document.class);
	    Utils.walkMap(d6, 0);
	}

	// An example of the clunkiness of the native scalar only / Tuple
	// data passing paradigm:
	{
	    Tuple2<byte[], BigInteger> result = ct2.getLoanInfo().send();

	    BigInteger amt = result.getValue2();
	    System.out.println("loan info: " + new String(result.getValue1()) + " " + amt);
	}
	

	{ // roundtrip!
	    Document d5 = new Document();
	    d5.put("name", "bob");
	    d5.put("age", 21);
	    d5.put("dbl", 3.14159);

	    Document d85 = new Document();
	    d85.put("corn", "dog");
	    d85.put("blb", "brp");
	    d85.put("foo", -8L); // ha!

	    // Use a constant date so the hash stays the same:
	    d85.put("hdate", new java.util.Date(1661462299912L)); // 2022-08-25T21:18:19.912Z

	    java.util.ArrayList jal = new java.util.ArrayList();
	    jal.add(1);
	    jal.add("foo");
	    jal.add(new java.math.BigDecimal("107.78"));
	    jal.add(new BsonBinary("I AM BYTES!".getBytes()));
	    
	    for(int j = 0; j < 2; j++) {
		jal.add(d85);
	    }
	    d5.put("someThings", jal);

	    //  Java Document complete.  Show it for fun (optional):
	    Utils.walkMap(d5, 0);

	    //  Encode to BSON bytestream:
	    byte[] p2 = Utils.toBytes(d5, Document.class);

	    //  Get fingerprint of outgoing stream...
	    MessageDigest md2 = MessageDigest.getInstance("SHA-256");
	    md2.update(p2, 0, p2.length);
	    byte[] digest1 = md2.digest();
	    System.out.println("outgoing SHA2: " + Utils.bytesToHex(digest1));

	    // This is The Juice.  BSON bytestream goes to roundTrip(), which
	    // will convert the bytestream to BsonValue structures in the
	    // contract, then turn around and re-encode that to a bytestream
	    // and send it back...
	    byte[] p3 = ct2.roundTrip(p2).send();

	    md2.reset();
	    md2.update(p3, 0, p3.length);
	    byte[] digest2 = md2.digest();
	    System.out.println("incoming SHA2: " + Utils.bytesToHex(digest2));

	    // This *should* match.  That's the power of BSON.
	    System.out.println("SHA2 matches: " + java.util.Arrays.equals(digest1,digest2));

	    // Decode into a Java objects:
	    Document d6 = Utils.fromBytes(p3, Document.class);
	    Utils.walkMap(d6, 0);
	}

	{
	    System.out.println("\nSAVED STATE:");
	    byte[] p5 = ct2.getState().send();
	    if(p5.length != 0) {
		Document d16 = Utils.fromBytes(p5, Document.class);
		Utils.walkMap(d16, 0);
	    } else {
		System.out.println("no saved state; run bsonupdate to set it");
	    }
	}

	hf.shutdown();
    }

}
