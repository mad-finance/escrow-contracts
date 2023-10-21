// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {Types as ModuleTypes} from 'lens/libraries/constants/Types.sol';

abstract contract LensModule {
    function supportsInterface(bytes4 interfaceID) public pure virtual returns (bool) {
        return interfaceID == bytes4(keccak256(abi.encodePacked("LENS_MODULE")));
    }
}

abstract contract MockModule is LensModule {
    error MockModuleReverted();

    function testMockModule() public {
        // Prevents being counted in Foundry Coverage
    }

    // Reverts if the flag decoded from the data is not `true`.
    function _decodeFlagAndRevertIfFalse(bytes memory data) internal pure returns (bytes memory) {
        bool shouldItSucceed = abi.decode(data, (bool));
        if (!shouldItSucceed) {
            revert MockModuleReverted();
        }
        return data;
    }

    function getModuleMetadataURI() external pure returns (string memory) {
        return "https://docs.lens.xyz/";
    }
}

interface IPublicationActionModule {
    /**
     * @notice Initializes the action module for the given publication being published with this Action module.
     * @custom:permissions LensHub.
     *
     * @param profileId The profile ID of the author publishing the content with this Publication Action.
     * @param pubId The publication ID being published.
     * @param transactionExecutor The address of the transaction executor (e.g. for any funds to transferFrom).
     * @param data Arbitrary data passed from the user to be decoded by the Action Module during initialization.
     *
     * @return bytes Any custom ABI-encoded data. This will be a LensHub event params that can be used by
     * indexers or UIs.
     */
    function initializePublicationAction(
        uint256 profileId,
        uint256 pubId,
        address transactionExecutor,
        bytes calldata data
    ) external returns (bytes memory);

    /**
     * @notice Processes the action for a given publication. This includes the action's logic and any monetary/token
     * operations.
     * @custom:permissions LensHub.
     *
     * @param processActionParams The parameters needed to execute the publication action.
     *
     * @return bytes Any custom ABI-encoded data. This will be a LensHub event params that can be used by
     * indexers or UIs.
     */
    function processPublicationAction(ModuleTypes.ProcessActionParams calldata processActionParams)
        external
        returns (bytes memory);
}

/**
 * @dev This is a simple mock Action module to be used for testing revert cases on processAction.
 */
contract MockActionModule is MockModule, IPublicationActionModule {
    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == type(IPublicationActionModule).interfaceId || super.supportsInterface(interfaceID);
    }

    error MockActionModuleReverted();

    function testMockActionModule() public {
        // Prevents being counted in Foundry Coverage
    }

    // Reverts if `data` does not decode as `true`.
    function initializePublicationAction(
        uint256,
        /**
         * profileId
         */
        uint256,
        /**
         * pubId
         */
        address,
        /**
         * transactionExecutor
         */
        bytes calldata data
    ) external pure override returns (bytes memory) {
        return _decodeFlagAndRevertIfFalse(data);
    }

    // Reverts if `processActionParams.actionModuleData` does not decode as `true`.
    function processPublicationAction(ModuleTypes.ProcessActionParams calldata processActionParams)
        external
        pure
        override
        returns (bytes memory)
    {
        return _decodeFlagAndRevertIfFalse(processActionParams.actionModuleData);
    }
}
