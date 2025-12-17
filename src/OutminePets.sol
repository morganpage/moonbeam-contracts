// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

event MaxSupplySet(uint256 newMaxSupply);

event BaseURISet(string newBaseURI);

event MintPriceSet(uint256 newPrice);

event Withdrawn(address to, uint256 amount);

event BatchMint(address indexed to, uint256 startTokenId, uint256 quantity);

contract OutminePets is ERC721, ERC721Pausable, AccessControl, ReentrancyGuard {
    uint256 private _nextTokenId;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    string private _baseTokenURI;
    uint256 private _maxSupply;
    uint256 private _mintPrice;

    constructor() ERC721("OutminePets", "OMP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function setMaxSupply(uint256 maxSupply_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxSupply_ == 0 || maxSupply_ >= _nextTokenId, "Cannot set max supply below current supply");
        _maxSupply = maxSupply_;
        emit MaxSupplySet(maxSupply_);
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function mint(address to) public onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 tokenId = _nextTokenId;
        require(_maxSupply == 0 || tokenId < _maxSupply, "Max supply reached");
        unchecked {
            _nextTokenId = tokenId + 1;
        }
        _safeMint(to, tokenId);
    }

    function mintBatch(address to, uint256 quantity) public onlyRole(MINTER_ROLE) whenNotPaused {
        require(quantity > 0, "Invalid batch quantity");
        if (_maxSupply != 0) {
            require(quantity <= _maxSupply - _nextTokenId, "Max supply reached");
        }

        uint256 startTokenId = _nextTokenId;
        for (uint256 i = 0; i < quantity; ++i) {
            uint256 tokenId = _nextTokenId;
            unchecked {
                _nextTokenId = tokenId + 1;
            }
            _safeMint(to, tokenId);
        }

        emit BatchMint(to, startTokenId, quantity);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function withdraw(address payable to) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(address(this).balance > 0, "No funds to withdraw");
        uint256 amount = address(this).balance;
        (bool sent,) = to.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit Withdrawn(to, amount);
    }

    function setBaseURI(string memory baseURI_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setMintPrice(uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mintPrice = price;
        emit MintPriceSet(price);
    }

    function mintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    function mintPayable() public payable whenNotPaused nonReentrant {
        require(_mintPrice > 0, "Mint price not set");
        require(msg.value == _mintPrice, "Incorrect Ether value sent");
        uint256 tokenId = _nextTokenId;
        require(_maxSupply == 0 || tokenId < _maxSupply, "Max supply reached");
        unchecked {
            _nextTokenId = tokenId + 1;
        }
        _safeMint(msg.sender, tokenId);
    }

    receive() external payable {}

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
