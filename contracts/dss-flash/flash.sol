// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.6.12;

import { Vat } from "../dss/vat.sol";
import { Dai } from "../dss/dai.sol";
import { DaiJoin } from "../dss/join.sol";

import { IERC3156FlashLender } from "./interface/IERC3156FlashLender.sol";
import { IERC3156FlashBorrower } from "./interface/IERC3156FlashBorrower.sol";
import { IVatDaiFlashLender } from "./interface/IVatDaiFlashLender.sol";
import { IVatDaiFlashBorrower } from "./interface/IVatDaiFlashBorrower.sol";

contract DssFlash is IERC3156FlashLender, IVatDaiFlashLender {

    // --- Auth ---
    function rely(address usr) external auth { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth { wards[usr] = 0; emit Deny(usr); }
    mapping (address => uint256) public wards;
    modifier auth {
        require(wards[msg.sender] == 1, "DssFlash/not-authorized");
        _;
    }

    // --- Data ---
    Vat         public immutable vat;
    DaiJoin     public immutable daiJoin;
    Dai         public immutable dai;
    address     public immutable vow;       // vow intentionally set immutable to save gas

    uint256     public  max;     // Maximum borrowable Dai  [wad]
    uint256     public  toll;    // Fee                     [wad = 100%]
    uint256     private locked;  // Reentrancy guard

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public constant CALLBACK_SUCCESS_VAT_DAI = keccak256("VatDaiFlashBorrower.onVatDaiFlashLoan");

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event FlashLoan(address indexed receiver, address token, uint256 amount, uint256 fee);
    event VatDaiFlashLoan(address indexed receiver, uint256 amount, uint256 fee);

    modifier lock {
        require(locked == 0, "DssFlash/reentrancy-guard");
        locked = 1;
        _;
        locked = 0;
    }

    // --- Init ---
    constructor(address daiJoin_, address vow_) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);

        Vat vat_ = vat = Vat(DaiJoin(daiJoin_).vat());
        daiJoin = DaiJoin(daiJoin_);
        Dai dai_ = dai = DaiJoin(daiJoin_).dai();
        vow = vow_;

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

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "max") {
            // Add an upper limit of 10^27 DAI to avoid breaking technical assumptions of DAI << 2^256 - 1
            require((max = data) <= RAD, "DssFlash/ceiling-too-high");
        } else if (what == "toll") toll = data;
        else revert("DssFlash/file-unrecognized-param");
        emit File(what, data);
    }

    // --- ERC 3156 Spec ---
    function maxFlashLoan(
        address token
    ) external override view returns (uint256) {
        if (token == address(dai) && locked == 0) {
            return max;
        } else {
            return 0;
        }
    }
    function flashFee(
        address token,
        uint256 amount
    ) external override view returns (uint256) {
        require(token == address(dai), "DssFlash/token-unsupported");

        return _mul(amount, toll) / WAD;
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override lock returns (bool) {
        require(token == address(dai), "DssFlash/token-unsupported");
        require(amount <= max, "DssFlash/ceiling-exceeded");

        uint256 amt = _mul(amount, RAY);
        uint256 fee = _mul(amount, toll) / WAD;
        uint256 total = _add(amount, fee);

        vat.suck(address(this), address(this), amt);
        daiJoin.exit(address(receiver), amount);

        emit FlashLoan(address(receiver), token, amount, fee);

        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "DssFlash/callback-failed"
        );

        dai.transferFrom(address(receiver), address(this), total); // The fee is also enforced here
        daiJoin.join(address(this), total);
        vat.heal(amt);

        return true;
    }

    // --- Vat Dai Flash Loan ---
    function vatDaiFlashLoan(
        IVatDaiFlashBorrower receiver,          // address of conformant IVatDaiFlashBorrower
        uint256 amount,                         // amount to flash loan [rad]
        bytes calldata data                     // arbitrary data to pass to the receiver
    ) external override lock returns (bool) {
        require(amount <= _mul(max, RAY), "DssFlash/ceiling-exceeded");

        uint256 prev = vat.dai(address(this));
        uint256 fee = _mul(amount, toll) / WAD;

        vat.suck(address(this), address(receiver), amount);

        emit VatDaiFlashLoan(address(receiver), amount, fee);

        require(
            receiver.onVatDaiFlashLoan(msg.sender, amount, fee, data) == CALLBACK_SUCCESS_VAT_DAI,
            "DssFlash/callback-failed"
        );

        vat.heal(amount);
        require(vat.dai(address(this)) >= _add(prev, fee), "DssFlash/insufficient-fee");

        return true;
    }

    function convert() external lock {
        daiJoin.join(address(this), dai.balanceOf(address(this)));
    }

    function accrue() external lock {
        vat.move(address(this), vow, vat.dai(address(this)));
    }
}
