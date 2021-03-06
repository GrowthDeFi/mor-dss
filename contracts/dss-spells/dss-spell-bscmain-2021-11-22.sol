// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import { DssAction } from "../dss-exec-lib/DssAction.sol";
import { DssExec } from "../dss-exec-lib/DssExec.sol";
import { DssExecLib } from "../dss-exec-lib/DssExecLib.sol";

import { DSPause } from "../ds-pause/pause.sol";

contract DssSpellAction_bscmain_2021_11_22 is DssAction
{
	// Hash: seth keccak -- "$(wget https://raw.githubusercontent.com/GrowthDeFi/community/master/governance/votes/Executive%20vote%20-%20November%2022%2C%202021.md -q -O - 2>/dev/null)"
	string public constant override description =
		"2021-11-22 GrowthDeFi Executive Spell | Hash: 0x2c235b56301859f0551cbd9511c4b8fba0417afa8795b223788691250dd390bf";

	address constant MULTISIG = 0x392681Eaf8AD9BC65e74BE37Afe7503D92802b7d; // GrowthDeFi multisig on BSC

	function actions() public override
	{
		// Bumps changelog version
		DssExecLib.setChangelogVersion("1.0.1");

		// ----- ADJUSTMENTS TO ILKS -----

		// STKAPEMORBUSD-A
		// - Stability Fee: 25%
		// - Liquidation Ratio: 110%
		// - Liquidation Penalty: 9%
		DssExecLib.setIlkStabilityFee("STKAPEMORBUSD-A", 1000000007075835619725814915, true); // duty 25%
		DssExecLib.setIlkLiquidationRatio("STKAPEMORBUSD-A", 11000); // mat 110%
		DssExecLib.setIlkLiquidationPenalty("STKAPEMORBUSD-A", 900); // chop 9%

		// STKPCSBUSDUSDC-A
		// - Stability Fee: 50%
		// - Debt Ceiling: 0
		//   By lowering the debt ceiling to 0 and increasing the
		//   stability fee this collateral type would be discontinued
		//   once all borrowers have closed down their positions.
		DssExecLib.setIlkStabilityFee("STKPCSBUSDUSDC-A", 1000000012857214317438491659, true); // duty 50%
		DssExecLib.setIlkDebtCeiling("STKPCSBUSDUSDC-A", 0); // line 0

		// STKCAKE-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKCAKE-A", 15000); // mat 150%

		// STKBANANA-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKBANANA-A", 15000); // mat 150%

		// STKPCSBNBCAKE-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKPCSBNBCAKE-A", 15000); // mat 150%

		// STKPCSBNBETH-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKPCSBNBETH-A", 15000); // mat 150%

		// STKPCSBNBBTCB-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKPCSBNBBTCB-A", 15000); // mat 150%

		// STKPCSETHBTCB-A
		// - Liquidation Ratio: 150%
		DssExecLib.setIlkLiquidationRatio("STKPCSETHBTCB-A", 15000); // mat 150%

		// ----- SURPLUS WITHDRAWAL OF 50,000 MOR -----

		DssExecLib.delegateVat(DssExecLib.daiJoin());
		DssExecLib.sendPaymentFromSurplusBuffer(MULTISIG, 50000); // 50k MOR
		DssExecLib.undelegateVat(DssExecLib.daiJoin());

		// ----- ADDS A 24-HOUR PAUSE DELAY FOR SPELLS -----

		{
			address _pause = DssExecLib.getChangelogAddress("MCD_PAUSE");
			DSPause(_pause).setDelay(24 hours);
		}
	}
}

// valid for 30 days
contract DssSpell_bscmain_2021_11_22 is DssExec(block.timestamp + 30 days, address(new DssSpellAction_bscmain_2021_11_22()))
{
}
