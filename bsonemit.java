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

import java.util.Map;
import java.util.List;
import java.util.Arrays;
import java.math.BigDecimal;
import java.math.BigInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.web3j.crypto.Credentials;
import org.web3j.crypto.WalletUtils;
import org.web3j.protocol.Web3j;
import org.web3j.protocol.core.methods.response.TransactionReceipt;
import org.web3j.protocol.http.HttpService;
import org.web3j.tx.Contract;
import org.web3j.tx.ManagedTransaction;
import org.web3j.tx.Transfer;
import org.web3j.utils.Convert;
import org.web3j.utils.Numeric;

import org.web3j.tuples.generated.Tuple2;
import org.web3j.tuples.generated.Tuple5;
import org.web3j.tuples.generated.Tuple7;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import org.bson.*;



public class bsonemit {

    private static final Logger log = LoggerFactory.getLogger(bsonemit.class);


    public static void main(String[] args) throws Exception {
        new bsonemit().run(args);
    }


    private void run(String[] args) throws Exception {

	String contractAddr = args[0];

	String newCpty = args[1];

	Provider pp = ProviderFactory.create(); // default!

	HttpFix hf = pp.vendHttpFix();
	Web3j web3j = hf.getweb3j();
	log.info("Connected to Ethereum client version: "
		 + web3j.web3ClientVersion().send().getWeb3ClientVersion());
	Credentials credentials = pp.vendCredentials();
        log.info("Credentials loaded");

	MyContract ct2 = MyContract.load(contractAddr, web3j, credentials,
					 pp.vendGasPrice(), Contract.GAS_LIMIT);

	TransactionReceipt TXr;

	boolean doEmit = false;
	if(newCpty.substring(0,1).equals("E")) {
	    doEmit = true;
	}
	log.info("wrap and emit is " + doEmit);
	log.info("new cpty name len is " + newCpty.length());	

	TXr = ct2.changeCounterparty(newCpty, doEmit).send();

	log.info("TXreceipt: " + TXr.toString());
	log.info("  TX status:   " + TXr.getStatus());
	log.info("  TX root:     " + TXr.getRoot());
	log.info("  TX TXhash:   " + TXr.getTransactionHash());
	log.info("  TX blk hash: " + TXr.getBlockHash());
	log.info("  TX blk num:  " + TXr.getBlockNumber());
	log.info("  TX gas used: " + TXr.getGasUsed());
	log.info("  TX from:     " + TXr.getFrom());
	log.info("  TX to:       " + TXr.getTo());
	
	hf.shutdown();
    }
}
