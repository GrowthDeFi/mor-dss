// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_bscmain_2022_05_11 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20May%2011%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-05-11 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.3");

		// ----- SETS DEBT CEILING TO 1mi FOR STKBANANA-A AND STKAPEMORBUSD-A ILKS
		{
			DssExecLib.setIlkDebtCeiling("STKBANANA-A", 1000000);
			DssExecLib.setIlkDebtCeiling("STKAPEMORBUSD-A", 1000000);
		}

		// ----- SETS DEBT CEILING TO 0 AND STABILITY FEE TO 10% FOR REMAINING ILKS
		{
			uint256 _10PERCENT = 1000000003022265980097387651; // duty 10%
			DssExecLib.setIlkDebtCeiling("STKCAKE-A", 0);
			DssExecLib.setIlkStabilityFee("STKCAKE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBNBCAKE-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBNBCAKE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBNBBUSD-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBNBBUSD-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBNBETH-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBNBETH-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBNBBTCB-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBNBBTCB-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBUSDUSDC-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBUSDUSDC-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBUSDBTCB-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBUSDBTCB-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSBUSDCAKE-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSBUSDCAKE-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSETHBTCB-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSETHBTCB-A", _10PERCENT, true);
			DssExecLib.setIlkDebtCeiling("STKPCSETHUSDC-A", 0);
			DssExecLib.setIlkStabilityFee("STKPCSETHUSDC-A", _10PERCENT, true);
		}
	}
}

// valid for 30 days
contract DssSpell_bscmain_2022_05_11 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_bscmain_2022_05_11()))
{
}
