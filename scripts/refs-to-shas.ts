import { readAll } from "jsr:@std/io/read-all";
import { Octokit } from "octokit";
import "jsr:@std/dotenv/load";

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

const octokit = new Octokit({ auth: Deno.env.get("GITHUB_TOKEN") });

async function getSha(repo, ref) {
  try {
    const [owner, repoName] = repo.split('/');
    const response = await octokit.rest.repos.getCommit({
      owner,
      repo: repoName,
      ref,
    });
    return response.data.sha;
  } catch (error) {
    throw new Error(`Failed to fetch SHA for ${repo}#${ref}: ${error.message}`);
  }
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
