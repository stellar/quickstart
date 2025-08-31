import { readAll } from "jsr:@std/io/read-all";

// Load the input (images.json).
const images = JSON.parse(new TextDecoder().decode(await readAll(Deno.stdin)));

const repoMapping = {
  "xdr": "stellar/rs-stellar-xdr",
  "core": "stellar/stellar-core",
  "horizon": "stellar/go",
  "stellar_rpc": "stellar/stellar-rpc",
  "friendbot": "stellar/go",
  "lab": "stellar/laboratory",
};

async function getSha(repo, ref) {
  const p = Deno.run({
    cmd: ["gh", "api", `repos/${repo}/commits/${ref}`],
    stdout: "piped",
    stderr: "piped",
  });

  const { code } = await p.status();
  if (code !== 0) {
    const rawError = await p.stderrOutput();
    const errorString = new TextDecoder().decode(rawError);
    throw new Error(`Failed to fetch SHA for ${repo}#${ref}: ${errorString}`);
  }

  const rawOutput = await p.output();
  const data = JSON.parse(new TextDecoder().decode(rawOutput));
  return data.sha;
}

const newImages = {};

for (const key in images) {
  const imageSet = images[key];
  const newImageSet = { ...imageSet };

  for (const imageKey in imageSet) {
    if (imageKey.endsWith("_ref")) {
      const software = imageKey.replace("_ref", "");
      const repo = repoMapping[software];
      const ref = imageSet[imageKey];

      if (repo) {
        const sha = await getSha(repo, ref);
        newImageSet[imageKey] = sha;
      }
    }
  }
  newImages[key] = newImageSet;
}

console.log(JSON.stringify(newImages, null, 2));
