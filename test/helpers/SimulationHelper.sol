// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract SimulationHelper {
    address[] public genesisBadgeAddresses;
    uint128[] public genesisRewardPoints;

    address[] public genesisBadgeExtraPointsAddresses;

    uint128 constant GENESIS_REWARD_POINTS = 500;
    uint8 constant GENESIS_REWARD_POINTS_EXTRA_ENUM = 0; // 250 points

    function addAddress(address _address) public {
        genesisBadgeAddresses.push(_address);
        genesisRewardPoints.push(GENESIS_REWARD_POINTS);
    }

    function addAddressExtra(address _address) public {
        genesisBadgeExtraPointsAddresses.push(_address);
    }

    // adds 42 addresses (mainnet badge holders with >= 500 points) to get base points
    function initializeAddresses() public {
        addAddress(0x0374F0273e01841F594a4C0becdf7Bfbd9B13a42);
        addAddress(0x06F455e2C297a4Ae015191FA7A4A11C77c5b1b7c);
        addAddress(0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64);
        addAddress(0x2D2a8cEe8113a969f2e3fC55922c42497fcC2519);
        addAddress(0x2D805c4784AC205875D51031ed971c21843b0331);
        addAddress(0x2dcC5b6135795fB408B59A53218490443A4C6101);
        addAddress(0x2Ec19e982172EaD28B312a07FAf25105fB3747d8);
        addAddress(0x30b0EAe5e9Df8a1C95dFdB7AF86aa4e7F3B51f13);
        addAddress(0x31Feab5c6E76f159bBE2F93FDE4A59200813679c);
        addAddress(0x45dA50B5e5552Ffd010E309d296c88e393D227Ab);
        addAddress(0x4E59eECCcA4A2A4B129F8b122d937f90Cce2f1Aa);
        addAddress(0x51A17188a744dD773740BE3ed30AE1dA37Ec1003);
        addAddress(0x5d56965d0742F80f5276bf89a80a43cB8d1C2b42);
        addAddress(0x61315007451e00451305f63c93Af8CDd866F6Bc9);
        addAddress(0x6d5d4fb55c61019c5eb9236c3da58c774B8232D1);
        addAddress(0x6F6783Da5d28092B33A6317bF59B58F5EAe36d88);
        addAddress(0x714b831eB02FE854283219B2B9f1c6951f46Dcb9);
        addAddress(0x736eD70a9059978A9C7733cD65E780f0c7bD162c);
        addAddress(0x770569f85346B971114e11E4Bb5F7aC776673469);
        addAddress(0x79603115Df2Ba00659ADC63192325CF104ca529C);
        addAddress(0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6);
        addAddress(0x806346b423dDB4727C1f5dC718886430aA7CE9cF);
        addAddress(0x8115AfD8DFfCE5579381AD27524b6Feeae917BEF);
        addAddress(0x8D44fC4be303f515e09777f5ab8D55006E0cf875);
        addAddress(0x965ec2820727148b8B4bD5dA4a7B23EfA03D95CD);
        addAddress(0x9C85C376A50721c75E4E015AC22EfE066dbB73EC);
        addAddress(0x9D59C1E01218b66578bb9b1d781188271c62Fe4f);
        addAddress(0xA1FC3CE428431c2F7303B44CfE1B10BF38402a90);
        addAddress(0xA4EAd72AE2494D06c1EbC7F3D9E6983EfEe32893);
        addAddress(0xA6583617baB73f18d1Db30a5Aa4EBe4dA4af581B);
        addAddress(0xb00Cc766b7AdC1a34d72EA46a8d4bbdfBc5904F9);
        addAddress(0xb1577a1506f858aeFC37F89d0BEABaf2C7557ed3);
        addAddress(0xb42573ddb86b68429C8f791ED0F2B79d2ca95588);
        addAddress(0xc2b96df49DA778BfCA0CC6c4416e40E2D17f72ff);
        addAddress(0xc31372dB84e456193e72a162928539C8F5999Ff6);
        addAddress(0xd475fD4722A7d9A22a2D033E685429AaA6F953B0);
        addAddress(0xdaA5EBe0d75cD16558baE6145644EDdFcbA1e868);
        addAddress(0xDC4471ee9DFcA619Ac5465FdE7CF2634253a9dc6);
        addAddress(0xF4e2Bc18464670a684Bb8Ce2F5663c543Db402c3);
        addAddress(0xF62DE7f630BfA578214F95F217150b61b8d6A15f);
        addAddress(0xFD0E1F2fc10F7E43dcF80b1F17F0e4435E858035);
        addAddress(0xff914CAeCc4B7e8113e4CA44D5735293205d01b9);
    }

    // adds 18 addresses (mainnet badge holders with > 500 points) to get more points
    function initializeAddressesExtra() public {
        addAddressExtra(0x0374F0273e01841F594a4C0becdf7Bfbd9B13a42);
        addAddressExtra(0x28ff8e457feF9870B9d1529FE68Fbb95C3181f64);
        addAddressExtra(0x2D2a8cEe8113a969f2e3fC55922c42497fcC2519);
        addAddressExtra(0x2dcC5b6135795fB408B59A53218490443A4C6101);
        addAddressExtra(0x2Ec19e982172EaD28B312a07FAf25105fB3747d8);
        addAddressExtra(0x45dA50B5e5552Ffd010E309d296c88e393D227Ab);
        addAddressExtra(0x5d56965d0742F80f5276bf89a80a43cB8d1C2b42);
        addAddressExtra(0x714b831eB02FE854283219B2B9f1c6951f46Dcb9);
        addAddressExtra(0x7F0408bc8Dfe90C09072D8ccF3a1C544737BcDB6);
        addAddressExtra(0x8D44fC4be303f515e09777f5ab8D55006E0cf875);
        addAddressExtra(0x965ec2820727148b8B4bD5dA4a7B23EfA03D95CD);
        addAddressExtra(0x9C85C376A50721c75E4E015AC22EfE066dbB73EC);
        addAddressExtra(0x9D59C1E01218b66578bb9b1d781188271c62Fe4f);
        addAddressExtra(0xA6583617baB73f18d1Db30a5Aa4EBe4dA4af581B);
        addAddressExtra(0xd475fD4722A7d9A22a2D033E685429AaA6F953B0);
        addAddressExtra(0xDC4471ee9DFcA619Ac5465FdE7CF2634253a9dc6);
        addAddressExtra(0xF62DE7f630BfA578214F95F217150b61b8d6A15f);
        addAddressExtra(0xff914CAeCc4B7e8113e4CA44D5735293205d01b9);
    }
}
