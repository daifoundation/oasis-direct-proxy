pragma solidity ^0.4.16;

import "ds-thing/thing.sol";

contract OtcInterface {
    mapping (uint => OfferInfo) public offers;
    struct OfferInfo {
        uint     payAmt;
        address  payToken;
        uint     buyAmt;
        address  buyToken;
        address  owner;
        bool     active;
        uint64   timestamp;
    }

    function getBestOffer(address, address) public returns (uint);
    function getWorseOffer(uint) public returns (uint);
    // function offer(uint, address, uint, address, uint) public returns (uint);
    function take(bytes32, uint128) public returns (uint);
}

contract TokenInterface {
    function balanceOf(address) returns (uint);
    function trust(address, bool);
}

contract TubInterface {
    function open() returns (bytes32);
    function join(uint);
    function lock(bytes32, uint);
    function draw(bytes32, uint);
    function cups(bytes32) returns (address, uint, uint);
    function gem() returns (TokenInterface);
    function skr() returns (TokenInterface);
    function sai() returns (TokenInterface);
    function vox() returns (VoxInterface);
    function mat() returns (uint);
    function per() returns (uint);
    function pip() returns (PipInterface);
    function tag() returns (uint);
}

contract VoxInterface {
    function par() returns (uint);
}

contract PipInterface {
    function read() returns (bytes32);
}

contract OasisDirectProxy is DSThing {
    address eth;
    address sai;

    function getPayAmount(OtcInterface otc, address buyToken, uint buyAmt, address payToken) constant public returns (uint sumPayAmt) {
        var offerId = otc.getBestOffer(buyToken, payToken); // Get best offer for the token pair
        var (offerPayAmt,,offerBuyAmt,,,,) = otc.offers(offerId); // Get amounts from best offer
        sumPayAmt = 0; // Amount to pay accumulator
        uint sumBuyAmt = 0; // Amount to buy accumulator (aux var)

        while (add(sumBuyAmt, offerPayAmt) < buyAmt) { // Meanwhile we need the whole offer to buy
            sumPayAmt = add(sumPayAmt, offerBuyAmt); // Add amount to pay accumulator
            sumBuyAmt = add(sumBuyAmt, offerPayAmt); // Add amount to buy accumulator
            offerId = otc.getWorseOffer(offerId); // We look for the next best offer
            assert(offerId != 0); // Fails if there are not enough offers to complete
            (offerPayAmt,,offerBuyAmt,,,,) = otc.offers(offerId); // Get amounts from the next best offer
        }
        sumPayAmt += rmul(sub(buyAmt, sumBuyAmt) * 10 ** 9, rdiv(offerBuyAmt, offerPayAmt)) / 10 ** 9; // Add proportional amount of last offer to pay accumulator
    }

    function sellAll(OtcInterface otc, TokenInterface buyToken, TokenInterface payToken, uint payAmt) public returns (uint buyAmt) {
        payToken.trust(otc, true);
        var offerId = otc.getBestOffer(buyToken, payToken); // Get best offer for the token pair
        buyAmt = 0; // Amount bought accumulator
        uint baux = 0; // Auxiliar var

        var (offerPayAmt,,offerBuyAmt,,,,) = otc.offers(offerId); // Get amounts from best offer

        while (payAmt > 0) { // Meanwhile there is amount to sell
            if (payAmt >= offerBuyAmt) { // If amount to sell is higher or equal than current offer amount to buy
                otc.take(bytes32(offerId), uint128(offerPayAmt)); // We take the whole offer
                buyAmt = add(buyAmt, offerPayAmt); // Add amount bought to acumulator
                payAmt = sub(payAmt, offerBuyAmt); // Decrease amount to sell
                if (payAmt > 0) { // If we still need more offers
                    offerId = otc.getBestOffer(buyToken, payToken); // We look for the next best offer
                    assert(offerId != 0); // Fails if there are not more offers
                }
            } else { // if lower
                baux = rmul(payAmt * 10 ** 9, rdiv(offerPayAmt, offerBuyAmt)) / 10 ** 9;
                otc.take(bytes32(offerId), uint128(baux)); // We take the portion of the offer that we need
                buyAmt = add(buyAmt, baux); // Add amount bought to acumulator
                payAmt = 0; // All amount is sold
            }
            (offerPayAmt,,offerBuyAmt,,,,) = otc.offers(offerId);  // Get actual amounts from the best offer
        }
    }

    function marginTrade(uint amt, uint lev, TubInterface tub, OtcInterface otc) public returns (bytes32 cup) {
        tub.gem().trust(tub, true);
        tub.skr().trust(tub, true);
        var neededAmt = wmul(amt, sub(lev, WAD)); // Amount we need to add to what we already have, so we can get the desired value
        var totSaiNeeded = getPayAmount(otc, tub.gem(), neededAmt, tub.sai()); // Check in the actual market how much total SAI is needed to get this desired WETH value
        uint saiDrawn = 0; // Total SAI already drawn
        uint saiToDraw = 0; // SAI to be drawn in each round
        uint gemToBuy = neededAmt; // WETH to be bought in each round (starts with the whole amount)
        uint initialSaiBalance = tub.sai().balanceOf(this); // Check actual balance of SAI of the proxy
        cup = tub.open(); // Open a new CDP

        while (saiDrawn < totSaiNeeded) { // While there is still SAI pending to be drawn
            saiToDraw = min(
                            rdiv(
                                rmul(
                                    rdiv(gemToBuy * 10 ** 9, tub.mat()),
                                    uint(tub.pip().read())
                                    ),
                                tub.vox().par()
                                ), // max value of SAI that can be drawn with the locked amount
                            sub(totSaiNeeded, saiDrawn) // value of SAI still needed to be drawn
                            );
            tub.join(gemToBuy); // Convert WETH to SKR (first time will be the initial amount, next cycles will on the amount bought)
            tub.lock(cup, rmul(tub.per(), gemToBuy)); // Lock SKR in the CDP created
            tub.draw(cup, saiToDraw); // Draw SAI
            saiDrawn = add(saiDrawn, saiToDraw); // Add SAI drawn to accumulator
            gemToBuy = sellAll(otc, tub.gem(), tub.sai(), sub(tub.sai().balanceOf(this), initialSaiBalance)); // Sell SAI, buy WETH, returns amount of WETH bought
        }
        tub.join(gemToBuy); // Convert last WETH to SKR
        tub.lock(cup, rmul(tub.per(), gemToBuy)); // Lock last SKR
    }
}
