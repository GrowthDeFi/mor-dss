// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";
import { CollateralOpts } from "../dss-exec-lib/CollateralOpts.sol";
import { UNIV2LPOracle } from "../univ2-lp-oracle/UNIV2LPOracle.sol";
import { UniV2TwapOracle } from "../univ2-twap-oracle/univ2-twap-oracle.sol";

contract DssSpellAction_ftmmain_2022_05_05 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20May%205%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-05-05 GrowthDeFi Executive Spell | Hash: 0xb45c7455ecaf8470c61131c13d2c5c19efdc6e1fa355cccd6e43146452b1daef";

	address constant PIP_BOO = 0x44B0234Eb02443E7B7d1f0EFd9a30eB269E1C859;
	address constant T_XBOO = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;
	address constant PIP_XBOO = 0x8f821768282F867C9EEeFbA8CCdA1ca1888c9F8b;

	address constant T_LINSPIRIT = 0xc5713B6a0F26bf0fdC1c52B90cd184D950be515C;
	address constant PIP_LINSPIRIT = 0x87930d19B4C98DD08B8B30793D4fB38cE9B6451d;

	address constant T_STKXBOO = 0x30463d33735677B4E70f956e3dd61c6e94D70DFe;
	address constant PIP_STKXBOO = 0x5D6892332C3BB313d10d3a50413b4e2B79CF3269;
	address constant MCD_JOIN_STKXBOO_A = 0xcbCFC27be6b2eD4eD261AD0E6212534a08c7B1F6;
	address constant MCD_CLIP_STKXBOO_A = 0x52Ee6fBecDd709AD1936e3241946B786979520A1;
	address constant MCD_CLIP_CALC_STKXBOO_A = 0xaf760e33a3a27F54aC018F780aaE06356b70da86;

	address constant PIP_SPOFTMBOO = 0xca70528209917F4D0443Dd3e90C863b19584CCAF;
	address constant T_STKSPOFTMBOOV2 = 0xaebd31E9FFcB222feE947f22369257cEcf1F96CA;
	address constant PIP_STKSPOFTMBOOV2 = 0xbCe5a62C49fcDfe9f834d40c41692612C8CfcE39;
	address constant MCD_JOIN_STKSPOFTMBOOV2_A = 0x7c414040fDd78c4d37131B1C59d051d56bee8645;
	address constant MCD_CLIP_STKSPOFTMBOOV2_A = 0xe55FB11e8322D663Fc2210c5CA8D85D9774A6d36;
	address constant MCD_CLIP_CALC_STKSPOFTMBOOV2_A = 0xA58E169f1C0503f9e736727A427EBf3a061647C7;

	address constant PIP_LQDR = 0x3d4604395595Bb30A8B7754b5dDBF0B3F680564b;
	address constant T_CLQDR = 0x814c66594a22404e101FEcfECac1012D8d75C156;
	address constant PIP_CLQDR = 0x91EF85162F18c038f0dC1e01a7a2F4191b2c6ce6;
	address constant MCD_JOIN_CLQDR_A = 0xe5fb3D583660e57b1f616f89Ae98dfb6e3c37f99;
	address constant MCD_CLIP_CLQDR_A = 0xBfc0a4714C8de532F5a2E9c20185752a902cD262;
	address constant MCD_CLIP_CALC_CLQDR_A = 0x5559771B806099bBc65867b79F971a2601FedD04;

	address constant PIP_SPIRIT = 0x5F6025D6514C6396D4Ba640d6F93966AF5b139B0;
	address constant T_SLINSPIRIT = 0x3F569724ccE63F7F24C5F921D5ddcFe125Add96b;
	address constant PIP_SLINSPIRIT = 0x6296e0B0dD895a66048022131F85653B0C2C3489;
	address constant MCD_JOIN_SLINSPIRIT_A = 0x726d946BBF3d0E6f9e5078D4F5e1f0014c37288F;
	address constant MCD_CLIP_SLINSPIRIT_A = 0x0e7482C50048628858d54AeC7af097765899a0b6;
	address constant MCD_CLIP_CALC_SLINSPIRIT_A = 0xb03d7418bBa8AFD553b8Fa7AED1fE044eFc52950;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.3");

		// ----- ADDS A NEW COLLATERAL STKXBOO -----
		{
			bytes32 _ilk = "STKXBOO-A";

			UniV2TwapOracle(PIP_BOO).kiss(PIP_XBOO);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKXBOO_A, 180 seconds, 99_00);

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

			// pokes spotter
			DssExecLib.updateCollateralPrice(_ilk);

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

			UNIV2LPOracle(PIP_SPOFTMBOO).kiss(PIP_STKSPOFTMBOOV2);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKSPOFTMBOOV2_A, 180 seconds, 99_00);

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

			// pokes spotter
			DssExecLib.updateCollateralPrice(_ilk);

			// updates change log
			DssExecLib.setChangelogAddress("STKSPOFTMBOOV2", T_STKSPOFTMBOOV2);
			DssExecLib.setChangelogAddress("PIP_STKSPOFTMBOOV2", PIP_STKSPOFTMBOOV2);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKSPOFTMBOOV2_A", MCD_JOIN_STKSPOFTMBOOV2_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKSPOFTMBOOV2_A", MCD_CLIP_STKSPOFTMBOOV2_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKSPOFTMBOOV2_A", MCD_CLIP_CALC_STKSPOFTMBOOV2_A);
		}

		// ----- ADDS A NEW COLLATERAL CLQDR -----
		{
			bytes32 _ilk = "CLQDR-A";

			UniV2TwapOracle(PIP_LQDR).kiss(PIP_CLQDR);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_CLQDR_A, 180 seconds, 99_00);

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

			// pokes spotter
			DssExecLib.updateCollateralPrice(_ilk);

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

			UniV2TwapOracle(PIP_SPIRIT).kiss(PIP_LINSPIRIT);

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_SLINSPIRIT_A, 180 seconds, 99_00);

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

			// pokes spotter
			DssExecLib.updateCollateralPrice(_ilk);

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
