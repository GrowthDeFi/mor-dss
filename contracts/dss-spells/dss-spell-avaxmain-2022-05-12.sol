// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_avaxmain_2022_05_12 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20May%2012%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-05-12 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.3");

		// ----- SETS DEBT CEILING TO 0 AND STABILITY FEE TO 10% FOR ALL ILKS
		{
			uint256 _10PERCENT = 1000000003022265980097387651; // duty 10%
			DssExecLib.setIlkDebtCeiling("STKXJOE-A", 0);
			DssExecLib.setIlkStabilityFee("STKXJOE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKJAVAX-A", 0);
			DssExecLib.setIlkStabilityFee("STKJAVAX-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKJWETH-A", 0);
			DssExecLib.setIlkStabilityFee("STKJWETH-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKJWBTC-A", 0);
			DssExecLib.setIlkStabilityFee("STKJWBTC-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKJLINK-A", 0);
			DssExecLib.setIlkStabilityFee("STKJLINK-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXJOE-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXJOE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXWETH-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXWETH-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXWBTC-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXWBTC-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXDAI-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXDAI-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXUSDC-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXUSDC-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXUSDT-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXUSDT-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXLINK-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXLINK-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJAVAXMIM-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJAVAXMIM-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJUSDCJOE-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJUSDCJOE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKTDJUSDTJOE-A", 0);
			DssExecLib.setIlkStabilityFee("STKTDJUSDTJOE-A", _10PERCENT, true);
		}
	}
}

// valid for 30 days
contract DssSpell_avaxmain_2022_05_12 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2022_05_12()))
{
}
