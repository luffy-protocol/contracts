const {
  keccak256,
  encodePacked,
  encodeAbiParameters,
  parseAbiParameters,
  hexToBytes,
} = await import("npm:viem");

const matchId = args[0];
const playerIdsRemmaping = args[1];

if (secrets.pinataKey == "") {
  throw Error("PINATA_API_KEY environment variable not set for Pinata API.");
}
if (secrets.cricBuzzKey == "") {
  throw Error("CRICKET_API_KEY environment variable not set for Cricbuzz API.");
}

const weightage = {
  run: 1,
  four: 4,
  six: 6,
  wicket: 25,
};

function computeMerkleRoot(points) {
  const hexValues = points.map((point) =>
    keccak256(`0x${point.toString(16).padStart(64, "0")}`)
  );

  function recursiveMerkleRoot(hashes) {
    if (hashes.length === 1) {
      return hashes[0];
    }

    const nextLevelHashes = [];

    // Combine adjacent hashes and hash them together
    for (let i = 0; i < hashes.length; i += 2) {
      const left = hashes[i];
      const right = i + 1 < hashes.length ? hashes[i + 1] : "0x";
      const combinedHash = keccak256(
        encodePacked(["bytes32", "bytes32"], [left, right])
      );
      nextLevelHashes.push(combinedHash);
    }

    // Recur for the next level
    return recursiveMerkleRoot(nextLevelHashes);
  }

  // Start the recursive computation
  return recursiveMerkleRoot(hexValues);
}

function padArrayWithZeros(array) {
  const paddedLength = Math.pow(2, Math.ceil(Math.log2(array.length)));
  return array.concat(
    Array.from({ length: paddedLength - array.length }, () => 0)
  );
}

const playerIdsRemmapingRequest = Functions.makeHttpRequest({
  url: playerIdsRemmaping,
  method: "GET",
  headers: {
    "Content-Type": "application/json",
  },
});

const playerPerformanceRequest = Functions.makeHttpRequest({
  url:
    "https://cricbuzz-cricket.p.rapidapi.com/mcenter/v1/" + matchId + "/hscard",
  method: "GET",
  headers: {
    "X-RapidAPI-Key": secrets.cricBuzzKey,
    "X-RapidAPI-Host": "cricbuzz-cricket.p.rapidapi.com",
  },
});

const [playerPerformanceResponse, playerIdsRemmapingResponse] =
  await Promise.all([playerPerformanceRequest, playerIdsRemmapingRequest]);
let points = new Array(64).fill(0);

if (!playerPerformanceResponse.error) {
  console.log("Player performance API success");

  [
    playerPerformanceResponse.data.scoreCard[0].batTeamDetails.batsmenData,
    playerPerformanceResponse.data.scoreCard[1].batTeamDetails.batsmenData,
  ].forEach((batsmenData) => {
    Object.values(batsmenData).forEach((player) => {
      const playerId = player.batId;
      const runs = player.runs || 0;
      const fours = player.fours || 0;
      const sixes = player.sixes || 0;
      points[playerIdsRemmapingResponse.data[playerId]] +=
        runs + fours * weightage.four + sixes * weightage.six;
    });
  });
  // Process bowlers data
  [
    playerPerformanceResponse.data.scoreCard[0].bowlTeamDetails.bowlersData,
    playerPerformanceResponse.data.scoreCard[1].bowlTeamDetails.bowlersData,
  ].forEach((bowlersData) => {
    Object.values(bowlersData).forEach((player) => {
      const playerId = player.bowlerId;
      const wickets = player.wickets || 0;
      const playerPoints = wickets * weightage.wicket; // Assuming 25 points per wicket
      points[playerIdsRemmapingResponse.data[playerId]] += playerPoints;
    });
  });
}

const pinFileToPinataRequest = Functions.makeHttpRequest({
  url: `https://api.pinata.cloud/pinning/pinJSONToIPFS`,
  method: "POST",
  headers: {
    Authorization: `Bearer ${secrets.pinataKey}`,
    "Content-Type": "application/json",
  },
  data: {
    pinataMetadata: {
      name: "Gameweeek " + matchId,
    },
    pinataOptions: {
      cidVersion: 1,
    },
    pinataContent: {
      points: points,
    },
  },
});

const [pinFileToPinataResponse] = await Promise.all([pinFileToPinataRequest]);

const merkleRoot = computeMerkleRoot(padArrayWithZeros(points));
console.log(merkleRoot);
const returnDataHex = encodeAbiParameters(
  parseAbiParameters("bytes32, string"),
  [merkleRoot, pinFileToPinataResponse.data.IpfsHash]
);

return hexToBytes(returnDataHex);
