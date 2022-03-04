// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { SurplusPayer } from "../surplus-payer/surplus-payer.sol";

contract DssSpellAction_bscmain_2022_03_07 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20March%207%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-03-07 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MULTISIG = 0x392681Eaf8AD9BC65e74BE37Afe7503D92802b7d; // GrowthDeFi multisig on BSC
	address constant REWARD_DISTRIBUTOR = 0x9E83396CD47c82197fDD5D7a5E486cB8da522cA2; // veGRO-MOR reward distributor on BSC

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.2");

		// ----- ADDS THE SURPLUS PAYER MODULE -----

		{
			address MCD_VAT = DssExecLib.vat();
			address MCD_JOIN_DAI = DssExecLib.daiJoin();
			address MCD_VOW = DssExecLib.vow();
			address _surplusPayer = address(new SurplusPayer(MCD_JOIN_DAI, MCD_VOW, REWARD_DISTRIBUTOR, MULTISIG));
			DssExecLib.authorize(MCD_VAT, _surplusPayer);
		}
	}
}

// valid for 30 days
contract DssSpell_bscmain_2022_03_07 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_bscmain_2022_03_07()))
{
}
