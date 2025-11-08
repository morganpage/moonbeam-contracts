// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @notice Emitted when max supply is updated
event MaxSupplySet(uint256 newMaxSupply);

/// @notice Emitted when base URI is updated
event BaseURISet(string newBaseURI);

/// @notice Emitted when mint price is updated
event MintPriceSet(uint256 newPrice);

/// @notice Emitted when funds are withdrawn
event Withdrawn(address to, uint256 amount);

/// @notice Emitted when a token is minted with payment
event PaidMint(address indexed minter, address indexed to, uint256 indexed tokenId, uint256 price);

/// @notice Emitted when tokens are batch minted
event BatchMint(address indexed to, uint256 startTokenId, uint256 quantity);

/// @notice Emitted when the base URI is permanently frozen
event BaseURIFrozen();

/// @notice Emitted when Ether is received via receive() function
event EtherReceived(address indexed from, uint256 amount);

/// @notice Emitted when a batch URI is set for a range of tokens
event BatchBaseURISet(uint256 indexed startTokenId, uint256 indexed endTokenId, string baseURI);

/// @notice Emitted when a batch's token range is updated
event BatchRangeUpdated(
    uint256 indexed batchIndex,
    uint256 oldStartTokenId,
    uint256 oldEndTokenId,
    uint256 newStartTokenId,
    uint256 newEndTokenId
);

/// @notice Cannot set max supply below current supply
error MaxSupplyTooLow(uint256 requested, uint256 current);

/// @notice Max supply has been reached
error MaxSupplyReached();

/// @notice Mint price has not been set
error MintPriceNotSet();

/// @notice Incorrect payment amount
error IncorrectPayment(uint256 sent, uint256 required);

/// @notice No funds available to withdraw
error NoFundsToWithdraw();

/// @notice Failed to send Ether
error FailedToSendEther();

/// @notice Base URI is frozen and cannot be changed
error URIFrozen();

/// @notice Invalid batch quantity
error InvalidBatchQuantity();

/// @notice Invalid batch range (start must be less than end)
error InvalidBatchRange();

/// @notice Batch URI is frozen and cannot be changed
error BatchURIFrozen();

/// @notice Stores information about a batch of tokens with a specific base URI
struct BatchInfo {
    uint256 startTokenId;
    uint256 endTokenId;
    string baseURI;
    bool frozen;
}

/// @title OutminePets
/// @notice ERC721 NFT contract with role-based access control, pausable minting, and paid minting functionality
/// @dev Implements ERC721, ERC721Pausable, AccessControl, and ReentrancyGuard
contract OutminePets is ERC721, ERC721Pausable, AccessControl, ReentrancyGuard {
    uint256 private _nextTokenId;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    string private _baseTokenURI;
    uint256 private _maxSupply;
    uint256 private _mintPrice;
    bool private _baseURIFrozen;

    /// @dev Array of all batch information
    BatchInfo[] private _batches;

    /// @dev Mapping from token ID to batch index + 1 (0 means no batch assigned)
    mapping(uint256 => uint256) private _tokenIdToBatchIndex;

    /// @notice Initializes the contract with default roles and optional initial configuration
    /// @param initialMaxSupply Initial maximum supply (0 for unlimited)
    /// @param initialMintPrice Initial mint price in wei (0 for not set)
    constructor(uint256 initialMaxSupply, uint256 initialMintPrice) ERC721("OutminePets", "OMP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        if (initialMaxSupply > 0) {
            _maxSupply = initialMaxSupply;
            emit MaxSupplySet(initialMaxSupply);
        }

        if (initialMintPrice > 0) {
            _mintPrice = initialMintPrice;
            emit MintPriceSet(initialMintPrice);
        }
    }

    /// @notice Sets the maximum supply of tokens
    /// @dev Can only be called by admin, cannot be set below current supply
    /// @param maxSupply_ The new maximum supply (0 for unlimited)
    function setMaxSupply(uint256 maxSupply_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (maxSupply_ != 0 && maxSupply_ < _nextTokenId) revert MaxSupplyTooLow(maxSupply_, _nextTokenId);
        _maxSupply = maxSupply_;
        emit MaxSupplySet(maxSupply_);
    }

    /// @notice Returns the maximum supply
    /// @return The maximum supply (0 means unlimited)
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /// @notice Returns the current total supply of minted tokens
    /// @return The total number of tokens minted
    function totalSupply() public view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Mints a single token to the specified address
    /// @dev Can only be called by addresses with MINTER_ROLE
    /// @param to The address to mint the token to
    function mint(address to) public onlyRole(MINTER_ROLE) whenNotPaused {
        if (_maxSupply != 0 && _nextTokenId >= _maxSupply) revert MaxSupplyReached();
        _safeMint(to, _nextTokenId);
        unchecked {
            _nextTokenId++;
        }
    }

    /// @notice Batch mints multiple tokens to the specified address
    /// @dev More gas efficient than calling mint() multiple times
    /// @param to The address to mint the tokens to
    /// @param quantity The number of tokens to mint
    function mintBatch(address to, uint256 quantity) public onlyRole(MINTER_ROLE) whenNotPaused {
        if (quantity == 0) revert InvalidBatchQuantity();
        if (_maxSupply != 0 && _nextTokenId + quantity > _maxSupply) revert MaxSupplyReached();

        uint256 startTokenId = _nextTokenId;
        for (uint256 i = 0; i < quantity;) {
            _safeMint(to, _nextTokenId);
            unchecked {
                _nextTokenId++;
                i++;
            }
        }

        emit BatchMint(to, startTokenId, quantity);
    }

    /// @notice Pauses all token transfers and minting
    /// @dev Can only be called by addresses with PAUSER_ROLE
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpauses all token transfers and minting
    /// @dev Can only be called by addresses with PAUSER_ROLE
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Withdraws all contract balance to the specified address
    /// @dev Can only be called by admin
    /// @param to The address to send the funds to
    function withdraw(address payable to) public onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (address(this).balance == 0) revert NoFundsToWithdraw();
        uint256 amount = address(this).balance;
        (bool sent,) = to.call{value: amount}("");
        if (!sent) revert FailedToSendEther();
        emit Withdrawn(to, amount);
    }

    /// @notice Sets the base URI for token metadata
    /// @dev Can only be called by admin, unless URI is frozen
    /// @param baseURI_ The new base URI
    function setBaseURI(string memory baseURI_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_baseURIFrozen) revert URIFrozen();
        _baseTokenURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    /// @notice Permanently freezes the base URI, preventing future changes
    /// @dev Can only be called by admin, this action is irreversible
    function freezeBaseURI() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseURIFrozen = true;
        emit BaseURIFrozen();
    }

    /// @notice Returns whether the base URI is frozen
    /// @return True if the base URI is frozen
    function isBaseURIFrozen() public view returns (bool) {
        return _baseURIFrozen;
    }

    /// @dev Internal function to get the base URI
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Returns the token URI for a given token ID
    /// @dev Checks for batch-specific URI first, then falls back to global base URI
    /// @param tokenId The token ID to query
    /// @return The complete token URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        // Check if token has a batch-specific URI (stored as batchIndex + 1)
        uint256 storedIndex = _tokenIdToBatchIndex[tokenId];
        if (storedIndex > 0) {
            uint256 batchIndex = storedIndex - 1;
            BatchInfo storage batch = _batches[batchIndex];
            if (bytes(batch.baseURI).length > 0) {
                return string(abi.encodePacked(batch.baseURI, Strings.toString(tokenId)));
            }
        }

        // Fall back to global base URI
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    /// @notice Sets a batch-specific base URI for a range of tokens
    /// @dev Can only be called by admin. Token range must be valid and not overlap with existing batches
    /// @param startTokenId The first token ID in the batch (inclusive)
    /// @param endTokenId The last token ID in the batch (inclusive)
    /// @param batchBaseURI The base URI for this batch
    function setBatchBaseURI(uint256 startTokenId, uint256 endTokenId, string memory batchBaseURI)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (startTokenId >= endTokenId) revert InvalidBatchRange();

        // Check if any token in this range already has a batch assignment
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            uint256 storedIndex = _tokenIdToBatchIndex[i];
            if (storedIndex > 0) {
                // Token already assigned to a batch, check if it's frozen
                uint256 existingBatchIndex = storedIndex - 1;
                if (_batches[existingBatchIndex].frozen) revert BatchURIFrozen();
            }
        }

        // Create new batch
        _batches.push(
            BatchInfo({startTokenId: startTokenId, endTokenId: endTokenId, baseURI: batchBaseURI, frozen: false})
        );

        uint256 newBatchIndex = _batches.length - 1;

        // Map all token IDs in the range to this batch (store batchIndex + 1)
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            _tokenIdToBatchIndex[i] = newBatchIndex + 1;
        }

        emit BatchBaseURISet(startTokenId, endTokenId, batchBaseURI);
    }

    /// @notice Updates the base URI for an existing batch
    /// @dev Can only be called by admin and only if the batch is not frozen
    /// @param batchIndex The index of the batch to update
    /// @param newBaseURI The new base URI for this batch
    function updateBatchBaseURI(uint256 batchIndex, string memory newBaseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (batchIndex >= _batches.length) revert InvalidBatchRange();
        if (_batches[batchIndex].frozen) revert BatchURIFrozen();

        _batches[batchIndex].baseURI = newBaseURI;

        emit BatchBaseURISet(_batches[batchIndex].startTokenId, _batches[batchIndex].endTokenId, newBaseURI);
    }

    /// @notice Updates the token range for an existing batch
    /// @dev Can only be called by admin and only if the batch is not frozen
    /// @param batchIndex The index of the batch to update
    /// @param newStartTokenId The new starting token ID for the batch (inclusive)
    /// @param newEndTokenId The new ending token ID for the batch (inclusive)
    function updateBatchRange(uint256 batchIndex, uint256 newStartTokenId, uint256 newEndTokenId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (batchIndex >= _batches.length) revert InvalidBatchRange();
        if (newStartTokenId >= newEndTokenId) revert InvalidBatchRange();

        BatchInfo storage batch = _batches[batchIndex];
        if (batch.frozen) revert BatchURIFrozen();

        uint256 storageIndex = batchIndex + 1;
        uint256 oldStart = batch.startTokenId;
        uint256 oldEnd = batch.endTokenId;

        // Remove tokens that are no longer in the batch range
        for (uint256 tokenId = oldStart; tokenId <= oldEnd; tokenId++) {
            if (_tokenIdToBatchIndex[tokenId] == storageIndex
                && (tokenId < newStartTokenId || tokenId > newEndTokenId))
            {
                _tokenIdToBatchIndex[tokenId] = 0;
            }
        }

        // Assign tokens in the new range to this batch
        for (uint256 tokenId = newStartTokenId; tokenId <= newEndTokenId; tokenId++) {
            uint256 storedIndex = _tokenIdToBatchIndex[tokenId];
            if (storedIndex == storageIndex) {
                continue;
            }
            if (storedIndex > 0) {
                uint256 existingBatchIndex = storedIndex - 1;
                if (_batches[existingBatchIndex].frozen) revert BatchURIFrozen();
            }
            _tokenIdToBatchIndex[tokenId] = storageIndex;
        }

        batch.startTokenId = newStartTokenId;
        batch.endTokenId = newEndTokenId;

        emit BatchRangeUpdated(batchIndex, oldStart, oldEnd, newStartTokenId, newEndTokenId);
        emit BatchBaseURISet(newStartTokenId, newEndTokenId, batch.baseURI);
    }

    /// @notice Permanently freezes a batch URI, preventing future changes
    /// @dev Can only be called by admin, this action is irreversible
    /// @param batchIndex The index of the batch to freeze
    function freezeBatchBaseURI(uint256 batchIndex) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (batchIndex >= _batches.length) revert InvalidBatchRange();
        _batches[batchIndex].frozen = true;
    }

    /// @notice Returns the batch information for a given token ID
    /// @param tokenId The token ID to query
    /// @return The batch information (returns empty batch if no batch is assigned)
    function getBatchInfo(uint256 tokenId) public view returns (BatchInfo memory) {
        uint256 storedIndex = _tokenIdToBatchIndex[tokenId];
        if (storedIndex > 0) {
            return _batches[storedIndex - 1];
        }
        return BatchInfo({startTokenId: 0, endTokenId: 0, baseURI: "", frozen: false});
    }

    /// @notice Returns the number of batches
    /// @return The total number of batches
    function getBatchCount() public view returns (uint256) {
        return _batches.length;
    }

    /// @notice Returns batch information by index
    /// @param batchIndex The index of the batch
    /// @return The batch information
    function getBatchByIndex(uint256 batchIndex) public view returns (BatchInfo memory) {
        if (batchIndex >= _batches.length) revert InvalidBatchRange();
        return _batches[batchIndex];
    }

    /// @notice Sets the mint price for public minting
    /// @dev Can only be called by admin
    /// @param price The new mint price in wei
    function setMintPrice(uint256 price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mintPrice = price;
        emit MintPriceSet(price);
    }

    /// @notice Returns the current mint price
    /// @return The mint price in wei
    function mintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    /// @notice Mints a token to the caller with payment
    /// @dev Requires exact payment of mint price, protected against reentrancy
    function mintPayable() public payable whenNotPaused nonReentrant {
        if (_mintPrice == 0) revert MintPriceNotSet();
        if (msg.value != _mintPrice) revert IncorrectPayment(msg.value, _mintPrice);
        if (_maxSupply != 0 && _nextTokenId >= _maxSupply) revert MaxSupplyReached();

        uint256 tokenId = _nextTokenId;
        unchecked {
            _nextTokenId++;
        }
        _safeMint(msg.sender, tokenId);

        emit PaidMint(msg.sender, msg.sender, tokenId, _mintPrice);
    }

    /// @notice Mints a token to a specified recipient with payment
    /// @dev Requires exact payment of mint price, allows gifting tokens
    /// @param to The address to mint the token to
    function mintPayableTo(address to) public payable whenNotPaused nonReentrant {
        if (_mintPrice == 0) revert MintPriceNotSet();
        if (msg.value != _mintPrice) revert IncorrectPayment(msg.value, _mintPrice);
        if (_maxSupply != 0 && _nextTokenId >= _maxSupply) revert MaxSupplyReached();

        uint256 tokenId = _nextTokenId;
        unchecked {
            _nextTokenId++;
        }
        _safeMint(to, tokenId);

        emit PaidMint(msg.sender, to, tokenId, _mintPrice);
    }

    /// @notice Receives Ether sent to the contract
    /// @dev Emits an event for transparency
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @dev Internal function to update token ownership
    /// @dev Overrides both ERC721 and ERC721Pausable
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @notice Checks if the contract supports a given interface
    /// @param interfaceId The interface identifier to check
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
