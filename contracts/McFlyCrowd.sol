pragma solidity ^0.4.19;

import "./SafeMath.sol";
import "./McFlyToken.sol";
import "./Haltable.sol";
import "./MultiOwners.sol";


contract McFlyCrowd is MultiOwners, Haltable {
    using SafeMath for uint256;

    // Total ETH received during WAVES, TLP1.2 & window[1-5]
    uint256 public counter_in; // tlp2
    
    // minimum ETH to partisipate in window 1-5
    uint256 public minETHin = 1e18; // 1 ETH

    // Token
    McFlyToken public token;

    // Withdraw wallet
    address public wallet;

    // start and end timestamp for TLP 1.2, other values callculated
    uint public sT2; // startTimeTLP2
    uint public dTLP2 = 56 days; // days of TLP2
    uint public dBt = 60 days; // days between Windows
    uint public dW = 12 days; // 12 days for 3,4,5,6,7 windows;

    // Cap maximum possible tokens for minting
    uint256 public hardCapInTokens = 1800e24; // 1,800,000,000 MFL

    // maximum possible tokens for sell 
    uint256 public mintCapInTokens = hardCapInTokens.mul(70).div(100); // 1,260,000,000 MFL

    // tokens crowd within TLP2
    uint256 public crowdTokensTLP2;

    // tokens crowd before this contract (MFL tokens)
    uint256 public preMcFlyTotalSupply;

    // maximum possible tokens for fund minting
    uint256 public fundTokens = hardCapInTokens.mul(15).div(100); // 270,000,000 MFL
    uint256 public fundTotalSupply;
    address public fundMintingAgent;

    // WAVES
    // maximum possible tokens to convert from WAVES
    uint256 public wavesTokens = 100e24; // 100,000,000 MFL
    address public wavesAgent;
    address public wavesGW;

    // Vesting for team, advisory, reserve.
    uint256 VestingPeriodInSeconds = 30 days; // 24 month
    uint256 VestingPeriodsCount = 24;

    // Team 10%
    uint256 _teamTokens;
    uint256 public teamTotalSupply;
    address public teamWallet;

    // Bounty 5% (2% + 3%)
    // Bounty online 2%
    uint256 _bountyOnlineTokens;
    address public bountyOnlineWallet;
    address public bountyOnlineGW;

    // Bounty offline 3%
    uint256 _bountyOfflineTokens;
    address public bountyOfflineWallet;

    // Advisory 5%
    uint256 _advisoryTokens;
    uint256 public advisoryTotalSupply;
    address public advisoryWallet;

    // Reserved for future 9%
    uint256 _reservedTokens;
    uint256 public reservedTotalSupply;
    address public reservedWallet;

    // AirDrop 1%
    uint256 _airdropTokens;
    address public airdropWallet;
    address public airdropGW;

    // PreMcFly wallet (MFL)
    uint256 _preMcFlyTokens;
    address public preMcFlyWallet;

    struct Ppl {
        address addr;
        uint256 amount;
    }

    struct Window {
        bool active;
        uint256 totalEthInWindow;
        uint totalTransactionCount;
        uint refundIndex;
        uint256 tokenPerWindow;
        mapping (uint => Ppl) ppls;
    }
    mapping (uint => Window) windows;

    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event TokenPurchaseInWindow(address indexed beneficiary, uint256 value);
    event TransferOddEther(address indexed beneficiary, uint256 value);
    event FundMinting(address indexed beneficiary, uint256 value);
    event WithdrawVesting(address indexed beneficiary, uint256 period, uint256 value);
    event TokenWithdrawAtWindow(address indexed beneficiary, uint256 value);
    event SetFundMintingAgent(address new_agent);
    event SetStartTimeTLP2(uint256 new_startTimeTLP2);
    event SetMinETHincome(uint256 new_minETHin);

    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;
        require(nonZeroPurchase);
        _;        
    }

    // constructor run once!
    function McFlyCrowd(
        uint _startTimeTLP2,
        uint256 _preMcFlyTotalSupply,
        address _wallet,
        address _wavesAgent,
        address _wavesGW,
        address _fundMintingAgent,
        address _teamWallet,
        address _bountyOnlineWallet,
        address _bountyOnlineGW,
        address _bountyOfflineWallet,
        address _advisoryWallet,
        address _reservedWallet,
        address _airdropWallet,
        address _airdropGW,
        address _preMcFlyWallet
    ) public {
        require(_startTimeTLP2 >= block.timestamp);
        require(_preMcFlyTotalSupply > 0);
        require(_wallet != 0x0);
        require(_wavesAgent != 0x0);
        require(_wavesGW != 0x0);
        require(_fundMintingAgent != 0x0);
        require(_teamWallet != 0x0);
        require(_bountyOnlineWallet != 0x0);
        require(_bountyOnlineGW != 0x0);
        require(_bountyOfflineWallet != 0x0);
        require(_advisoryWallet != 0x0);
        require(_reservedWallet != 0x0);
        require(_airdropWallet != 0x0);
        require(_airdropGW != 0x0);
        require(_preMcFlyWallet != 0x0);

        token = new McFlyToken();

        wallet = _wallet;

	    sT2 = _startTimeTLP2;
        setStartEndTimeTLP(_startTimeTLP2);

        wavesAgent = _wavesAgent;
        wavesGW = _wavesGW;

        fundMintingAgent = _fundMintingAgent;

        teamWallet = _teamWallet;
        bountyOnlineWallet = _bountyOnlineWallet;
        bountyOnlineGW = _bountyOnlineGW;
        bountyOfflineWallet = _bountyOfflineWallet;
        advisoryWallet = _advisoryWallet;
        reservedWallet = _reservedWallet;
        airdropWallet = _airdropWallet;
        airdropGW = _airdropGW;
        preMcFlyWallet = _preMcFlyWallet;

        // Mint all tokens and than control it by vesting
        _preMcFlyTokens = _preMcFlyTotalSupply; // McFly for thansfer to old MFL owners
        token.mint(preMcFlyWallet, _preMcFlyTokens);
        token.allowTransfer(preMcFlyWallet);
        crowdTokensTLP2 = crowdTokensTLP2.add(_preMcFlyTokens);

        token.mint(wavesAgent, wavesTokens); // 100,000,000 MFL
        token.allowTransfer(wavesAgent);
        token.allowTransfer(wavesGW);
        crowdTokensTLP2 = crowdTokensTLP2.add(wavesTokens);

        // rewards !!!!
        _teamTokens = 180e24; // 180,000,000 MFL
        token.mint(this, _teamTokens); // mint to contract address

        _bountyOnlineTokens = 36e24; // 36,000,000 MFL
        token.mint(bountyOnlineWallet, _bountyOnlineTokens);
        token.allowTransfer(bountyOnlineWallet);
        token.allowTransfer(bountyOnlineGW);

        _bountyOfflineTokens = 54e24; // 54,000,000 MFL
        token.mint(bountyOfflineWallet, _bountyOfflineTokens);
        token.allowTransfer(bountyOfflineWallet);

        _advisoryTokens = 90e24; // 90,000,000 MFL
        token.mint(this, _advisoryTokens);

        _reservedTokens = 162e24; // 162,000,000 MFL
        token.mint(this, _reservedTokens);

        _airdropTokens = 18e24; // 18,000,000 MFL
        token.mint(airdropWallet, _airdropTokens);
        token.allowTransfer(airdropWallet);
        token.allowTransfer(airdropGW);
    }

    function withinPeriod() constant public returns (bool) {
        bool withinPeriodTLP2 = (now >= sT2 && now <= (sT2+dTLP2));
        return withinPeriodTLP2;
    }

    // @return false if crowd event was ended
    function running() constant public returns (bool) {
        return withinPeriod() && !token.mintingFinished();
    }

    // @return current stage name
    function stageName() constant public returns (uint) {
        uint eT2 = sT2+dTLP2;

        if (now < sT2) {return 101;} // not started
        if (now >= sT2 && now <= eT2) {return (102);} // TLP1.2

        if (now > eT2 && now < eT2+dBt) {return (103);} // preTLP1.3
        if (now >= (eT2+dBt) && now <= (eT2+dBt+dW)) {return (0);} // TLP1.3
        if (now > (eT2+dBt+dW) && now < (eT2+dBt+dW+dBt)) {return (104);} // preTLP1.4
        if (now >= (eT2+dBt+dW+dBt) && now <= (eT2+dBt+dW+dBt+dW)) {return (1);} // TLP1.4
        if (now > (eT2+dBt+dW+dBt+dW) && now < (eT2+dBt+dW+dBt+dW+dBt)) {return (105);} // preTLP1.5
        if (now >= (eT2+dBt+dW+dBt+dW+dBt) && now <= (eT2+dBt+dW+dBt+dW+dBt+dW)) {return (2);} // TLP1.5
        if (now > (eT2+dBt+dW+dBt+dW+dBt+dW) && now < (eT2+dBt+dW+dBt+dW+dBt+dW+dBt)) {return (106);} // preTLP1.6
        if (now >= (eT2+dBt+dW+dBt+dW+dBt+dW+dBt) && now <= (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW)) {return (3);} // TLP1.6
        if (now > (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW) && now < (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW+dBt)) {return (107);} // preTLP1.7
        if (now >= (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW+dBt) && now <= (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW+dBt+dW)) {return (4);} // TLP1.7"
        if (now > (eT2+dBt+dW+dBt+dW+dBt+dW+dBt+dW+dBt+dW)) {return (200);} // Finished
        return (201); // unknown
    }

    /*
     * @dev change agent for waves minting
     * @praram agent - new agent address
     */
    function setFundMintingAgent(address agent) onlyOwner public {
        fundMintingAgent = agent;
        SetFundMintingAgent(agent);
    }
    
    /*
     * @dev change min ETH income during Window1-5
     * @param minETHin 
     */
    function setMinETHin(uint256 _minETHin) onlyOwner public {
        minETHin = _minETHin;
        SetMinETHincome(_minETHin);
    }

    /*
     * @dev set TLP1.X (2-7) start & end dates
     * @param _at - new or old start date
     */
    function setStartEndTimeTLP(uint256 _at) onlyOwner public {
        require(block.timestamp < sT2); // forbid change time when TLP1.2 is active
        require(block.timestamp < _at); // should be great than current block timestamp

        sT2 = _at;
        SetStartTimeTLP2(_at);
    }

    /*
     * @dev Large Token Holder minting 
     * @param to - mint to address
     * @param amount - how much mint
     */
    function fundMinting(address to, uint256 amount) stopInEmergency public {
        require(msg.sender == fundMintingAgent || isOwner());
        require(block.timestamp < sT2);
        require(fundTotalSupply + amount <= fundTokens);
        require(token.totalSupply() + amount <= hardCapInTokens);

        fundTotalSupply = fundTotalSupply.add(amount);
        FundMinting(to, amount);
        token.mint(to, amount);
    }

    /*
     * @dev calculate amount
     * @param  _value - ether to be converted to tokens
     * @param  at - current time
     * @param  _totalSupply - total supplied tokens
     * @return tokens amount that we should send to our dear ppl
     * @return odd ethers amount, which contract should send back
     */
    function calcAmountAt(
        uint256 amount,
        uint256 at,
        uint256 _totalSupply
    ) public constant returns (uint256, uint256) {
        uint256 estimate;
        uint256 price;

        if (at >= sT2 && at <= (sT2+dTLP2)) {
            if (at < sT2 + 7 days) {price = 12e13;} else
            if (at < sT2 + 14 days) {price = 14e13;} else  
            if (at < sT2 + 21 days) {price = 16e13;} else 
            if (at < sT2 + 28 days) {price = 18e13;} else 
            if (at < sT2 + 35 days) {price = 20e13;} else 
            if (at < sT2 + 42 days) {price = 22e13;} else
            if (at < sT2 + 49 days) {price = 24e13;} else 
            if (at < sT2 + 56 days) {price = 26e13;} else
            {revert();}
        } else {
            revert();
        }

        estimate = _totalSupply.add(amount.mul(1e18).div(price));

        if (estimate > hardCapInTokens) {
            return (
                hardCapInTokens.sub(_totalSupply),
                estimate.sub(hardCapInTokens).mul(price).div(1e18)
            );
        }
        return (estimate.sub(_totalSupply), 0);
    }

    // check private !!!!!!!!
     function contribute(uint _winNum, address _contributor, uint256 _amount) private { 
        Window storage w = windows[_winNum];
        w.ppls[w.totalTransactionCount++] = Ppl({addr: _contributor, amount: _amount});
        w.totalEthInWindow.add(msg.value);
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable public {
        return getTokens(msg.sender);
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function getTokens(address contributor) payable stopInEmergency validPurchase public {
        uint256 amount;
        uint256 oddEthers;
        uint256 ethers;
        uint256 __at;
        uint _winNum;
        
        __at = block.timestamp;

        require(contributor != 0x0);
       
        if (withinPeriod()) {
        
            (amount, oddEthers) = calcAmountAt(msg.value, __at, token.totalSupply());  // recheck!!!
  
            require(amount + token.totalSupply() <= hardCapInTokens);

            ethers = msg.value.sub(oddEthers);

            token.mint(contributor, amount); // fail if minting is finished
            TokenPurchase(contributor, ethers, amount);
            counter_in.add(ethers);
            crowdTokensTLP2 = crowdTokensTLP2.add(amount);

            if (oddEthers > 0) {
                require(oddEthers < msg.value);
                TransferOddEther(contributor, oddEthers);
                contributor.transfer(oddEthers);
            }

            wallet.transfer(ethers);
        } else {
            require(msg.value >= minETHin); // checks min ETH income
            _winNum = stageName();
            require(_winNum >= 0 && _winNum < 5);
            contribute(_winNum, contributor, msg.value);
            TokenPurchaseInWindow(contributor, msg.value);
        }
    }

    // close window N1-5
    function closeWindow(uint _winNum) onlyOwner stopInEmergency public {
        require(windows[_winNum].active);
	    windows[_winNum].active = false;

        wallet.transfer(this.balance);
    }

    // transfer tokens to ppl accts (window1-5)
    function sendTokensWindow(uint256 _winNum) onlyOwner stopInEmergency public {
        uint256 _tokenPerETH;
        uint256 _tokenToSend = 0;
        Window storage w = windows[_winNum];
        uint256 index = w.refundIndex;

        require(w.active);
        require(w.totalEthInWindow > 0 && w.totalTransactionCount > 0);

        _tokenPerETH = w.tokenPerWindow.div(w.totalEthInWindow); // max McFly in window / ethInWindow
 
        while (index < w.totalTransactionCount && msg.gas > 120000) {
	        _tokenToSend = _tokenPerETH.mul(w.ppls[index].amount);
            token.transfer(w.ppls[index].addr, _tokenToSend);
	        TokenWithdrawAtWindow(w.ppls[index].addr, _tokenToSend);
            w.ppls[index].amount = 0;
            index++;
        }
        w.refundIndex = index;
    }

    // function newWindow(uint _winNum, uint256 _maxTokenPerWindow) onlyOwner stopInEmergency public {
    function newWindow(uint _winNum, uint256 __tokenPerWindow) private {
        windows[_winNum] = Window(true, 0, 0, 0, __tokenPerWindow);
    }

    // Finish crowdsale TLP1.2 period and open window1-5 crowdsale
    function finishCrowd() onlyOwner public {
        uint256 _tokenPerWindow;
        require(now > (sT2.add(dTLP2)) || hardCapInTokens == token.totalSupply());
        require(!token.mintingFinished());

        _tokenPerWindow = (mintCapInTokens.sub(crowdTokensTLP2).sub(fundTotalSupply)).div(5);
        token.mint(this, _tokenPerWindow.mul(5)); // mint to contract address
        // shoud be MAX tokens minted!!! 1,800,000,000
        for (uint y = 0; y < 5; y++) {
            newWindow(y, _tokenPerWindow);
        }

        token.finishMinting();
    }

    // vesting for team, advisory and reserved
    function vestingWithdraw(address withdrawWallet, uint256 withdrawTokens, uint256 withdrawTotalSupply) private {
        require(token.mintingFinished());
        require(msg.sender == withdrawWallet || isOwner());

        uint256 currentPeriod = (block.timestamp.sub(sT2.add(dTLP2))).div(VestingPeriodInSeconds);
        if (currentPeriod > VestingPeriodsCount) {
            currentPeriod = VestingPeriodsCount;
        }
        uint256 tokenAvailable = withdrawTokens.mul(currentPeriod).div(VestingPeriodsCount).sub(withdrawTotalSupply);  // RECHECK!!!!!

        require(withdrawTotalSupply + tokenAvailable <= withdrawTokens);

        withdrawTotalSupply = withdrawTotalSupply.add(tokenAvailable);

	    WithdrawVesting(withdrawWallet, currentPeriod, tokenAvailable);
        token.transfer(withdrawWallet, tokenAvailable);
    }

    function teamWithdraw() public {
	    vestingWithdraw(teamWallet, _teamTokens, teamTotalSupply);
    }

    function advisoryWithdraw() public {
	    vestingWithdraw(advisoryWallet, _advisoryTokens, advisoryTotalSupply);
    }

    function reservedWithdraw() public {
	    vestingWithdraw(reservedWallet, _reservedTokens, reservedTotalSupply);
    }
}
