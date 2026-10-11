/**
 * Values the middleware attaches to each request.
 */
export interface AuthContext {
  userId: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      /** Set by `authenticate`. */
      auth?: AuthContext;
      /** The caller's install, from the `X-Device-Id` header (optional). */
      installationId?: string;
      /** Correlates log lines and error responses. */
      requestId?: string;
    }
  }
}

export {};
