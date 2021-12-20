// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { DssDeploy } from "../DssDeploy.sol";
import { Clipper } from "../dss/clip.sol";
import { DSValue } from "../ds-value/value.sol";
import { DssPsm } from "../dss-psm/psm.sol";
import { AuthGemJoin } from "../dss-gem-joins/join-auth.sol";
import { StairstepExponentialDecrease } from "../dss/abaci.sol";
import { IlkRegistry } from "../ilk-registry/IlkRegistry.sol";

contract DssSpellAction_avaxmain_2021_12_17 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20December%2017%2C%202021.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2021-12-17 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MULTISIG = 0x392681Eaf8AD9BC65e74BE37Afe7503D92802b7d; // GrowthDeFi multisig on BSC

	address public MCD_DEPLOY;
	address public MCD_VAT;
	address public MCD_SPOT;
	address public MCD_JOIN_DAI;
	address public MCD_JUG;
	address public MCD_VOW;
	address public MCD_DOG;
	address public CLIPPER_MOM;
	address public ILK_REGISTRY;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.1");

		deployNewPSM();

		DssExecLib.sendPaymentFromSurplusBuffer(MULTISIG, 142491); // 142,491k MOR
	}

	function deployNewPSM() internal
	{
		MCD_DEPLOY = DssExecLib.getChangelogAddress("MCD_DEPLOY");
		MCD_VAT = DssExecLib.vat();
		MCD_SPOT = DssExecLib.spotter();
		MCD_JOIN_DAI = DssExecLib.daiJoin();
		MCD_JUG = DssExecLib.jug();
		MCD_VOW = DssExecLib.vow();
		MCD_DOG = DssExecLib.dog();
		CLIPPER_MOM = DssExecLib.clipperMom();
		ILK_REGISTRY = DssExecLib.reg();

		bytes32 _ilk = "PSM-STKUSDLP-A";
		address T_PSM_STKUSDLP = 0x88Cc23286f1356EB0163Ad5bdbFa639416e4168d;
		address PSM_STKUSDLP_INJECTOR = 0x4EcD4082C1E809D89901cD3A802409c8d2Ae6EC4;

		address PIP_PSM_STKUSDLP = address(new DSValue());
		address MCD_JOIN_PSM_STKUSDLP_A = address(new AuthGemJoin(MCD_VAT, _ilk, T_PSM_STKUSDLP));
		address MCD_CLIP_CALC_PSM_STKUSDLP_A = address(new StairstepExponentialDecrease());

		Clipper _clipper;
		address MCD_CLIP_PSM_STKUSDLP_A;
		{
			DssExecLib.authorize(MCD_VAT, MCD_DEPLOY);
			DssExecLib.authorize(MCD_DOG, MCD_DEPLOY);
			DssExecLib.authorize(MCD_JUG, MCD_DEPLOY);
			DssExecLib.authorize(MCD_SPOT, MCD_DEPLOY);

			DssDeploy _dssDeploy = DssDeploy(MCD_DEPLOY);
			_dssDeploy.deployCollateralClip(_ilk, MCD_JOIN_PSM_STKUSDLP_A, PIP_PSM_STKUSDLP, MCD_CLIP_CALC_PSM_STKUSDLP_A);
			(, _clipper,) = _dssDeploy.ilks(_ilk);
			MCD_CLIP_PSM_STKUSDLP_A = address(_clipper);

			_dssDeploy.releaseAuthClip(_ilk);

			DssExecLib.deauthorize(MCD_VAT, MCD_DEPLOY);
			DssExecLib.deauthorize(MCD_DOG, MCD_DEPLOY);
			DssExecLib.deauthorize(MCD_JUG, MCD_DEPLOY);
			DssExecLib.deauthorize(MCD_SPOT, MCD_DEPLOY);
		}

		address MCD_PSM_STKUSDLP_A;
		{
			DssPsm _dssPsm = new DssPsm(MCD_JOIN_PSM_STKUSDLP_A, MCD_JOIN_DAI, MCD_VOW);
			MCD_PSM_STKUSDLP_A = address(_dssPsm);
			_dssPsm.file("tin", 1e15); // 0.001%
			_dssPsm.file("tout", 0); // 0%
			_dssPsm.donor(T_PSM_STKUSDLP, true);
			_dssPsm.donor(PSM_STKUSDLP_INJECTOR, true);
		}
		DssExecLib.authorize(MCD_JOIN_PSM_STKUSDLP_A, MCD_PSM_STKUSDLP_A);

		DSValue(PIP_PSM_STKUSDLP).poke(bytes32(uint256(1e18))); // review

		DssExecLib.setIlkLiquidationRatio(_ilk, 10000);
		DssExecLib.setIlkDebtCeiling(_ilk, 100000000);
		DssExecLib.setIlkMinVaultAmount(_ilk, 0);
		DssExecLib.setIlkStabilityFee(_ilk, 1e27, true);
		DssExecLib.updateCollateralPrice(_ilk);
		DssExecLib.setIlkLiquidationPenalty(_ilk, 1300);
		DssExecLib.setIlkMaxLiquidationAmount(_ilk, 0);
		DssExecLib.setKeeperIncentivePercent(_ilk, 10);
		DssExecLib.setKeeperIncentiveFlatRate(_ilk, 300);
		DssExecLib.setStartingPriceMultiplicativeFactor(_ilk, 10500);
		DssExecLib.setAuctionTimeBeforeReset(_ilk, 13200);
		DssExecLib.setAuctionPermittedDrop(_ilk, 9000);
		DssExecLib.setStairstepExponentialDecrease(MCD_CLIP_CALC_PSM_STKUSDLP_A, 120, 9900); 

		DssExecLib.authorize(MCD_CLIP_PSM_STKUSDLP_A, CLIPPER_MOM);
		DssExecLib.setLiquidationBreakerPriceTolerance(MCD_CLIP_PSM_STKUSDLP_A, 9500);

		IlkRegistry(ILK_REGISTRY).add(MCD_JOIN_PSM_STKUSDLP_A);

		DssExecLib.setChangelogAddress("PSM-STKUSDLP", T_PSM_STKUSDLP);
		DssExecLib.setChangelogAddress("PIP_PSM_STKUSDLP", PIP_PSM_STKUSDLP);
		DssExecLib.setChangelogAddress("MCD_JOIN_PSM_STKUSDLP_A", MCD_JOIN_PSM_STKUSDLP_A);
		DssExecLib.setChangelogAddress("MCD_CLIP_PSM_STKUSDLP_A", MCD_CLIP_PSM_STKUSDLP_A);
		DssExecLib.setChangelogAddress("MCD_CLIP_CALC_PSM_STKUSDLP_A", MCD_CLIP_CALC_PSM_STKUSDLP_A);
		DssExecLib.setChangelogAddress("MCD_PSM_STKUSDLP_A", MCD_PSM_STKUSDLP_A);
	}
}

// valid for 30 days
contract DssSpell_avaxmain_2021_12_17 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2021_12_17()))
{
}
