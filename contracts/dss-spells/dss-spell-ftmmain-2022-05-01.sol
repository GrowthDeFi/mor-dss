// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { DssAmo } from "../dss-amo/amo.sol";

contract DssSpellAction_ftmmain_2022_05_01 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20May%201%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-05-01 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MOR_bbyvUSD_AMO_OLD = 0x53AAF3c5FC977E2ED7E0e746306Dec3927829AE5;
	address constant MOR_bbyvUSD_AMO_NEW = 0xD9c0b7D0a62167E4aFadd8fF21761d016A3069AD;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.2");

		// ----- UPDATES MOR_bbyvUSD_AMO CEILING -----
		{
			address MCD_AMO = DssExecLib.getChangelogAddress("MCD_AMO");
			DssAmo(MCD_AMO).ceil(MOR_bbyvUSD_AMO_OLD, 0);
			DssAmo(MCD_AMO).ceil(MOR_bbyvUSD_AMO_NEW, 10_000_000e18); // 10mi MOR
		}
	}
}

// valid for 30 days
contract DssSpell_ftmmain_2022_05_01 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_ftmmain_2022_05_01()))
{
}
