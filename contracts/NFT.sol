// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ERC721.sol";

contract NFT is ERC721 {
    // tokenId - owner of the token
    mapping(uint256 => address) owners;

    // owner of the token - number of nfts owned by the owner
    mapping(address => uint256) balances;

    // delegate someone else to send the nft
    mapping(uint256 => address) approved;

    // owner of the token - addresses that are approved to send the nft
    mapping(address => mapping(address => bool)) approvedForAll;

    function mint(uint256 _tokenId) public {
        require(owners[_tokenId] == address(0));
        owners[_tokenId] = msg.sender;
        balances[msg.sender]++;
    }

    function ownerOf(uint256 _tokenId) public view override returns (address) {
        return owners[_tokenId];
    }

    function balanceOf(address _owner) public view override returns (uint256) {
        return balances[_owner];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable override {
        //require(msg.sender == manager);
        require(
            // owner
            _from == msg.sender ||
                // approved
                _from == approved[_tokenId] ||
                // approved for all (operator)
                approvedForAll[owners[_tokenId]][_from]
        );
        require(_to != _from);
        require(owners[_tokenId] == _from);
        require(balances[_from] > 0);
        owners[_tokenId] = _to;
        balances[_from]--;
        balances[_to]++;
        emit Transfer(_from, _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId)
        external
        payable
        override
    {
        // check if the approve is call by the owner of the token or by operator
        require(
            msg.sender == owners[_tokenId] ||
                approvedForAll[owners[_tokenId]][msg.sender],
            "Only the owner or operator can approve"
        );
        approved[_tokenId] = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    function getApproved(uint256 _tokenId)
        public
        view
        override
        returns (address)
    {
        return approved[_tokenId];
    }

    function setApprovalForAll(address _operator, bool _approved)
        external
        override
    {
        approvedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _owner, address _operator)
        external
        view
        virtual
        override
        returns (bool)
    {
        return approvedForAll[_owner][_operator];
    }
}