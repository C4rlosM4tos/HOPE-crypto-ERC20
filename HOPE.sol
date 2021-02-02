
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
import "./ERC20.sol";
import "./SafeMath.sol";
import "./ERC20Burnable.sol";

contract HOPE is ERC20, ERC20Burnable {
       using SafeMath for uint256;
    
    


      address payable public Fundcontract; //scam alert, read the contract to be sure, could be exit scam

    uint public bid;
    uint public ask;
    uint public volume;
    uint public totalFeesCollected;
    uint public feesLeftInContract;
    uint public claimedFees;
    bool public canInvest;
    bool public minFeeActive;
    uint public fee;
    uint public fundsCollectedTotal;
    uint public fundsRepaidTotal;
    uint public FundsLeftInContract;  //there could be other funds in the contract, like fees, this should be discarded for realValue;
    
    uint public indexOfOrders;
    uint public burnedToFund;
    uint public realBalance =payable(address(this)).balance;
    address payable public thisContract = payable(address(this));
   
    
    struct order {
        
        uint orderNumber;
        uint timeStamp;
        uint amount;
        bool buy;
        uint price;
        address participant;
        uint eth;
        uint fundingTokens;
        
        
    }
    
    mapping (address => bool) public owners;
    mapping (address => bool) public openProjects;
    mapping (uint => order) public orders;
    
    order[] public allOrdersArr;
    
    constructor(uint256 initsupply) public payable ERC20 ("Hopium", "HOPE") {
        _mint(msg.sender, initsupply.mul(10**18) );
        owners[msg.sender] = true;
        feesLeftInContract = 0;
        
      
        canInvest = true;
        FundsLeftInContract = msg.value;
     fundsCollectedTotal = FundsLeftInContract;
    }
    
    modifier onlyOwner{
        require(owners[msg.sender],
            
            "Only an owner can call this function."
        );
        _;
    }
     modifier onlyFundContract {
        require(
            msg.sender == Fundcontract,
            "Only the Fundcontract can call this function."
        );
        _;
    }
    


function closeFunding () public onlyOwner {
    canInvest = false;
}

function openFunding () public onlyOwner {
    canInvest = true;
}
function buy (uint amount, uint price, uint _fee) public payable returns (uint) {
    //free choice to donate or not
    require(canInvest, "funding is now closed, try again later");
    require(ask <= price, "user not willing to pay the ask price");
    
    
    if (!minFeeActive) {
        fee = _fee;
    }
    
    volume += amount;
    setPrice();
    uint priceToPay = ask.mul(amount);
    priceToPay = priceToPay.div(10**18);
    require(priceToPay > 1, "less than 1 wei, buy more");
    FundsLeftInContract += priceToPay;
    fundsCollectedTotal += priceToPay;
    priceToPay = priceToPay.add(fee);
    
   
    require(msg.value >= priceToPay, "not enough money send");
    
    indexOfOrders += 1;
    _mint(msg.sender, amount);

    if (priceToPay < msg.value) {
        
        require(priceToPay > 0);
        
        uint refund = msg.value.sub(priceToPay);
        msg.sender.transfer(refund);
    }
    
    order memory neworder = orders[indexOfOrders];
    neworder.orderNumber = indexOfOrders;
    neworder.timeStamp = block.number;
    neworder.amount = amount; //in wei
    neworder.buy = true;
    neworder.price = ask;
    neworder.participant = msg.sender;
    neworder.eth = priceToPay;
    neworder.fundingTokens = amount;
    
    orders[indexOfOrders] = neworder;
    allOrdersArr.push(neworder);
    
    setPrice();
    
    totalFeesCollected += fee;
    feesLeftInContract += fee;
    
    return indexOfOrders;
    
    
}
function addOwner (address payable newOwner) public onlyOwner {
    owners[newOwner] = true;
}

function checkPriceForXcoinsInWeiPerCoin(uint amountOfCoins) public view returns (uint pricePerCoin) {
    amountOfCoins = amountOfCoins;
    pricePerCoin = (amountOfCoins.div(10**18).mul(ask)).add(fee);
    
    
    return pricePerCoin;
    
    //should be front-end function, not on the smart contract itself
    
}
function sell (uint amount, uint minPrice, uint _fee) public returns (uint) {
    
    
    require(bid >= minPrice, "user not willing to pay the bid price");
    require(canInvest, "funding is now closed, try again later");
    if (!minFeeActive) {
        fee = _fee;
    }
    
    volume += amount;
       //to be adjusted when working front-end
     setPrice();
    
    uint ethToReceive = bid.mul(amount);
    ethToReceive = ethToReceive.div(10**18);
      require(ethToReceive <= FundsLeftInContract, "contract is too broke to pay that much");
    require (ethToReceive > 0, "nothing?");
    FundsLeftInContract = FundsLeftInContract.sub(ethToReceive); //receive by user
    fundsRepaidTotal += ethToReceive;
    totalFeesCollected += fee;
    feesLeftInContract += fee;
    ethToReceive = ethToReceive.sub(fee);
 

    
    indexOfOrders += 1;
    _burn(msg.sender, amount);
    
    msg.sender.transfer(ethToReceive);

   
  
    
    
    order memory neworder = orders[indexOfOrders];
    neworder.orderNumber = indexOfOrders;
    neworder.timeStamp = block.number;
    neworder.amount = amount; //in wei
    neworder.buy = false;
    neworder.price = bid;
    neworder.participant = msg.sender;
    neworder.eth = ethToReceive;
    neworder.fundingTokens = amount;
    
    orders[indexOfOrders] = neworder;
    allOrdersArr.push(neworder);
    
    setPrice();
   
    
    return indexOfOrders;
}

function setPrice () public {
    uint rvalue = RealValue(); //per coin?

    bid = rvalue.mul(99).div(100).sub(1 wei); //contract is willing to pay amount x for the tokens to burn them;
    require( bid >= 1 wei);
    ask = (rvalue.mul(101)).div(100).add(1 wei);
    
   // ask = rvalue.add(pip); // contract is offering newly minted tokens for the price of x;
    //the contract is asking 1% too much, and biding 1% too less, this gap will generate value for the hodlers and increase the real value, pumping up the price;
    //this 2% gap will also leave room for traders to trade the coin on uniswap instead of on this contract, resulting in possible arbitrage possibilities.
    //that way tokenholders have things they can do while they waiting for enough funding to fund real world fysical projects.
    //the contract will always offer the total supply of eth for 1% below the real value;
    
    
    
}
   
function RealValue () public  returns (uint) {
    if (FundsLeftInContract == 0) {
        FundsLeftInContract = 1;
    }
    uint rv =  (FundsLeftInContract.mul(10**18)).div(totalSupply()); //wei / hope  price too low for price per hwei real value per full coin // cutting off real value
  //value per hwei.
    
    require(rv >= 1 wei, 'real value is 1 wei or lower');
    
    return rv;
    
}


function setFee (uint amount) public onlyOwner {
    fee = amount;
}
function claimFees (uint amount) public onlyOwner {
    
    claimedFees += amount;
    feesLeftInContract = feesLeftInContract.sub(amount);
    require (feesLeftInContract >=  0, "not yet earned enough fees to claim that much");
    msg.sender.transfer(amount);
    
    
    
}

function setFundContract (address payable _fundcontract) public onlyOwner {
   Fundcontract = _fundcontract;
}


function registerProject (address payable projectToAdd) public onlyFundContract {
    openProjects[projectToAdd] = true;  //register in order to be able to receive funding
}


function fundProject ( uint amountOfTokens, address payable projectsAddress) public onlyFundContract returns (uint){
    
    require(openProjects[projectsAddress]);
     volume += amountOfTokens;
     burnedToFund += amountOfTokens;
     
  //  require(amountOfTokens >=10**18, 'you need to sell at least 1 full token');
    setPrice();
    uint ethToReceive = (RealValue().mul(10**18)).mul(amountOfTokens);  //dividing the tokens result in division by 0 error, so RealValue.mul10**18 instead as fix so we can sell less than 1 full token. (min 1 wei total value)
    //ethToReceive = ethToReceive.div(10**18);
   

    require(FundsLeftInContract >= ethToReceive, "not enough funds left in reserve for that");
    indexOfOrders += 1;
    _burn(msg.sender, amountOfTokens); // to stake in a projects, tokens must  be send to the fundingcontract. 
    FundsLeftInContract = FundsLeftInContract.sub(ethToReceive); //receive by user
    fundsRepaidTotal += ethToReceive;
    
    
    projectsAddress.transfer(ethToReceive);
    
    
    
    order memory neworder = orders[indexOfOrders];
    neworder.orderNumber = indexOfOrders;
    neworder.timeStamp = block.number;
    neworder.amount = amountOfTokens; //in wei
    neworder.buy = false;
    neworder.price = bid;
    neworder.participant = msg.sender;
    neworder.eth = ethToReceive;
    neworder.fundingTokens = amountOfTokens;
    
    orders[indexOfOrders] = neworder;
    allOrdersArr.push(neworder);
    
    setPrice();
   
    
    return indexOfOrders;
}

function removeOwner () public {
    //only an owner can remove himself, not other owners.
    owners[msg.sender] = false;
}

}


