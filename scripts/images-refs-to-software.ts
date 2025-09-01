// Converts an images.json into a list of software and the versions that need
// to be built.

import { readAll } from "jsr:@std/io/read-all";

// Load the input (images.json).
const images = JSON.parse(new TextDecoder().decode(await readAll(Deno.stdin)));

// Take the software versions from each image and place them into a mapping of
// software to versions.
const software = {};
for (const key in images) {
  const image = images[key];
  for (const key in image) {
    if (key.endsWith("_ref")) {
      const name = key.replace(/_ref/, "");
      const version = image[key];
      software[name] ||= new Set();
      software[name].add(version);
    }
  }
}

// Convert the Sets to Arrays.
for (const name in software) {
  software[name] = [...software[name]];
}

// Output the modified JSON.
console.log(JSON.stringify(software, null, 2));
