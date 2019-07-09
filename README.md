# Introduction

In order to get started and completely understand the mechanism behind the oasis-direct-proxy, one should first familiarize themselves with the DSProxy contract.

**DS Proxy Summary**

The DS Proxy contract works by executing transactions and sequences of transactions by proxy. The proxy works as a deployed standalone smart contract, which can then be used by the owner to execute code.

In short, the contract works by having a user pass in bytecode for the contract as well as the `calldata` for the function they want to execute. The proxy will then create a contract using the bytecode and then use the `delegatecall` function with arguments specified in the `calldata`. The reason for this process is because loading in the code is more efficient than jumping to it.

If you would like to read and understand how the DS Proxy contract works further, please visit the contract [here](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol).

## Oasis Direct Proxy

When learning about how the Oasis Direct Proxy works, it is important to understand some of the main naming conventions that are used in the contracts. Below is a brief summary to help you better understand the main terminology, variables and methods used within the Oasis Direct Proxy:

**Methods**:

- `sellAllAmount`
- `sellAllAmountPayEth`
- `sellAllAmountBuyEth`
- `buyAllAmount`
- `buyAllAmountPayEth`
- `buyAllAmountBuyEth`

The main methods are the `sellAllAmount*` and `buyAllAmount*` and the other methods listed above have the same intention plus extended functionality.

**Note**: There are cases where the `received` amount could be more or less. For example, a token could have been sold for a higher or lower price.

**Other**:

`payable` : A modifier that enables a contract to collect / receive funds in *`ETH`*

#### How to sell tokens:

In a trade there is always a token that is sold and one that is bought. Using `OasisDirectProxy` one can sell tokens using  both `sellAll*` and `buyAll*` methods. There is a significant difference regarding the amounts that will be sold/bought when different methods are used. In the examples below, we will try to highlight the difference and explain in details when one should use each of the methods.

All of the scenarios will include the following prerequisites:
 -- One would like to exchange (sell) `MKR` for (buy) `DAI`.
 -- The price  is `15 MKR/DAI`

 - ***Case Scenario 1:*** -  The market price is not going to move and no  [slippage](https://www.investopedia.com/terms/s/slippage.asp) will occur in the price. The caller would like to sell `10 MKR`. At the given price that means they will receive `150 DAI`. When the price is stable and won't move before the trade is completed the caller might use both `sellAllAmount` or `buyAllAmount` and they will sell exactly the `10MKR` and will get exactly the `150 DAI`.
 - ***Case Scenario 2*** - A negative [slippage](https://www.investopedia.com/terms/s/slippage.asp) occurs and the price moves down.  Between the moment when a transaction is initiated and confirmed everything might happen. In this case the caller would like to sell `10 MKR`. If the price fall to `10 MKR/DAI` the caller will receive only `100 DAI`. Again the caller might use either `sellAllAmount` or `buyAllAmount` with the following difference.
	 - ***Case Scenario 2.1*** - The caller is aware of the price and he would like to sell `10 MKR` and get as much `DAI` as possible. They might use the `sellAllAmount` method. As shown above the price might decrease significantly. In order to protect the caller of losing lots of their funds we introduced the `minBuyAmt` parameter. In our scenario we will use `140 DAI` as `minBuyAmt`. That means that the caller would like to receive at least `140 DAI`. If due to slippage the price will drop below `14 MKR/DAI` the transaction will fail and revert.
	 - ***Case Scenario 2.2*** - The caller is aware of the price and he would like to sell `MKR` and get `150 DAI`. In this case one can use `buyAllAmount` method. Again the price might decrease and the caller might pay more than `10 MKR` in order to get their desired `150 DAI`. To protect the caller from spending too much we introduced the `maxPayAmt` parameter. In our scenario we will use `11 MKR`. That means that the caller would like to deposit `11 MKR` at most. If due to slippage the price drops below `~13.63 MKR/DAI` the transaction will fail and revert.

 - ***Case Scenario 3:*** -  A positive [slippage](https://www.investopedia.com/terms/s/slippage.asp) occurs and the price moves up. Let's say the price moves from `15 MKR/DAI` to `20 MKR/DAI`. Again the caller might use both `sellAllAmount` and `buyAllAmount`. It's up to the caller to define their priority - whether they would like to sell all of their token and get as much as possible or get some fixed amount of the `quote` and pay as little as possible.
   - ***Case Scenario 3.1:*** - The caller is interested in selling `10 MKR`. By calling `sellAllAmount` they will sell all of the `10MKR` at the price of `20 MKR/DAI` and will receive `200 DAI`.
   - ***Case Scenario 3.2:*** - The caller is interested in buying `150 DAI`. By calling `buyAllAmount` the will sell  only `7.5 MKR` at the price of `20 MKR/DAI` in order to receive the desired amount in `DAI`
`Threshold`: It is a collective term to refer to the `maxSellAmount` and `minBuyAmount` paramters. Why and when to use them once can refer to the case scenarios described above.

The value provided by threshold is that it determines the lowest possible price that allows the trade to go through and close. However, if the prices drop below the limit, the transaction fails and everything is reverted. Following the example above, one can provide a value (in base units) such as `140 DAI`. This will allow the transaction to pass and then the trade will be deemed successful if the price of `MKR/DAI` does not drop below `1.4 MKR/DAI`.

## OTC Interface Contract

This contract provides an interface that exposes the following three methods:

- `sellAllAmount`
- `buyAllAmount`
- `getPayAmount`

All from the [Maker OTC Market](https://github.com/makerdao/maker-otc/blob/master/src/matching_market.sol).

## Token Interface Contract

This contract is an interface which contains `ERC-20 token` methods as well as methods from the [WETH token](https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol) contract, such as `deposit` and `withdraw`.

# [OasisDirectProxy Contract](https://github.com/makerdao/oasis-direct-proxy/blob/gg/readme/src/OasisDirectProxy.sol)

**Summary:** This contract can be used by anyone who wishes to swap tokens directly on [eth2dai](https://www.notion.so/makerdao/%5B%3Chttps://eth2dai.com%3E%5D(%3Chttps://eth2dai.com/%3E)).

## Key functionalities (as defined in the Smart Contract)

### withdrawAndSend

**Summary:** `withdrawAndSend` is used internally as the modifier states. This function is used in the following other methods:

- `sellAllAmountBuyEth`
- `buyAllAmountPayEth`
- `buyAllAmountBuyEth`

The purpose of this function is to withdraw the locked up `ETH` from the `WETH token` contract and then send it to the caller.

**Parameters:**

- `TokenInterface wethToken` - The address of the `WETH token` contract.
- `uint wethAmt` - The amount which will be withdrawn and sent.

**Modifiers**

- `internal` - When you see this modifier, it means that the function and/or state variable can only be accessed internally (i.e. from within the current contract or contracts deriving from it).

---

### sellAllAmount

**Summary:** `sellAllAmount` is used when triggering an ERC-20 for ERC-20 exchange, where the `payAmt` is sent to this contract from the caller. After that, the `otc` contract is guaranteed to have enough allowance in the `payToken` to do transfers on behalf of `this` contract. The next step is to proceed and sell the `payToken`. Lastly, the transfer occurs for the `buyAmt` to the caller.

**Parameters:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - This represents the contract address of the OTC market contract (where only a few methods are exposed).
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface of it.
- `uint payAmt` - The amount that is to be sold.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - The contract address of any `ERC-20 token`.
- `uint minBuyAmt` - Reference **threshold**.

**Returns:**

- `uint buyAmt` - The amount of `buyToken` that will be purchased.

**Errors:**

- `payToken.transferFrom` - This might cause the transaction to fail if the caller has not authorized `this` contract to do transfers.
- `otc.sellAllAmount` - This might cause the transaction to fail if the `buyAmt` results in being less than `minBuyAmt`.
- `buyToken.transfer` - This might cause the transaction to fail.

---

### sellAllAmountPayEth

**Summary:** The `sellAllAmountPayEth` method is  used when triggering an`ETH` for `ERC-20 token`exchange. The process begins when `ETH` is sent, it is then wrapped into `WETH token` and once the `otc` is guaranteed to have enough allowance, the locked `WETH` is then sold on the `otc` using `minBuyAmt` as a safeguard against slippage. Lastly, the `buyAmt` is sent back to the caller.

**Parameters:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token.`
- `uint minBuyAmt` - Reference **threshold**.

**Modifiers**

- `payable` - Added to the method to enable the receipt of Eth.

**Returns:**

- `uint buyAmt` - The amount of `buyToken` that will be purchased.

**Errors:**

- `otc.sellAllAmount` - This might cause the transaction to fail if the `buyAmt` results are less than `minBuyAmt`.
- `buyToken.transfer` - This might cause the transaction to fail.

---

### sellAllAmountBuyEth

**Summary:** The `sellAllAmountBuyEth`  is used when triggering an `ERC-20 token` for `ETH` exchange method has the same functionality as mentioned in `sellAllAmount` but with a difference, which is the withdrawal of the purchased `wethAmt` from the `WETH token` contract and then sending it to the caller in the form of native `ETH`.

**Parameters:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint payAmt` - The amount that is to be sold.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `wethToken` - The address of the `WETH token`
- `uint minBuyAmt` - Reference **threshold**.

**Returns:**

- `uint wethAmt` - The amount of `WETH` that will be purchased.

**Errors:**

- `payToken.transferFrom` - This might cause the transaction to fail if the caller has not authorized `this` contract to do transfers.
- `otc.sellAllAmount` - This might cause the transaction to fail if the `buyAmt` results are less than `minBuyAmt`.
- `withdrawAndSend` - This might cause the transaction to fail.

---

### buyAllAmount

**Summary:**  `buyAllAmount`  is used when triggering an `ERC-20 token` for `ERC-20 token` exchange. It calculates the amount to be paid, then the `payAmt` is transferred to this contract. Next, the `otc` contract is guaranteed to have enough allowance in the `payToken` to perform transfers on behalf of `this` contract. Follows a buy operation, where `buyAmt` is bought. Lastly, the transfer of the purchased amount to the caller occurs.

**Parameters:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint buyAmt` - The amount that will be purchased.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint maxPayAmt` - Reference **threshold**.

**Returns:**

- `uint payAmt` - The amount of `payToken` that will be paid out.

**Errors:**

- `otc.getPayAmount` - This might cause the transaction to fail if there isn't enough of an order to fill the `buyAmt`
    - This might also cause the transaction to fail if the calculated amount that is to be paid is higher than `maxPayAmt`
- `payToken.transferFrom` - This might cause the transaction to fail.
- `otc.buyAllAmount` - This might cause the transaction to fail if it needs to pay more than the calculated amount that needs to be paid in the beginning of the transaction.
- `buyToken.transfer` - This might cause the transaction to fail.

---

### buyAllAmountPayEth

**Summary:** The `buyAllAmountPayEth`  is used when triggering an `ETH` for `ERC-20 token` exchange. When called, the `ETH` sent in is locked in `WETH token`. Then, once the `otc` contract is guaranteed to have enough allowance in the `wethToken` to do transfers on the behalf of `this` contract, the buy operation proceeds to calculate the `wethAmt`. Next, the purchased amount is transferred to the caller. Lastly, the difference between the amount of `ETH` sent to the contract method and the actual amount needed to buy the `buyToken` amount is sent.

**Disclaimer:** It is important to note that there is neither `minBuyAmt` nor `maxPayAmt` here. It works by having the caller of the method take into account the slippage that might occur and thus send more `ETH` (the max amount he is willing to pay in order to get the `buyAmt`). If less amount of ETH is spent to get the buyAmt, the remaining amount of the sent ETH is returned to the caller.

**Parameters:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint buyAmt` - The amount that will be purchased.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `wethToken` - The address of the `WETH token`

**Modifiers**

- `payable`- Added to enable the receipt of Eth.

**Returns:**

- `uint wethAmt` - The amount of `WETH token` that will be paid.

**Errors**

- `otc.buyAllAmount` - This might cause the transaction to fail if the the caller is expected to pay more `ETH` than has been sent.
- `buyToken.transfer` - This might cause the transaction to fail.
- `withdrawAndSend` - This might cause the transaction to fail.

---

### buyAllAmountBuyEth

**Summary:** `buyAllAmountBuyEth`  is used when triggering an `ERC-20 token` for `ETH` exchange. The `wethAmt` is bought and then a transfer of the `wethAmt` to the caller occurs.

**Parameters:**

- OtcInterface `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `wethToken` - The address of the `WETH token`.
- `uint wethAmt` - The amount that will be purchased.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint maxPayAmt` - Reference **threshold**.

**Returns:**

- `uint payAmt` - The amount of `payToken` that will be paid.

**Errors:**

- `otc.getPayAmount` - This might cause the transaction to fail.
    - The transaction may fail if the calculated amount to be paid is higher than `maxPayAmt`.
- `otc.buyAllAmount` - The transaction may fail if the the caller is expected to pay more `ETH` than has been sent.
- `buyToken.transfer` - This might cause the transaction to fail.
- `withdrawAndSend` - This might cause the transaction to fail.

**Modifiers:**

- `payable`- Added to enable the receipt of Eth.

---

# [ProxyCreateAndExecute Contract](https://github.com/makerdao/oasis-direct-proxy/blob/gg/readme/src/ProxyCreationAndExecute.sol)

**Summary:** The `ProxyCreateAndExecute` allows the caller of the contract to create a proxy and exchange tokens within a ***single transaction***. It extends the `OasisDirectProxy` contract. If one is not interested in creating a proxy then using only `OasisDirectProxy` is sufficient.
One of the main call methods is the `DSProxyFactor.build`. This method creates a new proxy for a sender address. The other call in each of the additional methods is used to retrieve the amount that will be `sold` or `bought`.

### Constructor

**Summary:** This is used to inject the `WETH` token address which is used in some of the methods described below.

**Parameters:**:

- `address wethToken` - The address of the [WETH](https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol) token.

## Key functionalities (as defined in the Smart Contract)

### createAndSellAllAmount

**Summary:** `createAndSellAllAmount`  creates a proxy and calls `sellAllAmount`.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`- An address to the factory that will create a unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint payAmt` - The amount that will be sold.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`
- `uint minBuyAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint buyAmt` - The amount of `buyToken` the user will receive after selling all the specified tokens.

---

### createAndSellAllAmountPayEth

**Summary:** `createAndSellAllAmountPayEth` creates a proxy and calls `sellAllAmountPayEth`.

**Modifiers**:

- `payable`- Added to enable the receipt of Eth.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address of the factory that will create a unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint minBuyAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint buyAmt` - The amount of the `buyToken` the user will receive after selling all the specified tokens.

---

### createAndSellAllAmountBuyEth

**Summary:** `createAndSellAllAmountBuyEth` creates a proxy and calls `sellAllAmountBuyEth`.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create a unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token`.
- `uint payAmt` - The amount that will be sold.
- `uint minBuyAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint wethAmt` - The amount of `WETH` the user will receive after selling all the specified tokens.

---

### createAndBuyAllAmount

**Summary:** `createAndBuyAllAmount` creates a proxy and calls `buyAllAmount`.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create an unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint buyAmt` - The amount that will be purchased.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token`.
- `uint maxPayAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint payAmt` - The amount of the `payTkn` the user will have to pay.

---

### createAndBuyAllAmountPayEth

**Summary**: `createAndBuyAllAmountPayEth` creates a proxy and calls `buyAllAmountPayEth`.

**Note:** This further explained at the beginning of the documentation for this contract.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create an unique and one-time only proxy for each of the callers
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint buyAmt` - The amount that will be purchased.

**Parameters:**:

- `payable`- Added to enable the receipt of Eth.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint wethAmt`- The amount of `WETH` the user will have to pay.

---

### createAndBuyAllAmountBuyEth

**Summary**: `createAndBuyAllAmountBuyEth` creates a proxy and calls `buyAllAmountBuyEth`.

**Parameters:**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create an unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint wethAmt` - The amount that will be purchased.
- `uint maxPayAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint payAmt` - The amount of `payToken` the user will receive after selling all the tokens.

### Fallback Function

**Summary**: `fallback function` is an unnamed function that is called if no other method is called. Currently, only the `WETH token` smart contract can call this function and send an `ETH` amount to it. There is an `internal method` called `withdrawAndSend` which is inherited from `OasisDirectProxy` contract that used the `WETH token` and sends the amount to`ProxyCreationAndExecute.`

**Modifiers**:

- `payable`- Added to enable the receipt of Eth.
