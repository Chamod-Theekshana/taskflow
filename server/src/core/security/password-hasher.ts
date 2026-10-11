import { hash, verify } from '@node-rs/argon2';

/** Port: how passwords are hashed. Lets tests swap in something faster. */
export interface PasswordHasher {
  hash(password: string): Promise<string>;
  verify(hashValue: string, password: string): Promise<boolean>;
}

/**
 * Argon2id (the OWASP first choice) with the OWASP-recommended cost:
 * 19 MiB memory, 2 iterations, 1 lane. Native, prebuilt binaries: no node-gyp.
 */
export class Argon2PasswordHasher implements PasswordHasher {
  private static readonly options = {
    memoryCost: 19_456,
    timeCost: 2,
    parallelism: 1,
  } as const;

  hash(password: string): Promise<string> {
    return hash(password, Argon2PasswordHasher.options);
  }

  async verify(hashValue: string, password: string): Promise<boolean> {
    try {
      return await verify(hashValue, password);
    } catch {
      return false;
    }
  }
}

/** Same rules as the app's sign-up form: 8+ characters, upper and lower case, a digit. */
export function passwordMeetsRules(password: string): boolean {
  return (
    password.length >= 8 &&
    password.length <= 128 &&
    /[A-Z]/.test(password) &&
    /[a-z]/.test(password) &&
    /[0-9]/.test(password)
  );
}
