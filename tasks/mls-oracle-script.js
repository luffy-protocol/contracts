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
// if (secrets.cricBuzzKey == "") {
//   throw Error("CRICKET_API_KEY environment variable not set for Cricbuzz API.");
// }

const pointsScheme = {
  minutes: 0.2,
  number: 0,
  position: 0,
  rating: 0,
  captain: 0,
  substitute: 0,

  offsides: -1,
  shots: {
    total: 0,
    on: 1,
  },
  goals: {
    total: 4,
    conceded: -1,
    assists: 3,
    saves: 3,
  },
  passes: {
    total: 0.02,
    key: 0,
    accuracy: 0.02,
  },
  tackles: {
    total: 1,
    blocks: 1,
    interceptions: 2,
  },
  duels: {
    total: 0,
    won: 1,
  },
  dribbles: {
    attempts: 0,
    success: 1,
    past: 1,
  },
  fouls: {
    drawn: 0,
    committed: -2,
  },
  cards: {
    yellow: -5,
    red: -10,
  },
  penalty: {
    won: 0,
    commited: 0,
    scored: 10,
    missed: -5,
    saved: 10,
  },
};

function calculateFantasyPoints(playerStats) {
  let fantasyPoints = 0;

  for (const key in playerStats) {
    if (key in pointsScheme) {
      if (typeof playerStats[key] === "object") {
        for (const subKey in playerStats[key]) {
          if (subKey in pointsScheme[key]) {
            fantasyPoints +=
              playerStats[key][subKey] * pointsScheme[key][subKey];
          }
        }
      } else {
        fantasyPoints += playerStats[key] * pointsScheme[key];
      }
    }
  }

  return fantasyPoints;
}

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
    "https://api-football-v1.p.rapidapi.com/v3/fixtures/players?fixture=" +
    matchId,
  method: "GET",
  headers: {
    "X-RapidAPI-Key": "d77878f019mshb86b56759562ea1p13048ejsneda9faebabc4",
    "X-RapidAPI-Host": "api-football-v1.p.rapidapi.com",
  },
});

const [playerPerformanceResponse, playerIdsRemmapingResponse] =
  await Promise.all([playerPerformanceRequest, playerIdsRemmapingRequest]);
let points = new Array(64).fill(0.0);

if (!playerPerformanceResponse.error || playerIdsRemmapingResponse.error) {
  console.log("Player performance API success");

  //process home Team
  playerPerformanceResponse.data.response[0].players.forEach((player) => {
    const point = calculateFantasyPoints(player.statistics[0]);
    const playerId = player.player.id;
    points[playerIdsRemmapingResponse.data[playerId]] = point;
  });
  // Process bowlers data
  playerPerformanceResponse.data.response[1].players.forEach((player) => {
    const point = calculateFantasyPoints(player.statistics[0]);
    const playerId = player.player.id;
    points[playerIdsRemmapingResponse.data[playerId]] = point;
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
console.log(merkleRoot);
console.log(
  `https://amethyst-impossible-ptarmigan-368.mypinata.cloud/ipfs/${pinFileToPinataResponse.data.IpfsHash}?pinataGatewayToken=CUMCxB7dqGB8wEEQqGSGd9u1edmJpWmR9b0Oiuewyt5gs633nKmTogRoKZMrG4Vk`
);

return hexToBytes(returnDataHex);
