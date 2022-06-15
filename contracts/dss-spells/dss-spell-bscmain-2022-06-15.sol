// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_bscmain_2022_06_15 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20June%2015%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-06-15 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.3");

		// ----- SETS DEBT CEILING TO 1mi FOR STKBANANA-A
		{
			DssExecLib.setIlkDebtCeiling("STKBANANA-A", 300000); // line 300k
			DssExecLib.setIlkLiquidationRatio("STKBANANA-A", 20000); // mat 200%
		}
	}
}

// valid for 30 days
contract DssSpell_bscmain_2022_06_15 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_bscmain_2022_06_15()))
{
}
