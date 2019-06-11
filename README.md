# Introduction

In order to get started and completely understand the mechanism behind the oasis-direct-proxy (including the oasis-direct-proxy and ProxyCreationAndExecute contracts), one should first familiarize themselves with the DSProxy contract. 

**DS Proxy Summary**

The DS Proxy contract works by executing transactions and sequences of transactions by proxy. The proxy works as a deployed standalone smart contract, which can then be used by the owner to execute code.

In short, the contract works by having a user pass in bytecode for the contract as well as the `calldata` for the function they want to execute. The proxy will then create a contract using the bytecode and then use the `delegatecall` function with arguments specified in the `calldata`. The reason for this process is because loading in the code is more efficient than jumping to it.

If you would like to read and understand how the DS Proxy contract works further, please visit the contract [here](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol).

## Oasis Direct Proxy

When learning about how the Oasis Direct Proxy works, it is important to understand some of the main naming conventions that are used in the contracts. Below is a brief glossary to help you better understand the main terminology and variables used within the Oasis Direct Proxy: 

- `sellAllAmount` : this highlights the ideal condition to sell the exact amount provided on the expense of the `buy amount` as (`received`).

**Note:** There are cases where the `received` amount could be more or less. For example, a token could have been sold for a higher or lower price.  

- `buyAllAmount` : this highlights the ideal condition to buy the exact amount provided on the expense of the `pay amount` as (`deposit`). In some cases, the caller will `deposit` a higher amount in order to receive this amount or they will have to `deposit` less.

Most methods use an argument (`minBuyAmount` / `maxPayAmount`) that protects the caller from losses. This covers the case when the caller is trying to `buy` an `exact amount` and is willing to pay with `ETH` . In such a case, he/she should send the maximum amount of `ETH` that he/she is willing to pay in order to get the `exact buy amount`. This is due to the internal mechanism. This value will be used as `maxPayAmount`.

`payable` : This is used for those who are not aware of the above modifier. In short, it is a simple a way to allow your contract to collect and receive funds in `ETH`.

## OTC Interface Contract
This contract provides an interface that exposes the following three methods:
- `sellAllAmount`
- `buyAllAmount`
- `getPayAmount`

All from the [Maker OTC Market](https://github.com/makerdao/maker-otc/blob/master/src/matching_market.sol).

## Token Interface Contract

This contract is an interface which contains `ERC-20 token` methods as well as methods from the [WETH token](https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol) contract, such as `deposit` and `withdraw` .

# [OasisDirectProxy Contract](https://github.com/makerdao/oasis-direct-proxy/blob/gg/readme/src/OasisDirectProxy.sol)

**Summary:** This contract can be used by anyone who wishes to swap tokens directly on [eth2dai]([https://eth2dai.com](https://eth2dai.com/)).

## Key functionalities (as defined in the Smart Contract)

### withdrawAndSend

**Summary:** `withdrawAndSend` is used internally as the modifier states. This function is used in the following other methods:
-  `sellAllAmountBuyEth`
-  `buyAllAmountPayEth`
-  `buyAllAmountBuyEth`. 

The purpose of this function is to withdraw the locked up `ETH` from the `WETH token` contract and then send it to the specified destination.

**Arguments:**

- `TokenInterface wethToken` - The address of the `WETH token` contract.
- `uint wethAmt` - The amount which will be withdrawn and sent.

**Modifiers**

- `internal` - When you see this modifier, it means that the function and/or state variable can only be accessed internally (i.e. from within the current contract or contracts deriving from it).

---
### sellAllAmount

**Summary:** `sellAllAmount` is used to exchange `ERC-20 token` for `ERC-20 token`. When triggering an ERC-20 for ERC-20 exchange, the `payAmt` is sent to `this` contract from the caller. After this occurs, the `otc` contract can ensure that there is enough allowance in the `payToken` to do transfers on behalf of `this` contract. The next step is to proceed and sell the `payToken`. Lastly, the transfer occurs for the `buyAmt` to the caller.

**Arguments:**

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

**Summary:** `sellAllAmountPayEth` is used to exchange `ETH` for `ERC-20 tokens`. In order to call this method, the caller must first send `ETH`. The first step in this process is that the sent `ETH` is wrapped into `WETH token` (This is where `ETH` is locked in the `WETH` contract). After this occurs, the `otc` contract is guaranteed to have enough allowance to perform transfers on the behalf of `this` contract. Once the `otc` is guaranteed to have enough allowance, the locked `WETH` is then sold on the `otc` using `threshold` as a safeguard against slippage. Lastly, the `buyAmt` is sent back to the caller.

**Arguments:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken` - An address of any `ERC-20 token` or token that implements the interface.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token.`
- `uint minBuyAmt` - Reference **threshold**.

**Modifiers**

- `payable` - Added to the method to enable the receipt of eth while being called.

**Returns:**
- `uint buyAmt` - The amount of `buyToken` that will be purchased.

**Errors:**

- `otc.sellAllAmount` - This might cause the transaction to fail if the `buyAmt` results are less than `minBuyAmt`.
- `buyToken.transfer` - This might cause the transaction to fail.

---
### sellAllAmountBuyEth

**Summary:** `sellAllAmountBuyEth` is used to exchange `ERC-20 token` for `ETH`. To start, the method begins by sending the `payAmt` from the caller to `this` contract. Next, the `otc` contract is guaranteed to have enough allowance in the `payToken` to complete transfers on the behalf of `this` contract. The `paytoken` is then sold. The last step includes withdrawing the purchased `wethAmth` from the `WETH token` contract and then sending it to the caller.

**Arguments:**

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
**Summary:** `buyAllAmount` is used to exchange `ERC-20 token` for `ERC-20 token`. The process begins by calculating the amount to be paid. Next, `payAmt` is transferred to `this` contract. After this goes through, the `otc` contract is guaranteed to have enough allowance in the `payToken` to perform transfers on behalf of `this` contract. The following step is the buy operation, where `buyAmt` is bought. Lastly, the transfer of the purchased amount to the caller occurs.

**Arguments:**

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

**Summary:** `buyAllAmountPayEth` is used to exchange `ETH` for `ERC-20 token` (Note: this should be called with `ETH`). When first called, the `ETH` sent in is locked in `WETH token`. Then, once the `otc` contract guarantees that it has enough allowance in the `wethToken` to do transfers on the behalf of `this` contract, the buy operation proceeds to calculate the `wethAmt` . Next, the purchased amount is transferred to the caller. Lastly, the difference between the amount of `ETH` sent to the contract method and the actual amount needed to buy the `buyToken` amount is sent.

**Disclaimer:** It is important to note that there is neither `minBuyAmt` nor `maxPayAmt` here. It works by having the caller of the method take into account the slippage that might occur and thus send more `ETH` (the max amount he is willing to pay in order to get the `buyAmt`). If it is less, `ETH` is spent and the remaining is returned to the caller.

**Arguments:**

- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token` or token that implements the interface.
- `uint buyAmt` - The amount that will be purchased.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `wethToken` - The address of the `WETH token`

 **Modifiers**

- `payable`- Added to enable the receipt of eth while being called.

**Returns:**

- `uint wethAmth` - The amount of `WETH token` that will be paid.

**Errors**

- `otc.buyAllAmount` - This might cause the transaction to fail if the the caller is expected to pay more `ETH` than has been sent.
- `buyToken.transfer` - This might cause the transaction to fail.
- `withdrawAndSend` - This might cause the transaction to fail.

---
### buyAllAmountBuyEth

**Summary:** `buyAllAmountBuyEth` is used to exchange `ERC-20 token` for `ETH`. The process begins with the amount to be paid is calculated. Next, `payAmt` is transferred to `this` contract. Once done, the `otc` contract is guaranteed to have enough allowance in the `payToken` in order to do transfers on the behalf of `this` contract. The next operation is to buy the token, this is where `wethAmth` is purchased. Lastly, a transfer of the `wethAmt` to the caller occurs.

**Arguments:**

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

- `payable`- Added to enable the receipt of eth while being called.
---
# [ProxyCreateAndExecute Contract](https://github.com/makerdao/oasis-direct-proxy/blob/gg/readme/src/ProxyCreationAndExecute.sol)

**Summary:** The ProxyCreateAndExcecute contract is used to perform direct/instant trading by leveraging the existing Maker OTC platform. In this case, the caller of the methods is interested in creating a `DSProxy` that can be reused across other Maker Products as well as for selling and/or buying an exact amount of a given token for another token.

This contract works by extending the **OasisDirectProxy,** plus some additional methods. Each of the additional methods described below has the same functionality (calls two methods). 

One of the main call methods is the `DSProxyFactor.build` . This method creates a new proxy for a sender address. The other call in each of the additional methods is used to retrieve the amount that will be `sold` or `bought`.

### threshold

In order to understand exactly what `threshold` does, let's go though a quick example. 

**Example:** Let's say that someone wants to sell `10 MKR` at the price of `1.5 MKR/DAI`. 

Suppose the `buyAmt` will be `150 DAI`. By the time the transaction is executed, a [slippage](https://www.investopedia.com/terms/s/slippage.asp) may occur. This means that the price might have dropped to `1.2 MKR/DAI` and the caller will receive `120 DAI` instead of the exact uint `wethAmt` that was expected ( `150 DAI`). In order to mitigate such scenarios, we introduced **threshold** (`minBuyAmt` or `minPayAmt` ). 

The value provided here determines the lowest possible price that allows the trade to go through and close. If the prices drop below the threshold, the transaction fails and everything is reverted. Following the example above, one can provide a value (in base units) such as `140 DAI`. This will allow the transaction to pass and then the trade will be deemed successful if the price of `MKR/DAI` does not drop below `1.4 MKR/DAI`.


### Constructor
**Summary:** This is used to inject the `WETH` token address which is used in some of the methods described below.

**Arguments**:

- `address wethToken` - The address of the [WETH](https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol)  token. Note that it must be provided as a contract creation because the reference is needed in the `fallback` function.


## Key functionalities (as defined in the Smart Contract)

### createAndSellAllAmount

**Summary:** `createAndSellAllAmount`  is for `ERC-20 token` to `ERC-20 token` exchange. By calling this method, the sender creates a proxy and sells the exactly specified `ERC-20 token` amount.

**Arguments**:

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

**Summary:**  `createAndSellAllAmountPayEth`  method has the same functionality as mentioned in `createAndSellAllAmount`. However, there are a few key differences. For instance, there is no `payToken` and `payAmt`. When calling this method, a user is simply is selling `ETH`, and the function itself is marked as `payable`. This means that it can accept an `ETH` amount which is then used as `payAmt`.

**Modifiers**:

- `payable`- Added to enable the receipt of eth while being called.

**Arguments**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address of the factory that will create a unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract. 
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint minBuyAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint buyAmt` - The amount of the `buyToken` the user will receive after selling all the specified tokens.

---

### createAndSellAllAmountBuyEth

**Summary:**  `createAndSellAllAmountBuyEth` method also has similar behaviour as `createAndSellAllAmount` does but has a key difference. The key difference being that the `buyToken` is not specified and uses `wethToken` instead.

**Arguments**:

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

**Summary:**  `createAndBuyAllAmount`  is used in `ERC-20 token` to `ERC-20 token` exchange. This works by allowing the sender to create a proxy and then buy the exact `ERC-20 token` amount. 

**Arguments**:

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

**Summary**: `createAndBuyAllAmountPayEth` is used for `ETH` to `ERC-20 token` exchanges. Overall, it has the same functionality and intention as `createAndBuyAllAmount` as it is paying in `ETH` but has a few small differences. There is no `payToken` and `maxPayAmount` present. 

**Note:** This further explained at the beginning of the documentation for this contract. 

**Arguments**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create an unique and one-time only proxy for each of the callers
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract. 
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint buyAmt` - The amount that will be purchased.

**Arguments**:

- `payable`- Added to enable the receipt of eth while being called.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint wethAmt`- The amount of `WETH` the user will have to pay.

---
### createAndBuyAllAmountBuyEth

**Summary**:  `createAndBuyAllAmountBuyEth` method is used for `ERC-20 token` to `ETH` exchange. It works by enabling the sender to create a proxy and buy the exactly specified `WETH token` amount.

**Arguments**:

- [DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory` - An address to the factory that will create an unique and one-time only proxy for each of the callers.
- [OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc` - An address of the contract that represents the OTC market contract.
- [TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken` - An address of any `ERC-20 token`.
- `uint wethAmt` - The amount that will be purchased.
- `uint maxPayAmt` - Reference **threshold**.

**Returns**:

- [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy` - The newly created proxy for the user.
- `uint payAmt` - The amount of `payToken` the user will receive after selling all the tokens.

### Fallback Function

**Summary**: `fallback function`  is an unnamed function that is called if no other method is called. Currently, only the `WETH token` smart contract can call this function and send an `ETH` amount to it. There is an `internal method` called `withdrawAndSend` which is inherited from `OasisDirectProxy` contract that used the `WETH token` and sends the amount to`ProxyCreationAndExecute.`

**Modifiers**:

- `payable`- Added to enable the receipt of eth while being called.
