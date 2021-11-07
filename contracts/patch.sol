// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.6.12;

import { DSValue } from "./ds-value/value.sol";
import { ChainLog } from "./dss-chain-log/ChainLog.sol";
import { UNIV2LPOracle } from "./univ2-lp-oracle/UNIV2LPOracle.sol";
import { UniV2TwapOracle } from "./univ2-twap-oracle/univ2-twap-oracle.sol";
import { XSushiOracle } from "./xsushi-oracle/xsushi-oracle.sol";
import { Vat } from "./dss/vat.sol";
import { GemJoin } from "./dss/join.sol";
import { GemJoin5 } from "./dss-gem-joins/join-5.sol";
import { IlkRegistry } from "./ilk-registry/IlkRegistry.sol";

// Deploy Patch contract
// DSRole.setRootUser(DEPLOYER);
// tag = PATCH.soul(); // 0xa38ca46b144ae33993b6144595428e760a61cee1d0ff13ff4654a822e55d8ffd
// fax = 0xc0406226; // run()
// eta = Math.floor(Date.now() / 1000) + 60;
// DSPause.plot(PATCH, tag, fax, eta)
// DSPause.exec(PATCH, tag, fax, eta)
contract Patch
{
	address constant DEPLOYER = 0x0B640b3E91420B495a33d11Ee96AFb19bE2Db693;
	address constant MCD_VAT = 0x713C28b2Ef6F89750BDf97f7Bbf307f6F949b3fF;
	address constant MCD_SPOT = 0x7C4925D62d24A826F8d945130E620fdC510d0f68;
	address constant MCD_END = 0x67D8cda3131890a0603379B03cd1B8Ed39753DA6;
	address constant VAL_PSM_STKUSDC = 0x68697fF7Ec17F528E3E4862A1dbE6d7D9cBBd5C6;
	address constant VAL_JOE = 0x1a06452B84456728Ee4054AE6157d3feDF56C295;
	address constant VAL_XJOE = 0xF49390eE384C5df2e82ac99909a6236051a4E82B;
	address constant VAL_TDJAVAXJOE = 0xC5065b47A133071fe8cD94f46950fCfBA53864C6;
	address constant VAL_TDJUSDCJOE = 0x7bA715959A52ef046BE76c4E32f1de1d161E2888;
	address constant VAL_TDJUSDTJOE = 0xeBcb52E5696A2a90D684C76cDf7095534F265370;
	address constant MCD_JOIN_STKJAVAX_A = 0x0c88e124AF319af1A1a6BD4C3d1CB70070Fd421f;
	address constant MCD_JOIN_STKJWETH_A = 0x7a96803F857D854878A95fa07F290B34Ab2981a7;
	address constant MCD_JOIN_STKJWBTC_A = 0x781E44923fb912b1d0aa892BBf62dD1b4dfC9cd5;
	address constant MCD_JOIN_STKJLINK_A = 0x972F78558B4F8D677d84c8d1d4A73836c8DE4900;
	address constant ILK_REGISTRY = 0x03A90f53DeEac9104Ef699DB8Ca6Cc1EFfc7a0DC;
	address constant CHANGELOG = 0xd1a85349D73BaA4fFA6737474fdce9347B887cB2;

	function soul() external view returns (bytes32 _tag)
	{
		address _usr = address(this);
		assembly { _tag := extcodehash(_usr) }
	}

	// executed in the contact of the MCD_PAUSE_PROXY
	function run() external
	{
		fixVAL_PSM_STKUSDC();
		fixVAL_JOE();
		fixMCD_JOIN_STKJtoken_A(MCD_JOIN_STKJAVAX_A, "MCD_JOIN_STKJAVAX_A");
		fixMCD_JOIN_STKJtoken_A(MCD_JOIN_STKJWETH_A, "MCD_JOIN_STKJWETH_A");
		fixMCD_JOIN_STKJtoken_A(MCD_JOIN_STKJWBTC_A, "MCD_JOIN_STKJWBTC_A");
		fixMCD_JOIN_STKJtoken_A(MCD_JOIN_STKJLINK_A, "MCD_JOIN_STKJLINK_A");
	}

	function fixVAL_PSM_STKUSDC() internal
	{
		DSValue(VAL_PSM_STKUSDC).poke(bytes32(uint256(1e18)));
	}

	function fixVAL_JOE() internal
	{
		address _stwap = UniV2TwapOracle(VAL_JOE).stwap();
		address _ltwap = UniV2TwapOracle(VAL_JOE).ltwap();
		address _src = UniV2TwapOracle(VAL_JOE).src();
		address _token = UniV2TwapOracle(VAL_JOE).token();
		uint256 _cap = UniV2TwapOracle(VAL_JOE).cap();

		address NEW_VAL_JOE = address(new UniV2TwapOracle(_stwap, _ltwap, _src, _token, _cap));
		UniV2TwapOracle(NEW_VAL_JOE).kiss(DEPLOYER);
		UniV2TwapOracle(NEW_VAL_JOE).poke();
		UniV2TwapOracle(NEW_VAL_JOE).kiss(MCD_SPOT);
		UniV2TwapOracle(NEW_VAL_JOE).kiss(MCD_END);
		UniV2TwapOracle(NEW_VAL_JOE).kiss(VAL_XJOE);
		UniV2TwapOracle(NEW_VAL_JOE).kiss(VAL_TDJAVAXJOE);
		UniV2TwapOracle(NEW_VAL_JOE).kiss(VAL_TDJUSDCJOE);
		UniV2TwapOracle(NEW_VAL_JOE).kiss(VAL_TDJUSDTJOE);

		// update references
		XSushiOracle(VAL_XJOE).link(NEW_VAL_JOE);
		if (UNIV2LPOracle(VAL_TDJAVAXJOE).orb0() == VAL_JOE) UNIV2LPOracle(VAL_TDJAVAXJOE).link(0, NEW_VAL_JOE);
		else
		if (UNIV2LPOracle(VAL_TDJAVAXJOE).orb1() == VAL_JOE) UNIV2LPOracle(VAL_TDJAVAXJOE).link(1, NEW_VAL_JOE);
		if (UNIV2LPOracle(VAL_TDJUSDCJOE).orb0() == VAL_JOE) UNIV2LPOracle(VAL_TDJUSDCJOE).link(0, NEW_VAL_JOE);
		else
		if (UNIV2LPOracle(VAL_TDJUSDCJOE).orb1() == VAL_JOE) UNIV2LPOracle(VAL_TDJUSDCJOE).link(1, NEW_VAL_JOE);
		if (UNIV2LPOracle(VAL_TDJUSDTJOE).orb0() == VAL_JOE) UNIV2LPOracle(VAL_TDJUSDTJOE).link(0, NEW_VAL_JOE);
		else
		if (UNIV2LPOracle(VAL_TDJUSDTJOE).orb1() == VAL_JOE) UNIV2LPOracle(VAL_TDJUSDTJOE).link(1, NEW_VAL_JOE);

		ChainLog(CHANGELOG).setAddress("PIP_JOE", NEW_VAL_JOE);

		emit ReplaceAddress(VAL_JOE, NEW_VAL_JOE);
	}

	function fixMCD_JOIN_STKJtoken_A(address MCD_JOIN_STKJtoken_A, bytes32 _name) internal
	{
		address _vat = address(GemJoin(MCD_JOIN_STKJtoken_A).vat());
		bytes32 _ilk = GemJoin(MCD_JOIN_STKJtoken_A).ilk();
		address _gem = address(GemJoin(MCD_JOIN_STKJtoken_A).gem());

		GemJoin(MCD_JOIN_STKJtoken_A).cage();
		Vat(MCD_VAT).deny(MCD_JOIN_STKJtoken_A);

		IlkRegistry(ILK_REGISTRY).remove(_ilk);

		address NEW_MCD_JOIN_STKJtoken_A = address(new GemJoin5(_vat, _ilk, _gem));
		Vat(MCD_VAT).rely(NEW_MCD_JOIN_STKJtoken_A);

		IlkRegistry(ILK_REGISTRY).add(NEW_MCD_JOIN_STKJtoken_A);

		ChainLog(CHANGELOG).setAddress(_name, NEW_MCD_JOIN_STKJtoken_A);

		emit ReplaceAddress(MCD_JOIN_STKJtoken_A, NEW_MCD_JOIN_STKJtoken_A);
	}

	event ReplaceAddress(address _old, address _new);
}
