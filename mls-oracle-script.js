const matchId = args[0];
const playerIdsRemmaping = args[1];
if (secrets.pinataKey == "") {
  throw Error("PINATA_API_KEY environment variable not set for Pinata API.");
}

if (secrets.mlsApiKey == "") {
  throw Error("MLS_API_KEY environment variable not set for Rapid API.");
}
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

function base64ToUint8Array(base64) {
  const binaryString = atob(base64);
  const len = binaryString.length;
  const uint8Array = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    uint8Array[i] = binaryString.charCodeAt(i);
  }
  return uint8Array;
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
    "X-RapidAPI-Key": secrets.mlsApiKey,

    "X-RapidAPI-Host": "api-football-v1.p.rapidapi.com",
  },
});

const [playerPerformanceResponse, playerIdsRemmapingResponse] =
  await Promise.all([playerPerformanceRequest, playerIdsRemmapingRequest]);
let points = new Array(128).fill(0);

if (playerPerformanceResponse.error) {
  throw new Error("PLAYER PERFORMANCE API ERROR");
}

if (playerIdsRemmapingResponse.error) {
  throw new Error("PLAYER IDS REMAPPING API ERROR");
}

//process home Team
playerPerformanceResponse.data.response[0].players.forEach((player) => {
  const point = calculateFantasyPoints(player.statistics[0]);
  const playerId = player.player.id;
  points[playerIdsRemmapingResponse.data[playerId]] = Math.ceil(
    point < 0 ? 0 : point
  );
});
// Process bowlers data
playerPerformanceResponse.data.response[1].players.forEach((player) => {
  const point = calculateFantasyPoints(player.statistics[0]);
  const playerId = player.player.id;
  points[playerIdsRemmapingResponse.data[playerId]] = Math.ceil(
    point < 0 ? 0 : point
  );
});

const pinFileToPinataRequest = Functions.makeHttpRequest({
  url: `https://api.pinata.cloud/pinning/pinJSONToIPFS`,
  method: "POST",
  headers: {
    Authorization: `Bearer ${secrets.pinataKey}`,
    "Content-Type": "application/json",
  },
  data: {
    pinataMetadata: {
      name: "Game " + matchId,
    },
    pinataOptions: {
      cidVersion: 1,
    },
    pinataContent: {
      points: points,
    },
  },
});

const computeMerkleRootRequest = Functions.makeHttpRequest({
  url: "https://luffyprotocol.adaptable.app/api/compute-merkle-root",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  data: {
    points: points,
  },
});
const [pinFileToPinataResponse, computeMerkleRootResponse] = await Promise.all([
  pinFileToPinataRequest,
  computeMerkleRootRequest,
]);

if (pinFileToPinataResponse.error) {
  throw new Error("Error while pinning file to pinata");
}

if (computeMerkleRootResponse.error) {
  throw new Error("Error while computing merkle root");
}

const encodeReturnDataRequest = Functions.makeHttpRequest({
  url: "https://luffyprotocol.adaptable.app/api/encode-return-data",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
  },
  data: {
    ipfsHash: pinFileToPinataResponse.data.IpfsHash,
    merkleRoot: computeMerkleRootResponse.data.merkleRoot,
  },
});

const [encodeReturnDataResponse] = await Promise.all([encodeReturnDataRequest]);

if (encodeReturnDataResponse.error) {
  throw new Error("Error while encoding return data");
}
const uint8ArrayResponse = base64ToUint8Array(
  encodeReturnDataResponse.data.returnData
);

return uint8ArrayResponse;
