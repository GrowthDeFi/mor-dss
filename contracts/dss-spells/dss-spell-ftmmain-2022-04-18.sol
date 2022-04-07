// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_ftmmain_2022_04_18 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20April%2018%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-04-18 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MULTISIG = 0x392681Eaf8AD9BC65e74BE37Afe7503D92802b7d; // GrowthDeFi multisig on BSC
	address constant AMO_MODULE = 0x0000000000000000000000000000000000000000;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.0");

		// ----- INSTALLS THE AMO MODULE -----

		{
			address MCD_VAT = DssExecLib.vat();
			DssExecLib.authorize(MCD_VAT, AMO_MODULE);
		}
	}
}

// valid for 30 days
contract DssSpell_ftmmain_2022_04_18 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_bscmain_2022_04_18()))
{
}
