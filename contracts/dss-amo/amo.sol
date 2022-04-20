// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import { Vat } from "../dss/vat.sol";
import { Dai } from "../dss/dai.sol";
import { DaiJoin } from "../dss/join.sol";

contract DssAmo {

    // --- Auth ---
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    mapping (address => uint256) public wards;
    modifier auth {
        require(wards[msg.sender] == 1, "DssAmo/not-authorized");
        _;
    }

    // --- Data ---
    Vat         public immutable vat;
    DaiJoin     public immutable daiJoin;
    Dai         public immutable dai;

    mapping (address => uint256) public bal; // borrowed Dai  [wad]
    mapping (address => uint256) public max; // Maximum borrowable Dai  [wad]

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Ceil(address indexed usr, uint256 amount);
    event Mint(address indexed usr, uint256 amount);
    event Burn(address indexed usr, uint256 amount);

    // --- Init ---
    constructor(address daiJoin_) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        Vat vat_ = vat = Vat(DaiJoin(daiJoin_).vat());
        daiJoin = DaiJoin(daiJoin_);
        Dai dai_ = dai = DaiJoin(daiJoin_).dai();

        vat_.hope(daiJoin_);
        dai_.approve(daiJoin_, type(uint256).max);
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;
    function _add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }
    function _mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function _sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    // --- Administration ---
    function ceil(address usr, uint256 amount) external auth {
        max[usr] = amount;
        emit Ceil(msg.sender, amount);
    }

    // --- Vat Dai Mint/Burn ---
    function mint(uint256 amount) external
    {
        bal[msg.sender] = _add(bal[msg.sender], amount);
        require(bal[msg.sender] <= max[msg.sender], "DssAmo/ceiling-exceeded");
        vat.suck(address(this), address(this), _mul(amount, RAY));
        daiJoin.exit(msg.sender, amount);
        emit Mint(msg.sender, amount);
    }

    function burn(uint256 amount) external
    {
        bal[msg.sender] = _sub(bal[msg.sender], amount);
        dai.transferFrom(msg.sender, address(this), amount);
        daiJoin.join(address(this), amount);
        vat.heal(_mul(amount, RAY));
        emit Burn(msg.sender, amount);
    }
}
