// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import { PipLike } from "../dss/spot.sol";

interface INonViewableRateProvider
{
	function getRate() external returns (uint256 _rate);
}

contract RateCapOracle is PipLike {

    // --- Auth ---
    mapping (address => uint256) public wards;                                       // Addresses with admin authority
    function rely(address _usr) external auth { wards[_usr] = 1; emit Rely(_usr); }  // Add admin
    function deny(address _usr) external auth { wards[_usr] = 0; emit Deny(_usr); }  // Remove admin
    modifier auth {
        require(wards[msg.sender] == 1, "RateCapOracle/not-authorized");
        _;
    }

    address public src;   // Price source
    address public cap;   // Price cap source

    // hop and zph are packed into single slot to reduce SLOADs;
    // this outweighs the cost from added bitmasking operations.
    uint8   public stopped;         // Stop/start ability to update
    uint16  public hop = 1 hours;   // Minimum time in between price updates
    uint232 public zph;             // Time of last price update plus hop

    // --- Whitelisting ---
    mapping (address => uint256) public bud;
    modifier toll { require(bud[msg.sender] == 1, "RateCapOracle/contract-not-whitelisted"); _; }

    struct Feed {
        uint256 val;  // Price
        bool    has;  // Is price valid
    }

    Feed    internal cur;  // Current price
    Feed    internal nxt;  // Queued price

    address public            orb;   // Oracle for quote token

    function _sub(uint256 _x, uint256 _y) internal pure returns (uint256 z) {
        require((z = _x - _y) <= _x, "RateCapOracle/sub-underflow");
    }
    function _mul(uint256 _x, uint256 _y) internal pure returns (uint256 z) {
        require(_y == 0 || (z = _x * _y) / _y == _x, "RateCapOracle/mul-overflow");
    }

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Step(uint256 hop);
    event Stop();
    event Start();
    event Value(uint256 curVal, uint256 nxtVal);
    event Link(uint256 id, address val);
    event Kiss(address a);
    event Diss(address a);

    // --- Init ---
    constructor (address _src, address _cap, address _orb) public {
        require(_src != address(0), "RateCapOracle/invalid-src-address");
        require(_cap != address(0), "RateCapOracle/invalid-cap-address");
        require(_orb != address(0), "RateCapOracle/invalid-oracle-address");
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
        src  = _src;
        cap  = _cap;
        orb = _orb;
    }

    function stop() external auth {
        stopped = 1;
        delete cur;
        delete nxt;
        zph = 0;
        emit Stop();
    }

    function start() external auth {
        stopped = 0;
        emit Start();
    }

    function step(uint256 _hop) external auth {
        require(_hop <= uint16(-1), "RateCapOracle/invalid-hop");
        hop = uint16(_hop);
        emit Step(_hop);
    }

    function link(uint256 _id, address _val) external auth {
        require(_val != address(0), "RateCapOracle/no-contract-0");
        if(_id == 0) {
            src = _val;
        } else if (_id == 1) {
            cap = _val;
        } else if (_id == 2) {
            orb = _val;
        } else {
            revert("RateCapOracle/invalid-id");
        }
        emit Link(_id, _val);
    }

    // For consistency with other oracles.
    function zzz() external view returns (uint256) {
        if (zph == 0) return 0;  // backwards compatibility
        return _sub(zph, hop);
    }

    function pass() external view returns (bool) {
        return block.timestamp >= zph;
    }

    function seek() internal returns (uint256 quote) {
        // All rates are priced assuming 18 decimals
        // Get rate from liquidity pool (WAD)
	uint256 v = INonViewableRateProvider(src).getRate();
        require(v != 0, "RateCapOracle/invalid-src-price");
        // Get rate from limiter (WAD)
	uint256 l = INonViewableRateProvider(cap).getRate();
        require(l != 0, "RateCapOracle/invalid-cap-price");
        // Applies the cap
	if (v > l) v = l;
        // All Oracle prices are priced with 18 decimals against USD
        uint256 p = uint256(PipLike(orb).read());  // Query quote token price from oracle (WAD)
        require(p != 0, "RateCapOracle/invalid-oracle-price");
        return _mul(v, p) / 1e18;
    }

    function poke() external {
        // When stopped, values are set to zero and should remain such; thus, disallow updating in that case.
        require(stopped == 0, "RateCapOracle/is-stopped");
        // Equivalent to requiring that pass() returns true.
        // The logic is repeated instead of calling pass() to save gas
        // (both by eliminating an internal call here, and allowing pass to be external).
        require(block.timestamp >= zph, "RateCapOracle/not-passed");
        uint256 val = seek();
        require(val != 0, "RateCapOracle/invalid-price");
        cur = nxt;
        nxt = Feed(val, true);
        emit Value(cur.val, nxt.val);
    }

    function peek() external view override toll returns (bytes32,bool) {
        return (bytes32(uint256(cur.val)), cur.has);
    }

    function peep() external view toll returns (bytes32,bool) {
        return (bytes32(uint256(nxt.val)), nxt.has);
    }

    function read() external view override toll returns (bytes32) {
        require(cur.has, "RateCapOracle/no-current-value");
        return (bytes32(uint256(cur.val)));
    }

    function kiss(address _a) external auth {
        require(_a != address(0), "RateCapOracle/no-contract-0");
        bud[_a] = 1;
        emit Kiss(_a);
    }

    function kiss(address[] calldata _a) external auth {
        for(uint256 i = 0; i < _a.length; i++) {
            require(_a[i] != address(0), "RateCapOracle/no-contract-0");
            bud[_a[i]] = 1;
            emit Kiss(_a[i]);
        }
    }

    function diss(address _a) external auth {
        bud[_a] = 0;
        emit Diss(_a);
    }

    function diss(address[] calldata _a) external auth {
        for(uint256 i = 0; i < _a.length; i++) {
            bud[_a[i]] = 0;
            emit Diss(_a[i]);
        }
    }
}
