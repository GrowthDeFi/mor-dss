// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_avaxmain_2022_01_08 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20January%208%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-01-08 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.2");

		// ----- SETS PSM-STKUSDLP-A DEBT CEILING TO 10M -----

		{
			DssExecLib.setIlkDebtCeiling("PSM-STKUSDLP-A", 1000000); // line 10m
		}
	}
}

// valid for 30 days
contract DssSpell_avaxmain_2022_01_08 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2022_01_08()))
{
}
