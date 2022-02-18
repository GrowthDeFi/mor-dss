// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.0;

import { DSNote } from "../ds-note/note.sol";
import { DSToken } from "../ds-token/token.sol";
import { PipLike } from "../dss/spot.sol";
import { UniswapV2PairLike } from "../univ2-lp-oracle/UNIV2LPOracle.sol";

interface OracleLike
{
    function consultAveragePrice(address _pair, address _token, uint256 _amountIn) external view returns (uint256 _amountOut);
    function updateAveragePrice(address _pair) external;
}

contract UniV2TwapOracle is DSNote, PipLike {

    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address _usr) external note auth { wards[_usr] = 1;  }
    function deny(address _usr) external note auth { wards[_usr] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "UniV2TwapOracle/not-authorized");
        _;
    }

    // --- Math ---
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    address public immutable src;     // Price source (LP)
    address public immutable token;   // Token from the pair (the other must be PSM-pegged coin, like BUSD)
    uint256 public immutable cap;     // Price cap
    uint256 public immutable unit;    // Price unit
    uint256 public immutable factor;  // Price multiplier

    address public stwap;             // Short window TWAP implementation
    address public ltwap;             // Large window TWAP implementation

    address public orb;               // Optional oracle for the other token

    // --- Whitelisting ---
    mapping (address => uint256) public bud;
    modifier toll { require(bud[msg.sender] == 1, "UniV2TwapOracle/contract-not-whitelisted"); _; }

    constructor (address _stwap, address _ltwap, address _src, address _token, uint256 _cap, address _orb) public {
        require(_stwap != address(0), "UniV2TwapOracle/invalid-short-twap-address");
        require(_ltwap != address(0), "UniV2TwapOracle/invalid-long-twap-address");
        require(_src   != address(0), "UniV2TwapOracle/invalid-src-address");
        require(_token != address(0), "UniV2TwapOracle/invalid-token-address");
        address _token0 = UniswapV2PairLike(_src).token0();
        address _token1 = UniswapV2PairLike(_src).token1();
        require(_token == _token0 || _token == _token1, "UniV2TwapOracle/unknown-token-address");
        address _otherToken = _token == _token0 ? _token1 : _token0;
        uint8 _dec = DSToken(_token).decimals();
        require(_dec   <=         18, "UniV2TwapOracle/invalid-dec-places");
        uint8 _odec = DSToken(_otherToken).decimals();
        require(_odec  <=         18, "UniV2TwapOracle/invalid-other-dec-places");
        wards[msg.sender] = 1;
        stwap = _stwap;
        ltwap = _ltwap;
        src  = _src;
        token = _token;
        cap = _cap > 0 ? _cap : uint256(-1);
        unit = 10 ** uint256(_dec);
        factor = 10 ** (18 - uint256(_odec));
        orb = _orb;
    }

    function link(uint256 _id, address _twapOrOrb) external note auth {
        require(_twapOrOrb != address(0), "UniV2TwapOracle/no-contract");
        if(_id == 0) {
            stwap = _twapOrOrb;
        } else if (_id == 1) {
            ltwap = _twapOrOrb;
        } else if (_id == 2) {
            orb = _twapOrOrb;
        } else {
            revert("UniV2TwapOracle/invalid-id");
        }
    }

    function poke() external {
        OracleLike(stwap).updateAveragePrice(src);
        OracleLike(ltwap).updateAveragePrice(src);
    }

    function read() external view override toll returns (bytes32) {
        uint256 sprice = OracleLike(stwap).consultAveragePrice(src, token, unit);
        uint256 lprice = OracleLike(ltwap).consultAveragePrice(src, token, unit);
        uint256 price = sprice < lprice ? sprice : lprice;
        if (price > cap) price = cap;
        require(price > 0, "UniV2TwapOracle/invalid-price-feed");
        uint256 fprice = mul(price, factor);
        if (orb != address(0)) {
          uint256 oprice = uint256(PipLike(orb).read());
          require(oprice > 0, "UniV2TwapOracle/invalid-oracle-price");
          fprice = mul(fprice, oprice) / 1e18;
        }
        return bytes32(fprice);
    }

    function peek() external view override toll returns (bytes32,bool) {
        uint256 sprice = OracleLike(stwap).consultAveragePrice(src, token, unit);
        uint256 lprice = OracleLike(ltwap).consultAveragePrice(src, token, unit);
        uint256 price = sprice < lprice ? sprice : lprice;
        if (price > cap) price = cap;
        uint256 fprice = mul(price, factor);
        if (orb != address(0)) {
          (bytes32 _oprice, bool valid) = PipLike(orb).peek();
          uint256 oprice = valid ? uint256(_oprice) : 0;
          fprice = mul(fprice, oprice) / 1e18;
        }
        return (bytes32(fprice), fprice > 0);
    }

    function kiss(address a) external note auth {
        require(a != address(0), "UniV2TwapOracle/no-contract-0");
        bud[a] = 1;
    }

    function diss(address a) external note auth {
        bud[a] = 0;
    }

    function kiss(address[] calldata a) external note auth {
        for(uint i = 0; i < a.length; i++) {
            require(a[i] != address(0), "UniV2TwapOracle/no-contract-0");
            bud[a[i]] = 1;
        }
    }

    function diss(address[] calldata a) external note auth {
        for(uint i = 0; i < a.length; i++) {
            bud[a[i]] = 0;
        }
    }
}
