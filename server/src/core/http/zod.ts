import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';

// Adds `.openapi()` to every zod schema. Import `z` from here (not from 'zod')
// in any file that describes a request or response.
extendZodWithOpenApi(z);

export { z };
