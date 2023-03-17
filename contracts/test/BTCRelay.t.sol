pragma solidity >=0.8.17;

import "./utils/Test.sol";
import "../BTCRelay.sol";

contract BTCRelayTest is Test {
    BTCRelay public btcRelay;

    function setUp() public {
        btcRelay = new BTCRelay();
    }

    function setGenesis() public {
        // Taken from tbtc tests
        bytes
            memory genesisHeader = hex"00000020e2acb3e71e4e443af48e81d381dea7d35e2e8d5e69fe150000000000000000007f2ada224dc4afba6ca37010b099c02322cb5df24fcedb0ff5b87fb3ca64eeaea01a055c7cd9311771f2861e";
        uint256 genesisHeight = 552384;
        uint64 proofLength = 4;

        btcRelay.genesis(genesisHeader, genesisHeight, proofLength);
    }

    function testGenesisNotSet() public {
        vm.expectRevert();
        btcRelay.retarget(hex"01");
    }

    function testSetGenesis() public {
        setGenesis();

        // Once genesis block is established, relay should be ready
        assert(btcRelay.ready());

        // Genesis should only be settable once
        vm.expectRevert();
        setGenesis();

        // Difficulty for genesis blockheight from
        // https://www.blockchain.com/explorer/blocks/btc/552384
        assertEq(btcRelay.getCurrentEpochDifficulty(), 5646403851534);
    }

    function testIssuance() public {
        setGenesis();

        // 12.5 BTC in sats
        assertEq(btcRelay.getBTCIssuancePerBlock(), 1250000000);
    }

    function testRetarget() public {
        // Block headers from height 554396 to 554403
        // Epoch boundary at 554400
        bytes
            memory retargetHeader = hex"000000208e3d25087f0c1dc73fb5698fb3a21fc27ab5c09a51a4030000000000000000002fe4c18dc554ac199203ac26358814752bc0db76ed72d2673d3d4f6b20d66760737f195c7cd931171e60b26b";
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"00000020b84058dc5f40275d4c880f9cb63ec5e572524518ce180e0000000000000000008a9ec4242c4003dde9ae9ac167dd36614ee00c56b8ffdf63abf1d0dbdcdcb24fc27f195c7cd931173f2077a9"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"000000203633c1376556de44ddd528d0a6c27244ee5798bdd4e7110000000000000000008a5a4c9ebf9b6b77e3f63e1f4ddbbe1aeec4b7592554cb3c003068f849647b147180195c7cd93117b8c8e83f"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"000000202da0c39c117f882d54d03df822915a8a6373be4cfa1a01000000000000000000dd6f24bd263432435f0954c59c022cfd8e5190f4615fc2c249815244a3fe09b34683195c7cd931170f68c64a"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"00004020d3b2d7d61ad2d95ffbd556d9e00f07877423600a8da015000000000000000000d192743a2c190a7421f92fefe92505579d7b8eda568cacee13b25751ac704c669d83195cf41e371721bae3e7"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"00000020ae67207125404fa8786acaeb7cff69156fe0a01b0b3c04000000000000000000b668f999166662460c4a9717d3c8e72e3b0c24863fccdd90295dfb0b047aa1f3f484195cf41e37176b176d83"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"00008020f1b333748571d00f25c262706b03313443f1a4424be70f0000000000000000004d7b233c0f561f7e5d57fb1d9bae5c72576787da5c13ec792d1d87eb1a62795eba85195cf41e3717d904e9c3"
        );
        retargetHeader = bytes.concat(
            retargetHeader,
            hex"00000020b12386369f49f8800f47ab7813e3420b511fd4e2de8907000000000000000000026069ddf2c58926646215a8434823226646051ebcb77b6644d9791732763da8c585195cf41e3717689570ae"
        );

        setGenesis();

        // Need to set block timestamp so that the header checks succeed
        // By default it's 1
        // This value is Mon Mar 13 2023 21:03:54 GMT
        vm.warp(1678741434);
        btcRelay.retarget(retargetHeader);

        // Difficulties should be properly set
        assertEq(btcRelay.getPrevEpochDifficulty(), 5646403851534);
        // From https://www.blockchain.com/explorer/blocks/btc/554400
        assertEq(btcRelay.getCurrentEpochDifficulty(), 5106422924659);

        // Should give proper block range for difficulty
        (uint256 lower, uint256 upper) = btcRelay.getRelayRange();
        assertEq(lower, 552384);
        // This is equal to current epoch height + 2015
        assertEq(upper, 556415);
    }
}
