// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC1155} from "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Pausable} from "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract OutmineItems is ERC1155, AccessControl, ERC1155Pausable, ERC1155Burnable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using Strings for uint256;

    mapping(uint256 => bool) public isSoulbound;

    event SoulboundSet(uint256 indexed tokenId, bool soulbound);

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function balanceOfBatchOneAddr(address account, uint256[] memory ids) public view returns (uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            batchBalances[i] = balanceOf(account, ids[i]);
        }
        return batchBalances;
    }

    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    function grantMinterRole(address minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, minter);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory baseURI = ERC1155.uri(tokenId);
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyRole(MINTER_ROLE) {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    function mintBatchAddr(address[] memory accounts, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; ++i) {
            _mint(accounts[i], ids[i], amounts[i], data);
        }
    }

    function setSoulbound(uint256 tokenId, bool soulbound) public onlyRole(DEFAULT_ADMIN_ROLE) {
        isSoulbound[tokenId] = soulbound;
        emit SoulboundSet(tokenId, soulbound);
    }

    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable)
    {
        // Block transfer of soulbound tokens except mint (from == 0) or burn (to == 0)
        for (uint256 i = 0; i < ids.length; ++i) {
            if (isSoulbound[ids[i]]) {
                require(from == address(0) || to == address(0), "Soulbound: non-transferable");
            }
        }
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
