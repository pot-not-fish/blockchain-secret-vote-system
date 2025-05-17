// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ElectInfo {
    string Title;           // 选票标题
    // uint256 StartTime;      // 结束时间
    // uint256 EndTime;        // 开始时间
    address Initiator;      // 发起者

    uint256 p; // 素数p
    uint256 g; // 生成元g
    uint256 r; // 随机数
    uint256 q; // q是的p−1除数
    uint256 grev; // g的逆元
}

event PrintUint(string name, uint256 value);
event PrintInt(string name, int256 value);

contract PubElections {
    ElectInfo public electInfo;

    // 0-非法选民 1-合法选民 2-已经创建投票后的选民
    mapping(address => int) voters; // 选民

    constructor() { // string memory _title, address[] memory _votes
        // check
        // require(bytes(_title).length != 0, "title is empty");
        // require(_startTime >= block.timestamp+10 minutes, "start time must be greater than current time plus 10 minutes");
        // require(_endTime >= _startTime+1 hours, "end time must be greater than start time plus 1 hour");
        // require(_votes.length > 2, "voters must over than 2 people");

        // init
        // electInfo.Title = _title;
        // electInfo.StartTime = _startTime;
        // electInfo.EndTime = _endTime;
        electInfo.Initiator = msg.sender;
        // for (uint256 i = 0; i < _votes.length; i++) {
        //     voters[_votes[i]] = 1;
        // }

        // 硬编码 区块链生成随机数不安全，直接传入参数或调用预言机
        electInfo.p = 3929288131;
        electInfo.g = 2;
        electInfo.r = 7203;
        electInfo.q = 17387;
        electInfo.grev = 8694;
    }

    function GetElectInfo() external view returns(ElectInfo memory) {
        return electInfo;
    }

    uint256[] public yList;
    // 创建投票区块后回调传入公钥
    function SetVote(uint256 y) external {
        yList.push(y);
    }

    function GetPubKeySum(uint256 y) external view returns (uint256) {
        uint256 sum = 1;
        for (uint256 i = 0; i < yList.length; i++) {
            if (yList[i] != y) {
                sum *= yList[i];
            }
        }
        return sum;
    }

    function GetH(uint256 y) external view returns (uint256) {
        uint256 up = 1;
        uint256 down = 1;
        uint256 i = 0;
        for (; i < yList.length; i++) {
            if (yList[i] == y) {
                i++;
                break;
            }
            up *= yList[i];
        }
        for (; i < yList.length; i++) {
            down *= yList[i];
        }
        return powMod(down, electInfo.q-2, electInfo.q) * up % electInfo.q;
    }

    function ResetYList() external {
        yList = new uint256[](0);
    }

    function powMod(uint256 base, uint256 exponent, uint256 modulus) internal pure returns (uint256) {
        uint256 result = 1;
        base = base % modulus;
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result = (result * base) % modulus;
            }
            base = (base * base) % modulus;
            exponent = exponent >> 1;
        }
        return result;
    }

    uint256[] public sumV;
    function SetTally(uint256 V) external {
        sumV.push(V);
    }
    function GetResult() external view returns(uint256) {
        uint256 result = 1;
        for (uint256 i = 0; i < sumV.length; i++) {
            result *= sumV[i];
            result %= electInfo.q;
        }
        return result;
    }

    uint256[] public sumRecV;
    function SetRecV(uint256 gp) external {
        sumRecV.push(gp);
    }
    function GetRecV(uint256 c) external view returns(uint256) {
        uint256 sumYP = 1;
        for (uint256 i = 0; i < sumRecV.length; i++) {
            sumYP *= sumRecV[i];
            sumYP %= electInfo.q;
        }
        uint256 sumYPRev = powMod(sumYP, electInfo.q-2, electInfo.q);
        return (c * sumYPRev) % electInfo.q;
    }

    uint256[] public recYList;
    function SetRecY(uint256 y) external {
        recYList.push(y);
    }
    function GetRecH(uint256 y) external view returns(uint256) {
        uint256 up = 1;
        uint256 down = 1;
        uint256 i = 0;
        for (; i < recYList.length; i++) {
            if (recYList[i] == y) {
                i++;
                break;
            }
            up *= recYList[i];
        }
        for (; i < recYList.length; i++) {
            down *= recYList[i];
        }
        return powMod(down, electInfo.q-2, electInfo.q) * up % electInfo.q;
    }

    uint256[] public recList;
    function SetRec(uint256 rec) external {
        recList.push(rec);
    }
    function GetRecResult() external view returns(uint256) {
        uint256 result = 1;
        for (uint256 i = 0; i < recList.length; i++) {
            result *= recList[i];
            result %= electInfo.q;
        }
        return result;
    }
}

struct VoteParameter {
    uint256 wx;
    uint256 wp;
    uint256 e1;
    uint256 e2;
    uint256 rx1;
    uint256 rx2;
    uint256 rp1;
    uint256 rp2;

    uint256 a1;
    uint256 a2;
    uint256 b1;
    uint256 b2;
    uint256 c1;
    uint256 c2;
    uint256 d1;
    uint256 d2;
}

contract Vote {
    ElectInfo public electInfo;

    uint256 public y; // 公钥
    uint256 x; // 私钥

    address voter;

    // 用于承诺的公钥和私钥
    uint256 public cy;
    uint256 cx;

    PubElections pubElections;

    constructor(PubElections _pubElections) {
        electInfo = _pubElections.GetElectInfo();
        pubElections = _pubElections;
        voter = msg.sender;

        // set up
        x = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (electInfo.q-1);
        y = powMod(electInfo.g, x, electInfo.q);
        pubElections.SetVote(y);

        // commit
        cx = uint256(keccak256(abi.encodePacked(block.timestamp+1, block.prevrandao))) % (electInfo.q-1);
        cy = powMod(electInfo.g, cx, electInfo.q);
    }

    function powMod(uint256 base, uint256 exponent, uint256 modulus) internal pure returns (uint256) {
        uint256 result = 1;
        base = base % modulus;
        while (exponent > 0) {
            if (exponent % 2 == 1) {
                result = (result * base) % modulus;
            }
            base = (base * base) % modulus;
            exponent = exponent >> 1;
        }
        return result;
    }

    function GetSecretKey() external view returns (uint256) {
        // require(voter == msg.sender, "only onwer can watch the secret key");
        return x;
    }

    function GetCommitSecretKey() external view returns (uint256) {
        // require(voter == msg.sender, "only onwer can watch the commit secret key");
        return cx;
    }

    function GetPublicKey() external view returns (uint256) {
        return y;
    }

    mapping(address => uint256) setupW;
    function SetupProve(uint256 e, uint256 mode) external returns(uint256) {
        require(mode == 1 || mode == 2, "invalid mode");
        uint256 w;
        if (mode == 1) {
            w = uint256(keccak256(abi.encodePacked(block.timestamp+1, block.prevrandao))) % (electInfo.q-1);
            setupW[msg.sender] = w;
            uint256 a = powMod(electInfo.g, w, electInfo.q);
            return a;
        }
        // mode == 2
        w = setupW[msg.sender];
        int256 n = int256(electInfo.q-1);
        uint256 r = uint256(((int256(w) - int256(x * e)) % n + n) % n); // 中间有负数 需要int256转换 模运算有负需要两次取模
        return r;
    }

    function SetupVerify(Vote vote) external {
        // require(voter == msg.sender, "only block onwer can call the SetupVerify");
        uint256 a = vote.SetupProve(0, 1);
        uint256 e = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (electInfo.q-1);
        uint256 r = vote.SetupProve(e, 2);
        uint256 result =  powMod(electInfo.g, r, electInfo.q)*powMod(vote.GetPublicKey(), e, electInfo.q) % electInfo.q;
        require(result == a, "set up: invalid secret key and public key");
    }

    uint256 v; // 个人投票结果
    uint256 public c; // 承诺
    uint256 public sumY; // 其他投票者公钥之积

    function GenCommit(uint256 _v) external {
        v = _v;
        sumY = pubElections.GetPubKeySum(y);
        c = powMod(electInfo.g, v, electInfo.q) * powMod(sumY, cx, electInfo.q) % electInfo.q;
    }

    mapping(address => uint256) commitW;
    mapping(address => uint256) commitE1;
    mapping(address => uint256) commitE2;
    mapping(address => uint256) commitR1;
    mapping(address => uint256) commitR2;
    function CommitProve(uint256 e, uint256 mode) external returns(uint256, uint256, uint256, uint256) {       
        if (mode == 1) {
            uint256 a1;
            uint256 b1;
            uint256 a2;
            uint256 b2;
            uint256 n = electInfo.q-1;
            uint256 w = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (n);
            uint256 e1 = uint256(keccak256(abi.encodePacked(block.timestamp+1, block.prevrandao))) % (n);
            uint256 r1 = uint256(keccak256(abi.encodePacked(block.timestamp+2, block.prevrandao))) % (n);
            uint256 e2 = uint256(keccak256(abi.encodePacked(block.timestamp+3, block.prevrandao))) % (n);
            uint256 r2 = uint256(keccak256(abi.encodePacked(block.timestamp+4, block.prevrandao))) % (n);

            emit PrintUint("w", w);
            emit PrintUint("e1", e1);
            emit PrintUint("r1", r1);
            emit PrintUint("e2", e2);
            emit PrintUint("r2", r2);

            commitW[msg.sender] = w;
            commitE1[msg.sender] = e1;
            commitE2[msg.sender] = e2;
            commitR1[msg.sender] = r1;
            commitR2[msg.sender] = r2;
            if (v == 1) {
                a1 = powMod(sumY, r1, electInfo.q) * powMod(c, e1, electInfo.q) % electInfo.q;
                b1 = powMod(electInfo.g, r1, electInfo.q) * powMod(cy, e1, electInfo.q) % electInfo.q;
                a2 = powMod(sumY, w, electInfo.q);
                b2 = powMod(electInfo.g, w, electInfo.q);
            } else {
                a1 = powMod(sumY, w, electInfo.q);
                b1 = powMod(electInfo.g, w, electInfo.q);
                a2 = powMod(sumY, r2, electInfo.q) * powMod(c*electInfo.grev % electInfo.q, e2, electInfo.q) % electInfo.q;
                b2 = powMod(electInfo.g, r2, electInfo.q) * powMod(cy, e2, electInfo.q) % electInfo.q;
            }

            emit PrintUint("a1", a1);
            emit PrintUint("b1", b1);
            emit PrintUint("a2", a2);
            emit PrintUint("b2", b2);

            return (a1, a2, b1, b2);
        }
        int256 i_n = int256(electInfo.q - 1);
        uint256 v_e1;
        uint256 v_e2;
        uint256 v_r1;
        uint256 v_r2;
        if (v == 1) {
            v_e1 = commitE1[msg.sender];
            v_e2 = uint256(((int256(e) - int256(commitE1[msg.sender])) % i_n + i_n) % i_n);
            v_r1 = commitR1[msg.sender];
            v_r2 = uint256((int256(commitW[msg.sender]) - int256(cx*v_e2) % i_n + i_n) % i_n);
        } else {
            v_e1 = uint256(((int256(e) - int256(commitE2[msg.sender])) % i_n + i_n) % i_n);
            v_e2 = commitE2[msg.sender];
            v_r1 = uint256((int256(commitW[msg.sender]) - int256(cx*v_e1) % i_n + i_n) % i_n);
            v_r2 = commitR2[msg.sender];
        }
        return (v_e1, v_e2, v_r1, v_r2);
    }

    function CommitVerify(Vote vote) external {
        // require(voter == msg.sender, "only block onwer can call the CommitVerify");
        (uint256 a1, uint256 a2, uint256 b1, uint256 b2) = vote.CommitProve(0, 1);
        uint256 e = uint256(keccak256(abi.encodePacked(block.timestamp+5, block.prevrandao))) % (electInfo.q - 1);

        (uint256 e1, uint256 e2, uint256 r1, uint256 r2) = vote.CommitProve(e, 2);

        emit PrintUint("e", e);
        emit PrintUint("check e", (e1+e2) % (electInfo.q - 1));
        emit PrintUint("check a1", (powMod(vote.sumY(), r1, electInfo.q) * powMod(vote.c(), e1, electInfo.q)) % electInfo.q);
        emit PrintUint("check a2", (powMod(vote.sumY(), r2, electInfo.q) * powMod(vote.c() * electInfo.grev, e2, electInfo.q)) % electInfo.q);
        emit PrintUint("check b1", (powMod(electInfo.g, r1, electInfo.q) * powMod(vote.cy(), e1, electInfo.q)) % electInfo.q);
        emit PrintUint("check b2", (powMod(electInfo.g, r2, electInfo.q) * powMod(vote.cy(), e2, electInfo.q)) % electInfo.q);
        // e = a1 = a2 = b1 = b2;

        require(e == (e1+e2) % (electInfo.q - 1), "e is invalid");
        require(a1 == (powMod(vote.sumY(), r1, electInfo.q) * powMod(vote.c(), e1, electInfo.q)) % electInfo.q, "a1 is invalid");
        require(a2 == (powMod(vote.sumY(), r2, electInfo.q) * powMod(vote.c() * electInfo.grev, e2, electInfo.q)) % electInfo.q, "a2 is invalid");
        require(b1 == (powMod(electInfo.g, r1, electInfo.q) * powMod(vote.cy(), e1, electInfo.q)) % electInfo.q, "b1 is invalid");
        require(b2 == (powMod(electInfo.g, r2, electInfo.q) * powMod(vote.cy(), e2, electInfo.q)) % electInfo.q, "b2 is invalid");
    }

    uint256 public h;
    uint256 public V;

    function GenVote(uint256 _v) external {
        v = _v;
        h = pubElections.GetH(y);
        V = powMod(h, x, electInfo.q) * powMod(electInfo.g, v, electInfo.q) % electInfo.q;
        pubElections.SetTally(V);
    }

    function generateRandomNumber(uint256 timestampOffset) internal view returns (uint256) {
        uint256 n = electInfo.q - 1;
        return uint256(keccak256(abi.encodePacked(block.timestamp + timestampOffset, block.prevrandao))) % n;
    }

    mapping(address => uint256) voteWx;
    mapping(address => uint256) voteWp;
    mapping(address => uint256) voteE1;
    mapping(address => uint256) voteE2;
    mapping(address => uint256) voteRx1;
    mapping(address => uint256) voteRx2;
    mapping(address => uint256) voteRp1;
    mapping(address => uint256) voteRp2;
    function VoteProve(uint256 e, uint256 mode) external returns(uint256[] memory) {
        uint256[] memory res;
        VoteParameter memory vp;
        uint256 q = electInfo.q;
        if (mode == 1) {
            uint256 n = electInfo.q-1;
            vp.wx = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (n);
            vp.wp = uint256(keccak256(abi.encodePacked(block.timestamp+1, block.prevrandao))) % (n);
            vp.e1 = uint256(keccak256(abi.encodePacked(block.timestamp+2, block.prevrandao))) % (n);
            vp.e2 = uint256(keccak256(abi.encodePacked(block.timestamp+3, block.prevrandao))) % (n);
            vp.rx1 = uint256(keccak256(abi.encodePacked(block.timestamp+4, block.prevrandao))) % (n);
            vp.rx2 = uint256(keccak256(abi.encodePacked(block.timestamp+5, block.prevrandao))) % (n);
            vp.rp1 = uint256(keccak256(abi.encodePacked(block.timestamp+6, block.prevrandao))) % (n);
            vp.rp2 = uint256(keccak256(abi.encodePacked(block.timestamp+7, block.prevrandao))) % (n);

            voteWx[msg.sender] = vp.wx;
            voteWp[msg.sender] = vp.wp;
            voteE1[msg.sender] = vp.e1;
            voteE2[msg.sender] = vp.e2;
            voteRx1[msg.sender] = vp.rx1;
            voteRx2[msg.sender] = vp.rx2;
            voteRp1[msg.sender] = vp.rp1;
            voteRp2[msg.sender] = vp.rp2;
            if (v == 1) {
                vp.a1 = powMod(sumY, vp.rp1, q) * powMod(c, vp.e1, q) % q;
                vp.b1 = powMod(h, vp.rx1, q) * powMod(V, vp.e1, q) % q;
                vp.c1 = powMod(electInfo.g, vp.rx1, q) * powMod(y, vp.e1, q) % q;
                vp.d1 = powMod(electInfo.g, vp.rp1, q) * powMod(cy, vp.e1, q) % q;
                vp.a2 = powMod(sumY, vp.wp, q);
                vp.b2 = powMod(h, vp.wx, q);
                vp.c2 = powMod(electInfo.g, vp.wx, q);
                vp.d2 = powMod(electInfo.g, vp.wp, q);
            } else {
                vp.a1 = powMod(sumY, vp.wp, electInfo.q);
                vp.b1 = powMod(h, vp.wx, electInfo.q);
                vp.c1 = powMod(electInfo.g, vp.wx, electInfo.q);
                vp.d1 = powMod(electInfo.g, vp.wp, electInfo.q);
                vp.a2 = powMod(sumY, vp.rp2, electInfo.q) * powMod(c * electInfo.grev, vp.e2, electInfo.q) % electInfo.q;
                vp.b2 = powMod(h, vp.rx2, electInfo.q) * powMod(V * electInfo.grev, vp.e2, electInfo.q) % electInfo.q;
                vp.c2 = powMod(electInfo.g, vp.rx2, electInfo.q) * powMod(y, vp.e2, electInfo.q) % electInfo.q;
                vp.d2 = powMod(electInfo.g, vp.rp2, electInfo.q) * powMod(cy, vp.e2, electInfo.q) % electInfo.q;
            }
            res = new uint256[](8);
            res[0] = vp.a1;
            res[1] = vp.b1;
            res[2] = vp.c1;
            res[3] = vp.d1;
            res[4] = vp.a2;
            res[5] = vp.b2;
            res[6] = vp.c2;
            res[7] = vp.d2;
            return res;
        }
        vp.wx = voteWx[msg.sender];
        vp.wp = voteWp[msg.sender];
        vp.e1 = voteE1[msg.sender];
        vp.e2 = voteE2[msg.sender];
        vp.rx1 = voteRx1[msg.sender];
        vp.rx2 = voteRx2[msg.sender];
        vp.rp1 = voteRp1[msg.sender];
        vp.rp2 = voteRp2[msg.sender];

        int256 i_n = int256(electInfo.q-1);
        if (v == 1) {
            vp.e2 = uint256(((int256(e) - int256(vp.e1)) % i_n + i_n) % i_n);
            vp.rx2 = uint256(((int256(vp.wx)-int256(x*vp.e2)) % i_n + i_n) % i_n);
            vp.rp2 = uint256(((int256(vp.wp)-int256(cx*vp.e2)) % i_n + i_n) % i_n);
        } else {
            vp.e1 = uint256(((int256(e) - int256(vp.e2)) % i_n + i_n) % i_n);
            vp.rx1 = uint256(((int256(vp.wx)-int256(x*vp.e1)) % i_n + i_n) % i_n);
            vp.rp1 = uint256(((int256(vp.wp)-int256(cx*vp.e1)) % i_n + i_n) % i_n);
        }
        res = new uint256[](6);
        res[0] = vp.e1;
        res[1] = vp.e2;
        res[2] = vp.rx1;
        res[3] = vp.rx2;
        res[4] = vp.rp1;
        res[5] = vp.rp2;
        return res;
    }

    function VoteVerify(Vote vote) external {
        // require(voter == msg.sender, "only block onwer can call the VoteVerify");
        VoteParameter memory vp;
        uint256[] memory res = vote.VoteProve(0, 1);
        vp.a1 = res[0];
        vp.b1 = res[1];
        vp.c1 = res[2];
        vp.d1 = res[3];
        vp.a2 = res[4];
        vp.b2 = res[5];
        vp.c2 = res[6];
        vp.d2 = res[7];
        uint256 e = uint256(keccak256(abi.encodePacked(block.timestamp+8, block.prevrandao))) % (electInfo.q - 1);

        res = vote.VoteProve(e, 2);
        vp.e1 = res[0];
        vp.e2 = res[1];
        vp.rx1 = res[2];
        vp.rx2 = res[3];
        vp.rp1 = res[4];
        vp.rp2 = res[5];

        uint256 q = electInfo.q;

        require(e == (vp.e1+vp.e2) % (electInfo.q-1), "e is invalid");
        require(vp.a1 == powMod(vote.sumY(), vp.rp1, q) * powMod(vote.c(), vp.e1, q) % q, "a1 is invalid");
        require(vp.b1 == powMod(vote.h(), vp.rx1, q) * powMod(vote.V(), vp.e1, q) % q, "b1 is invalid");
        require(vp.c1 == powMod(electInfo.g, vp.rx1, q) * powMod(vote.y(), vp.e1, q) % q, "c1 is invalid");
        require(vp.d1 == powMod(electInfo.g, vp.rp1, q) * powMod(vote.cy(), vp.e1, q) % q, "d1 is invalid");
        require(vp.a2 == powMod(vote.sumY(), vp.rp2, q) * powMod(vote.c() * electInfo.grev, vp.e2, q) % q, "a2 is invalid");
        require(vp.b2 == powMod(vote.h(), vp.rx2, q) * powMod(vote.V() * electInfo.grev, vp.e2, q) % q, "b2 is invalid");
        require(vp.c2 == powMod(electInfo.g, vp.rx2, q) * powMod(vote.y(), vp.e2, q) % q, "c2 is invalid");
        require(vp.d2 == powMod(electInfo.g, vp.rp2, q) * powMod(vote.cy(), vp.e2, q) % q, "d2 is invalid");
    }

    function RecoverLastVote(uint256 recCY) external {
        uint256 gp = powMod(recCY, x, electInfo.q);
        pubElections.SetRecY(y);
        pubElections.SetRecV(gp);
    }

    uint256 public recHx;
    function SetRecHx() external returns(uint256) {
        uint256 hHat = pubElections.GetRecH(y);
        recHx = powMod(hHat, x, electInfo.q);
        pubElections.SetRec((recHx * (electInfo.g ** v) % electInfo.q));
        return recHx;
    }
}
