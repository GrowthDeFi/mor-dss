// SPDX-License-Identifier: AGPL-3.0-or-later

/// ESM.sol

// Copyright (C) 2019-2021 Maker Ecosystem Growth Holdings, INC.

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

pragma solidity >=0.6.12;

import { End } from "../dss/end.sol";
import { DSToken } from "../ds-token/token.sol";

interface DenyLike {
    function deny(address) external;
}

contract ESM {
    DSToken public immutable gem;   // collateral (MKR token)
    End     public immutable end;   // cage module
    address public immutable proxy; // Pause proxy
    uint256 public immutable min;   // minimum activation threshold [wad]

    mapping(address => uint256) public sum; // per-address balance
    uint256 public Sum; // total balance

    event Fire();
    event Join(address indexed usr, uint256 wad);

    constructor(address gem_, address end_, address proxy_, uint256 min_) public {
        gem = DSToken(gem_);
        end = End(end_);
        proxy = proxy_;
        min = min_;
    }

    function revokesGovernanceAccess() external view returns (bool ret) {
        ret = proxy != address(0);
    }

    // -- math --
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x + y;
        require(z >= x);
    }

    function fire() external {
        require(Sum >= min,  "ESM/min-not-reached");

        if (proxy != address(0)) {
            end.vat().deny(proxy);
        }
        end.cage();

        emit Fire();
    }

    function deny(address target) external {
        require(Sum >= min,  "ESM/min-not-reached");

        DenyLike(target).deny(proxy);
    }

    function join(uint256 wad) external {
        require(end.live() == 1, "ESM/system-already-shutdown");

        sum[msg.sender] = add(sum[msg.sender], wad);
        Sum = add(Sum, wad);

        require(gem.transferFrom(msg.sender, address(this), wad), "ESM/transfer-failed");
        emit Join(msg.sender, wad);
    }

    function burn() external {
        uint256 balance = gem.balanceOf(address(this));
        try gem.burn(balance) {} catch { gem.transfer(address(0xdead), balance); }
    }
}
