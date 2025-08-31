import { readAll } from "jsr:@std/io/read-all";

// Load the input (images.json).
const images = JSON.parse(new TextDecoder().decode(await readAll(Deno.stdin)));

// Take the software versions from each image and place them into a mapping of
// software to all the versions of each software needed for all the images.
const softwareVersions = {};
for (const key in images) {
  const imageSet = images[key];
  for (const imageKey in imageSet) {
    if (imageKey.endsWith("_ref")) {
      const software = imageKey.replace(/_ref/, "");
      const version = imageSet[imageKey];
      if (!softwareVersions[software]) {
        softwareVersions[software] = new Set();
      }
      softwareVersions[software].add(version);
    }
  }
}

// Convert the Sets to Arrays.
for (const software in softwareVersions) {
  softwareVersions[software] = [...softwareVersions[software]];
}

console.log(JSON.stringify(softwareVersions, null, 2));
