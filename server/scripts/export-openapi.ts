import { writeFileSync } from 'node:fs';

import { buildApiDocument } from '../src/app.js';

// Writes docs/openapi.json, e.g. to generate a client or review API changes in PRs.
const document = buildApiDocument('http://localhost:8080');
writeFileSync(
  new URL('../docs/openapi.json', import.meta.url),
  `${JSON.stringify(document, null, 2)}\n`,
);
console.log('Wrote docs/openapi.json');
