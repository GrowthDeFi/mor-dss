// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

contract DssSpellAction_bscmain_2021_10_14 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20October%2014%2C%202021.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2021-10-14 GrowthDeFi Executive Spell | Hash: 0x0541987601cebf12382695d2e171aaa68bf2f1d7aad5ad49148f0adb31b5ad4f";

	function actions() public override
	{
		// Set changelog version
		DssExecLib.setChangelogVersion("1.0.0");
	}
}

contract DssSpell_bscmain_2021_10_14 is DssExec
{
	constructor(address log)
		DssExec(log, block.timestamp + 30 days, address(new DssSpellAction_bscmain_2021_10_14())) public
	{
	}
}
