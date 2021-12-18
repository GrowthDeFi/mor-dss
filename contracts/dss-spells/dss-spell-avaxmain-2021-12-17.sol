// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { DssPsm } from "../dss-psm/psm.sol";
import { AuthGemJoin } from "../dss-gem-joins/join-auth.sol";
import { StairstepExponentialDecrease } from "../dss/abaci.sol";

contract DssSpellAction_avaxmain_2021_12_17 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20December%2017%2C%202021.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2021-12-17 GrowthDeFi Executive Spell | Hash: 0x0000000000000000000000000000000000000000000000000000000000000000";

	bytes32 constant ILK_NAME = "PSM-STKUSDLP-A";
	address constant STKUSDLP = 0x88Cc23286f1356EB0163Ad5bdbFa639416e4168d;
	address constant STKUSDLP_INJECTOR = 0x4EcD4082C1E809D89901cD3A802409c8d2Ae6EC4;
	address constant STKUSDLP_CONTANT_PIP = 0x68697fF7Ec17F528E3E4862A1dbE6d7D9cBBd5C6;

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.1");

		AuthGemJoin _authGemJoin = new AuthGemJoin(DssExecLib.vat(), ILK_NAME, STKUSDLP);

		StairstepExponentialDecrease _calc = new StairstepExponentialDecrease();

		/*
		_dssDeploy.deployCollateralClip(ILK_NAME, _authGemJoin, PIP_[token_name], address _calc);

		// Deploy
		ilks[ilk].clip = clipFab.newClip(address(this), address(vat), address(spotter), address(dog), ilk);
		ilks[ilk].join = join;
		Spotter(spotter).file(ilk, "pip", address(pip)); // Set pip

		// Internal references set up
		dog.file(ilk, "clip", address(ilks[ilk].clip));
		ilks[ilk].clip.file("vow", address(vow));
		ilks[ilk].clip.file("calc", calc);
		vat.init(ilk);
		jug.init(ilk);

		// Internal auth
		vat.rely(join);
		vat.rely(address(ilks[ilk].clip));
		dog.rely(address(ilks[ilk].clip));
		ilks[ilk].clip.rely(address(dog));
		ilks[ilk].clip.rely(address(end));
		ilks[ilk].clip.rely(address(esm));
		ilks[ilk].clip.rely(address(pause.proxy()));
		*/

		DssPsm _dssPsm = new DssPsm(address(_authGemJoin), DssExecLib.daiJoin(), DssExecLib.vow());
		_dssPsm.file("tin", 1e15); // 0.001%
		_dssPsm.file("tout", 0); // 0%
		_dssPsm.donor(STKUSDLP, true);
		_dssPsm.donor(STKUSDLP_INJECTOR, true);

		_authGemJoin.rely(address(_dssPsm));
	}
}

// valid for 30 days
contract DssSpell_avaxmain_2021_12_17 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_avaxmain_2021_12_17()))
{
}
