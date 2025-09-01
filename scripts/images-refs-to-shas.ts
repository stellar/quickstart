// Modifies images.json input containing git references (branches, tags) so
// that the references are replaced with a commit sha.

import { readAll } from "jsr:@std/io/read-all";
import { Octokit } from "octokit";

const octokit = new Octokit({ auth: Deno.env.get("GITHUB_TOKEN")});

// Load the input (images.json).
const images = JSON.parse(new TextDecoder().decode(await readAll(Deno.stdin)));

// Map the values in _ref fields to a sha.
for (const key in images) {
  const image = images[key];
  for (const key in image) {
    if (key.endsWith("_ref")) {
      const ref = image[key];
      image[key] = await getSha(ref);
    }
  }
}

// Output the modified JSON.
console.log(JSON.stringify(images, null, 2));

// Given an owner/repo@ref string, return owner/repo@sha.
async function getSha(ownerRepoRef : string) : Promise<string> {
  const [ownerRepo, ref] = ownerRepoRef.split('@');
  const [owner, repo] = ownerRepo.split('/');
  const response = await octokit.rest.repos.getCommit({ owner, repo, ref });
  return `${ownerRepo}@${response.data.sha}`;
}
