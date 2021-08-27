// SPDX-License-Identifier: AGPL-3.0-or-later

/// join-6.sol -- Non-standard token adapters

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.
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

pragma solidity >=0.5.12;

import { DSNote } from "../ds-note/note.sol";
import { Vat } from "../dss/vat.sol";
import { DSToken } from "../ds-token/token.sol";

abstract contract DSToken6 is DSToken {
    function implementation() external view virtual returns (address);
}

// For a token with a proxy and implementation contract (like tUSD)
//  If the implementation behind the proxy is changed, this prevents joins
//   and exits until the implementation is reviewed and approved by governance.

contract GemJoin6 is DSNote {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external note auth { wards[usr] = 1; }
    function deny(address usr) external note auth { wards[usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "GemJoin6/not-authorized");
        _;
    }

    Vat     public vat;
    bytes32 public ilk;
    DSToken6 public gem;
    uint256 public dec;
    uint256 public live;  // Access Flag

    mapping (address => uint256) public implementations;

    constructor(address vat_, bytes32 ilk_, address gem_) public {
        wards[msg.sender] = 1;
        live = 1;
        vat = Vat(vat_);
        ilk = ilk_;
        gem = DSToken6(gem_);
        setImplementation(gem.implementation(), 1);
        dec = gem.decimals();
    }
    function cage() external note auth {
        live = 0;
    }
    function setImplementation(address implementation, uint256 permitted) public auth note {
        implementations[implementation] = permitted;  // 1 live, 0 disable
    }
    function join(address usr, uint256 wad) external note {
        require(live == 1, "GemJoin6/not-live");
        require(int256(wad) >= 0, "GemJoin6/overflow");
        require(implementations[gem.implementation()] == 1, "GemJoin6/implementation-invalid");
        vat.slip(ilk, usr, int256(wad));
        require(gem.transferFrom(msg.sender, address(this), wad), "GemJoin6/failed-transfer");
    }
    function exit(address usr, uint256 wad) external note {
        require(wad <= 2 ** 255, "GemJoin6/overflow");
        require(implementations[gem.implementation()] == 1, "GemJoin6/implementation-invalid");
        vat.slip(ilk, msg.sender, -int256(wad));
        require(gem.transfer(usr, wad), "GemJoin6/failed-transfer");
    }
}
