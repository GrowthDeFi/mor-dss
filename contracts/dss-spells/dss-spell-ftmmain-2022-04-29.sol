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
import { UniV2TwapOracle } from "../univ2-twap-oracle/univ2-twap-oracle.sol";
import { UNIV2LPOracle } from "../univ2-lp-oracle/UNIV2LPOracle.sol";
import { VaultOracle } from "../vault-oracle/vault-oracle.sol";

library LibDssSpell_ftmmain_2022_04_29_A
{
	function newClipper(address _vat, address _spotter, address _dog, bytes32 _ilk) public returns (address _clipper)
	{
		return address(new Clipper(_vat, _spotter, _dog, _ilk));
	}

	function newStairstepExponentialDecrease() public returns (address _calc)
	{
		return address(new StairstepExponentialDecrease());
	}

	function newGemJoin(address _vat, bytes32 _ilk, address _gem) public returns (address _authGemJoin)
	{
		return address(new GemJoin(_vat, _ilk, _gem));
	}
}

library LibDssSpell_ftmmain_2022_04_29_B
{
	function newUNIV2LPOracle(address _src, bytes32 _wat, address _orb0, address _orb1) public returns (address _oracle)
	{
		return address(new UNIV2LPOracle(_src, _wat, _orb0, _orb1));
	}
}

library LibDssSpell_ftmmain_2022_04_29_C
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

contract DssSpellAction_ftmmain_2022_04_29 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20April%2029%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-04-29 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.1");

		// ----- ADDS A NEW COLLATERAL STKSPOUSDCDEI -----

		{
			bytes32 _ilk = "STKSPOUSDCDEI-A";
			address T_STKSPOUSDCDEI = 0x1DE2bC09527Aa3F6a3Aa35271471966b2dd4E215;

			address MCD_CLIP_STKSPOUSDCDEI_A;
			address MCD_JOIN_STKSPOUSDCDEI_A;
			address MCD_CLIP_CALC_STKSPOUSDCDEI_A;
			{
				address MCD_VAT = DssExecLib.vat();
				address MCD_SPOT = DssExecLib.spotter();
				address MCD_DOG = DssExecLib.dog();

				MCD_CLIP_STKSPOUSDCDEI_A = LibDssSpell_ftmmain_2022_04_29_A.newClipper(MCD_VAT, MCD_SPOT, MCD_DOG, _ilk);
				MCD_JOIN_STKSPOUSDCDEI_A = LibDssSpell_ftmmain_2022_04_29_A.newGemJoin(MCD_VAT, _ilk, T_STKSPOUSDCDEI);
				MCD_CLIP_CALC_STKSPOUSDCDEI_A = LibDssSpell_ftmmain_2022_04_29_A.newStairstepExponentialDecrease();
			}

			address T_DEI = 0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3;
			address T_SPOUSDCDEI = 0xD343b8361Ce32A9e570C1fC8D4244d32848df88B;
			address PIP_USDC = 0x8BBcd7E4da4395E391Fbfc2A11775debe3ca0D58;
			address STWAP = 0x2e5a83cE42F9887E222813371c5cA2bA1e827700;
			address LTWAP = 0x292b138C6785BB7a6e7EE2acB3Cea792aD9f7F2E;

			address PIP_DEI = LibDssSpell_ftmmain_2022_04_29_C.newUniV2TwapOracle(STWAP, LTWAP, T_SPOUSDCDEI, T_DEI, 1e18, PIP_USDC);
			address PIP_SPOUSDCDEI = LibDssSpell_ftmmain_2022_04_29_B.newUNIV2LPOracle(T_SPOUSDCDEI, "SPOUSDCDEI", PIP_USDC, PIP_DEI);
			address PIP_STKSPOUSDCDEI = LibDssSpell_ftmmain_2022_04_29_C.newVaultOracle(T_STKSPOUSDCDEI, T_SPOUSDCDEI, PIP_SPOUSDCDEI);

			// update oracle price
			//DSValue(PIP_PSM_STKUSDLP).poke(bytes32(uint256(1e18)));

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_STKSPOUSDCDEI_A, 180, 9900);

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
			co.liquidationRatio = 11100; // mat
			co.ilkDebtCeiling = 500000; // line
			co.minVaultAmount = 100; // dust
			co.ilkStabilityFee = 0; // duty
			co.liquidationPenalty = 500; // chop
			co.maxLiquidationAmount = 100000000; // hole
			co.kprPctReward = 0; // chip
			co.kprFlatReward = 5; // tip
			co.startingPriceFactor = 13000; // buf
			co.auctionDuration = 16800; // tail
			co.permittedDrop = 4000; // cusp
			co.breakerTolerance = 5000; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// updates change log
			DssExecLib.setChangelogAddress("STKSPOUSDCDEI", T_STKSPOUSDCDEI);
			DssExecLib.setChangelogAddress("PIP_STKSPOUSDCDEI", PIP_STKSPOUSDCDEI);
			DssExecLib.setChangelogAddress("MCD_JOIN_STKSPOUSDCDEI_A", MCD_JOIN_STKSPOUSDCDEI_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_STKSPOUSDCDEI_A", MCD_CLIP_STKSPOUSDCDEI_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_STKSPOUSDCDEI_A", MCD_CLIP_CALC_STKSPOUSDCDEI_A);
		}
	}
}

// valid for 30 days
contract DssSpell_ftmmain_2022_04_29 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_ftmmain_2022_04_29()))
{
}
