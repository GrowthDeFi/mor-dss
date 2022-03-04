// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import { DaiJoin } from "../dss/join.sol";
import { Vat } from "../dss/vat.sol";

contract SurplusPayer {

    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Data ---
    Vat immutable public vat;
    DaiJoin immutable public daiJoin;
    address immutable public vow;

    uint256 constant PAYMENT_INTERVAL = 1 weeks;
    uint256 constant PAYMENT_LIMIT = 10_000e18; // 10k

    uint256 public lastPaymentTime;

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event SendPayment(address indexed recipient, uint256 amount);

    // --- Init ---
    constructor(address _daiJoin, address _vow, address _usr) public {
        wards[_usr] = 1;
        emit Rely(_usr);
        Vat _vat = vat = Vat(DaiJoin(_daiJoin).vat());
        daiJoin = DaiJoin(_daiJoin);
        vow = _vow;
        Vat(_vat).hope(_daiJoin);
    }

    // --- Math ---
    uint256 constant RAY = 10 ** 27;

    // --- Primary Functions ---
    function sendPayment(address _recipient, uint256 _amount) external auth {
        require(_amount <= PAYMENT_LIMIT, "SurplusPayer/limit-exceeded");
        require(lastPaymentTime / PAYMENT_INTERVAL < block.timestamp / PAYMENT_INTERVAL, "SurplusPayer/grace-period");
        vat.suck(vow, address(this), _amount * RAY);
        daiJoin.exit(_recipient, _amount);
        lastPaymentTime = block.timestamp;
        emit SendPayment(_recipient, _amount);
    }

}
