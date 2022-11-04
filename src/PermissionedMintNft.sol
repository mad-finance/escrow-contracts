// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/access/Ownable.sol";

contract PermissionedMintNft is ERC721, Ownable {
    using Strings for uint256;

    string public baseURI;
    uint256 public currentTokenId;
    address public notary;

    mapping(uint256 => bool) internal usedNonces;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) Ownable() ERC721(_name, _symbol) {
        setBaseURI(_baseURI);
        setNotary(_msgSender());
    }

    /// @notice allows a user to mint an Nft of their brief
    function mint(
        address recipient,
        uint256 nonce,
        bytes memory signature
    ) public {
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encode(address(this), recipient, nonce))
        );

        if (notary != ECDSA.recover(hash, signature)) {
            revert InvalidNotarization();
        }
        if (usedNonces[nonce]) {
            revert NonceReused();
        }

        usedNonces[nonce] = true;

        _safeMint(recipient, currentTokenId);
        currentTokenId++;
    }

    /// @notice returns token Uri
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) {
            revert NonexistantToken();
        }

        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, "/", tokenId.toString())
                : "";
    }

    // ADMIN FUNCTIONS
    function setNotary(address _notary) public onlyOwner {
        notary = _notary;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    // ERRORS
    error InvalidNotarization();
    error NonceReused();
    error NonexistantToken();
}
