// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { DssAmo } from "../dss-amo/amo.sol";
import { DssPsm } from "../dss-psm/psm.sol";

contract DssSpellAction_ftmmain_2022_04_18 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20April%2018%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-04-18 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MOR_bbyvUSD_AMO = 0x53AAF3c5FC977E2ED7E0e746306Dec3927829AE5;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.0");

		// ----- INSTALLS THE AMO MODULE -----
		{
			address MCD_VAT = DssExecLib.vat();
			address MCD_JOIN_DAI = DssExecLib.daiJoin();
			address MCD_AMO = address(new DssAmo(MCD_JOIN_DAI));
			DssExecLib.authorize(MCD_VAT, MCD_AMO);
			DssExecLib.setChangelogAddress("MCD_AMO", MCD_AMO);
		}

		// ----- ADDS MOR_bbyvUSD_AMO TO THE SYSTEM -----
		{
			address MCD_AMO = DssExecLib.getChangelogAddress("MCD_AMO");
			DssAmo(MCD_AMO).ceil(MOR_bbyvUSD_AMO, 10_000e18); // 10k MOR
		}

		// ----- SETS DEBT CEILING TO 0 AND STABILITY FEE TO 5% FOR ALL ILKS
		{
			uint256 _5PERCENT = 1000000001547125871859122981; // duty 5%
			DssExecLib.setIlkDebtCeiling("STKSPIFTMLQDR-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMLQDR-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMFUSDT-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMFUSDT-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMWBTC-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMWBTC-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMUSDC-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMUSDC-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMWETH-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMWETH-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMMIM-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMMIM-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMSPIRIT-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMSPIRIT-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMFRAX-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMFRAX-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPIFTMMAI-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPIFTMMAI-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMBOO-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMBOO-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMUSDC-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMUSDC-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMDAI-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMDAI-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMSUSHI-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMSUSHI-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMLINK-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMLINK-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMWETH-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMWETH-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMFUSDT-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMFUSDT-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMMIM-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMMIM-A", _5PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKSPOFTMSCREAM-A", 0);
			DssExecLib.setIlkStabilityFee("STKSPOFTMSCREAM-A", _5PERCENT, true);
		}

		// ----- ADJUSTS PSM TIN/TOUT
		{
			address MCD_PSM_STKUSDLP_A = DssExecLib.getChangelogAddress("MCD_PSM_STKUSDLP_A");
			DssPsm _dssPsm = DssPsm(MCD_PSM_STKUSDLP_A);
			_dssPsm.file("tin", 0); // 0%
			_dssPsm.file("tout", 1e15); // 0.1%
		}

		// ----- ADDS A 24-HOUR PAUSE DELAY FOR SPELLS -----
		{
			address _pause = DssExecLib.getChangelogAddress("MCD_PAUSE");
			DSPause(_pause).setDelay(24 hours);
		}
	}
}

// valid for 30 days
contract DssSpell_ftmmain_2022_04_18 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_ftmmain_2022_04_18()))
{
}
