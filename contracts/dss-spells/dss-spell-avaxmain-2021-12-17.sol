// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";
import { CollateralOpts } from "../dss-exec-lib/CollateralOpts.sol";

import { DSValue } from "../ds-value/value.sol";
import { AuthGemJoin } from "../dss-gem-joins/join-auth.sol";
import { Clipper } from "../dss/clip.sol";
import { StairstepExponentialDecrease } from "../dss/abaci.sol";
import { DssPsm } from "../dss-psm/psm.sol";

library LibDssSpell_avaxmain_2021_12_17
{
	function newDSValue() public returns (address _dsValue)
	{
		return address(new DSValue());
	}

	function newStairstepExponentialDecrease() public returns (address _calc)
	{
		return address(new StairstepExponentialDecrease());
	}

	function newAuthGemJoin(address _vat, bytes32 _ilk, address _gem) public returns (address _authGemJoin)
	{
		return address(new AuthGemJoin(_vat, _ilk, _gem));
	}

	function newDssPsm(address _gemJoin, address _daiJoin, address _vow) public returns (address _dssPsm)
	{
		return address(new DssPsm(_gemJoin, _daiJoin, _vow));
	}
}

contract DssSpellAction_avaxmain_2021_12_17 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20December%2017%2C%202021.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2021-12-17 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MULTISIG = 0x6F926fFBe338218b06D2FC26eC59b52Fd5b125cE; // GrowthDeFi multisig on Avalanche

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.1");

		// ----- INCREASES TIN AND ZEROS TOUT FOR OLD PSM -----

		{
			address MCD_PSM_STKUSDC_A = DssExecLib.getChangelogAddress("MCD_PSM_STKUSDC_A");
			DssPsm _dssPsm = DssPsm(MCD_PSM_STKUSDC_A);
			_dssPsm.file("tin", 3e15); // 0.3%
			_dssPsm.file("tout", 0); // 0%
		}

		// ----- ADDS A NEW COLLATERAL AND PSM STKUSDLP -----

		{
			bytes32 _ilk = "PSM-STKUSDLP-A";
			address T_PSM_STKUSDLP = 0x88Cc23286f1356EB0163Ad5bdbFa639416e4168d;
			address INJECTOR_PSM_STKUSDLP = 0x4EcD4082C1E809D89901cD3A802409c8d2Ae6EC4;

			address MCD_VAT = DssExecLib.vat();
			address MCD_JOIN_DAI = DssExecLib.daiJoin();
			address MCD_VOW = DssExecLib.vow();
			address MCD_SPOT = DssExecLib.spotter();
			address MCD_DOG = DssExecLib.dog();

			// deploys components
			address PIP_PSM_STKUSDLP = LibDssSpell_avaxmain_2021_12_17.newDSValue();
			address MCD_CLIP_CALC_PSM_STKUSDLP_A = LibDssSpell_avaxmain_2021_12_17.newStairstepExponentialDecrease();
			address MCD_CLIP_PSM_STKUSDLP_A = address(new Clipper(MCD_VAT, MCD_SPOT, MCD_DOG, _ilk));
			address MCD_JOIN_PSM_STKUSDLP_A = LibDssSpell_avaxmain_2021_12_17.newAuthGemJoin(MCD_VAT, _ilk, T_PSM_STKUSDLP);
			address MCD_PSM_STKUSDLP_A = LibDssSpell_avaxmain_2021_12_17.newDssPsm(MCD_JOIN_PSM_STKUSDLP_A, MCD_JOIN_DAI, MCD_VOW);

			// update oracle price
			DSValue(PIP_PSM_STKUSDLP).poke(bytes32(uint256(1e18)));

			// configures the calc
			DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_PSM_STKUSDLP_A, 120, 9900); 

			// wires and configure the new collateral
			CollateralOpts memory co;
			co.ilk = _ilk;
			co.gem = T_PSM_STKUSDLP;
			co.join = MCD_JOIN_PSM_STKUSDLP_A;
			co.clip = MCD_CLIP_PSM_STKUSDLP_A;
			co.calc = MCD_CLIP_CALC_PSM_STKUSDLP_A;
			co.pip = PIP_PSM_STKUSDLP;
			co.isLiquidatable = true;
			co.isOSM = false;
			co.whitelistOSM = false;
			co.liquidationRatio = 10000; // mat
			co.ilkDebtCeiling = 10000; // line (will go to 100M afterwards)
			co.minVaultAmount = 0; // dust
			co.ilkStabilityFee = 1e27; // duty
			co.liquidationPenalty = 1300; // chop
			co.maxLiquidationAmount = 0; // hole
			co.kprPctReward = 10; // chip
			co.kprFlatReward = 300; // tip
			co.startingPriceFactor = 10500; // buf
			co.auctionDuration = 13200; // tail
			co.permittedDrop = 9000; // cusp
			co.breakerTolerance = 9500; // cm_tolerance
			DssExecLib.addNewCollateral(co);

			// configures the psm
			DssPsm _dssPsm = DssPsm(MCD_PSM_STKUSDLP_A);
			_dssPsm.file("tin", 1e15); // 0.1%
			_dssPsm.file("tout", 0); // 0%
			_dssPsm.donor(T_PSM_STKUSDLP, true);
			_dssPsm.donor(INJECTOR_PSM_STKUSDLP, true);

			// authorizes the psm
			DssExecLib.authorize(MCD_JOIN_PSM_STKUSDLP_A, MCD_PSM_STKUSDLP_A);

			// updates change log
			DssExecLib.setChangelogAddress("PSM-STKUSDLP", T_PSM_STKUSDLP);
			DssExecLib.setChangelogAddress("PIP_PSM_STKUSDLP", PIP_PSM_STKUSDLP);
			DssExecLib.setChangelogAddress("MCD_JOIN_PSM_STKUSDLP_A", MCD_JOIN_PSM_STKUSDLP_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_PSM_STKUSDLP_A", MCD_CLIP_PSM_STKUSDLP_A);
			DssExecLib.setChangelogAddress("MCD_CLIP_CALC_PSM_STKUSDLP_A", MCD_CLIP_CALC_PSM_STKUSDLP_A);
			DssExecLib.setChangelogAddress("MCD_PSM_STKUSDLP_A", MCD_PSM_STKUSDLP_A);
		}

		// ----- SETS STKTDJAVAXDAI-A STABILITY FEE TO 5% -----

		{
			DssExecLib.setIlkStabilityFee("STKTDJAVAXDAI-A", 1000000001547125871859122981, true); // duty 5%
		}

		// ----- SURPLUS WITHDRAWAL OF 142,491 MOR -----

		{
			address MCD_JOIN_DAI = DssExecLib.daiJoin();
			DssExecLib.delegateVat(MCD_JOIN_DAI);
			DssExecLib.sendPaymentFromSurplusBuffer(MULTISIG, 142491); // 142,491 MOR
			DssExecLib.undelegateVat(MCD_JOIN_DAI);
		}
	}
}

// valid for 30 days
contract DssSpell_avaxmain_2021_12_17 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2021_12_17()))
{
}
