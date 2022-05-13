// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";
import { CollateralOpts } from "../dss-exec-lib/CollateralOpts.sol";

import { Clipper } from "../dss/clip.sol";
import { GemJoin } from "../dss/join.sol";
import { StairstepExponentialDecrease } from "../dss/abaci.sol";
import { LinkOracle } from "../link-oracle/link-oracle.sol";
import { UniV2TwapOracle } from "../univ2-twap-oracle/univ2-twap-oracle.sol";
import { UNIV2LPOracle } from "../univ2-lp-oracle/UNIV2LPOracle.sol";
import { VaultOracle } from "../vault-oracle/vault-oracle.sol";
import { RateCapOracle } from "../ratecap-oracle/ratecap-oracle.sol";

library LibDssSpell_ftmmain_2022_05_05_A
{
	function newClipper(address _vat, address _spotter, address _dog, bytes32 _ilk) public returns (address _clipper)
	{
		return address(new Clipper(_vat, _spotter, _dog, _ilk));
	}

	function newGemJoin(address _vat, bytes32 _ilk, address _gem) public returns (address _authGemJoin)
	{
		return address(new GemJoin(_vat, _ilk, _gem));
	}
}

library LibDssSpell_ftmmain_2022_05_05_B
{
	function newStairstepExponentialDecrease() public returns (address _calc)
	{
		return address(new StairstepExponentialDecrease());
	}

	function newUNIV2LPOracle(address _src, bytes32 _wat, address _orb0, address _orb1) public returns (address _oracle)
	{
		return address(new UNIV2LPOracle(_src, _wat, _orb0, _orb1));
	}
}

library LibDssSpell_ftmmain_2022_05_05_C
{
	function newUniV2TwapOracle(address _stwap, address _ltwap, address _src, address _token, uint256 _cap, address _orb) public returns (address _oracle)
	{
		return address(new UniV2TwapOracle(_stwap, _ltwap, _src, _token, _cap, _orb));
	}

	function newVaultOracle(address _vault, address _reserve, address _orb) public returns (address _oracle)
	{
		return address(new VaultOracle(_vault, _reserve, _orb));
	}
}

library LibDssSpell_ftmmain_2022_05_05_D
{
	address constant POKEBOT = 0x0B640b3E91420B495a33d11Ee96AFb19bE2Db693;

	function newRateCapOracle(address _src, address _cap, address _orb) public returns (address _oracle)
	{
		return address(new RateCapOracle(_src, _cap, _orb));
	}

	function _deployVaultComponents(bytes32 _ilk, address _token, address _tokenr, address _pipr) public returns (address _pip, address _join, address _clip, address _calc)
	{
		_pip = LibDssSpell_ftmmain_2022_05_05_C.newVaultOracle(_token, _tokenr, _pipr);
		_join = LibDssSpell_ftmmain_2022_05_05_A.newGemJoin(DssExecLib.vat(), _ilk, _token);
		_clip = LibDssSpell_ftmmain_2022_05_05_A.newClipper(DssExecLib.vat(), DssExecLib.spotter(), DssExecLib.dog(), _ilk);
		_calc = LibDssSpell_ftmmain_2022_05_05_B.newStairstepExponentialDecrease();
		return (_pip, _join, _clip, _calc);
	}

	function _deployCapComponents(bytes32 _ilk, address _token, address _rate, address _rate_cap, address _pipr) public returns (address _pip, address _join, address _clip, address _calc)
	{
		_pip = newRateCapOracle(_rate, _rate_cap, _pipr);
		_join = LibDssSpell_ftmmain_2022_05_05_A.newGemJoin(DssExecLib.vat(), _ilk, _token);
		_clip = LibDssSpell_ftmmain_2022_05_05_A.newClipper(DssExecLib.vat(), DssExecLib.spotter(), DssExecLib.dog(), _ilk);
		_calc = LibDssSpell_ftmmain_2022_05_05_B.newStairstepExponentialDecrease();
		return (_pip, _join, _clip, _calc);
	}

	function _configureTwapOracle(address _pip) public
	{
		UniV2TwapOracle(_pip).kiss(POKEBOT);
		UniV2TwapOracle(_pip).poke();
		UniV2TwapOracle(_pip).kiss(DssExecLib.spotter());
		UniV2TwapOracle(_pip).kiss(DssExecLib.end());
		LinkOracle(UniV2TwapOracle(_pip).orb()).kiss(_pip);
	}

	function _configurePoolOracle(address _pip) public
	{
		UNIV2LPOracle(_pip).step(3600 seconds);
		UNIV2LPOracle(_pip).kiss(POKEBOT);
		UNIV2LPOracle(_pip).kiss(DssExecLib.spotter());
		UNIV2LPOracle(_pip).kiss(DssExecLib.end());
		UniV2TwapOracle(UNIV2LPOracle(_pip).orb0()).kiss(_pip);
		UniV2TwapOracle(UNIV2LPOracle(_pip).orb1()).kiss(_pip);
	}

	function _configureVaultOracle(address _pip, address _clip) public
	{
		VaultOracle(_pip).kiss(POKEBOT);
		VaultOracle(_pip).kiss(DssExecLib.spotter());
		VaultOracle(_pip).kiss(DssExecLib.end());
		if (_clip != address(0)) {
			VaultOracle(_pip).kiss(_clip);
			VaultOracle(_pip).kiss(DssExecLib.clipperMom());
		}
		UNIV2LPOracle(UniV2TwapOracle(_pip).orb()).kiss(_pip);
	}

	function _configureCapOracle(address _pip, address _clip) public
	{
		RateCapOracle(_pip).step(3600 seconds);
		RateCapOracle(_pip).kiss(POKEBOT);
		RateCapOracle(_pip).kiss(DssExecLib.spotter());
		RateCapOracle(_pip).kiss(DssExecLib.end());
		if (_clip != address(0)) {
			RateCapOracle(_pip).kiss(_clip);
			RateCapOracle(_pip).kiss(DssExecLib.clipperMom());
		}
		UniV2TwapOracle(RateCapOracle(_pip).orb()).kiss(_pip);
	}
}

contract DssSpellAction_ftmmain_2022_05_05 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20May%205%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-05-05 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant T_XBOO = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;
	address constant T_XBOO_SRC = 0xC34A9A80CfFCe827c3bD234922782c51e7af9C8C;
	address constant T_STKXBOO = 0x30463d33735677B4E70f956e3dd61c6e94D70DFe;

	address constant T_STKSPOFTMBOOV2 = 0xaebd31E9FFcB222feE947f22369257cEcf1F96CA;

	address constant T_DEI = 0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3;
	address constant T_SPOUSDCDEI = 0xD343b8361Ce32A9e570C1fC8D4244d32848df88B;
	address constant T_STKSPOUSDCDEI = 0x1DE2bC09527Aa3F6a3Aa35271471966b2dd4E215;

	address constant T_DEUS = 0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44;
	address constant T_SPOFTMDEUS = 0xaF918eF5b9f33231764A5557881E6D3e5277d456;
	address constant T_STKSPOFTMDEUS = 0xDE98dFbFCa4Bce256AF0b9Aa7664051a6B414548;

	address constant T_LQDR = 0x10b620b2dbAC4Faa7D7FFD71Da486f5D44cd86f9;
	address constant T_CLQDR = 0x814c66594a22404e101FEcfECac1012D8d75C156;
	address constant RATE_CLQDR_LQDR = 0x153f6Ce9e1b49d8535aac45DB917465E1386F175;
	address constant RATE_CLQDR_PERP = 0x1A148871bf262451F34f13CBCb7917b4FE59cB32;

	address constant T_SPIRIT = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B;
	address constant T_LINSPIRIT = 0xc5713B6a0F26bf0fdC1c52B90cd184D950be515C;
	address constant T_SLINSPIRIT = 0x3F569724ccE63F7F24C5F921D5ddcFe125Add96b;
	address constant T_SLINSPIRIT_SRC = 0x1Fb01F02E1141F10c3E679bD9B6f87cE737Ff223;
	address constant RATE_LINSPIRIT_SPIRIT = 0xca28403137FF88D58e76184B130133F65256Cd16;
	address constant RATE_UNIT = 0x698a3a40bcB782a491217ed18610F3341Ba9f3a5;

	address constant STWAP = 0x2e5a83cE42F9887E222813371c5cA2bA1e827700;
	address constant LTWAP = 0x292b138C6785BB7a6e7EE2acB3Cea792aD9f7F2E;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.3");

		// ----- ADDS A NEW COLLATERAL STKXBOO -----
		{
			bytes32 _ilk = "STKXBOO-A";

			address T_BOO = DssExecLib.getChangelogAddress("BOO");
			address PIP_BOO = DssExecLib.getChangelogAddress("PIP_BOO");

			// deploys components
			address PIP_XBOO = LibDssSpell_ftmmain_2022_05_05_C.newVaultOracle(T_XBOO_SRC, T_BOO, PIP_BOO);
			(
				address PIP_STKXBOO,
				address MCD_JOIN_STKXBOO_A,
				address MCD_CLIP_STKXBOO_A,
				address MCD_CLIP_CALC_STKXBOO_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployVaultComponents(_ilk, T_STKXBOO, T_XBOO, PIP_XBOO);

			// configures PIP_XBOO
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_XBOO, address(0));

			// configures PIP_STKXBOO
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_STKXBOO, MCD_CLIP_STKXBOO_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKXBOO_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_STKXBOO_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_STKXBOO;
			co.join = MCD_JOIN_STKXBOO_A;
			co.clip = MCD_CLIP_STKXBOO_A;
			co.calc = MCD_CLIP_CALC_STKXBOO_A;
			co.pip = PIP_STKXBOO;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 167_00; // mat
			co.ilkDebtCeiling = 500000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1e27; // duty 0%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("XBOO", T_XBOO);
			DssExecLib.setChangelogAddress("PIP_XBOO", PIP_XBOO);

			DssExecLib.setChangelogAddress("STKXBOO", T_STKXBOO);
			DssExecLib.setChangelogAddress("PIP_STKXBOO", PIP_STKXBOO);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKXBOO_A", MCD_JOIN_STKXBOO_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKXBOO_A", MCD_CLIP_STKXBOO_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKXBOO_A", MCD_CLIP_CALC_STKXBOO_A);
		}

		// ----- ADDS A NEW COLLATERAL STKSPOFTMBOOV2 -----
		{
			bytes32 _ilk = "STKSPOFTMBOOV2-A";

			address T_SPOFTMBOO = DssExecLib.getChangelogAddress("SPOFTMBOO");
			address PIP_SPOFTMBOO = DssExecLib.getChangelogAddress("PIP_SPOFTMBOO");

			// deploys components
			(
				address PIP_STKSPOFTMBOOV2,
				address MCD_JOIN_STKSPOFTMBOOV2_A,
				address MCD_CLIP_STKSPOFTMBOOV2_A,
				address MCD_CLIP_CALC_STKSPOFTMBOOV2_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployVaultComponents(_ilk, T_STKSPOFTMBOOV2, T_SPOFTMBOO, PIP_SPOFTMBOO);

			// configures PIP_STKSPOFTMBOOV2
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_STKSPOFTMBOOV2, MCD_CLIP_STKSPOFTMBOOV2_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKSPOFTMBOOV2_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_STKSPOFTMBOOV2_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_STKSPOFTMBOOV2;
			co.join = MCD_JOIN_STKSPOFTMBOOV2_A;
			co.clip = MCD_CLIP_STKSPOFTMBOOV2_A;
			co.calc = MCD_CLIP_CALC_STKSPOFTMBOOV2_A;
			co.pip = PIP_STKSPOFTMBOOV2;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 167_00; // mat
			co.ilkDebtCeiling = 500000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1e27; // duty 0%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("STKSPOFTMBOOV2", T_STKSPOFTMBOOV2);
			DssExecLib.setChangelogAddress("PIP_STKSPOFTMBOOV2", PIP_STKSPOFTMBOOV2);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKSPOFTMBOOV2_A", MCD_JOIN_STKSPOFTMBOOV2_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKSPOFTMBOOV2_A", MCD_CLIP_STKSPOFTMBOOV2_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKSPOFTMBOOV2_A", MCD_CLIP_CALC_STKSPOFTMBOOV2_A);
		}

		// ----- ADDS A NEW COLLATERAL STKSPOUSDCDEI -----
		{
			bytes32 _ilk = "STKSPOUSDCDEI-A";

			address PIP_USDC = DssExecLib.getChangelogAddress("PIP_USDC");

			// deploys components
			address PIP_DEI = LibDssSpell_ftmmain_2022_05_05_C.newUniV2TwapOracle(STWAP, LTWAP, T_SPOUSDCDEI, T_DEI, 1e18, PIP_USDC);
			address PIP_SPOUSDCDEI = LibDssSpell_ftmmain_2022_05_05_B.newUNIV2LPOracle(T_SPOUSDCDEI, "SPOUSDCDEI", PIP_USDC, PIP_DEI);
			(
				address PIP_STKSPOUSDCDEI,
				address MCD_JOIN_STKSPOUSDCDEI_A,
				address MCD_CLIP_STKSPOUSDCDEI_A,
				address MCD_CLIP_CALC_STKSPOUSDCDEI_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployVaultComponents(_ilk, T_STKSPOUSDCDEI, T_SPOUSDCDEI, PIP_SPOUSDCDEI);

			// configures PIP_DEI
			LibDssSpell_ftmmain_2022_05_05_D._configureTwapOracle(PIP_DEI);

			// configures PIP_SPOUSDCDEI
			LibDssSpell_ftmmain_2022_05_05_D._configurePoolOracle(PIP_SPOUSDCDEI);

			// configures PIP_STKSPOUSDCDEI
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_STKSPOUSDCDEI, MCD_CLIP_STKSPOUSDCDEI_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKSPOUSDCDEI_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_STKSPOUSDCDEI_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_STKSPOUSDCDEI;
			co.join = MCD_JOIN_STKSPOUSDCDEI_A;
			co.clip = MCD_CLIP_STKSPOUSDCDEI_A;
			co.calc = MCD_CLIP_CALC_STKSPOUSDCDEI_A;
			co.pip = PIP_STKSPOUSDCDEI;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 133_00; // mat
			co.ilkDebtCeiling = 500000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1e27; // duty 0%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("DEI", T_DEI);
			DssExecLib.setChangelogAddress("PIP_DEI", PIP_DEI);

			DssExecLib.setChangelogAddress("SPOUSDCDEI", T_SPOUSDCDEI);
			DssExecLib.setChangelogAddress("PIP_SPOUSDCDEI", PIP_SPOUSDCDEI);

			DssExecLib.setChangelogAddress("STKSPOUSDCDEI", T_STKSPOUSDCDEI);
			DssExecLib.setChangelogAddress("PIP_STKSPOUSDCDEI", PIP_STKSPOUSDCDEI);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKSPOUSDCDEI_A", MCD_JOIN_STKSPOUSDCDEI_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKSPOUSDCDEI_A", MCD_CLIP_STKSPOUSDCDEI_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKSPOUSDCDEI_A", MCD_CLIP_CALC_STKSPOUSDCDEI_A);
		}

		// ----- ADDS A NEW COLLATERAL STKSPOFTMDEUS -----
		{
			bytes32 _ilk = "STKSPOFTMDEUS-A";

			address PIP_FTM = DssExecLib.getChangelogAddress("PIP_FTM");

			// deploys components
			address PIP_DEUS = LibDssSpell_ftmmain_2022_05_05_C.newUniV2TwapOracle(STWAP, LTWAP, T_SPOFTMDEUS, T_DEUS, 0e18, PIP_FTM);
			address PIP_SPOFTMDEUS = LibDssSpell_ftmmain_2022_05_05_B.newUNIV2LPOracle(T_SPOFTMDEUS, "SPOFTMDEUS", PIP_FTM, PIP_DEUS);
			(
				address PIP_STKSPOFTMDEUS,
				address MCD_JOIN_STKSPOFTMDEUS_A,
				address MCD_CLIP_STKSPOFTMDEUS_A,
				address MCD_CLIP_CALC_STKSPOFTMDEUS_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployVaultComponents(_ilk, T_STKSPOFTMDEUS, T_SPOFTMDEUS, PIP_SPOFTMDEUS);

			// configures PIP_DEUS
			LibDssSpell_ftmmain_2022_05_05_D._configureTwapOracle(PIP_DEUS);

			// configures PIP_SPOFTMDEUS
			LibDssSpell_ftmmain_2022_05_05_D._configurePoolOracle(PIP_SPOFTMDEUS);

			// configures PIP_STKSPOFTMDEUS
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_STKSPOFTMDEUS, MCD_CLIP_STKSPOFTMDEUS_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKSPOFTMDEUS_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_STKSPOFTMDEUS_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_STKSPOFTMDEUS;
			co.join = MCD_JOIN_STKSPOFTMDEUS_A;
			co.clip = MCD_CLIP_STKSPOFTMDEUS_A;
			co.calc = MCD_CLIP_CALC_STKSPOFTMDEUS_A;
			co.pip = PIP_STKSPOFTMDEUS;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 250_00; // mat
			co.ilkDebtCeiling = 300000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1e27; // duty 0%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("DEUS", T_DEUS);
			DssExecLib.setChangelogAddress("PIP_DEUS", PIP_DEUS);

			DssExecLib.setChangelogAddress("SPOFTMDEUS", T_SPOFTMDEUS);
			DssExecLib.setChangelogAddress("PIP_SPOFTMDEUS", PIP_SPOFTMDEUS);

			DssExecLib.setChangelogAddress("STKSPOFTMDEUS", T_STKSPOFTMDEUS);
			DssExecLib.setChangelogAddress("PIP_STKSPOFTMDEUS", PIP_STKSPOFTMDEUS);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKSPOUSDCDEI_A", MCD_JOIN_STKSPOFTMDEUS_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKSPOUSDCDEI_A", MCD_CLIP_STKSPOFTMDEUS_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKSPOUSDCDEI_A", MCD_CLIP_CALC_STKSPOFTMDEUS_A);
		}

		// ----- ADDS A NEW COLLATERAL CLQDR -----
		{
			bytes32 _ilk = "CLQDR-A";

			address PIP_LQDR = DssExecLib.getChangelogAddress("PIP_LQDR");

			// deploys components
			(
				address PIP_CLQDR,
				address MCD_JOIN_CLQDR_A,
				address MCD_CLIP_CLQDR_A,
				address MCD_CLIP_CALC_CLQDR_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployCapComponents(_ilk, T_CLQDR, RATE_CLQDR_LQDR, RATE_CLQDR_PERP, PIP_LQDR);

			// configures PIP_CLQDR
			LibDssSpell_ftmmain_2022_05_05_D._configureCapOracle(PIP_CLQDR, MCD_CLIP_CLQDR_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_CLQDR_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_CLQDR_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_CLQDR;
			co.join = MCD_JOIN_CLQDR_A;
			co.clip = MCD_CLIP_CLQDR_A;
			co.calc = MCD_CLIP_CALC_CLQDR_A;
			co.pip = PIP_CLQDR;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 200_00; // mat
			co.ilkDebtCeiling = 80000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1e27; // duty 0%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("CLQDR", T_CLQDR);
			DssExecLib.setChangelogAddress("PIP_CLQDR", PIP_CLQDR);
			DssExecLib.setChangelogAddress("MCD_JOIN_CLQDR_A", MCD_JOIN_CLQDR_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CLQDR_A", MCD_CLIP_CLQDR_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_CLQDR_A", MCD_CLIP_CALC_CLQDR_A);
		}

		// ----- ADDS A NEW COLLATERAL SLINSPIRIT -----
		{
			bytes32 _ilk = "SLINSPIRIT-A";

			address PIP_SPIRIT = DssExecLib.getChangelogAddress("PIP_SPIRIT");

			// deploys components
			address PIP_LINSPIRIT = LibDssSpell_ftmmain_2022_05_05_D.newRateCapOracle(RATE_LINSPIRIT_SPIRIT, RATE_UNIT, PIP_SPIRIT);
			(
				address PIP_SLINSPIRIT,
				address MCD_JOIN_SLINSPIRIT_A,
				address MCD_CLIP_SLINSPIRIT_A,
				address MCD_CLIP_CALC_SLINSPIRIT_A
			) = LibDssSpell_ftmmain_2022_05_05_D._deployVaultComponents(_ilk, T_SLINSPIRIT_SRC, T_LINSPIRIT, PIP_LINSPIRIT);

			// configures PIP_LINSPIRIT
			LibDssSpell_ftmmain_2022_05_05_D._configureCapOracle(PIP_LINSPIRIT, address(0));

			// configures PIP_SLINSPIRIT
			LibDssSpell_ftmmain_2022_05_05_D._configureVaultOracle(PIP_SLINSPIRIT, MCD_CLIP_SLINSPIRIT_A);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_SLINSPIRIT_A, 180 seconds, 99_00);

			// updates clipper chost
			Clipper(MCD_CLIP_SLINSPIRIT_A).upchost();

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_SLINSPIRIT;
			co.join = MCD_JOIN_SLINSPIRIT_A;
			co.clip = MCD_CLIP_SLINSPIRIT_A;
			co.calc = MCD_CLIP_CALC_SLINSPIRIT_A;
			co.pip = PIP_SLINSPIRIT;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 167_00; // mat
			co.ilkDebtCeiling = 200000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 1000000001547125871859122981; // duty 5%
			co.liquidationPenalty = 15_00; // chop
			co.maxLiquidationAmount = 100000000; // hole
			//co.kprPctReward = 0_00; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 130_00; // buf
			co.auctionDuration = 16800 seconds; // tail
			co.permittedDrop = 40_00; // cusp
			co.breakerTolerance = 50_00; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("LINSPIRIT", T_LINSPIRIT);
			DssExecLib.setChangelogAddress("PIP_LINSPIRIT", PIP_LINSPIRIT);

			DssExecLib.setChangelogAddress("SLINSPIRIT", T_SLINSPIRIT);
			DssExecLib.setChangelogAddress("PIP_SLINSPIRIT", PIP_SLINSPIRIT);
			DssExecLib.setChangelogAddress("MCD_JOIN_SLINSPIRIT_A", MCD_JOIN_SLINSPIRIT_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_SLINSPIRIT_A", MCD_CLIP_SLINSPIRIT_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_SLINSPIRIT_A", MCD_CLIP_CALC_SLINSPIRIT_A);
		}
	}
}

// valid for 30 days
contract DssSpell_ftmmain_2022_05_05 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_ftmmain_2022_05_05()))
{
}
