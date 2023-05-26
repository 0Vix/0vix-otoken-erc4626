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

    function _getVault() internal returns (OvixERC4626) {
        return
            OvixERC4626(
                address(
                    factory.createERC4626(ERC20(vm.envAddress("USDC_ADDRESS")))
                )
            );
    }

    function setUp() public {
        comptroller = IComptroller(vm.envAddress("COMPTROLLER_ADDRESS"));
        factory = new OvixERC4626Factory(
            comptroller,
            vm.envAddress("ONATIVE_ADDRESS"),
            vm.envAddress("REWARD_RECIPIENT")
        );
    }

    function testUsdcDeposit() public {
        OvixERC4626 vault = _getVault();
    }

    function testUsdcWithdraw() public {
        OvixERC4626 vault = _getVault();
    }

    function testVaultDeployment() public {
        OvixERC4626 vault = _getVault();

        assertEq(vault.decimals(), 6);
        assertEq(vault.symbol(), "woUSDC");
        assertEq(vault.name(), "ERC4626-Wrapped 0VIX USDC");
        assertEq(address(vault.oToken()), vm.envAddress("oUSDC_ADDRESS"));
        assertEq(address(vault.asset()), vm.envAddress("USDC_ADDRESS"));
    }

    function testExchangeRate() public {
        OvixERC4626 vault = _getVault();

        assertEq(vault.exchangeRate(), vault.oToken().exchangeRateCurrent());
    }
}
