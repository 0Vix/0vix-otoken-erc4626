// SPDX-License-Identifier: UNLICENSED
/**
 * IMPORTANT:
 * THIS TEST RUNS ONLY AGAINST A POLYGON FORK
 */
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "yield-daddy/compound/OvixERC4626.sol";

contract vaultTest is Test {
    //cheat codes
    OvixERC4626 public vault;

    ICERC20 ovGHST = ICERC20(0xE053A4014b50666ED388ab8CbB18D5834de0aB12);
    IComptroller comptroller =
        IComptroller(0x8849f1a0cB6b5D6076aB150546EddEe193754F1C);
    ERC20 vghst = ERC20(0x51195e21BDaE8722B29919db56d95Ef51FaecA6C);

    address prankster = 0x84Ef9d47a2B1cbFC2F011F886287Ef44F08c80ab;

    function setUp() public {
        vault = new OvixERC4626(
            vghst,
            vghst,
            ovGHST,
            prankster,
            comptroller
        );
    }

    function testVault() public {
        console.log("symbol:", vault.symbol());
        console.log("name:", vault.name());
        console.log("decimals:", vault.decimals());
        console.log("underlying", ERC20(vault.asset()).symbol());
    }

    function testDeposit() public {
        vm.startPrank(prankster);
        vghst.approve(address(vault), type(uint256).max);

        uint balanceBefore = ovGHST.getCash();
        vault.deposit(10 ether, prankster);
        uint balanceAfter = ovGHST.getCash();
        assertEq(balanceAfter, balanceBefore + 10 ether);
    }

    function testYieldDepositWithdraw() public {
        vm.startPrank(prankster);
        vghst.approve(address(vault), type(uint256).max);

        uint sharesToReceive = vault.convertToShares(10 ether);
        vault.deposit(10 ether, prankster);

        console.log("Deposited (vGHST):\t\t", 10 ether);
        console.log("Shares minted:\t\t", sharesToReceive);
        console.log("balanceOFUnderlying\t\t", vault.totalAssets());

        // wait 1000 blocks
        console.log(unicode"⏩ fast forward 10 minutes");
        vm.warp(block.timestamp + 600);

        uint underlyingWorthLater = vault.convertToAssets(10 ether);

        console.log("Assets value + yield:\t\t", underlyingWorthLater);
        console.log("Yield:\t\t\t", underlyingWorthLater - 10 ether);
        console.log(unicode"✅ Withdraw underlying + yield");

        uint vghstBalBefore = vghst.balanceOf(prankster);

        assertEq(vghst.balanceOf(address(this)), 0);

        vault.withdraw(underlyingWorthLater, prankster, prankster);

        assertEq(
            vghst.balanceOf(prankster) - vghstBalBefore,
            underlyingWorthLater
        );
    }

    function testMaxDeposit() public {
        vault.maxDeposit(address(this));
    }

    function testTotalAssets() public {
        console.log("Total assets:", vault.totalAssets());
    }

    function testClaimRewards() public {
        vault.claimRewards();
    }

    function testMaxMint() public {
        vault.maxMint(address(this));
    }

    function testMaxWithdraw() public {
        vault.maxWithdraw(address(this));
    }

    function testMaxRedeem() public {
        vault.maxRedeem(address(this));
    }

    function testExchangeRate() public {
        console.log("Exchange rate:", vault.exchangeRate());
    }
}
