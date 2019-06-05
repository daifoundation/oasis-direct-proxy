In order to understand the idea behind those two contract one should familiarize  themselves with [DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol).

### OasisDirectProxy Contract

- **withdrawAndSend** -
- **sellAllAmount** -
- **sellAllAmountPayEth** -
- **sellAllAmountBuyEth** -
- **buyAllAmount** -
- **buyAllAmountPayEth** -
- **buyAllAmountBuyEth** -

### ProxyCreateAndExecute Contract
This contract is used to do direct/instant trading leveraging the existing Maker OTC platform. The caller of those methods is interested in creating a `DSProxy` that could reusing across other Maker Products and selling or buying exact amount of given token for another one.

It extends **OasisDirectProxy** and has some additional methods. Each of those  additional methods described below has the same functionality and calls two methods.

One of the call methods that is used is the _`DSProxyFactor.build`_ method that creates a new proxy for sender address.
The other call in each of those additional methods is used to get the amount that will be `sold` or `bought`

It's important to understand the naming convention that is used.

-- `*sellAllAmount*` highlights the necessity to sell the exact amount provided on the expense of the `buy amount` as (`received`). There are cases where `received` could be more, meaning that the token has been sold for a higher price but there are cases where the `received` could be less.

-- `*buyAllAmount*` highlights the necessity to buy the exact amount provided on the expense of the `pay amount` as ( `deposit`). There are cases again when the caller will `deposit` more in order to receive this amount or will have to `deposit` less.

In _`*all`_ the methods though there is an argument (`minBuyAmount` / `maxPayAmount`) that protects the caller from big losses except one.  In case when the caller is trying to `buy exact amount` and is willing to pay with _`ETH`_.  he/she should send the maximum amount of _`ETH`_ that he/she is willing to pay in order to get the `exct buy amount` because internally that value is used as `maxPayAmount`.

_`*threshold`_ - Let's take for an example that the caller would like to sell _`10 MKR`_ at the price of _`1.5 MKR/DAI`_. The _`buyAmt`_ he will get is supposed to be _`150 DAI`_. By the time the TX is executed a [slippage](https://www.investopedia.com/terms/s/slippage.asp) might occur.  That means that the price might have dropped to _`1.2 MKR/DAI`_ and the caller will receive _`120 DAI`_ instead of the expected _`150 DAI`_. It order to mitigate such scenarios we introduced the _threshold_ ( `minBuyAmt` or `minPayAmt` ). The value provided there determines the lowest possible price that allows the trade do close. If the prices drop below the threshold the TX fail and everything is reverted. Following the example above, one can provide a value ( in base units ) such as _`140 DAI`_. So TX will pass and the trade will be successful if the price of _`MKR/DAI`_ do not drop below  _`1.4 MKR/DAI`_

_`*payable`_ - for those who are not aware of this modifier it's simply a way to allow your contract to collect / receive funds in _`ETH`_

---
- **`constructor`** - Used to inject the _`WETH`_ token address which is used in some of the methods described below.

   **Arguments**:
   - _`address wethToken`_ - The address of the [WETH ](https://github.com/dapphub/ds-weth/blob/master/src/weth9.sol) token. It must be provided as contract creation because the reference is needed in the `fallback` function.

---
- **`createAndSellAllAmount`**  - By calling this method the sender creates a proxy and  sells the exact `ERC-20 token` amount. It's used in `ERC-20 token` to `ERC-20 token` exchange.

  **Arguments**:
  - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
  - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
  - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken`_ - An address of any `ERC-20 token` or token that implements the interface
  - _`uint payAmt`_ - The amount that will be sold
  - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken`_ - address of any `ERC-20 token`
  - _`uint minBuyAmt`_ - please check _*threshold_.

   **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint buyAmt`_ - the amount of _`buyToken`_ the user will receive after selling all the tokens
---

- **`createAndSellAllAmountPayEth`** -  Generally speaking It has the same functionality as _`createAndSellAllAmount`_ but there are some key differences. There is no _`payToken`_ and _`payAmt`_. Using this function one simply is selling _`ETH`_.  The function itself is marked as _`payable`_.  That means that it can accept _`ETH`_ amount which is used as _`payAmt`_.

	**Modifiers**:
	 - _`*payable`_

	 **Arguments**:
	 - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
	 - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken`_ - address of any `ERC-20 token`
	 - _`uint minBuyAmt`_ - please check _*threshold_.

	 **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint buyAmt`_ - the amount of _`buyToken`_ the user will receive after selling all the tokens

---
- **`createAndSellAllAmountBuyEth`** - Again this function has the behavior as _`createAndSellAllAmount`_ with the key difference that  _`buyToken`_ is not specified but instead _`wethToken`_ is used.

	 **Arguments**:
	 - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
	 - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken`_ - address of any `ERC-20 token`
	 - _`uint payAmt`_ - The amount that will be sold
	 - _`uint minBuyAmt`_ - please check _*threshold_.

   **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint wethAmt`_ - the amount  of _`WETH`_ the user will receive after selling all the tokens
---

- **`createAndBuyAllAmount`** - By calling this method the sender creates a proxy and  buys the exact `ERC-20 token` amount. It's used in `ERC-20 token` to `ERC-20 token` exchange.

	 **Arguments**:
	 - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
	 - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken`_ - address of any `ERC-20 token`
	 - _`uint buyAmt`_ - The amount that will be bought
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `payToken`_ - address of any `ERC-20 token`
	 - _`uint maxPayAmt`_ - please check _*threshold_.

   **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint payAmt`_ - the amount  of _`payTkn`_ the user will have to pay
---

- **`createAndBuyAllAmountPayEth`** - Same as `createAndBuyAllAmount` but paying in _`ETH`_ with the following differences. There are no `payToken` and `maxPayAmount (In the beginning of the documentation for this contract it's explained why)` specified. It's used in _`ETH`_ to _`ERC-20 token` exchange.

	 **Arguments**:
	 - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
	 - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken`_ - address of any `ERC-20 token`
	 - _`uint buyAmt`_ - The amount that will be bought

   **Modifiers**:
    - _`*payable`_

   **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint wethAmt`_ - the amount  of _`WETH`_ the user will have to pay
---

- **`createAndBuyAllAmountBuyEth`** - By calling this method the sender creates a proxy and  buys the exact `WETH token` amount. It's used in `ERC-20 token` to `ETH` exchange.

	 **Arguments**:
	 - _[DSProxyFactory](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol#L96) `factory`_ - An address to the factory that will create an unique and one-time only proxy for each of the callers
	 - _[OtcInterface](https://github.com/makerdao/maker-otc-support-methods/blob/master/src/MakerOtcSupportMethods.sol#L5) `otc`_ - An address of the contract that represents the OTC market contract. Only a few methods are exposed.
	 - _[TokenInterface](https://github.com/makerdao/oasis-direct-proxy/blob/master/src/OasisDirectProxy.sol#L11) `buyToken`_ - address of any `ERC-20 token`
	 - _`uint wethAmt`_ - The amount that will be bought
	 - _`uint maxPayAmt`_ - please check _*threshold_.

   **Returns**:
    - _[DSProxy](https://github.com/dapphub/ds-proxy/blob/master/src/proxy.sol) `proxy`_ - the newly created proxy for the user
    - _`uint payAmt`_ - the amount  of _`payToken`_ the user will receive after selling all the tokens
---
- **`fallback function`** - This is unnamed function that is called if no method is called. Only the _`WETH token`_ smart contract can call it and send _`ETH`_ amount to it.  There is an `internal method` called `withdrawAndSend` which is inherited from `OasisDirectProxy` contract that used the _`WETH token`_ and sends amount of  to  `ProxyCreationAndExecute.`

	**Modifiers**:
	 - _`*payable`_
