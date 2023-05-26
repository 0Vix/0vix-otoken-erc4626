// SPDX-License-Identifier: UNLICENSED
/**
 * IMPORTANT:
 * THIS TEST RUNS ONLY AGAINST A POLYGON FORK
 */
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "yield-daddy/compound/OvixERC4626Factory.sol";

contract vaultTest is Test {
    OvixERC4626Factory factory;
    IComptroller comptroller;
    ERC20 underlying;

    function _getVault() internal returns (OvixERC4626) {
        return OvixERC4626(address(factory.createERC4626(underlying)));
    }

    function _fundUser(address user, uint256 amount) internal {
        address usdcWhale = vm.envAddress("UNDERLYING_WHALE");
        vm.prank(usdcWhale);
        underlying.transfer(user, amount);
    }

    function setUp() public {
        comptroller = IComptroller(vm.envAddress("COMPTROLLER_ADDRESS"));
        underlying = ERC20(vm.envAddress("UNDERLYING_ADDRESS"));
        factory = new OvixERC4626Factory(
            comptroller,
            vm.envAddress("ONATIVE_ADDRESS"),
            vm.envAddress("REWARD_RECIPIENT")
        );
    }

    function testVaultDeployment() public {
        OvixERC4626 vault = _getVault();

        assertEq(vault.decimals(), 6);
        assertEq(vault.symbol(), "woUSDC");
        assertEq(vault.name(), "ERC4626-Wrapped 0VIX USDC");
        assertEq(address(vault.oToken()), vm.envAddress("oUNDERLYING_ADDRESS"));
        assertEq(address(vault.asset()), vm.envAddress("UNDERLYING_ADDRESS"));
    }

    function testExchangeRate() public {
        OvixERC4626 vault = _getVault();

        assertEq(vault.exchangeRate(), vault.oToken().exchangeRateCurrent());
    }

    function testDepositAndWithdrawSingleUser() public {
        OvixERC4626 vault = _getVault();
        uint amount = 20000000000;

        // FUND USER
        _fundUser(address(this), amount);

        // How much shares will user get
        uint256 shares = vault.convertToShares(amount);

        // Approve vault to spend user's underlying
        underlying.approve(address(vault), type(uint256).max);

        // Deposit to vault
        vault.deposit(amount, address(this));

        // vault should have the amount of underlying
        assertEq(vault.balanceOf(address(this)), amount);

        // user should have no remaining underlying
        assertEq(underlying.balanceOf(address(this)), 0);

        // user should have the expected shares
        assertEq(vault.balanceOf(address(this)), shares);

        // Make time pass so that yield is generated - 1 day
        vm.warp(block.timestamp + 150);

        uint amountPlusYield = vault.totalAssets();

        // expect convertToAssets to increase as well
        assertEq(vault.convertToAssets(shares), amountPlusYield);

        // Test that withdrawal captures yield
        vault.withdraw(amountPlusYield, address(this), address(this));

        // Expect vault to have no shares and no underlying
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.totalAssets(), 0);

        // Expect user to have the amount of underlying + yield
        assertEq(underlying.balanceOf(address(this)), amountPlusYield);
    }

    function testDepositAndWithdrawSMultiUser() public {
        OvixERC4626 vault = _getVault();
        uint user1Amount = 20000000000;
        uint user2Amount = 10000000000;
        address account2 = 0xa86Cd62AF83cDfe32B7EC36E3A32D80FDf42a3aD;

        // FUND USER
        _fundUser(address(this), user1Amount);
        _fundUser(account2, user2Amount);

        // How much shares will user get
        uint256 sharesUser1 = vault.convertToShares(user1Amount);

        /* -------------------------------------------------------------------------- */
        /*                                  Account 1                               */
        /* -------------------------------------------------------------------------- */
        // USER:1 Approve vault to spend user's underlying
        underlying.approve(address(vault), type(uint256).max);

        // USER1: Deposit to vault
        vault.deposit(user1Amount, address(this));

        // vault should have the amount of underlying
        assertEq(vault.balanceOf(address(this)), user1Amount);

        // user should have no remaining underlying
        assertEq(underlying.balanceOf(address(this)), 0);

        /* -------------------------------------------------------------------------- */
        /*                                  ACCOUNT 2                                  */
        /* -------------------------------------------------------------------------- */
        vm.startPrank(account2);
        uint256 sharesUser2 = vault.convertToShares(user2Amount);

        // USER:1 Approve vault to spend user's underlying
        underlying.approve(address(vault), type(uint256).max);

        // USER1: Deposit to vault
        vault.deposit(user2Amount, account2);

        // vault should have the amount of underlying
        assertEq(vault.balanceOf(account2), sharesUser2);

        // user should have no remaining underlying
        assertEq(underlying.balanceOf(account2), 0);

        // user should have the expected shares
        assertEq(vault.balanceOf(account2), sharesUser2);

        // Make time pass so that yield is generated - 1 day
        vm.warp(block.timestamp + 160);

        /* -------------------------------------------------------------------------- */
        /*                                 Withdrawals                                */
        /* -------------------------------------------------------------------------- */

        // account 2 withdraw
        uint user1AmountPlusYield = vault.convertToAssets(sharesUser1);
        uint user2AmountPlusYield = vault.convertToAssets(sharesUser2);

        // Test that withdrawal captures yield
        vault.withdraw(user2AmountPlusYield, account2, account2);

        assertEq(vault.balanceOf(account2), 0);
        assertEq(vault.totalSupply(), sharesUser1);
        assertEq(underlying.balanceOf(account2), user2AmountPlusYield);

        // account 1 withdraw
        vm.stopPrank();

        vault.withdraw(user1AmountPlusYield, address(this), address(this));

        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(underlying.balanceOf(address(this)), user1AmountPlusYield);

        console.log("User 1 deposited", user1Amount);
        console.log("User 1 made", user1AmountPlusYield - user1Amount);
        console.log("User 2 deposited", user2Amount);
        console.log("User 2 made", user2AmountPlusYield - user2Amount);
    }

    function testUnderlyingDonationShouldNotAffectSharePrice() public {
        OvixERC4626 vault = _getVault();
        uint amount = 20000000000;

        // FUND USER
        _fundUser(address(this), amount);
        // How much shares will user get
        uint256 shares = vault.convertToShares(amount);

        // Approve vault to spend user's underlying
        underlying.approve(address(vault), type(uint256).max);

        // Deposit to vault
        vault.deposit(amount, address(this));

        uint userAssets = vault.totalAssets();
        assertEq(userAssets, vault.convertToAssets(shares));

        // DONATE
        _fundUser(address(vault), 10000000000);

        // User assets should not change
        assertEq(userAssets, vault.convertToAssets(shares));

        // Total assets should not change
        assertEq(vault.totalAssets(), userAssets);
    }

    function testOTokenDonationShouldAffectSharePrice() public {
        OvixERC4626 vault = _getVault();
        uint amount = 10000000000;

        // FUND USER
        _fundUser(address(this), amount);
        // How much shares will user get
        uint256 shares = vault.convertToShares(amount);

        // Approve vault to spend user's underlying
        underlying.approve(address(vault), type(uint256).max);

        // Deposit to vault
        vault.deposit(amount, address(this));

        uint userAssets = vault.totalAssets();
        assertEq(userAssets, vault.convertToAssets(shares));

        // Mint oTokens and donate to vault
        uint mintOTokensUsingUnderlying = 10000000000;
        _fundUser(address(this), mintOTokensUsingUnderlying);

        underlying.approve(address(vault.oToken()), type(uint256).max);
        vault.oToken().mint(mintOTokensUsingUnderlying);
        (bool success, ) = address(vault.oToken()).call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                address(vault),
                vault.oToken().balanceOf(address(this))
            )
        );
        require(success, "Transfer failed");
        // User asset should be more now
        assertEq(vault.convertToAssets(shares), vault.totalAssets());
    

        // withdraw
        vault.withdraw(
            vault.convertToAssets(shares),
            address(this),
            address(this)
        );

        assertLt(amount + mintOTokensUsingUnderlying - underlying.balanceOf(address(this)), 10); //rounding error
    }

    function testVaultInteractionWithOToken() public {
        OvixERC4626 vault = _getVault();
        uint amount = 20000000000;
        _fundUser(address(this), amount);

        uint256 shares = vault.convertToShares(amount);

        underlying.approve(address(vault), type(uint256).max);

        vault.deposit(amount, address(this));

        // OToken assertions
        uint vaultBalInOtoken = vault.oToken().balanceOf(address(vault));
        vm.warp(block.timestamp + 150);

        vault.withdraw(
            vault.convertToAssets(shares),
            address(this),
            address(this)
        );

        assertLt(vault.oToken().balanceOf(address(vault)), 100000); //Rounding due to decimal diff
    }

    // function testClaimRewards() public {
    //     OvixERC4626 vault = _getVault();
    //     uint amount = 20000000000;
    //     _fundUser(address(this), amount);

    //     uint256 shares = vault.convertToShares(amount);

    //     underlying.approve(address(vault), type(uint256).max);

    //     vault.deposit(amount, address(this));

    //     vault.claimRewards();
    // }
}
