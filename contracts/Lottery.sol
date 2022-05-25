// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

import "./NFT.sol";

/*
Before operating the lottery, the lottery manager buys a batch of collectibles,
and mints a Non Fungible Token (NFT) for each of them.
A new round may only be opened by the lottery operator.
Opening a new round is allowed the first time, when the contract has 
been deployed, or when a previous round is finished.
*/
contract Lottery {
    /// Round is open
    event RoundOpened(uint256 _startingBlock, uint256 _finalBlock);

    /// Lottery is closed
    event LotteryClosed();

    /// Create a nft for a collectible
    event TokenMinted(address _to, uint256 _tokenId, string _image);

    /// User buys a ticket
    event TicketBought(
        address _buyer,
        uint8 _one,
        uint8 _two,
        uint8 _three,
        uint8 _four,
        uint8 _five,
        uint8 _powerball
    );

    /// Winning numbers are announced
    event WinningNumbersDrawn(
        uint8 _one,
        uint8 _two,
        uint8 _three,
        uint8 _four,
        uint8 _five,
        uint8 _powerball
    );

    event PrizeAssigned(address _to, uint256 _tokenId, string _image);

    event RoundFinished();

    string public constant COLLECTIBLES_REPO =
        "https://github.com/fedehsq/nft_lottery/master/collectibles/";

    address public manager;
    uint256 public roundDuration;
    uint256 public endRoundBlock;
    uint256 public kParam = 0;
    uint256 public tokenId = 0;

    bool public lotteryActive;
    bool public numbersExtracted;
    bool public roundFinished;

    uint256 public constant TICKET_PRICE = 1 gwei;
    NFT public nft;

    // Ticket bought by the user
    struct Ticket {
        uint8[5] numbers;
        uint8 powerball;
        address owner;
    }

    // Collectible is represented by a tokenId and the related image url
    struct Collectible {
        uint256 id;
        string image;
    }

    // Mapping between the class that the collectible belongs to and the collectible
    mapping(uint8 => Collectible[]) collectibles;

    Ticket[] public tickets;

    Ticket public winningTicket;

    /// @notice msg.sender is the owner of the contract
    /// @param _nftAddress address of the nft contract
    /// @param _roundDuration The duration of the round in block numbers.
    constructor(address _nftAddress, uint256 _roundDuration) payable {
        require(_roundDuration < 1000, "Round duration must be less than 1000");
        manager = msg.sender;
        nft = NFT(_nftAddress);
        roundDuration = _roundDuration;
        lotteryActive = true;
        // Open the furst new round
        endRoundBlock = block.number + roundDuration;
        emit RoundOpened(block.number, endRoundBlock);
    }

    /// @notice The lottery operator can open a new round.
    /// The lottery operator can only open a new round if the previous round is finished.
    /// @dev Throws unless `msg.sender` is the current owner or the lottery is not finished
    /// @dev Throws unless the lottery is active
    /// @dev Throws if the round is yet open
    function openRound() public {
        require(lotteryActive, "Lottery is not active");
        require(
            msg.sender == manager,
            "Only the operator con do this operation"
        );
        require(!isRoundActive(), "Round is already active");
        require(numbersExtracted, "Numbers have not been extracted yet");
        require(roundFinished, "Round is not finished yet");
        delete tickets;
        delete winningTicket;
        roundFinished = false;
        numbersExtracted = false;
        endRoundBlock = block.number + roundDuration;
        emit RoundOpened(block.number, endRoundBlock);
    }

    /// @notice The lottery operator can close the contract.
    /// If the round is active, refunds the users who bought tickets.
    /// @dev Throws unless `msg.sender` is the current owner or the lottery is not finished
    /// @dev Throws unless the lottery is active
    function closeLottery() public {
        require(
            msg.sender == manager,
            "Only the operator con do this operation"
        );
        require(lotteryActive, "Lottery is not active");
        if (isRoundActive()) {
            for (uint256 i = 0; i < tickets.length; i++) {
                payable(tickets[i].owner).transfer(TICKET_PRICE);
            }
        }
        lotteryActive = false;
        emit LotteryClosed();
    }

    /// @notice The lottery operator can mint new token.
    /// The name of the image is the tokenId.
    /// @dev Throws unless `msg.sender` is the current owner or the class (rank) is not valid
    /// @dev Throws unless the lottery is active
    /// @dev Throws unless the number of collectibles is less than 8 or the number of tickets
    function mint() public {
        require(
            msg.sender == manager,
            "Only the operator con do this operation"
        );
        require(lotteryActive, "Lottery is not active");
        uint8 class = uint8((generateRandomNumber() % 8) + 1);
        // id of the collectible is the index of the collectible in the array
        tokenId++;
        string memory image = string(
            abi.encodePacked(
                COLLECTIBLES_REPO,
                Strings.toString(tokenId),
                ".svg"
            )
        );
        collectibles[class].push(Collectible(tokenId, image));
        nft.mint(tokenId, image);
        emit TokenMinted(msg.sender, tokenId, image);
    }

    /// @notice The user can buy a ticket.
    /// @dev Throws unless `one`, `two`, `three`, `four`, `five`, `six` are valid numbers
    /// @dev Throws unless `msg.sender` has enough ether to buy the ticket
    /// @dev Throws unless `ticket` is unique
    /// @dev Throws unless the lottery is active
    /// @param _one The first number of the ticket
    /// @param _two The second number of the ticket
    /// @param _three The third number of the ticket
    /// @param _four The fourth number of the ticket
    /// @param _five The fifth number of the ticket
    /// @param _powerball The special powerball number of the ticket
    function buy(
        uint8 _one,
        uint8 _two,
        uint8 _three,
        uint8 _four,
        uint8 _five,
        uint8 _powerball
    ) public payable {
        require(lotteryActive, "Lottery is not active");
        require(isRoundActive(), "Round is not active");
        require(msg.value == TICKET_PRICE, "You need to send 1 gwei");
        require(_one >= 1 && _one <= 69, "Invalid number");
        require(_two >= 1 && _two <= 69, "Invalid number");
        require(_three >= 1 && _three <= 69, "Invalid number");
        require(_four >= 1 && _four <= 69, "Invalid number");
        require(_five >= 1 && _five <= 69, "Invalid number");
        require(_powerball >= 1 && _powerball <= 26, "Invalid number");
        //uint16 id = _one + _two + _three + _four + _five + _powerball;
        tickets.push(
            Ticket(
                sortTicketNumbers(_one, _two, _three, _four, _five),
                _powerball,
                msg.sender
            )
        );
        emit TicketBought(
            msg.sender,
            _one,
            _two,
            _three,
            _four,
            _five,
            _powerball
        );
    }

    /// @notice Check if the round is active.
    /// The round is active if the current block number < endRoundBlock
    /// @return True if the round is active, false otherwise.
    function isRoundActive() public view returns (bool) {
        return endRoundBlock >= block.number;
    }

    /// @notice Generate a random int.
    /// @return A random int.
    function generateRandomNumber() public returns (uint256) {
        kParam++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, kParam++)
                )
            );
    }

    /// @notice Draw winning numbers of the current lottery round
    /// @dev Throws unless `msg.sender` is the lottery operator
    /// @dev Throws unless `winner` is not defined
    /// @dev Throws unless `winningTicket` is not defined
    /// @dev Throws unless the lottery is active
    function drawNumbers() public {
        require(
            msg.sender == manager,
            "Only the operator con do this operation"
        );
        require(lotteryActive, "Lottery is not active");
        require(!isRoundActive(), "Round is not yet finished");
        require(!roundFinished, "Round is already finished");
        require(!numbersExtracted, "Won numbers are already drawn");

        uint8 one = uint8((generateRandomNumber() % 69) + 1);
        uint8 two = uint8((generateRandomNumber() % 69) + 1);
        uint8 three = uint8((generateRandomNumber() % 69) + 1);
        uint8 four = uint8((generateRandomNumber() % 69) + 1);
        uint8 five = uint8((generateRandomNumber() % 69) + 1);
        uint8 six = uint8((generateRandomNumber() % 26) + 1);
        //uint16 id = one + two + three + four + five + six;
        winningTicket = Ticket(
            sortTicketNumbers(one, two, three, four, five),
            six,
            address(0)
        );
        numbersExtracted = true;
        emit WinningNumbersDrawn(one, two, three, four, five, six);
    }

    /// @notice Distribute the prizes of the current lottery round
    /// @dev Throws unless `msg.sender` is the lottery operator
    /// @dev Throws unless `winner` is not defined
    /// @dev Throws unless `winningTicket` is already drawn
    /// @dev Throws unless the lottery is active
    function givePrizes() public {
        require(
            msg.sender == manager,
            "Only the operator con do this operation"
        );
        require(lotteryActive, "Lottery is not active");
        require(!isRoundActive(), "Round is not yet finished");
        require(numbersExtracted, "Won numbers are not drawn");
        require(!roundFinished, "Round is already finished");
        for (uint256 i = 0; i < tickets.length; i++) {
            // Check how many numbers count the winning ticket numbers
            uint8 count = 0;
            bool powerballMatch = false;
            for (uint256 j = 0; j < 5; j++) {
                if (
                    binarySearch(tickets[i].numbers[j], 0, 5, winningTicket.numbers)
                ) {
                    count++;
                }
                // Check if the powerball matches the winning ticket powerball
                if (tickets[i].powerball == winningTicket.powerball) {
                    powerballMatch = true;
                }
            }
            if (count > 0 || powerballMatch) {
                uint8 classPrize = getClassPrize(count, powerballMatch);
                // if the class is empty, mint a new collectible for the winner
                if (collectibles[classPrize].length == 0) {
                    mint();
                    nft.transferFrom(address(this), tickets[i].owner, tokenId);
                    emit PrizeAssigned(
                        tickets[i].owner,
                        tokenId,
                        string(
                            abi.encodePacked(
                                COLLECTIBLES_REPO,
                                Strings.toString(tokenId),
                                ".svg"
                            )
                        )
                    );
                } else {
                    uint256 collectibleIndex = generateRandomNumber() %
                        collectibles[classPrize].length;
                    uint256 id = collectibles[classPrize][collectibleIndex].id;
                    nft.transferFrom(address(this), tickets[i].owner, id);
                    emit PrizeAssigned(
                        tickets[i].owner,
                        id,
                        collectibles[classPrize][collectibleIndex].image
                    );
                }
            }
        }
        roundFinished = true;
        //sendCoin();
        emit RoundFinished();
    }

    /// @notice Binary search to find if a number is in an array of numbers
    /// @param number The number to search for
    /// @param numbers The array of numbers to search in
    /// @return True if the number is in the array, false otherwise
    function binarySearch(uint8 number, uint begin, uint end, uint8[5] memory numbers)
        public
        view
        returns (bool)
    {
        if (begin > end) {
            return false;
        }
        uint mid = (begin + end) / 2;
        if (numbers[mid] == number) {
            return true;
        } else if (numbers[mid] > number) {
            return binarySearch(number, begin, mid - 1, numbers);
        } else {
            return binarySearch(number, mid + 1, end, numbers);
        }
    }

    /* @notice Send the prize to one random winner if it exists otherwise send it to the a random user
    function sendCoin() internal {
        if (winners.length > 0) {
            // Send the prize to one winner in a random way
            uint256 winnerIndex = generateRandomNumber() % winners.length;
            payable(winners[winnerIndex]).transfer(
                tickets.length * TICKET_PRICE
            );
        } else {
            // Send the prize to one user in a random way
            uint256 winnerIndex = generateRandomNumber() % tickets.length;
            payable(tickets[winnerIndex].owner).transfer(
                tickets.length * TICKET_PRICE
            );
        }
    } */

    /// @notice Get the class prize of the current lottery round based on the number of matching numbers
    /// @param _count The number of matching numbers
    /// @param _powerballMatch True if the powerball matches the winning ticket powerball, false otherwise
    /// @dev Throws unless the lottery is active
    /// @return The class prize
    function getClassPrize(uint8 _count, bool _powerballMatch)
        internal
        view
        returns (uint8)
    {
        require(lotteryActive, "Lottery is not active");
        if (_count == 5) {
            if (_powerballMatch) {
                return 1;
            }
            return 2;
        } else if (_count == 4) {
            if (_powerballMatch) {
                return 3;
            }
            return 4;
        } else if (_count == 3) {
            if (_powerballMatch) {
                return 4;
            }
            return 5;
        } else if (_count == 2) {
            if (_powerballMatch) {
                return 5;
            }
            return 6;
        } else if (_count == 1) {
            if (_powerballMatch) {
                return 6;
            }
            return 7;
        } else if (_powerballMatch) {
            return 8;
        }
        return 0;
    }

    /// @notice Build the tickets number in ascending order
    /// @param _one The first number
    /// @param _two The second number
    /// @param _three The third number
    /// @param _four The fourth number
    /// @param _five The fifth number
    /// @return The ticket numbers in ascending order
    function sortTicketNumbers(
        uint8 _one,
        uint8 _two,
        uint8 _three,
        uint8 _four,
        uint8 _five
    ) internal pure returns (uint8[5] memory) {
        // Order the numbers in ascending order
        uint8[5] memory numbers = [_one, _two, _three, _four, _five];
        uint8 temp;
        for (uint256 i = 0; i < numbers.length; i++) {
            for (uint256 j = i + 1; j < numbers.length; j++) {
                if (numbers[i] > numbers[j]) {
                    temp = numbers[i];
                    numbers[i] = numbers[j];
                    numbers[j] = temp;
                }
            }
        }
        return numbers;
    }
}
