// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { SurplusPayer } from "../surplus-payer/surplus-payer.sol";

contract DssSpellAction_avaxmain_2022_03_07 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20March%207%2C%202022.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2022-03-07 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	address constant MULTISIG = 0x6F926fFBe338218b06D2FC26eC59b52Fd5b125cE; // GrowthDeFi multisig on Avalanche
	address constant REWARD_DISTRIBUTOR = 0x09d46be693608dB03A9f29EdbaD09C0A557f8690; // veGRO-MOR reward distributor on Avalanche

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
			emit NewSurplusPayer(_surplusPayer);
		}
	}

	event NewSurplusPayer(address _surplusPayer);
}

// valid for 30 days
contract DssSpell_avaxmain_2022_03_07 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2022_03_07()))
{
}
