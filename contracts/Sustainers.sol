pragma solidity >=0.4.25 <0.7.0;

// The Sustainers contract specifies the workings of a system made up of Purposes and their stewards, constrained only by time.
// Each Purpose has a predefined sustainability that can be contributed to by any sustainer, after which the surplus get's redistributed proportionally to sustainers.
contract Sustainers {

    // The Purpose structure represents a purpose envisioned by a steward, and accounts for who has contributed to the vision.
    struct Purpose {
        // The description of this purpose. This is an opportunity for the steward to make the case
        // for this Purpose's sutainability on-chain.
        string description;

        // The address which is stewarding this purpose.
        address steward;

        // The amount that represents sustainability for this purpose.
        uint sustainability;

        // The number of days this Purpose can be sustained according to `sustainability`.
        uint duration;

        // The time when this Purpose will become active.
        uint start;

        // The running amount that's been contributed to sustaining this purpose.
        unit sustainment;

        // The addresses who have helped to sustain this purpose.
        address[] sustainers;

        // The amount each address has contributed to the sustaining of this purpose.
        mapping(address => uint) sustainments;

        // The net amount each address has contributed to the sustaining of this purpose after redistribution.
        mapping(address => uint) netSustainments;

        // The amount that has been redistributed to each address as a consequence of abundant sustainment of this Purpose.
        mapping(address => uint) redistribution;
    }

    // The current Chapter, whos Purposes are immutable once the Purpose receives some sustainment.
    // Chapter currentChapter;
    mapping(uint => Purpose) currentPurposes;

    // The next Chapter, which is entirely mutable until it becomes the current Chapter.
    // Chapter nextChapter;
    mapping(uint => Purpose) nextPurposes;

    // The amount that has been redistributed to each address as a consequence of overall abundance.
    mapping(address => uint) redistribution;

    // IERC20 public daiInstance;

    // constructor() public {
    // balances[tx.origin] = 10000;
    // }
    // constructor(IERC20 _daiInstance) public {
    //   daiInstance = _daiInstance;
    // }

    function updateSustainability(uint _sustainability) public {
      Purpose storage purposeToUpdate(msg.sender);
      purpose.sustainability = _sustainability;
    }

    function updateDuration(uint _duration) public {
      Purpose storage purposeToUpdate(msg.sender);
      purpose.duration = _duration;
    }
    
    function updateDescription(string _description) public {
      Purpose storage purposeToUpdate(msg.sender);
      purpose.description = _description;
    }

    // Contribute a specified amount to the sustainability of a Purpose stewarded by the specified address.
    // If the amount results in surplus, redistribute the surplus proportionally to sustainers of the Purpose.
    function sustain(address _steward, uint _amount) public {

      // The function operates on the state of the current Purpose belonging to the specified steward.
      Purpose storage currentPurpose = currentPurposes[_steward];

      // If the current time is greater than the current Chapter's endTime, progress to the next Chapter.
      while (now > currentPurpose.start * currentPurpose.duration * days) {
        progressPurpose();
        sustain(_steward, _amount);
        return;
      }

      require(currentPurpose > 0, "This account isn't stewarding a purpose yet.");
      require(_amount > 0, "The sustainment amount should be positive.")

      //// ************* Before changing state:
      ///
      // Save the amount to send to the steward of the Purpose.
      uint amountToSendToSteward = currentPurpose.sustainability - currentPurpose.sustainment > amount ? amount : currentPurpose.sustainability - currentPurpose.sustainment;
      // Save if the message sender is contributing to this Purpose for the first time.
      bool isNewSustainer = currentPurpose.sustainments[msg.sender] == 0;
      ///
      //// *************


      //// ************* TODO: Transfer an amount to the steward:
      ///
      // bool success = daiInstance.transferFrom(msg.sender, address(this), amountToSend);
      // require(success, "Transfer failed.");
      ///
      //// *************


      //// ************* Update the state of the Purpose:
      ///
      // Increment the sustainments to the Purpose made by the message sender.
      currentPurpose.sustainments[msg.sender] += _amount;
      // Increment the total amount contributed to the sustainment of the Purpose.
      currentPurpose.sustainment += _amount;
      // Add the message sender as a sustainer of the Purpose if this is the first sustainment it's making to it.
      if (isNewSustainer) {
        currentPurpose.sustainers.push(msg.sender);
      }
      ///
      //// *************


      //// ************* Manage redistribution:
      /// 
      // Save the amount to distribute before changing the state.
      uint amountToDistribute = currentPurpose.sustainment <= currentPurpose.sustainability ? 0 : currentPurpose.sustainment - currentPurpose.sustainability;
      // Redistribute any leftover amount.
      if (amountToDistribute > 0) {
        redistribute(currentPurpose, amountToDistribute);
      }
      /// 
      //// *************
    }
 
    // A sender can withdrawl funds that have been redistributed to it.
    function withdrawl(uint _amount) public {
      require(redistribution[msg.sender] > 0, "There's nothing to collect.")

      //TODO: transfer to msg.sender wallet; 
    }

    function progressPurpose(address _steward) internal {
      //TODO not sure consequence of referencing like this.
      Purpose currentPurpose = currentPurposes[_steward];
      unit currentPurposeDuration = currentPurpose.duration;
      unit currentPurposeSustainability = currentPurpose.sustainability;
      unit currentPurposeDescription = currentPurpose.description;

      //TODO: fix up.
      currentPurposes[_steward] = nextChapter[_steward];
      nextChapter[_steward] = Chapter(now, currentPurposeDuration, _steward, currentPurposeSustainability, 0, description);
    }

    // The sustainability of a Purpose cannot be changed if there have been sustainments made to it.
    function purposeToUpdate(address _steward) internal returns Purpose {
      // If the steward does not have a current Purpose in the current Chapter, make one and return it.
      if (currentPurposes[_steward] == 0) {
          Purpose storage purpose = currentPurposes[_steward];
          return purpose
      } 

      // If the steward's current Purpose does not yet have sustainments, return it.
      if (currentPurposes[_steward].sustainment == 0) {
        return currentPurposes[_steward];
      } 

      // If the steward does not have a Purpose in the next Chapter, make one and return it.
      if (nextPurposes[_steward] == 0) {
          Purpose storage purpose = nextPurposes[_steward];
          return purpose;
      } 

      // Return the steward's next Purpose.
      return nextPurposes[_steward];
    }

    // Proportionally allocate the specified amount to the contributors of the specified Purpose,
    // meaning each sustainer will receive a portion of the specified amount equivalent to the portion of the total
    // amount contributed to the sustainment of the Purpose that they are responsible for.
    function redistribute(Purpose purpose, uint amount) internal {
      assert(amount > 0);

      // For each sustainer, calculate their share of the sustainment and allocate a proportional share of the amount.
      for (uint i=0; i<purpose.sustainers.length; i++) {
        address sustainer = purpose.sustainers[i];
        uint sustainerSustainment = purpose.sustainments[sustainer];
        uint amountShare = sustainerSustainment * amount / purpose.sustainment
        redistribution[sustainer] += amountShare;
      }
    }
}

//ARCHIVE
// function getNeedAmount(address entity) public view returns (uint256) {
//     return needs[entity].amount;
// }
// event Transfer(address indexed _from, address indexed _to, uint256 _value);

// function sendCoin(address receiver, uint256 amount)
//     public
//     returns (bool sufficient)
// {
//     if (balances[msg.sender] < amount) return false;
//     balances[msg.sender] -= amount;
//     balances[receiver] += amount;
//     emit Transfer(msg.sender, receiver, amount);
//     return true;
// }

// function getBalanceInEth(address addr) public view returns (uint256) {
//     return ConvertLib.convert(getBalance(addr), 2);
// }

// function getNeedAmount(address entity) public view returns (uint256) {
//     return needs[entity].amount;
// }

// function getContribution(address entity, address contributer)
//     public
//     view
//     returns (uint256)
// {
//     return needs[entity].contributions[contributer];
// }