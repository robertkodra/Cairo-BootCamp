
## Setup:

1. First build the contract:
    `protostar build`
2. Run the test method:
    `protostar test test/test_main.cairo`
3. Convert your StarkNet Address utilizing the `utils.py` file. Contract Addresses need to be in `felt` type, so you will need to invoke `hex_to_felt()` function from the `utils.py` file. Once converted, save it somewhere. We will need it in the next process.
4. Deploy the contract on testnet:
   `protostar deploy build/main.json --network testnet --inputs YOUR_ADDRESS_CONVERTED_TO_FELT`
5. Success! 



## Libraries:

`protostar install https://github.com/OpenZeppelin/cairo-contracts`